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
TOOLS_PATH="${TELAMON_ROOT}/src/tools"
FUNCTIONS_PATH="${TELAMON_ROOT}/src/functions"
export TOOLS_PATH FUNCTIONS_PATH TELAMON_ROOT

# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/opt/homebrew/bin:/home/linuxbrew/.linuxbrew/bin:/usr/local/bin:$PATH"

PASS=0
FAIL=0
WARN_COUNT=0

_pass() { echo -e "  ${TEXT_GREEN}✔${TEXT_CLEAR}  $1"; PASS=$((PASS + 1)); }
_fail() { echo -e "  ${TEXT_RED}✖${TEXT_CLEAR}  $1"; FAIL=$((FAIL + 1)); }
_warn() { echo -e "  ${TEXT_YELLOW}⚠${TEXT_CLEAR}  $1"; WARN_COUNT=$((WARN_COUNT + 1)); }
_info() { echo -e "  ${TEXT_BLUE}ℹ${TEXT_CLEAR}  $1"; }

echo -e "\n${TEXT_BOLD}${TEXT_BLUE}"
echo "  ══════════════════════════════════════════"
echo "  Telamon Doctor"
echo "  ══════════════════════════════════════════"
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
  _fail "Docker not installed — run: make install"
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
    if wget -qO- --timeout=5 http://localhost:17400/api/public/health &>/dev/null 2>&1; then
      _pass "Langfuse HTTP health: http://localhost:17400/api/public/health"
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
      _warn "LANGFUSE_SECRET not set in .env — run: make install"
    fi

    lf_salt="$(grep -E "^LANGFUSE_SALT=" "${ENV_FILE_LF}" | head -1 | cut -d= -f2- | tr -d "\"' " || true)"
    if [[ -n "${lf_salt}" && "${lf_salt}" != "REPLACE_WITH"* ]]; then
      _pass "LANGFUSE_SALT is set"
    else
      _warn "LANGFUSE_SALT not set in .env — run: make install"
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
    if wget -qO- --timeout=5 http://localhost:17801/healthcheck &>/dev/null 2>&1; then
      _pass "Graphiti HTTP health: http://localhost:17801/healthcheck"
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
      _warn "NEO4J_PASSWORD not set in .env — run: make install"
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
    _fail "${name} not found — run: make install"
  fi
}

_check_binary "uv (Python tool manager)"  "uv"       "uv --version"
_check_binary "Node.js"                    "node"     "node --version"
_check_binary "npm"                        "npm"      "npm --version"
_check_binary "opencode"                   "opencode" "opencode --version"
_check_binary "graphify"                   "graphify" "graphify --version"
_check_binary "rtk"                        "rtk"      "rtk --version"

# ── 3. QMD (vault semantic search) ────────────────────────────────────────────
header "QMD (vault semantic search)"

