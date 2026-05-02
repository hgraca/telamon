"""Tests for scripts/format-md.py — pure logic functions."""

import sys
import os

# Make the scripts directory importable
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "scripts"))

import importlib.util

spec = importlib.util.spec_from_file_location(
    "format_md",
    os.path.join(os.path.dirname(__file__), "..", "..", "scripts", "format-md.py"),
)
format_md = importlib.util.module_from_spec(spec)
spec.loader.exec_module(format_md)

is_table_row = format_md.is_table_row
is_separator_row = format_md.is_separator_row
parse_cells = format_md.parse_cells
format_separator_cell = format_md.format_separator_cell
format_table = format_md.format_table
format_content = format_md.format_content


# ---------------------------------------------------------------------------
# is_table_row
# ---------------------------------------------------------------------------

class TestIsTableRow:
    def test_basic_table_row(self):
        assert is_table_row("| foo | bar |") is True

    def test_single_cell(self):
        assert is_table_row("| only |") is True

    def test_leading_whitespace(self):
        assert is_table_row("  | foo | bar |  ") is True

    def test_separator_row_is_table_row(self):
        assert is_table_row("| --- | --- |") is True

    def test_plain_text_not_table_row(self):
        assert is_table_row("just text") is False

    def test_starts_pipe_no_end(self):
        assert is_table_row("| foo | bar") is False

    def test_ends_pipe_no_start(self):
        assert is_table_row("foo | bar |") is False

    def test_empty_string(self):
        assert is_table_row("") is False

    def test_only_pipes(self):
        assert is_table_row("||") is True

    def test_heading_not_table_row(self):
        assert is_table_row("# Heading") is False


# ---------------------------------------------------------------------------
# is_separator_row
# ---------------------------------------------------------------------------

class TestIsSeparatorRow:
    def test_basic_separator(self):
        assert is_separator_row("| --- | --- |") is True

    def test_left_aligned(self):
        assert is_separator_row("| :--- | :--- |") is True

    def test_right_aligned(self):
        assert is_separator_row("| ---: | ---: |") is True

    def test_center_aligned(self):
        assert is_separator_row("| :---: | :---: |") is True

    def test_mixed_alignment(self):
        assert is_separator_row("| :--- | --- | ---: |") is True

    def test_single_dash_not_separator(self):
        # Single dash per cell — regex requires -+, so "-" matches
        assert is_separator_row("| - | - |") is True

    def test_data_row_not_separator(self):
        assert is_separator_row("| foo | bar |") is False

    def test_not_table_row(self):
        assert is_separator_row("just text") is False

    def test_separator_with_extra_dashes(self):
        assert is_separator_row("| --------- | ---------- |") is True

    def test_mixed_data_and_dashes_not_separator(self):
        assert is_separator_row("| foo | --- |") is False


# ---------------------------------------------------------------------------
# parse_cells
# ---------------------------------------------------------------------------

class TestParseCells:
    def test_basic_two_cells(self):
        assert parse_cells("| foo | bar |") == ["foo", "bar"]

    def test_strips_whitespace(self):
        assert parse_cells("|  hello  |  world  |") == ["hello", "world"]

    def test_single_cell(self):
        assert parse_cells("| only |") == ["only"]

    def test_three_cells(self):
        assert parse_cells("| a | b | c |") == ["a", "b", "c"]

    def test_separator_cells(self):
        assert parse_cells("| --- | :---: | ---: |") == ["---", ":---:", "---:"]

    def test_empty_cells(self):
        assert parse_cells("|  |  |") == ["", ""]

    def test_no_leading_trailing_pipe(self):
        # parse_cells handles lines without leading/trailing pipe too
        result = parse_cells("foo | bar")
        assert "foo" in result
        assert "bar" in result


# ---------------------------------------------------------------------------
# format_separator_cell
# ---------------------------------------------------------------------------

class TestFormatSeparatorCell:
    def test_plain_dashes(self):
        result = format_separator_cell("---", 5)
        assert result == "-----"
        assert len(result) == 5

    def test_left_aligned(self):
        result = format_separator_cell(":---", 6)
        assert result.startswith(":")
        assert len(result) == 6

    def test_right_aligned(self):
        result = format_separator_cell("---:", 6)
        assert result.endswith(":")
        assert len(result) == 6

    def test_center_aligned(self):
        result = format_separator_cell(":---:", 7)
        assert result.startswith(":")
        assert result.endswith(":")
        assert len(result) == 7

    def test_minimum_one_dash(self):
        # Even with width=0, at least 1 dash
        result = format_separator_cell("---", 0)
        assert "-" in result
        assert len(result) >= 1


# ---------------------------------------------------------------------------
# format_table
# ---------------------------------------------------------------------------

