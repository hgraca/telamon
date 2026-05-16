#!/usr/bin/env bash
# Integration test: codebase-index init.sh injects `include` key based on src/ or app/ presence.
# Tests are expected to FAIL until init.sh is modified by a developer.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INIT_SH="${REPO_ROOT}/src/modules/codebase-index/init.sh"
FUNCTIONS_PATH="${REPO_ROOT}/src/functions"
export FUNCTIONS_PATH

# ── Mock Telamon helper functions so init.sh can run without full environment ──
header() { :; }
skip()   { echo "[skip] $*"; exit 0; }
log()    { :; }
info()   { :; }
step()   { :; }
warn()   { :; }
install_telamon_hook() { :; }
export -f header skip log info step warn install_telamon_hook

# Override autoload.sh sourcing: provide a stub that exports the mocks above
# by pointing FUNCTIONS_PATH to a temp dir with a no-op autoload.sh
MOCK_FUNCTIONS_DIR="$(mktemp -d)"
cat > "${MOCK_FUNCTIONS_DIR}/autoload.sh" <<'AUTOLOAD'
#!/usr/bin/env bash
header() { :; }
skip()   { echo "[skip] $*"; exit 0; }
log()    { :; }
info()   { :; }
step()   { :; }
warn()   { :; }
install_telamon_hook() { :; }
AUTOLOAD
export FUNCTIONS_PATH="${MOCK_FUNCTIONS_DIR}"

# ── Temp dir management ────────────────────────────────────────────────────────
TEMP_DIRS=()
make_project_dir() {
  local d
  d="$(mktemp -d)"
  TEMP_DIRS+=("${d}")
  echo "${d}"
}

cleanup() {
  for d in "${TEMP_DIRS[@]+"${TEMP_DIRS[@]}"}"; do
    rm -rf "${d}"
  done
  rm -rf "${MOCK_FUNCTIONS_DIR}"
}
trap cleanup EXIT

# ── Test runner helpers ────────────────────────────────────────────────────────
PASS_COUNT=0
FAIL_COUNT=0
FAILURES=()

pass() { echo "PASS: $1"; (( PASS_COUNT++ )) || true; }
fail() { echo "FAIL: $1"; FAILURES+=("$1"); (( FAIL_COUNT++ )) || true; }

run_init() {
  local proj_dir="$1"
  # Run init.sh with cwd = project dir; suppress index-build (node/ollama absent in CI)
  (cd "${proj_dir}" && bash "${INIT_SH}") 2>/dev/null || true
}

# ── Case 1: src/ exists, no prior config ──────────────────────────────────────
case1() {
  local proj
  proj="$(make_project_dir)"
  mkdir -p "${proj}/src"

  run_init "${proj}"

  local cfg="${proj}/.opencode/codebase-index.json"
  if [[ ! -f "${cfg}" ]]; then
    fail "Case 1: config file not created"
    return
  fi

  local has_include has_src has_app
  has_include=$(grep -c '"include"' "${cfg}" || true)
  has_src=$(grep -c 'src/\*\*/\*' "${cfg}" || true)
  has_app=$(grep -c 'app/\*\*/\*' "${cfg}" || true)

  if [[ "${has_include}" -eq 0 ]]; then
    fail "Case 1: 'include' key missing (src/ exists, no prior config)"
  elif [[ "${has_src}" -eq 0 ]]; then
    fail "Case 1: 'src/**/*' pattern missing"
  elif [[ "${has_app}" -gt 0 ]]; then
    fail "Case 1: 'app/**/*' pattern present but should not be"
  else
    pass "Case 1: src/ exists, no prior config → include with src/**/* injected"
  fi
}

