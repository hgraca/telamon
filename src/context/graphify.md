## Graphify — Codebase Knowledge Graph

Graphify builds a knowledge graph of the codebase and maintains it automatically via git hooks after the first run.

### Self-initialize (once per project):
- Check: does `graphify-out/GRAPH_REPORT.md` exist?
- If NO: run `graphify .` — builds the graph (git hooks maintain it after)
- If YES: read `graphify-out/GRAPH_REPORT.md` before touching any architecture

### Retrieve:
- `graphify query "<question>"` — architecture, relationships, god nodes

### Rules:
- Before answering architecture or codebase questions, read `graphify-out/GRAPH_REPORT.md` for god nodes and community structure
- If `graphify-out/wiki/index.md` exists, navigate it instead of reading raw files
- After modifying code files in this session, run `python3 -c "from graphify.watch import _rebuild_code; from pathlib import Path; _rebuild_code(Path('.'))"` to keep the graph current
