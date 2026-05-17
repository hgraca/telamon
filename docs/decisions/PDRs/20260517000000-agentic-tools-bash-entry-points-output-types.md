---
date: 2026-05-17
keywords: ["telamon", "agentic-tool", "bash", "cli", "output-format"]
see: []
---

## Agentic tools bash scripts entry points and output types

Every agentic tool under `src/instructions/tools/` must ship a companion bash script so the user can invoke the tool directly from the CLI without going through the agent. Both the bash script and the underlying JS tool accept `--markdown` and `--json` flags to select output format; when neither flag is given, the bash script defaults to markdown (human-readable) while the JS tool defaults to JSON (structured, easier for agents to consume). The `--format <value>` long-form flag is also accepted as an alias. This dual-default rule keeps CLI usage ergonomic for humans while keeping agent consumption efficient by default.
