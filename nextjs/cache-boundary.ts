export const PRIVATE_NO_STORE_CACHE_CONTROL =
  "private, no-store, no-cache, must-revalidate, proxy-revalidate";

export const PAINEL_MANIFEST_PATH = "/painel/manifest.webmanifest";
export const PAINEL_MANIFEST_CACHE_CONTROL =
  "public, max-age=86400, s-maxage=86400";

const PROTECTED_PAGE_PREFIXES = ["/painel", "/dashboard"] as const;

export const PROTECTED_PAGE_ROUTE_SOURCES = PROTECTED_PAGE_PREFIXES.map(
  (prefix) => `${prefix}/:path*`,
);

/**
 * Returns true when a route contains authenticated page state and must not be
 * shared through a browser, proxy, or service-worker cache.
 */
export function isProtectedPagePathname(pathname: string): boolean {
  return (
    pathname !== PAINEL_MANIFEST_PATH &&
    PROTECTED_PAGE_PREFIXES.some(
      (prefix) => pathname === prefix || pathname.startsWith(`${prefix}/`),
    )
  );
}
