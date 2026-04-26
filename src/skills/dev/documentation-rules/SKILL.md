---
name: telamon.documentation_rules
description: "Repository documentation conventions: file organization, README TOC, docs/ structure, splitting large files, image storage. Use when writing documentation, creating new docs files, or updating the README."
---

# Repository Documentation

## When to Apply

- Writing or organizing repository documentation
- Creating new documentation files
- Updating the README.md table of contents
- Deciding how to structure long documents

## Rules

- Text docs should be organized in `.md` files
- All docs should be organized under a `docs/` folder on the root
- The repo README.md must have a TOC pointing to each text doc file under `docs/`
- Whenever new docs files are created, the README.md TOC must be updated to include them
- The TOC must use indentation and enumerated sections to reflect the nesting levels of the documentation sections it points to
- Each subject should be self-contained in one `.md` file
- When an `.md` file exceeds 200 lines and contains several sections:
  - Create a folder with the name of that `.md` file
  - Break up the file into several files inside that folder, each new file containing one section of the initial file
- Images used in documentation, should be stored under `docs/imgs/`
- **After writing or editing any `.md` file**, run `python3 scripts/format-md.py <file-or-directory>` to align markdown table columns. Run this on every `.md` file touched before committing.
