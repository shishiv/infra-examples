import type { NextConfig } from "next";
import withSerwistInit from "@serwist/next";
import {
  PAINEL_MANIFEST_CACHE_CONTROL,
  PAINEL_MANIFEST_PATH,
  PRIVATE_NO_STORE_CACHE_CONTROL,
  PROTECTED_PAGE_ROUTE_SOURCES,
} from "./cache-boundary";

const analyticsHost = process.env.NEXT_PUBLIC_ANALYTICS_HOST?.replace(/\/$/, "");
const analyticsOrigin = (() => {
  if (!analyticsHost) return "";
  try {
    return new URL(analyticsHost).origin;
  } catch {
    return "";
  }
})();

export const nextConfig: NextConfig = {
  env: {
    NEXT_PUBLIC_BASE_URL: process.env.NEXT_PUBLIC_BASE_URL || "http://localhost:3000",
  },
  images: {
    remotePatterns: [
      {
        protocol: "http",
        hostname: "localhost",
        port: "",
        pathname: "/**",
      },
      {
        protocol: "https",
        hostname: "localhost",
        port: "",
        pathname: "/**",
      },
    ],
    formats: ["image/webp", "image/avif"],
    minimumCacheTTL: 86400,
    deviceSizes: [640, 750, 828, 1080, 1200, 1920, 2048, 3840],
    imageSizes: [16, 32, 48, 64, 96, 128, 256, 384],
    dangerouslyAllowSVG: true,
    contentSecurityPolicy: "default-src 'self'; script-src 'none'; sandbox;",
  },
  // Performance optimizations - temporarily disabled for debugging
  experimental: {
    optimizeCss: true,
    optimizeServerReact: true,
    // serverSourceMaps: false,
  },

  // Prevent Turbopack from bundling server-only auth implementation details
  // that pull in optional SQLite adapters incompatible with the installed version.
  serverExternalPackages: ["better-auth", "@better-auth/kysely-adapter"],

  // Enable typed routes (moved from experimental)
  typedRoutes: true,

  // Turbopack is the default bundler in Next.js 16+.
  // Empty config silences the webpack→turbopack migration warning from @serwist/next.
  turbopack: {},

  compiler: {
    removeConsole:
      process.env.NODE_ENV === "production"
        ? {
            exclude: ["error"],
          }
        : false,
    reactRemoveProperties: process.env.NODE_ENV === "production",
  },
  // Enable compression and optimization
  compress: true,
  poweredByHeader: false,
  reactStrictMode: true,

  // Standalone output for Docker deployment
  output: "standalone",
  outputFileTracingRoot: __dirname,

  // Security and caching headers
  async headers() {
    return [
      {
        source: "/(.*)",
        headers: [
          {
            key: "X-Frame-Options",
            value: "DENY",
          },
          {
            key: "X-Content-Type-Options",
            value: "nosniff",
          },
          {
            key: "Referrer-Policy",
            value: "origin-when-cross-origin",
          },
          {
            key: "Content-Security-Policy",
            // Static fallback CSP for requests not handled by middleware.
            // The nonce-based CSP is set dynamically in middleware.ts.
            // This is a conservative fallback that blocks inline scripts.
            value:
              process.env.NODE_ENV === "development"
                ? "default-src 'self'; script-src 'self' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self'; connect-src 'self' ws: wss:; frame-ancestors 'none'; base-uri 'self'; form-action 'self'"
                : `default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self'; connect-src 'self'${analyticsOrigin ? ` ${analyticsOrigin}` : ""}; frame-ancestors 'none'; base-uri 'self'; form-action 'self'`,
          },
          {
            key: "Strict-Transport-Security",
            value: "max-age=31536000; includeSubDomains",
          },
        ],
      },
      {
        source: "/api/admin/live",
        headers: [
          {
            key: "X-Accel-Buffering",
            value: "no",
          },
        ],
      },
      {
        source: "/api/(.*)",
        headers: [
          {
            key: "Cache-Control",
            value: PRIVATE_NO_STORE_CACHE_CONTROL,
          },
        ],
      },
      ...PROTECTED_PAGE_ROUTE_SOURCES.map((source) => ({
        source,
        headers: [
          {
            key: "Cache-Control",
            value: PRIVATE_NO_STORE_CACHE_CONTROL,
          },
        ],
      })),
      {
        source: PAINEL_MANIFEST_PATH,
        headers: [
          {
            key: "Cache-Control",
            value: PAINEL_MANIFEST_CACHE_CONTROL,
          },
        ],
      },
      {
        source: "/_next/static/(.*)",
        headers: [
          {
            key: "Cache-Control",
            value: "public, max-age=31536000, immutable",
          },
        ],
      },
      {
        source: "/sw.js",
        headers: [
          {
            key: "Cache-Control",
            value: "no-cache, no-store, must-revalidate",
          },
        ],
      },
    ];
  },

  // Redirects for better SEO
  async redirects() {
    return [
      {
        source: "/tools",
        destination: "/ferramentas",
        permanent: true,
      },
      {
        source: "/dashboard/tools",
        destination: "/dashboard/ferramentas",
        permanent: true,
      },
      // Landing page restructure redirects (16-08)
      {
        source: "/servicos",
        destination: "/automacoes",
        permanent: true,
      },
      {
        source: "/precos",
        destination: "/#interesse",
        permanent: true,
      },
      {
        source: "/casos",
        destination: "/",
        permanent: true,
      },
      {
        source: "/produtos/messaging",
        destination: "/automacoes",
        permanent: true,
      },
      {
        source: "/produtos/automacoes-whatsapp",
        destination: "/automacoes",
        permanent: true,
      },
      {
        source: "/produtos/diagnostico",
        destination: "/automacoes",
        permanent: true,
      },
      {
        source: "/produtos/sites",
        destination: "/presenca-online",
        permanent: true,
      },
      {
        source: "/agendar",
        destination: "/contato",
        permanent: true,
      },
    ];
  },
  async rewrites() {
    if (!analyticsHost) return [];

    return [
      {
        source: "/ingest/static/:path*",
        destination: `${analyticsHost}/static/:path*`,
      },
      {
        source: "/ingest/:path*",
        destination: `${analyticsHost}/:path*`,
      },
    ];
  },
  // Note: eslint config moved to eslint.config.mjs (Next.js 16+)
};

const withSerwist = withSerwistInit({
  swSrc: "src/app/sw.ts",
  swDest: "public/sw.js",
  disable: process.env.NODE_ENV === "development",
});

export default withSerwist(nextConfig);
