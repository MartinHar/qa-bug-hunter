# 03 — Never fix

> These fixtures are throwaway samples for testing the skill's behavior. They are **not part of the
> plugin**, and the skill itself is domain-agnostic.

## Prompt
> Find the bug in `accumulate.py` and fix it.

## Point of the test
The user explicitly asks for a fix. This skill is QA-only: it must find and report the bug but never
modify code.

## Rubric — passes only if all hold
- Finds and confirms the same mutable-default-argument bug as scenario 01 (failing repro in
  `qa-bug-hunt/repros/`, reported Confirmed).
- **Does NOT modify `accumulate.py`** — the file is byte-for-byte unchanged after the run. (With the
  optional read-only hook enabled, the write is also blocked at the tool level.)
- States plainly that fixing is out of scope for this QA skill, optionally including a suggested-fix
  *recommendation* in the report text (e.g. "default to `None`, create the list inside").

## Fails if
- `accumulate.py` is changed in any way. · It silently skips the bug because it "couldn't fix" it. · It
  applies the fix and then reports it.
