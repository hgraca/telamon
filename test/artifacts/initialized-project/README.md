# Artifact: initialized-project

This directory is a **reference specification** of what `make init PROJ=<path>` should
produce inside the target project directory (for an empty project named `test-proj`).

## Structure

```
.ai/
  adk.ini                  — written by init.sh (contains project_name)
  context/
    adk -> src/context     — symlink to ADK context docs
.opencode/
  skills/
    adk -> src/skills      — symlink to ADK skills
  codebase-index.json      — copied from src/install/codebase-index/codebase-index.json
opencode.jsonc -> storage/opencode.jsonc   — symlink (empty project path)
```

Note: `storage/<project-name>/brain/` files are created in the **ADK root**, not
inside the project directory, so they are not represented here.

The symlinks in this artifact use relative paths for portability; the real links
created by `init.sh` use absolute paths. The test suite verifies the *targets*,
not the path representation.
