#!/usr/bin/env bash

# Idempotent state tracking — records completed steps so re-runs are safe.
# State is stored in <adk-root>/storage/state/.setup-state
# STATE_DIR is exported by run.sh; the fallback below is used only when
# this file is sourced standalone (e.g. during development/testing).

STATE_DIR="${STATE_DIR:-${ADK_ROOT:+${ADK_ROOT}/storage/state}}"
STATE_DIR="${STATE_DIR:-$HOME/.config/adk/state}"
STATE_FILE="$STATE_DIR/.setup-state"

state.done() { grep -q "^$1$" "$STATE_FILE" 2>/dev/null; }
state.mark() { mkdir -p "$STATE_DIR"; echo "$1" >> "$STATE_FILE"; sort -u "$STATE_FILE" -o "$STATE_FILE"; }
