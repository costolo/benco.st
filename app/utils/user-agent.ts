import { UAParser } from 'ua-parser-js'

/**
 * Same check `astro-useragent`'s `isMobile` performs: ua-parser-js device type
 * of exactly `mobile` (tablets are excluded).
 */
export const isMobileUA = (userAgent?: string | null): boolean =>
  new UAParser(userAgent ?? '').getDevice().type === 'mobile'
