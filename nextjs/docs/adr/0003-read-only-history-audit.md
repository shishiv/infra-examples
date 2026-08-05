# ADR-0003: histórico não faz parte do recorte

- Status: Accepted
- Date: 2026-08-05

## Contexto

Sanitizar arquivos atuais não limpa valores que possam existir em commits
antigos. Copiar `.git` para um repositório público ampliaria essa superfície.

## Decisão

Consolidar somente conteúdo de trabalho sanitizado. Não copiar `.git`, refs,
objetos, logs de scanner ou histórico do app de origem. A auditoria histórica
fica como evidência privada do processo e não como conteúdo necessário para
entender o padrão Next.js.

## Consequências

- Este diretório não promete que o histórico da fonte é público ou limpo.
- Uma futura publicação deve repetir a varredura sobre o histórico do destino.
- Nenhum `filter-repo`, BFG, reset ou force-push faz parte desta consolidação.
