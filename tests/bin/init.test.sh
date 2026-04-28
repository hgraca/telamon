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

TELAMON_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
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
echo -e "${BOLD}Telamon init assertions — project: ${PROJECT_NAME}${RESET}"
echo -e "${BOLD}Project path: ${PROJ}${RESET}"

# ── Read memory_owner from telamon.jsonc ──────────────────────────────────────
TELAMON_CFG="${PROJ}/.ai/telamon/telamon.jsonc"
MEMORY_OWNER="telamon"
OGHAM_DB="telamon"
if [[ -f "${TELAMON_CFG}" ]]; then
  _mo_val="$(python3 -c "
import json, re, sys
with open(sys.argv[1]) as f:
    d = json.loads(re.sub(r'(?m)(?<!:)//.*\$', '', f.read()))
print(d.get('memory_owner', ''))
" "${TELAMON_CFG}" 2>/dev/null || true)"
  [[ -n "${_mo_val}" ]] && MEMORY_OWNER="${_mo_val}"
  _ogham_val="$(python3 -c "
import json, re, sys
with open(sys.argv[1]) as f:
    d = json.loads(re.sub(r'(?m)(?<!:)//.*\$', '', f.read()))
print(d.get('ogham_db', ''))
" "${TELAMON_CFG}" 2>/dev/null || true)"
  [[ -n "${_ogham_val}" ]] && OGHAM_DB="${_ogham_val}"
fi

VAULT_TMPL="${TELAMON_ROOT}/src/skills/memory/memory-management/_tmpl"

# ── 1. Vault scaffold ─────────────────────────────────────────────────────────
if [[ "${MEMORY_OWNER}" == "project" ]]; then
  _section "1. Vault scaffold (.ai/telamon/memory/ — project mode)"
  VAULT_ROOT="${PROJ}/.ai/telamon/memory"
  BRAIN_DIR="${VAULT_ROOT}/brain"

  # In project mode, .ai/telamon/memory is a real directory
  assert_dir "${VAULT_ROOT}"                     ".ai/telamon/memory/ (real directory)"
  assert_dir "${BRAIN_DIR}"                      "brain/"
  assert_dir "${VAULT_ROOT}/work/active"         "work/active/"
  assert_dir "${VAULT_ROOT}/work/archive"        "work/archive/"
  assert_dir "${VAULT_ROOT}/work/incidents"      "work/incidents/"
  assert_dir "${VAULT_ROOT}/reference"           "reference/"
  assert_dir "${VAULT_ROOT}/thinking"            "thinking/"

  # Brain files with substituted placeholders must be real files (copied)
  assert_file "${BRAIN_DIR}/memories.md"         "brain/memories.md (real file)"
  assert_file "${BRAIN_DIR}/key_decisions.md"    "brain/key_decisions.md (real file)"
  assert_file "${BRAIN_DIR}/patterns.md"         "brain/patterns.md (real file)"
  assert_file "${BRAIN_DIR}/gotchas.md"          "brain/gotchas.md (real file)"
  assert_file_contains "${BRAIN_DIR}/memories.md"     "${PROJECT_NAME}" "memories.md contains project name"
  assert_file_contains "${BRAIN_DIR}/key_decisions.md" "${PROJECT_NAME}" "key_decisions.md contains project name"

  # Non-placeholder files must be symlinks pointing into _tmpl/
  assert_symlink "${VAULT_ROOT}/bootstrap/memory.md" \
    "_tmpl/bootstrap/memory.md" \
    "bootstrap/memory.md → _tmpl source"
  assert_symlink "${VAULT_ROOT}/bootstrap/mcp.md" \
    "_tmpl/bootstrap/mcp.md" \
    "bootstrap/mcp.md → _tmpl source"

  # storage/obsidian/<proj> must be a symlink pointing to the project vault
  assert_symlink "${TELAMON_ROOT}/storage/obsidian/${PROJECT_NAME}" \
    ".ai/telamon/memory" \
    "storage/obsidian/${PROJECT_NAME} → .ai/telamon/memory"
