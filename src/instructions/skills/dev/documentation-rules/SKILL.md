---
name: telamon.documentation_rules
description: "Repository documentation conventions: file organization, README TOC, docs/ structure, splitting large files, image storage. Use when writing documentation, creating new docs files, or updating README."
---

# Repository Documentation

## When to Apply

- Writing or organizing repository documentation
- Creating new documentation files
- Updating README.md table of contents
- Deciding how to structure long documents

## Rules

- Text docs should be organized in `.md` files
- All docs should be organized under `docs/` folder on root
- Repo README.md must have TOC pointing to each text doc file under `docs/`
- Whenever new docs files created, README.md TOC must be updated to include them
- TOC must use indentation and enumerated sections to reflect nesting levels of documentation sections it points to
- Each subject should be self-contained in one `.md` file
- When `.md` file exceeds 200 lines and contains several sections:
  - Create folder with name of that `.md` file
  - Break up file into several files inside that folder, each new file containing one section of initial file
- Images used in documentation, should be stored under `docs/imgs/`
