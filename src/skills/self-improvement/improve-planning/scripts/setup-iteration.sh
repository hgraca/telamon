#!/usr/bin/env bash
# setup-iteration.sh — Prepare an iteration folder for the improve-planning skill.
#
# Usage:
#   setup-iteration.sh <model-id>
#     <model-id>  Required when stdin is not a TTY. Optional in interactive use
#                 (script will prompt). Example: github-copilot/claude-opus-4.7
#
# Steps:
#   1. Determine next iteration number under storage/self-improvement/improve-planning/.
#   2. Copy references/poke-api-kata/ contents into iteration-<n>/.
#   3. Run `telamon init` against the iteration folder, with project-side memory ownership.
#   4. Materialize opencode.jsonc (replace symlink with a real file).
#   5. Use the model passed as $1 (or prompt interactively) and rewrite agent
#      model assignments in opencode.jsonc and agent frontmatter.
#   6. Print instructions to start a new opencode session inside the iteration folder.

set -euo pipefail

# -- locate skill root ---------------------------------------------------------
_resolve() {
  local p="$1"
  while [ -L "$p" ]; do
    local d; d="$(cd "$(dirname "$p")" && pwd)"
    p="$(readlink "$p")"
    [[ "$p" != /* ]] && p="$d/$p"
  done
  echo "$(cd "$(dirname "$p")" && pwd)/$(basename "$p")"
}

SCRIPT_PATH="$(_resolve "${BASH_SOURCE[0]}")"
SCRIPTS_DIR="$(cd "$(dirname "${SCRIPT_PATH}")" && pwd)"
SKILL_DIR="$(cd "${SCRIPTS_DIR}/.." && pwd)"
TASK_TMPL="${SKILL_DIR}/references/poke-api-kata"

# Telamon root = up 5 levels: scripts -> improve-planning -> self-improvement -> skills -> src -> root
TELAMON_ROOT="$(cd "${SKILL_DIR}/../../../.." && pwd)"
STORAGE_DIR="${TELAMON_ROOT}/storage/self-improvement/improve-planning"

# -- colors --------------------------------------------------------------------
if [[ -t 1 ]]; then
  C_BLUE=$'\033[34m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'
  C_RED=$'\033[31m'; C_BOLD=$'\033[1m'; C_RESET=$'\033[0m'
else
  C_BLUE=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_BOLD=""; C_RESET=""
fi

log()  { echo "${C_BLUE}▸${C_RESET} $*"; }
ok()   { echo "${C_GREEN}✔${C_RESET} $*"; }
warn() { echo "${C_YELLOW}⚠${C_RESET} $*"; }
die()  { echo "${C_RED}✖${C_RESET} $*" >&2; exit 1; }

# -- pre-flight ----------------------------------------------------------------
[[ -d "${TASK_TMPL}" ]] || die "Task template not found: ${TASK_TMPL}"
command -v telamon >/dev/null 2>&1 || die "'telamon' CLI not found in PATH"

mkdir -p "${STORAGE_DIR}"

# -- determine iteration number ------------------------------------------------
NEXT_N=1
for d in "${STORAGE_DIR}"/iteration-*; do
  [[ -d "$d" ]] || continue
  n="${d##*/iteration-}"
  [[ "$n" =~ ^[0-9]+$ ]] || continue
  (( n >= NEXT_N )) && NEXT_N=$(( n + 1 ))
done

ITER_DIR="${STORAGE_DIR}/iteration-${NEXT_N}"
[[ -e "${ITER_DIR}" ]] && die "Iteration folder already exists: ${ITER_DIR}"

log "Creating ${C_BOLD}iteration-${NEXT_N}${C_RESET} at ${ITER_DIR}"
mkdir -p "${ITER_DIR}"

# -- failure rollback ----------------------------------------------------------
# If anything fails between here and the explicit `SUCCESS=1` at the end,
# remove the partial iteration folder so the next run starts clean.
SUCCESS=0
_rollback() {
  local rc=$?
  if (( SUCCESS == 0 )) && [[ -d "${ITER_DIR}" ]]; then
    echo
    warn "Setup failed (exit ${rc}). Rolling back partial iteration folder..."
    rm -rf "${ITER_DIR}"
    ok "Removed ${ITER_DIR}"
    echo
    echo "${C_RED}${C_BOLD}Setup did not complete.${C_RESET} Diagnose the failure"
    echo "above, fix the cause, and re-run the script. If you cannot diagnose"
    echo "or fix it, return to the main improve-planning session and ask the"
    echo "agent for instructions."
  fi
}
trap _rollback EXIT

# -- copy task template --------------------------------------------------------
log "Copying task template (excluding composer binary)..."
# rsync excludes the composer binary (2.9M); we install it fresh below.
# If rsync is unavailable, fall back to cp -a then delete the binary.
if command -v rsync >/dev/null 2>&1; then
  rsync -a --exclude='composer' "${TASK_TMPL}/" "${ITER_DIR}/"
else
  cp -a "${TASK_TMPL}/." "${ITER_DIR}/"
  rm -f "${ITER_DIR}/composer"
fi
ok "Task template copied"

# -- install composer binary ---------------------------------------------------
# Avoid copying the 2.9M composer binary into every iteration folder.
# Prefer system composer (symlink); otherwise download it once into the
# iteration folder.
log "Provisioning composer..."
if command -v composer >/dev/null 2>&1; then
  ln -sf "$(command -v composer)" "${ITER_DIR}/composer"
  ok "Symlinked system composer"
elif [[ -x "${TASK_TMPL}/composer" ]]; then
  # Fall back to the bundled binary if nothing else works.
  cp "${TASK_TMPL}/composer" "${ITER_DIR}/composer"
  ok "Copied bundled composer (no system composer found)"
else
  # Last resort: download from getcomposer.org.
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL https://getcomposer.org/download/latest-stable/composer.phar \
      -o "${ITER_DIR}/composer"
    chmod +x "${ITER_DIR}/composer"
    ok "Downloaded composer.phar from getcomposer.org"
  else
    die "No composer available: no system composer, no bundled binary, no curl"
  fi
fi

# -- isolate iteration as its own git root -------------------------------------
# Opencode discovers project config by walking up to the nearest git root,
# merging every opencode.jsonc along the way. Without this step, the iteration
# session would inherit (and try to resolve {file:...} secret refs against)
# every outer opencode.jsonc up to the workspace root. We make the iteration
# its own git root so opencode stops discovery here.
log "Initialising iteration as its own git root (isolation barrier)..."
git -C "${ITER_DIR}" init -q
ok "Git root created — opencode discovery will stop at this folder"

# -- run telamon init with project-side memory ownership -----------------------
log "Running 'telamon init' (memory ownership: project-side)..."
# TELAMON_MEMORY_OWNER=project signals init to keep memory inside the project
# instead of symlinking to storage/projects-memory/. If the init script does not
# support this env var, the user will see a clear error and can adjust.
TELAMON_MEMORY_OWNER=project telamon init "${ITER_DIR}"
ok "Project initialised"

# -- materialise opencode.jsonc (resolve symlink to a real file) ---------------
OPENCODE_JSONC="${ITER_DIR}/opencode.jsonc"
if [[ -L "${OPENCODE_JSONC}" ]]; then
  log "Materialising opencode.jsonc (was a symlink)..."
  TARGET="$(_resolve "${OPENCODE_JSONC}")"
  [[ -f "${TARGET}" ]] || die "Symlink target does not exist: ${TARGET}"
  rm "${OPENCODE_JSONC}"
  cp "${TARGET}" "${OPENCODE_JSONC}"
  ok "opencode.jsonc is now a regular file"
elif [[ -f "${OPENCODE_JSONC}" ]]; then
  ok "opencode.jsonc already a regular file"
else
  die "opencode.jsonc not found in ${ITER_DIR}"
fi

# -- detect current model ------------------------------------------------------
CURRENT_MODEL="$(grep -E '^\s*"model"\s*:' "${OPENCODE_JSONC}" \
  | head -1 | sed -E 's/.*"model"\s*:\s*"([^"]+)".*/\1/')"
[[ -n "${CURRENT_MODEL}" ]] || CURRENT_MODEL="github-copilot/claude-opus-4.6"

# -- determine model -----------------------------------------------------------
# Model may be passed as the first positional argument (preferred — non-interactive,
# allows the calling agent to choose). If absent and stdin is a TTY, prompt
# interactively. If absent and stdin is not a TTY, fail loudly rather than
# silently default (silent defaults make iterations non-comparable).
if [[ $# -ge 1 && -n "${1:-}" ]]; then
  CHOSEN_MODEL="$1"
  log "Using model from argument: ${C_BOLD}${CHOSEN_MODEL}${C_RESET}"
elif [[ -t 0 ]]; then
  echo
  echo "${C_BOLD}Select the LLM model for the agents in this iteration${C_RESET}"
  echo "Current default: ${CURRENT_MODEL}"
  read -r -p "Model [${CURRENT_MODEL}]: " CHOSEN_MODEL
  CHOSEN_MODEL="${CHOSEN_MODEL:-${CURRENT_MODEL}}"
  log "Using model: ${C_BOLD}${CHOSEN_MODEL}${C_RESET}"
else
  die "No model passed as argument and stdin is not a TTY. Pass model as: $0 <model-id>"
fi

# -- rewrite top-level model + assign to agents --------------------------------
# Replace the top-level "model": "..." line.
python3 - "${OPENCODE_JSONC}" "${CHOSEN_MODEL}" <<'PY'
import json, re, sys, pathlib

path = pathlib.Path(sys.argv[1])
model = sys.argv[2]
text = path.read_text()

# 1. Top-level "model": "..."
text = re.sub(
    r'("model"\s*:\s*)"[^"]*"',
    lambda m: f'{m.group(1)}"{model}"',
    text,
    count=1,
)

# 2. Ensure agent.<name>.model = chosen for the planning agents.
#    We mutate via JSONC-aware approach: strip comments, parse, mutate, then
#    write back as JSON (comments lost — acceptable for an iteration sandbox).
def strip_jsonc(s: str) -> str:
    out = []
    i, n = 0, len(s)
    in_str = False
    while i < n:
        c = s[i]
        if in_str:
            out.append(c)
            if c == '\\' and i + 1 < n:
                out.append(s[i+1]); i += 2; continue
            if c == '"': in_str = False
            i += 1; continue
        if c == '"': in_str = True; out.append(c); i += 1; continue
        if c == '/' and i + 1 < n and s[i+1] == '/':
            while i < n and s[i] != '\n': i += 1
            continue
        if c == '/' and i + 1 < n and s[i+1] == '*':
            i += 2
            while i + 1 < n and not (s[i] == '*' and s[i+1] == '/'): i += 1
            i += 2; continue
        out.append(c); i += 1
    return ''.join(out)

try:
    data = json.loads(strip_jsonc(text))
except Exception as e:
    sys.stderr.write(f"Failed to parse opencode.jsonc as JSONC: {e}\n")
    # Top-level model was already replaced via regex; that's the minimum.
    path.write_text(text)
    sys.exit(0)

agents = data.setdefault("agent", {})
# Only the four planning agents are in scope for this skill.
for name in ("telamon/telamon", "telamon/po", "telamon/architect",
             "telamon/critic"):
    a = agents.setdefault(name, {})
    a["model"] = model

# 3. If the chosen model is on the cortecs provider, inject the provider
#    config so opencode can authenticate. The apiKey is loaded from a secret
#    file (resolved relative to this opencode.jsonc's directory).
if model.startswith("cortecs/"):
    providers = data.setdefault("provider", {})
    cortecs = providers.setdefault("cortecs", {})
    options = cortecs.setdefault("options", {})
    options["apiKey"] = "{file:.ai/telamon/secrets/provider-key-cortecs}"

path.write_text(json.dumps(data, indent=2) + "\n")
PY

# Report whether the cortecs provider was injected.
if [[ "${CHOSEN_MODEL}" == cortecs/* ]]; then
  ok "Cortecs provider injected (apiKey from .ai/telamon/secrets/provider-key-cortecs)"
fi

ok "Model assigned to planning agents in opencode.jsonc"

# -- materialise planning agent files (override frontmatter model) -------------
# Agent .md files have a `model:` line in their frontmatter that takes
# precedence over agent.<name>.model in opencode.jsonc. The .opencode/agents/
# tree is symlinked to src/agents (shared across all sessions), so we cannot
# edit the source — that would leak the iteration's model choice globally.
# Instead, we replace the symlinked dir with a real dir of copies, then
# rewrite the model: line for the four planning agents only.
log "Materialising planning agent files (frontmatter model override)..."

AGENTS_LINK="${ITER_DIR}/.opencode/agents/telamon"
if [[ -L "${AGENTS_LINK}" ]]; then
  AGENTS_TARGET="$(_resolve "${AGENTS_LINK}")"
  [[ -d "${AGENTS_TARGET}" ]] || die "Agents symlink target is not a directory: ${AGENTS_TARGET}"
  rm "${AGENTS_LINK}"
  mkdir -p "${AGENTS_LINK}"
  cp -a "${AGENTS_TARGET}/." "${AGENTS_LINK}/"
  ok "Replaced .opencode/agents/telamon symlink with a real directory of copies"
elif [[ -d "${AGENTS_LINK}" ]]; then
  ok ".opencode/agents/telamon already a regular directory"
else
  die ".opencode/agents/telamon not found in ${ITER_DIR}"
fi

# Rewrite the `model:` frontmatter line on the four planning agents only.
# Other agents (developer, reviewer, tester, etc.) keep their original model.
for agent in telamon po architect critic; do
  agent_file="${AGENTS_LINK}/${agent}.md"
  [[ -f "${agent_file}" ]] || die "Planning agent file missing: ${agent_file}"
  # Replace the model: line in YAML frontmatter (between the first two `---`).
  # Use sed in-place; only the first match (frontmatter is at the top).
  python3 - "${agent_file}" "${CHOSEN_MODEL}" <<'PY'
import re, sys, pathlib
path = pathlib.Path(sys.argv[1])
model = sys.argv[2]
text = path.read_text()
# Only touch the frontmatter (first --- ... --- block).
m = re.match(r'^(---\n)(.*?)(\n---\n)', text, re.DOTALL)
if not m:
    sys.stderr.write(f"WARN: no YAML frontmatter found in {path}\n")
    sys.exit(0)
fm = m.group(2)
new_fm, n = re.subn(r'^model:\s*.*$', f'model: {model}', fm, count=1, flags=re.MULTILINE)
if n == 0:
    # No model line — append one.
    new_fm = fm + f'\nmodel: {model}'
text = m.group(1) + new_fm + m.group(3) + text[m.end():]
path.write_text(text)
PY
  ok "Patched ${agent}.md → model: ${CHOSEN_MODEL}"
done

# Mark setup as successful so the rollback trap will not fire on EXIT.
SUCCESS=1

# -- final instructions --------------------------------------------------------
cat <<EOF

${C_GREEN}${C_BOLD}Iteration ${NEXT_N} ready.${C_RESET}

${C_BOLD}Next steps:${C_RESET}

  1. Open a new opencode session in the iteration folder:

       ${C_BOLD}cd ${ITER_DIR}${C_RESET}
       ${C_BOLD}opencode${C_RESET}

  2. In that new session, tell the agent:

       ${C_BOLD}"Execute the instructions in PROMPT.md"${C_RESET}

  3. Wait for the task-solver session to finish Phase 1 (planning only —
     no implementation) and Phase 2 (write interactions.md). It will NOT
     ask for approvals.

  4. When the solver session reports completion, ${C_BOLD}return to the main
     (improve-planning) session${C_RESET} and tell the agent:

       ${C_BOLD}"Evaluate iteration ${NEXT_N}"${C_RESET}

EOF