# ── Case 2: app/ exists, no prior config ──────────────────────────────────────
case2() {
  local proj
  proj="$(make_project_dir)"
  mkdir -p "${proj}/app"

  run_init "${proj}"

  local cfg="${proj}/.opencode/codebase-index.json"
  if [[ ! -f "${cfg}" ]]; then
    fail "Case 2: config file not created"
    return
  fi

  local has_include has_src has_app
  has_include=$(grep -c '"include"' "${cfg}" || true)
  has_src=$(grep -c 'src/\*\*/\*' "${cfg}" || true)
  has_app=$(grep -c 'app/\*\*/\*' "${cfg}" || true)

  if [[ "${has_include}" -eq 0 ]]; then
    fail "Case 2: 'include' key missing (app/ exists, no prior config)"
  elif [[ "${has_app}" -eq 0 ]]; then
    fail "Case 2: 'app/**/*' pattern missing"
  elif [[ "${has_src}" -gt 0 ]]; then
    fail "Case 2: 'src/**/*' pattern present but should not be"
  else
    pass "Case 2: app/ exists, no prior config → include with app/**/* injected"
  fi
}

# ── Case 3: neither src/ nor app/ exists, no prior config ─────────────────────
case3() {
  local proj
  proj="$(make_project_dir)"
  # No src/ or app/ created

  run_init "${proj}"

  local cfg="${proj}/.opencode/codebase-index.json"
  if [[ ! -f "${cfg}" ]]; then
    fail "Case 3: config file not created"
    return
  fi

  local has_include
  has_include=$(grep -c '"include"' "${cfg}" || true)

  if [[ "${has_include}" -gt 0 ]]; then
    fail "Case 3: 'include' key present but should not be (neither src/ nor app/ exists)"
  else
    pass "Case 3: neither src/ nor app/ → no include key (uses defaults)"
  fi
}

# ── Case 4: src/ exists, config already has include key ───────────────────────
case4() {
  local proj
  proj="$(make_project_dir)"
  mkdir -p "${proj}/src"
  mkdir -p "${proj}/.opencode"

  local existing_include='["custom/**/*"]'
  cat > "${proj}/.opencode/codebase-index.json" <<JSON
{
  "embeddingProvider": "custom",
  "include": ${existing_include}
}
JSON

  run_init "${proj}"

  local cfg="${proj}/.opencode/codebase-index.json"
  local preserved
  preserved=$(grep -c '"custom/\*\*/\*"' "${cfg}" || true)
  local has_src
  has_src=$(grep -c 'src/\*\*/\*' "${cfg}" || true)

  if [[ "${preserved}" -eq 0 ]]; then
    fail "Case 4: existing include value was overwritten (should be preserved)"
  elif [[ "${has_src}" -gt 0 ]]; then
    fail "Case 4: src/**/* was injected despite include already present"
  else
    pass "Case 4: config already has include → existing value preserved unchanged"
  fi
}

# ── Case 5: config exists with no include key, src/ exists ────────────────────
case5() {
  local proj
  proj="$(make_project_dir)"
  mkdir -p "${proj}/src"
  mkdir -p "${proj}/.opencode"

  cat > "${proj}/.opencode/codebase-index.json" <<'JSON'
{
  "embeddingProvider": "custom",
  "customProvider": {
    "baseUrl": "http://127.0.0.1:17434/v1",
    "model": "nomic-embed-text"
  }
}
JSON

  run_init "${proj}"

  local cfg="${proj}/.opencode/codebase-index.json"
  local has_include has_src
  has_include=$(grep -c '"include"' "${cfg}" || true)
  has_src=$(grep -c 'src/\*\*/\*' "${cfg}" || true)

  if [[ "${has_include}" -eq 0 ]]; then
    fail "Case 5: 'include' key not injected into existing config that lacked it"
  elif [[ "${has_src}" -eq 0 ]]; then
    fail "Case 5: 'src/**/*' pattern missing from injected include"
  else
    pass "Case 5: existing config without include + src/ → include injected"
  fi
}