if command -v qmd &>/dev/null; then
  _pass "QMD binary installed"

  # Check QMD index exists
  QMD_INDEX_DIR="${TELAMON_ROOT}/storage/qmd"
  if [[ -d "${QMD_INDEX_DIR}" ]]; then
    qmd_doc_count=$(find "${QMD_INDEX_DIR}" -name "*.json" -type f 2>/dev/null | wc -l | tr -d ' ')
    _pass "QMD index directory present (${qmd_doc_count} files)"
  else
    _warn "QMD index directory missing — run: bin/init.sh <project>"
  fi

  # Check QMD collections exist
  for collection_dir in "${TELAMON_ROOT}/storage/projects-memory"/*/brain; do
    if [[ -d "${collection_dir}" ]]; then
      collection_name="$(basename "$(dirname "${collection_dir}")")-brain"
      doc_count=$(find "${collection_dir}" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
      _pass "QMD collection source: ${collection_name} (${doc_count} docs)"
    fi
  done
else
  _fail "QMD binary not found — run: make install"
fi

# ── 4. Codebase Index ──────────────────────────────────────────────────────────
header "Codebase Index"

CODEBASE_INDEX_CONFIG="${TELAMON_ROOT}/.opencode/codebase-index.json"
if [[ -f "${CODEBASE_INDEX_CONFIG}" ]]; then
  _pass "Codebase index config present"
else
  _warn "Codebase index config missing (.opencode/codebase-index.json) — run: bin/init.sh <project>"
fi

# Check if index data exists
# The codebase-index MCP stores data at <project>/.opencode/index/ (project scope)
# or ~/.opencode/global-index/ (global scope). Also check legacy locations.
INDEX_DATA_FOUND=false
for idx_dir in \
  "${TELAMON_ROOT}/.opencode/index" \
  "${TELAMON_ROOT}/.codebase-index" \
  "${TELAMON_ROOT}/.opencode/codebase-index" \
  "${HOME}/.opencode/global-index"; do
  if [[ -d "${idx_dir}" ]]; then
    idx_file_count=$(find "${idx_dir}" -type f 2>/dev/null | wc -l | tr -d ' ')
    if [[ "${idx_file_count}" -gt 0 ]]; then
      _pass "Codebase index data present (${idx_file_count} files in ${idx_dir})"
      INDEX_DATA_FOUND=true
      break
    fi
  fi
done

# Also check initialized projects
if [[ "${INDEX_DATA_FOUND}" == "false" ]]; then
  for proj_idx in "${TELAMON_ROOT}"/storage/graphify/*/; do
    [[ -d "${proj_idx}" ]] || continue
    proj_path_file="${proj_idx}.project-path"
    [[ -f "${proj_path_file}" ]] || continue
    proj_path="$(cat "${proj_path_file}")"
    if [[ -d "${proj_path}/.opencode/index" ]]; then
      idx_file_count=$(find "${proj_path}/.opencode/index" -type f 2>/dev/null | wc -l | tr -d ' ')
      if [[ "${idx_file_count}" -gt 0 ]]; then
        _pass "Codebase index data present (${idx_file_count} files in ${proj_path}/.opencode/index/)"
        INDEX_DATA_FOUND=true
        break
      fi
    fi
  done
fi

if [[ "${INDEX_DATA_FOUND}" == "false" ]]; then
  _warn "Codebase index not built — run index_codebase tool from an agent session"
fi

# ── 6b. Repomix ────────────────────────────────────────────────────────────
header "Repomix"

repomix_ver=$(npx -y repomix --version 2>/dev/null) || true
if [[ -n "${repomix_ver}" ]]; then
  _pass "Repomix installed (${repomix_ver})"
else
  _fail "Repomix: npx -y repomix --version failed"
fi

REPOMIX_CONFIG="$(pwd)/repomix.config.json"
if [[ -f "${REPOMIX_CONFIG}" ]]; then
  _pass "Repomix config present (repomix.config.json)"
else
  _warn "Repomix config missing (repomix.config.json) — run: bin/init.sh <project>"
fi

# ── 6c. promptfoo (Agent Evaluation) ──────────────────────────────────────
header "promptfoo (Agent Evaluation)"

# Check npx cache — never trigger download from doctor
PROMPTFOO_BIN=$(find "${HOME}/.npm/_npx" -path "*/node_modules/.bin/promptfoo" 2>/dev/null | head -1)
if [[ -n "${PROMPTFOO_BIN}" && -x "${PROMPTFOO_BIN}" ]]; then
  pf_ver=$("${PROMPTFOO_BIN}" --version 2>/dev/null) || true
  if [[ -n "${pf_ver}" ]]; then
    _pass "promptfoo cached (${pf_ver})"
  else
    _warn "promptfoo binary found but --version failed"
  fi
else
  _warn "promptfoo not yet cached — run 'npx -y promptfoo --version' to initialize"
fi

EVAL_CONFIG="$(pwd)/tests/agents/promptfooconfig.yaml"
if [[ -f "${EVAL_CONFIG}" ]]; then
  _pass "Eval config present (tests/agents/promptfooconfig.yaml)"
else
  _warn "Eval config missing (tests/agents/promptfooconfig.yaml) — run: bin/init.sh --with-tests <project>"
