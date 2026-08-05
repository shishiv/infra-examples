# infra-examples

Exemplos derivados de infraestrutura real, sanitizados e organizados **por
ferramenta**, não por projeto.

A pergunta que este repositório responde é: "como esta ferramenta foi usada
com segurança e quais decisões preciso entender antes de repetir o padrão?"
Por isso cada pasta reúne código, callgraph Mermaid, porquês e gotchas no
mesmo lugar, enquanto um mesmo material de origem pode aparecer em mais de uma
ferramenta.

## Estrutura

| Pasta | O que demonstra |
| --- | --- |
| [`docker-swarm/`](docker-swarm/) | Stack sintética com manifestos imutáveis, preflight read-only, pausa, TTL e rollback |
| [`github-actions/`](github-actions/) | CI de shell/YAML e publicação isolada de uma imagem com tag e digest imutáveis |
| [`nextjs/`](nextjs/) | Build standalone, runtime sem root, configuração pública/server-only e cache seguro |
| [`drizzle/`](drizzle/) | Migração PostgreSQL, snapshot, journal, relações e tipos inferidos |
| [`playwright/`](playwright/) | E2E por contrato: rotas públicas, fronteira de auth e visual determinístico |
| [`bash-ops/`](bash-ops/) | Forced-command SSH, sandbox loopback e bootstrap histórico de runner |

## Como ler

1. Abra o `README.md` da ferramenta.
2. Leia o `callgraph.md` e siga os nomes até os arquivos de implementação.
3. Leia os blocos **Porquês** e **Gotchas** antes de adaptar qualquer trecho.
4. Rode somente os comandos locais documentados. Exemplos que exigem host,
   registry, banco ou credencial são descritos, não executados pelo CI deste
   repositório.

## Origem e limites

O conteúdo é derivado de infraestrutura privada e foi reduzido para uma
superfície pública: sem histórico dos repositórios de origem, sem `.git`, sem
credencial, token, chave privada, host interno, domínio privado, IP operacional,
dado de cliente ou estado de runtime.

Os valores restantes são placeholders, `localhost` ou domínios reservados para
documentação. Um exemplo sanitizado explica uma decisão, mas não é uma
configuração pronta para produção. Substitua contratos externos, revisão de
segurança, legal copy e observabilidade antes de qualquer uso real.

## Segurança pública

A revisão da superfície pública está documentada em [`SECURITY.md`](SECURITY.md).
Qualquer dúvida sobre um arquivo ou valor deve interromper a publicação desse
arquivo, não ser resolvida por suposição.
