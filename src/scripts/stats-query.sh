#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TELAMON_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DB_PATH="$TELAMON_ROOT/storage/stats/stats.sqlite"

if [[ ! -f "$DB_PATH" ]]; then
  echo "No statistics database found"
  exit 0
fi

# Parse arguments
PROJECT=""
FROM=""
TO=""
OUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)
      PROJECT="$2"
      shift 2
      ;;
    --from)
      FROM="$2"
      shift 2
      ;;
    --to)
      TO="$2"
      shift 2
      ;;
    --out)
      OUT="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

# Build SQL query
QUERY="SELECT tool, agent, skill, project, timestamp FROM tool_calls"
WHERE_CLAUSES=()

if [[ -n "$PROJECT" ]]; then
  WHERE_CLAUSES+=("project = '$PROJECT'")
fi
if [[ -n "$FROM" ]]; then
  WHERE_CLAUSES+=("timestamp >= '$FROM'")
fi
if [[ -n "$TO" ]]; then
  WHERE_CLAUSES+=("timestamp <= '${TO}T23:59:59'")
fi

if [[ ${#WHERE_CLAUSES[@]} -gt 0 ]]; then
  QUERY="$QUERY WHERE $(IFS=' AND '; echo "${WHERE_CLAUSES[*]}")"
fi

QUERY="$QUERY ORDER BY timestamp DESC"

# Prepare output file
if [[ -n "$OUT" ]]; then
  [[ "$OUT" != /* ]] && OUT="$PWD/$OUT"
  OUTPUT_FILE="$OUT"
  mkdir -p "$(dirname "$OUTPUT_FILE")"
else
  THINKING_DIR="$TELAMON_ROOT/.ai/telamon/memory/thinking"
  mkdir -p "$THINKING_DIR"
  FILENAME="$(date '+%Y%m%d-%H%M%S')-stats.csv"
  OUTPUT_FILE="$THINKING_DIR/$FILENAME"
fi

# Run query
sqlite3 -header -csv "$DB_PATH" "$QUERY" > "$OUTPUT_FILE"

ROW_COUNT=$(( $(wc -l < "$OUTPUT_FILE") - 1 ))
echo "$OUTPUT_FILE"
echo "$ROW_COUNT rows written to $OUTPUT_FILE"
