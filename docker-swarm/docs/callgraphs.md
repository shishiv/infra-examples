# Callgraphs Mermaid

## Ciclo principal

```mermaid
flowchart TD
    operator["Operador ou deploy.sh"] --> start["start.sh <manifest>"]
    timer["systemd expiry timer"] --> expiry["check-expiry.sh"]
    expiry --> active{"is_staging_active?"}
    active -->|não| skip["log e sai"]
    active -->|sim| ttl["staging_ttl_remaining"]
    ttl --> valid{"TTL válido?"}
    valid -->|sim| skip
    valid -->|não| stopExpired["stop.sh"]

    start --> validate["validate_manifest"]
    validate --> preflight["preflight.sh\nobservação edge, Swarm e DNS"]
    preflight --> login["registry_login"]
    login --> pull["docker pull\nreferências imutáveis"]
    pull --> render["render_stack_from_manifest"]
    render --> deployStack["docker stack deploy"]
    deployStack --> scale["escala serviços de aplicação"]
    scale --> smoke["smoke-test.sh"]
    smoke --> record["grava TTL, estado e manifesto"]

    start -. falha ou interrupção .-> reconcile["reconcile_prior_lifecycle"]
    reconcile --> restoreTTL["restore_prior_ttl"]
    reconcile --> restoreStart["start.sh com manifesto anterior"]
    reconcile --> restoreStop["stop.sh se pausado ou expirado"]

    operator --> stop["stop.sh"]
    stop --> zero["escala aplicação para zero"]
    zero --> paused["paused-html fica em uma réplica"]
    paused --> clear["limpa TTL e registra paused"]

    operator --> rollback["rollback.sh [1|2|3]"]
    rollback --> verify["verify_manifest_images_exist"]
    verify --> prior["start.sh com histórico"]
    prior --> consume["consume_manifest_history"]
```

## Fronteiras externas

```mermaid
flowchart LR
    env[".env"] --> parse["read_operator_env"]
    manifest["deploy-manifest.yml"] --> validate["validate_manifest"]
    parse --> policy["lib.sh\nconfiguração e política"]
    validate --> policy
    policy --> render["render_stack_from_manifest"]
    render --> template["stack.yml placeholders"]
    render --> swarm["Docker Swarm stack"]

    policy --> registry["container registry"]
    registry --> pull["pull + inspect imutáveis"]
    policy --> edge["rede edge externa"]
    edge --> preflight["preflight read-only"]
    policy --> dns["resolver DNS"]
    dns --> preflight
    policy --> https["health HTTPS"]
    https --> smoke["smoke-test"]

    systemd["systemd timer"] --> expiry["check-expiry"]
    ci["GitHub Actions"] --> shellcheck["ShellCheck"]
    ci --> tests["staging/tests/run.sh"]
    tests --> mocks["Docker, DNS e HTTP mocks"]
    sandbox["bash-ops/e2e-sandbox.sh"] --> pausedArtifact["paused-html/index.html"]
    sandbox --> loopback["127.0.0.1 only"]
```

## Extensão

```mermaid
flowchart TD
    service["Novo serviço"] --> lists["STAGING_SERVICES + STAGING_APP_SERVICES"]
    lists --> manifestEntry["images.<service>"]
    manifestEntry --> validator["validate_manifest"]
    lists --> stackService["stack.yml service"]
    stackService --> health["limites + /health"]
    lists --> lifecycle["start, stop, smoke, drift e reset"]
    lifecycle --> tests["testes de falha"]
    tests --> docs["README, ADR e callgraph"]
```

Uma extensão que aparece só no template não é deployável; ela precisa cruzar
todos os contratos relevantes e ter teste e documentação.
