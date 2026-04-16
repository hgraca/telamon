"""Shared JSONC comment stripper — single source of truth for Telamon."""


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
