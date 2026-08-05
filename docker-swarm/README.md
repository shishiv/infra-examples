# Docker Swarm: staging sintético com ciclo de vida limitado

Este é o exemplo mais completo do repositório. Ele mostra uma stack Docker
Swarm temporária, com imagens imutáveis, preflight somente leitura, pausa
segura, TTL e recuperação transacional. O material é um recorte derivado de
infraestrutura real, mas todos os hosts, redes, registries e serviços são
nomes de exemplo.

## O que está aqui

| Caminho | Demonstração |
| --- | --- |
| [`staging/stack.yml`](staging/stack.yml) | template com placeholders e rede edge externa |
| [`staging/deploy-manifest.yml`](staging/deploy-manifest.yml) | contrato de imagens imutáveis e dados sintéticos |
| [`staging/scripts/`](staging/scripts/) | validação, preflight, deploy, stop, rollback, TTL e reconciliação |
| [`staging/tests/`](staging/tests/) | testes mock-only de sucesso e falha |
| [`staging/paused-html/`](staging/paused-html/) | resposta explícita quando o app está pausado |
| [`staging/systemd/`](staging/systemd/) | timer de expiração |
| [`docs/`](docs/) | arquitetura, decisões e callgraph Mermaid |
| [`.env.example`](.env.example) | configuração genérica sem segredo |

## Verificação local

A suíte não precisa de Docker, rede, DNS ou credenciais:

```bash
( cd docker-swarm/staging/tests && ./run.sh )
./bash-ops/e2e-sandbox.sh
```

O sandbox serve uma cópia descartável do HTML em loopback e confirma que
nenhum estado de staging apareceu. Para validar scripts, use ShellCheck se ele
estiver instalado:

```bash
( cd docker-swarm && find staging -name '*.sh' -exec shellcheck -x {} + )
find bash-ops -name '*.sh' -exec shellcheck -x {} +
```

## Porquês

1. **Manifesto antes da stack:** a stack não contém imagens prontas. O
   manifesto precisa declarar uma referência por serviço, e cada referência
   deve ser digest ou tag `sha-<40 hex>`.
2. **Preflight sem mutação:** rede edge, serviço de entrada e DNS são
   observados antes do deploy. O exemplo não altera infraestrutura compartilhada
   para fazer o teste passar.
3. **Pausa como estado válido:** `paused-html` fica com uma réplica enquanto
   os serviços de aplicação vão para zero. O domínio tem uma resposta clara em
   vez de um erro genérico.
4. **TTL e reconciliação:** o timer encerra uma janela esquecida; falhas e
   interrupções restauram estado e TTL anteriores em vez de conceder vida nova.
5. **Dados sintéticos:** não existem volumes persistentes. `reset-synthetic.sh`
   recria somente estado efêmero e exige `--activate` para uma nova janela.
6. **CI sem deploy de app:** o workflow valida o módulo e publica somente o
   artefato pausado. Deploy de imagens de aplicação pertence ao módulo que as
   constrói.

## Gotchas

- `staging/stack.yml` só é implantável depois que `start.sh` injeta valores e
  imagens. Aplicar o template cru deixa `image: ""` e placeholders inválidos.
- `lib.sh` lê uma allow-list do `.env`; ele não faz `source` do arquivo. Não
  transforme o parser em execução arbitrária de shell.
- O serviço edge é externo à stack e precisa ser uma rede overlay Swarm já
  existente. O exemplo não cria nem reconfigura essa rede.
- `stop.sh` só limpa TTL e estado depois de confirmar que todos os serviços de
  aplicação foram escalados e que o placeholder ficou disponível.
- Os testes usam mocks e `fixture` como valor técnico. Eles não validam uma
  credencial real nem substituem um teste de contrato com o ambiente escolhido.
- `installer/` altera systemd e o host. É uma receita operacional, não parte
  da verificação local e não deve ser executada por cópia e cola sem revisão.

## Leitura guiada

Comece em [`docs/callgraphs.md`](docs/callgraphs.md), depois leia
[`docs/architecture.md`](docs/architecture.md) e os ADRs. O callgraph aponta
para os nomes reais de funções e arquivos para que uma busca simples encontre
a implementação.
