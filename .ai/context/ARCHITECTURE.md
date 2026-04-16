# ARCHITECTURE

## Product

The way this project works is:

- A developer clones the repo into their local machine
- User runs `make up` to start Telamon 
  - Verifies installation of necessary tools, and installs them if necesary
  - starts postgres, MCPs, etc
- User runs `make init PROJ=path/to/project` to make a project use Telamon
  - Creates `.ai/telamon/memory` symlink → `storage/obsidian/<project-name>/` (vault with brain notes and bootstrap context)
  - Creates `.opencode/skills/telamon` symlink → `src/skills` (Telamon skills available to agents)
  - Creates `.opencode/plugins/telamon` symlink → `src/plugins` (Telamon plugins)
  - Creates `.ai/telamon/telamon.ini` with the project name
  - Creates `.ai/telamon/secrets` symlink → `storage/secrets/`
  - Creates `opencode.jsonc` symlink → `storage/opencode.jsonc` (or merges into existing)
  - Writes/merges `AGENTS.md` from `src/AGENTS.md`
  - Writes `.opencode/codebase-index.json`
  - Creates `graphify-out/` symlink and installs git hooks
  - Registers QMD collections and runs an initial semantic index
- In the other project, the user starts the coding agent, ie `opencode` and it has access to the Telamon `skills`, `plugins`, `memory`, and shared `opencode.jsonc` config

## Priority Order

1. Security
2. Extensibility
3. Feature growth
4. Determinism
5. Stability

## Project structure

```
- .ai/          # ai context
- bin/          # binaries and executable scripts
- scripts/      # shell scripts 
```
