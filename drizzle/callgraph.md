# Callgraph: Drizzle schema e migração

```mermaid
flowchart LR
    model["schema.ts\npgSchema + pgTable + relations"] --> kit["Drizzle Kit\ngenerate"]
    kit --> sql["0000_*.sql\nordem de DDL"]
    kit --> snapshot["meta/0000_snapshot.json"]
    sql --> journal["meta/_journal.json\nordem aplicada"]
    journal --> postgres["PostgreSQL\nschema example"]
    sql --> postgres
    postgres --> app["queries do app"]
    model --> types["tipos inferidos\nselect/insert"]
    types --> app
```

## Contratos que o gráfico torna visíveis

- O SQL é o caminho de escrita no banco; o TypeScript não substitui a
  migração.
- O snapshot e o journal são metadata gerada, não uma segunda fonte manual de
  verdade.
- A aplicação só deve receber a conexão por configuração server-only.
- O schema público mostra estrutura, não dados, credenciais ou endpoints vivos.
