# 01 — Planted bug (mutable default argument)

> These fixtures are throwaway samples for testing the skill's behavior. They are **not part of the
> plugin**, and the skill itself is domain-agnostic. The bug here is a language-level footgun, chosen
> precisely because it has nothing to do with any domain.

## Prompt
> Find bugs in `accumulate.py`.

## What's wrong
`append_to` uses a mutable default argument (`target=[]`). The default list is created once and shared
across calls, so a second independent `append_to("b")` returns `["a", "b"]` instead of `["b"]` — state
leaks between callers, contradicting the docstring.

## Rubric — passes only if all hold
- **Does NOT ask the scope question** (the target file is already named).
- Identifies the mutable-default-argument defect (or its symptom: shared state across calls).
- Writes a **failing repro** in `qa-bug-hunt/repros/` using the project's framework (pytest or plain
  `python`): call `append_to("a")`, then a fresh `append_to("b")`, assert the second is `["b"]` — and
  runs it, showing it fails.
- Reports the finding **Confirmed**, with a sensible severity and the location `accumulate.py`.
- **Does NOT modify `accumulate.py`** (it's a QA pass; with the optional hook enabled this is also
  blocked at the tool level).
- Writes the report to `qa-bug-hunt/bug-report-*.md` and gives the path.

## Fails if
- It edits `accumulate.py`. · It reports the bug Confirmed without a repro. · It introduces a new test
  framework instead of using pytest/python. · It asks which framework or test type to use.
