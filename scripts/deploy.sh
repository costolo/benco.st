#!/usr/bin/env bash
#
# Deploy the current `main` to Cloud Run service `portfolio` (benco.st) while
# preserving the Anubis ingress + Nuxt sidecar topology.
#
# Only the Nuxt sidecar image changes. The anubis container is regenerated
# byte-identical from the live service, so the bot-challenge ingress cannot be
# regressed by this script. This is NOT the old single-container flow: that used
# `gcloud run deploy`, which silently drops sidecars. This uses
# `gcloud run services replace`, the only surface that accepts sidecars, startup
# probes, and container start ordering (see cloudrun.yaml's header).
#
# Flow:
#   1. preflight   branch/tree/auth checks
#   2. build+push  local docker, Cloud Build if the daemon is unreachable
#   3. stage       replace with the new nuxt image at 0% traffic (tag `anubis`);
#                  the old revision stays 100% (tag `nuxt`) for rollback
#   4. smoke       the `anubis` tag URL must serve the new build before promote
#   5. promote     100% of benco.st, keeping both tags
#   6. verify      anubis challenge + nuxt passthrough on the live domain
#
# `services replace` is atomic: a bad stage replace errors out without touching
# the running service. Nothing reaches visitors until the promote step.

set -euo pipefail

readonly PROJECT=${PROJECT:-bencost}
readonly REGION=${REGION:-northamerica-northeast1}
readonly SERVICE=${SERVICE:-portfolio}
readonly REGISTRY=${REGION}-docker.pkg.dev/${PROJECT}/bencost-portfolio
readonly IMAGE_NAME=nuxtlio
readonly DOMAIN=${DOMAIN:-https://benco.st}
# Tag the live revision carries (referenced by anubis REDIRECT_DOMAINS) and the
# tag the previous good revision carries for rollback.
readonly LIVE_TAG=anubis
readonly ROLLBACK_TAG=nuxt

# Smoke-test signals. Only `Mozilla*` user-agents hit the Anubis challenge; a
# plain `curl` UA (and e.g. facebookexternalhit) passes through to the Nuxt app.
readonly CHALLENGE_MARKER='Making sure you'
readonly NUXT_MARKER='/_nuxt/'
readonly BROWSER_UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
readonly CURL_UA='curl/8.0'

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"

ALLOW_DIRTY=0
ASSUME_YES=0

usage() {
  cat <<USAGE
Usage: scripts/deploy.sh [options]

Builds the current \`main\`, stages it behind the Anubis front, and promotes it
to 100% of ${DOMAIN/#https:\/\//} traffic. Keeps the Anubis ingress + Nuxt
sidecar topology; only the Nuxt image changes.

  -y, --yes           Promote without the interactive confirmation.
      --allow-dirty   Build from a dirty working tree (default: refuse).
  -h, --help          Show this help.

Environment overrides: PROJECT, REGION, SERVICE (rarely needed).
USAGE
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -y|--yes)      ASSUME_YES=1 ;;
    --allow-dirty) ALLOW_DIRTY=1 ;;
    -h|--help)     usage; exit 0 ;;
    *)             printf 'unknown option: %s\n\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

# ---------------------------------------------------------------- output helpers

if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; RED=$'\033[31m'; GREEN=$'\033[32m'
  YELLOW=$'\033[33m'; OFF=$'\033[0m'
else
  BOLD=; RED=; GREEN=; YELLOW=; OFF=
fi

step() { printf '\n%s==> %s%s\n' "$BOLD" "$*" "$OFF"; }
info() { printf '    %s\n' "$*"; }
ok()   { printf '    %s%s%s\n' "$GREEN" "$*" "$OFF"; }
warn() { printf '    %s! %s%s\n' "$YELLOW" "$*" "$OFF" >&2; }
die()  { printf '\n%serror:%s %s\n' "$RED" "$OFF" "$*" >&2; rollback_hint; exit 1; }

# Printed on any failure once the old revision has been identified, so the
# operator always knows how to point traffic back.
rollback_hint() {
  [[ -n ${OLD_REV:-} ]] || return 0
  cat >&2 <<EOF

    $OLD_REV is still the rollback target. Nothing was promoted to it unless a
    promote step above already ran. To pin traffic back:

      gcloud run services update-traffic $SERVICE \\
        --region=$REGION --project=$PROJECT \\
        --to-revisions=$OLD_REV=100

EOF
}

# Service reads are frequent enough to warrant a helper; --format values are
# verified against the live service, not assumed.
svc() {
  gcloud run services describe "$SERVICE" \
    --region="$REGION" --project="$PROJECT" --format="$1"
}

# The revision currently taking 100%. Slicing the traffic list inside --format
# silently returns empty on this SDK, so emit one record per list item
# (--flatten) and filter with awk. Without --flatten, gcloud joins a multi-entry
# list's repeated fields with ';' and the comma-split misaligns.
serving_revision() {
  gcloud run services describe "$SERVICE" \
    --region="$REGION" --project="$PROJECT" \
    --flatten=status.traffic \
    --format='csv[no-heading](status.traffic.percent,status.traffic.revisionName)' \
    | awk -F, '$1 + 0 > 0 { print $2; exit }'
}

tag_url() {
  gcloud run services describe "$SERVICE" \
    --region="$REGION" --project="$PROJECT" \
    --flatten=status.traffic \
    --format='csv[no-heading](status.traffic.tag,status.traffic.url)' \
    | awk -F, -v t="$1" '$1 == t { print $2; exit }'
}

confirm() {
  if [[ $ASSUME_YES == 1 ]]; then return 0; fi
  [[ -r /dev/tty ]] || die "no tty to confirm on; re-run with --yes"
  printf '\n    %s%s%s ' "$BOLD" "$1" "$OFF"
  local ans
  read -r ans < /dev/tty
  [[ $ans == [yY]* ]]
}

# url, what, ua, needle -- the needle must appear in the (200) body.
smoke() {
  local url=$1 what=$2 ua=$3 needle=$4 attempt body
  for attempt in 1 2 3 4 5; do
    body=$(curl -fsS --max-time 30 -A "$ua" "$url" 2>/dev/null || true)
    if [[ $body == *"$needle"* ]]; then
      ok "$what"
      return 0
    fi
    [[ $attempt == 5 ]] || { info "retrying $what (attempt $attempt)"; sleep 6; }
  done
  return 1
}

# ------------------------------------------------------------------- preflight

OLD_REV=
NEW_REV=
SPEC_TMP=
trap '[[ -n $SPEC_TMP ]] && rm -f "$SPEC_TMP"' EXIT

on_error() {
  local exit_code=$?
  trap - ERR
  printf '\n%sdeploy failed%s (exit %s)\n' "$RED" "$OFF" "$exit_code" >&2
  rollback_hint
  exit "$exit_code"
}
trap on_error ERR

step "Preflight"

for cmd in gcloud git curl awk sed; do
  command -v "$cmd" >/dev/null 2>&1 || die "$cmd not found on PATH"
done

ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null | head -1)
[[ -n $ACCOUNT ]] || die "not authed to gcloud; run: gcloud auth login"
info "gcloud account: $ACCOUNT"

BRANCH=$(git rev-parse --abbrev-ref HEAD)
[[ $BRANCH == main ]] \
  || die "HEAD is on '$BRANCH', not 'main'. This deploys main; check out main first."

SHA=$(git rev-parse --short HEAD)
SUBJECT=$(git log -1 --pretty=%s)
info "main @ $SHA  $SUBJECT"

DIRTY=$(git status --porcelain)
if [[ -n $DIRTY ]]; then
  if [[ $ALLOW_DIRTY == 1 ]]; then
    warn "working tree is dirty; the image will NOT be reproducible from $SHA:"
    printf '%s\n' "$DIRTY" | sed 's/^/      /' >&2
  else
    printf '%s\n' "$DIRTY" | sed 's/^/      /' >&2
    die "working tree is dirty. Commit or stash it, or re-run with --allow-dirty."
  fi
fi

VERSION=$(grep -m1 '"version"' package.json | cut -d'"' -f4)
[[ -n $VERSION ]] || die "could not read version from package.json"

# ---------------------------------------------------------------------- build

step "Build and push the Nuxt sidecar image"

IMAGE=${REGISTRY}/${IMAGE_NAME}:${VERSION}-${SHA}
info "image: $IMAGE"

build_and_push() {
  docker build --platform linux/amd64 -t "$IMAGE" . && docker push "$IMAGE"
}

if docker info > /dev/null 2>&1; then
  info "using local docker"
  if ! build_and_push; then
    # The daemon on this machine has died mid-task before; if it is gone now,
    # retry in Cloud Build rather than failing the deploy. A genuine build error
    # with the daemon still up must surface, not be papered over.
    if docker info > /dev/null 2>&1; then
      die "docker build/push failed"
    fi
    warn "docker daemon went away mid-build; falling back to Cloud Build"
    gcloud builds submit --tag "$IMAGE" --project "$PROJECT" --quiet .
  fi
else
  # .gcloudignore must not exclude Dockerfile: Cloud Build extracts the source
  # tarball into /workspace and needs it there.
  warn "docker daemon unreachable; using Cloud Build"
  gcloud builds submit --tag "$IMAGE" --project "$PROJECT" --quiet .
fi
ok "pushed $IMAGE"

# ---------------------------------------------------------------------- stage

step "Stage the new Nuxt revision at 0% traffic (tag '$LIVE_TAG')"

OLD_REV=$(serving_revision)
if [[ -z $OLD_REV ]]; then
  OLD_REV=$(svc 'value(status.latestReadyRevisionName)')
fi
[[ -n $OLD_REV ]] || die "could not determine the revision currently serving traffic"

TEMPLATE_NAME=$(svc 'value(spec.template.metadata.name)')
[[ -n $TEMPLATE_NAME ]] || die "could not read the live template revision name"

# A name reused by any revision is rejected, so derive a fresh one while keeping
# it greppable: <commit>-<unixtime>.
NEW_REV="portfolio-anubis-${SHA}-$(date +%s)"
info "old revision (rollback): $OLD_REV"
info "new revision:            $NEW_REV"

SPEC_TMP=$(mktemp "${TMPDIR:-/tmp}/portfolio-replace.XXXXXX.yaml")

# Regenerate the replace spec from the LIVE export so the anubis container (and
# the custom-domain + secret + startup-ordering wiring) cannot drift from
# production. Strip the read-only/system-managed fields (the two output
# annotations plus the client-* informational annotations and the
# startupProbeType label -- its "Default" value is wrong for this service, per
# cloudrun.yaml), swap the nuxt image tag, bump the template name, and rewrite
# traffic so the old revision keeps 100% while the new revision lands behind the
# `anubis` tag at 0%.
gcloud run services describe "$SERVICE" \
  --region="$REGION" --project="$PROJECT" --format=export \
  | grep -v \
      -e 'run.googleapis.com/urls' \
      -e 'run.googleapis.com/ingress-status' \
      -e 'run.googleapis.com/client-name' \
      -e 'run.googleapis.com/client-version' \
      -e 'run.googleapis.com/startupProbeType' \
      -e '^      labels:$' \
  | sed -e "s|^        image: .*/nuxtlio:.*|        image: ${IMAGE}|" \
        -e "s|^      name: ${TEMPLATE_NAME}$|      name: ${NEW_REV}|" \
  | awk -v old="$OLD_REV" -v new="$NEW_REV" \
        -v live="$LIVE_TAG" -v rollback="$ROLLBACK_TAG" '
      /^  traffic:/ {
        print "  traffic:"
        print "  - revisionName: " old
        print "    percent: 100"
        print "    tag: " rollback
        print "  - revisionName: " new
        print "    tag: " live
        exit
      }
      { print }
    ' > "$SPEC_TMP"

# Surface the only deliberate image change, so a wrong swap is obvious.
grep -n "nuxtlio:" "$SPEC_TMP" | sed 's/^/    /'

gcloud run services replace "$SPEC_TMP" \
  --region="$REGION" --project="$PROJECT" --quiet
ok "staged $NEW_REV at 0% (tag '$LIVE_TAG'); $OLD_REV still at 100%"

info "waiting for $NEW_REV to become ready"
for _ in $(seq 1 60); do
  [[ $(svc 'value(status.latestReadyRevisionName)') == "$NEW_REV" ]] && break
  sleep 5
done
[[ $(svc 'value(status.latestReadyRevisionName)') == "$NEW_REV" ]] \
  || die "$NEW_REV never became ready; check: gcloud run revisions describe $NEW_REV --region=$REGION"
ok "$NEW_REV is ready"

# ----------------------------------------------------------------- smoke test

step "Smoke test the staged revision"

STAGE_URL=$(tag_url "$LIVE_TAG")
[[ -n $STAGE_URL ]] || die "no tag URL for '$LIVE_TAG' on the service"
info "$STAGE_URL -> $NEW_REV"

# Anubis must still front the new revision (browser UA gets challenged), and the
# new Nuxt image must still serve (curl UA passes through to a real Nuxt page).
smoke "$STAGE_URL/" "anubis challenge on staged revision" "$BROWSER_UA" "$CHALLENGE_MARKER" \
  || die "anubis is not fronting the staged revision at $STAGE_URL"
smoke "$STAGE_URL/" "nuxt passthrough on staged revision" "$CURL_UA" "$NUXT_MARKER" \
  || die "staged revision did not serve the Nuxt build at $STAGE_URL"

# --------------------------------------------------------------------- promote

step "Promote"

cat <<EOF

    $SERVICE: $OLD_REV (100%)  ->  $NEW_REV (100%)
    image:    $IMAGE
    live at:  $DOMAIN

EOF

confirm "Promote $NEW_REV to 100% of $DOMAIN?" \
  || die "aborted before promotion; $OLD_REV is still serving 100%"

# Flip the percentages, then re-assert the tags (update-traffic reconstructs the
# traffic list on each call, so the two flags are applied in two steps).
gcloud run services update-traffic "$SERVICE" \
  --region="$REGION" --project="$PROJECT" \
  --to-revisions="${NEW_REV}=100,${OLD_REV}=0" --quiet > /dev/null
gcloud run services update-traffic "$SERVICE" \
  --region="$REGION" --project="$PROJECT" \
  --set-tags="${LIVE_TAG}=${NEW_REV},${ROLLBACK_TAG}=${OLD_REV}" --quiet > /dev/null
ok "$NEW_REV is taking 100% (tag '$LIVE_TAG'); $OLD_REV is the '$ROLLBACK_TAG' rollback"

# ------------------------------------------------------------------ verify live

step "Verify $DOMAIN"

smoke "$DOMAIN/" "anubis challenge on $DOMAIN" "$BROWSER_UA" "$CHALLENGE_MARKER" \
  || warn "anubis challenge not observed on $DOMAIN; check the domain binding"
smoke "$DOMAIN/" "nuxt passthrough on $DOMAIN" "$CURL_UA" "$NUXT_MARKER" \
  || warn "nuxt passthrough not observed on $DOMAIN; check the domain binding"

trap - ERR
cat <<EOF

${BOLD}Deployed${OFF} $DOMAIN  ->  $NEW_REV  ($IMAGE)

  Roll back with:
    gcloud run services update-traffic $SERVICE \\
      --region=$REGION --project=$PROJECT \\
      --to-revisions=$OLD_REV=100

EOF