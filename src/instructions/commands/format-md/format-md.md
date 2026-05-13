---
description: Format markdown tables in a folder or file so columns are properly aligned
agent: telamon/telamon
---

Invoke `format-md` tool with `path: $1` to align all markdown tables in given path.

If `$1` is directory, tool formats all `.md` files recursively. If file, tool formats that file in-place.