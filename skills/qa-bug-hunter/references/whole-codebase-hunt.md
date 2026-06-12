# Whole-codebase hunt (high-quality mode)

Whole-codebase is the most error-prone scope, and the reason isn't tokens — it's **attention decay**:
one context can't hold an entire repo without the model starting to skim, so quality drops the longer
the run goes. So **never read the repo end to end in a single context.** When the scope is the whole
codebase, follow this pipeline regardless of repo size. Each slice gets full attention, coverage is
tracked, and cross-cutting bugs get a dedicated pass.

## Warm start — a repeat whole-codebase hunt is incremental, not cold

Before mapping from scratch, check the knowledge base (`knowledge-base.md`). If this repo has a card
with a cached **map, dependency graph, and partition risk-ranking**, reuse them and run *incrementally*
instead of re-scanning everything:

- Resolve what changed since the card's commit with a **local** `git diff <cached-commit> HEAD`
  (local only — no remote access). Fall back to the card's file fingerprints, or to a full pass, if
  git can't answer (see `knowledge-base.md` for the rungs).
- **Deep-scan only the changed partitions** (step 4) and any partition whose risk inputs moved.
- **Re-run the seam pass (step 5) only for contracts the changed files touch** — walk the cached
  dependency graph outward from the changed nodes.
- **Regression-check prior findings**: re-run each cached repro (Confirmed → still open or fixed?
  Suspected → re-examine). No git needed for this.
- Refresh the map/graph/ranking for the changed areas only, and re-stamp the card at the end (step 8).

A first-ever hunt on the repo is the cold path: run every step below in full. Cached knowledge is a
warm start, never a verdict — every reported finding is still freshly reproduced.

## Pipeline

1. **Map the codebase (cheaply, with tools).** Build an inventory before reading deeply: top-level
   structure, modules/packages, entry points, the layers (API · service · data · UI), external
   integrations, and where tests live. Lean on tools rather than reading by hand — `tree -L 2 -d`,
   `cloc`/`tokei` for size, LSP workspace symbols, and an **import/call graph** from a language tool
   (`dependency-cruiser`/`madge` for JS/TS, `go mod graph`, `pydeps`/`importlab` for Python, LSP call
   hierarchy; fall back to grepping import statements). Save the inventory as `qa-bug-hunt/map.md` and
   the edges as `qa-bug-hunt/graph.md` (or a dot/json). The map is the spine; the graph powers the seam
   pass (step 5) and incremental re-hunts.

2. **Gather cheap signals across the whole repo, once.** Run the project's type-checker, linter, and
   full test suite and collect every failure/warning; run any configured static/security analyzer and
   read any coverage report. Pull risk signals from git: churn hotspots
   (`git log --format= --name-only | sort | uniq -c | sort -rn | head -30`), files with many recent
   bug-fix commits, and markers (`rg -n "TODO|FIXME|HACK|XXX"`). High signal, low cost — this seeds the
   whole hunt and tells you where bugs already cluster. Keep each signal **indexed by file** so step 4
   can hand each subagent only the signals for its slice.

3. **Partition, size, and risk-rank.** Split the repo into coherent partitions (by module/package/
   layer) and rank each by risk from the signals above: complexity, churn, money/auth/concurrency/
   external-IO, low or absent coverage, and tool flags.
   - **Size each partition to fit one context comfortably** — roughly **≤ ~2–3k LOC / ~15–20 files**.
     This is the crux: a partition too large makes the subagent in step 4 decay *inside its own
     context*, which defeats the whole point. **Split** oversized modules along internal seams; **merge**
     tiny sibling files into one partition to avoid overhead.
   - **Apply a risk budget for large repos.** Deep-scan the highest-risk partitions until the budget
     (attention/token) is spent; give the remaining low-risk partitions a **light pass** (tool signals
     only, no deep read) and record that honestly. Don't pretend every line was read.
   - Record everything in `qa-bug-hunt/coverage.md` as a resumable ledger, one row per partition:
     `partition · risk · planned depth (deep | light) · status`, where **status** is one of
     `pending · scanning · done · skipped-low-risk · blocked`. This ledger is the resume point and the
     coverage record.

