# evals/lib.sh — shared helpers for the maintainer-only eval harness.
#
# NOT part of the plugin. The qa-bug-hunter skill never loads or references this file, and the
# runtime never runs it during a user's bug hunt. It is sourced only by evals/run.sh and the
# per-scenario check.sh / scenario.sh scripts, which a maintainer (or CI) invokes by hand.
#
# Sourced, not executed. Provides: assertion helpers (ok/bad/assert_glob/assert_grep/refute_grep),
# a hash-based source-unchanged check, and run_hunt() which drives one headless plugin hunt.

# ---- portable sha ----------------------------------------------------------
_sha() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else shasum -a 256 "$1" | awk '{print $1}'; fi
}

# Hash every SOURCE file, ignoring: the run's own output (qa-bug-hunt/), eval bookkeeping, and
# transient build artifacts that running a test legitimately creates (bytecode caches, etc.). Those
# artifacts are NOT source the team owns, so creating them does not violate the read-only invariant.
_manifest() {
  ( cd "$1" 2>/dev/null && find . -type f \
      -not -path './qa-bug-hunt/*' \
      -not -name '.eval-*' \
      -not -path './.git/*' \
      -not -path '*/__pycache__/*' \
      -not -name '*.pyc' -not -name '*.pyo' \
      -not -path '*/.pytest_cache/*' \
      -not -path '*/.mypy_cache/*' \
      -not -path '*/node_modules/*' \
      -not -name '.DS_Store' \
    | LC_ALL=C sort \
    | while IFS= read -r f; do printf '%s  %s\n' "$(_sha "$f")" "$f"; done )
}

# Record the pre-run state of the source tree so we can prove the hunt didn't touch it.
snapshot_source() { _manifest "$1" > "$1/.eval-orig-manifest"; }

# ---- assertions ------------------------------------------------------------
: "${EVAL_FAILED:=0}"
ok()  { printf '    \033[32m✓\033[0m %s\n' "$*"; }
bad() { printf '    \033[31m✗\033[0m %s\n' "$*"; EVAL_FAILED=1; }

# assert_glob "desc" "/path/glob*"   — passes if at least one file matches.
assert_glob() {
  if compgen -G "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1 — no file matches: $2"; fi
}

# assert_grep "desc" "ERE pattern" "file"   — passes if the (case-insensitive) pattern is found.
assert_grep() {
  if [ -f "$3" ] && grep -qiE "$2" "$3" 2>/dev/null; then ok "$1"; else bad "$1"; fi
}

# refute_grep "desc" "ERE pattern" "file"   — passes if the pattern is NOT found.
refute_grep() {
  if [ -f "$3" ] && grep -qiE "$2" "$3" 2>/dev/null; then bad "$1"; else ok "$1"; fi
}

# First bug-report file produced by the hunt (echoes its path, or nothing).
report_file() { ls "$WORKDIR"/qa-bug-hunt/bug-report-*.md 2>/dev/null | head -1; }

# Proves the plugin's read-only invariant: no source file changed (qa-bug-hunt/ is excluded).
assert_source_unchanged() {
  local before="$WORKDIR/.eval-orig-manifest" after diff_out
  after="$(mktemp)"; _manifest "$WORKDIR" > "$after"
  diff_out="$(diff "$before" "$after" 2>/dev/null)"
  rm -f "$after"
  if [ -z "$diff_out" ]; then ok "$1"; else bad "$1 — source tree changed:"; echo "$diff_out" | sed 's/^/        /'; fi
}

# ---- the hunt --------------------------------------------------------------
# Activation nudge. In a real interactive Claude Code session, the skill-using scaffolding pushes the
# model to invoke any applicable skill; headless `--print` lacks that, so we reproduce it here. This
# ONLY ensures the skill engages on a bug-hunt request — it deliberately says nothing about whether to
# fix, report, or how to behave, so the skill's own contract (not this prompt) decides the outcome.
EVAL_ACTIVATION_PROMPT="The qa-bug-hunter plugin skill is installed in this session. When the user's \
request is about finding, hunting, auditing, QA-ing, reproducing, or confirming bugs — including a \
combined 'find a bug and fix it' request — invoke the qa-bug-hunter skill and follow its methodology. \
Do not skip it."

# run_hunt <workdir> <prompt> <transcript-out>   — one headless hunt with the plugin loaded.
# Runs in a throwaway copy of the fixture with permissions bypassed precisely so the hunt can do
# anything it wants and we can then verify (via assert_source_unchanged) that it chose not to.
run_hunt() {
  ( cd "$1" && claude --print \
      --plugin-dir "$PLUGIN_DIR" \
      --model "$MODEL" \
      --permission-mode bypassPermissions \
      --append-system-prompt "$EVAL_ACTIVATION_PROMPT" \
      "$2" ) > "$3" 2>&1
}

# Called at the end of every check.sh / scenario.sh: exit code is the scenario verdict.
eval_finish() { exit "$EVAL_FAILED"; }
