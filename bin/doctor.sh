#!/usr/bin/env bash
# =============================================================================
# bin/doctor.sh
# Comprehensive health check for the full ADK stack.
# Goes beyond `make status` — verifies tools are installed AND working.
#
# Usage:
#   bin/doctor.sh
#   make doctor
# =============================================================================

set -euo pipefail

ADK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_PATH="${ADK_ROOT}/src/install"
export INSTALL_PATH ADK_ROOT

# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/opt/homebrew/bin:/home/linuxbrew/.linuxbrew/bin:/usr/local/bin:$PATH"

PASS=0
FAIL=0
WARN_COUNT=0

_pass() { echo -e "  ${TEXT_GREEN}✔${TEXT_CLEAR}  $1"; PASS=$((PASS + 1)); }
_fail() { echo -e "  ${TEXT_RED}✖${TEXT_CLEAR}  $1"; FAIL=$((FAIL + 1)); }
_warn() { echo -e "  ${TEXT_YELLOW}⚠${TEXT_CLEAR}  $1"; WARN_COUNT=$((WARN_COUNT + 1)); }
_info() { echo -e "  ${TEXT_BLUE}ℹ${TEXT_CLEAR}  $1"; }

echo -e "\n${TEXT_BOLD}${TEXT_BLUE}"
echo "  ╔═════════════════════════════════════════════════╗"
echo "  ║   AI Agentic Development Kit — Doctor           ║"
echo "  ╚═════════════════════════════════════════════════╝"
echo -e "${TEXT_CLEAR}"

# ── 1. Core Infrastructure ────────────────────────────────────────────────────
header "Infrastructure"

# Docker daemon
if command -v docker &>/dev/null; then
  if docker info &>/dev/null 2>&1; then
    _pass "Docker daemon running ($(docker --version | grep -oP '\d+\.\d+\.\d+' | head -1))"
  else
    _fail "Docker installed but daemon is not running — run: sudo systemctl start docker"
  fi
else
  _fail "Docker not installed — run: make up"
fi

# Postgres container
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^ogham-postgres$"; then
  _pass "Postgres container running (ogham-postgres)"
  # Try a real connection test
  if docker exec ogham-postgres pg_isready -U ogham -d ogham &>/dev/null 2>&1; then
    _pass "Postgres accepting connections"
  else
    _warn "Postgres container running but not yet accepting connections"
  fi
else
  _fail "Postgres container not running — run: make up (or docker compose up -d)"
fi

# Ollama container
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^adk-ollama$"; then
  _pass "Ollama container running (adk-ollama)"
  # Check model is available
  if docker exec adk-ollama ollama list 2>/dev/null | grep -q "nomic-embed-text"; then
    _pass "nomic-embed-text model available"
  else
    _warn "nomic-embed-text model not yet pulled — Ollama init may still be running"
  fi
else
  _fail "Ollama container not running — run: make up"
fi

# ── 2. Host binaries ──────────────────────────────────────────────────────────
header "Host tools"

_check_binary() {
  local name="$1" cmd="$2" version_cmd="${3:-}"
  if command -v "${cmd}" &>/dev/null; then
    local ver=""
    if [[ -n "${version_cmd}" ]]; then
      ver=" ($(eval "${version_cmd}" 2>/dev/null | head -1 | grep -oP '[\d.]+' | head -1 || echo '?'))"
    fi
    _pass "${name}${ver}"
  else
    _fail "${name} not found — run: make up"
  fi
}

_check_binary "uv (Python tool manager)"  "uv"       "uv --version"
_check_binary "Node.js"                    "node"     "node --version"
_check_binary "npm"                        "npm"      "npm --version"
_check_binary "opencode"                   "opencode" "opencode --version"
_check_binary "ogham"                      "ogham"    "ogham --version"
_check_binary "graphify"                   "graphify" "graphify --version"
_check_binary "cass"                       "cass"     "cass --version"
_check_binary "rtk"                        "rtk"      "rtk --version"

# ── 3. Ogham health ───────────────────────────────────────────────────────────
header "Ogham (semantic memory)"

if command -v ogham &>/dev/null; then
  if ogham health &>/dev/null 2>&1; then
    _pass "Ogham ↔ Postgres: connected"
  else
    _fail "Ogham cannot connect to Postgres — run: make up"
  fi
else
  _fail "ogham not installed — run: make up"
fi

# ── 4. opencode config ────────────────────────────────────────────────────────
header "opencode config"

STORAGE_CONFIG="${ADK_ROOT}/storage/opencode.jsonc"
if [[ -f "${STORAGE_CONFIG}" ]]; then
  _pass "storage/opencode.jsonc present"

  # Check key MCP servers are registered (use proper JSONC tokenizer — not regex)
  _check_mcp() {
    local name="$1"
    if python3 - "${STORAGE_CONFIG}" "${name}" <<'PYEOF' 2>/dev/null
import sys, json

def strip_jsonc_comments(text):
    result = []
    i, n = 0, len(text)
    while i < n:
        if text[i] == '"':
            j = i + 1
            while j < n:
                if text[j] == '\\': j += 2
                elif text[j] == '"': j += 1; break
                else: j += 1
            result.append(text[i:j]); i = j
        elif text[i:i+2] == '//':
            j = text.find('\n', i)
            i = j if j != -1 else n
        elif text[i:i+2] == '/*':
            j = text.find('*/', i+2)
            i = j + 2 if j != -1 else n
        else:
            result.append(text[i]); i += 1
    return ''.join(result)

config_file, server_name = sys.argv[1], sys.argv[2]
with open(config_file) as f:
    data = json.loads(strip_jsonc_comments(f.read()))
assert server_name in data.get('mcp', {}), f"'{server_name}' not in mcp"
PYEOF
    then
      _pass "MCP server registered: ${name}"
    else
      _warn "MCP server '${name}' not in storage/opencode.jsonc — run: make up"
    fi
  }

  _check_mcp "ogham"
  _check_mcp "codebase-index"
  _check_mcp "obsidian"
  _check_mcp "websearch"
  _check_mcp "context7"
  _check_mcp "ast-grep"
  _check_mcp "git"