# ── Case 6: both src/ and app/ exist → src/ wins ─────────────────────────────
case6() {
  local proj
  proj="$(make_project_dir)"
  mkdir -p "${proj}/src"
  mkdir -p "${proj}/app"

  run_init "${proj}"

  local cfg="${proj}/.opencode/codebase-index.json"
  if [[ ! -f "${cfg}" ]]; then
    fail "Case 6: config file not created"
    return
  fi

  local has_src has_app
  has_src=$(grep -c 'src/\*\*/\*' "${cfg}" || true)
  has_app=$(grep -c 'app/\*\*/\*' "${cfg}" || true)

  if [[ "${has_src}" -eq 0 ]]; then
    fail "Case 6: 'src/**/*' pattern missing (src/ should win over app/)"
  elif [[ "${has_app}" -gt 0 ]]; then
    fail "Case 6: 'app/**/*' pattern present but src/ should win"
  else
    pass "Case 6: both src/ and app/ present → src/ wins, no app/**/* patterns"
  fi
}

# ── Case 7: config exists without include, app/ exists (no src/) ──────────────
case7() {
  local proj
  proj="$(make_project_dir)"
  mkdir -p "${proj}/app"
  mkdir -p "${proj}/.opencode"

  cat > "${proj}/.opencode/codebase-index.json" <<'JSON'
{
  "embeddingProvider": "custom",
  "customProvider": {
    "baseUrl": "http://127.0.0.1:17434/v1",
    "model": "nomic-embed-text"
  }
}
JSON

  run_init "${proj}"

  local cfg="${proj}/.opencode/codebase-index.json"
  local has_include has_app
  has_include=$(grep -c '"include"' "${cfg}" || true)
  has_app=$(grep -c 'app/\*\*/\*' "${cfg}" || true)

  if [[ "${has_include}" -eq 0 ]]; then
    fail "Case 7: 'include' key not injected into existing config that lacked it"
  elif [[ "${has_app}" -eq 0 ]]; then
    fail "Case 7: 'app/**/*' pattern missing from injected include"
  else
    pass "Case 7: existing config without include + app/ (no src/) → app/**/* injected"
  fi
}

# ── Case 8: idempotency of patch path ─────────────────────────────────────────
case8() {
  local proj
  proj="$(make_project_dir)"
  mkdir -p "${proj}/src"
  mkdir -p "${proj}/.opencode"

  cat > "${proj}/.opencode/codebase-index.json" <<'JSON'
{
  "embeddingProvider": "custom",
  "customProvider": {
    "baseUrl": "http://127.0.0.1:17434/v1",
    "model": "nomic-embed-text"
  }
}
JSON

  # First run: patches include into config
  run_init "${proj}"

  local cfg="${proj}/.opencode/codebase-index.json"
  local has_include_after_first
  has_include_after_first=$(grep -c '"include"' "${cfg}" || true)
  if [[ "${has_include_after_first}" -eq 0 ]]; then
    fail "Case 8: 'include' key not injected on first run"
    return
  fi

  # Capture include value after first run
  local include_after_first
  include_after_first=$(jq '.include' "${cfg}")

  # Second run: should skip (config now has include key)
  run_init "${proj}"

  local include_after_second
  include_after_second=$(jq '.include' "${cfg}")

  if [[ "${include_after_first}" != "${include_after_second}" ]]; then
    fail "Case 8: include value changed on second run (not idempotent)"
  else
    pass "Case 8: second run on config with include → skipped, value unchanged"
  fi
}

# ── Run all cases ──────────────────────────────────────────────────────────────
echo "=== codebase-index src-scope integration tests ==="
echo ""
case1
case2
case3
case4
case5
case6
case7
case8
echo ""
echo "Results: ${PASS_COUNT} passed, ${FAIL_COUNT} failed"

if [[ "${FAIL_COUNT}" -gt 0 ]]; then
  echo ""
  echo "Failed cases:"
  for f in "${FAILURES[@]}"; do
    echo "  - ${f}"
  done
  exit 1
fi

exit 0
