# Mapa de fontes: orquestração Firstmate e Compounding

Este arquivo aponta para os donos da manutenção sem copiar scripts privados nem
transportar registros operacionais. Os enlaces do Firstmate apontam para o
upstream público MIT. O texto de Compounding é um resumo público-safe, porque os
dossiês de origem não são um repositório público de implementação.

## Firstmate upstream

| Fonte | O que estabelece | Uso nesta prova |
| --- | --- | --- |
| [`README.md`](https://github.com/kunchenguid/firstmate/blob/main/README.md) | Firstmate fala com um agente principal, cria crew visível, usa worktrees limpos e separa ship de scout. | Base para a abertura do problema e o limite de produto. |
| [`AGENTS.md: task lifecycle`](https://github.com/kunchenguid/firstmate/blob/main/AGENTS.md) | Intake, ship, scout, modo de entrega, isolamento, validação e teardown. | F01, F04 e F06. |
| [`AGENTS.md: project and knowledge management`](https://github.com/kunchenguid/firstmate/blob/main/AGENTS.md#6-project-and-knowledge-management) | Owner de conhecimento de projeto, fleet e tarefa. | F08. |
| [`AGENTS.md: supervision protocol`](https://github.com/kunchenguid/firstmate/blob/main/AGENTS.md#8-supervision-protocol) | Ordem de drain, reconciliação, ack e tratamento de stale, check e heartbeat. | F05 e F09. |
| [`AGENTS.md: hard rules`](https://github.com/kunchenguid/firstmate/blob/main/AGENTS.md#1-identity-and-prime-directives) | Captain, merge, descarte, isolamento e limites de autoridade. | F01, F06 e F09. |
| [`docs/architecture.md`](https://github.com/kunchenguid/firstmate/blob/main/docs/architecture.md) | Supervisão event-driven, backends, worktrees, secondmates, modos e memória de projeto. | F03, F04 e F05. |
| [`docs/watcher-continuity.md`](https://github.com/kunchenguid/firstmate/blob/main/docs/watcher-continuity.md) | Rearm, queue durável, recovery generation, fallback bounded e ausência de shell background. | F05. |
| [`docs/agent-control.md`](https://github.com/kunchenguid/firstmate/blob/main/docs/agent-control.md) | Plano de dados versus controle, verbs allowlisted, postconditions e falhas fail-closed. | F09. |
| [`bin/fm-spawn.sh`](https://github.com/kunchenguid/firstmate/blob/main/bin/fm-spawn.sh) | Spawn de ship, scout e secondmate, worktree real, base fresca e meta de tarefa. | F03 e F04. |
| [`bin/fm-watch.sh`](https://github.com/kunchenguid/firstmate/blob/main/bin/fm-watch.sh) | Classificação de wakes, fila durável e regra de não interromper automaticamente um worker. | F05. |
| [`bin/fm-supervise-daemon.sh`](https://github.com/kunchenguid/firstmate/blob/main/bin/fm-supervise-daemon.sh) | Sub-supervisor opcional, fail-safe-to-escalate e rechecagem de pausas declaradas. | F05. |
| [`bin/fm-pr-check.sh`](https://github.com/kunchenguid/firstmate/blob/main/bin/fm-pr-check.sh) | Registro validado de PR e armamento de poll. | F06. |
| [`bin/fm-pr-merge.sh`](https://github.com/kunchenguid/firstmate/blob/main/bin/fm-pr-merge.sh) | Registro de metadados antes do merge e URL GitHub canônica. | F06. |
| [`bin/fm-guard.sh`](https://github.com/kunchenguid/firstmate/blob/main/bin/fm-guard.sh) | Aviso de tangle, wakes pendentes e supervisão não saudável. | F05 e F06. |
| [`LICENSE`](https://github.com/kunchenguid/firstmate/blob/main/LICENSE) | Licença MIT e obrigação de preservar aviso de copyright em cópias permitidas. | Nenhum script é copiado; o link registra a atribuição. |

## Wayfinder e Ready

| Conceito público-safe | Fonte ou explicação | Limite |
| --- | --- | --- |
| Mapa | O mapa registra decisões, dependências e uma rota. | Não executa e não concede autoridade. |
| Folha Ready | A folha contém uma unidade executável, escopo e aceite. | Não substitui o captain quando a escolha muda estratégia ou risco. |
| Evidence update | Nova evidência pode atualizar claim ou decisão. | Não cria poder destrutivo nem amplia escopo por inferência. |

A distinção acima é uma paráfrase sanitizada do vocabulário de Wayfinder usado
na operação autorizada. Nenhum mapa privado, ticket, nome de projeto, ID,
sessão ou estado de frota foi publicado. A implementação desta prova usa apenas
o contrato sintético em [events.json](contracts/events.json).

## Compounding sanitizado

A camada planejada usa estes conceitos públicos, sem importar o conteúdo dos
dossiês privados:

| Conceito | Definição pública-safe | Dono pretendido |
| --- | --- | --- |
| Session Trace | Registro bruto do harness, usado como evidência e não como conhecimento servido. | Harness e retenção privada |
| Cut | Parte limitada do trace escolhida para possível reutilização. | Hook local, depois watcher |
| Proof | Ponte durável que permite verificar a fonte sem transportar o trace. | Engine de ingestão |
| Candidate | Proposta de Claim ou Skill antes de decisão de escrita. | Extractor e validação |
| Claim | O que permanece útil: Decision, Constraint, Failure ou Module. | Artefato canônico |
| Skill | Como executar: trigger, passos, riscos e verificação. | Artefato canônico |
| Write Decision | `reject`, `enrich`, `related new`, `supersede` ou `consolidate`. | Engine determinístico |
| Brief | Resposta limitada para uma frente, sem JSONL bruto. | Query e render derivado |
| Front | Dono de domínio que consome Brief e não recebe trace como fonte primária. | Frente persistente |
| Índice derivado | Busca reconstruível a partir dos artefatos canônicos. | Projeção descartável |

Esses conceitos são **arquitetura planejada**, não uma alegação de deployment.
O resumo público vive em [README.md](README.md#camada-compounding-planejada), o
ledger vive em [evidence.md](evidence.md#ledger-de-claims) e o fixture marca a
maturidade de cada evento. Os documentos de especificação privados não entram
como enlaces, caminhos ou anexos públicos.

## Fronteira de cópia

- Não há script Firstmate copiado neste caso.
- O diagrama é uma composição nova, não uma conversão de callgraph privado.
- Os nomes Firstmate são referências a arquivos públicos e respeitam a licença
  MIT indicada acima.
- Os conceitos Compounding foram reescritos para esta prova e não contêm
  sessões, caminhos absolutos, credenciais, endpoints, IDs ou nomes privados.
