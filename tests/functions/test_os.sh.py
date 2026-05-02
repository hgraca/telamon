"""Tests for src/functions/os.sh"""

import os
import subprocess
import tempfile

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def run(cmd: str, **kwargs) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["bash", "-c", cmd],
        capture_output=True, text=True, cwd=PROJECT_ROOT, **kwargs
    )


class TestOsGetOs:
    def test_returns_linux(self):
        result = run("source src/functions/os.sh && os.get_os")
        assert result.returncode == 0
        assert result.stdout.strip() == "linux"


class TestOsGetArch:
    def test_returns_x86_64(self):
        result = run("source src/functions/os.sh && os.get_arch")
        assert result.returncode == 0
        assert result.stdout.strip() == "x86_64"


class TestOsVersionToNumber:
    def _run(self, version: str) -> str:
        result = run(f"source src/functions/os.sh && os.version_to_number {version}")
        assert result.returncode == 0
        return result.stdout.strip()

    def test_basic(self):
        assert self._run("1.2.3") == "10203"

    def test_large_major(self):
        assert self._run("10.0.0") == "100000"

    def test_zero_major(self):
        assert self._run("0.0.1") == "1"

    def test_two_digit_minor(self):
        assert self._run("2.14.7") == "21407"

    def test_major_only(self):
        assert self._run("1") == "10000"

    def test_major_minor_only(self):
        assert self._run("1.2") == "10200"


class TestOsSedI:
    def test_replaces_in_file(self):
        with tempfile.NamedTemporaryFile(mode="w", suffix=".txt", delete=False) as f:
            f.write("hello world\n")
            tmp = f.name
        try:
            result = run(f"source src/functions/os.sh && os.sed_i 's/hello/goodbye/' {tmp}")
            assert result.returncode == 0
            with open(tmp) as f:
                assert f.read().strip() == "goodbye world"
        finally:
            os.unlink(tmp)

    def test_multiple_expressions(self):
        with tempfile.NamedTemporaryFile(mode="w", suffix=".txt", delete=False) as f:
            f.write("foo bar\n")
            tmp = f.name
        try:
            result = run(f"source src/functions/os.sh && os.sed_i -e 's/foo/baz/' -e 's/bar/qux/' {tmp}")
            assert result.returncode == 0
            with open(tmp) as f:
                assert f.read().strip() == "baz qux"
        finally:
            os.unlink(tmp)


class TestOsHasGpu:
    def test_returns_exit_code_0_or_1(self):
        result = run("source src/functions/os.sh && os.has_gpu")
        assert result.returncode in (0, 1)


class TestOsDockerHost:
    def test_returns_ip_or_hostname(self):
        result = run("source src/functions/os.sh && os.docker_host")
        assert result.returncode == 0
        output = result.stdout.strip()
        assert len(output) > 0
        # Either an IP address or the hostname
        is_ip = all(part.isdigit() for part in output.split(".")) and len(output.split(".")) == 4
        is_hostname = output == "host.docker.internal"
        assert is_ip or is_hostname


class TestOsGetDistribution:
    def test_returns_non_empty_string(self):
        result = run("source src/functions/os.sh && os.get_distribution")
        assert result.returncode == 0
        output = result.stdout.strip()
        assert len(output) > 0
        # Should be lowercase (ID field from /etc/os-release)
        assert output == output.lower()
