#!/usr/bin/env bash
# =============================================================================
# bin/status.sh
# Show installation status of all Telamon tools and services.
#
# Usage:
#   bin/status.sh
#   make status
# =============================================================================

set -euo pipefail

TELAMON_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_PATH="${TELAMON_ROOT}/src/tools"
FUNCTIONS_PATH="${TELAMON_ROOT}/src/functions"
export TOOLS_PATH FUNCTIONS_PATH TELAMON_ROOT

# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/opt/homebrew/bin:/home/linuxbrew/.linuxbrew/bin:/usr/local/bin:$PATH"

OS=$(os.get_os)
echo
_ok() { echo -e "  ${TEXT_GREEN}✔${TEXT_CLEAR}  $1"; }
_no() { echo -e "  ${TEXT_RED}✖${TEXT_CLEAR}  $1"; }

if [[ "${OS}" == "macos" ]]; then
  command -v brew &>/dev/null && _ok "Homebrew"             || _no "Homebrew"
else
  command -v brew &>/dev/null && _ok "Homebrew (Linuxbrew)" || _no "Homebrew (Linuxbrew)"
fi
command -v docker &>/dev/null                                              && _ok "Docker"             || _no "Docker"
docker info &>/dev/null 2>&1                                               && _ok "Docker running"     || _no "Docker not running"
docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^telamon-ollama$"      && _ok "Ollama container"   || _no "Ollama container"
docker exec telamon-ollama ollama list 2>/dev/null | grep -q "nomic-embed-text" && _ok "nomic-embed-text" || _no "nomic-embed-text"

# ── Optional: Langfuse ────────────────────────────────────────────────────────
if env.is_enabled LANGFUSE_ENABLED; then
  docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^telamon-langfuse-web$" \
    && _ok "Langfuse web"      || _no "Langfuse web"
  docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^telamon-langfuse-db$" \
    && _ok "Langfuse Postgres" || _no "Langfuse Postgres"
fi

# ── Optional: Graphiti ────────────────────────────────────────────────────────
if env.is_enabled GRAPHITI_ENABLED; then
  docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^telamon-neo4j$" \
    && _ok "Neo4j"    || _no "Neo4j"
  docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^telamon-graphiti$" \
    && _ok "Graphiti" || _no "Graphiti"
fi
command -v uv       &>/dev/null && _ok "uv"       || _no "uv"
command -v node     &>/dev/null && _ok "Node.js"  || _no "Node.js"
command -v graphify &>/dev/null && _ok "Graphify" || _no "Graphify"
command -v rtk      &>/dev/null && _ok "RTK"      || _no "RTK"
command -v opencode &>/dev/null && _ok "opencode" || _no "opencode"
[[ -f "${TELAMON_ROOT}/storage/opencode.jsonc" ]] && _ok "storage/opencode.jsonc" || _no "storage/opencode.jsonc"
[[ -d "${TELAMON_ROOT}/storage/secrets" ]]        && _ok "storage/secrets/"        || _no "storage/secrets/ (run 'make up' to create)"
[[ -d "${TELAMON_ROOT}/storage/state" ]]          && _ok "storage/state/"          || _no "storage/state/ (run 'make up' to create)"
[[ -d "${TELAMON_ROOT}/src/skills" ]]             && _ok "Telamon skills (src/skills)" || _no "Telamon skills (src/skills)"
echo

# =============================================================================
# Runtime report sections
# =============================================================================

