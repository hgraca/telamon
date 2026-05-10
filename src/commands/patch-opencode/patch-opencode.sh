#!/usr/bin/env bash
# patch-opencode.sh — Build a patched opencode binary on demand.
#
# Triggered manually via the /patch-opencode slash command (NOT on install/update).
#
# Usage:
#   patch-opencode.sh [latest|dev|<version>] [--resume] [--dry-run]
#     latest     — newest v* tag in the opencode repo (default)
#     dev        — origin/dev branch
#     <version>  — explicit version, e.g. 1.14.44 or v1.14.44
#     --resume   — continue after LLM-resolved merge conflicts (working tree preserved)
#     --dry-run  — build & smoke-test only; do NOT back up or replace ~/.opencode/bin/opencode
#
# Workflow:
#   1. Resolve target ref from argument: latest | dev | <version> (default: latest)
#   2. Clone/update opencode source under storage/opencode-src/
#   3. Hard-reset to the target ref
#   4. Apply each PR from .telamon.jsonc::opencode_patches sequentially
#        - Clean apply  → continue
#        - Conflict     → exit 3 with structured payload for the LLM
#                          (LLM resolves in working tree, then re-runs with --resume)
#   5. Save combined diff to storage/opencode-src/combined.patch (record)
#   6. Build for current OS only via packages/opencode/script/build.ts --single
#      with OPENCODE_VERSION=666.0.0 stamped into the binary
#   7. Run smoke test (binary --version must equal 666.0.0)
#   8. Backup current binary → storage/opencode-backups/, atomic mv replacement
#   9. Save state to storage/opencode-patch-state.json
#
# Exit codes:
#    0 — success (patched binary installed)
#    1 — fatal error (build failure, missing tool, etc.)
#    2 — no patches configured (nothing to do)
#    3 — merge conflict; LLM intervention required (see CONFLICT.json)

set -euo pipefail

# ── Locate Telamon root ──────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# .opencode/commands/telamon/patch-opencode/ → src/commands/patch-opencode/ via symlink.
# Climb until we find .telamon.jsonc.
TELAMON_ROOT=""
_dir="${SCRIPT_DIR}"
while [[ "${_dir}" != "/" ]]; do
  if [[ -f "${_dir}/.telamon.jsonc" ]]; then
    TELAMON_ROOT="${_dir}"
    break
  fi
  _dir="$(dirname "${_dir}")"
done

if [[ -z "${TELAMON_ROOT}" ]]; then
  # Fallback: real path of script lives at <telamon>/src/commands/patch-opencode/
  TELAMON_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../.." && pwd)"
fi

FUNCTIONS_PATH="${TELAMON_ROOT}/src/functions"
# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

# ── Args ─────────────────────────────────────────────────────────────────────
TARGET_ARG="latest"
RESUME=0
DRY_RUN=0
for arg in "$@"; do
  case "${arg}" in
    --resume)  RESUME=1 ;;
    --dry-run) DRY_RUN=1 ;;
    -*)        error "Unknown flag: ${arg}" ;;
    *)         TARGET_ARG="${arg}" ;;
  esac
done

PATCHED_VERSION="666.0.0"   # stamped into the built binary
SRC_DIR="${TELAMON_ROOT}/storage/opencode-src"
BACKUP_DIR="${TELAMON_ROOT}/storage/opencode-backups"
STATE_FILE="${TELAMON_ROOT}/storage/opencode-patch-state.json"
CONFLICT_FILE="${TELAMON_ROOT}/storage/opencode-patch-conflict.json"
COMBINED_PATCH="${TELAMON_ROOT}/storage/opencode-src/combined.patch"
DEST="${HOME}/.opencode/bin/opencode"
CONFIG_FILE="${TELAMON_ROOT}/.telamon.jsonc"

mkdir -p "${BACKUP_DIR}" "$(dirname "${DEST}")" "$(dirname "${STATE_FILE}")"

_mode_suffix=""
[[ "${RESUME}" -eq 1 ]] && _mode_suffix="${_mode_suffix}, resume"
[[ "${DRY_RUN}" -eq 1 ]] && _mode_suffix="${_mode_suffix}, DRY-RUN"
header "patch-opencode (target: ${TARGET_ARG}${_mode_suffix})"

# ── 1. Read patches list ─────────────────────────────────────────────────────
if [[ ! -f "${CONFIG_FILE}" ]]; then
  error ".telamon.jsonc not found at ${CONFIG_FILE}"
fi

PATCHES_JSON="$(python3 - "${FUNCTIONS_PATH}" "${CONFIG_FILE}" <<'PYEOF'
import json, sys
sys.path.insert(0, sys.argv[1])
from strip_jsonc import load_jsonc
with open(sys.argv[2]) as f:
    data = load_jsonc(f.read())
