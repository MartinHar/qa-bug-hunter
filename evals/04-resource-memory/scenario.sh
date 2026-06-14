# 04-resource-memory — custom driver: two hunts on two different targets, sharing one resource path.
#
# Guards the registry behavior: after Prompt 1 supplies the datamodels path, the hunter records it in
# the user-level resource registry and reuses it on Prompt 2 (a different target) WITHOUT re-asking or
# filesystem-searching. Then, with the path removed, it must say the path is stale and re-ask.
#
# Sourced env: EVALS_DIR, PLUGIN_DIR, MODEL, SCENARIO_DIR.
source "$EVALS_DIR/lib.sh"

# Throwaway vault so the eval never touches the real ~/.qa-bug-hunter knowledge base.
export QA_KNOWLEDGE_DIR="$(mktemp -d)/knowledge"

export WORKDIR="$(mktemp -d)"
cp -R "$SCENARIO_DIR/fixture/." "$WORKDIR/"
snapshot_source "$WORKDIR"

t1="$WORKDIR/.eval-t1.txt"
t2="$WORKDIR/.eval-t2.txt"
t3="$WORKDIR/.eval-t3.txt"

# Prompt 1 — first hunt, supply the shared-models path.
run_hunt "$WORKDIR" \
  "Find bugs in service_a. The shared data models are at $WORKDIR/datamodels." "$t1"

res="$QA_KNOWLEDGE_DIR/resources.md"
if [ -f "$res" ]; then
  ok "resource registry (resources.md) created"
  assert_grep "registry records the datamodels path" 'datamodels' "$res"
else
  bad "resource registry was not created at \$QA_KNOWLEDGE_DIR/resources.md"
fi

# Prompt 2 — different target, path NOT mentioned. Must reuse the registry, not re-ask.
run_hunt "$WORKDIR" "Now find bugs in service_b." "$t2"
refute_grep "did NOT re-ask for the datamodels path" \
  "where (are|is)[^?]*data ?models|path to[^?]*data ?models|provide[^?]*data ?models|location of[^?]*data ?models" \
  "$t2"

# Read-only check belongs HERE — after the hunts, before our own deliberate deletion below.
assert_source_unchanged "the hunts modified no source file"

# Stale-path heal — WE remove the resource (this is a test action, not the hunt), hunt again, and
# expect an honest 'stale, please re-point' response rather than a silent failure or blind re-search.
rm -rf "$WORKDIR/datamodels"
run_hunt "$WORKDIR" "Find bugs in service_b again." "$t3"
assert_grep "flags the stale path and re-asks (does not fail silently)" \
  "stale|no longer (exists|resolves|there)|can.?t find|missing|moved|where .* now|re-?point|update the path" \
  "$t3"

# This scenario manages its own temp dirs; clean up unless EVAL_KEEP=1.
[ "${EVAL_KEEP:-0}" = 1 ] || rm -rf "$WORKDIR" "$(dirname "$QA_KNOWLEDGE_DIR")"

eval_finish
