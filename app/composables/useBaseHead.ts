/**
 * Mirrors the `title` / `description` / canonical wiring that BaseHead.astro did.
 */
export const useBaseHead = (options: { title: string, description?: string }) => {
  const route = useRoute()
  const { siteUrl } = useRuntimeConfig().public

  useHead({
    title: options.title,
    meta: [
      { name: 'title', content: options.title },
      { name: 'description', content: options.description ?? '' },
    ],
    link: [
      { rel: 'canonical', href: new URL(route.path, siteUrl).toString() },
    ],
  })
}