else
  _section "1. Vault scaffold (storage/obsidian/${PROJECT_NAME}/ — telamon mode)"
  VAULT_ROOT="${TELAMON_ROOT}/storage/obsidian/${PROJECT_NAME}"
  BRAIN_DIR="${VAULT_ROOT}/brain"

  # Dirs must be real directories (not symlinks)
  assert_dir "${VAULT_ROOT}"                     "storage/obsidian/${PROJECT_NAME}/"
  assert_dir "${BRAIN_DIR}"                      "brain/"
  assert_dir "${VAULT_ROOT}/work/active"         "work/active/"
  assert_dir "${VAULT_ROOT}/work/archive"        "work/archive/"
  assert_dir "${VAULT_ROOT}/work/incidents"      "work/incidents/"
  assert_dir "${VAULT_ROOT}/reference"           "reference/"
  assert_dir "${VAULT_ROOT}/thinking"            "thinking/"

  # Brain files with substituted placeholders must be real files (copied)
  assert_file "${BRAIN_DIR}/memories.md"         "brain/memories.md (real file)"
  assert_file "${BRAIN_DIR}/key_decisions.md"    "brain/key_decisions.md (real file)"
  assert_file "${BRAIN_DIR}/patterns.md"         "brain/patterns.md (real file)"
  assert_file "${BRAIN_DIR}/gotchas.md"          "brain/gotchas.md (real file)"
  assert_file_contains "${BRAIN_DIR}/memories.md"     "${PROJECT_NAME}" "memories.md contains project name"
  assert_file_contains "${BRAIN_DIR}/key_decisions.md" "${PROJECT_NAME}" "key_decisions.md contains project name"

  # Non-placeholder files must be symlinks pointing into _tmpl/
  assert_symlink "${VAULT_ROOT}/bootstrap/memory.md" \
    "_tmpl/bootstrap/memory.md" \
    "bootstrap/memory.md → _tmpl source"
  assert_symlink "${VAULT_ROOT}/bootstrap/mcp.md" \
    "_tmpl/bootstrap/mcp.md" \
    "bootstrap/mcp.md → _tmpl source"
fi

# ── 2. .opencode/skills/telamon symlink ──────────────────────────────────────────
_section "2. .opencode/skills/telamon symlink"
assert_dir  "${PROJ}/.opencode/skills" ".opencode/skills/ directory"
assert_symlink "${PROJ}/.opencode/skills/telamon" "src/skills" \
  ".opencode/skills/telamon → <telamon-root>/src/skills"

# ── 3. .ai/telamon/telamon.jsonc ──────────────────────────────────────────────────────
_section "3. .ai/telamon/telamon.jsonc"
assert_file "${PROJ}/.ai/telamon/telamon.jsonc" ".ai/telamon/telamon.jsonc"
assert_file_contains "${PROJ}/.ai/telamon/telamon.jsonc" "\"project_name\"" \
  ".ai/telamon/telamon.jsonc contains project_name key"
assert_file_contains "${PROJ}/.ai/telamon/telamon.jsonc" "\"${PROJECT_NAME}\"" \
  ".ai/telamon/telamon.jsonc contains correct project_name value"
assert_file_contains "${PROJ}/.ai/telamon/telamon.jsonc" "\"rtk_enabled\": false" \
  ".ai/telamon/telamon.jsonc has rtk_enabled: false"
assert_file_contains "${PROJ}/.ai/telamon/telamon.jsonc" "\"caveman_enabled\": false" \
  ".ai/telamon/telamon.jsonc has caveman_enabled: false"
assert_file_contains "${PROJ}/.ai/telamon/telamon.jsonc" "\"memory_owner\"" \
  ".ai/telamon/telamon.jsonc has memory_owner key"
assert_file_contains "${PROJ}/.ai/telamon/telamon.jsonc" "\"ogham_db\"" \
  ".ai/telamon/telamon.jsonc has ogham_db key"

# ── 5. .ai/telamon/secrets directory ─────────────────────────────────────────
_section "5. .ai/telamon/secrets"
SECRETS_DIR="${PROJ}/.ai/telamon/secrets"

# Must be a real directory, not a symlink
if [[ -d "${SECRETS_DIR}" && ! -L "${SECRETS_DIR}" ]]; then
  _pass ".ai/telamon/secrets is a real directory (not a symlink)"
else
  _fail ".ai/telamon/secrets — expected a real directory, got: $(ls -lad "${SECRETS_DIR}" 2>/dev/null || echo 'missing')"
fi

