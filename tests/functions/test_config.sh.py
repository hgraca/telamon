"""Tests for src/functions/config.sh"""

import json
import os
import subprocess
import tempfile
import shutil

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def run(cmd: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["bash", "-c", cmd],
        capture_output=True, text=True, cwd=PROJECT_ROOT
    )


class TestConfigReadIni:
    def setup_method(self):
        self.tmp_dir = tempfile.mkdtemp(prefix="telamon_test_")

    def teardown_method(self):
        shutil.rmtree(self.tmp_dir, ignore_errors=True)

    def _write_jsonc(self, content: str) -> str:
        path = os.path.join(self.tmp_dir, "telamon.jsonc")
        with open(path, "w") as f:
            f.write(content)
        return path

    def test_reads_string_value(self):
        path = self._write_jsonc('{"model": "gpt-4o"}')
        result = run(f"source src/functions/config.sh && config.read_ini {path} model")
        assert result.returncode == 0
        assert result.stdout.strip() == "gpt-4o"

    def test_missing_file_returns_1(self):
        result = run(f"source src/functions/config.sh && config.read_ini /nonexistent/file.jsonc model")
        assert result.returncode == 1

    def test_missing_key_returns_1(self):
        path = self._write_jsonc('{"model": "gpt-4o"}')
        result = run(f"source src/functions/config.sh && config.read_ini {path} nonexistent_key")
        assert result.returncode == 1

    def test_handles_jsonc_comments(self):
        content = '{\n  // This is a comment\n  "model": "claude-3"\n}'
        path = self._write_jsonc(content)
        result = run(f"source src/functions/config.sh && config.read_ini {path} model")
        assert result.returncode == 0
        assert result.stdout.strip() == "claude-3"

    def test_boolean_true_value(self):
        path = self._write_jsonc('{"enabled": true}')
        result = run(f"source src/functions/config.sh && config.read_ini {path} enabled")
        assert result.returncode == 0
        assert result.stdout.strip() == "true"

    def test_boolean_false_value(self):
        path = self._write_jsonc('{"enabled": false}')
        result = run(f"source src/functions/config.sh && config.read_ini {path} enabled")
        assert result.returncode == 0
        assert result.stdout.strip() == "false"

    def test_null_value_returns_1(self):
        path = self._write_jsonc('{"model": null}')
        result = run(f"source src/functions/config.sh && config.read_ini {path} model")
        assert result.returncode == 1

    def test_array_value_prints_json(self):
        path = self._write_jsonc('{"items": [1, 2, 3]}')
        result = run(f"source src/functions/config.sh && config.read_ini {path} items")
        assert result.returncode == 0
        parsed = json.loads(result.stdout.strip())
        assert parsed == [1, 2, 3]

    def test_object_value_prints_json(self):
        path = self._write_jsonc('{"nested": {"a": 1}}')
        result = run(f"source src/functions/config.sh && config.read_ini {path} nested")
        assert result.returncode == 0
        parsed = json.loads(result.stdout.strip())
        assert parsed == {"a": 1}


class TestConfigWriteIni:
    def setup_method(self):
        self.tmp_dir = tempfile.mkdtemp(prefix="telamon_test_")

    def teardown_method(self):
        shutil.rmtree(self.tmp_dir, ignore_errors=True)

    def _write_jsonc(self, content: str) -> str:
        path = os.path.join(self.tmp_dir, "telamon.jsonc")
        with open(path, "w") as f:
            f.write(content)
        return path

    def _read_json(self, path: str) -> dict:
        with open(path) as f:
            return json.load(f)

    def test_creates_new_key(self):
        path = self._write_jsonc('{}')
        result = run(f"source src/functions/config.sh && config.write_ini {path} model gpt-4o")
        assert result.returncode == 0
        data = self._read_json(path)
        assert data["model"] == "gpt-4o"

    def test_updates_existing_key(self):
        path = self._write_jsonc('{"model": "old-model"}')
        result = run(f"source src/functions/config.sh && config.write_ini {path} model new-model")
        assert result.returncode == 0
        data = self._read_json(path)
        assert data["model"] == "new-model"

    def test_string_true_becomes_boolean(self):
        path = self._write_jsonc('{}')
        result = run(f"source src/functions/config.sh && config.write_ini {path} enabled true")
        assert result.returncode == 0
        data = self._read_json(path)
        assert data["enabled"] is True

    def test_string_false_becomes_boolean(self):
        path = self._write_jsonc('{}')
        result = run(f"source src/functions/config.sh && config.write_ini {path} enabled false")
        assert result.returncode == 0
        data = self._read_json(path)
        assert data["enabled"] is False

    def test_preserves_other_keys(self):
        path = self._write_jsonc('{"model": "gpt-4o", "other": "preserved"}')
        result = run(f"source src/functions/config.sh && config.write_ini {path} model new-model")
        assert result.returncode == 0
        data = self._read_json(path)
        assert data["other"] == "preserved"
        assert data["model"] == "new-model"
