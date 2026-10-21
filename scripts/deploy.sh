#!/usr/bin/env bash
#
# Deploy the current `main` to Cloud Run service `portfolio` (benco.st) and
# promote it to 100% of live traffic.
#
# Flow:
#   1. preflight      branch/tree/auth checks
#   2. pin            freeze traffic on the revision serving 100% right now
#   3. build+push     local docker, Cloud Build if the daemon is unreachable
#   4. stage          new revision at 0% traffic behind a tag URL
#   5. smoke test     the tag URL must serve the new build before promotion
#   6. promote        100% of benco.st, then restore --to-latest
#
# Step 2 is load-bearing: the service ships `latestRevision: true`, which
# auto-promotes ANY new revision to 100% the moment it is created. Pinning first
# is what makes step 4 actually inert, so nothing reaches visitors until step 6.
#
# This deploys the single-container Nuxt image only. The Anubis sidecar topology
# in cloudrun.yaml is a separate `gcloud run services replace` flow.

set -euo pipefail

readonly PROJECT=${PROJECT:-bencost}
readonly REGION=${REGION:-northamerica-northeast1}
readonly SERVICE=${SERVICE:-portfolio}
readonly REGISTRY=${REGION}-docker.pkg.dev/${PROJECT}/bencost-portfolio
readonly IMAGE_NAME=nuxtlio
readonly DOMAIN=${DOMAIN:-https://benco.st}

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"

TAG=nuxt
ALLOW_DIRTY=0
ASSUME_YES=0
KEEP_PINNED=0

usage() {
  cat <<USAGE
Usage: scripts/deploy.sh [options]

Builds the current \`main\` and promotes it to 100% of ${DOMAIN/#https:\/\//} traffic.

  -y, --yes           Promote without the interactive confirmation.
      --allow-dirty   Build from a dirty working tree (default: refuse).
      --tag NAME      Traffic tag for the staged revision (default: $TAG).
                      The tag URL moves to the new revision, so the old rollback
                      tag URL keeps resolving but no longer points at the old build.
      --keep-pinned   Leave traffic pinned to the deployed revision instead of
                      restoring --to-latest (the service's shipped default).
  -h, --help          Show this help.

Environment overrides: PROJECT, REGION, SERVICE (rarely needed).
USAGE
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -y|--yes)      ASSUME_YES=1 ;;
    --allow-dirty) ALLOW_DIRTY=1 ;;
    --keep-pinned) KEEP_PINNED=1 ;;
    --tag)         TAG=${2:?"--tag needs a value"}; shift ;;
    --tag=*)       TAG=${1#--tag=} ;;
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
die()  { printf '\n%serror:%s %s\n' "$RED" "$OFF" "$*" >&2; pin_hint; exit 1; }

# Printed on any failure once traffic has been pinned, so the operator is never
# left guessing whether the old build is still live.
pin_hint() {
  [[ -n ${PREV_REV:-} ]] || return 0
  cat >&2 <<EOF

    Traffic is pinned to $PREV_REV, so $DOMAIN is still serving the
    previous build. Nothing was promoted. Re-run after fixing, or re-pin:

      gcloud run services update-traffic $SERVICE \\
        --region=$REGION --project=$PROJECT --to-revisions=$PREV_REV=100
EOF
}

# Service reads are frequent enough to be worth a helper; --format values are
# verified against the live service, not assumed.
svc() {
  gcloud run services describe "$SERVICE" \
    --region="$REGION" --project="$PROJECT" --format="$1"
}

# The revision currently taking traffic. Slicing the traffic list inside
# --format (status.traffic[percent=100].revisionName) silently returns empty on
# this SDK, so flatten to csv and filter with awk instead.
serving_revision() {
  svc 'csv[no-heading](status.traffic.percent,status.traffic.revisionName)' \
    | awk -F, '$1 + 0 > 0 { print $2; exit }'
}

tag_url() {
  svc 'csv[no-heading](status.traffic.tag,status.traffic.url)' \
    | awk -F, -v t="$1" '$1 == t { print $2; exit }'
}

http_code() {
  curl -sS -o /dev/null -w '%{http_code}' --max-time "${2:-30}" "$1" || true
}

confirm() {
  if [[ $ASSUME_YES == 1 ]]; then return 0; fi
  [[ -r /dev/tty ]] || die "no tty to confirm on; re-run with --yes"
  printf '\n    %s%s%s ' "$BOLD" "$1" "$OFF"
  local ans
  read -r ans < /dev/tty
  [[ $ans == [yY]* ]]
}

# ------------------------------------------------------------------- preflight

PREV_REV=
NEW_REV=

on_error() {
  local exit_code=$?
  trap - ERR
  printf '\n%sdeploy failed%s (exit %s)\n' "$RED" "$OFF" "$exit_code" >&2
  pin_hint
  exit "$exit_code"
}
trap on_error ERR

step "Preflight"

for cmd in gcloud git curl awk; do
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
IMAGE=${REGISTRY}/${IMAGE_NAME}:${VERSION}-${SHA}
info "image: $IMAGE"

# ------------------------------------------------------------------------ pin

step "Pin traffic to the running revision"

PREV_REV=$(serving_revision)
if [[ -z $PREV_REV ]]; then
  warn "no revision with a traffic percent; falling back to latestReadyRevisionName"
  PREV_REV=$(svc 'value(status.latestReadyRevisionName)')
fi
[[ -n $PREV_REV ]] || die "could not determine the revision currently serving traffic"
info "serving 100% now: $PREV_REV"

gcloud run services update-traffic "$SERVICE" \
  --region="$REGION" --project="$PROJECT" \
  --to-revisions="${PREV_REV}=100" --quiet > /dev/null
ok "pinned to $PREV_REV (latestRevision auto-promote is now off)"

# ---------------------------------------------------------------------- build

step "Build and push"

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

step "Create the new revision (0% traffic, tag '$TAG')"

gcloud run deploy "$SERVICE" \
  --region="$REGION" --project="$PROJECT" \
  --image="$IMAGE" \
  --port=8080 \
  --cpu-boost \
  --no-traffic --tag="$TAG"

NEW_REV=$(svc 'value(status.latestCreatedRevisionName)')
[[ -n $NEW_REV ]] || die "could not read the new revision name"
[[ $NEW_REV != "$PREV_REV" ]] \
  || die "latestCreatedRevisionName is still $PREV_REV; the deploy did not create a revision"
ok "created $NEW_REV"

info "waiting for $NEW_REV to become ready"
for _ in $(seq 1 60); do
  [[ $(svc 'value(status.latestReadyRevisionName)') == "$NEW_REV" ]] && break
  sleep 5
done
[[ $(svc 'value(status.latestReadyRevisionName)') == "$NEW_REV" ]] \
  || die "$NEW_REV never became ready; check: gcloud run revisions describe $NEW_REV --region=$REGION"
ok "$NEW_REV is ready"

# `gcloud run deploy` read-modify-writes the service, so cpu/memory carry over
# from the previous revision. Surface them anyway: a silent downgrade only shows
# up later as an OOM kill under load.
REV_SPEC=$(gcloud run revisions describe "$NEW_REV" \
  --region="$REGION" --project="$PROJECT" \
  --format='value(spec.containers[0].image,spec.containers[0].resources.limits.cpu,spec.containers[0].resources.limits.memory)' \
  | tr '\t' ' ')
info "running: $REV_SPEC"
[[ $REV_SPEC == ${REGISTRY}/${IMAGE_NAME}* ]] \
  || die "$NEW_REV is not running $IMAGE_NAME from $REGISTRY"

# ----------------------------------------------------------------- smoke test

step "Smoke test the staged revision"

STAGE_URL=$(tag_url "$TAG")
[[ -n $STAGE_URL ]] || die "no tag URL for '$TAG' on the service"
info "$STAGE_URL -> $NEW_REV"

smoke() { # url, description, [substring]
  local url=$1 what=$2 needle=${3:-} attempt code body
  for attempt in 1 2 3; do
    if [[ -n $needle ]]; then
      body=$(curl -fsS --max-time 30 "$url" 2>/dev/null || true)
      if [[ $body == *"$needle"* ]]; then
        ok "$what"
        return 0
      fi
    else
      code=$(http_code "$url")
      if [[ $code == 200 ]]; then
        ok "$what (200)"
        return 0
      fi
    fi
    [[ $attempt == 3 ]] || { info "retrying $what (attempt $attempt)"; sleep 5; }
  done
  return 1
}

# `/_nuxt/` asset paths prove the response came from a Nuxt build rather than a
# cached or error page.
smoke "$STAGE_URL/" "GET /  renders the Nuxt app" '/_nuxt/' \
  || die "staged revision failed GET / at $STAGE_URL"
smoke "$STAGE_URL/sitemap.xml" "GET /sitemap.xml" \
  || die "staged revision failed /sitemap.xml at $STAGE_URL"

# --------------------------------------------------------------------- promote

step "Promote"

cat <<EOF

    $SERVICE: $PREV_REV (100%)  ->  $NEW_REV (100%)
    image:    $IMAGE
    live at:  $DOMAIN

EOF

confirm "Promote $NEW_REV to 100% of $DOMAIN?" \
  || die "aborted before promotion; $PREV_REV is still serving 100%"

gcloud run services update-traffic "$SERVICE" \
  --region="$REGION" --project="$PROJECT" \
  --to-revisions="${NEW_REV}=100" --quiet > /dev/null
ok "$NEW_REV is taking 100%"

if [[ $KEEP_PINNED == 1 ]]; then
  info "leaving traffic pinned to $NEW_REV (--keep-pinned)"
else
  gcloud run services update-traffic "$SERVICE" \
    --region="$REGION" --project="$PROJECT" --to-latest --quiet > /dev/null
  ok "restored latestRevision: true (the service's shipped default)"
fi

step "Verify $DOMAIN"

for path in / /sitemap.xml; do
  for attempt in 1 2 3; do
    code=$(http_code "${DOMAIN}${path}")
    [[ $code == 200 ]] && { ok "GET ${path} 200"; break; }
    if [[ $attempt == 3 ]]; then
      warn "GET ${path} returned ${code:-000} after 3 tries; check the LB/domain binding"
    else
      sleep 5
    fi
  done
done

trap - ERR
cat <<EOF

${BOLD}Deployed${OFF} $DOMAIN  ->  $NEW_REV  ($IMAGE)

  Roll back with:
    gcloud run services update-traffic $SERVICE \\
      --region=$REGION --project=$PROJECT \\
      --to-revisions=$PREV_REV=100

EOF
