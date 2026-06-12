# Scope & token efficiency

The single biggest control on both cost and quality is **how much code you scan**. Scope tight, read
narrowly, and let the project's own tools do the cheap first pass. Quality comes from attention on what
matters — not from reading everything.

## Resolving the scope (the first question)

If the target is a **repo URL** rather than a local path, clone it first (see `remote-targets.md`),
then resolve scope against the local checkout exactly as below.

Ask the user, up front (unless the request already pins it down), what to scan, then resolve it with
git:

- **A specific commit** — `git show <sha>` for the change and message; `git diff <sha>^ <sha>` for just
  its hunks; `git diff-tree --no-commit-id --name-only -r <sha>` for the files it touched.
- **A branch** — `git diff <base>...<branch>` (what the branch introduced vs. its merge base, e.g.
  `main...feature`); `git diff --name-only <base>...<branch>` for the file list.
- **Recent changes** — uncommitted work: `git status -s`, `git diff` (unstaged) and `git diff --staged`
  (staged); or the last N commits: `git diff HEAD~<N>` and `git log --oneline -<N>`.
- **The whole codebase** — the slowest, most token-heavy option, and the one most prone to quality loss
  from attention decay. Confirm the user wants it, then run the structured pipeline in
  `whole-codebase-hunt.md` (map → risk-rank → parallel deep scan → seam pass → consolidate); never read
  it end to end in one context.

The first three scopes use **local** git only (never the remote — no GitHub/Azure/GitLab access needed).
If the target isn't a git checkout, or git history isn't available (a shallow clone, an exported
snapshot, no git binary), those scopes can't be resolved — don't force them. Say so and fall back to
scoping by **path** (a file, directory, or module the user names) or to the whole-codebase pipeline.
Scope is an optimization, not a precondition; a hunt never depends on git being present.

Hunt the **changed hunks plus their immediate blast radius** — the callers and callees of changed
functions, and the modules that touch them. That's where regressions surface, and it's a tiny fraction
of the tree.

## Keeping token use low (ordered by leverage)

1. **Scope to the changeset, not the tree.** A commit / branch / recent-changes diff is a fraction of
   the codebase. This is the dominant lever — everything else is secondary. Whole-codebase is the costly
   fallback, used only when asked.
2. **Locate, then read.** Use `grep`/`rg` to find the suspect spots, then read only those line ranges.
   Read a whole file only when the bug genuinely needs the full picture. Never read directories
   wholesale. Before searching for an external dependency you've already located on a past hunt (shared
   data models, a sibling repo), check the resource registry rather than re-discovering it — see
   `resource-memory.md`.
3. **Let cheap, deterministic tools do the first pass.** Run the project's type-checker, linter, and
   existing test suite before reading code — and use LSP diagnostics if the companion LSP plugins are
   installed. A type error, lint warning, or red test is high-signal and costs a fraction of the tokens
   of reading source. Triage that output first, then spend reading budget on the logic and edge cases
   the tools can't see.
   When the suite is **already red before you've touched anything**, triage each failure before
   treating it as a lead: re-run it twice and check for order/time/network dependence, then classify
   it — **flaky** (intermittent: note it, don't chase), **known-failing** (pre-dates the scope:
   note as environment context), or **in-scope regression** (deterministic and inside the
   changeset: this one becomes a hunt lead). Only the last category enters the hunt.
4. **Fan out with subagents for large scopes.** For a whole-codebase or multi-module hunt, dispatch one
   subagent per area, each returning a short findings summary — not file contents — so the main context
   stays lean and each investigation stays focused. Be honest about the trade-off: subagents don't lower
   *total* tokens (each has its own context), but they keep the main context from bloating with files,
   which is what otherwise degrades quality on long runs. Net: more effective per token, not fewer
   tokens overall.
5. **Budget by the chosen depth.** A "quick pass" reads only the highest-risk spots and stops at the
   agreed coverage; a "thorough audit" goes wider. Don't read past the point of diminishing returns.
6. **Don't re-read.** Jot interim notes to `qa-bug-hunt/` and refer back to them instead of re-opening
   files.
7. **Keep the browser out of non-UI hunts.** UI verification prefers the Playwright CLI (just a shell
   command, no tool overhead); the Playwright MCP loads no tools into context until a UI bug actually
   needs it, at which point the plugin pulls it in itself — you don't enable it. So a backend or
   whole-codebase hunt runs with zero browser cost (see `ui-verification.md`).
8. **Report by reference.** Cite file paths and minimal snippets, not pasted files.

## Repeat hunts start warm

A repeat hunt on the same target shouldn't re-pay the discovery cost. Reuse the cached **toolchain**
(test/run/lint commands), **map**, and **risk hotspots** from the knowledge base instead of
re-deriving them, and re-run prior **repros as a regression checklist** rather than re-discovering
known issues — a known-open bug is noted, not re-investigated from scratch. On a single scope this just
means a warmer phase 0; for the whole codebase it becomes a full incremental re-scan of only what
changed. This is one of the larger levers on repeat runs. See `knowledge-base.md` (and
`whole-codebase-hunt.md` for the incremental whole-repo version).

## Why quality doesn't drop

Tight scope means more attention per line that actually matters. Offloading the mechanical defects to
the type-checker, linter, and existing tests frees the reading budget for the logic and edge-case bugs
that need a careful read. And confirmation is unchanged — every Confirmed finding still has a failing
repro behind it. The savings come from not reading irrelevant code and not re-deriving what the
project's own tools already know — never from looking less carefully at what counts.
