#!/usr/bin/env bash
# Returns 1 if running inside a Docker container, 0 otherwise.
if [ -f /.dockerenv ] || grep -q docker /proc/1/cgroup 2>/dev/null; then
  echo 1
else
  echo 0
fi
