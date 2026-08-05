# Project agent memory

This file is the project's committed home for project-intrinsic agent knowledge: build, test, release, architecture, and sharp-edge notes that should travel with the code.

- Add durable project-specific notes here as they are discovered through real work.

## Maintaining this file

Keep this file for knowledge useful to almost every future agent session in this project.
Do not repeat what the codebase already shows; point to the authoritative file or command instead.
Prefer rewriting or pruning existing entries over appending new ones.
When updating this file, preserve this bar for all agents and keep entries concise.

## Project shape

The public portfolio is intentionally organized by tool, not source project. The
root `README.md` is the index; each tool directory owns its README and
`callgraph.md`. The local checks are documented in the tool READMEs, with the
full mock-only Swarm suite at `docker-swarm/staging/tests/run.sh` and the
loopback sandbox at `bash-ops/e2e-sandbox.sh`.
