# Playwright: E2E por contrato

Este exemplo transforma uma suíte E2E em contratos observáveis: páginas públicas,
fronteira de autenticação e regressão visual determinística. Os testes são
recortes portáveis e assumem um app Next.js com as rotas descritas no próprio
arquivo; não apontam para um ambiente publicado por padrão.

## Arquivos

| Arquivo | O que cobre |
| --- | --- |
| [`playwright.config.ts`](playwright.config.ts) | base URL local, retries, trace e servidor de desenvolvimento |
| [`e2e/public-routes.spec.ts`](e2e/public-routes.spec.ts) | status HTTP e metadados canônicos |
| [`e2e/auth-boundary.spec.ts`](e2e/auth-boundary.spec.ts) | redirecionamento anônimo e navegação por papel |
| [`e2e/visual-regression.spec.ts`](e2e/visual-regression.spec.ts) | overflow e screenshot com animação congelada |
| [`callgraph.md`](callgraph.md) | ciclo de execução e limites de dados |

## Porquês

1. **A base é explícita:** `BASE_URL` é opcional e o default é localhost. Um
   teste não deve acessar produção só porque uma variável ficou configurada.
2. **A autenticação usa fixtures locais:** o teste verifica a navegação e o
   contrato de UI sem exigir conta real. O token do fixture é deliberadamente
   inválido fora do ambiente de teste.
3. **Mocks ficam na borda:** `page.route` substitui a API para testar a reação
   da UI, não para alegar que o contrato HTTP do serviço está coberto.
4. **Visual é determinístico:** transições, animações e caret são desligados
   antes do snapshot; o limite de diferença fica visível no arquivo.
5. **Falha deixa evidência:** trace no retry, screenshot em falha e relatório
   HTML tornam o diagnóstico reproduzível.

## Gotchas

- Um mock verde não prova que o backend aceita o payload. Mantenha testes de
  contrato real separados quando a API for parte do risco.
- `test.only` é proibido em CI por `forbidOnly`; não desative esse portão para
  acelerar uma execução local.
- Retries podem esconder flakiness. Investigue o trace em vez de aumentar o
  número de tentativas indefinidamente.
- Snapshots pertencem ao mesmo contrato de viewport, fonte e locale. Atualize
  baselines de forma revisada, nunca para silenciar uma diferença visual.
- O teste de autenticação cria cookies e IDs sintéticos. Nunca troque-os por
  cookies, e-mails, telefones ou tokens de uma conta real.

## Execução

A partir de um app que tenha as rotas do exemplo:

```bash
BASE_URL=http://localhost:3000 pnpm exec playwright test playwright/e2e
```

O repositório consolidado não sobe um app sozinho. A linha acima é um contrato
de integração para o app que consumir este recorte.