else
  _fail "storage/opencode.jsonc missing — run: make up"
fi

# ── 5. Secrets ─────────────────────────────────────────────────────────────────
header "Secrets"

SECRETS_DIR="${ADK_ROOT}/storage/secrets"
if [[ -d "${SECRETS_DIR}" ]]; then
  _pass "storage/secrets/ directory exists"
  for secret_name in "ogham-database-url"; do
    if [[ -f "${SECRETS_DIR}/${secret_name}" && -s "${SECRETS_DIR}/${secret_name}" ]]; then
      _pass "Secret file: ${secret_name}"
    else
      _warn "Secret file missing or empty: ${secret_name} — run: make up"
    fi
  done
else
  _fail "storage/secrets/ not found — run: make up"
fi

# ── 6. ADK storage layout ──────────────────────────────────────────────────────
header "Storage layout"

for d in "storage" "storage/state"; do
  if [[ -d "${ADK_ROOT}/${d}" ]]; then
    _pass "${d}/ exists"
  else
    _fail "${d}/ missing — run: make up"
  fi
done

if [[ -L "${ADK_ROOT}/graphify-out" ]]; then
  _pass "graphify-out → $(readlink "${ADK_ROOT}/graphify-out")"
else
  _warn "graphify-out symlink missing (graphify not yet run in this repo)"
fi

if [[ -L "${ADK_ROOT}/.ai/adk/secrets" ]]; then
  _pass ".ai/adk/secrets → $(readlink "${ADK_ROOT}/.ai/adk/secrets")"
else
  _warn ".ai/adk/secrets symlink missing"
fi

# ── 7. ADK skills & context ───────────────────────────────────────────────────
header "Skills & context"

[[ -d "${ADK_ROOT}/src/skills" ]]   && _pass "src/skills/ present"  || _fail "src/skills/ missing"
[[ -d "${ADK_ROOT}/src/context" ]]  && _pass "src/context/ present" || _fail "src/context/ missing"

skill_count=$(find "${ADK_ROOT}/src/skills" -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
context_count=$(find "${ADK_ROOT}/src/context" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
_info "${skill_count} skill(s) in src/skills/,  ${context_count} context doc(s) in src/context/"

# ── 8. .env ────────────────────────────────────────────────────────────────────
header ".env configuration"

ENV_FILE="${ADK_ROOT}/.env"
if [[ -f "${ENV_FILE}" ]]; then
  _pass ".env file present"

  pg_pass="$(grep -E "^POSTGRES_PASSWORD=" "${ENV_FILE}" | head -1 | cut -d= -f2- | tr -d '"'"'"' ' || true)"
  if [[ -n "${pg_pass}" && "${pg_pass}" != "REPLACE_WITH"* ]]; then
    _pass "POSTGRES_PASSWORD is set"
  else
    _warn "POSTGRES_PASSWORD not set in .env — edit .env before running make up"
  fi

  obsidian_key="$(grep -E "^OBSIDIAN_API_KEY=" "${ENV_FILE}" | head -1 | cut -d= -f2- | tr -d '"'"'"' ' || true)"
  if [[ -n "${obsidian_key}" && "${obsidian_key}" != "REPLACE_WITH"* ]]; then
    _pass "OBSIDIAN_API_KEY is set"
  else
    _warn "OBSIDIAN_API_KEY not set — obsidian MCP will be disabled until key is provided"
  fi
else
  _fail ".env not found — run: make up  (it copies .env.dist → .env automatically)"
fi

# ── Summary ────────────────────────────────────────────────────────────────────
echo
echo -e "${TEXT_BOLD}────────────────────────────────────────────────${TEXT_CLEAR}"
if [[ "${FAIL}" -eq 0 && "${WARN_COUNT}" -eq 0 ]]; then
  echo -e "${TEXT_GREEN}${TEXT_BOLD}  ✔  All ${PASS} checks passed. ADK is healthy.${TEXT_CLEAR}"
elif [[ "${FAIL}" -eq 0 ]]; then
  echo -e "${TEXT_YELLOW}${TEXT_BOLD}  ⚠  ${PASS} passed, ${WARN_COUNT} warning(s). ADK is mostly healthy.${TEXT_CLEAR}"
else
  echo -e "${TEXT_RED}${TEXT_BOLD}  ✖  ${FAIL} failure(s), ${WARN_COUNT} warning(s), ${PASS} passed.${TEXT_CLEAR}"
  echo -e "${TEXT_RED}${TEXT_BOLD}     Run 'make up' to fix failures.${TEXT_CLEAR}"
fi
echo -e "${TEXT_BOLD}────────────────────────────────────────────────${TEXT_CLEAR}"
echo

[[ "${FAIL}" -gt 0 ]] && exit 1 || exit 0
