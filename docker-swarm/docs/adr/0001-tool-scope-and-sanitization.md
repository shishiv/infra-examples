# ADR-0001: escopo por ferramenta e sanitização

- Status: Accepted
- Date: 2026-08-05

## Contexto

O portfólio consolidado é organizado por ferramenta. Este módulo demonstra
Docker Swarm e não deve carregar identidade, histórico ou configuração de um
projeto de origem.

## Decisão

Manter o exemplo sob `docker-swarm/`, com nomes de host, registry, serviço e
instalação genéricos. O conteúdo pode ser movido como unidade dentro da pasta
da ferramenta, mas não possui um repositório, remote ou visibilidade próprios.

## Consequências

- O módulo não contém `.git`, histórico, estado runtime ou credencial.
- `.env.example` documenta a interface, mas `.env` nunca é versionado.
- A estrutura interna preserva os caminhos necessários para os scripts e
  testes serem lidos juntos.
