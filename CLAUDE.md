# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

This repo **is a Claude Code plugin** (`qa-bug-hunter`), not an application. The "product" is the
skill and its supporting files that get loaded into Claude Code. There is no build step and no app to
run — editing the plugin means editing markdown skill instructions, an optional Python hook, and JSON
manifests. Understand the plugin's runtime behavior before changing it; that behavior is defined almost
entirely in prose, so wording is load-bearing.

## Commands

- **Validate the manifest after editing JSON or structure:** `claude plugin validate ./` (or
  `claude plugin validate ./qa-bug-hunter` from a parent dir).
- **Try the plugin in one session:** `claude --plugin-dir /path/to/qa-bug-hunter`.
- **Apply changes mid-session:** edits to `skills/qa-bug-hunter/SKILL.md` take effect immediately;
  changes to other components (hooks, references, manifests) need `/reload-plugins`.
- **Structural checks (free, no tokens):** `bash evals/check-structure.sh` — version parity, reference
  links resolve, eval scenarios wired. A local `.git/hooks/pre-push` hook runs this on every `git push`
  and aborts on failure (bypass with `git push --no-verify`). Local only — there is no CI.
- **Behavioral evals (spends tokens):** `evals/run.sh` (add `--only NN`, `--model …`, `--keep`). Runs
  each scenario as a headless hunt against a throwaway fixture copy and asserts its `check.sh` /
  `scenario.sh`, including a hash-based read-only check. Cheap model (Sonnet) by default. You run these
  yourself before a release; the pre-push hook reminds you but never runs them. Never runs in a user hunt.
- **Run a single eval by hand:** `cd evals/<scenario>/fixture`, start Claude Code with the plugin
  active, paste the prompt from `SCENARIO.md`, and check against its rubric. Fixtures are plain Python.

The repo is published on GitHub (`origin`, default branch `master`) at
https://github.com/MartinHar/qa-bug-hunter and is itself a Claude Code marketplace, so **pushing to
`master` ships the release** (see INSTALL.md → "Release a new version"). The plugin's own runtime
knowledge vault and bug-hunt artifacts are written elsewhere (see below), never committed here.

## Architecture

The plugin has four parts, layered by how the runtime loads them:

1. **Manifests** (`.claude-plugin/`) — `plugin.json` is the plugin manifest; `marketplace.json`
   defines a local single-plugin marketplace pointing at `./`. Keep `name`, `version`, `description`,
   and `keywords` in sync across both when editing metadata.

2. **The skill** (`skills/qa-bug-hunter/SKILL.md`) — the brain. It's a behavioral contract, not code:
   a read-only QA methodology (establish intended behavior → risk-rank → hypothesize → confirm with a
   unit test → escalate to a browser only when a unit test can't see the bug → report). Two invariants
   run through everything and must be preserved in any edit:
   - **Activation is narrow.** The skill applies *only* on explicit bug-hunting requests and is inert
     for build/implement/refactor/fix work. The `description` frontmatter is what gates this — it is
     the trigger surface, so treat changes to it as behavior changes.
   - **Read-only on the user's code.** While hunting it never modifies application code (even if
     asked); the only files it writes are repro tests and artifacts under `qa-bug-hunt/` at the
     *target* project's root. That folder self-ignores via its own `qa-bug-hunt/.gitignore` containing
     `*`.

3. **References** (`skills/qa-bug-hunter/references/*.md`) — loaded on demand from SKILL.md, not all
   at once; this is the token strategy. SKILL.md stays short and points to a reference for each phase
   (`scope-and-tokens`, `whole-codebase-hunt`, `cross-service`, `knowledge-base`,
   `backend-`/`frontend-bug-patterns`, `repro-execution`, `auth-and-sessions`, `ui-verification`,
   `bug-report-format`, `intake-and-confirmation`). When adding depth, put it in a reference and link
   it from SKILL.md rather than growing SKILL.md.

4. **Optional hook** (`hooks/`) — `guard-readonly.py` hard-blocks Write/Edit/MultiEdit/NotebookEdit
   outside `qa-bug-hunt/`. It is **disabled by default**: the registration file is
   `hooks/hooks.json.disabled` and is only active when renamed to `hooks.json`. It is deliberately off
   because a Claude Code hook is session-global — enabling it would block *all* writes for the whole
   session, including normal development. Do not enable it by default or wire it into the manifest.

### Cross-cutting runtime concepts (described in the skill, not implemented as code here)

- **Knowledge vault / service cards** — at runtime the skill caches per-target "hunt profiles" and
  per-service "cards" as markdown under `$QA_KNOWLEDGE_DIR` (default `~/.qa-bug-hunter/knowledge/`,
  also usable as an Obsidian vault). `templates/service-card.md` is the card template. This lets a
  repeat hunt start "warm." None of this lives in this repo at rest.
- **Browser verification** is an *optional* Playwright MCP, off by default, enabled on demand
  (`claude mcp add playwright -- npx @playwright/mcp@latest --caps=storage`) only when a UI bug can't
  be confirmed at the unit level. `scripts/save-auth-state.mjs` captures a session for repeatable runs.

## Editing guidance specific to this plugin

- The skill's correctness is behavioral and lives in prose. When changing the workflow, preserve the
  two invariants above (narrow activation, read-only) and the Confirmed-vs-Suspected honesty rule —
  false positives are treated as worse than misses throughout.
- `evals/` are maintainer test assets (planted-bug / correct-code / never-fix), not part of plugin
  behavior — the plugin never reads them at runtime and stays domain-agnostic. After any behavioral
  edit to the skill, re-run the relevant scenario against its rubric.
