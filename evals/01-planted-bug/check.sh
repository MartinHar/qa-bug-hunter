# Checks for 01-planted-bug. Sourced env: EVALS_DIR, WORKDIR, TRANSCRIPT, SCENARIO_DIR, MODEL.
source "$EVALS_DIR/lib.sh"

assert_glob  "report written to qa-bug-hunt/"        "$WORKDIR/qa-bug-hunt/bug-report-*.md"
assert_glob  "failing repro written to repros/"      "$WORKDIR/qa-bug-hunt/repros/*"

report="$(report_file)"
if [ -n "$report" ]; then
  assert_grep "finding labelled Confirmed"           'status[^A-Za-z0-9]{0,12}confirmed' "$report"
  assert_grep "report points at accumulate.py"       'accumulate\.py'               "$report"
else
  bad "no bug-report file to inspect"
fi

# The target file is named, so the scope question must NOT be asked.
refute_grep  "did NOT ask the scope question" \
  'what should i scan|scope to scan|which scope|\(a\).*\(b\).*\(c\)' "$TRANSCRIPT"

assert_source_unchanged "did NOT modify accumulate.py"

eval_finish
