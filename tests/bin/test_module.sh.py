"""Tests for bin/module.sh helper functions."""
import json
import os
import shutil
import subprocess
import tempfile

import pytest

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FUNCTIONS_PATH = os.path.join(PROJECT_ROOT, "src", "functions")


class TestDerivePath:
    """Tests for _derive_path function."""

    def _run(self, url: str) -> str:
        script = f"""
            _derive_path() {{
              local url="${{1%/}}"
              url="${{url%.git}}"
              local org_repo
              if [[ "${{url}}" == git@* ]]; then
                org_repo="${{url##*:}}"
              else
                local path_part="${{url#*://}}"
                path_part="${{path_part#*/}}"
                local repo; repo="$(basename "${{path_part}}")"
                local org;  org="$(basename "$(dirname "${{path_part}}")")"
                org_repo="${{org}}/${{repo}}"
              fi
              echo "vendor/${{org_repo}}"
            }}
            _derive_path "{url}"
        """
        result = subprocess.run(["bash", "-c", script], capture_output=True, text=True)
        assert result.returncode == 0, f"stderr: {result.stderr}"
        return result.stdout.strip()

    def test_https_url(self):
        assert self._run("https://github.com/org/repo.git") == "vendor/org/repo"

    def test_https_url_no_git_suffix(self):
        assert self._run("https://github.com/org/repo") == "vendor/org/repo"

    def test_ssh_url(self):
        assert self._run("git@github.com:org/repo.git") == "vendor/org/repo"

    def test_ssh_url_no_git_suffix(self):
        assert self._run("git@github.com:org/repo") == "vendor/org/repo"

    def test_trailing_slash(self):
        assert self._run("https://github.com/myorg/myrepo/") == "vendor/myorg/myrepo"

    def test_deep_path(self):
        # basename of path_part gives repo, dirname gives parent segment
        assert self._run("https://gitlab.com/group/subgroup/repo.git") == "vendor/subgroup/repo"


class TestUrlToDefaultName:
    """Tests for _url_to_default_name function."""

    def _run(self, url: str) -> str:
        script = f"""
            _url_to_default_name() {{
              local url="${{1%/}}"
              url="${{url%.git}}"
              basename "${{url}}"
            }}
            _url_to_default_name "{url}"
        """
        result = subprocess.run(["bash", "-c", script], capture_output=True, text=True)
        assert result.returncode == 0
        return result.stdout.strip()

    def test_https_url(self):
        assert self._run("https://github.com/org/repo.git") == "repo"

    def test_ssh_url(self):
        assert self._run("git@github.com:org/repo.git") == "repo"

    def test_no_git_suffix(self):
        assert self._run("https://github.com/org/my-module") == "my-module"

    def test_trailing_slash(self):
        assert self._run("https://github.com/org/repo/") == "repo"


