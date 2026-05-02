"""Tests for src/functions/strip_jsonc.py — JSONC parser."""

import sys
import os
import json
import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "src", "functions"))

from strip_jsonc import strip_jsonc_comments, load_jsonc


# ---------------------------------------------------------------------------
# strip_jsonc_comments
# ---------------------------------------------------------------------------

class TestStripJsoncComments:

    # --- line comments ---

    def test_removes_line_comment(self):
        result = strip_jsonc_comments('{"key": "value"} // comment')
        assert "//" not in result
        assert "value" in result

    def test_removes_full_line_comment(self):
        text = '{\n// full line comment\n"key": 1\n}'
        result = strip_jsonc_comments(text)
        assert "full line comment" not in result
        assert '"key"' in result

    def test_inline_comment_after_value(self):
        text = '{"a": 1 // inline\n}'
        result = strip_jsonc_comments(text)
        assert "inline" not in result
        assert '"a"' in result

    def test_url_in_string_preserved(self):
        # // inside a string must NOT be treated as comment
        text = '{"url": "http://example.com"}'
        result = strip_jsonc_comments(text)
        assert "http://example.com" in result

    def test_comment_at_end_of_file_no_newline(self):
        text = '{"x": 1} // trailing'
        result = strip_jsonc_comments(text)
        assert "trailing" not in result

    # --- block comments ---

    def test_removes_block_comment(self):
        text = '{"a": /* block */ 1}'
        result = strip_jsonc_comments(text)
        assert "block" not in result
        assert '"a"' in result

    def test_removes_multiline_block_comment(self):
        text = '{\n/* line one\nline two */\n"k": 2\n}'
        result = strip_jsonc_comments(text)
        assert "line one" not in result
        assert "line two" not in result
        assert '"k"' in result

    def test_block_comment_inside_string_preserved(self):
        text = '{"s": "/* not a comment */"}'
        result = strip_jsonc_comments(text)
        assert "/* not a comment */" in result

    def test_unterminated_block_comment_consumed_to_end(self):
        # Unterminated /* — everything after consumed
        text = '{"a": 1 /* unterminated'
        result = strip_jsonc_comments(text)
        assert "unterminated" not in result

    # --- string literal preservation ---

    def test_escaped_quote_in_string(self):
        text = r'{"s": "he said \"hello\""}'
        result = strip_jsonc_comments(text)
        assert r'\"hello\"' in result

    def test_backslash_in_string(self):
        text = r'{"path": "C:\\Users\\foo"}'
        result = strip_jsonc_comments(text)
        assert r"C:\\Users\\foo" in result

    def test_empty_string_value(self):
        text = '{"k": ""}'
        result = strip_jsonc_comments(text)
        assert '""' in result

    # --- no comments passthrough ---

    def test_plain_json_unchanged(self):
        text = '{"a": 1, "b": "hello"}'
        result = strip_jsonc_comments(text)
        assert result == text

    def test_empty_input(self):
        assert strip_jsonc_comments("") == ""


# ---------------------------------------------------------------------------
# load_jsonc
# ---------------------------------------------------------------------------

class TestLoadJsonc:

    # --- happy paths ---

    def test_plain_json(self):
        result = load_jsonc('{"a": 1, "b": "hello"}')
        assert result == {"a": 1, "b": "hello"}

    def test_line_comment_stripped(self):
        text = '{\n// comment\n"key": 42\n}'
        result = load_jsonc(text)
        assert result == {"key": 42}

    def test_block_comment_stripped(self):
        text = '{"x": /* ignored */ 99}'
        result = load_jsonc(text)
        assert result == {"x": 99}

    def test_trailing_comma_object(self):
        text = '{"a": 1,}'
        result = load_jsonc(text)
        assert result == {"a": 1}

    def test_trailing_comma_array(self):
        text = '[1, 2, 3,]'
        result = load_jsonc(text)
        assert result == [1, 2, 3]

    def test_trailing_comma_nested(self):
        text = '{"arr": [1, 2,], "obj": {"x": 1,}}'
        result = load_jsonc(text)
        assert result == {"arr": [1, 2], "obj": {"x": 1}}

    def test_inline_comment_after_value(self):
        text = '{\n"rtk_enabled": true // inline\n}'
        result = load_jsonc(text)
        assert result["rtk_enabled"] is True

    def test_multiple_line_comments(self):
        text = '{\n// first\n// second\n"k": "v"\n}'
        result = load_jsonc(text)
        assert result == {"k": "v"}

    def test_boolean_values(self):
        text = '{"t": true, "f": false}'
        result = load_jsonc(text)
        assert result == {"t": True, "f": False}

    def test_null_value(self):
        text = '{"n": null}'
        result = load_jsonc(text)
        assert result == {"n": None}

    def test_array_input(self):
        text = '[1, 2, /* skip */ 3]'
        result = load_jsonc(text)
        assert result == [1, 2, 3]

    def test_nested_objects(self):
        text = '{"outer": {"inner": 42 // comment\n}}'
        result = load_jsonc(text)
        assert result == {"outer": {"inner": 42}}

    def test_string_with_url(self):
        text = '{"url": "http://example.com"}'
        result = load_jsonc(text)
        assert result["url"] == "http://example.com"

    def test_empty_object(self):
        result = load_jsonc("{}")
        assert result == {}

    def test_empty_array(self):
        result = load_jsonc("[]")
        assert result == []

    def test_number_types(self):
        text = '{"int": 42, "float": 3.14}'
        result = load_jsonc(text)
        assert result["int"] == 42
        assert abs(result["float"] - 3.14) < 1e-9

    # --- error conditions ---

    def test_invalid_json_raises(self):
        with pytest.raises((json.JSONDecodeError, ValueError)):
            load_jsonc('{"unclosed": ')

    def test_empty_string_raises(self):
        with pytest.raises((json.JSONDecodeError, ValueError)):
            load_jsonc("")

    # --- real-world JSONC pattern (telamon config style) ---

    def test_telamon_config_pattern(self):
        text = """{
  // Agent configuration
  "caveman_enabled": true, // enable caveman mode
  /* Multi-line
     block comment */
  "rtk_enabled": false
}"""
        result = load_jsonc(text)
        assert result["caveman_enabled"] is True
        assert result["rtk_enabled"] is False
