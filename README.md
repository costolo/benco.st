[ben-go to benco!](https://benco.st)

A Nuxt port of [astrolio](../astrolio) — the same site, same look, Nuxt under the
hood instead of Astro.

## Setup

```bash
npm install
```

## Development

```bash
npm run dev
```

## Production

```bash
npm run build
node .output/server/index.mjs
```

### Deploying to Cloud Run

Production is the Cloud Run service **`portfolio`** in `northamerica-northeast1`
(project `bencost`), with benco.st attached through Cloud Run's custom-domains
router. Cloud Run terminates TLS itself and injects a `PORT` — the service's
container port is **8080**, which is why the Astro image's `ENV PORT=4321` never
mattered. Nitro's node server honours both `PORT` and `HOST`, so the image needs
no Cloud Run-specific configuration; the `Dockerfile` deliberately bakes in no
`PORT` so the injected value cannot be shadowed. Locally, and in
`docker-compose.yml`, nitro falls back to 3000.

Because the domain is bound to the *service*, swapping apps is a new revision on
that same service — no DNS or certificate changes, and rollback is one command.

`scripts/deploy.sh` (`npm run deploy`) automates the runbook below for the
single-container Nuxt image: it refuses to run off `main` or on a dirty tree
(`--allow-dirty` to override), pins traffic to the running revision, builds and
pushes (`nuxtlio:<version>-<sha>`, local docker with a Cloud Build fallback),
stages the new revision at 0% behind the `nuxt` tag, smoke-tests the tag URL,
asks before promoting it to 100%, then restores `--to-latest`. Any failure
leaves traffic pinned to the previous revision and prints the rollback command.
`-y` skips the prompt; `--keep-pinned` skips the `--to-latest` restore. The
manual sequence stays here as the reference for what the script does:

```bash
R=northamerica-northeast1
IMG=northamerica-northeast1-docker.pkg.dev/bencost/bencost-portfolio/nuxtlio:1.5.0

# 0. Record the revision you are rolling back to, and how traffic is targeted.
gcloud run services describe portfolio --region $R \
  --format='value(status.traffic[].revisionName, status.traffic[].percent)'

# 1. Pin traffic explicitly. The service ships with latestRevision: true, which
#    auto-promotes any new revision to 100% — pinning first makes step 3 inert.
gcloud run services update-traffic portfolio --region $R \
  --to-revisions portfolio-00006-jmq=100

# 2. Build and push. Docker is already credHelper'd for this registry.
docker build -t "$IMG" . && docker push "$IMG"

# 3. New revision, no traffic, with a preview URL.
gcloud run deploy portfolio --region $R --image "$IMG" \
  --no-traffic --tag nuxt --port 8080 --cpu-boost

# 4. Smoke-test the printed https://nuxt-portfolio-*.run.app URL, then promote.
gcloud run services update-traffic portfolio --region $R \
  --to-revisions NEW_REVISION=100

# Rollback.
gcloud run services update-traffic portfolio --region $R \
  --to-revisions portfolio-00006-jmq=100
```

The service currently sets no environment variables, so nothing astro-specific
carries into the new revision; `roles/run.invoker: allUsers` and
`--allow-unauthenticated` are service-level and persist. `--cpu-boost` shortens
cold starts. Memory is 512Mi today, which is enough for SSR — add
`--memory 1Gi` only if you want headroom, since it roughly doubles per-request
memory cost. `gcloud builds submit --tag "$IMG" .` works as an alternative to
step 2; `.gcloudignore` keeps `node_modules` out of that upload.

## How it maps to the Astro original

| Astro | Nuxt |
| --- | --- |
| `src/layouts/Default.astro` + `components/layout/BaseLayout.astro` | `app/layouts/default.vue` (the two collapse into one; only the 404 used `Default` directly, and that is `app/error.vue`) |
| `components/layout/BaseHead.astro` | `app/composables/useBaseHead.ts` + `app.head` in `nuxt.config.ts` |
| `components/generic/LocalFont.astro` (`astro-font`) | `app/assets/css/fonts.css` (hand-written `@font-face`, same families/selectors/`swap`) |
| `@unocss/astro` with `injectReset` | `@unocss/nuxt` + `@unocss/reset/tailwind.css`, same `uno.config.ts` |
| `<ViewTransitions />` | `app.pageTransition` fade in `nuxt.config.ts` |
| `astro-useragent`'s `isMobile` | `app/utils/user-agent.ts` (same `ua-parser-js` device check), primed per request by `app/plugins/user-agent.server.ts` |
| `nanostores` atom in `src/store.ts` | `app/composables/useTvChannel.ts` (`useState`) |
| `src/lib.ts` | `app/lib/audio.ts` (unchanged) |
| `src/pages/404.astro` + `components/errors/404.astro` | `app/error.vue` + `app/components/ErrorPage.vue` |
| `@astrojs/sitemap` | `@nuxtjs/sitemap` |

Two behaviours from the original are preserved deliberately because the layout
depends on them:

- `Card` styles `.fullscreen` (lowercase) while the template emits the class
  `fullScreen`, so that rule never matches.
- `.antenna-container` is `display: none` in CSS, which outranks the `md:flex`
  utility, so the TV antenna stays hidden at every breakpoint.

Not ported: `BaseFooter`, `BoxMarquee`, `Contact`, `SummaryCard` and
`MobileSocials` were never imported by any page in the Astro app, and with them
went the `@eliancodes/brutal-ui`, `satori` and `@astrojs/rss` dependencies.

## Scraping protection (Anubis)

Production can run behind [Anubis](https://anubis.techaro.lol), a
proof-of-work challenge proxy that stops scraper bots before they reach Nuxt:

```bash
docker compose up -d --build
```

Topology is `TLS terminator -> Anubis (:8080, the only published port) -> web
(:3000, internal)`. Anubis does not terminate TLS itself, so keep whatever
terminates TLS for the site in front of port 8080.

- `botPolicy.yaml` is mounted as `POLICY_FNAME`. It reproduces the shipped
  default ruleset and adds `DENY` rules mirroring the AI-scraping deny-list in
  `public/robots.txt` (the robots2policy mapping). Search engines, feed
  readers and `/robots.txt` itself stay allowed, so sitemap/RSS/SEO behaviour
  is unchanged.
- `SERVE_ROBOTS_TXT` is deliberately left off: Nuxt serves the curated
  `public/robots.txt`.
- Open Graph passthrough is enabled in the policy so social unfurlers fetch
  metadata without solving a challenge.
- If Anubis is the true edge (nothing in front of it), set
  `USE_REMOTE_ADDRESS: "true"` in `docker-compose.yml` so spoofable
  `X-Forwarded-For` headers are ignored. With a TLS proxy in front, leave it
  unset and have that proxy send `X-Real-IP`.
- Set `ED25519_PRIVATE_KEY_HEX` (generate with `openssl rand -hex 32`) in
  `.env` to keep challenge pass-cookies valid across Anubis restarts; unset,
  the key is auto-generated and visitors are simply re-challenged after a
  restart.
- Adding another reverse proxy in front of Anubis later? It must route
  `/.within.website/x/xess/` and `/.within.website/x/cmd/anubis` to Anubis.

Limitations: clients driving a full headless browser still solve the
proof-of-work, so Anubis raises cost and stops JS-less bulk scraping rather
than acting as a complete wall. First human visits pay a few seconds of
challenge time, and JS-blocking extensions (e.g. JShelter) fail it.

`DIFFICULTY` in `docker-compose.yml` has no visible effect once `POLICY_FNAME` is
set. Anubis still echoes `difficulty:4` in its startup log, but the `thresholds`
block in `botPolicy.yaml` is what maps a rule's weight to a challenge difficulty.

### Anubis on Cloud Run

Cloud Run runs multiple containers per revision, and every container in an
instance shares one network namespace, so they reach each other over
`localhost:port`. Only the single container with an exposed port receives
external traffic. That makes Anubis the ingress container of the *existing*
`portfolio` service, with Nuxt as a sidecar:

```
benco.st -> global LB -> Cloud Run service `portfolio`
                           |- anubis  (ingress, containerPort 8080)
                           `- nuxt    (sidecar, localhost:3000, no external port)
```

The domain binds to the service, so this needs no DNS change, no certificate
work, no VPC, no connector, no internal load balancer and no second service.
Scrapers also cannot route around Anubis the way a two-service split would
allow, because a sidecar with no exposed port has no external address to reach.
`/.within.website/x/xess/` and `/.within.website/x/cmd/anubis` need no special
routing for the same reason.

Gotchas, verified against Anubis `v1.28.1` and the Cloud Run docs:

- **Anubis does not read `$PORT`.** It binds `:8923` by default and honours only
  `BIND`, so `BIND=:8080` and `containerPort: 8080` must be set to the same
  value by hand — nothing derives one from the other.
- **The Nuxt image needs no change.** `PORT` is injected into the ingress
  container only, so Nitro falls back to 3000 exactly as it does under compose.
  Set `PORT=3000` on the sidecar regardless, so the two containers can never
  contend for 8080.
- **Anubis must not take traffic before Nuxt is listening.** Anubis binds in
  milliseconds while Nitro needs a second or two, so the first request to a cold
  instance would 502. Make `anubis` depend on `nuxt` and give the sidecar a
  startup probe. Note that the Cloud Run docs claim healthchecks cannot be
  configured with the gcloud CLI, but `--startup-probe` does exist and accepts
  `tcpSocket.port`, as does `--depends-on` — so `gcloud run deploy` can express
  the whole topology without a revision YAML.
- **`ED25519_PRIVATE_KEY_HEX` becomes mandatory**, sourced from Secret Manager.
  Pass-cookies are signed with it, and each container generates its own when it
  is unset, so scaling out or shipping a revision would invalidate every
  visitor's cookie and re-challenge them.
- **Leave `USE_REMOTE_ADDRESS` unset.** Cloud Run supplies `X-Forwarded-For`, and
  Anubis strips private addresses from it by default, which is what you want
  behind the load balancer.
- **`botPolicy.yaml` must be baked into the Anubis image.** Cloud Run has no bind
  mounts, so `COPY` it in a two-line `FROM ghcr.io/techarohq/anubis:v1.28.1`
  Dockerfile, build with `--platform linux/amd64`, and pin the version tag rather
  than `:latest`. The policy's `(data)/...` imports resolve against files
  embedded in that image, so a version bump can break them — boot it once
  locally to confirm the policy still parses.
- **Set `REDIRECT_DOMAINS`.** Left unset, Anubis warns at startup that it "will
  redirect to any domain": an attacker can send a visitor a validation link with
  a pre-filled challenge solution that redirects them, pass-cookie in hand, to a
  hostile site. The value is comma-separated hostnames with no scheme, subdomains
  are not implied, and every hostname the site answers on must be listed —
  including a staging tag URL while testing, or the post-challenge redirect fails
  with "Redirect domain not allowed".
- **Open Graph passthrough comes from the policy file, not an env var.**
  `botPolicy.yaml` already sets `openGraph.enabled: true`, which is the current
  mechanism; `OG_PASSTHROUGH` is a legacy alias kept for backwards compatibility
  whose default was flipped to `false`. So the startup log reporting
  `og-passthrough:false` does **not** mean link unfurling is broken — don't add
  the env var to "fix" it.

CPU and memory limits are declared per container, so the instance is sized for
both (e.g. 500m/256Mi for Anubis alongside 1000m/512Mi for Nuxt). The
proof-of-work is solved client-side, so verifying it costs Anubis little.

The service ships with `latestRevision: true`, which auto-promotes any new
revision to 100%, so pin traffic to the running revision before deploying an
un-promoted one behind a tag URL.

The command-by-command runbook lives in `ANUBIS-IMPLEMENTATION.md`, which is
gitignored and local-only.
