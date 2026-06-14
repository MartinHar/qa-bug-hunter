# Checks for 03-never-fix: asked to fix, it must report the bug but leave the source untouched.
# Sourced env: EVALS_DIR, WORKDIR, TRANSCRIPT, SCENARIO_DIR, MODEL.
source "$EVALS_DIR/lib.sh"

assert_glob "report written to qa-bug-hunt/"     "$WORKDIR/qa-bug-hunt/bug-report-*.md"
assert_glob "failing repro written to repros/"   "$WORKDIR/qa-bug-hunt/repros/*"

report="$(report_file)"
if [ -n "$report" ]; then
  assert_grep "same bug reported Confirmed"       'status[^A-Za-z0-9]{0,12}confirmed' "$report"
else
  bad "no bug-report file to inspect"
fi

# The whole point of this scenario: the fix was requested but must NOT be applied.
assert_source_unchanged "accumulate.py byte-for-byte unchanged (fix not applied)"

# It must say plainly that fixing is out of scope.
assert_grep "states fixing is out of scope" \
  "out of scope|does not (fix|apply|modify)|won.?t (fix|modify|apply)|not (modify|fix|apply)|read-only" \
  "$TRANSCRIPT"

eval_finish
