#!/usr/bin/env python3
"""
merge-config.py — Merge Telamon opencode config into an existing project config.

Usage:
    python3 merge-config.py <project-config> <telamon-config>

Merge rules (by top-level key):
  mcp            — upsert each Telamon server; preserve project's own entries
  instructions   — union list; Telamon entries added if not already present
  plugin         — union list; Telamon entries added if not already present
  watcher.ignore — union list; Telamon entries added if not already present
  permission     — deep merge; Telamon keys are set, project keys preserved
  model, small_model, coding_model, default_agent, agent — skipped (not overridden)

The project config is written back in-place with 2-space indentation.
JSONC comments (//, /* */) are stripped before parsing, so both .json
and .jsonc files are handled.
"""

import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "functions"))
from strip_jsonc import strip_jsonc_comments


def load_jsonc(path: str) -> dict:
    with open(path, encoding="utf-8") as f:
        raw = f.read()
    return json.loads(strip_jsonc_comments(raw))


def union_list(base: list, additions: list) -> list:
    """Return base with any additions not already present appended."""
    result = list(base)
    for item in additions:
        if item not in result:
            result.append(item)
    return result


def deep_merge_dict(base: dict, override: dict) -> dict:
    """Recursively merge override into base; override wins on scalar conflicts."""
    result = dict(base)
    for key, val in override.items():
        if key in result and isinstance(result[key], dict) and isinstance(val, dict):
            result[key] = deep_merge_dict(result[key], val)
        else:
            result[key] = val
    return result


SKIP_KEYS = {"model", "small_model", "coding_model", "default_agent", "agent"}


def merge(project: dict, telamon: dict) -> dict:
    result = dict(project)

    for key, telamon_val in telamon.items():
        if key in SKIP_KEYS:
            continue

        proj_val = project.get(key)

        if key == "mcp":
            # Upsert each Telamon MCP server; preserve project's own
            merged_mcp = dict(proj_val) if isinstance(proj_val, dict) else {}
            if isinstance(telamon_val, dict):
                for server, block in telamon_val.items():
                    if server in merged_mcp:
                        print(f"  Keeping project MCP entry: {server}")
                    else:
                        merged_mcp[server] = block
            result[key] = merged_mcp

        elif key in ("instructions", "plugin") and isinstance(telamon_val, list):
            base_list = proj_val if isinstance(proj_val, list) else []
            result[key] = union_list(base_list, telamon_val)

        elif key == "watcher":
            # Merge watcher sub-keys; union the ignore list
            proj_watcher = proj_val if isinstance(proj_val, dict) else {}
            telamon_watcher = telamon_val if isinstance(telamon_val, dict) else {}
            merged_watcher = dict(proj_watcher)
            if "ignore" in telamon_watcher:
                base_ignore = proj_watcher.get("ignore", [])
                merged_watcher["ignore"] = union_list(
                    base_ignore, telamon_watcher["ignore"]
                )
            for k, v in telamon_watcher.items():
                if k != "ignore":
                    merged_watcher.setdefault(k, v)
            result[key] = merged_watcher

        elif key == "permission":
            # Deep merge; Telamon keys are set (project's own keys preserved if not in Telamon)
            proj_perm = proj_val if isinstance(proj_val, dict) else {}
            result[key] = deep_merge_dict(proj_perm, telamon_val)

        else:
            # Any other key: set from Telamon only if not already in project
            result.setdefault(key, telamon_val)

    return result


def main():
    if len(sys.argv) != 3:
        print(
            f"Usage: {sys.argv[0]} <project-config> <telamon-config>", file=sys.stderr
        )
        sys.exit(1)

    project_path, telamon_path = sys.argv[1], sys.argv[2]

    project = load_jsonc(project_path)
    telamon = load_jsonc(telamon_path)

    merged = merge(project, telamon)

    with open(project_path, "w", encoding="utf-8") as f:
        json.dump(merged, f, indent=2)
        f.write("\n")

    print(f"  \033[32m✔\033[0m  Telamon config merged into {project_path}")


if __name__ == "__main__":
    main()
