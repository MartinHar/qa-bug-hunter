# Resource registry (remember where shared things live)

Per-target cards (`knowledge-base.md`) remember one codebase. They do **not** help when a *different*
service needs the same shared resource — your data models, a shared schema package, a dependency repo.
Without this, the hunter re-searches for those every hunt and fails when they live outside the repo.
The resource registry fixes that: a **user-global** list of named local resources and their paths,
reused across every target.

## Where it lives

One file: `$QA_KNOWLEDGE_DIR/resources.md` (default `~/.qa-bug-hunter/knowledge/resources.md`) — the
same vault as the cards, but a single shared file rather than one-per-codebase. To share a registry
across a team, point `$QA_KNOWLEDGE_DIR` at an in-repo or shared path (see "Team sharing" below).

## Format

A markdown table, one row per resource:

| name | kind | path | last-verified | notes |
|------|------|------|---------------|-------|
| datamodels | data-models | /Users/me/repos/datamodels | 2026-06-06 | shared Pydantic models used by all services |
| billing-svc | service | /Users/me/repos/billing | 2026-06-06 | upstream the orders API calls |

- **kind** is one of `data-models | shared-lib | service | other`.
- **path** is an absolute local path.
- **last-verified** is the date the path was last confirmed to exist (`date +%Y-%m-%d`).

## Read first — before searching or asking

Whenever a hunt needs an external resource (the code imports shared models, calls a dependency, etc.),
**consult the registry before grepping the filesystem or asking the user**:

1. Find a row whose `name`/`kind` matches what you need.
2. Confirm the `path` still resolves on disk (`test -e <path>`).
3. If it resolves → use it silently. No search, no question.
4. If it does **not** resolve → this is a stale entry; do not fail silently (see "Stale-path heal").

## Write on receipt — capture every path the user gives you

The moment the user provides a path to an external resource during a hunt — answering a cross-service
ask, or just mentioning "the models are at X" — **append or update a row in the registry immediately**,
with today's date in `last-verified`. That is the whole point: it is asked once, ever. (This happens
only inside a hunt; the skill still activates only on bug-hunt requests.)

## Stale-path heal

When a registry (or card) path no longer resolves, say so plainly and re-ask rather than silently
re-searching or giving up — e.g.:

> My note says `datamodels` is at `/Users/me/repos/datamodels`, but that path no longer exists. Where
> is it now? (or: continue without it)

When the user gives the new path, update the row's `path` and `last-verified`. A stale entry is a
reason to re-ask, never a reason to abort the hunt.

## Suppressed under the read-only hook

Writing the registry is a write outside `qa-bug-hunt/`, so when the optional read-only hook (`hooks/`)
is enabled the registry **write** is suppressed (consistent with card-caching). Read-first still works.
The hook is off by default.

## Team sharing

Because the registry is just a markdown file under `$QA_KNOWLEDGE_DIR`, a team can share one by setting
that env var to a shared/in-repo path. Keep only paths and non-sensitive notes in it — never secrets.
