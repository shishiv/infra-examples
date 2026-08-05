# Bash Ops: scripts operacionais com limites claros

Esta pasta reúne três scripts de operação que não pertencem a um projeto:
chave SSH com forced command, sandbox E2E local e bootstrap de runner
self-hosted. Eles demonstram como um script operacional deve declarar o limite
que pode atravessar e deixar o restante para configuração explícita.

## Arquivos

| Arquivo | Demonstração |
| --- | --- |
| [`deploy-key-helper.sh`](deploy-key-helper.sh) | chave Ed25519 com comando forçado e opções SSH restritivas |
| [`e2e-sandbox.sh`](e2e-sandbox.sh) | servidor HTTP descartável preso a loopback |
| [`runner-bootstrap.sh`](runner-bootstrap.sh) | helper histórico, opt-in, para instalar runner de CI |
| [`callgraph.md`](callgraph.md) | relações e limites dos scripts |

O sandbox usa o artefato pausado de [`docker-swarm/`](../docker-swarm/) e
confere os workflows em [`github-actions/`](../github-actions/). Assim, o
mesmo material de origem alimenta várias pastas de ferramenta sem criar uma
pasta com nome de projeto.

## Porquês

1. **Forced command:** a chave de deploy não recebe um shell arbitrário; o
   servidor SSH só aceita o protocolo de deploy versionado.
2. **Loopback-only:** o teste local serve o HTML real em um diretório temporário
   e comprova `127.0.0.1`, sem Docker, SSH, DNS, systemd ou endpoint externo.
3. **Runner separado:** o bootstrap fica fora dos workflows ativos porque
   runner self-hosted aumenta o risco operacional e exige revisão do host.
4. **Configuração por ambiente:** caminho de instalação, usuário e comentário
   são valores editáveis; nenhuma chave privada é versionada.

## Gotchas

- `deploy-key-helper.sh` imprime a chave privada recém-criada. Execute-o apenas
  em um terminal controlado e entregue a saída por um canal de segredo; nunca
  redirecione essa saída para este repositório ou para logs de CI.
- O helper de runner recebe o token como argumento de processo. Em uma operação
  real, prefira o mecanismo de credencial recomendado pelo provedor e não deixe
  o valor em histórico de shell ou lista de processos.
- O runner bootstrap instala pacotes e cria usuário no host. Ele é uma receita
  histórica, não é chamado por nenhum workflow e não deve ser executado em um
  host sem revisão.
- O sandbox depende dos caminhos consolidados. Se um artefato mudar de pasta,
  atualize o script e seu callgraph no mesmo commit.
- Nenhum script desta pasta acessa uma infraestrutura viva por padrão.

## Execução segura

A única verificação sem credencial ou privilégio é:

```bash
./bash-ops/e2e-sandbox.sh
```

Os outros dois scripts são documentação operacional e não fazem parte do
caminho de validação do pull request.
