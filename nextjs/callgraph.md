# Callgraph: Next.js build e request boundary

```mermaid
flowchart TD
    source["Next app + workspace"] --> deps["Docker deps stage\npnpm install --frozen-lockfile"]
    deps --> build["Docker build stage\nshared package + next build"]
    build --> standalone[".next/standalone + static + public"]
    standalone --> runtime["runtime node\nusuário nextjs\nporta 3000"]

    browser["Browser"] --> middleware["middleware\nnonce, auth e CSRF"]
    middleware --> routes["App Router\npágina ou API"]
    routes --> policy["cache-boundary\nprivate/no-store"]
    routes --> proxy["server proxy\nAPI_URL"]
    proxy --> service["serviço configurado"]
    service --> proxy
    proxy --> routes
    routes --> browser

    env[".env.example"] --> public["NEXT_PUBLIC_*\nbuild-time"]
    env --> server["API_URL, DATABASE_URL, JWT_SECRET\nserver-only"]
    public --> routes
    server --> middleware
    server --> proxy
    analytics["analytics origin opcional"] --> rewrites["rewrites somente se\na origem for válida"]
    rewrites --> routes
```

## Leitura

- `Dockerfile` define a fronteira entre dependências de build e runtime.
- `next.config.ts` centraliza headers, redirects, rewrites e a saída standalone.
- `cache-boundary.ts` é a fonte de verdade para rotas privadas; não espalhe
  strings de `Cache-Control` por componentes.
- A API é uma dependência externa. Este exemplo mostra o ponto de entrada, mas
  não embute contrato, credencial ou host de um serviço vivo.
