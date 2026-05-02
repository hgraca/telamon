"""Tests for bin/fix-memory-links.sh — symlink migration logic."""
import os
import shutil
import subprocess
import tempfile

import pytest

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FUNCTIONS_PATH = os.path.join(PROJECT_ROOT, "src", "functions")

# Inline the core fix logic so tests don't depend on BASH_SOURCE path resolution.
# This mirrors the Strategy 1 loop from fix-memory-links.sh exactly.
_FIX_LOGIC = """
FIXED=0
SKIPPED=0

while IFS= read -r _ppath_file; do
  [[ -f "${_ppath_file}" ]] || continue
  _proj_dir="$(cat "${_ppath_file}")"
  [[ -d "${_proj_dir}" ]] || continue

  _memory_link="${_proj_dir}/.ai/telamon/memory"

  if [[ -L "${_memory_link}" ]]; then
    _target="$(readlink "${_memory_link}")"

    if [[ "${_target}" == *"/storage/obsidian/"* ]]; then
      _new_target="${_target/storage\\/obsidian\\//storage\\/projects-memory\\/}"

      if [[ -d "${_new_target}" ]]; then
        rm "${_memory_link}"
        ln -s "${_new_target}" "${_memory_link}"
        FIXED=$((FIXED + 1))
      else
        SKIPPED=$((SKIPPED + 1))
      fi
    fi
  fi
done < <(find "${TELAMON_ROOT}/storage/graphify" -name ".project-path" 2>/dev/null || true)

echo "FIXED=${FIXED} SKIPPED=${SKIPPED}"
"""


