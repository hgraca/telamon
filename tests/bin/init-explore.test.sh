#!/usr/bin/env bash
# =============================================================================
# tests/bin/init-explore.test.sh
#
# Hermetic branch coverage for the telamon.explore-project block in bin/init.sh.
#
# Strategy: extract the sentinel-delimited block from bin/init.sh, source it in
# isolation against a mktemp project tree, with `opencode` stubbed via a PATH
# binary. The rest of bin/init.sh (set -euo pipefail, flag parsing, MEMORY_OWNER
# resolution, INIT_APPS loop, gitignore, external modules, Done footer) is NEVER
# executed — so this test makes ZERO writes outside its own mktemp tempdirs and
# does not depend on a working Telamon installation.
# =============================================================================

set -euo pipefail

TELAMON_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INIT_SH="${TELAMON_ROOT}/bin/init.sh"
STDOUT_HELPERS="${TELAMON_ROOT}/src/functions/stdout.sh"

# ── Colour helpers + counters (same style as init.test.sh) ───────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; RESET='\033[0m'
PASS=0; FAIL=0
_pass() { echo -e "  ${GREEN}✔${RESET}  $1"; PASS=$((PASS + 1)); }
_fail() { echo -e "  ${RED}✖${RESET}  $1"; FAIL=$((FAIL + 1)); }
_section() { echo -e "\n${BOLD}$1${RESET}"; }

# ── Per-run scratch (everything under here is mktemp; cleanup on EXIT) ───────
SCRATCH_ROOT="$(mktemp -d)"
trap 'rm -rf "${SCRATCH_ROOT}"' EXIT

# ── 1. Extract the sentinel-delimited block from bin/init.sh ─────────────────
BLOCK_FILE="${SCRATCH_ROOT}/explore-block.sh"
awk '
  /# ──BEGIN telamon\.explore-project block──/ { begins++; in_block=1; next }
  /# ──END telamon\.explore-project block──/   { ends++;   in_block=0; next }
  in_block { print }
  END {
    if (begins != 1 || ends != 1) {
      printf "EXTRACTOR-ERROR: expected exactly 1 BEGIN and 1 END sentinel in %s; got BEGIN=%d END=%d\n", FILENAME, begins, ends > "/dev/stderr"
      exit 1
    }
  }
' "${INIT_SH}" > "${BLOCK_FILE}" || {
  echo -e "  ${RED}✖${RESET}  Failed to extract telamon.explore-project block from ${INIT_SH}" >&2
  exit 1
}

# Sanity-check: the extracted block must reference the canonical description path.
# If a future refactor moves the path, this test fails loudly so the developer
# updates both sides in lockstep.
if ! grep -qF '_DESC_FILE="${PROJ}/.ai/telamon/memory/project-rules/description.md"' "${BLOCK_FILE}"; then
  echo -e "  ${RED}✖${RESET}  Extracted block does not contain the expected _DESC_FILE assignment — sentinels or block contents drifted" >&2
  exit 1
fi
_pass "Extracted telamon.explore-project block from bin/init.sh ($(wc -l < "${BLOCK_FILE}") lines)"

# ── 2. Build the opencode stub once per run ──────────────────────────────────
STUB_DIR="${SCRATCH_ROOT}/stub-bin"
mkdir -p "${STUB_DIR}"
cat > "${STUB_DIR}/opencode" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
{
  printf 'argv-begin\n'
  printf '%s\n' "$@"
  printf 'argv-end\n'
} >> "${OPENCODE_STUB_LOG:?OPENCODE_STUB_LOG must be set by the test}"
if [[ "${OPENCODE_STUB_WRITE_DESC:-0}" == "1" ]] && [[ -n "${OPENCODE_STUB_DESC_PATH:-}" ]]; then
  mkdir -p "$(dirname "${OPENCODE_STUB_DESC_PATH}")"
  printf '%s\n' "# Stub project description (test fixture)" > "${OPENCODE_STUB_DESC_PATH}"
