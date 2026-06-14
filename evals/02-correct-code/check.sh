# Checks for 02-correct-code (the no-false-positive guard — the most important scenario).
# Sourced env: EVALS_DIR, WORKDIR, TRANSCRIPT, SCENARIO_DIR, MODEL.
source "$EVALS_DIR/lib.sh"

report="$(report_file)"

# The code is correct, so nothing may be reported Confirmed — not in the report, not in chat.
# (A report file may legitimately not exist at all; if it does, it must contain no Confirmed finding.)
refute_grep "no Confirmed finding in the report"      'status:[[:space:]]*confirmed' "${report:-/dev/null}"
refute_grep "no Confirmed finding announced in chat"  'status:[[:space:]]*confirmed' "$TRANSCRIPT"

# Common fabricated false positive for this fixture: claiming the n>0 guard should be n>=0.
refute_grep "did NOT invent the n>=0 false positive"  'should be[^.]*>=[[:space:]]*0|>=[[:space:]]*0[^.]*instead' "$TRANSCRIPT"

assert_source_unchanged "did NOT rewrite powers.py"

eval_finish
