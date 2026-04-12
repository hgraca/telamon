#!/usr/bin/env bash
# =============================================================================
# test/test-init.sh
# Assert that `make init PROJ=<proj>` produced the correct wiring.
#
# Usage:
#   bash test/test-init.sh <proj-path> <project-name>
#
# Exit code:
#   0 — all assertions passed
#   1 — one or more assertions failed
# =============================================================================

set -euo pipefail

ADK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJ="${1:-}"
PROJECT_NAME="${2:-}"

if [[ -z "${PROJ}" || -z "${PROJECT_NAME}" ]]; then
  echo "Usage: $0 <proj-path> <project-name>" >&2
  exit 1
fi

PROJ="$(cd "${PROJ}" && pwd)"

# ── Colour helpers ─────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
RESET='\033[0m'

PASS=0
FAIL=0

_pass() { echo -e "  ${GREEN}✔${RESET}  $1"; PASS=$((PASS + 1)); }
_fail() { echo -e "  ${RED}✖${RESET}  $1"; FAIL=$((FAIL + 1)); }
_warn() { echo -e "  ${YELLOW}⚠${RESET}  $1"; }
_section() { echo -e "\n${BOLD}$1${RESET}"; }

# ── Assertion helpers ──────────────────────────────────────────────────────────

# assert_symlink <path> <expected-target>
# Passes if <path> is a symlink whose resolved target ends with <expected-target>.
assert_symlink() {
  local path="$1"
  local expected_suffix="$2"
  local label="${3:-${path}}"

  if [[ ! -L "${path}" ]]; then
    _fail "${label} — expected a symlink, got: $(ls -lad "${path}" 2>/dev/null || echo 'missing')"
    return
  fi

  local target
  target="$(readlink -f "${path}")"
  if [[ "${target}" == *"${expected_suffix}" ]]; then
    _pass "${label} → ${target}"
  else
    _fail "${label} — symlink target '${target}' does not end with '${expected_suffix}'"
  fi
}

# assert_symlink_target <path> <exact-target>
# Passes if readlink (without -f) of <path> equals <exact-target>.
assert_symlink_target() {
  local path="$1"
  local expected="$2"
  local label="${3:-${path}}"

  if [[ ! -L "${path}" ]]; then
    _fail "${label} — expected a symlink, got: $(ls -lad "${path}" 2>/dev/null || echo 'missing')"
    return
  fi

  local target
  target="$(readlink "${path}")"
  if [[ "${target}" == "${expected}" ]]; then
    _pass "${label} → ${target}"
  else
    _fail "${label} — symlink target '${target}' != expected '${expected}'"
  fi
}

# assert_file <path>
# Passes if <path> is a regular file.
assert_file() {
  local path="$1"
  local label="${2:-${path}}"
  if [[ -f "${path}" ]]; then
    _pass "${label} (file exists)"
  else
    _fail "${label} — regular file not found"
  fi
}

# assert_dir <path>
# Passes if <path> is a directory.
assert_dir() {
  local path="$1"
  local label="${2:-${path}}"
  if [[ -d "${path}" ]]; then
    _pass "${label} (directory exists)"
  else
    _fail "${label} — directory not found"
  fi
}

# assert_file_contains <path> <pattern>
# Passes if <path> is a regular file and contains <pattern> (grep -q).
assert_file_contains() {
  local path="$1"
  local pattern="$2"
  local label="${3:-${path} contains '${pattern}'}"
  if [[ ! -f "${path}" ]]; then
    _fail "${label} — file not found: ${path}"
    return
  fi
  if grep -q "${pattern}" "${path}"; then
    _pass "${label}"
  else
    _fail "${label} — pattern not found in file"
  fi
}

# assert_json_key <path> <jq-filter> <expected>
# Passes if the JSON value at <jq-filter> equals <expected>.
# <jq-filter> is a dot-notation key path, e.g. "embeddingProvider" or "indexing.autoIndex"
assert_json_key() {
  local path="$1"
  local key_path="$2"
  local expected="$3"
  local label="${4:-${path}: ${key_path} == ${expected}}"
  if [[ ! -f "${path}" ]]; then
    _fail "${label} — file not found: ${path}"
    return
  fi
  local actual
  actual="$(python3 - "${path}" "${key_path}" <<'PYEOF'
import json, sys

def get_nested(obj, key_path):
    keys = key_path.split(".")
    for k in keys:
        if isinstance(obj, dict):
            obj = obj.get(k)
        else:
            return None
    return obj

data = json.load(open(sys.argv[1]))
val = get_nested(data, sys.argv[2])
print(str(val))
PYEOF
)" 2>/dev/null || echo '__ERROR__'
  if [[ "${actual}" == "${expected}" ]]; then
    _pass "${label}"
  else
    _fail "${label} — got '${actual}'"
  fi
}

# ── Tests ──────────────────────────────────────────────────────────────────────

echo
echo -e "${BOLD}ADK init assertions — project: ${PROJECT_NAME}${RESET}"
echo -e "${BOLD}Project path: ${PROJ}${RESET}"

# ── 1. Brain scaffold (in ADK storage, not in project) ────────────────────────
_section "1. Brain scaffold (storage/${PROJECT_NAME}/brain/)"
BRAIN_DIR="${ADK_ROOT}/storage/${PROJECT_NAME}/brain"