fi
exit "${OPENCODE_STUB_EXIT_CODE:-0}"
STUB
chmod +x "${STUB_DIR}/opencode"

# ── 3. Per-case runner: source the extracted block in a controlled shell ─────
#
# Strategy: spawn a fresh `bash` subshell that
#   (a) sources stdout.sh so header/info/log/warn are defined;
#   (b) exports PROJ (the only variable the extracted block reads beyond helpers);
#   (c) sets PATH to either include the stub dir or exclude opencode entirely;
#   (d) sources the extracted block.
# Captured stdout/stderr is the assertion surface. NO other init code runs.
_run_block() {
  local mode="$1"            # "with-opencode" | "without-opencode"
  local write_desc="$2"      # "1" → stub writes description.md; "0" → it does not
  local exit_code="$3"       # stub's exit code (string, e.g. "0" or "1")
  local seed_desc="$4"       # "missing" | "empty" | "populated" | "dangling-symlink" | "populated-via-symlink" | "empty-via-symlink"

  # Each case gets its own project tree AND its own storage-side dir, both under
  # SCRATCH_ROOT — NEVER under TELAMON_ROOT/storage/. This makes the symlink
  # cases hermetic.
  PROJ_DIR="$(mktemp -d -p "${SCRATCH_ROOT}")"
  STORAGE_PROJ="$(mktemp -d -p "${SCRATCH_ROOT}")"   # stands in for storage/projects-memory/<name>/
  STUB_LOG="$(mktemp -p "${SCRATCH_ROOT}")"
  CAPTURE="$(mktemp -p "${SCRATCH_ROOT}")"

  local desc_path="${PROJ_DIR}/.ai/telamon/memory/project-rules/description.md"
  local desc_dir; desc_dir="$(dirname "${desc_path}")"
  mkdir -p "${desc_dir}"

  case "${seed_desc}" in
    missing) : ;;  # nothing to do — description.md absent
    empty)
      : > "${desc_path}"
      ;;
    populated)
      printf '%s\n' "pre-existing content" > "${desc_path}"
      ;;
    dangling-symlink)
      ln -s "${SCRATCH_ROOT}/does-not-exist" "${desc_path}"
      ;;
    populated-via-symlink)
      mkdir -p "${STORAGE_PROJ}/project-rules"
      printf '%s\n' "pre-existing via symlink" > "${STORAGE_PROJ}/project-rules/description.md"
      # Replace the project-rules dir with a symlink to the storage-side dir,
      # mirroring MEMORY_OWNER=telamon's vault layout.
      rmdir "${desc_dir}"
      ln -s "${STORAGE_PROJ}/project-rules" "${desc_dir}"
      ;;
    empty-via-symlink)
      mkdir -p "${STORAGE_PROJ}/project-rules"
      : > "${STORAGE_PROJ}/project-rules/description.md"
      rmdir "${desc_dir}"
      ln -s "${STORAGE_PROJ}/project-rules" "${desc_dir}"
      ;;
    *)
      _fail "unknown seed_desc '${seed_desc}'"
      return
      ;;
  esac

  local path_for_run
  if [[ "${mode}" == "with-opencode" ]]; then
    path_for_run="${STUB_DIR}:${PATH}"
  else
    # Scrub opencode from PATH by listing only known-clean dirs.
    path_for_run="/usr/bin:/bin"
  fi

  # The "harness" subshell: minimal env, sources helpers + block, runs nothing else.
  PATH="${path_for_run}" \
  OPENCODE_STUB_LOG="${STUB_LOG}" \
  OPENCODE_STUB_WRITE_DESC="${write_desc}" \
  OPENCODE_STUB_EXIT_CODE="${exit_code}" \
  OPENCODE_STUB_DESC_PATH="${desc_path}" \
  PROJ="${PROJ_DIR}" \
  STDOUT_HELPERS="${STDOUT_HELPERS}" \
  BLOCK_FILE="${BLOCK_FILE}" \
    bash -c '
      set -euo pipefail
      # shellcheck disable=SC1090
      . "${STDOUT_HELPERS}"
      # shellcheck disable=SC1090
      . "${BLOCK_FILE}"
    ' > "${CAPTURE}" 2>&1 || true

  BLOCK_STDOUT="$(cat "${CAPTURE}")"
}

