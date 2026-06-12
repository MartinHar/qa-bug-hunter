# 04 — resource memory (registry reuse)

Guards the headline fix: once the user gives a path to a shared resource, the hunter records it and
reuses it on a later hunt of a *different* target instead of re-searching or re-asking.

## Setup

Use a throwaway `$QA_KNOWLEDGE_DIR` so the test doesn't touch your real vault:

    export QA_KNOWLEDGE_DIR="$(mktemp -d)/knowledge"

## Prompt 1 (first hunt, supply the path)

> Find bugs in `fixture/service_a`. The shared data models are at `fixture/datamodels`.

## Prompt 2 (second hunt, different target, do NOT mention the path)

> Now find bugs in `fixture/service_b`.

## Pass rubric (every "must" holds)

- After Prompt 1, `"$QA_KNOWLEDGE_DIR/resources.md"` exists and contains a row pointing at
  `fixture/datamodels` (kind `data-models`).
- On Prompt 2 the hunter uses the recorded datamodels path **without asking again** and **without
  filesystem-searching** for it (it consults the registry).
- If the datamodels path is made to not exist before Prompt 2, the hunter **says the path is stale and
  re-asks** rather than failing silently or re-searching blindly.
- It never modifies any source file (read-only invariant holds).
