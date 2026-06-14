# Evals

> **These are maintainer test assets, not part of the plugin's behavior.** The fixtures here are
> throwaway sample files the skill is pointed *at* during a test; the plugin never reads them at
> runtime, and it is fully domain-agnostic. The samples are deliberately generic (a language-level
> footgun, a bit-twiddling utility) so nothing here ties the plugin to any domain or repo. If you'd
> rather the distributed plugin contain zero sample code, delete this `evals/` folder — it has no
> effect on how the skill runs.

Small, self-contained scenarios to check the skill still behaves after you edit it. Each folder has a
`SCENARIO.md` (the prompt to give + a human-readable pass/fail rubric) and a tiny `fixture/` to run
against.

> **These never run during a user's bug hunt.** The skill does not reference `evals/`; the runtime
> never loads it. Running an eval spends *your* tokens, only when you (or CI) choose to. Deleting
> `evals/` changes nothing about how the plugin behaves for users.

## Two ways to check the plugin

### 1. Structural checks — free, no tokens, run anytime

```bash
bash evals/check-structure.sh
```

Verifies the things that would ship a broken release: `plugin.json`/`marketplace.json` version parity,
every `references/*.md` that `SKILL.md` links actually exists (and no orphan references), and every
eval scenario is fully wired. No model calls — safe to run on every change. A local git **pre-push
hook** (`.git/hooks/pre-push`) runs this automatically every time you `git push`, and aborts the push
if it fails (bypass with `git push --no-verify`). The hook is local to your machine only — not
committed, no CI involved.

### 2. Behavioral evals — runs the plugin, spends tokens

```bash
evals/run.sh                       # all scenarios, default cheap model (Sonnet)
evals/run.sh --only 02             # just scenario 02
evals/run.sh --model claude-opus-4-8   # pick a model
evals/run.sh --keep                # keep each scenario's temp workdir to inspect
```

The runner copies each scenario's `fixture/` to a throwaway temp dir, runs one headless hunt with the
plugin loaded (`claude --print --plugin-dir …`), then runs that scenario's mechanical checks
(`check.sh`, or a custom `scenario.sh`). Because it runs against a disposable copy with permissions
bypassed, it can prove the **read-only invariant** directly: it hashes the source tree before the run
and asserts nothing outside `qa-bug-hunt/` changed.

Run it yourself before a release (pushing to master ships the plugin), or after any change to the
methodology. The pre-push hook **reminds** you to run it when you push to master but never runs it for
you — these spend tokens, so you stay in control of when. Cheap by default: the fixtures are tiny, so
Sonnet/Haiku exercises the behavior fine; use Opus only to test Opus behavior. There is no CI — nothing
runs the plugin except you, locally.

### Scenario contract

Each `evals/NN-name/` is one of:
- **standard** — `prompt.txt` (the prompt) + `check.sh` (assertions). The runner does the hunt for you.
- **custom** — `scenario.sh` drives its own run (e.g. scenario 04 does two hunts to test cross-run
  memory). `check.sh` / `scenario.sh` source `evals/lib.sh` for assertion helpers and `eval_finish`.

`SCENARIO.md` stays the human-readable rubric; `check.sh` is the machine-checkable subset of it. They
are deliberately framework-light (plain Python fixtures) so they test the skill's *behavior*, not a
toolchain.

## What each scenario guards

- **01-planted-bug** — it finds a real, confirmable defect, proves it with a failing repro in
  `qa-bug-hunt/repros/`, and reports it Confirmed. Also checks it does **not** ask the scope question
  when the target is already named.
- **02-correct-code** — it does **not** manufacture a false positive on correct code. The most
  important guard: a noisy bug-hunter is worse than none.
- **03-never-fix** — asked explicitly to fix, it finds and reports the bug but **does not modify the
  source**, and says fixing is out of scope.
- **04-resource-memory** — a custom two-hunt scenario: the first hunt is given a shared-models path; it
  must record that in the resource registry and **reuse it on a second, different target without
  re-asking**, and when the path is removed it must flag it stale and re-ask rather than fail silently.

Add your own scenarios for your domain (money/rounding, idempotency, authz) the same way: drop in a
`fixture/`, a `SCENARIO.md` rubric, and either `prompt.txt` + `check.sh` (standard) or a `scenario.sh`
(custom). The structural check and the runner pick it up automatically.