# ── Graphify ──────────────────────────────────────────────────────────────────
header "Graphify"
_graphify_found=0
for _gdir in "${TELAMON_ROOT}/storage/graphify/"/*/; do
  [[ -d "${_gdir}" ]] || continue
  _gname=$(basename "${_gdir}")
  _gjson="${_gdir}graph.json"
  if [[ -f "${_gjson}" ]]; then
    _gnodes=$(python3 -c "import json; d=json.load(open('${_gjson}')); print(len(d.get('nodes',[])))" 2>/dev/null || echo "?")
    echo -e "  ${TEXT_BOLD}${_gname}:${TEXT_CLEAR} ${_gnodes} nodes"
    _graphify_found=1
  fi
done
[[ ${_graphify_found} -eq 0 ]] && echo -e "  ${TEXT_DIM}(no graphs found)${TEXT_CLEAR}"

# ── Codebase Index ────────────────────────────────────────────────────────────
header "Codebase Index"
_index_found=0

# Check projects via .project-path markers
for _gdir in "${TELAMON_ROOT}/storage/graphify/"/*/; do
  [[ -d "${_gdir}" ]] || continue
  _gname=$(basename "${_gdir}")
  _ppath_file="${_gdir}.project-path"
  [[ -f "${_ppath_file}" ]] || continue
  _ppath=$(cat "${_ppath_file}" 2>/dev/null | tr -d '[:space:]')
  _idir="${_ppath}/.opencode/index"
  if [[ -d "${_idir}" ]]; then
    _ifiles=$(find "${_idir}" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
    _isize=$(du -sh "${_idir}" 2>/dev/null | awk '{print $1}')
    echo -e "  ${TEXT_BOLD}${_gname}:${TEXT_CLEAR} ${_ifiles} files (${_isize})"
    _index_found=1
  fi
done

# Also check TELAMON_ROOT itself if not already covered
_self_idir="${TELAMON_ROOT}/.opencode/index"
if [[ -d "${_self_idir}" ]]; then
  _already=0
  for _gdir in "${TELAMON_ROOT}/storage/graphify/"/*/; do
    _ppath_file="${_gdir}.project-path"
    [[ -f "${_ppath_file}" ]] || continue
    _ppath=$(cat "${_ppath_file}" 2>/dev/null | tr -d '[:space:]')
    [[ "${_ppath}" == "${TELAMON_ROOT}" ]] && { _already=1; break; }
  done
  if [[ ${_already} -eq 0 ]]; then
    _ifiles=$(find "${_self_idir}" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
    _isize=$(du -sh "${_self_idir}" 2>/dev/null | awk '{print $1}')
    echo -e "  ${TEXT_BOLD}telamon (self):${TEXT_CLEAR} ${_ifiles} files (${_isize})"
    _index_found=1
  fi
fi

[[ ${_index_found} -eq 0 ]] && echo -e "  ${TEXT_DIM}(no indexes found)${TEXT_CLEAR}"

# ── QMD ───────────────────────────────────────────────────────────────────────
header "QMD"
if command -v qmd &>/dev/null; then
  _qmd_status=$(timeout 5 qmd status 2>/dev/null || true)
  if [[ -n "${_qmd_status}" ]]; then
    _qmd_size=$(echo "${_qmd_status}"        | grep "^Size:" | awk '{print $2, $3}')
    _qmd_collections=$(echo "${_qmd_status}" | grep -E "^\s+[a-z].*\(qmd://" | sed 's/.*(\(qmd:\/\/[^)]*\)).*//' | wc -l | tr -d ' ')
    _qmd_names=$(echo "${_qmd_status}"       | grep -E "^\s+[a-z][a-z0-9-]+ \(qmd://" | awk '{print $1}' | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')
    echo -e "  ${TEXT_BOLD}Collections:${TEXT_CLEAR} ${_qmd_collections} (${_qmd_names})"
    [[ -n "${_qmd_size}" ]] && echo -e "  ${TEXT_DIM}Index size: ${_qmd_size}${TEXT_CLEAR}"
  else
    echo -e "  ${TEXT_DIM}(qmd not available)${TEXT_CLEAR}"
  fi
else
  echo -e "  ${TEXT_DIM}(qmd not available)${TEXT_CLEAR}"
fi

# ── Scheduled Jobs ────────────────────────────────────────────────────────────
header "Scheduled Jobs"
_jobs_found=0
if [[ "${OS}" == "linux" ]]; then
  while IFS= read -r _timer_line; do
    [[ -z "${_timer_line}" ]] && continue
    _tname=$(echo "${_timer_line}" | awk '{print $(NF-1)}' | sed 's/\.timer$//')
    _tstate=$(systemctl --user show "${_tname}.timer" --property=ActiveState 2>/dev/null | sed 's/ActiveState=//')
    _tsched=$(systemctl --user cat "${_tname}.timer" 2>/dev/null | grep -E "OnCalendar|OnUnitActiveSec" | head -1 | sed 's/.*=//')
    _tlabel="${_tstate}"
    [[ -n "${_tsched}" ]] && _tlabel="${_tstate} (${_tsched})"
    echo -e "  ${TEXT_BOLD}${_tname}:${TEXT_CLEAR} ${_tlabel}"
    _jobs_found=1
  done < <(systemctl --user list-timers --no-legend 2>/dev/null | grep -E "graphify-update-")
elif [[ "${OS}" == "macos" ]]; then
  while IFS= read -r _agent; do
    [[ -z "${_agent}" ]] && continue
    _astate=$(launchctl list "${_agent}" 2>/dev/null | grep '"LastExitStatus"' | awk '{print $3}' | tr -d ';')
    echo -e "  ${TEXT_BOLD}${_agent}:${TEXT_CLEAR} ${_astate:-unknown}"
    _jobs_found=1
  done < <(launchctl list 2>/dev/null | awk '{print $3}' | grep "^com\.telamon\.")
fi
[[ ${_jobs_found} -eq 0 ]] && echo -e "  ${TEXT_DIM}(no scheduled jobs found)${TEXT_CLEAR}"

# ── MCP Runtime Health ────────────────────────────────────────────────────────
header "MCP Runtime Health"
_mcp_issues=0

# Graphify mcp dependency
if [[ -f "${TELAMON_ROOT}/storage/secrets/graphify-python" ]]; then
  _graphify_py="$(cat "${TELAMON_ROOT}/storage/secrets/graphify-python")"
  if [[ -x "${_graphify_py}" ]]; then
    if "${_graphify_py}" -c "import mcp" &>/dev/null 2>&1; then
      _ok "Graphify MCP: 'mcp' dependency present"
    else
      _no "Graphify MCP: 'mcp' Python package not installed"
      _mcp_issues=$((_mcp_issues + 1))
    fi
  else
    _no "Graphify MCP: Python interpreter not found at ${_graphify_py}"
    _mcp_issues=$((_mcp_issues + 1))
  fi
else
  echo -e "  ${TEXT_DIM}(graphify-python secret not found — skipping mcp dependency check)${TEXT_CLEAR}"
fi

# npm cache health
if command -v npm &>/dev/null; then
  if npm cache verify &>/dev/null 2>&1; then
    _ok "npm cache: healthy"
  else
    _no "npm cache: corrupted (EACCES permission errors)"
    _mcp_issues=$((_mcp_issues + 1))
  fi
else
  echo -e "  ${TEXT_DIM}(npm not found — skipping cache check)${TEXT_CLEAR}"
fi

# GitHub MCP authentication
_gh_pat_file="${TELAMON_ROOT}/storage/secrets/gh_pat"
if [[ -f "${_gh_pat_file}" ]]; then
  _gh_pat="$(cat "${_gh_pat_file}" 2>/dev/null)"
  if [[ -z "${_gh_pat}" || "${_gh_pat}" == CREATE_A_PAT_AS_IN_IMAGE* ]]; then
    _no "GitHub MCP: PAT not configured (placeholder or empty)"
    _mcp_issues=$((_mcp_issues + 1))
  elif curl -sf --max-time 5 -H "Authorization: token ${_gh_pat}" https://api.github.com/user &>/dev/null 2>&1; then
    _ok "GitHub MCP: PAT authenticated"
  else
    _no "GitHub MCP: PAT authentication failed (expired or invalid)"
    _mcp_issues=$((_mcp_issues + 1))
  fi
else
  _no "GitHub MCP: PAT file missing (storage/secrets/gh_pat)"
  _mcp_issues=$((_mcp_issues + 1))
fi

if [[ "${_mcp_issues}" -gt 0 ]]; then
  echo
  echo -e "  ${TEXT_YELLOW}${TEXT_BOLD}⚠  ${_mcp_issues} MCP issue(s) detected — running doctor for auto-fix...${TEXT_CLEAR}"
  echo -e "  ${TEXT_DIM}────────────────────────────────────────────────${TEXT_CLEAR}"
  bash "${TELAMON_ROOT}/bin/doctor.sh" || true
fi

echo
