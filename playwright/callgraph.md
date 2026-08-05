# Callgraph: Playwright E2E

```mermaid
flowchart TD
    config["playwright.config.ts\nBASE_URL + webServer"] --> runner["Playwright runner"]
    runner --> public["public-routes.spec.ts"]
    runner --> auth["auth-boundary.spec.ts"]
    runner --> visual["visual-regression.spec.ts"]

    public --> appPublic["Next.js public routes"]
    auth --> cookies["fixture cookies\nsynthetic JWT"]
    cookies --> protected["protected route"]
    protected --> apiMock["page.route API fixture"]
    visual --> freeze["freezeMotion"]
    freeze --> screenshot["stable screenshot baseline"]

    runner --> evidence["trace, screenshot, HTML/JSON report"]
    appPublic --> evidence
    apiMock --> evidence
    screenshot --> evidence
```

## Fronteiras

- O navegador é o observador; não há acesso a credenciais reais.
- O mock da API fica explicitamente separado do teste de rota pública.
- A evidência de falha é um artefato local do runner, não um upload para um
  serviço externo.
