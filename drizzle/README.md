# Drizzle: migração e contrato de schema

Este exemplo mostra uma evolução de schema PostgreSQL com Drizzle: a
migração SQL, o snapshot gerado e o schema TypeScript que descreve relações e
tipos. Os nomes são genéricos e não há linhas de dados.

## Arquivos

| Arquivo | Papel |
| --- | --- |
| [`schema.ts`](schema.ts) | tabelas, enum, relações e tipos inferidos |
| [`0000_useful_mystique.sql`](0000_useful_mystique.sql) | migração inicial ordenada por dependência |
| [`meta/0000_snapshot.json`](meta/0000_snapshot.json) | snapshot gerado pelo Drizzle Kit |
| [`meta/_journal.json`](meta/_journal.json) | ordem e metadata das migrações |
| [`callgraph.md`](callgraph.md) | caminho de geração, aplicação e leitura |

## Porquês

1. **Schema PostgreSQL nomeado:** as tabelas ficam em `example`, separando o
   contrato do exemplo de tabelas que possam existir no mesmo banco.
2. **Foreign keys na migração:** tabelas base vêm antes das tabelas dependentes;
   a tabela de junção usa uma chave primária composta para impedir duplicidade.
3. **Tipos no código e no banco:** `schema.ts` mantém a fonte de tipos para o
   app, enquanto o SQL é a operação que o banco realmente executa.
4. **Snapshot e journal versionados:** o histórico de migrações pode ser
   reconstruído sem depender do estado atual do banco.
5. **`tsvector` explícito:** o custom type deixa a busca textual visível no
   contrato sem fingir que o ORM possui uma abstração nativa para esse tipo.

## Gotchas

- Não edite uma migração já aplicada para "corrigir" o passado. Crie a próxima
  migração e deixe o journal registrar a nova ordem.
- O snapshot é artefato gerado. Atualize-o pelo Drizzle Kit, não por edição
  manual, e revise o diff antes de aceitar uma mudança de schema.
- `schema.ts` e o SQL precisam concordar sobre nomes, nulabilidade e relações.
  Um só deles mudar deixa o app e o banco com contratos diferentes.
- O exemplo contém campos como e-mail e telefone apenas como tipos de coluna,
  nunca valores reais. Não use este schema como licença para versionar dados.
- A conexão é um contrato externo. O repositório público não traz
  `DATABASE_URL`, dumps, seeds ou um host de banco.

## Callgraph resumido

Veja [`callgraph.md`](callgraph.md) para o fluxo completo. A validação útil é
comparar o SQL gerado com uma base PostgreSQL descartável e depois rodar o
schema TypeScript contra o mesmo contrato.
