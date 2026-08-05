# ADR-0002: fronteira de configuração

- Status: Accepted
- Date: 2026-08-05

## Contexto

Stack templates precisam de hosts, rede edge e imagens, mas valores operacionais
não podem virar defaults implícitos em código público.

## Decisão

`lib.sh` lê somente chaves allow-listed de `.env`; o manifesto fornece imagens
imutáveis; o token de registry entra apenas no ambiente do processo que precisa
dele. O template permanece com placeholders até a renderização validada.

## Consequências

- O exemplo pode ser revisado sem acesso a registry, DNS ou Docker.
- Uma execução real precisa fornecer os valores do próprio ambiente.
- Não se deve substituir o parser por `source .env`, pois isso transforma
  configuração em código executável.
