# infra-examples

Provas operacionais sanitizadas para uma pergunta prática: como um sistema passa
de diagnóstico, decisão, validação, implantação e operação sem esconder o que
não foi provado.

**Não afirmado:** esta superfície pública não contém histórico de origem,
credenciais, hosts internos, estado de runtime, dados de cliente ou receita de
deploy. Leia [SECURITY.md](SECURITY.md) antes de reutilizar qualquer padrão.

## Comece por um problema

| Situação | O que a prova mostra | Estado da evidência | Comece aqui |
| --- | --- | --- | --- |
| Uma janela de staging não pode ficar ativa por esquecimento nem deixar o domínio sem resposta quando a aplicação para. | Manifestos imutáveis, preflight sem mutação, pausa explícita, TTL, recuperação e testes locais. | **Contrato sintético** e **contrato loopback**. Não afirma Docker, DNS, registry ou credenciais reais. | [Janela de staging limitada e recuperação explícita](proofs/bounded-staging-recovery/) |

## Como ler uma prova

Cada prova usa rótulos explícitos. Eles evitam que um teste local pareça uma
observação de produção.

| Rótulo | Significado |
| --- | --- |
| **Decisão** | Uma escolha documentada no código, ADR ou contrato. |
| **Contrato sintético** | Uma validação local com mocks, fixtures ou dados sintéticos. |
| **Contrato loopback** | Uma validação HTTP local, sem infraestrutura externa. |
| **Observação datada** | Um recibo de ambiente real com escopo e data. Não prova o estado atual. |
| **Não afirmado** | Um limite que a prova não cobre. |

Abra o caso primeiro. Depois siga os links para código, testes, ADRs e mapas de
manutenção. Cada afirmação operacional do caso aponta para uma fonte pública ou
se declara como limite.

## Biblioteca de implementação

Os módulos abaixo continuam organizados por ferramenta. Eles são fontes de
manutenção e de evidência para as provas, não uma promessa de configuração
pronta para produção.

| Módulo | O que demonstra | Estado da evidência | Fonte de manutenção |
| --- | --- | --- | --- |
| `docker-swarm/` | Stack sintética com manifestos imutáveis, preflight read-only, pausa, TTL e rollback. | **Decisão** e **contratos sintéticos**. | [README](docker-swarm/README.md) · [callgraphs](docker-swarm/docs/callgraphs.md) |
| `github-actions/` | CI de shell/YAML e publicação isolada de uma imagem com tag e digest imutáveis. | **Decisão**. | [README](github-actions/README.md) · [callgraph](github-actions/callgraph.md) |
| `nextjs/` | Build standalone, runtime sem root, configuração pública/server-only e cache seguro. | **Decisão**. | [README](nextjs/README.md) · [callgraph](nextjs/callgraph.md) |
| `drizzle/` | Migração PostgreSQL, snapshot, journal, relações e tipos inferidos. | **Decisão**. | [README](drizzle/README.md) · [callgraph](drizzle/callgraph.md) |
| `playwright/` | E2E por contrato: rotas públicas, fronteira de auth e visual determinístico. | **Contrato sintético**. | [README](playwright/README.md) · [callgraph](playwright/callgraph.md) |
| `bash-ops/` | Forced-command SSH, sandbox loopback e bootstrap histórico de runner. | **Decisão** e **contrato loopback**. | [README](bash-ops/README.md) · [callgraph](bash-ops/callgraph.md) |

## Origem e limites

**Não afirmado:** o conteúdo foi reduzido para uma superfície pública. Os
valores restantes são placeholders, `localhost` ou domínios reservados para
documentação. Um exemplo sanitizado explica uma decisão, mas não é uma
configuração pronta para produção.

Substitua contratos externos, revisão de segurança, legal copy e observabilidade
antes de qualquer uso real. Se um arquivo ou valor não puder ser explicado sem
contexto privado, ele fica fora deste repositório.

## Segurança pública

A política e a revisão da superfície pública estão em [SECURITY.md](SECURITY.md).
Qualquer dúvida sobre um arquivo ou valor deve interromper a publicação desse
arquivo, não ser resolvida por suposição.
