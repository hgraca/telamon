"""Tests for src/functions/state.sh"""

import os
import subprocess
import tempfile
import shutil

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def run(cmd: str, state_dir: str) -> subprocess.CompletedProcess:
    env = {**os.environ, "STATE_DIR": state_dir}
    return subprocess.run(
        ["bash", "-c", cmd],
        capture_output=True, text=True, cwd=PROJECT_ROOT, env=env
    )


class TestStateDone:
    def setup_method(self):
        self.tmp_dir = tempfile.mkdtemp(prefix="telamon_test_")

    def teardown_method(self):
        shutil.rmtree(self.tmp_dir, ignore_errors=True)

    def test_step_not_recorded_returns_nonzero(self):
        result = run("source src/functions/state.sh && state.done my_step", self.tmp_dir)
        assert result.returncode != 0

    def test_step_recorded_returns_0(self):
        result = run(
            "source src/functions/state.sh && state.mark my_step && state.done my_step",
            self.tmp_dir
        )
        assert result.returncode == 0

    def test_different_step_not_found(self):
        result = run(
            "source src/functions/state.sh && state.mark step_a && state.done step_b",
            self.tmp_dir
        )
        assert result.returncode == 1


class TestStateMark:
    def setup_method(self):
        self.tmp_dir = tempfile.mkdtemp(prefix="telamon_test_")

    def teardown_method(self):
        shutil.rmtree(self.tmp_dir, ignore_errors=True)

    def _state_file(self) -> str:
        return os.path.join(self.tmp_dir, ".setup-state")

    def test_creates_state_file(self):
        run("source src/functions/state.sh && state.mark my_step", self.tmp_dir)
        assert os.path.exists(self._state_file())

    def test_records_step(self):
        run("source src/functions/state.sh && state.mark my_step", self.tmp_dir)
        with open(self._state_file()) as f:
            lines = f.read().splitlines()
        assert "my_step" in lines

    def test_idempotent_no_duplicates(self):
        run(
            "source src/functions/state.sh && state.mark my_step && state.mark my_step",
            self.tmp_dir
        )
        with open(self._state_file()) as f:
            lines = f.read().splitlines()
        assert lines.count("my_step") == 1

    def test_file_is_sorted(self):
        run(
            "source src/functions/state.sh && state.mark zebra && state.mark alpha && state.mark middle",
            self.tmp_dir
        )
        with open(self._state_file()) as f:
            lines = [l for l in f.read().splitlines() if l]
        assert lines == sorted(lines)

    def test_multiple_steps_recorded(self):
        run(
            "source src/functions/state.sh && state.mark step_a && state.mark step_b",
            self.tmp_dir
        )
        with open(self._state_file()) as f:
            lines = f.read().splitlines()
        assert "step_a" in lines
        assert "step_b" in lines