4. **Deep-scan each partition in its own context (in waves).** Dispatch one subagent per partition.
   **Don't fan out all at once** — run in **waves of a few (e.g. 3–5)**, merging each wave's summaries
   (step 6 collation) before launching the next, and mark `scanning → done` in the ledger as you go.
   If subagents aren't available, process partitions sequentially: scan one, write its summary, drop it
   from working memory, move on — never hold them all at once. This isolation is the biggest quality
   win: full attention per slice, no context bloat.

   **The brief each subagent receives (the same payload every time):**
   - its partition's file list and the `map.md`/`graph.md` slice relevant to it;
   - the **cheap-signal failures scoped to its files** (from step 2) so it starts warm, plus the
     toolchain (test/run commands) so it doesn't re-derive them;
   - the relevant pattern catalog (`backend-bug-patterns.md` / `frontend-bug-patterns.md`), the
     confirm-vs-suspect discipline, and the report format;
   - the resource registry / service cards (`resource-memory.md`, `cross-service.md`) for anything it
     depends on across a boundary;
   - an instruction to **confirm in place** (below) and to **note every assumption it makes about other
     partitions** (for the seam pass).

   **Confirm in the subagent's own context — don't defer everything.** The subagent already has the
   code loaded, so for findings it can prove cheaply it writes the smallest failing repro right there
   into `qa-bug-hunt/repros/` (prefix the filename with the partition, e.g. `auth__test_…`, to avoid
   collisions) and captures the verbatim output. Findings that are expensive or **cross-partition** it
   leaves **Suspected** with the assumption recorded, for the seam pass / consolidation to confirm —
   that avoids re-loading the same code later just to write a repro.

   **The structured summary each subagent returns** (not file contents) — one record per finding,
   appended to `qa-bug-hunt/findings/<partition>.md`:
   `id · location (file:line) · precondition→expected→actual · status (Confirmed|Suspected) ·
   severity · cross-partition assumptions · repro path (if Confirmed) · root-cause note`.

5. **Cross-cutting / seam pass — walk the graph, don't guess.** The bugs partitions miss live at the
   boundaries. Drive this pass from the **dependency/call graph** (step 1), not just from self-reported
   assumptions: for each edge between partitions, check the contract on both sides — request/response
   shapes, shared types and enums, events, error/null contracts — plus shared state and invariants
   assumed in one place but enforced in another, data that flows across layers, and auth/permission
   checks that span components. Confirm the cross-partition Suspecteds parked in step 4 here. On a warm
   re-hunt, walk only the edges touched by changed files.

6. **Consolidate, dedupe, cluster, confirm the rest.** Merge all per-partition summaries. Collapse
   duplicates (two partitions often report the same seam bug from each side) and **cluster by root
   cause** — one cause surfaces as many symptoms, so report the cause once with its symptoms listed,
   not fifty items. Most repros already exist from step 4; here you confirm the remaining high-value
   Suspecteds, re-run prior repros on a warm hunt, and drop low-value noise. This triage keeps a large
   hunt's report trustworthy instead of overwhelming.

7. **Report with coverage.** Write the report (`bug-report-format.md`) into `qa-bug-hunt/`, led by
   Confirmed Critical/High and root-cause-clustered. Append the coverage record (`coverage.md`): which
   partitions were deep- vs light-scanned, what was skipped under the risk budget, and the blind spots
   — so the team knows the hunt's reach.

8. **Update the knowledge base.** Cache the **map, dependency graph, and partition risk-ranking** on the
   repo's card, append this run's findings to the known-issues ledger (with repro paths and status), and
   re-stamp `refreshed:` at the current commit (see `knowledge-base.md`). This is what makes the next
   whole-codebase hunt incremental rather than cold. (Suppressed if the optional read-only hook is on.)

## Optional booster for the few highest-risk partitions

For the handful ranked highest-risk (money/auth/concurrency cores), run a **second, independent reviewer
subagent** over the same slice with no memory of the first. A fresh pass catches misses — the same
reason two human reviewers beat one. Reserve it for the critical few; it isn't worth it everywhere.

## What raises quality here

- **Isolated, right-sized attention per partition** beats a single diluted pass — and the *sizing* is
  what keeps the isolation real (an oversized partition just relocates the decay).
- **Warm, incremental re-hunts** spend deep attention only on what changed, so repeat runs are both
  cheaper and sharper.
- **A map + graph + coverage ledger** turns a haphazard skim into systematic, resumable coverage with
  known blind spots.
- **Risk-ranked, budgeted depth** concentrates effort where bugs cluster and scales to large repos
  honestly.
- **A concrete subagent contract** (warm brief in, structured findings out, confirm-in-context) makes
  the parallel work consistent and the consolidation mechanical.
- **A graph-driven seam pass** catches the cross-module/contract bugs that per-file reading
  structurally misses.
- **Root-cause clustering + re-confirmation** keeps the report high-signal and trustworthy at scale.

## Resumability & token note

The map, graph, coverage ledger, and per-partition findings all live in `qa-bug-hunt/`, and the ledger
statuses (`pending → scanning → done`) make a paused hunt resumable to the partition. You never re-read
what's already summarized, and a warm re-hunt re-scans only the delta. This is also the token-efficient
shape — cheap signals first, warm subagent briefs, risk-budgeted depth, summaries not file contents —
so quality and efficiency align here rather than trading off. See `scope-and-tokens.md` and
`knowledge-base.md`.
