/**
 * Set on the server for every request (see plugins/user-agent.server.ts) so the
 * value survives client-side navigation, the way it did under Astro SSR.
 */
export const useIsMobile = () => useState<boolean>('ua:is-mobile', () => false)
