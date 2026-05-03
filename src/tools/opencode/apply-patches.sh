#!/usr/bin/env bash
# Apply configured upstream PR patches to opencode by building from source.
# Exit codes: 0=success  1=failure  2=no patches configured (not an error)

set -euo pipefail

TOOLS_PATH="${TOOLS_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TELAMON_ROOT="${TELAMON_ROOT:-$(cd "${TOOLS_PATH}/../.." && pwd)}"
# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

header "opencode patches"

# ── 1. Read opencode_patches from .telamon.jsonc ──────────────────────────────
CONFIG_FILE="${TELAMON_ROOT}/.telamon.jsonc"

if [[ ! -f "${CONFIG_FILE}" ]]; then
  warn ".telamon.jsonc not found at ${CONFIG_FILE}"
  exit 1
fi

PATCHES_JSON="$(python3 - "${CONFIG_FILE}" <<'PYEOF'
import json, re, sys

def strip(t): return re.sub(r'(?m)(?<!:)//.*$', '', t)

with open(sys.argv[1]) as f:
    data = json.loads(strip(f.read()))

patches = data.get('opencode_patches', [])
print(json.dumps(patches))
PYEOF
)"

PATCH_COUNT="$(python3 -c "import json, sys; print(len(json.loads(sys.argv[1])))" "${PATCHES_JSON}")"

if [[ "${PATCH_COUNT}" -eq 0 ]]; then
  skip "opencode patches (none configured)"
  exit 2
fi

step "Found ${PATCH_COUNT} patch(es) to apply..."

# ── 2. Ensure Bun meets minimum version ──────────────────────────────────────
_install_bun() {
  step "Installing/upgrading bun..."
  curl -fsSL https://bun.sh/install | bash
  export PATH="$HOME/.bun/bin:$PATH"
}

BUN_REQUIRED="$(config.read_ini "${CONFIG_FILE}" "bun_version" 2>/dev/null || echo "")"
# Strip ^ or ~ prefix to get the minimum version
BUN_MIN="${BUN_REQUIRED#^}"
BUN_MIN="${BUN_MIN#~}"
BUN_MIN="${BUN_MIN:-1.3.13}"  # fallback if not configured

if ! command -v bun &>/dev/null; then
  _install_bun
fi

BUN_CURRENT="$(bun --version 2>/dev/null || echo "0.0.0")"
if [[ $(os.version_to_number "${BUN_CURRENT}") -lt $(os.version_to_number "${BUN_MIN}") ]]; then
  warn "bun ${BUN_CURRENT} is below required ${BUN_MIN}"
  _install_bun
  BUN_CURRENT="$(bun --version 2>/dev/null || echo "0.0.0")"
  if [[ $(os.version_to_number "${BUN_CURRENT}") -lt $(os.version_to_number "${BUN_MIN}") ]]; then
    warn "bun upgrade failed — version ${BUN_CURRENT} still below ${BUN_MIN}"
    exit 1
  fi
fi

log "bun ${BUN_CURRENT} (required: ${BUN_REQUIRED:-≥${BUN_MIN}})"

# ── 3. Clone or update opencode source ───────────────────────────────────────
REPO_URL="https://github.com/anomalyco/opencode.git"
SRC_DIR="${TELAMON_ROOT}/storage/opencode-src"

if [[ -d "${SRC_DIR}/.git" ]]; then
  step "Updating opencode source..."
  git -C "${SRC_DIR}" fetch --all --quiet
  log "opencode source updated"
else
  step "Cloning opencode source..."
  git clone "${REPO_URL}" "${SRC_DIR}" --quiet
  log "opencode source cloned → ${SRC_DIR}"
fi

# ── 4. Determine current opencode version ────────────────────────────────────
VERSION="$(opencode --version 2>/dev/null || echo "")"

if [[ -z "${VERSION}" ]]; then
  warn "opencode not installed — cannot determine version to patch"
  exit 1
fi

log "opencode version: ${VERSION}"

# ── 5. Checkout the version tag ───────────────────────────────────────────────
step "Checking out v${VERSION}..."
# Hard reset to clear any leftover state from previous failed runs
# (git apply --3way stages conflicted files normally, so checkout --force alone
# may not fully clean them)
git -C "${SRC_DIR}" reset --hard --quiet 2>/dev/null || true
if git -C "${SRC_DIR}" tag | grep -q "^v${VERSION}$"; then
  git -C "${SRC_DIR}" checkout "v${VERSION}" --force --quiet
  log "Checked out tag v${VERSION}"
else
  warn "Tag v${VERSION} not found — falling back to dev branch"
  git -C "${SRC_DIR}" checkout dev --force --quiet 2>/dev/null \
    || git -C "${SRC_DIR}" checkout main --force --quiet
  log "Checked out dev/main branch"
fi

# ── 6. Apply each patch ───────────────────────────────────────────────────────
step "Applying patches..."

