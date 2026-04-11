<!-- ogham-managed append block — do not remove this marker -->

---

## Memory Setup for: PROJECT_NAME

### Every session:
```
ogham use OGHAM_PROFILE
ogham hooks recall
```
Then read `PROJECT_NAME/brain/NorthStar.md` from the Obsidian vault.

### Self-initialize once (check and build if missing):
- **Graphify**: if `graphify-out/GRAPH_REPORT.md` missing → run `graphify .`
- **Codebase index**: if `.opencode/codebase-index/` missing → run `index_codebase` tool
- **cass**: run `cass index` once to index past sessions

### Save to BOTH Ogham AND Obsidian brain/:
- Decision: `ogham store "decision: ..."` + add to `brain/KeyDecisions.md`
- Pattern: `ogham store "pattern: ..."` + add to `brain/Patterns.md`
- Bug/gotcha: `ogham store "bug/gotcha: ..."` + add to `brain/Gotchas.md`
- End of significant work: `ogham hooks inscribe`

### Wrap-up (on "wrap up" / "wrapping up"):
1. Promote learnings → brain/ notes
2. Archive work/active/ notes
3. `ogham hooks inscribe`
4. Verify new vault notes have `[[wikilinks]]`
