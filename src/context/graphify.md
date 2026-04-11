## Graphify — Codebase Knowledge Graph

Graphify builds a knowledge graph of the codebase and maintains it automatically via git hooks after the first run.

### Self-initialize (once per project):
- Check: does `graphify-out/GRAPH_REPORT.md` exist?
- If NO: run `graphify .` — builds the graph (git hooks maintain it after)
- If YES: read `graphify-out/GRAPH_REPORT.md` before touching any architecture

### Retrieve:
- `graphify query "<question>"` — architecture, relationships, god nodes
