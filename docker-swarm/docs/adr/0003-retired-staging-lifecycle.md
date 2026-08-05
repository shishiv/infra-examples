# ADR-0003: ciclo de vida de staging aposentado

- Status: Accepted
- Date: 2026-08-05

## Contexto

Uma janela de staging sintético não deve permanecer ativa por esquecimento, e
uma falha no deploy não pode registrar um estado que nunca foi confirmado.

## Decisão

O exemplo usa TTL padrão de quatro horas, timer de expiração, lock de operação,
manifestos históricos e reconciliação de falhas. `paused-html` permanece
acessível quando os serviços de aplicação estão parados. Preflight e drift são
somente leitura.

O workflow de deploy da aplicação fica aposentado. A automação de publicação,
quando ativada, publica apenas a imagem da página pausada.

## Consequências

- `start`, `stop`, `reset` e `rollback` precisam preservar estado e TTL juntos.
- A página pausada tem custo pequeno, mas reduz a ambiguidade de uma parada.
- O módulo não deve ser tratado como um deploy pronto para um ambiente real.
