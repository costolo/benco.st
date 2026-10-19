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
