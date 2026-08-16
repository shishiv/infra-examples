# Orquestração Firstmate: dono, prova e aprendizado

> **Pergunta:** como coordenar muitas tarefas paralelas sem deixar que o chat seja o único lugar onde vivem o dono, a evidência e o aprendizado?

[← Índice de provas](../../README.md)

## Em uma frase

**Decisão:** a operação separa intenção aceita, mapa de decisão, folha executável,
trabalho isolado, supervisão, entrega e captura terminal. Cada etapa tem um dono
visível e uma falha deixa evidência durável em vez de depender da memória do chat.

**Estado da evidência:** o ciclo Firstmate e a captura terminal são **decisões e
comportamentos atuais** da arquitetura de manutenção. A camada automática de
Compounding é **arquitetura planejada**. O contrato local desta prova é sintético.
Ele não é uma instalação de Firstmate nem um produto novo.

## O problema operacional

Quando várias tarefas avançam em paralelo, o chat mistura intenção, execução,
estado atual e aprendizado. Um reinício pode esconder uma decisão aberta. Uma
folha de planejamento pode parecer executável sem ter critério de aceite. Um
worker pode terminar sem deixar claro quem revisa, quem entrega e o que deve ser
reutilizado.

Esta prova publica a separação que evita esses erros:

1. intenção aceita e evidência informam um mapa Wayfinder;
2. o mapa resolve decisões e roteia uma folha **Ready** concreta;
3. uma frente persistente ou o coordenador principal recebe a folha;
4. um ship ou scout recebe instruções limitadas e uma cópia isolada;
5. wakes esparsos acordam a supervisão, enquanto o estado atual é reconciliado
   separadamente;
6. o caminho de entrega valida, pousa ou preserva o trabalho sem autoaprovação;
7. o mesmo worker executa a captura terminal com `learn-skill`;
8. cada aprendizado segue para um único dono, ou recebe `no-new-learning`.

### Mapa não é execução

Um mapa Wayfinder é um artefato de decisão e rota. Ele torna o caminho claro;
não executa trabalho. A folha **Ready** é uma unidade concreta, com escopo,
fonte e critério suficientes para o coordenador dispatchar sem inventar
estratégia.

Essa distinção evita transformar uma lista de desejos em autoridade autônoma.
Evidência nova pode atualizar uma claim ou uma decisão do mapa, mas não concede
ao worker poder para definir estratégia, ampliar escopo ou executar uma ação
destrutiva.

## O ciclo operacional atual

