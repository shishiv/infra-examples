# Evidências: orquestração Firstmate e Compounding

Esta prova usa documentação pública do Firstmate, uma síntese sanitizada do
limite de Compounding autorizada pelo captain e um contrato sintético local.
Nenhuma linha abaixo é recibo de uma frota privada, de uma sessão ou de um
deploy.

## Legenda de status

| Rótulo | Significado nesta prova |
| --- | --- |
| **Decisão** | A documentação ou o código de manutenção descreve uma escolha de arquitetura. |
| **Contrato sintético** | A validação local usa somente fixture e regras sanitizadas. |
| **Arquitetura planejada** | A fonte define um contrato futuro, mas não há aceitação publicada de implementação. |
| **Observação datada** | Recibo de ambiente real com escopo e data. Não usado para afirmar estado atual. |
| **Não afirmado** | A prova declara a fronteira que não cobre. |

## Ledger de claims

| ID | Claim público | Rótulo | Fonte pública ou sanitizada | Método de leitura | Não prova |
| --- | --- | --- | --- | --- | --- |
| F01 | Intenção aceita e evidência devem preceder a execução; o ship carrega modo de entrega explícito. | **Decisão** | [AGENTS.md: task lifecycle](https://github.com/kunchenguid/firstmate/blob/main/AGENTS.md) · [arquitetura](https://github.com/kunchenguid/firstmate/blob/main/docs/architecture.md) | Comparar intake, brief, spawn e modo de entrega. | Que uma intenção privada ou um resultado externo foi aceito. |
| F02 | O mapa Wayfinder resolve decisões e uma folha Ready concreta é a unidade roteável; o mapa não executa trabalho. | **Decisão** | [distinção sanitizada no README](README.md#mapa-não-é-execução) · [mapa e brief planejados](README.md#camada-compounding-planejada) | Conferir a separação entre mapa, folha, Claim e Skill no fixture e no texto. | Que um Wayfinder público específico ou qualquer ticket privado esteja autorizado. |
| F03 | Escopo encaminha o trabalho para uma frente persistente ou para o coordenador principal; uma frente vazia fica ociosa. | **Decisão** | [arquitetura: optional secondmates](https://github.com/kunchenguid/firstmate/blob/main/docs/architecture.md#optional-secondmates) · [secondmate provisioning](https://github.com/kunchenguid/firstmate/blob/main/.agents/skills/secondmate-provisioning/SKILL.md) | Ler o contrato de scope, home persistente, idle-by-default e recuperação local. | Que uma frente privada, um home ou uma rota remota exista neste repositório. |
| F04 | Ship e scout recebem instruções limitadas e cópias de trabalho isoladas; scout produz relatório e não PR. | **Decisão** | [README upstream](https://github.com/kunchenguid/firstmate#what-it-is) · [fm-spawn.sh](https://github.com/kunchenguid/firstmate/blob/main/bin/fm-spawn.sh) · [task lifecycle](https://github.com/kunchenguid/firstmate/blob/main/AGENTS.md) | Seguir a asserção de worktree, a diferença entre ship/scout e os modos de entrega. | Que uma tarefa específica foi executada, ou que um worktree privado é recuperável. |
| F05 | Wakes duráveis acordam supervisão, enquanto a leitura de estado atual é separada da última linha de status. | **Decisão** | [arquitetura: event-driven supervision](https://github.com/kunchenguid/firstmate/blob/main/docs/architecture.md#event-driven-supervision) · [fm-watch.sh](https://github.com/kunchenguid/firstmate/blob/main/bin/fm-watch.sh) · [watcher continuity](https://github.com/kunchenguid/firstmate/blob/main/docs/watcher-continuity.md) | Ler queue, current-state reconciliation, ack após handling e rearm bounded. | Que qualquer worker privado esteja vivo ou que um wake tenha sido entregue em produção. |
| F06 | O caminho de entrega valida e registra a referência antes de pousar; o worker não aprova a própria entrega e teardown preserva trabalho não landed. | **Decisão** | [AGENTS.md: PR ready, landing, teardown](https://github.com/kunchenguid/firstmate/blob/main/AGENTS.md#pr-ready-landing-and-teardown) · [fm-pr-check.sh](https://github.com/kunchenguid/firstmate/blob/main/bin/fm-pr-check.sh) · [fm-pr-merge.sh](https://github.com/kunchenguid/firstmate/blob/main/bin/fm-pr-merge.sh) · [fm-guard.sh](https://github.com/kunchenguid/firstmate/blob/main/bin/fm-guard.sh) | Seguir registro de PR, gate do modo, autoridade de merge e recusa de teardown inseguro. | Que um PR real esteja verde, merged ou autorizado pelo captain. |
| F07 | Depois da entrega, o mesmo worker executa captura terminal; a captura não invalida o resultado e pode terminar em `no-new-learning`. | **Decisão** | [captura terminal sanitizada](README.md#captura-terminal-e-owners) · [rota de owners no README](README.md#captura-terminal-e-owners) | Comparar o ordenamento entrega -> captura e a lista de owners. | Que esta prova tenha criado uma skill, escrito `/knowledge` ou alterado um projeto. |
| F08 | Workflow reutilizável, lição entre projetos, verdade do projeto e evidência da tarefa seguem owners diferentes, sem cópia duplicada. | **Decisão** | [README: owners](README.md#captura-terminal-e-owners) · [AGENTS.md: project and knowledge management](https://github.com/kunchenguid/firstmate/blob/main/AGENTS.md#6-project-and-knowledge-management) | Conferir a tabela de roteamento e a regra de owner único. | Que qualquer candidato tenha passado por adjudicação, publicação ou revisão privada. |
| F09 | Evidência pode atualizar claims e decisões, mas não concede estratégia, expansão de escopo ou autoridade destrutiva ao agente. | **Decisão** | [AGENTS.md: hard rules](https://github.com/kunchenguid/firstmate/blob/main/AGENTS.md#1-identity-and-prime-directives) · procedimento de autoridade · [agent control](https://github.com/kunchenguid/firstmate/blob/main/docs/agent-control.md) | Ler os limites de captain, allowlist de lifecycle verbs e decisão explícita. | Que o captain tenha aprovado qualquer ação concreta fora desta prova. |
| F10 | Cut, watcher externo, Claim tipada, decisão de escrita, proveniência, índice derivado e Brief limitado são a próxima camada, não comportamento atual. | **Arquitetura planejada** | [vocabulário sanitizado de Compounding](README.md#camada-compounding-planejada) · [contrato planejado no fixture](contracts/events.json) · [mapa de fonte](source-map.md#compounding-sanitizado) | Conferir que todos os eventos futuros têm `maturity: planned` e aparecem em uma seção separada. | Que extração automática, reconciliação de Claims, adapters cross-harness ou publicação de Brief já estejam implantados. |

## Contrato sintético

O fixture [events.json](contracts/events.json) contém nomes, autoridades e
maturidade artificiais. O validador [validate-events.sh](contracts/validate-events.sh)
confere que:

- o ciclo atual inclui Ready, isolamento, supervisão, entrega e captura;
- o ciclo planejado permanece marcado como `planned`;
- `Claim` e `Skill` mantêm a distinção declarativa versus procedural;
- as cinco disposições de escrita planejadas aparecem sem virar uma ação atual;
- o captain mantém strategy, expansão, ações destrutivas ou irreversíveis,
  segurança, publicação privada e revisão visual;
- os owners de aprendizado incluem skill, `/knowledge`, projeto, tarefa e
  `no-new-learning`;
- a fixture não contém caminhos absolutos, credenciais ou nomes privados.

Execução permitida:

```bash
./proofs/firstmate-orchestration/contracts/validate-events.sh
```

**Rótulo:** contrato sintético. O comando verifica a narrativa e a fronteira
de publicação. Ele não executa Firstmate, não abre uma sessão e não simula uma
frota.

## Não-claims explícitas

Esta prova não afirma:

1. disponibilidade, desempenho, escala ou taxa de sucesso de uma frota;
2. existência de um front, secondmate, ship, scout, worktree, PR ou endpoint
   privado;
3. acesso a dados de sessão, estado de runtime, host, conta, chave, token ou
   registro de cliente;
4. que o Firstmate define estratégia, que Wayfinder executa ou que `learn-skill`
   sempre cria uma skill;
5. que o watcher externo e a camada de Claims tipadas já foram implementados;
6. que índice derivado é fonte canônica ou que Brief substitui revisão humana;
7. que uma execução local do validador prova um contrato externo.

## Regra de publicação

Qualquer claim adicional precisa receber um rótulo, um enlace ou fonte
sanitizada revisável e uma frase de limite. Fonte privada sem autorização de
sanitização não entra nesta prova. Os caminhos de manutenção apontados em
[source-map.md](source-map.md) são referências, não cópias de scripts.
