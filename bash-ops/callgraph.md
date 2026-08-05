# Callgraph: Bash Ops

```mermaid
flowchart TD
    operator["operador"] --> key["deploy-key-helper.sh"]
    key --> sshgen["ssh-keygen Ed25519"]
    key --> forced["authorized_keys\nforced command + no forwarding"]
    forced --> remote["staging/scripts/remote-deploy.sh"]

    ci["CI local"] --> sandbox["e2e-sandbox.sh"]
    sandbox --> workflowCheck["workflows sem deploy ativo"]
    sandbox --> copy["cópia do paused-page\nem diretório temporário"]
    copy --> loopback["HTTP server 127.0.0.1"]
    loopback --> assertion["status 200 + marcador paused"]

    hostOperator["operador do host"] --> bootstrap["runner-bootstrap.sh\nopt-in histórico"]
    bootstrap --> packages["apt + docker + jq"]
    bootstrap --> runner["GitHub Actions runner"]
    runner --> service["serviço do host"]
```

## Limites

- A chave restringe o comando, mas não substitui revisão do script remoto.
- O sandbox prova apenas o artefato HTTP local; ele não prova o Swarm, registry
  ou DNS.
- O bootstrap instala software em um host e, por isso, não é uma etapa de CI
  automática.
