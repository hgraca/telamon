"""Tests for src/functions/env.sh"""

import os
import subprocess
import tempfile
import shutil

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def run(cmd: str, env_vars: dict = None) -> subprocess.CompletedProcess:
    env = {**os.environ, **(env_vars or {})}
    return subprocess.run(
        ["bash", "-c", cmd],
        capture_output=True, text=True, cwd=PROJECT_ROOT, env=env
    )


class TestEnvIsEnabled:
    def setup_method(self):
        self.tmp_dir = tempfile.mkdtemp(prefix="telamon_test_")

    def teardown_method(self):
        shutil.rmtree(self.tmp_dir, ignore_errors=True)

    def _run(self, var_value=None, dot_env_content=None, var_name="MY_VAR"):
        env_vars = {"TELAMON_ROOT": self.tmp_dir}
        if var_value is not None:
            env_vars[var_name] = var_value
        if dot_env_content is not None:
            with open(os.path.join(self.tmp_dir, ".env"), "w") as f:
                f.write(dot_env_content)
        cmd = f"source src/functions/env.sh && env.is_enabled {var_name}"
        return run(cmd, env_vars)

    def test_env_var_true_lowercase(self):
        result = self._run(var_value="true")
        assert result.returncode == 0

    def test_env_var_true_uppercase(self):
        result = self._run(var_value="TRUE")
        assert result.returncode == 0

    def test_env_var_true_mixed_case(self):
        result = self._run(var_value="True")
        assert result.returncode == 0

    def test_env_var_false(self):
        result = self._run(var_value="false")
        assert result.returncode == 1

    def test_env_var_empty(self):
        result = self._run(var_value="", dot_env_content="")
        assert result.returncode == 1

    def test_dotenv_true(self):
        result = self._run(dot_env_content="MY_VAR=true\n")
        assert result.returncode == 0

    def test_dotenv_false(self):
        result = self._run(dot_env_content="MY_VAR=false\n")
        assert result.returncode == 1

    def test_dotenv_missing(self):
        # No .env file written
        result = self._run()
        assert result.returncode == 1


class TestEnvIsDisabled:
    def setup_method(self):
        self.tmp_dir = tempfile.mkdtemp(prefix="telamon_test_")

    def teardown_method(self):
        shutil.rmtree(self.tmp_dir, ignore_errors=True)

    def _run(self, var_value=None, dot_env_content=None, var_name="MY_VAR"):
        env_vars = {"TELAMON_ROOT": self.tmp_dir}
        if var_value is not None:
            env_vars[var_name] = var_value
        if dot_env_content is not None:
            with open(os.path.join(self.tmp_dir, ".env"), "w") as f:
                f.write(dot_env_content)
        cmd = f"source src/functions/env.sh && env.is_disabled {var_name}"
        return run(cmd, env_vars)

    def test_env_var_false_lowercase(self):
        result = self._run(var_value="false")
        assert result.returncode == 0

    def test_env_var_false_uppercase(self):
        result = self._run(var_value="FALSE")
        assert result.returncode == 0

    def test_env_var_true(self):
        result = self._run(var_value="true")
        assert result.returncode == 1

    def test_env_var_empty(self):
        result = self._run(var_value="", dot_env_content="")
        assert result.returncode == 1

    def test_dotenv_false(self):
        result = self._run(dot_env_content="MY_VAR=false\n")
        assert result.returncode == 0


class TestEnvRead:
    def setup_method(self):
        self.tmp_dir = tempfile.mkdtemp(prefix="telamon_test_")

    def teardown_method(self):
        shutil.rmtree(self.tmp_dir, ignore_errors=True)

    def _run(self, var_value=None, dot_env_content=None, var_name="MY_VAR"):
        env_vars = {"TELAMON_ROOT": self.tmp_dir}
        if var_value is not None:
            env_vars[var_name] = var_value
        if dot_env_content is not None:
            with open(os.path.join(self.tmp_dir, ".env"), "w") as f:
                f.write(dot_env_content)
        cmd = f"source src/functions/env.sh && env.read {var_name}"
        return run(cmd, env_vars)

    def test_env_var_set(self):
        result = self._run(var_value="myvalue")
        assert result.returncode == 0
        assert result.stdout == "myvalue"

    def test_dotenv_plain_value(self):
        result = self._run(dot_env_content="MY_VAR=hello\n")
        assert result.returncode == 0
        assert result.stdout == "hello"

    def test_dotenv_quoted_value(self):
        result = self._run(dot_env_content='MY_VAR="quoted"\n')
        assert result.returncode == 0
        assert result.stdout == "quoted"

    def test_dotenv_missing(self):
        result = self._run()
        assert result.returncode == 0
        assert result.stdout == ""
