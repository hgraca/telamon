---
layout: page
title: Graphify
description: Auto-built structural knowledge graph of the codebase.
nav_section: docs
---

[Graphify](https://github.com/safishamsi/graphify) — Codebase Knowledge Graph

Builds a structural knowledge graph of the codebase. Identifies god nodes, architectural layers, call relationships, and module boundaries.

- **Auto-build**: `telamon init` builds the graph. Existing graphs are skipped.
- **Scheduled updates**: platform-native timer runs `graphify . --update` every 30 minutes
- **MCP server**: tools include `query_graph`, `get_node`, `get_neighbors`, `get_community`, `god_nodes`, `graph_stats`, `shortest_path`
- **Context injection**: opencode plugin injects god nodes and communities into the first tool call of each session

Particularly valuable for large legacy codebases where nobody has a complete mental model.

**Manage scheduled updates:**
- Linux: `systemctl --user status graphify-update-<project-name>.timer`
- macOS: `launchctl list | grep graphify-update-<project-name>`

**Priority:** Tier 2

### MCP server details

The Graphify MCP server is registered during install and starts on-demand with each opencode session. It requires:

- `storage/secrets/graphify-python` — path to graphify's Python interpreter
- `storage/secrets/telamon-root` — path to the Telamon root directory
- `.opencode/graphify-serve.sh` — symlink in each project (created by `telamon init`)

The wrapper checks for `graph.json` before starting. If the graph hasn't been built yet, it exits gracefully.
