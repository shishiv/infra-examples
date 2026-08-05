# Arquitetura: ciclo de vida do Docker Swarm

Este módulo é um sistema operacional pequeno, não uma coleção de scripts
independentes. `staging/scripts/lib.sh` concentra política compartilhada; os
comandos são orquestradores finos que chamam helpers validados e preservam o
lock de ciclo de vida.

## Camadas

1. **Entradas:** `.env` genérico e manifesto de deploy imutável.
2. **Política:** parsing de configuração, validação do manifesto, imutabilidade
   de imagem, redaction, lock e reconciliação em `lib.sh`.
3. **Observação:** consultas Swarm, resolução DNS e health checks HTTPS. Preflight
   e drift report não mutam a rede edge.
4. **Mutação:** renderizar stack, puxar imagens, fazer deploy, escalar serviços,
   registrar TTL e arquivar o manifesto ativo.
5. **Proteção:** `paused-html`, rollback, timer de expiração, testes de falha e
   sandbox HTTP local.

## Entradas principais

- `start.sh`: caminho completo de validação, preflight, pull, deploy e smoke.
- `stop.sh`: escala a aplicação para zero e preserva a página pausada.
- `deploy.sh`: adiciona transação e histórico ao start.
- `reset-synthetic.sh`: remove apenas estado efêmero e preserva o ciclo atual,
  salvo quando `--activate` foi pedido.
- `rollback.sh`: verifica imagens históricas antes de delegar ao start.
- `check-expiry.sh`: entrada do timer systemd.

## Fronteiras

O registry recebe somente referências imutáveis; o `.env` não contém token; o
edge é observado, não administrado; e o caminho E2E local não cruza Docker,
SSH, systemd, DNS ou endpoint externo.
