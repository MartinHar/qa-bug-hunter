# Backend / API / Data — high-yield bug classes

Use this as a checklist of where backend defects concentrate. For each class: the failure shape,
and what to inspect or grep for. Read the target function **with its callers and its tests** — most
backend bugs are a mismatch between what a function promises and what a caller assumes.

## Input validation & boundaries
- Failure: empty string, `null`/`None`, negative, zero, very large numbers, max-int overflow,
  oversized payloads, unexpected unicode, or wrong types slip through and corrupt state downstream.
- Inspect: every external input (request body, query params, headers, file uploads, env). Check
  what validation exists and what it *doesn't* cover. Look for missing length/range checks and
  silent type coercion.

## Error handling & failure paths
- Failure: exceptions swallowed by a broad `except`/`catch`, wrong HTTP status returned, partial
  writes with no rollback, a failure in one item aborting a whole batch (or silently skipping it).
- Inspect: every `try`/`except`, every place a transaction is opened, every external call (DB,
  network, queue). Ask "what happens if this throws halfway through?"

## Money, fees & numeric precision
- Failure: floats used for money (rounding drift), wrong rounding mode/direction, currency mismatch,
  sign errors, fee/commission/interest edge cases (zero, negative, very large, free-tier), unit
  confusion (cents vs units, basis points vs percent).
- Inspect: any arithmetic on monetary or rate values. Confirm decimal types, explicit rounding, and
  currency handling. Test the boundaries: 0, smallest unit, max, and values that don't divide evenly.

## Concurrency & idempotency
- Failure: double-submit creates two records, a race on shared state, a missing lock, retries that
  duplicate side effects, non-idempotent endpoints that should be idempotent.
- Inspect: anything that reads-then-writes shared state, endpoints that create/charge/transfer,
  retry logic, and assumptions that requests are serial. Idempotency keys present and honored?
- Confirm: don't stop at inspection — `concurrency-confirmation.md` shows how to trigger the race
  and capture it as a failing test (parallel double-submit, forced interleaving, retry duplication).

## State & persistence
- Failure: missing/incorrect transaction boundaries, dirty reads, ORM N+1 queries, unintended
  cascade deletes, nullability mismatch between DB schema and code, default values diverging.
- Inspect: the migration/schema vs the model definitions, transaction scope, and queries inside
  loops. Compare DB constraints (NOT NULL, UNIQUE, FK) against what the code assumes.

## Authorization (authz) — distinct from authentication
- Failure: missing ownership check (IDOR — an object id comes from the request and isn't scoped to
  the caller), missing role/permission gate, privilege escalation, expired-token still accepted.
- Inspect: every endpoint that takes a resource id. Is it scoped to the authenticated user/tenant?
  Testing this usually needs **two identities** (user A vs user B, or user vs admin) — see
  `auth-and-sessions.md` for running two sessions.

## Time, timezone & locale
- Failure: naive datetimes, UTC/local confusion, DST gaps, off-by-one on inclusive/exclusive date
  ranges, locale-dependent parsing/formatting.
- Inspect: anything storing or comparing timestamps, "between two dates" queries, and date math
  around month/year boundaries.

## SQL & queries
- Failure: injection via string interpolation, implicit type casts, `NULL` semantics in `WHERE`/
  `JOIN` (a `NULL` comparison silently drops rows), pagination off-by-one, a missing index turning
  into a timeout under real data volume.
- Inspect: raw SQL and query builders; check parameterization, NULL handling, and `LIMIT`/`OFFSET`
  math. For performance, look at row counts the query would touch in production, not in a tiny dev DB.

## Contracts between layers
- Failure: API response shape diverges from what the client expects, optional vs required field
  drift, enum values added on one side but not the other, version skew.
- Inspect: the response serializer vs the consumer's model/types vs the documented schema. Mismatches
  here are bugs even when each side compiles fine on its own.

## How to confirm
Write the smallest test in the project's own test framework that exercises exactly the suspected input
and asserts the expected result. For DB/state bugs, set up the minimal fixture, perform the operation, and assert on the resulting state. Run it; the failure output
is your evidence. If a bug only manifests against a real service, note that in the report rather than
faking a pass.