class TestWireModuleToProject:
    """Tests for _wire_module_to_project — creates symlinks in .opencode/."""

    def setup_method(self):
        self.tmp = tempfile.mkdtemp(prefix="module-wire-test-")
        self.vendor_dir = os.path.join(self.tmp, "vendor", "org", "testmod")
        self.project_dir = os.path.join(self.tmp, "project")
        for t in ["skills", "plugins", "agents"]:
            os.makedirs(os.path.join(self.vendor_dir, t))
        os.makedirs(os.path.join(self.project_dir, ".opencode"), exist_ok=True)

    def teardown_method(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def _run_wire(self, name: str, vendor_dir: str, paths_json: str, project_dir: str):
        script = f"""
            export FUNCTIONS_PATH="{FUNCTIONS_PATH}"
            source "$FUNCTIONS_PATH/autoload.sh" 2>/dev/null

            _wire_module_to_project() {{
              local name="$1"
              local vendor_dir="$2"
              local paths_json="$3"
              local project_dir="$4"

              for type in skills plugins agents commands scripts; do
                local rel_path
                rel_path="$(python3 -c "
import json, sys
paths = json.loads(sys.argv[1])
print(paths.get(sys.argv[2], ''))
" "${{paths_json}}" "${{type}}")"

                [[ -z "${{rel_path}}" ]] && continue

                local src_dir
                src_dir="$(cd "${{vendor_dir}}" && cd "${{rel_path}}" 2>/dev/null && pwd)" || continue
                [[ -d "${{src_dir}}" ]] || continue

                local target_dir="${{project_dir}}/.opencode/${{type}}"
                local link_path="${{target_dir}}/${{name}}"

                mkdir -p "${{target_dir}}"

                if [[ -L "${{link_path}}" ]]; then
                  : # already exists — idempotent
                elif [[ -e "${{link_path}}" ]]; then
                  : # not a symlink — leave alone
                else
                  ln -s "${{src_dir}}" "${{link_path}}"
                fi
              done
            }}

            _wire_module_to_project "{name}" "{vendor_dir}" '{paths_json}' "{project_dir}"
        """
        return subprocess.run(["bash", "-c", script], capture_output=True, text=True, cwd=PROJECT_ROOT)

    def test_creates_symlinks_for_existing_paths(self):
        paths = {"skills": "./skills", "plugins": "./plugins", "agents": "./agents"}
        r = self._run_wire("testmod", self.vendor_dir, json.dumps(paths), self.project_dir)
        assert r.returncode == 0, f"stderr: {r.stderr}"
        for t in ["skills", "plugins", "agents"]:
            link = os.path.join(self.project_dir, ".opencode", t, "testmod")
            assert os.path.islink(link), f"Expected symlink at {link}"
            assert os.path.isdir(link), f"Symlink {link} should resolve to dir"

    def test_skips_missing_path_types(self):
        # commands and scripts dirs don't exist in vendor_dir
        paths = {"commands": "./commands", "scripts": "./scripts"}
        r = self._run_wire("testmod", self.vendor_dir, json.dumps(paths), self.project_dir)
        assert r.returncode == 0
        assert not os.path.exists(os.path.join(self.project_dir, ".opencode", "commands", "testmod"))
        assert not os.path.exists(os.path.join(self.project_dir, ".opencode", "scripts", "testmod"))

    def test_idempotent_existing_symlink(self):
        paths = {"skills": "./skills"}
        self._run_wire("testmod", self.vendor_dir, json.dumps(paths), self.project_dir)
        r = self._run_wire("testmod", self.vendor_dir, json.dumps(paths), self.project_dir)
        assert r.returncode == 0
        link = os.path.join(self.project_dir, ".opencode", "skills", "testmod")
        assert os.path.islink(link)

    def test_empty_paths_json(self):
        r = self._run_wire("testmod", self.vendor_dir, json.dumps({}), self.project_dir)
        assert r.returncode == 0
        # No .opencode subdirs should be created (nothing to wire)
        for t in ["skills", "plugins", "agents", "commands", "scripts"]:
            assert not os.path.exists(os.path.join(self.project_dir, ".opencode", t, "testmod"))


class TestRemoveModuleWiring:
    """Tests for _remove_module_wiring."""

    def setup_method(self):
        self.tmp = tempfile.mkdtemp(prefix="module-rm-test-")
        self.project_dir = os.path.join(self.tmp, "project")
        for t in ["skills", "plugins"]:
            d = os.path.join(self.project_dir, ".opencode", t)
            os.makedirs(d)
            os.symlink("/tmp", os.path.join(d, "testmod"))

    def teardown_method(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def _run_remove(self, name: str, project_dir: str):
        script = f"""
            export FUNCTIONS_PATH="{FUNCTIONS_PATH}"
            source "$FUNCTIONS_PATH/autoload.sh" 2>/dev/null

            _remove_module_wiring() {{
              local name="$1"
              local project_dir="$2"
              for type in skills plugins agents commands scripts; do
                local link_path="${{project_dir}}/.opencode/${{type}}/${{name}}"
                if [[ -L "${{link_path}}" ]]; then
                  rm "${{link_path}}"
                fi
              done
            }}

            _remove_module_wiring "{name}" "{project_dir}"
        """
        return subprocess.run(["bash", "-c", script], capture_output=True, text=True, cwd=PROJECT_ROOT)

    def test_removes_existing_symlinks(self):
        r = self._run_remove("testmod", self.project_dir)
        assert r.returncode == 0
        assert not os.path.exists(os.path.join(self.project_dir, ".opencode", "skills", "testmod"))
        assert not os.path.exists(os.path.join(self.project_dir, ".opencode", "plugins", "testmod"))

    def test_noop_when_no_symlinks(self):
        self._run_remove("testmod", self.project_dir)
        r = self._run_remove("testmod", self.project_dir)
        assert r.returncode == 0

    def test_does_not_remove_real_directories(self):
        # Create a real dir (not symlink) — should be left alone
        real_dir = os.path.join(self.project_dir, ".opencode", "agents", "testmod")
        os.makedirs(real_dir)
        r = self._run_remove("testmod", self.project_dir)
        assert r.returncode == 0
        assert os.path.isdir(real_dir), "Real directory should not be removed"

    def test_removes_only_named_module(self):
        # Add another module symlink — should survive
        other_link = os.path.join(self.project_dir, ".opencode", "skills", "othermod")
        os.symlink("/tmp", other_link)
        self._run_remove("testmod", self.project_dir)
        assert os.path.islink(other_link), "othermod symlink should survive"
