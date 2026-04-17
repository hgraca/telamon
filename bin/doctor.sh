#!/usr/bin/env bash
# =============================================================================
# bin/doctor.sh
# Comprehensive health check for the full Telamon stack.
# Goes beyond `make status` — verifies tools are installed AND working.
#
# Usage:
#   bin/doctor.sh
#   make doctor
# =============================================================================

set -euo pipefail

TELAMON_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_PATH="${TELAMON_ROOT}/src/install"
export INSTALL_PATH TELAMON_ROOT

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
echo "  ║   Telamon — Harness for Agentic Software Development           ║"
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
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^telamon-ollama$"; then
  _pass "Ollama container running (telamon-ollama)"
  # Check model is available
  if docker exec telamon-ollama ollama list 2>/dev/null | grep -q "nomic-embed-text"; then
    _pass "nomic-embed-text model available"
  else
    _warn "nomic-embed-text model not yet pulled — Ollama init may still be running"
  fi
else
  _fail "Ollama container not running — run: make up"
fi

# ── Optional: Langfuse ────────────────────────────────────────────────────────
if env.is_enabled LANGFUSE_ENABLED; then
  header "Langfuse (LLM observability)"

  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^telamon-langfuse-db$"; then
    _pass "Langfuse Postgres container running (telamon-langfuse-db)"
  else
    _fail "Langfuse Postgres container not running — run: make up (LANGFUSE_ENABLED=true)"
  fi

  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^telamon-langfuse-web$"; then
    _pass "Langfuse web container running (telamon-langfuse-web)"
    # HTTP health check — use _warn since the service may still be starting
    if wget -qO- http://localhost:4000/api/public/health &>/dev/null 2>&1; then
      _pass "Langfuse HTTP health: http://localhost:4000/api/public/health"
    else
      _warn "Langfuse HTTP health check failed — service may still be starting"
    fi
  else
    _fail "Langfuse web container not running — run: make up (LANGFUSE_ENABLED=true)"
  fi

  # .env secret checks
  ENV_FILE_LF="${TELAMON_ROOT}/.env"
  if [[ -f "${ENV_FILE_LF}" ]]; then
    lf_secret="$(grep -E "^LANGFUSE_SECRET=" "${ENV_FILE_LF}" | head -1 | cut -d= -f2- | tr -d "\"' " || true)"
    if [[ -n "${lf_secret}" && "${lf_secret}" != "REPLACE_WITH"* ]]; then
      _pass "LANGFUSE_SECRET is set"
    else
      _warn "LANGFUSE_SECRET not set in .env — run: make up"
    fi

    lf_salt="$(grep -E "^LANGFUSE_SALT=" "${ENV_FILE_LF}" | head -1 | cut -d= -f2- | tr -d "\"' " || true)"
    if [[ -n "${lf_salt}" && "${lf_salt}" != "REPLACE_WITH"* ]]; then
      _pass "LANGFUSE_SALT is set"
    else
      _warn "LANGFUSE_SALT not set in .env — run: make up"
    fi
  fi
fi

# ── Optional: Graphiti ────────────────────────────────────────────────────────
if env.is_enabled GRAPHITI_ENABLED; then
  header "Graphiti (temporal knowledge graph)"

  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^telamon-neo4j$"; then
    _pass "Neo4j container running (telamon-neo4j)"
  else
    _fail "Neo4j container not running — run: make up (GRAPHITI_ENABLED=true)"
  fi

  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^telamon-graphiti$"; then
    _pass "Graphiti container running (telamon-graphiti)"
    # HTTP health check — use _warn since the service may still be starting
    if wget -qO- http://localhost:8001/healthcheck &>/dev/null 2>&1; then
      _pass "Graphiti HTTP health: http://localhost:8001/healthcheck"
    else
      _warn "Graphiti HTTP health check failed — service may still be starting"
    fi
  else
    _fail "Graphiti container not running — run: make up (GRAPHITI_ENABLED=true)"
  fi

  # .env secret check
  ENV_FILE_GR="${TELAMON_ROOT}/.env"
  if [[ -f "${ENV_FILE_GR}" ]]; then
    neo4j_pass="$(grep -E "^NEO4J_PASSWORD=" "${ENV_FILE_GR}" | head -1 | cut -d= -f2- | tr -d "\"' " || true)"
    if [[ -n "${neo4j_pass}" && "${neo4j_pass}" != "REPLACE_WITH"* ]]; then
      _pass "NEO4J_PASSWORD is set"
    else
      _warn "NEO4J_PASSWORD not set in .env — run: make up"
    fi
  fi
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

# Check root symlink
ROOT_CONFIG="${TELAMON_ROOT}/opencode.jsonc"
if [[ -L "${ROOT_CONFIG}" && ! -e "${ROOT_CONFIG}" ]]; then
  _warn "opencode.jsonc is a dangling symlink — run: make up"
elif [[ -L "${ROOT_CONFIG}" ]]; then
  _pass "opencode.jsonc symlink"
elif [[ -f "${ROOT_CONFIG}" ]]; then
  _warn "opencode.jsonc is a regular file (expected symlink to storage/opencode.jsonc)"
else
  _fail "opencode.jsonc missing"
fi

