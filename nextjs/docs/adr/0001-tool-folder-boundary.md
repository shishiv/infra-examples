# ADR-0001: fronteira da pasta de ferramenta

- Status: Accepted
- Date: 2026-08-05

## Contexto

A organização do portfólio é por ferramenta. O build Next.js, seus limites de
configuração e os recortes de integração devem ser encontrados em `nextjs/`,
sem obrigar o leitor a navegar a história de um projeto.

## Decisão

Tratar esta pasta como um exemplo derivado e portável. Ela não é um app
standalone, não controla visibilidade de repositório e não traz o histórico do
app de origem. O README da raiz continua dono do mapa entre ferramentas.

## Consequências

- `Dockerfile`, `next.config.ts`, `.env.example` e o callgraph viajam juntos.
- O build real deve fornecer o app e o workspace que o Dockerfile espera.
- Código que não demonstra Next.js, cache ou configuração deve ir para outra
  pasta de ferramenta, não ser escondido aqui.
