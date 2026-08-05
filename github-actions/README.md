# GitHub Actions: validação e publicação imutável

Esta pasta contém dois workflows como exemplos de automação: um portão de
lint/teste e uma publicação manual ou por mudança do artefato `paused-page`.
Eles ficam sob uma pasta de ferramenta para serem estudados; só ficam ativos
se alguém os mover para `.github/workflows/` na raiz do repositório.

## Arquivos

| Arquivo | Demonstração |
| --- | --- |
| [`workflows/ci.yml`](workflows/ci.yml) | ShellCheck, YAML parse e testes mock-only |
| [`workflows/publish-paused-html.yml`](workflows/publish-paused-html.yml) | build, push e validação de referências imutáveis |
| [`callgraph.md`](callgraph.md) | eventos, permissões e limites |

## Porquês

1. **CI e publicação separados:** o portão de qualidade roda em push e PR; a
   publicação é uma responsabilidade estreita, acionada manualmente ou por
   mudança no artefato pausado.
2. **Permissão mínima:** CI lê conteúdo; publicação escreve somente packages e
   usa `GITHUB_TOKEN` no passo de login.
3. **Referência imutável:** o job publica a tag `sha-<commit>` e captura o
   digest retornado pelo registry. Os dois passam pela mesma validação do
   manifesto.
4. **Concorrência explícita:** uma publicação por vez evita que pushes
   simultâneos confundam o digest apresentado no resumo.
5. **Sem deploy de aplicação:** o workflow não constrói nem inicia serviços de
   app; isso evita que um exemplo de CI vire um caminho acidental para um host.

## Gotchas

- Um workflow guardado em `github-actions/` não é descoberto pelo GitHub. O
  caminho de ativação e as permissões precisam ser revisados no PR que o mover.
- `GITHUB_TOKEN` é usado somente via secret context. Nunca substitua a
  expressão por um token colado no YAML ou em um log.
- `IMAGE_REPO` e o namespace são derivados do owner do repositório. Não fixe
  namespace de registry de uma organização privada neste exemplo.
- A validação do digest chama o contrato em `docker-swarm/staging/scripts`.
  Se a estrutura mudar, mude o workflow e o callgraph juntos.
- PRs de forks normalmente não recebem secrets de escrita. O job de publicação
  deve continuar ausente desse evento e depender de revisão explícita.
- O passo de instalação usa as ferramentas do runner público. Em uma política
  com runner próprio, reavalie a cadeia de suprimentos antes de trocar o
  executor.
