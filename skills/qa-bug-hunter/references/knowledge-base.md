# Knowledge base (warm starts across runs)

A cold hunt burns tokens rediscovering the same things every time — the toolchain, the structure, the
risk hotspots. The knowledge base fixes that: after each run the tool records what it learned about a
target, and the next run starts **warm** instead of cold. It lives in the same vault as the
cross-service cards (`$QA_KNOWLEDGE_DIR`, default `~/.qa-bug-hunter/knowledge/`), one card per codebase
— the card holds both the cross-service contract facts (`cross-service.md`) and a **hunt profile** the
tool maintains (see `templates/service-card.md`).

> The per-codebase card is **not** the place for shared, cross-target resource paths (your data
> models, a dependency repo). Those go in the user-level **resource registry**
> (`references/resource-memory.md`), which any target's hunt consults first. Cards may reference a
> registry resource by name.

## What gets cached (and what doesn't)

Cache the slow-changing, expensive-to-derive facts:
- **Toolchain** — test framework + how to run it, build/run, lint/type-check commands.
- **Map** — structure, entry points, where code and tests live; for whole-codebase, the partition map,
  the dependency/call graph, and the partition risk-ranking (so a repeat hunt re-scans only the delta —
  see `whole-codebase-hunt.md`).
- **Risk hotspots** — areas worth hunting first (churn, complexity, money/auth/concurrency, untested).
- **Known issues** — prior findings (Confirmed and Suspected) with severity, location, a
  **fingerprint** — `file path · symbol (function/component) · root-cause one-liner`, no line
  numbers so it survives drift — the path to their repro in `qa-bug-hunt/repros/`, and current
  status (`open` / `fixed` / `regressed` / `suspected`).
- **Stamp & fingerprints** — a `refreshed:` date; the commit if the target is a git checkout (`n/a`
  otherwise); and a couple of cheap, **git-independent** fingerprints: a hash of the dependency
  manifest/lockfile (package.json + lock, poetry.lock, go.mod, *.csproj, etc.) and the size/mtime (or a
  quick hash) of the hotspot files. These let the next run tell what changed with no git and no network.

Don't cache secrets, data, or anything sensitive — facts and pointers only. Keep cards concise (facts,
not transcripts): the cache must *save* tokens, not become a context hog. Load the vault index plus the
one relevant card — never the whole knowledge base.

## Warm start — verify, then trust

At the start of a hunt (phase 0), look the target up **by a stable id** — its name / path / remote URL,
*not* by commit — so the card is always found regardless of version. **No card → cold start: hunt
normally and write one at the end.** If a card exists, decide how much to trust it using whatever
freshness signal is available, in this order. **Every step is best-effort: if a command fails — no git,
shallow clone, locked-down environment — drop to the next rung. Never error out, never block the hunt,
and never assume the cache is correct because a git command happened to fail.**

1. **Local git delta (best, when it works).** This is all *local* git — it never contacts GitHub, Azure
   DevOps, or GitLab, so no remote access is needed. If `git rev-parse HEAD` works and the cached commit
   is reachable:
   - same commit → full reuse of toolchain, map, and hotspots (one cheap check: the test command still
     runs).
   - different commit and `git diff <cached-commit> HEAD` resolves → reuse the stable facts, re-risk-rank
     only the changed files.
2. **Git present but the cached commit isn't reachable** (shallow `--depth 1` clone, force-push, or a
   gc'd commit — common in CI). The diff to the old commit won't resolve; don't fight it. Use what's
   local — `git status` / `git diff` for uncommitted changes — and otherwise fall to the fingerprint
   check below.
3. **No usable git history** (not a checkout, or no git binary). Use the **fingerprints** stored in the
   card: recompute the manifest/lockfile hash and the hotspot files' size/mtime.
   - unchanged → trust the cached toolchain and map for those areas.
   - changed → refresh only those areas.
   No git, no network.
4. **No signal usable at all.** Treat the card as a **hint only**: reuse the toolchain (re-verify by
   running the test command once) and the structural map (check a couple of cached paths still exist),
   but re-derive the risk-ranking fresh.

Whichever rung you land on, the **known-issues ledger is self-verifying** — re-running a prior repro
tells you directly whether the bug is fixed (it passes) or still open / regressed (it fails), with no
git or network at all. And in every case cached knowledge is a **warm start, never a verdict**: findings
are always freshly reproduced.

**Stale paths never fail silently.** If any cached path (a card's map entry or a registry resource) no
longer resolves on disk, tell the user and re-ask for the new location rather than re-searching blindly
or aborting — then update the stored path. See `references/resource-memory.md`.

## Known issues drive regression re-checks

On a repeat hunt the card's known-issues list is a checklist, not just a memory:
- For each prior **Confirmed** bug, re-run its cached repro — still failing (open / regressed) or now
  passing (fixed)? Update the status, and don't re-report an already-known open bug as a new find; note
  it's still open.
- Re-examine prior **Suspected** items with whatever new access you have (e.g. a service path you now
  have that you didn't before).
- **Dedup by fingerprint.** Before adding any new finding to the report, compare it against the
  ledger's fingerprints. A match is a **status update on the existing entry** (still open, fixed,
  regressed), never a second copy of the same finding.
- **Regressed beats open.** A repro that previously passed (the bug was fixed) and now fails again
  is **`regressed`** — a broken fix. Flag it explicitly and order it above same-severity open bugs
  in the report.

This turns the knowledge base into accumulating QA value — institutional memory of what's been found and
whether it's been fixed — not just a token saver.

## Update at the end of the run

After reporting, write or refresh the card: toolchain and map (if newly learned or changed), updated
hotspots, this run's findings appended to known issues (with repro paths and status), and a fresh
`refreshed:` stamp at the current commit. Keep it concise.

> If the optional read-only hook (`hooks/`) is enabled it blocks writes outside `qa-bug-hunt/`, so the
> card update is suppressed in that mode — the warm-start *reading* still works. The hook is off by
> default.
