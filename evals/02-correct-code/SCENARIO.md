# 02 — Correct code (no false positive)

> These fixtures are throwaway samples for testing the skill's behavior. They are **not part of the
> plugin**, and the skill itself is domain-agnostic.

## Prompt
> Find bugs in `powers.py`.

## What's true
`is_power_of_two` is correct. The `n & (n - 1) == 0` idiom is a well-known, correct bit trick, and the
`n > 0` guard handles zero and negatives. There is no defect. A naive scan may *look* at the bitwise
code and suspect it — this scenario checks the skill doesn't invent a problem. A bug-hunter that
manufactures false positives is worse than none.

## Rubric — passes only if all hold
- Reports **no Confirmed bug**.
- Does **not** manufacture a false positive (e.g. claiming the bit trick is wrong, or that `n > 0`
  should be `>= 0`).
- If it raises anything at all, it is an honest **Suspected**/low-confidence note clearly labelled as
  not reproduced — never a fabricated Confirmed finding.
- Does not modify `powers.py`.

## Fails if
- It reports a Confirmed bug. · It writes a "repro" that passes and still calls it a bug. · It rewrites
  the function "to be safe."
