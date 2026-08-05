# ADR-0004: Mermaid como contrato de arquitetura

- Status: Accepted
- Date: 2026-08-05

## Contexto

Configuração de build, middleware, cache e proxy formam uma fronteira que não
fica clara quando o leitor vê somente um Dockerfile.

## Decisão

Manter [`callgraph.md`](../../callgraph.md) com três vistas: build e runtime,
request boundary e configuração pública/server-only. Os nós usam nomes de
arquivo e conceitos pesquisáveis, não hosts ou IDs de provider.

## Consequências

- Uma mudança de middleware, cache ou variável deve atualizar o gráfico.
- O diagrama é documentação revisável, não topologia gerada.
- O leitor tem um caminho curto entre decisão, arquivo e gotcha.