[Abrir o diagrama HTML acessível do ciclo Firstmate e seus caminhos de bloqueio](visuals/orchestration.html#current-loop).

Leia as caixas como contratos, não como uma topologia privada:

| Etapa | Contrato público | Dono da decisão ou evidência |
| --- | --- | --- |
| Intenção | O captain aceita o resultado, a evidência necessária e o limite de publicação. | Captain |
| Mapa | Wayfinder ordena decisões e deixa explícitas as folhas prontas e as dependências. | Mapa e captain quando a escolha é material |
| Folha Ready | Uma folha executável informa tarefa, escopo, fonte, aceite e saída esperada. | Coordenador, sem mudar estratégia |
| Rota | A frente persistente cuida do domínio; o coordenador principal cuida do que não pertence a uma frente. | Escopo registrado |
| Ship ou scout | Ship entrega mudança pelo modo selecionado; scout entrega relatório e não abre PR. | Worker dentro do brief |
| Isolamento | A tarefa usa worktree descartável ou home isolada, distinta do checkout principal. | `fm-spawn.sh` e backend |
| Supervisão | Wakes duráveis acordam somente o que precisa de atenção; estado atual não vem da última linha do status. | Watcher, estado persistente e firstmate |
| Entrega | O caminho selecionado valida, registra o PR quando aplicável e só pousa com o gate correto. | Worker, automação e captain conforme o modo |
| Aprendizado | O mesmo worker faz a captura terminal depois de entregar o resultado. | Worker, com um único owner |

### Falhas que ficam visíveis

- **Folha não Ready:** a rota retorna ao mapa ou a uma decisão do captain. Não
  há execução por inferência.
- **Isolamento não comprovado:** o spawn recusa antes de criar o endpoint. O
  checkout principal não recebe a mudança.
- **Worker parado ou ambíguo:** a supervisão preserva o wake e pede inspeção. Ela
  não interrompe, reinicia ou descarta o worker automaticamente.
- **Validação com falha:** o caminho registra a falha e segue o gate; o worker
  não edita a própria execução para aprová-la.
- **Trabalho não pousado:** teardown recusa a devolução do worktree. Trabalho
  sujo ou não landed continua preservado.
- **Sem aprendizado reutilizável:** a captura registra `no-new-learning`. Ela
  não cria uma skill só para preencher um arquivo.

## Limites de autoridade humana

O captain mantém a decisão sobre:

- estratégia e destino;
- expansão de escopo;
- ação destrutiva ou irreversível;
- escolha sensível de segurança;
- publicação de material privado;
- revisão visual exigida pelo produto.

Firstmate pode classificar, rotear, supervisionar e aplicar gates já definidos.
A autonomia de um worker não vira autoridade de produto. Um PR pronto para
revisão não é um PR autorizado para merge.

## Captura terminal e owners

A captura acontece somente depois que Firstmate recebeu o resultado do worker.
O mesmo worker carrega `learn-skill`, procura owners existentes e devolve um
recibo. O resultado já entregue permanece final; a captura não reabre nem atrasa
a entrega.

A rota de um candidato é única:

- workflow de agente reutilizável: skill com trigger, método, riscos e
  verificação;
- padrão ou incidente entre projetos: `/knowledge`, com recibos e escopo;
- verdade intrínseca de um projeto: owner do projeto, como `AGENTS.md` ou runbook;
- evidência que só serve à tarefa: relatório da tarefa;
- nenhum aprendizado novo: `no-new-learning` explícito.

Uma execução terminal não cria sempre uma skill. O teste é reutilização,
trigger distinto e owner não duplicado.

## Camada Compounding planejada

> **Arquitetura planejada:** esta seção descreve contratos futuros. Ela não
> afirma que extração automática, reconciliação de Claims ou Briefs derivados
> já estejam implantados.

[Abrir a vista HTML acessível da camada Compounding planejada](visuals/orchestration.html#planned-compounding).

A camada planejada move a extração para fora da sessão interativa:

1. um hook marca um **Cut** pequeno, não transporta o Session Trace inteiro;
2. um watcher externo lê o Cut, valida o envelope e propõe um Candidate;
3. o Candidate distingue **Claim**, o que permanece verdadeiro, de **Skill**,
   como executar um procedimento;
4. o engine aplica uma decisão explícita: `reject`, `enrich`, `related new`,
   `supersede` ou `consolidate`;
5. a cadeia de proveniência liga fonte, Cut, extração, decisão e versão canônica;
6. Claims e Skills canônicos são a fonte humana; busca, grafo e índice são
   projeções derivadas e reconstruíveis;
7. uma Brief limitada chega à frente, nunca o JSONL bruto.

O primeiro corte planejado permanece estreito: um marcador local, um watcher,
Claims tipadas, decisões determinísticas, proveniência, rebuild derivado e
Brief limitado. Adaptadores de outros harnesses, ingestão em massa e retrieval
avançado ficam depois de evidência de aceitação.

## O que esta prova não afirma

- Não publica registros da frota, sessões, hosts, endpoints, credenciais ou
  nomes de projetos privados.
- Não afirma que Wayfinder executa trabalho ou que um agente define estratégia.
- Não afirma que uma captura terminal sempre produz uma skill.
- Não afirma que o watcher externo, Claims tipadas, adapters cross-harness ou
  Briefs derivados já estejam em produção.
- Não transforma o contrato sintético em observação de produção.
- Não transforma Firstmate em um novo software de orquestração neste repositório.

## Verificação local

O contrato sintético verifica eventos atuais, eventos planejados, autoridade
humana, rotas de aprendizado e a ausência de caminhos privados:

```bash
./proofs/firstmate-orchestration/contracts/validate-events.sh
```

Ele não simula uma frota. Para o ledger completo de claims, rótulos e limites,
leia [evidence.md](evidence.md). Para os arquivos de manutenção e a fronteira
de licença, leia [source-map.md](source-map.md).

## Lição transferível

A unidade segura de autonomia não é o prompt nem o número de abas. É uma folha
concreta, em uma cópia isolada, com estado atual reconciliável, entrega protegida
e um dono explícito para o aprendizado que sobreviver.
