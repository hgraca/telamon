---
description: Format markdown tables in a folder or file so columns are properly aligned
agent: telamon/telamon
---

Run `.opencode/commands/telamon/format-md/format-md.py $1` to format all markdown tables in the given path.

If `$1` is a directory, format all `.md` files recursively. If it is a file, format that file in-place.
