# Mapa de fontes: janela de staging limitada e recuperação explícita

Este mapa liga a leitura pública curta aos arquivos que continuam donos da
implementação. Ele não duplica scripts nem substitui os Mermaid de manutenção.

## Decisões e ciclo de vida

| Fonte | O que estabelece |
| --- | --- |
| [README do Docker Swarm](../../docker-swarm/README.md) | Escopo sintético, porquês, gotchas e comandos de verificação local. |
| [Arquitetura do ciclo de vida](../../docker-swarm/docs/architecture.md) | Camadas, entradas, política, observação, mutação e proteção. |
| [ADR: escopo e sanitização](../../docker-swarm/docs/adr/0001-tool-scope-and-sanitization.md) | Por que o módulo não carrega identidade, histórico ou configuração de origem. |
| [ADR: fronteira de configuração](../../docker-swarm/docs/adr/0002-configuration-boundary.md) | Por que `.env` é permitido só como configuração allow-listed e o manifesto contém imagens imutáveis. |
| [ADR: ciclo de vida aposentado](../../docker-swarm/docs/adr/0003-retired-staging-lifecycle.md) | TTL, pausa, recuperação e o limite de publicação do workflow. |
| [Biblioteca do ciclo de vida](../../docker-swarm/staging/scripts/lib.sh) | Parsing, validação, lock, TTL, histórico e reconciliação de estado anterior. |
| [Start](../../docker-swarm/staging/scripts/start.sh) | Preflight, pull, renderização, deploy, scale, smoke e gravação de estado. |
| [Stop](../../docker-swarm/staging/scripts/stop.sh) | Escala de aplicação para zero e confirmação da página pausada. |
| [Rollback](../../docker-swarm/staging/scripts/rollback.sh) | Restauração de manifestos imutáveis retidos e reconciliação após falha. |

## Mapas de manutenção

| Fonte | Uso |
| --- | --- |
| [Callgraphs Mermaid do Swarm](../../docker-swarm/docs/callgraphs.md) | Mapas completos de ciclo, fronteiras externas e extensão. A prova usa uma vista reduzida; este arquivo continua sendo a fonte para manutenção. |
| [Callgraph do GitHub Actions](../../github-actions/callgraph.md) | Mostra a fronteira entre validação, publicação imutável e ausência de `docker stack deploy`. |
| [Callgraph de Bash Ops](../../bash-ops/callgraph.md) | Mostra a fronteira entre helper de chave, sandbox loopback e bootstrap de host. |

## Contratos de validação

| Fonte | O que a validação cobre |
| --- | --- |
| [Runner da suíte mock-only](../../docker-swarm/staging/tests/run.sh) | Descobre e executa contratos shell de staging sem ativar infraestrutura real. |
| [Fixtures e testes do Swarm](../../docker-swarm/staging/tests/) | Exercitam os caminhos de manifest, preflight, TTL, rollback, pausa, reset e redaction. |
| [Sandbox E2E loopback](../../bash-ops/e2e-sandbox.sh) | Copia o artefato pausado, serve somente em loopback e verifica que staging ficou desativado. |
| [Artefato HTML pausado](../../docker-swarm/staging/paused-html/index.html) | É a resposta explícita usada pelo contrato loopback. |

## Fronteira de publicação

| Fonte | Regra |
| --- | --- |
| [SECURITY.md](../../SECURITY.md) | Nenhuma prova pública inclui segredo, host interno, IP operacional, cliente, runtime ou arquivo de origem não explicável sem contexto privado. |
| [Índice de provas](../../README.md) | Define rótulos de evidência e deixa a biblioteca por ferramenta como fonte de manutenção. |