STORAGE_CONFIG="${TELAMON_ROOT}/storage/opencode.jsonc"
if [[ -f "${STORAGE_CONFIG}" ]]; then
  _pass "storage/opencode.jsonc present"

  # Check key MCP servers are registered (use proper JSONC tokenizer — not regex)
  _check_mcp() {
    local name="$1"
    if python3 - "${TELAMON_ROOT}/src/install/functions/strip_jsonc.py" "${STORAGE_CONFIG}" "${name}" <<'PYEOF' 2>/dev/null
import sys, json

exec(open(sys.argv[1]).read())

config_file, server_name = sys.argv[2], sys.argv[3]
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
  # Optional: Graphiti MCP (only when enabled)
  if env.is_enabled GRAPHITI_ENABLED; then
    _check_mcp "graphiti"
  fi
else
  _fail "storage/opencode.jsonc missing — run: make up"
fi

# ── 5. Secrets ─────────────────────────────────────────────────────────────────
header "Secrets"

SECRETS_DIR="${TELAMON_ROOT}/storage/secrets"
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

# ── 6. Telamon storage layout ──────────────────────────────────────────────────────
header "Storage layout"

for d in "storage" "storage/state"; do
  if [[ -d "${TELAMON_ROOT}/${d}" ]]; then
    _pass "${d}/ exists"
  else
    _fail "${d}/ missing — run: make up"
  fi
done

if [[ -L "${TELAMON_ROOT}/graphify-out" ]]; then
  _pass "graphify-out → $(readlink "${TELAMON_ROOT}/graphify-out")"
else
  _warn "graphify-out symlink missing (graphify not yet run in this repo)"
fi

if [[ -L "${TELAMON_ROOT}/.ai/telamon/secrets" ]]; then
  _pass ".ai/telamon/secrets → $(readlink "${TELAMON_ROOT}/.ai/telamon/secrets")"
else
  _warn ".ai/telamon/secrets symlink missing"
fi

# ── 7. Telamon skills & context ───────────────────────────────────────────────────
header "Skills & context"

[[ -d "${TELAMON_ROOT}/src/skills" ]]   && _pass "src/skills/ present"  || _fail "src/skills/ missing"

skill_count=$(find "${TELAMON_ROOT}/src/skills" -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
_info "${skill_count} skill(s) in src/skills/"

# ── 8. .env ────────────────────────────────────────────────────────────────────
header ".env configuration"

ENV_FILE="${TELAMON_ROOT}/.env"
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

  # Optional service secrets (only checked when service is enabled)
  if env.is_enabled LANGFUSE_ENABLED; then
    lf_secret_env="$(grep -E "^LANGFUSE_SECRET=" "${ENV_FILE}" | head -1 | cut -d= -f2- | tr -d "\"' " || true)"
    if [[ -n "${lf_secret_env}" && "${lf_secret_env}" != "REPLACE_WITH"* ]]; then
      _pass "LANGFUSE_SECRET is set (.env)"
    else
      _warn "LANGFUSE_SECRET not set in .env — run: make up"
    fi

    lf_salt_env="$(grep -E "^LANGFUSE_SALT=" "${ENV_FILE}" | head -1 | cut -d= -f2- | tr -d "\"' " || true)"
    if [[ -n "${lf_salt_env}" && "${lf_salt_env}" != "REPLACE_WITH"* ]]; then
      _pass "LANGFUSE_SALT is set (.env)"
    else
      _warn "LANGFUSE_SALT not set in .env — run: make up"
    fi
  fi

  if env.is_enabled GRAPHITI_ENABLED; then
    neo4j_pass_env="$(grep -E "^NEO4J_PASSWORD=" "${ENV_FILE}" | head -1 | cut -d= -f2- | tr -d "\"' " || true)"
    if [[ -n "${neo4j_pass_env}" && "${neo4j_pass_env}" != "REPLACE_WITH"* ]]; then
      _pass "NEO4J_PASSWORD is set (.env)"
    else
      _warn "NEO4J_PASSWORD not set in .env — run: make up"
    fi
  fi
else
  _fail ".env not found — run: make up  (it copies .env.dist → .env automatically)"
fi

# ── Summary ────────────────────────────────────────────────────────────────────
echo
echo -e "${TEXT_BOLD}────────────────────────────────────────────────${TEXT_CLEAR}"
if [[ "${FAIL}" -eq 0 && "${WARN_COUNT}" -eq 0 ]]; then
  echo -e "${TEXT_GREEN}${TEXT_BOLD}  ✔  All ${PASS} checks passed. Telamon is healthy.${TEXT_CLEAR}"
elif [[ "${FAIL}" -eq 0 ]]; then
  echo -e "${TEXT_YELLOW}${TEXT_BOLD}  ⚠  ${PASS} passed, ${WARN_COUNT} warning(s). Telamon is mostly healthy.${TEXT_CLEAR}"
else
  echo -e "${TEXT_RED}${TEXT_BOLD}  ✖  ${FAIL} failure(s), ${WARN_COUNT} warning(s), ${PASS} passed.${TEXT_CLEAR}"
  echo -e "${TEXT_RED}${TEXT_BOLD}     Run 'make up' to fix failures.${TEXT_CLEAR}"
fi
echo -e "${TEXT_BOLD}────────────────────────────────────────────────${TEXT_CLEAR}"
echo

[[ "${FAIL}" -gt 0 ]] && exit 1 || exit 0
