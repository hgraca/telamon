# BOOTSTRAP

NEVER read nor modify any file with "no-vcs" in the name, unless explicitly directed to read it.
NEVER read nor modify any folder with "no-vcs" in the name, unless explicitly directed to read it.

## MANDATORY START SEQUENCE

Read all files matching `.ai/context*/*.md` (if they exist) to gather context and agent instructions

If any rule cannot be satisfied:
STOP and report conflict.

Do not proceed without loading these files into context.

## graphify

This project has a graphify knowledge graph at graphify-out/.

Rules:
- Before answering architecture or codebase questions, read graphify-out/GRAPH_REPORT.md for god nodes and community structure
- If graphify-out/wiki/index.md exists, navigate it instead of reading raw files
- After modifying code files in this session, run `python3 -c "from graphify.watch import _rebuild_code; from pathlib import Path; _rebuild_code(Path('.'))"` to keep the graph current