print(json.dumps(data.get('opencode_patches', [])))
PYEOF
)"

PATCH_COUNT="$(python3 -c "import json,sys; print(len(json.loads(sys.argv[1])))" "${PATCHES_JSON}")"

if [[ "${PATCH_COUNT}" -eq 0 ]]; then
  warn "No patches configured in .telamon.jsonc::opencode_patches — nothing to do"
  exit 2
fi
log "${PATCH_COUNT} patch(es) configured"

# ── 2. Ensure bun ────────────────────────────────────────────────────────────
_install_bun() {
  step "Installing/upgrading bun..."
  curl -fsSL https://bun.sh/install | bash
  export PATH="$HOME/.bun/bin:$PATH"
}

BUN_REQUIRED="$(config.read_ini "${CONFIG_FILE}" "bun_version" 2>/dev/null || echo "")"
BUN_MIN="${BUN_REQUIRED#^}"; BUN_MIN="${BUN_MIN#~}"; BUN_MIN="${BUN_MIN:-1.3.13}"

if ! command -v bun &>/dev/null; then _install_bun; fi
BUN_CURRENT="$(bun --version 2>/dev/null || echo "0.0.0")"
if [[ $(os.version_to_number "${BUN_CURRENT}") -lt $(os.version_to_number "${BUN_MIN}") ]]; then
  warn "bun ${BUN_CURRENT} is below required ${BUN_MIN}"
  _install_bun
  BUN_CURRENT="$(bun --version 2>/dev/null || echo "0.0.0")"
fi
log "bun ${BUN_CURRENT}"

# ── 3. Clone or update opencode source ───────────────────────────────────────
REPO_URL="https://github.com/anomalyco/opencode.git"
if [[ -d "${SRC_DIR}/.git" ]]; then
  step "Fetching opencode source..."
  git -C "${SRC_DIR}" fetch --all --tags --quiet
else
  step "Cloning opencode source..."
  git clone --quiet "${REPO_URL}" "${SRC_DIR}"
fi
log "opencode source ready at ${SRC_DIR}"

# ── 4. Resolve target ref ────────────────────────────────────────────────────
resolve_ref() {
  local arg="$1"
  case "${arg}" in
    dev)
      echo "origin/dev"
      ;;
    latest)
      git -C "${SRC_DIR}" tag -l 'v[0-9]*' | sort -V -r | head -1
      ;;
    v*)
      echo "${arg}"
      ;;
    *)
      echo "v${arg}"
      ;;
  esac
}
TARGET_REF="$(resolve_ref "${TARGET_ARG}")"
if [[ -z "${TARGET_REF}" ]]; then
  error "Could not resolve ref for '${TARGET_ARG}'"
fi
# Verify the ref exists
if ! git -C "${SRC_DIR}" rev-parse --verify --quiet "${TARGET_REF}^{commit}" >/dev/null; then
  error "Ref '${TARGET_REF}' does not exist in opencode repo"
fi
log "Target ref: ${TARGET_REF}"

# ── 5. Reset working tree (unless --resume) ──────────────────────────────────
if [[ "${RESUME}" -eq 0 ]]; then
  step "Resetting working tree to ${TARGET_REF}..."
  git -C "${SRC_DIR}" reset --hard --quiet
  git -C "${SRC_DIR}" clean -fdx --quiet
  git -C "${SRC_DIR}" checkout --quiet --detach "${TARGET_REF}"
  rm -f "${CONFLICT_FILE}"
else
  step "Resuming after conflict resolution (working tree preserved)"
  if [[ ! -f "${CONFLICT_FILE}" ]]; then
    warn "No conflict marker found — resuming anyway"
  fi
fi

# ── 6. Apply each PR ─────────────────────────────────────────────────────────
APPLIED_PRS=()
SKIPPED_PRS=()
CONFLICT_PR=""
CONFLICT_FILES=""

