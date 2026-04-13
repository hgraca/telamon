## Codebase Index — Semantic Code Search

The codebase index enables semantic search over the project's source code using Ollama embeddings. It is built once and maintained automatically by a file watcher.

### Self-initialize (once per project):
- Check: does `.opencode/codebase-index/` exist?
- If NO: run the `index_codebase` tool — file watcher maintains it after
- If YES: index is ready — semantic code search available

### Retrieve:
- Ask naturally in plain English — e.g. "find the authentication logic"
- Results are ranked by semantic similarity to the query
