#!/usr/bin/env bash
# evals/run.sh — run the qa-bug-hunter behavioral evals. MAINTAINER / CI ONLY.
#
# This is NOT part of the plugin and NEVER runs during a user's bug hunt. The skill does not
# reference the evals/ folder; deleting evals/ changes nothing about how the plugin behaves. You
# run this yourself (or CI runs it on release) to check that an edit to the skill's prose didn't
# break its behavior. Running it spends tokens — only you pay, only when you choose to.
#
# Usage:
#   evals/run.sh                 # run all scenarios on the default (cheap) model
#   evals/run.sh --only 02       # run just the scenario whose folder starts with "02"
#   evals/run.sh --model claude-opus-4-8   # run on a specific model
#   evals/run.sh --keep          # keep each scenario's temp workdir for inspection
#   EVAL_MODEL=claude-haiku-4-5 evals/run.sh   # set the model via env
#
# Each scenario lives in evals/NN-name/ and is either:
#   - standard: prompt.txt + check.sh   (run one hunt, then assert), or
#   - custom:   scenario.sh             (drives its own run, e.g. multi-prompt).
set -uo pipefail

export EVALS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PLUGIN_DIR="$(cd "$EVALS_DIR/.." && pwd)"
source "$EVALS_DIR/lib.sh"

export MODEL="${EVAL_MODEL:-claude-sonnet-4-6}"   # cheap by default; fixtures are simple
KEEP="${EVAL_KEEP:-0}"
ONLY=""

while [ $# -gt 0 ]; do
  case "$1" in
    --model) MODEL="$2"; shift 2;;
    --only)  ONLY="$2";  shift 2;;
    --keep)  KEEP=1;     shift;;
    -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    *) echo "unknown arg: $1 (try --help)"; exit 2;;
  esac
done
export MODEL

if ! command -v claude >/dev/null 2>&1; then
  echo "✗ 'claude' CLI not found on PATH — install it to run behavioral evals."
  exit 2
fi

echo "Running qa-bug-hunter evals  (model: $MODEL)"
echo

total=0; failed=0
for dir in "$EVALS_DIR"/[0-9]*/; do
  name="$(basename "$dir")"
  [ -n "$ONLY" ] && [[ "$name" != "$ONLY"* ]] && continue
  total=$((total + 1))
  echo "▶ $name"

  if [ -f "$dir/scenario.sh" ]; then
    export SCENARIO_DIR="$dir"
    if bash "$dir/scenario.sh"; then echo "  → PASS"; else echo "  → FAIL"; failed=$((failed + 1)); fi
  else
    work="$(mktemp -d)"
    cp -R "$dir/fixture/." "$work/" 2>/dev/null
    snapshot_source "$work"
    export WORKDIR="$work" TRANSCRIPT="$work/.eval-transcript.txt" SCENARIO_DIR="$dir"
    run_hunt "$work" "$(cat "$dir/prompt.txt")" "$TRANSCRIPT"
    if bash "$dir/check.sh"; then echo "  → PASS"; else echo "  → FAIL"; failed=$((failed + 1)); fi
    if [ "$KEEP" = 1 ]; then echo "  (workdir kept: $work)"; else rm -rf "$work"; fi
  fi
  echo
done

echo "================  $((total - failed))/$total scenarios passed  ================"
[ "$failed" -eq 0 ]
