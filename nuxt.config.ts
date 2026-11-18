export default defineNuxtConfig({
  compatibilityDate: '2026-10-19',

  modules: ['@unocss/nuxt', '@nuxtjs/sitemap'],

  css: [
    '@unocss/reset/tailwind.css',
    '~/assets/css/fonts.css',
    '~/assets/css/global.css',
  ],

  app: {
    head: {
      htmlAttrs: { lang: 'en', class: 'h-full' },
      bodyAttrs: { class: 'h-full' },
      meta: [
        { name: 'viewport', content: 'width=device-width, initial-scale=1' },
        { name: 'robots', content: 'noai, noimageai' },
      ],
      link: [
        { rel: 'icon', type: 'image/svg', href: '/favicon.svg' },
        {
          rel: 'alternate',
          type: 'application/rss+xml',
          href: 'https://benco.st/blog.xml',
        },
        {
          rel: 'preload',
          as: 'font',
          type: 'font/ttf',
          href: '/fonts/outfit.ttf',
          crossorigin: '',
        },
      ],
    },
    pageTransition: { name: 'page-fade', mode: 'out-in' },
  },

  runtimeConfig: {
    public: {
      siteUrl: 'https://benco.st',
    },
  },

  site: {
    url: 'https://benco.st',
  },

  routeRules: {
    // The Godot game lives in the public GCS bucket, not in public/; keep the
    // old routes working for anyone with a direct link.
    '/games/trawler': {
      redirect: 'https://storage.googleapis.com/bencost-games/trawler/index.html',
    },
    '/games/trawler/': {
      redirect: 'https://storage.googleapis.com/bencost-games/trawler/index.html',
    },
  },
})