assert_dir  "${BRAIN_DIR}"                       "storage/${PROJECT_NAME}/brain/"
assert_file "${BRAIN_DIR}/NorthStar.md"          "storage/${PROJECT_NAME}/brain/NorthStar.md"
assert_file "${BRAIN_DIR}/KeyDecisions.md"       "storage/${PROJECT_NAME}/brain/KeyDecisions.md"
assert_file "${BRAIN_DIR}/Patterns.md"           "storage/${PROJECT_NAME}/brain/Patterns.md"
assert_file "${BRAIN_DIR}/Gotchas.md"            "storage/${PROJECT_NAME}/brain/Gotchas.md"
assert_file_contains "${BRAIN_DIR}/NorthStar.md"    "${PROJECT_NAME}" \
  "NorthStar.md contains project name"
assert_file_contains "${BRAIN_DIR}/KeyDecisions.md" "${PROJECT_NAME}" \
  "KeyDecisions.md contains project name"

# ── 2. .ai/context/adk symlink ───────────────────────────────────────────────
_section "2. .ai/context/adk symlink"
assert_dir  "${PROJ}/.ai/context" ".ai/context/ directory"
assert_symlink "${PROJ}/.ai/context/adk" "src/context" \
  ".ai/context/adk → <adk-root>/src/context"

# ── 3. .opencode/skills/adk symlink ──────────────────────────────────────────
_section "3. .opencode/skills/adk symlink"
assert_dir  "${PROJ}/.opencode/skills" ".opencode/skills/ directory"
assert_symlink "${PROJ}/.opencode/skills/adk" "src/skills" \
  ".opencode/skills/adk → <adk-root>/src/skills"

# ── 4. .ai/adk.ini ────────────────────────────────────────────────────────────
_section "4. .ai/adk.ini"
assert_file "${PROJ}/.ai/adk.ini" ".ai/adk.ini"
assert_file_contains "${PROJ}/.ai/adk.ini" "project_name = ${PROJECT_NAME}" \
  ".ai/adk.ini contains correct project_name"
assert_file_contains "${PROJ}/.ai/adk.ini" "\[adk\]" \
  ".ai/adk.ini has [adk] section"

# ── 5. opencode config ────────────────────────────────────────────────────────
_section "5. opencode.jsonc"
OPENCODE_CONFIG=""
for _candidate in "${PROJ}/opencode.jsonc" "${PROJ}/opencode.json"; do
  if [[ -e "${_candidate}" || -L "${_candidate}" ]]; then
    OPENCODE_CONFIG="${_candidate}"
    break
  fi
done

if [[ -z "${OPENCODE_CONFIG}" ]]; then
  # Check if storage/opencode.jsonc exists — if not, this is expected pre-make-up
  if [[ ! -f "${ADK_ROOT}/storage/opencode.jsonc" ]]; then
    _warn "opencode.jsonc skipped — storage/opencode.jsonc does not exist yet (run 'make up' first)"
  else
    _fail "opencode.jsonc or opencode.json — neither found in project root"
  fi
else
  if [[ -L "${OPENCODE_CONFIG}" ]]; then
    # Empty-project path: must be a symlink to storage/opencode.jsonc
    assert_symlink "${OPENCODE_CONFIG}" "storage/opencode.jsonc" \
      "$(basename "${OPENCODE_CONFIG}") → storage/opencode.jsonc"
  else
    # Existing-file path: must contain ADK mcp servers after merge
    assert_file "${OPENCODE_CONFIG}" "$(basename "${OPENCODE_CONFIG}") (file)"
    assert_json_key "${OPENCODE_CONFIG}" "mcp.websearch.type" "remote" \
      "mcp.websearch.type == remote (ADK MCP merged)"
    assert_json_key "${OPENCODE_CONFIG}" "mcp.context7.type" "remote" \
      "mcp.context7.type == remote (ADK MCP merged)"
    assert_json_key "${OPENCODE_CONFIG}" "mcp.git.type" "local" \
      "mcp.git.type == local (ADK MCP merged)"
  fi
fi

# ── 6. .opencode/codebase-index.json ─────────────────────────────────────────
_section "6. .opencode/codebase-index.json"
INDEX_JSON="${PROJ}/.opencode/codebase-index.json"
assert_file "${INDEX_JSON}" ".opencode/codebase-index.json"
assert_json_key "${INDEX_JSON}" "embeddingProvider" "ollama" \
  "codebase-index.json: embeddingProvider == ollama"
assert_json_key "${INDEX_JSON}" "indexing.autoIndex" "True" \
  "codebase-index.json: indexing.autoIndex == true"

# ── Summary ───────────────────────────────────────────────────────────────────
echo
echo -e "${BOLD}────────────────────────────────────────────${RESET}"
if [[ "${FAIL}" -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}  ✔  All ${PASS} assertions passed.${RESET}"
  echo -e "${BOLD}────────────────────────────────────────────${RESET}"
  echo
  exit 0
else
  echo -e "${RED}${BOLD}  ✖  ${FAIL} assertion(s) failed, ${PASS} passed.${RESET}"
  echo -e "${BOLD}────────────────────────────────────────────${RESET}"
  echo
  exit 1
fi