# ── 4. Assertion helpers ─────────────────────────────────────────────────────
_assert_stub_called()     { grep -q '^argv-begin$' "${STUB_LOG}" && _pass "$1" || _fail "$1 — stub log empty"; }
_assert_stub_not_called() { ! grep -q '^argv-begin$' "${STUB_LOG}" && _pass "$1" || _fail "$1 — stub log has entries"; }
_assert_argv_contains() {
  local needle="$1"; local label="$2"
  grep -qF -- "${needle}" "${STUB_LOG}" && _pass "${label}" || _fail "${label} — argv did not contain '${needle}'"
}
_assert_stdout_contains() {
  local needle="$1"; local label="$2"
  printf '%s' "${BLOCK_STDOUT}" | grep -qF -- "${needle}" && _pass "${label}" || _fail "${label} — stdout missing '${needle}'"
}

# ── 5. Test cases ────────────────────────────────────────────────────────────

_section "Case 1: fresh init, description.md missing → opencode invoked"
_run_block with-opencode 1 0 missing
_assert_stub_called                                  "opencode stub was invoked"
_assert_argv_contains "--agent"                      "--agent flag present in argv"
_assert_argv_contains "telamon"                      "telamon agent name present in argv"
_assert_argv_contains "--dir"                        "--dir flag present in argv"
_assert_argv_contains "${PROJ_DIR}"                  "<PROJ> value present in argv"
_assert_argv_contains "--dangerously-skip-permissions" "--dangerously-skip-permissions present in argv"
_assert_argv_contains "Use the telamon.explore-project skill to map this project and write the project description." "full prompt present as single argv token"
_assert_stdout_contains "Project exploration complete" "success log printed"

_section "Case 2: re-run with description.md already populated → opencode NOT invoked"
_run_block with-opencode 1 0 populated
_assert_stub_not_called      "opencode stub was NOT invoked"
_assert_stdout_contains "Project description already present — skipping exploration" "skip info printed"

_section "Case 3: description.md exists but is empty (zero bytes) → opencode invoked"
_run_block with-opencode 1 0 empty
_assert_stub_called          "opencode stub was invoked (empty file triggers exploration)"

_section "Case 4: opencode missing from PATH → warning, block exits cleanly"
_run_block without-opencode 0 0 missing
_assert_stdout_contains "opencode not on PATH" "missing-opencode warning printed"

_section "Case 5: MEMORY_OWNER=telamon analogue — populated symlinked target → skip"
_run_block with-opencode 1 0 populated-via-symlink
_assert_stub_not_called      "telamon-mode populated symlink → exploration skipped"

_section "Case 6: MEMORY_OWNER=telamon analogue — empty symlinked target → opencode invoked"
_run_block with-opencode 1 0 empty-via-symlink
_assert_stub_called          "telamon-mode empty symlink target → exploration invoked"

_section "Case 7: opencode exits non-zero → warn"
_run_block with-opencode 0 1 missing
_assert_stdout_contains "opencode run exited with non-zero status" "failure warn printed"

_section "Case 8: opencode exits 0 but description still empty → warn"
_run_block with-opencode 0 0 missing
_assert_stdout_contains "still empty" "post-condition failure warn printed"

_section "Case 9: dangling symlink at description.md → opencode invoked"
_run_block with-opencode 1 0 dangling-symlink
_assert_stub_called          "dangling symlink treated as missing → exploration invoked"

# ── 6. Summary ───────────────────────────────────────────────────────────────
echo
echo -e "${BOLD}────────────────────────────────────────────${RESET}"
if [[ "${FAIL}" -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}  ✔  All ${PASS} assertions passed.${RESET}"
  exit 0
else
  echo -e "${RED}${BOLD}  ✖  ${FAIL} assertion(s) failed, ${PASS} passed.${RESET}"
  exit 1
fi
