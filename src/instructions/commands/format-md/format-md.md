---
description: Format markdown tables in a folder or file so columns are properly aligned
agent: telamon/telamon
---

Invoke the `format-md` tool with `path: $1` to align all markdown tables in the given path.

If `$1` is a directory, the tool formats all `.md` files recursively. If it is a file, the tool formats that file in-place.
