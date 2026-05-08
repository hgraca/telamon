#!/usr/bin/env bash
# Install the GitHub CLI (`gh`) and configure authentication for Telamon agents.
#
# Replaces the previous `mcp/github` Docker-based MCP server. Agents now drive
# GitHub via the `gh` CLI directly (PRs, reviews, issues, repo operations).
#
# Steps:
#   1. Install gh (idempotent — skips if already on PATH).
#   2. Prompt for a Personal Access Token (PAT) if no secret exists yet.
#      The token is persisted to ${SECRETS_DIR}/gh_pat (mode 600) and used by
#      `gh auth login --with-token` to authenticate the CLI.
#
# Recommended PAT:
#   Classic Personal Access Token with scopes:
#     - repo       (read repos, push commits, create/read PRs, reply to review comments)
#     - read:org   (only if the target repos belong to an SSO-protected org)
#   Create at: https://github.com/settings/tokens

set -euo pipefail

TOOLS_PATH="${TOOLS_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SECRETS_DIR="${SECRETS_DIR:-$(cd "${TOOLS_PATH}/../.." && pwd)/storage/secrets}"
export TOOLS_PATH FUNCTIONS_PATH SECRETS_DIR

# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

header "GitHub CLI (gh)"

# ── 1. Install the binary ────────────────────────────────────────────────────
if command -v gh &>/dev/null; then
  skip "gh ($(gh --version | head -1 | awk '{print $3}'))"
else
  OS=$(os.get_os)
  if [[ "${OS}" == "macos" ]]; then
    step "Installing gh via Homebrew..."
    brew install gh
  else
    step "Installing gh via apt..."
    apt.install gh
  fi
  log "gh installed ($(gh --version | head -1 | awk '{print $3}'))"
fi

# ── 2. Configure authentication ──────────────────────────────────────────────
GH_PAT_FILE="${SECRETS_DIR}/gh_pat"
PLACEHOLDER_PREFIX="CREATE_A_PAT_AS_IN_IMAGE"

# Read existing token (if any) and detect placeholder.
existing_token=""
if [[ -f "${GH_PAT_FILE}" ]]; then
  existing_token="$(cat "${GH_PAT_FILE}" 2>/dev/null || true)"
  if [[ -z "${existing_token}" || "${existing_token}" == ${PLACEHOLDER_PREFIX}* ]]; then
    existing_token=""
  fi
fi

if [[ -z "${existing_token}" ]]; then
  echo
  echo -e "  ${TEXT_BOLD}GitHub authentication setup${TEXT_CLEAR}"
  echo "    Create a classic Personal Access Token at:"
  echo "      https://github.com/settings/tokens"
  echo "    Required scopes:"
  echo "      - repo       (read repos, push commits, PRs, review comments)"
  echo "      - read:org   (only if the target repos use SSO-protected orgs)"
  echo
  ask "Paste GitHub PAT (leave empty to skip and configure later):"
  # Read silently so the token does not echo to the terminal.
  read -rs PAT_INPUT
  echo

  if [[ -z "${PAT_INPUT}" ]]; then
    warn "No PAT provided. Telamon will run without GitHub access until you re-run this installer."
    skip "gh authentication"
    exit 0
  fi

  secrets.write --force gh_pat "${PAT_INPUT}"
  existing_token="${PAT_INPUT}"
else
  skip "gh PAT (already present at ${GH_PAT_FILE})"
fi

# ── 3. Hand the token to gh ──────────────────────────────────────────────────
# `gh auth login --with-token` reads the token from stdin and stores it in the
# CLI's config (~/.config/gh/hosts.yml). Idempotent — overwrites prior login.
step "Authenticating gh with stored PAT..."
if printf '%s' "${existing_token}" | gh auth login --with-token 2>/dev/null; then
  if gh auth status &>/dev/null; then
    log "gh authenticated as $(gh api user --jq .login 2>/dev/null || echo '<unknown>')"
  else
    warn "gh auth login succeeded but 'gh auth status' failed — check network or token scopes."
  fi
else
  warn "gh auth login failed — token may be invalid. Re-run installer with a valid PAT."
fi
