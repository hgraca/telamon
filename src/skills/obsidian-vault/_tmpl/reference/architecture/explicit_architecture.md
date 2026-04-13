# EXPLICIT ARCHITECTURE

In this document:

- `<root>` is `app/` for Laravel projects, otherwise `src/`.
- `/` is the namespace separator, it might be different depending on the programming language.

## Directory Structure

```
<root>/
  Core/
    Component/<ComponentXName>/             # Can not depend on <ComponentYName>
      Domain/<EntityName>/                  # Pure business logic. Zero framework deps.
      Application/
        Query/<QueryName>/                  # Query handlers
        Repository/
        Listener/                           # Event handlers
        Service/
        UseCase/<UseCaseName>/              # Command handlers
    Component/<ComponentYName>/             # Can not depend on <ComponentXName>
      <SubComponentYA>/                     # Same inner structure as <ComponentXName>, can depend on <SubComponentYB>
      <SubComponentYB>/                     # Same inner structure as <ComponentXName>, can depend on <SubComponentYA>
    Port/<ToolName>/                        # Interfaces the core needs
  Infrastructure/<ToolName>/<AdapterName>/  # Implements ports
  Presentation/{Api,Web,Cli}/               # Thin delivery layer
```

Shared Kernel: events, query objects, DTOs, value objects that cross component boundaries.

A component may have subcomponents when the domain is large.

The `Core/Component/` grouping is required even for single-component projects — it establishes boundaries for future growth. Do not flatten `Domain/`, `Application/`, or `Port/` to the source root.

**Legacy:** anything in `<root>/` outside this structure is legacy, unless explicitly mentioned otherwise.
            Never place new files in legacy namespaces.

## Dependency Rules

```
                Domain
                  ^
Presentation -> Application -> Port <- Infrastructure
                    |           |          |
                language-overlay (treated as the language runtime)
```