if [[ "${RESUME}" -eq 0 ]]; then
  step "Applying ${PATCH_COUNT} patch(es)..."

  # Read patch URLs into bash array
  mapfile -t PATCH_URLS < <(python3 -c "import json,sys; [print(x) for x in json.loads(sys.argv[1])]" "${PATCHES_JSON}")

  for pr_url in "${PATCH_URLS[@]}"; do
    pr_num="$(echo "${pr_url}" | grep -oE '/pull/[0-9]+' | grep -oE '[0-9]+$' || true)"
    if [[ -z "${pr_num}" ]]; then
      warn "Cannot extract PR number from ${pr_url} — skipping"
      SKIPPED_PRS+=("${pr_url}")
      continue
    fi

    patch_file="${SRC_DIR}/.pr-${pr_num}.patch"
    if ! curl -fsSL "${pr_url}.patch" -o "${patch_file}" 2>/dev/null; then
      warn "Failed to download patch for PR #${pr_num} — skipping"
      SKIPPED_PRS+=("${pr_url}")
      rm -f "${patch_file}"
      continue
    fi

    # Try clean apply first
    if git -C "${SRC_DIR}" apply --check "${patch_file}" 2>/dev/null; then
      git -C "${SRC_DIR}" apply "${patch_file}"
      log "  ✔ PR #${pr_num} applied cleanly"
      APPLIED_PRS+=("${pr_url}")
      rm -f "${patch_file}"
      continue
    fi

    # Try 3-way merge (leaves conflict markers in working tree)
    if git -C "${SRC_DIR}" apply --3way "${patch_file}" 2>/dev/null; then
      # Check if there are conflict markers
      conflicting="$(git -C "${SRC_DIR}" diff --name-only --diff-filter=U 2>/dev/null || true)"
      if [[ -z "${conflicting}" ]]; then
        log "  ✔ PR #${pr_num} applied via 3-way merge"
        APPLIED_PRS+=("${pr_url}")
        rm -f "${patch_file}"
        continue
      fi
      # Conflicts present → bail to LLM
      CONFLICT_PR="${pr_url}"
      CONFLICT_FILES="${conflicting}"
      break
    fi

    # 3-way also failed (probably no common ancestor) — give up on this PR's
    # autopilot path and surface to LLM
    git -C "${SRC_DIR}" apply --3way "${patch_file}" 2>"${SRC_DIR}/.pr-${pr_num}.err" || true
    CONFLICT_PR="${pr_url}"
    CONFLICT_FILES="$(git -C "${SRC_DIR}" diff --name-only --diff-filter=U 2>/dev/null || true)"
    if [[ -z "${CONFLICT_FILES}" ]]; then
      # No 3-way attempted → leave the patch file so LLM can inspect
      CONFLICT_FILES="(patch did not apply; see ${patch_file} and .pr-${pr_num}.err)"
    fi
    break
  done

  # ── 6a. Conflict path → write CONFLICT.json and exit 3 ─────────────────────
  if [[ -n "${CONFLICT_PR}" ]]; then
    pr_num="$(echo "${CONFLICT_PR}" | grep -oE '[0-9]+$')"
    python3 - "${CONFLICT_FILE}" "${CONFLICT_PR}" "${TARGET_REF}" "${SRC_DIR}" "${CONFLICT_FILES}" \
      "$(printf '%s\n' "${APPLIED_PRS[@]}")" "$(printf '%s\n' "${SKIPPED_PRS[@]}")" <<'PYEOF'
import json, sys
state_file, pr, target, src, files, applied, skipped = sys.argv[1:8]
data = {
  "conflict_pr": pr,
  "target_ref": target,
  "src_dir": src,
  "conflicting_files": [f for f in files.split("\n") if f.strip()],
  "applied_prs": [p for p in applied.split("\n") if p.strip()],
  "skipped_prs": [p for p in skipped.split("\n") if p.strip()],
}
with open(state_file, "w") as f:
  json.dump(data, f, indent=2)
  f.write("\n")
PYEOF
    warn "Merge conflict in ${CONFLICT_PR}"
    warn "Conflicting files:"
    echo "${CONFLICT_FILES}" | sed 's/^/       /'
    echo
    echo -e "  ${TEXT_BOLD}Next steps for the LLM:${TEXT_CLEAR}"
    echo "    1. cd ${SRC_DIR}"
    echo "    2. Resolve conflicts in the listed files (remove <<<<<<< / ======= / >>>>>>> markers)"
    echo "    3. git add <resolved-files>"
    echo "    4. Re-run: bash ${BASH_SOURCE[0]} --resume ${TARGET_ARG}"
    echo
    echo "  Conflict context written to: ${CONFLICT_FILE}"
    exit 3
  fi
fi

# ── 7. Sanity check: ensure no leftover conflicts before building ────────────
if git -C "${SRC_DIR}" diff --name-only --diff-filter=U 2>/dev/null | grep -q .; then
  error "Working tree still has unresolved conflicts. Resolve them and re-run with --resume"
fi

# ── 8. Save combined patch (record of what was applied) ─────────────────────
step "Saving combined patch → ${COMBINED_PATCH}"
git -C "${SRC_DIR}" add -A
git -C "${SRC_DIR}" diff --cached --binary > "${COMBINED_PATCH}" || true
log "Combined patch: $(wc -l < "${COMBINED_PATCH}") lines"