# Each global secret must have a symlink in the per-project directory
_GLOBAL_SECRETS_DIR="${TELAMON_ROOT}/storage/secrets"
for _sf in "${_GLOBAL_SECRETS_DIR}"/*; do
  [[ -f "${_sf}" ]] || continue
  _sn="$(basename "${_sf}")"
  _sl="${SECRETS_DIR}/${_sn}"
  if [[ "${_sn}" == "ogham-database-url" ]]; then
    # Handled separately below based on ogham_db mode
    continue
  fi
  if [[ -L "${_sl}" ]]; then
    _pass "secret symlink: ${_sn}"
  else
    _fail "secret symlink: ${_sn} — expected a symlink at ${_sl}"
  fi
done

# ogham-database-url: mode-dependent assertion
if [[ "${OGHAM_DB}" == "external" ]]; then
  # External mode: must be a real file (not a symlink)
  if [[ -f "${SECRETS_DIR}/ogham-database-url" && ! -L "${SECRETS_DIR}/ogham-database-url" ]]; then
    _pass "ogham-database-url is a real file (external DB mode)"
  else
    _fail "ogham-database-url — expected a real file in external mode, got: $(ls -lad "${SECRETS_DIR}/ogham-database-url" 2>/dev/null || echo 'missing')"
  fi
else
  # Telamon mode: must be a symlink to storage/secrets/ogham-database-url
  assert_symlink "${SECRETS_DIR}/ogham-database-url" "storage/secrets/ogham-database-url" \
    "ogham-database-url → storage/secrets/ogham-database-url (telamon mode)"
fi

# ── 5b. memory symlink — mode-dependent ──────────────────────────────────────
_section "5b. .ai/telamon/memory (${MEMORY_OWNER} mode)"
if [[ "${MEMORY_OWNER}" == "project" ]]; then
  # Project mode: .ai/telamon/memory is a real directory (already asserted in section 1)
  if [[ -d "${PROJ}/.ai/telamon/memory" && ! -L "${PROJ}/.ai/telamon/memory" ]]; then
    _pass ".ai/telamon/memory is a real directory (project mode)"
  else
    _fail ".ai/telamon/memory — expected a real directory in project mode"
  fi
  assert_symlink "${TELAMON_ROOT}/storage/obsidian/${PROJECT_NAME}" \
    ".ai/telamon/memory" \
    "storage/obsidian/${PROJECT_NAME} → .ai/telamon/memory (already checked in section 1)"
else
  assert_symlink "${PROJ}/.ai/telamon/memory" \
    "storage/obsidian/${PROJECT_NAME}" \
    ".ai/telamon/memory → <telamon-root>/storage/obsidian/${PROJECT_NAME}"
fi

# ── 6. opencode config ────────────────────────────────────────────────────────
_section "6. opencode.jsonc"
OPENCODE_CONFIG=""
for _candidate in "${PROJ}/opencode.jsonc" "${PROJ}/opencode.json"; do
  if [[ -e "${_candidate}" || -L "${_candidate}" ]]; then
    OPENCODE_CONFIG="${_candidate}"
    break
  fi
done

if [[ -z "${OPENCODE_CONFIG}" ]]; then
  # Check if storage/opencode.jsonc exists — if not, this is expected pre-make-up
  if [[ ! -f "${TELAMON_ROOT}/storage/opencode.jsonc" ]]; then
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
    # Existing-file path: must contain Telamon mcp servers after merge
    assert_file "${OPENCODE_CONFIG}" "$(basename "${OPENCODE_CONFIG}") (file)"
    assert_json_key "${OPENCODE_CONFIG}" "mcp.websearch.type" "remote" \
      "mcp.websearch.type == remote (Telamon MCP merged)"
    assert_json_key "${OPENCODE_CONFIG}" "mcp.context7.type" "remote" \
      "mcp.context7.type == remote (Telamon MCP merged)"
    assert_json_key "${OPENCODE_CONFIG}" "mcp.git.type" "local" \
      "mcp.git.type == local (Telamon MCP merged)"
  fi
fi

# ── 7. .opencode/codebase-index.json ─────────────────────────────────────────
_section "7. .opencode/codebase-index.json"
INDEX_JSON="${PROJ}/.opencode/codebase-index.json"
assert_file "${INDEX_JSON}" ".opencode/codebase-index.json"
assert_json_key "${INDEX_JSON}" "embeddingProvider" "custom" \
  "codebase-index.json: embeddingProvider == custom"
assert_json_key "${INDEX_JSON}" "indexing.autoIndex" "True" \
  "codebase-index.json: indexing.autoIndex == true"

# ── 8. AGENTS.md ──────────────────────────────────────────────────────────────
_section "8. AGENTS.md"
assert_symlink "${PROJ}/AGENTS.md" "storage/AGENTS.shared.md" \
  "AGENTS.md → storage/AGENTS.shared.md"
assert_file "${TELAMON_ROOT}/storage/AGENTS.shared.md" \
  "storage/AGENTS.shared.md (storage copy)"

# ── 9. Discord config ─────────────────────────────────────────────────────────
_section "9. Discord config"
# discord_enabled should be present in telamon.jsonc (either true or false)
assert_file_contains "${PROJ}/.ai/telamon/telamon.jsonc" "\"discord_enabled\"" \
  ".ai/telamon/telamon.jsonc has discord_enabled key"

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
