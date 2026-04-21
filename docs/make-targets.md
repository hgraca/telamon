---
layout: page
title: Make Targets
description: All available make commands.
nav_section: docs
---

| Target                  | Description                                                     |
|-------------------------|-----------------------------------------------------------------|
| `make up`               | Install host tools + start Docker services                      |
| `make down`             | Stop Docker services                                            |
| `make restart`          | `down` then `up`                                                |
| `make purge`            | Stop services and delete all volumes (destructive)              |
| `make status`           | Quick installation status of all Telamon tools                  |
| `make doctor`           | Comprehensive health check (connectivity, config, secrets)      |
| `make update`           | Upgrade all Telamon-managed tools to their latest versions      |
| `make init PROJ=<path>` | Initialise a project to use Telamon                             |
| `make test`             | Run the full test suite (make up + init dummy project + assert) |
