export default defineNuxtPlugin(() => {
  const { 'user-agent': userAgent } = useRequestHeaders(['user-agent'])

  useState<boolean>('ua:is-mobile', () => isMobileUA(userAgent))
})
