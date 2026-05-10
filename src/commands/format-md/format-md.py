#!/usr/bin/env python3
# Formats markdown tables so all columns are padded to equal width per column.
#
# Usage:
#   format-md.py path/to/directory    # format all .md files recursively
#   format-md.py file1.md file2.md    # format specific files in-place
#   cat file.md | format-md.py        # pipe mode: stdin -> stdout
#   format-md.py --help               # show this help

import sys
import os
import re


USAGE = """\
Usage:
  format-md.py <directory>         Format all .md files in directory (recursive)
  format-md.py <file> [<file>...]  Format specific files in-place
  cat file.md | format-md.py       Pipe mode: stdin -> stdout
  format-md.py --help              Show this help
"""


def is_table_row(line: str) -> bool:
    s = line.strip()
    return s.startswith("|") and s.endswith("|")


def is_separator_row(line: str) -> bool:
    s = line.strip()
    if not is_table_row(s):
        return False
    cells = parse_cells(s)
    return all(re.match(r'^:?-+:?$', c) for c in cells if c)


def parse_cells(line: str) -> list[str]:
    s = line.strip()
    # Remove leading and trailing |
    if s.startswith("|"):
        s = s[1:]
    if s.endswith("|"):
        s = s[:-1]
    return [c.strip() for c in s.split("|")]


def format_separator_cell(cell: str, width: int) -> str:
    left_colon = cell.startswith(":")
    right_colon = cell.endswith(":")
    # Number of dashes needed to fill width
    dash_count = width - (1 if left_colon else 0) - (1 if right_colon else 0)
    dash_count = max(dash_count, 1)
    return (":" if left_colon else "") + "-" * dash_count + (":" if right_colon else "")


def format_table(lines: list[str]) -> list[str]:
    rows = [parse_cells(l) for l in lines]
    sep_indices = [i for i, l in enumerate(lines) if is_separator_row(l)]

    # Determine number of columns
    num_cols = max(len(r) for r in rows)

    # Pad rows to num_cols
    for r in rows:
        while len(r) < num_cols:
            r.append("")

    # Compute max width per column (excluding separator rows)
    col_widths = [0] * num_cols
    for i, row in enumerate(rows):
        if i in sep_indices:
            continue
        for j, cell in enumerate(row):
            if len(cell) > col_widths[j]:
                col_widths[j] = len(cell)

    # Ensure separator cells fit too (at least 3 dashes)
    for j in range(num_cols):
        if col_widths[j] < 3:
            col_widths[j] = 3

    # Format rows
    result = []
    for i, row in enumerate(rows):
        if i in sep_indices:
            cells = []
            for j, cell in enumerate(row):
                # +2 to match the " cell " padding used in data rows
                cells.append(format_separator_cell(cell if cell else "---", col_widths[j] + 2))
            result.append("|" + "|".join(cells) + "|")
        else:
            cells = []
            for j, cell in enumerate(row):
                cells.append(" " + cell.ljust(col_widths[j]) + " ")
            result.append("|" + "|".join(cells) + "|")

    return result


def format_content(text: str) -> str:
    lines = text.splitlines(keepends=True)
    output = []
    table_buf: list[str] = []
    table_line_endings: list[str] = []

    def flush_table():
        if not table_buf:
            return
        formatted = format_table(table_buf)
        for k, fline in enumerate(formatted):
            ending = table_line_endings[k] if k < len(table_line_endings) else "\n"
            output.append(fline + ending)
        table_buf.clear()
        table_line_endings.clear()

    for raw_line in lines:
        line = raw_line.rstrip("\r\n")
        ending = raw_line[len(line):]
        if is_table_row(line):
            table_buf.append(line)
            table_line_endings.append(ending)
        else:
            flush_table()
            output.append(raw_line)

    flush_table()
    return "".join(output)


def format_file(path: str) -> None:
    with open(path, "r", encoding="utf-8") as f:
        original = f.read()
    formatted = format_content(original)
    if formatted != original:
        with open(path, "w", encoding="utf-8") as f:
            f.write(formatted)


def find_md_files(directory: str) -> list[str]:
    result = []
    for root, _dirs, files in os.walk(directory):
        for fname in files:
            if fname.endswith(".md"):
                result.append(os.path.join(root, fname))
    return sorted(result)


def main() -> int:
    args = sys.argv[1:]

    if "--help" in args or "-h" in args:
        print(USAGE, end="")
        return 0

    if not args:
        # Pipe mode
        if sys.stdin.isatty():
            print("Error: no arguments given and stdin is a terminal.", file=sys.stderr)
            print(USAGE, end="", file=sys.stderr)
            return 1
        text = sys.stdin.read()
        sys.stdout.write(format_content(text))
        return 0

    paths = args
    errors = 0

    for path in paths:
        if os.path.isdir(path):
            for md_file in find_md_files(path):
                try:
                    format_file(md_file)
                except Exception as e:
                    print(f"Error formatting {md_file}: {e}", file=sys.stderr)
                    errors += 1
        elif os.path.isfile(path):
            try:
                format_file(path)
            except Exception as e:
                print(f"Error formatting {path}: {e}", file=sys.stderr)
                errors += 1
        else:
            print(f"Error: {path!r} is not a file or directory.", file=sys.stderr)
            errors += 1

    return 0 if errors == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
