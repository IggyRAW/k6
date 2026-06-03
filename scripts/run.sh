#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <project> <scenario> [k6 options...]"
  echo "  scenario: smoke | load"
  exit 1
}

if [[ $# -lt 2 ]]; then
  usage
fi

PROJECT="$1"
SCENARIO="$2"
shift 2

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SCRIPT_PATH="projects/${PROJECT}/scripts/${SCENARIO}.js"
if [[ ! -f "$SCRIPT_PATH" ]]; then
  echo "Script not found: $SCRIPT_PATH" >&2
  exit 1
fi

COMPOSE_ARGS=(compose --profile tools run --rm)

ENV_FILE="projects/${PROJECT}/.env"
if [[ -f "$ENV_FILE" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="$(echo "$line" | xargs)"
    [[ -z "$line" ]] && continue
    if [[ "$line" == *"="* ]]; then
      COMPOSE_ARGS+=(-e "$line")
    fi
  done < "$ENV_FILE"
fi

COMPOSE_ARGS+=(k6 run "/projects/${PROJECT}/scripts/${SCENARIO}.js")
COMPOSE_ARGS+=("$@")

echo "Running: docker ${COMPOSE_ARGS[*]}"
exec docker "${COMPOSE_ARGS[@]}"