python3 - "${PATCHES_JSON}" "${SRC_DIR}" <<'PYEOF'
import json, os, re, subprocess, sys

patches = json.loads(sys.argv[1])
src_dir = sys.argv[2]

for pr_url in patches:
    m = re.search(r'/pull/([0-9]+)$', pr_url)
    if not m:
        print(f"  WARN: Cannot extract PR number from URL: {pr_url}", flush=True)
        continue

    pr_num = m.group(1)
    patch_file = os.path.join(src_dir, f"pr-{pr_num}.patch")

    # Download patch
    result = subprocess.run(
        ["curl", "-sL", f"{pr_url}.patch", "-o", patch_file],
        capture_output=True
    )
    if result.returncode != 0:
        print(f"  WARN: Failed to download patch for PR #{pr_num}", flush=True)
        if os.path.exists(patch_file):
            os.remove(patch_file)
        continue

    # Fetch PR ref so git has blobs needed for 3-way merge
    subprocess.run(
        ["git", "-C", src_dir, "fetch", "origin", f"pull/{pr_num}/head"],
        capture_output=True, text=True
    )

    # Apply patch with 3-way merge
    result = subprocess.run(
        ["git", "-C", src_dir, "apply", "--3way", patch_file],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        # git apply --3way may leave conflict markers in files without creating
        # proper unmerged index entries. Scan all modified files for markers.
        modified = subprocess.run(
            ["git", "-C", src_dir, "diff", "--name-only", "HEAD"],
            capture_output=True, text=True
        )
        conflicted_files = []
        for f in (modified.stdout.strip().split("\n") if modified.stdout.strip() else []):
            fpath = os.path.join(src_dir, f)
            if not os.path.isfile(fpath):
                continue
            with open(fpath, "r") as fh:
                content = fh.read()
            if "<<<<<<< ours" not in content:
                continue
            # Strip conflict markers keeping "theirs" (the patch version)
            content = re.sub(
                r'<<<<<<< ours\n.*?=======\n(.*?)>>>>>>> theirs\n',
                r'\1',
                content,
                flags=re.DOTALL
            )
            with open(fpath, "w") as fh:
                fh.write(content)
            subprocess.run(
                ["git", "-C", src_dir, "add", "--", f],
                capture_output=True, text=True
            )
            conflicted_files.append(f)
        if conflicted_files:
            print(f"  ✔  Applied PR #{pr_num} (resolved {len(conflicted_files)} conflict(s))", flush=True)
        else:
            print(f"  WARN: Failed to apply patch for PR #{pr_num}: {result.stderr.strip()}", flush=True)
    else:
        print(f"  ✔  Applied PR #{pr_num} ({pr_url})", flush=True)

    # Clean up patch file
    if os.path.exists(patch_file):
        os.remove(patch_file)
PYEOF

# ── 7. Build ──────────────────────────────────────────────────────────────────
step "Installing dependencies..."
bun install --cwd "${SRC_DIR}" --quiet

step "Building opencode..."
bun run --cwd "${SRC_DIR}/packages/opencode" build -- --single --skip-install

# ── 8. Find and install the built binary ─────────────────────────────────────
step "Locating built binary..."
BUILT_BINARY="$(find "${SRC_DIR}/packages/opencode" -name "opencode" -type f -executable 2>/dev/null | head -1 || true)"

if [[ -z "${BUILT_BINARY}" ]]; then
  warn "Could not find compiled opencode binary after build"
  exit 1
fi

log "Built binary: ${BUILT_BINARY}"

DEST="${HOME}/.opencode/bin/opencode"
mkdir -p "$(dirname "${DEST}")"
cp "${BUILT_BINARY}" "${DEST}"
chmod +x "${DEST}"
log "Installed patched opencode → ${DEST}"

# ── 9. Save state ─────────────────────────────────────────────────────────────
STATE_FILE="${TELAMON_ROOT}/storage/opencode-patch-state.json"
BINARY_SHA="$(sha256sum "${DEST}" | cut -d' ' -f1)"
TIMESTAMP="$(date -Iseconds)"

python3 - "${STATE_FILE}" "${VERSION}" "${PATCHES_JSON}" "${BINARY_SHA}" "${TIMESTAMP}" <<'PYEOF'
import json, sys

state_file = sys.argv[1]
version    = sys.argv[2]
patches    = json.loads(sys.argv[3])
binary_sha = sys.argv[4]
timestamp  = sys.argv[5]

state = {
    "version":    version,
    "patches":    patches,
    "binary_sha": binary_sha,
    "timestamp":  timestamp,
}

with open(state_file, "w") as f:
    json.dump(state, f, indent=2)
    f.write("\n")
PYEOF

log "Patch state saved → ${STATE_FILE}"
log "opencode patched successfully (v${VERSION}, ${PATCH_COUNT} patch(es))"
