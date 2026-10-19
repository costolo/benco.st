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

### Anubis on Cloud Run

Cloud Run runs a single container per service — no compose, no sidecar — so the
topology above does not deploy there. On Cloud Run the site is protected by the
`public/robots.txt` deny-list alone unless Anubis is stood up as its own
service, which takes:

1. A second, public Cloud Run service running `ghcr.io/techarohq/anubis`, bound
   to the injected `PORT` rather than a hardcoded `:8080`, with `botPolicy.yaml`
   baked in via `COPY` — Cloud Run has no volumes, so the bind mount has to go
   into the image.
2. The Nuxt service made unreachable directly, otherwise scrapers just skip
   Anubis. `--ingress internal` only accepts traffic from an internal or
   self-managed load balancer, so this needs a VPC network, a connector, and an
   internal application load balancer in front of Nuxt.
3. `TARGET` pointing at Nuxt's internal load balancer hostname, and
   `USE_REMOTE_ADDRESS` left unset, since Cloud Run supplies `X-Forwarded-For`.
4. `ED25519_PRIVATE_KEY_HEX` set from a Cloud Run secret. Pass-cookies are
   signed with this key, and each container generates its own when it is unset,
   so cookies minted by one instance or revision would be rejected by the next.
   This is optional in the compose setup and effectively mandatory here.
5. The benco.st domain mapping moved from the Nuxt service to the Anubis one,
   with any future proxy in front of Anubis still routing
   `/.within.website/x/xess/` and `/.within.website/x/cmd/anubis` to it.

Other Anubis state is also per-container, so decide whether a single instance is
acceptable before scaling it. Net: a load balancer, a VPC connector and a second
service to protect a mostly-static personal site — not worth it until scraping
is a measured problem rather than an annoyance.