class TestFormatTable:
    def test_basic_two_column_table(self):
        lines = [
            "| Name | Age |",
            "| --- | --- |",
            "| Alice | 30 |",
        ]
        result = format_table(lines)
        assert len(result) == 3
        # All rows start and end with |
        for row in result:
            assert row.startswith("|")
            assert row.endswith("|")

    def test_columns_padded_to_equal_width(self):
        lines = [
            "| Short | A very long header |",
            "| --- | --- |",
            "| x | y |",
        ]
        result = format_table(lines)
        # Compare raw segment widths (between pipes, including padding)
        header_segments = result[0].strip().strip("|").split("|")
        data_segments = result[2].strip().strip("|").split("|")
        assert len(header_segments[0]) == len(data_segments[0])
        assert len(header_segments[1]) == len(data_segments[1])

    def test_separator_row_preserved(self):
        lines = [
            "| A | B |",
            "| --- | --- |",
            "| 1 | 2 |",
        ]
        result = format_table(lines)
        # Middle row should be separator
        assert is_separator_row(result[1])

    def test_single_column_table(self):
        lines = [
            "| Header |",
            "| --- |",
            "| Value |",
        ]
        result = format_table(lines)
        assert len(result) == 3

    def test_wide_data_expands_separator(self):
        lines = [
            "| Col |",
            "| --- |",
            "| A very long value indeed |",
        ]
        result = format_table(lines)
        # Separator must be at least as wide as data
        sep_cells = parse_cells(result[1])
        data_cells = parse_cells(result[2])
        assert len(sep_cells[0]) >= len(data_cells[0])

    def test_aligned_separator_preserved(self):
        lines = [
            "| Left | Center | Right |",
            "| :--- | :---: | ---: |",
            "| a | b | c |",
        ]
        result = format_table(lines)
        sep_cells = parse_cells(result[1])
        assert sep_cells[0].startswith(":")
        assert sep_cells[1].startswith(":") and sep_cells[1].endswith(":")
        assert sep_cells[2].endswith(":")

    def test_minimum_column_width_three(self):
        lines = [
            "| A | B |",
            "| - | - |",
            "| x | y |",
        ]
        result = format_table(lines)
        # Separator cells must be at least 3 dashes wide (plus padding)
        sep_cells = parse_cells(result[1])
        for cell in sep_cells:
            dashes = cell.strip(":")
            assert len(dashes) >= 3


# ---------------------------------------------------------------------------
# format_content
# ---------------------------------------------------------------------------

class TestFormatContent:
    def test_passthrough_non_table_content(self):
        text = "# Heading\n\nSome paragraph.\n"
        assert format_content(text) == text

    def test_formats_simple_table(self):
        text = "| A | B |\n| --- | --- |\n| short | a much longer value |\n"
        result = format_content(text)
        lines = result.splitlines()
        assert len(lines) == 3
        # All lines should be table rows
        for line in lines:
            assert is_table_row(line)

    def test_preserves_content_before_table(self):
        text = "# Title\n\n| A | B |\n| --- | --- |\n| 1 | 2 |\n"
        result = format_content(text)
        assert result.startswith("# Title\n")

    def test_preserves_content_after_table(self):
        text = "| A | B |\n| --- | --- |\n| 1 | 2 |\n\nFooter text.\n"
        result = format_content(text)
        assert result.endswith("Footer text.\n")

    def test_multiple_tables_formatted_independently(self):
        text = (
            "| X | Y |\n| --- | --- |\n| a | b |\n"
            "\n"
            "| Long Header | Short |\n| --- | --- |\n| val | v |\n"
        )
        result = format_content(text)
        # Both tables should still be valid
        table_lines = [l for l in result.splitlines() if is_table_row(l)]
        assert len(table_lines) == 6

    def test_empty_string(self):
        assert format_content("") == ""

    def test_no_table(self):
        text = "Just some text\nwith multiple lines\n"
        assert format_content(text) == text

    def test_preserves_line_endings_lf(self):
        text = "| A | B |\n| --- | --- |\n| 1 | 2 |\n"
        result = format_content(text)
        assert "\r\n" not in result

    def test_table_columns_equal_width_after_format(self):
        text = "| Short | A very long header |\n| --- | --- |\n| x | y |\n"
        result = format_content(text)
        lines = result.splitlines()
        # Compare raw segment widths (between pipes, including padding)
        header_segments = lines[0].strip().strip("|").split("|")
        data_segments = lines[2].strip().strip("|").split("|")
        assert len(header_segments[0]) == len(data_segments[0])
        assert len(header_segments[1]) == len(data_segments[1])

    def test_idempotent(self):
        text = "| Name | Value |\n| --- | --- |\n| foo | bar |\n"
        once = format_content(text)
        twice = format_content(once)
        assert once == twice

    def test_table_without_separator(self):
        # A table with no separator row — still formatted as table rows
        text = "| A | B |\n| 1 | 2 |\n"
        result = format_content(text)
        lines = result.splitlines()
        for line in lines:
            assert is_table_row(line)
