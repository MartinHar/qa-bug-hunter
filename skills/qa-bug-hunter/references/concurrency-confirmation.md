# Confirming concurrency bugs (turning Suspected races into Confirmed)

A race suspected from reading code is a lead, not a finding. This reference shows how to *trigger*
the race and capture it as a failing test, so concurrency findings can be **Confirmed** like any
other. Everything here lives in repro tests under `qa-bug-hunt/repros/` — application code is never
modified; any patching happens inside the test process only.

Use the techniques in order — cheapest first.

## 1. Parallel double-submit (the hammer)

Fire N identical operations concurrently at the suspected non-idempotent seam and assert the
**exactly-once effect** — one record created, one charge, one email. Assert on the resulting state,
never on timing.

- **Python:** `asyncio.gather(*[op() for _ in range(N)])` (interleaves only at `await` points), or
  `ThreadPoolExecutor` + `executor.map` for sync code.
- **JS/TS:** `await Promise.all(Array.from({length: N}, () => op()))`.
- **Go:** N goroutines released together by a closed-channel start gun, joined with a
  `sync.WaitGroup` before the assert.
- **HTTP-level (any stack):** N parallel `curl` invocations (`for i in ...; do curl ... & done; wait`)
  against a local/staging endpoint, then assert on state via a query. This mutates state — for
  anything shared (staging), confirm with the user first, per SKILL.md.

Choosing N: for a missing idempotency key or absent unique constraint, N=2 usually fails
immediately. For a narrow read-then-write window, raise N (20–50) and loop the whole attempt a few
times before concluding it won't trigger.

## 2. Deterministic interleaving (when the hammer is flaky)

If the window is too small to hit reliably, force the bad ordering from inside the test: patch the
slow side so the interleaving is guaranteed — e.g. monkeypatch the "read" step of one writer to
block on a `threading.Barrier` / `asyncio.Event` until the other writer has committed, then release
it and assert. The race becomes a deterministic, repeatable failure instead of a probabilistic one.
Patching is test-process-only (mock/monkeypatch/test double) — never an edit to application code.

## 3. Retry duplication

Many "races" are really retry bugs. Simulate failure-then-retry: patch the operation to throw
*after* its side effect has been applied (e.g. after the DB write, before the response), then
re-invoke it the way the client or framework's retry policy would. Assert the side effect happened
exactly once. This confirms missing idempotency keys and non-transactional write-then-notify
sequences without any true parallelism.

## Reporting rules for concurrency findings

- **Consistency requirement.** Run the repro three times. Fails every time → **Confirmed**. Fails
  intermittently → still **Confirmed** (the wrong state was observed), but record the observed rate
  (e.g. "3 of 10 runs") in the Evidence/Notes and say plainly that the repro is not deterministic —
  never present an intermittent repro as a deterministic one.
- **Couldn't trigger it** → the finding stays **Suspected**. Record which technique you attempted,
  the N used, and what you observed instead; that record is what makes the Suspected credible.
- **Manual reproduction** for races is usually
  `Not manually reproducible — needs precisely-timed concurrent requests`; say so honestly rather
  than inventing a by-hand path (see `bug-report-format.md`).
- If the race only exists against real shared infrastructure (multi-process DB locking, a real
  queue) and can't be isolated in a test, note exactly that in the report instead of faking a pass.
