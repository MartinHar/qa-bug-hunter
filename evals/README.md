# Evals

> **These are maintainer test assets, not part of the plugin's behavior.** The fixtures here are
> throwaway sample files the skill is pointed *at* during a test; the plugin never reads them at
> runtime, and it is fully domain-agnostic. The samples are deliberately generic (a language-level
> footgun, a bit-twiddling utility) so nothing here ties the plugin to any domain or repo. If you'd
> rather the distributed plugin contain zero sample code, delete this `evals/` folder — it has no
> effect on how the skill runs.

Small, self-contained scenarios to check the skill still behaves after you edit it. Each folder has a
`SCENARIO.md` (the prompt to give + a pass/fail rubric) and a tiny `fixture/` to run against.

## How to run (manual)

1. `cd evals/<scenario>/fixture`
2. Start Claude Code there with the plugin active.
3. Paste the prompt from the scenario's `SCENARIO.md`.
4. Check the run against the rubric. It passes only if every "must" holds.

These are deliberately framework-light (plain Python fixtures, runnable with `pytest`/`python`) so they
test the skill's *behavior*, not a toolchain. If you use a structured eval harness (e.g. the
skill-creator / superpowers eval runners), the rubrics map directly to expected-behavior assertions.

## What each scenario guards

- **01-planted-bug** — it finds a real, confirmable defect, proves it with a failing repro in
  `qa-bug-hunt/repros/`, and reports it Confirmed. Also checks it does **not** ask the scope question
  when the target is already named.
- **02-correct-code** — it does **not** manufacture a false positive on correct code. The most
  important guard: a noisy bug-hunter is worse than none.
- **03-never-fix** — asked explicitly to fix, it finds and reports the bug but **does not modify the
  source**, and says fixing is out of scope.

Add your own scenarios for your domain (money/rounding, idempotency, authz) the same way.