fi

# ── 7. Graphify (knowledge graph) ─────────────────────────────────────────────
header "Graphify (knowledge graph)"

if command -v graphify &>/dev/null; then
  _pass "Graphify binary installed ($(graphify --version 2>/dev/null || echo '?'))"
else
  _fail "Graphify binary not found — run: make install"
fi

# Check graphify Python path stored
if [[ -f "${TELAMON_ROOT}/storage/secrets/graphify-python" ]]; then
  GRAPHIFY_PY="$(cat "${TELAMON_ROOT}/storage/secrets/graphify-python")"
  if [[ -x "${GRAPHIFY_PY}" ]]; then
    _pass "Graphify Python interpreter: ${GRAPHIFY_PY}"
  else
    _warn "Graphify Python interpreter not executable: ${GRAPHIFY_PY}"
  fi
else
  _warn "Graphify Python path not stored — run: make install"
fi

# Check graphify-out symlink
if [[ -L "${TELAMON_ROOT}/graphify-out" ]]; then
  _pass "graphify-out → $(readlink "${TELAMON_ROOT}/graphify-out")"
else
  _warn "graphify-out symlink missing — run: bin/init.sh <project>"
fi

# Check for built graphs across all initialized projects
GRAPH_BUILT=0
GRAPH_MISSING=0
for storage_dir in "${TELAMON_ROOT}/storage/graphify"/*/; do
  [[ -d "${storage_dir}" ]] || continue
  project_name="$(basename "${storage_dir}")"
  if [[ -f "${storage_dir}graph.json" ]]; then
    node_count=""
    if command -v python3 &>/dev/null; then
      node_count=$(python3 -c "import json; d=json.load(open('${storage_dir}graph.json')); print(len(d.get('nodes',[])))" 2>/dev/null || echo "?")
    fi
    _pass "Graph built: ${project_name} (${node_count} nodes)"
    GRAPH_BUILT=$((GRAPH_BUILT + 1))
  else
    _warn "Graph missing: ${project_name} — run: bin/init.sh <project> or graphify update ."
    GRAPH_MISSING=$((GRAPH_MISSING + 1))
  fi
  # Check .project-path marker
  if [[ -f "${storage_dir}.project-path" ]]; then
    proj_path="$(cat "${storage_dir}.project-path")"
    if [[ -d "${proj_path}" ]]; then
      _pass "Project path valid: ${project_name} → ${proj_path}"
    else
      _warn "Project path stale: ${project_name} → ${proj_path} (directory not found)"
    fi
  else
    _warn "Project path marker missing: ${project_name}/.project-path"
  fi
done
if [[ "${GRAPH_BUILT}" -eq 0 && "${GRAPH_MISSING}" -eq 0 ]]; then
  _warn "No graphify projects initialized — run: bin/init.sh <project>"
fi

# Check MCP serve wrapper
if [[ -f "${TELAMON_ROOT}/.opencode/graphify-serve.sh" ]]; then
  _pass "Graphify MCP serve wrapper present"
else
  _warn "Graphify MCP serve wrapper missing (.opencode/graphify-serve.sh) — run: bin/init.sh <project>"
fi

# ── 7b. MCP Runtime Health ────────────────────────────────────────────────────
header "MCP Runtime Health"

# a) Graphify mcp dependency
if [[ -f "${TELAMON_ROOT}/storage/secrets/graphify-python" ]]; then
  GRAPHIFY_PY="$(cat "${TELAMON_ROOT}/storage/secrets/graphify-python")"
  if [[ -x "${GRAPHIFY_PY}" ]]; then
    if "${GRAPHIFY_PY}" -c "import mcp" &>/dev/null 2>&1; then
      _pass "Graphify MCP: 'mcp' Python package installed"
    else
      _warn "Graphify MCP: 'mcp' Python package missing — attempting auto-fix..."
      if uv pip install --python "${GRAPHIFY_PY}" mcp &>/dev/null 2>&1; then
        _pass "Graphify MCP: 'mcp' installed successfully"
      else
        _fail "Graphify MCP: could not install 'mcp' — run manually: uv pip install --python ${GRAPHIFY_PY} mcp"
      fi
    fi
  fi
fi

# b) npm cache health
if command -v npm &>/dev/null; then
  if npm cache verify &>/dev/null 2>&1; then
    _pass "npm cache: healthy"
  else
    _warn "npm cache: corrupted — attempting auto-fix..."
    if npm cache clean --force &>/dev/null 2>&1; then
      _pass "npm cache: cleaned successfully"
    else
      _fail "npm cache: could not clean — run manually: npm cache clean --force"
    fi
  fi
fi

# c) GitHub MCP authentication
GH_PAT_FILE="${TELAMON_ROOT}/storage/secrets/gh_pat"
if [[ -f "${GH_PAT_FILE}" ]]; then
  GH_PAT="$(cat "${GH_PAT_FILE}" 2>/dev/null)"
  if [[ -z "${GH_PAT}" || "${GH_PAT}" == CREATE_A_PAT_AS_IN_IMAGE* ]]; then
    _fail "GitHub MCP: PAT not configured — replace placeholder in storage/secrets/gh_pat with a valid token"
  elif curl -sf --max-time 5 -H "Authorization: token ${GH_PAT}" https://api.github.com/user &>/dev/null 2>&1; then
    _pass "GitHub MCP: PAT authenticated"
  else
    _fail "GitHub MCP: PAT authentication failed — token may be expired or revoked"
  fi
else
  _fail "GitHub MCP: PAT file missing — create storage/secrets/gh_pat with a valid GitHub token"
fi

# ── 8. Scheduled jobs ─────────────────────────────────────────────────────────
header "Scheduled jobs"

OS="$(uname -s)"
JOBS_FOUND=0

if [[ "${OS}" == "Linux" ]]; then
  # Check systemd user timers for graphify
  for timer in "${HOME}/.config/systemd/user"/graphify-update-*.timer; do
    [[ -f "${timer}" ]] || continue
    timer_name="$(basename "${timer}" .timer)"
    if systemctl --user is-active "${timer_name}.timer" &>/dev/null 2>&1; then
      _pass "Timer active: ${timer_name}"
    else
      _warn "Timer inactive: ${timer_name} — run: systemctl --user enable --now ${timer_name}.timer"
    fi
    JOBS_FOUND=$((JOBS_FOUND + 1))
  done

elif [[ "${OS}" == "Darwin" ]]; then
  # Check launchd agents for graphify
  for plist in "${HOME}/Library/LaunchAgents"/com.telamon.graphify-update-*.plist; do
    [[ -f "${plist}" ]] || continue
    job_name="$(basename "${plist}" .plist)"
    if launchctl list 2>/dev/null | grep -q "${job_name}"; then
      _pass "LaunchAgent active: ${job_name}"
    else
      _warn "LaunchAgent inactive: ${job_name}"
    fi
    JOBS_FOUND=$((JOBS_FOUND + 1))
  done
fi

if [[ "${JOBS_FOUND}" -eq 0 ]]; then
  _warn "No scheduled jobs found — run: bin/init.sh <project> to set up graph update timers"
fi

# ── 9. opencode config ────────────────────────────────────────────────────────
header "opencode config"

# Check root symlink
ROOT_CONFIG="${TELAMON_ROOT}/opencode.jsonc"
if [[ -L "${ROOT_CONFIG}" && ! -e "${ROOT_CONFIG}" ]]; then
  _warn "opencode.jsonc is a dangling symlink — run: make install"
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
    if python3 - "${TELAMON_ROOT}/src/functions/strip_jsonc.py" "${STORAGE_CONFIG}" "${name}" <<'PYEOF' 2>/dev/null
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
      _warn "MCP server '${name}' not in storage/opencode.jsonc — run: make install"
    fi
  }

  _check_mcp "codebase-index"
  _check_mcp "websearch"
  _check_mcp "context7"
  _check_mcp "ast-grep"
  _check_mcp "git"
  _check_mcp "repomix"
  # Optional: Graphiti MCP (only when enabled)
  if env.is_enabled GRAPHITI_ENABLED; then
    _check_mcp "graphiti"
  fi
else
  _fail "storage/opencode.jsonc missing — run: make install"
fi

# ── 10. Secrets ────────────────────────────────────────────────────────────────
header "Secrets"

SECRETS_DIR="${TELAMON_ROOT}/storage/secrets"
if [[ -d "${SECRETS_DIR}" ]]; then
  _pass "storage/secrets/ directory exists"
else
  _fail "storage/secrets/ not found — run: make install"
fi

# ── 11. Telamon storage layout ─────────────────────────────────────────────────
header "Storage layout"

for d in "storage" "storage/state"; do
  if [[ -d "${TELAMON_ROOT}/${d}" ]]; then
    _pass "${d}/ exists"
  else
    _fail "${d}/ missing — run: make install"
  fi
done

if [[ -L "${TELAMON_ROOT}/.ai/telamon/secrets" ]]; then
  _pass ".ai/telamon/secrets → $(readlink "${TELAMON_ROOT}/.ai/telamon/secrets")"
else
  _warn ".ai/telamon/secrets symlink missing"
fi

# ── 12. Telamon skills & context ──────────────────────────────────────────────
header "Skills & context"

[[ -d "${TELAMON_ROOT}/src/skills" ]]   && _pass "src/skills/ present"  || _fail "src/skills/ missing"

skill_count=$(find "${TELAMON_ROOT}/src/skills" -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
_info "${skill_count} skill(s) in src/skills/"

# ── 13. .env ──────────────────────────────────────────────────────────────────
header ".env configuration"

ENV_FILE="${TELAMON_ROOT}/.env"
if [[ -f "${ENV_FILE}" ]]; then
  _pass ".env file present"

  # Optional service secrets (only checked when service is enabled)
  if env.is_enabled LANGFUSE_ENABLED; then
    lf_secret_env="$(grep -E "^LANGFUSE_SECRET=" "${ENV_FILE}" | head -1 | cut -d= -f2- | tr -d "\"' " || true)"
    if [[ -n "${lf_secret_env}" && "${lf_secret_env}" != "REPLACE_WITH"* ]]; then
      _pass "LANGFUSE_SECRET is set (.env)"
    else
      _warn "LANGFUSE_SECRET not set in .env — run: make install"
    fi

    lf_salt_env="$(grep -E "^LANGFUSE_SALT=" "${ENV_FILE}" | head -1 | cut -d= -f2- | tr -d "\"' " || true)"
    if [[ -n "${lf_salt_env}" && "${lf_salt_env}" != "REPLACE_WITH"* ]]; then
      _pass "LANGFUSE_SALT is set (.env)"
    else
      _warn "LANGFUSE_SALT not set in .env — run: make install"
    fi
  fi

  if env.is_enabled GRAPHITI_ENABLED; then
    neo4j_pass_env="$(grep -E "^NEO4J_PASSWORD=" "${ENV_FILE}" | head -1 | cut -d= -f2- | tr -d "\"' " || true)"
    if [[ -n "${neo4j_pass_env}" && "${neo4j_pass_env}" != "REPLACE_WITH"* ]]; then
      _pass "NEO4J_PASSWORD is set (.env)"
    else
      _warn "NEO4J_PASSWORD not set in .env — run: make install"
    fi
  fi
else
  _fail ".env not found — run: make install  (it copies .env.dist → .env automatically)"
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
  echo -e "${TEXT_RED}${TEXT_BOLD}     Run 'make install' to fix failures.${TEXT_CLEAR}"
fi
echo -e "${TEXT_BOLD}────────────────────────────────────────────────${TEXT_CLEAR}"
echo -e "  ${TEXT_DIM}If any problem persists, start opencode and ask it to help debug the issue.${TEXT_CLEAR}"
echo

[[ "${FAIL}" -gt 0 ]] && exit 1 || exit 0
