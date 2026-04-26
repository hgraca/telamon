---
layout: page
title: Graphiti
description: Temporal knowledge graph backed by Neo4j — tracks architectural evolution.
nav_section: docs
---

[Graphiti](https://github.com/getzep/graphiti) — Temporal Knowledge Graph (Optional)

Temporal knowledge graph backed by Neo4j. Stores entities and relationships with temporal metadata.
Enable by setting `GRAPHITI_ENABLED=true` in `.env`.

- Runs as a Docker Compose profile with Neo4j and the Graphiti API server
- Requires `NEO4J_PASSWORD` and `OPENAI_API_KEY` in `.env`
- Neo4j browser at `http://localhost:17474`, Graphiti API at `http://localhost:17801`

**Status:** Optional — enable when needed.