# ── 9. Build ────────────────────────────────────────────────────────────────
step "Installing build dependencies (bun install)..."
( cd "${SRC_DIR}" && bun install --silent )

step "Building opencode (OPENCODE_VERSION=${PATCHED_VERSION}, --single for current OS)..."
(
  cd "${SRC_DIR}"
  OPENCODE_VERSION="${PATCHED_VERSION}" \
  OPENCODE_CHANNEL="patched" \
    bun run ./packages/opencode/script/build.ts --single
)

# Locate built binary (build.ts puts it in dist/opencode-<os>-<arch>/bin/opencode)
BUILT_BINARY="$(find "${SRC_DIR}/packages/opencode/dist" -name 'opencode' -type f -perm -u+x 2>/dev/null | head -1 || true)"
if [[ -z "${BUILT_BINARY}" ]]; then
  error "Build succeeded but binary not found under ${SRC_DIR}/packages/opencode/dist/"
fi
log "Built binary: ${BUILT_BINARY}"

# ── 10. Smoke test the new binary ──────────────────────────────────────────
step "Smoke testing new binary..."
SMOKE_OUTPUT="$("${BUILT_BINARY}" --version 2>&1 || true)"
if [[ "${SMOKE_OUTPUT}" != *"${PATCHED_VERSION}"* ]]; then
  error "Smoke test failed: '${BUILT_BINARY} --version' returned '${SMOKE_OUTPUT}' (expected to contain '${PATCHED_VERSION}')"
fi
log "Smoke test passed: ${SMOKE_OUTPUT}"

# ── 11. Backup current binary, replace ─────────────────────────────────────
if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo
  log "DRY-RUN: skipping backup / install / state-save"
  log "DRY-RUN: built binary left at ${BUILT_BINARY}"
  log "DRY-RUN: combined patch at ${COMBINED_PATCH}"
  log "DRY-RUN: would have replaced ${DEST} (current: $([[ -f ${DEST} ]] && "${DEST}" --version 2>/dev/null || echo "absent"))"
  log "DRY-RUN: ${#APPLIED_PRS[@]} PR(s) applied on ${TARGET_REF}, smoke-test passed"
  exit 0
fi

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
if [[ -f "${DEST}" ]]; then
  CURRENT_VERSION="$("${DEST}" --version 2>/dev/null || echo "unknown")"
  BACKUP_PATH="${BACKUP_DIR}/opencode-v${CURRENT_VERSION}-${TIMESTAMP}"
  cp -p "${DEST}" "${BACKUP_PATH}"
  log "Backed up current binary (v${CURRENT_VERSION}) → ${BACKUP_PATH}"
fi

step "Installing patched binary → ${DEST}"
cp "${BUILT_BINARY}" "${DEST}.new"
chmod +x "${DEST}.new"
mv -f "${DEST}.new" "${DEST}"

# Verify the installed binary still works
INSTALLED_VERSION="$("${DEST}" --version 2>&1 || echo "FAIL")"
if [[ "${INSTALLED_VERSION}" != *"${PATCHED_VERSION}"* ]]; then
  warn "Installed binary failed verification (returned '${INSTALLED_VERSION}'). Restoring backup."
  if [[ -n "${BACKUP_PATH:-}" && -f "${BACKUP_PATH}" ]]; then
    mv -f "${BACKUP_PATH}" "${DEST}"
    error "Patched binary broken — backup restored"
  fi
  error "Patched binary broken and no backup available"
fi
log "Installed: opencode --version → ${INSTALLED_VERSION}"

# ── 12. Save state ──────────────────────────────────────────────────────────
BINARY_SHA="$(sha256sum "${DEST}" | cut -d' ' -f1)"
python3 - "${STATE_FILE}" "${TARGET_REF}" "${PATCHED_VERSION}" "${BINARY_SHA}" \
  "$(date -Iseconds)" "$(printf '%s\n' "${APPLIED_PRS[@]}")" "$(printf '%s\n' "${SKIPPED_PRS[@]}")" <<'PYEOF'
import json, sys
state_file, target, version, sha, ts, applied, skipped = sys.argv[1:8]
state = {
  "patched_version": version,
  "target_ref": target,
  "binary_sha": sha,
  "timestamp": ts,
  "applied_prs": [p for p in applied.split("\n") if p.strip()],
  "skipped_prs": [p for p in skipped.split("\n") if p.strip()],
}
with open(state_file, "w") as f:
  json.dump(state, f, indent=2)
  f.write("\n")
PYEOF
log "State → ${STATE_FILE}"

rm -f "${CONFLICT_FILE}"

echo
log "opencode patched successfully (${#APPLIED_PRS[@]} PR(s) applied on ${TARGET_REF}, stamped as v${PATCHED_VERSION})"
