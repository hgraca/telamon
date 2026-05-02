"""Shared JSONC parser — single source of truth for Telamon."""

import json
import re


def strip_jsonc_comments(text):
    """Remove // and /* */ comments from JSONC, preserving string literals."""
    result = []
    i, n = 0, len(text)
    while i < n:
        if text[i] == '"':
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
            j = text.find("\n", i)
            i = j if j != -1 else n
        elif text[i : i + 2] == "/*":
            j = text.find("*/", i + 2)
            i = j + 2 if j != -1 else n
        else:
            result.append(text[i])
            i += 1
    return "".join(result)


def _fix_commas(text):
    """Fix trailing commas before } or ] and missing commas between properties."""
    # Remove trailing commas: ,\s*} or ,\s*]
    text = re.sub(r",(\s*[}\]])", r"\1", text)
    # Insert missing commas: "value"\n"key" or value\n"key" (missing comma between properties)
    text = re.sub(r'("(?:[^"\\]|\\.)*"|true|false|null|\d+(?:\.\d+)?)\s*\n(\s*")', r"\1,\n\2", text)
    return text


def load_jsonc(text):
    """Parse JSONC text (with comments, trailing/missing commas) into a Python object."""
    stripped = strip_jsonc_comments(text)
    fixed = _fix_commas(stripped)
    return json.loads(fixed)
