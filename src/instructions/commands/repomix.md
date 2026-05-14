---
description: Package directories with repomix --compress and output markdown to stdout
agent: telamon/telamon
---

Invoke `repomix-report` tool with `dir: [$*]` to package one or more directories with repomix --compress. Always outputs markdown to stdout. Positional args are treated as directories to pack. Supports --no-compress, --include-patterns, --ignore-patterns flags.