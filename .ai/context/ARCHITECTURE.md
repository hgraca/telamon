# ARCHITECTURE

## Product

The way this project works is:

- A developer clones the repo into their local machine
- User runs `make up` to start the ADK 
  - Verifies installation of necessary tools, and installs them if necesary
  - starts postgres, MCPs, etc
- User runs `make init PROJ=path/to/project` to make a project use this ADK
  - creates a link from the project `.ai/context.adk` to this repository `src/context`
  - creates a link from the project `.opencode/skills/adk` to this repository `src/skills`
  - creates a link from the project `.ai/brain` to this repository `storage/<project-name>/brain`
- In the other project, the user starts the coding agent, ie `opencode` and it has access to the adk `context`, `skills` and `brain`

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
