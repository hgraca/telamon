#!/usr/bin/env bash

# Idempotent state tracking — records completed steps so re-runs are safe.
# State is stored in ~/.config/ogham/.setup-state

STATE_DIR="${STATE_DIR:-$HOME/.config/ogham}"
STATE_FILE="$STATE_DIR/.setup-state"

state.done() { grep -q "^$1$" "$STATE_FILE" 2>/dev/null; }
state.mark() { mkdir -p "$STATE_DIR"; echo "$1" >> "$STATE_FILE"; sort -u "$STATE_FILE" -o "$STATE_FILE"; }
