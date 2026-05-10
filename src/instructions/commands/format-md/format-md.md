---
description: Format markdown tables in a folder or file so columns are properly aligned
agent: telamon/telamon
---

Use the `format-md` tool with `path: $1` to align Markdown table columns.

If `$1` is a directory, all `.md` files are formatted recursively. If it is a file, that file is formatted in-place.
