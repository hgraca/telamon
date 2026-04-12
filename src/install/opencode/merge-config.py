#!/usr/bin/env python3
"""
merge-config.py — Merge ADK opencode config into an existing project config.

Usage:
    python3 merge-config.py <project-config> <adk-config>

Merge rules (by top-level key):
  mcp            — upsert each ADK server; preserve project's own entries
  instructions   — union list; ADK entries added if not already present
  plugin         — union list; ADK entries added if not already present
  watcher.ignore — union list; ADK entries added if not already present
  permission     — deep merge; ADK keys are set, project keys preserved
  model, small_model, coding_model, default_agent, agent — skipped (not overridden)

The project config is written back in-place with 2-space indentation.
JSONC comments (//, /* */) are stripped before parsing, so both .json
and .jsonc files are handled.
"""

import json
import sys


def strip_jsonc_comments(text: str) -> str:
    """
    Remove // line comments and /* */ block comments from a JSONC string.

    Uses a character-by-character tokenizer so that comment markers inside
    string literals are correctly preserved.
    """
    result: list[str] = []
    i = 0
    n = len(text)
    while i < n:
        if text[i] == '"':
            # Consume string literal verbatim (including escape sequences)
            j = i + 1
            while j < n:
                if text[j] == "\\":
                    j += 2
                elif text[j] == '"':
                    j += 1
                    break
                else:
                    j += 1
            result.append(text[i:j])
            i = j
        elif text[i : i + 2] == "//":
            # Skip line comment; preserve the newline so line numbers stay intact
            j = text.find("\n", i)
            if j == -1:
                break
            i = j
        elif text[i : i + 2] == "/*":
            # Skip block comment
            j = text.find("*/", i + 2)
            if j == -1:
                break
            i = j + 2
        else:
            result.append(text[i])
            i += 1
    return "".join(result)


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


def merge(project: dict, adk: dict) -> dict:
    result = dict(project)

    for key, adk_val in adk.items():
        if key in SKIP_KEYS:
            continue

        proj_val = project.get(key)

        if key == "mcp":
            # Upsert each ADK MCP server; preserve project's own
            merged_mcp = dict(proj_val) if isinstance(proj_val, dict) else {}
            if isinstance(adk_val, dict):
                for server, block in adk_val.items():
                    merged_mcp[server] = block
            result[key] = merged_mcp

        elif key in ("instructions", "plugin") and isinstance(adk_val, list):
            base_list = proj_val if isinstance(proj_val, list) else []
            result[key] = union_list(base_list, adk_val)

        elif key == "watcher":
            # Merge watcher sub-keys; union the ignore list
            proj_watcher = proj_val if isinstance(proj_val, dict) else {}
            adk_watcher = adk_val if isinstance(adk_val, dict) else {}
            merged_watcher = dict(proj_watcher)
            if "ignore" in adk_watcher:
                base_ignore = proj_watcher.get("ignore", [])
                merged_watcher["ignore"] = union_list(base_ignore, adk_watcher["ignore"])
            for k, v in adk_watcher.items():
                if k != "ignore":
                    merged_watcher.setdefault(k, v)
            result[key] = merged_watcher

        elif key == "permission":
            # Deep merge; ADK keys are set (project's own keys preserved if not in ADK)
            proj_perm = proj_val if isinstance(proj_val, dict) else {}
            result[key] = deep_merge_dict(proj_perm, adk_val)

        else:
            # Any other key: set from ADK only if not already in project
            result.setdefault(key, adk_val)

    return result


def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <project-config> <adk-config>", file=sys.stderr)
        sys.exit(1)

    project_path, adk_path = sys.argv[1], sys.argv[2]

    project = load_jsonc(project_path)
    adk = load_jsonc(adk_path)

    merged = merge(project, adk)

    with open(project_path, "w", encoding="utf-8") as f:
        json.dump(merged, f, indent=2)
        f.write("\n")

    print(f"  \033[32m✔\033[0m  ADK config merged into {project_path}")


if __name__ == "__main__":
    main()
