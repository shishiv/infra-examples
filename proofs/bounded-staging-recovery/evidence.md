# Evidências: janela de staging limitada e recuperação explícita

Esta prova usa apenas fontes públicas deste repositório. Nenhuma linha abaixo é
um recibo de produção, acesso a host, DNS, registry, segredo ou conta.

## Legenda de status

| Rótulo | O que significa nesta prova |
| --- | --- |
| **Decisão** | O código ou ADR público descreve uma escolha de arquitetura. |
| **Contrato sintético** | Uma suíte local usa mocks ou fixtures. |
| **Contrato loopback** | Um processo local prova HTTP apenas em `127.0.0.1`. |
| **Não afirmado** | A prova não cobre a fronteira indicada. |

## Ledger de claims

| Claim | Rótulo | Fonte pública | Método ou forma de leitura | Não prova |
| --- | --- | --- | --- | --- |
| O manifesto deve declarar referências imutáveis e o template não recebe imagens prontas. | **Decisão** | [README do módulo](../../docker-swarm/README.md#porquês) · [validador](../../docker-swarm/staging/scripts/lib.sh) | Ler a regra e seguir a validação de referências. | Que qualquer imagem exista em um registry real. |
| O preflight observa edge, Swarm e DNS antes do deploy e não altera a edge compartilhada. | **Decisão** | [arquitetura](../../docker-swarm/docs/architecture.md#camadas) · [README](../../docker-swarm/README.md#gotchas) | Ler a separação entre observação e mutação. | Que um edge, DNS ou host externo está acessível agora. |
| A pausa conserva a página pausada enquanto serviços de aplicação vão a zero. | **Decisão** | [README](../../docker-swarm/README.md#porquês) · [stack](../../docker-swarm/staging/stack.yml) | Comparar a descrição com as réplicas e labels da stack. | Que uma rota externa respondeu durante esta leitura. |
| Falha e interrupção devem restaurar o ciclo e TTL anteriores. | **Decisão** | [reconciliação](../../docker-swarm/staging/scripts/lib.sh) · [start](../../docker-swarm/staging/scripts/start.sh) · [rollback](../../docker-swarm/staging/scripts/rollback.sh) | Seguir captura de estado anterior, restauração de TTL e ramificações de recuperação. | Que uma falha ocorreu em ambiente externo. |
| A suíte local cobre contratos de sucesso e falha sem Docker, rede, DNS ou credenciais. | **Contrato sintético** | [runner](../../docker-swarm/staging/tests/run.sh) · [README](../../docker-swarm/README.md#verificação-local) | Executar `( cd docker-swarm/staging/tests && ./run.sh )`. | Docker Swarm, DNS, registry, host ou credencial real. |
| O artefato pausado responde localmente e o sandbox não cria estado de staging. | **Contrato loopback** | [sandbox](../../bash-ops/e2e-sandbox.sh) · [HTML pausado](../../docker-swarm/staging/paused-html/index.html) | Executar `./bash-ops/e2e-sandbox.sh`. | Deploy, SSH, systemd, DNS, registry ou endpoint externo. |
| O conteúdo publicado exclui credenciais, hosts internos, IPs operacionais, dados de cliente e estado de runtime. | **Não afirmado** | [SECURITY.md](../../SECURITY.md) | Revisar a fronteira de publicação antes de adicionar fonte. | Que a configuração de origem seja pública ou pronta para reutilização. |

## Reexecução permitida

Os dois comandos abaixo são os únicos caminhos de validação local citados pela
prova. Eles não pedem segredo e não devem ser reinterpretados como instrução de
deploy.

```sh
( cd docker-swarm/staging/tests && ./run.sh )
./bash-ops/e2e-sandbox.sh
```

## Regra de publicação

Se uma futura edição acrescentar uma afirmação operacional, ela precisa ganhar:

1. um rótulo desta página;
2. um link público direto para código, teste ou ADR; e
3. uma frase sobre a fronteira que ainda não foi provada.

Se a fonte exigir contexto privado para ser explicada, ela não entra nesta
prova. A regra segue [SECURITY.md](../../SECURITY.md).
