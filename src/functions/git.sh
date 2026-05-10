#!/usr/bin/env bash
# Git-related shared helpers.
#
# install_telamon_hook <hook-name> <body>
#   Installs (or replaces) a TELAMON-marked section inside the named git hook
#   file under "${PROJ}/.git/hooks/<hook-name>". Idempotent: multiple calls for
#   the same hook with the same body produce the same final file.
#
#   Multiple modules can call this for the same hook (e.g. several modules
#   contributing lines to post-commit) — each call appends a fresh TELAMON
#   section. Re-running an installer replaces only that module's section by
#   matching on the body's first line as a per-module fingerprint.
#
#   Requires: PROJ env var (absolute path to the project root).
#   Side effects: creates the hook file if missing, chmod +x.
#
#   Pattern: hook bodies are wrapped between TELAMON START / END markers so
#   they can be stripped on re-install without touching user-authored hook
#   content. Existing user content is preserved.

install_telamon_hook() {
  local hook_name="$1"
  local hook_body="$2"

  local proj="${PROJ:?install_telamon_hook requires PROJ env var}"
  local hooks_dir="${proj}/.git/hooks"

  if [[ ! -d "${hooks_dir}" ]]; then
    warn "No .git/hooks directory in ${proj} — skipping ${hook_name} hook install"
    return 0
  fi

  local hook_file="${hooks_dir}/${hook_name}"
  local marker_start="# ── TELAMON START ──"
  local marker_end="# ── TELAMON END ──"

  # Per-module fingerprint: first non-empty line of the body. Used to remove
  # only this module's previously-installed section while preserving sections
  # contributed by other modules.
  local fingerprint
  fingerprint="$(printf '%s\n' "${hook_body}" | sed -n '/[^[:space:]]/{p;q;}')"

  local section
  section="$(printf '%s\n%s\n%s\n' "${marker_start}" "${hook_body}" "${marker_end}")"

  if [[ -f "${hook_file}" ]]; then
    # Remove the prior TELAMON section whose body starts with our fingerprint.
    # awk state machine: when we see MARKER_START, buffer the section; if its
    # first body line matches the fingerprint, drop the whole section; else
    # flush it back out.
    local tmp
    tmp="$(mktemp)"
    awk -v ms="${marker_start}" -v me="${marker_end}" -v fp="${fingerprint}" '
      BEGIN { in_section=0; matched=0; n=0 }
      {
        if (!in_section && $0 == ms)        { in_section=1; n=0; matched=0; buf[n++]=$0; next }
        if (in_section) {
          buf[n++]=$0
          if (matched==0 && $0 != ms && $0 !~ /^[[:space:]]*$/) {
            matched = ($0 == fp) ? 1 : 2
          }
          if ($0 == me) {
            if (matched != 1) { for (i=0;i<n;i++) print buf[i] }
            in_section=0; n=0; matched=0
          }
          next
        }
        print
      }
    ' "${hook_file}" > "${tmp}"

    # Trim trailing blank lines then append the new section with a separator.
    local existing
    existing="$(sed -e '/./,$!d' "${tmp}" | sed -e :a -e '/^\n*$/{$d;N;ba}')"
    if [[ -n "${existing}" ]]; then
      printf '%s\n\n%s\n' "${existing}" "${section}" > "${hook_file}"
    else
      printf '#!/usr/bin/env bash\n\n%s\n' "${section}" > "${hook_file}"
    fi
    rm -f "${tmp}"
  else
    printf '#!/usr/bin/env bash\n\n%s\n' "${section}" > "${hook_file}"
  fi

  chmod +x "${hook_file}"
}
