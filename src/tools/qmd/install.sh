#!/usr/bin/env bash
# Install QMD (Query Markup Documents — semantic search for Markdown vaults)
# via npm, and download the upstream QMD skill into
# src/skills/memory/_tools/qmd/SKILL.md so it is available to all initialized projects
# via the .opencode/skills/telamon symlink.
#
# QMD's cache location is controlled by XDG_CACHE_HOME.  Telamon redirects it
# to <telamon-root>/storage so the index and model files live alongside all other Telamon
# runtime data instead of in the system-wide ~/.cache directory:
#   storage/qmd/index.sqlite   — the search index
#   storage/qmd/models/        — GGUF model cache (~2 GB, downloaded on first use)
#
# The absolute storage path is written to storage/secrets/qmd-cache-home so that
# opencode.jsonc can inject it as XDG_CACHE_HOME for the `qmd mcp` server.
#
# Models auto-downloaded on first use (~2 GB total):
#   - 300 MB  embeddinggemma   (embedding)
#   - 640 MB  qwen3-reranker   (reranker)
#   - 1.1 GB  qmd-query-expansion (query expansion)

set -euo pipefail

TOOLS_PATH="${TOOLS_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TELAMON_ROOT="${TELAMON_ROOT:-$(cd "${TOOLS_PATH}/../.." && pwd)}"
# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

# ── Install QMD binary ─────────────────────────────────────────────────────────
header "QMD (semantic vault search)"

if ! command -v qmd &>/dev/null; then
  step "Installing QMD via npm..."
  npm install -g @tobilu/qmd
  log "QMD installed"
else
  skip "QMD ($(XDG_CACHE_HOME="${TELAMON_ROOT}/storage" qmd --version 2>/dev/null || echo 'installed'))"
fi

# ── Write storage path to secrets so opencode.jsonc can reference it ──────────
# opencode resolves {file:.ai/telamon/secrets/qmd-cache-home} relative to the project
# root (where opencode.jsonc is symlinked). The symlink .ai/telamon/secrets →
# <telamon-root>/storage/secrets makes this file visible from every project.
QMD_CACHE_SECRET="${TELAMON_ROOT}/storage/secrets/qmd-cache-home"
mkdir -p "${TELAMON_ROOT}/storage/secrets"

if [[ -f "${QMD_CACHE_SECRET}" ]] && [[ "$(cat "${QMD_CACHE_SECRET}")" == "${TELAMON_ROOT}/storage" ]]; then
  skip "storage/secrets/qmd-cache-home (already correct)"
else
  printf '%s' "${TELAMON_ROOT}/storage" > "${QMD_CACHE_SECRET}"
  log "Written storage/secrets/qmd-cache-home → ${TELAMON_ROOT}/storage"
fi

# ── Download QMD agent skill into src/skills/memory/_tools/qmd/ ──────────────────────
# The skill teaches agents to use QMD proactively before reading vault files,
# before creating notes (duplicate check), and after creating notes (find related).
# It reaches all initialized projects via the .opencode/skills/telamon → src/skills
# symlink created by bin/init.sh.
SKILL_URL="https://raw.githubusercontent.com/tobi/qmd/main/skills/qmd/SKILL.md"
SKILL_DIR="${TELAMON_ROOT}/src/skills/memory/_tools/qmd"
SKILL_FILE="${SKILL_DIR}/SKILL.md"

step "Downloading QMD skill → src/skills/memory/_tools/qmd/SKILL.md ..."
mkdir -p "${SKILL_DIR}"
if curl -fsSL "${SKILL_URL}" -o "${SKILL_FILE}" 2>/dev/null; then
  log "QMD skill downloaded → src/skills/memory/_tools/qmd/SKILL.md"
else
  warn "QMD skill download failed — will use bundled Telamon skill at ${SKILL_FILE}"
  warn "To retry manually: curl -fsSL ${SKILL_URL} -o ${SKILL_FILE}"
fi

# ── Detect GPU for QMD ────────────────────────────────────────────────────────
if os.has_gpu; then
  QMD_GPU_VALUE="true"
  if [[ "$(os.get_os)" == "macos" ]]; then
    log "GPU acceleration: enabled (Metal)"
  else
    log "GPU acceleration: enabled (NVIDIA)"
  fi
else
  QMD_GPU_VALUE="false"
  log "GPU acceleration: disabled (no GPU detected)"
fi

# ── Register QMD MCP server in opencode.jsonc ─────────────────────────────────
# The {file:.ai/telamon/secrets/qmd-cache-home} reference is resolved by opencode
# relative to the project root (where opencode.jsonc is symlinked). The symlink
# .ai/telamon/secrets → <telamon-root>/storage/secrets makes the secret visible there.
step "Registering QMD MCP in storage/opencode.jsonc ..."
opencode.upsert_mcp "qmd" \
  "{\"type\":\"local\",\"command\":[\"qmd\",\"mcp\"],\"enabled\":true,\"environment\":{\"XDG_CACHE_HOME\":\"{file:.ai/telamon/secrets/qmd-cache-home}\",\"QMD_LLAMA_GPU\":\"${QMD_GPU_VALUE}\"}}"
log "QMD MCP registered"

# ── Pre-download models in background (~2 GB) ────────────────────────────────
# Running a dummy query triggers all 3 model downloads (query expansion,
# embedding, reranker). The process runs in the background so it does not
# block the rest of the install. Skip if all models are already present.
QMD_MODEL_DIR="${TELAMON_ROOT}/storage/qmd/models"
if [[ -f "${QMD_MODEL_DIR}/hf_ggml-org_embeddinggemma-300M-Q8_0.gguf" ]] \
  && [[ -f "${QMD_MODEL_DIR}/hf_ggml-org_qwen3-reranker-0.6b-q8_0.gguf" ]] \
  && [[ -f "${QMD_MODEL_DIR}/hf_tobil_qmd-query-expansion-1.7B-q4_k_m.gguf" ]]; then
  skip "QMD models (all 3 already downloaded)"
else
  step "Pre-downloading QMD models in background (~2 GB)..."
  (
    XDG_CACHE_HOME="${TELAMON_ROOT}/storage" QMD_LLAMA_GPU="${QMD_GPU_VALUE}" \
      qmd query "test" >/dev/null 2>&1
  ) &
  log "QMD model download started in background (PID $!)"
fi

info "Run 'make init PROJ=<path>' to register QMD collections for a project (initial embed can take a few minutes)."
