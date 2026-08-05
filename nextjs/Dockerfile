# syntax=docker/dockerfile:1

FROM node:26-slim AS base
# Node 26 no longer bundles Corepack. Install a pinned release explicitly.
RUN npm install -g corepack@0.35.0 && \
    corepack enable && \
    corepack prepare pnpm@9.15.4 --activate

FROM base AS deps
WORKDIR /app
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY packages-shared/package.json ./packages-shared/
RUN --mount=type=cache,id=pnpm-store-portfolio-example,target=/pnpm-store \
    pnpm install --frozen-lockfile --store-dir /pnpm-store

FROM base AS build
WORKDIR /app
COPY --from=deps /app/ .
COPY . .
ARG NEXT_PUBLIC_SITE_NAME=Portfolio Example
ARG NEXT_PUBLIC_BASE_URL=http://localhost:3000
ARG NEXT_PUBLIC_API_URL=http://localhost:4000
ARG NEXT_PUBLIC_POSTHOG_KEY
ARG NEXT_PUBLIC_ANALYTICS_HOST
ARG NEXT_PUBLIC_VAPID_PUBLIC_KEY
ENV NEXT_PUBLIC_SITE_NAME=$NEXT_PUBLIC_SITE_NAME
ENV NEXT_PUBLIC_BASE_URL=$NEXT_PUBLIC_BASE_URL
ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL
ENV NEXT_PUBLIC_POSTHOG_KEY=$NEXT_PUBLIC_POSTHOG_KEY
ENV NEXT_PUBLIC_ANALYTICS_HOST=$NEXT_PUBLIC_ANALYTICS_HOST
ENV NEXT_PUBLIC_VAPID_PUBLIC_KEY=$NEXT_PUBLIC_VAPID_PUBLIC_KEY
ENV JWT_SECRET="build-only-placeholder-not-used-at-runtime"
RUN cd packages-shared && pnpm build && cd ..
RUN pnpm build

FROM node:26-slim AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      curl \
      postgresql-client \
    && rm -rf /var/lib/apt/lists/*
RUN groupadd --system --gid 1001 nextjs && \
    useradd --system --uid 1001 --gid nextjs --no-create-home nextjs
COPY --from=build --chown=nextjs:nextjs /app/.next/standalone ./
COPY --from=build --chown=nextjs:nextjs /app/public ./public
COPY --from=build --chown=nextjs:nextjs /app/.next/static ./.next/static
USER nextjs
EXPOSE 3000
CMD ["node", "server.js"]