class TestFixMemoryLinks:
    """Integration tests — runs the fix logic against temp directory structures."""

    def setup_method(self):
        self.tmp = tempfile.mkdtemp(prefix="fix-memory-links-test-")
        self.telamon_root = self.tmp

    def teardown_method(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def _create_project(self, proj_name: str, memory_target: str | None = None, create_new_target: bool = True) -> str:
        """Create fake project with graphify marker and optional memory symlink."""
        proj_dir = os.path.join(self.tmp, "projects", proj_name)
        ai_dir = os.path.join(proj_dir, ".ai", "telamon")
        os.makedirs(ai_dir, exist_ok=True)

        # graphify .project-path marker
        graphify_dir = os.path.join(self.telamon_root, "storage", "graphify", proj_name)
        os.makedirs(graphify_dir, exist_ok=True)
        with open(os.path.join(graphify_dir, ".project-path"), "w") as f:
            f.write(proj_dir)

        if create_new_target:
            new_vault = os.path.join(self.telamon_root, "storage", "projects-memory", proj_name)
            os.makedirs(new_vault, exist_ok=True)

        if memory_target is not None:
            os.symlink(memory_target, os.path.join(ai_dir, "memory"))

        return proj_dir

    def _run(self) -> subprocess.CompletedProcess:
        script = (
            f"set -euo pipefail\n"
            f"export TELAMON_ROOT=\"{self.telamon_root}\"\n"
            f"export FUNCTIONS_PATH=\"{FUNCTIONS_PATH}\"\n"
            f"source \"$FUNCTIONS_PATH/autoload.sh\" 2>/dev/null\n"
            + _FIX_LOGIC
        )
        return subprocess.run(["bash", "-c", script], capture_output=True, text=True, cwd=PROJECT_ROOT)

    # ── Core fix behaviour ────────────────────────────────────────────────────

    def test_fixes_obsidian_symlink(self):
        """Symlink pointing to storage/obsidian/<name> → fixed to storage/projects-memory/<name>."""
        old_target = os.path.join(self.telamon_root, "storage", "obsidian", "myproj")
        os.makedirs(old_target, exist_ok=True)
        proj_dir = self._create_project("myproj", memory_target=old_target)

        r = self._run()
        assert r.returncode == 0, f"stderr: {r.stderr}"
        assert "FIXED=1" in r.stdout

        memory_link = os.path.join(proj_dir, ".ai", "telamon", "memory")
        assert os.path.islink(memory_link)
        new_target = os.readlink(memory_link)
        assert "storage/projects-memory/" in new_target
        assert "storage/obsidian/" not in new_target

    def test_skips_already_correct_symlink(self):
        """Symlink already pointing to storage/projects-memory/ → no change."""
        new_target = os.path.join(self.telamon_root, "storage", "projects-memory", "goodproj")
        os.makedirs(new_target, exist_ok=True)
        self._create_project("goodproj", memory_target=new_target, create_new_target=False)

        r = self._run()
        assert r.returncode == 0, f"stderr: {r.stderr}"
        assert "FIXED=0" in r.stdout
        assert "SKIPPED=0" in r.stdout

    def test_skips_when_new_target_missing(self):
        """Old obsidian symlink but new target doesn't exist → SKIPPED incremented."""
        old_target = os.path.join(self.telamon_root, "storage", "obsidian", "noexist")
        os.makedirs(old_target, exist_ok=True)
        proj_dir = self._create_project("noexist", memory_target=old_target, create_new_target=False)

        r = self._run()
        assert r.returncode == 0, f"stderr: {r.stderr}"
        assert "SKIPPED=1" in r.stdout

        # Original symlink must be untouched
        memory_link = os.path.join(proj_dir, ".ai", "telamon", "memory")
        assert os.path.islink(memory_link)
        assert os.readlink(memory_link) == old_target

    def test_skips_project_without_memory_link(self):
        """Project exists but no .ai/telamon/memory → no crash, FIXED=0."""
        self._create_project("nolinkproj", memory_target=None)

        r = self._run()
        assert r.returncode == 0, f"stderr: {r.stderr}"
        assert "FIXED=0" in r.stdout

    def test_handles_multiple_projects(self):
        """Fixes all broken symlinks across multiple projects in one run."""
        for name in ["proj1", "proj2"]:
            old = os.path.join(self.telamon_root, "storage", "obsidian", name)
            os.makedirs(old, exist_ok=True)
            self._create_project(name, memory_target=old)

        r = self._run()
        assert r.returncode == 0, f"stderr: {r.stderr}"
        assert "FIXED=2" in r.stdout

    def test_mixed_projects(self):
        """Mix of broken, correct, and no-link projects — only broken ones fixed."""
        # broken
        old = os.path.join(self.telamon_root, "storage", "obsidian", "broken")
        os.makedirs(old, exist_ok=True)
        self._create_project("broken", memory_target=old)

        # already correct
        good = os.path.join(self.telamon_root, "storage", "projects-memory", "good")
        os.makedirs(good, exist_ok=True)
        self._create_project("good", memory_target=good, create_new_target=False)

        # no link
        self._create_project("nolink", memory_target=None)

        r = self._run()
        assert r.returncode == 0, f"stderr: {r.stderr}"
        assert "FIXED=1" in r.stdout

    # ── Edge cases ────────────────────────────────────────────────────────────

    def test_empty_graphify_dir(self):
        """No .project-path files → runs cleanly with FIXED=0."""
        os.makedirs(os.path.join(self.telamon_root, "storage", "graphify"), exist_ok=True)
        r = self._run()
        assert r.returncode == 0, f"stderr: {r.stderr}"
        assert "FIXED=0" in r.stdout

    def test_no_graphify_dir(self):
        """storage/graphify doesn't exist → no crash (find handles gracefully)."""
        r = self._run()
        assert r.returncode == 0, f"stderr: {r.stderr}"
        assert "FIXED=0" in r.stdout

    def test_project_path_file_points_to_missing_dir(self):
        """Stale .project-path pointing to non-existent dir → skipped gracefully."""
        graphify_dir = os.path.join(self.telamon_root, "storage", "graphify", "ghost")
        os.makedirs(graphify_dir, exist_ok=True)
        with open(os.path.join(graphify_dir, ".project-path"), "w") as f:
            f.write("/tmp/this-dir-does-not-exist-telamon-test")

        r = self._run()
        assert r.returncode == 0, f"stderr: {r.stderr}"
        assert "FIXED=0" in r.stdout

    def test_idempotent_second_run(self):
        """Running twice on already-fixed symlinks → FIXED=0 on second run."""
        old_target = os.path.join(self.telamon_root, "storage", "obsidian", "idem")
        os.makedirs(old_target, exist_ok=True)
        self._create_project("idem", memory_target=old_target)

        self._run()  # first run fixes it
        r = self._run()  # second run should be a no-op
        assert r.returncode == 0, f"stderr: {r.stderr}"
        assert "FIXED=0" in r.stdout
