## cass — Agent Session History Search

cass indexes past agent session conversations and makes them searchable. Run once per machine to build the index; it updates automatically.

### Self-initialize (once per machine):
- Run `cass index` to index all past agent sessions

### Retrieve:
- `cass search "<topic>"` — past session conversations
