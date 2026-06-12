# Bug report format

## Where the report goes

Write the report to a **uniquely-named markdown file inside `qa-bug-hunt/`** at the project root:

- Filename: `bug-report-<UTC-timestamp>-<slug>.md`, where the timestamp is `YYYYMMDD-HHMMSS`
  (`date -u +%Y%m%d-%H%M%S`) and `<slug>` is a short kebab-case tag for the target (e.g.
  `auth-login`, `csv-parser`). The timestamp guarantees a unique name per run.
- One file per run; it contains all findings from that run.
- Reference evidence by relative path — `./repros/<test>` for the failing test and
  `./evidence/<file>` for screenshots/traces — so the report and its evidence stay together.
- After writing it, summarize in chat and give the user the file path.

## Structure

Report each finding with this structure. Lead with the most severe finding, group related ones, and
label every finding Confirmed or Suspected — never blur the two.

## Status

- **Confirmed** — reproduced. A failing test, a captured screenshot, or observed wrong state exists.
- **Suspected** — looks wrong on reading but not yet reproduced. State *why* it isn't confirmed (no
  repro path, needs a real service, ambiguous spec). A suspected finding is a lead, not a verdict.

## Severity (give a one-line rationale, don't just pick a label)

The rationale should reflect both **impact** (what breaks, how badly) and **reach** (who hits it,
how often). Challenge mismatches in both directions: an edge case nobody can reach is rarely
Critical, and a cosmetic glitch every user sees on login is rarely Low.

- **Critical** — data loss/corruption, security breach, incorrect financial/monetary result, or
  system down. Anything that loses money, leaks data, or takes the system offline.
- **High** — a core feature is broken with no reasonable workaround, or produces wrong results that a
  user would act on.
- **Medium** — a feature is impaired but a workaround exists, or the impact is limited to an edge case.
- **Low** — cosmetic, minor, or very-rare-edge issues with little user impact.

## Manual reproduction

Separate from — and **in addition to** — the automated repro in **Steps to reproduce**, every finding
states how a **human reproduces it by hand**, through a user-facing surface only: UI clicks/inputs, an
HTTP request (curl/Postman), or a CLI command — with exact inputs and preconditions, ending at the
observable wrong result. No test framework, no code. It always takes one of three forms, and you must
say which:

- **`(walked by hand)`** — you actually executed this path this run (drove the browser in phase 4, or
  sent the request) and saw it fail. The numbered steps are what you did.
- **`(derived from code path, not hand-executed)`** — the steps are inferred from how the bug is
  reachable through a user-facing surface, but the bug was confirmed by a unit test, so no human
  independently walked them this run. Be honest that the manual path is reasoned, not observed.
- **`Not manually reproducible — <reason>`** — no user-facing surface exposes it by hand: e.g. an
  internal helper not reachable from any UI/API/CLI, a race that needs precisely-timed concurrent
  requests, or state that must be injected programmatically. The reason is itself useful — give it.

Never label inferred steps as walked. Apply the same secret-scrubbing here as everywhere — any token,
cookie, or `Authorization` header in a curl/HTTP step becomes `***`.

## Template

```
### [Title — concise, specific: what breaks and where]
- Status:      Confirmed | Suspected (if suspected, why not confirmed)
- Severity:    Critical | High | Medium | Low — <one-line rationale>
- Location:    path/to/file.ext:line  (function / component)
- Fingerprint:  <file path · symbol · root-cause one-liner> (stable id for cross-run dedup)
- Environment: local | staging; relevant versions/flags; identity used (for authz bugs)
- Preconditions: what must be true to hit it (data, state, role)
- Steps to reproduce (REQUIRED — exact, numbered, runnable by a third party with no extra context):
    1. <exact command or click, e.g. `npx playwright test ./repros/login.spec.ts`>
    2. ...
- Manual reproduction (REQUIRED — how a human reproduces it by hand, or why they can't). Mark which:
    `(walked by hand)` actually executed this run · `(derived from code path, not hand-executed)` inferred from a reachable surface, bug confirmed by unit test · `Not manually reproducible — <reason>`
    1. <user-facing step: UI click/input, curl/HTTP request, or CLI command — exact inputs>
    2. ...
- Expected:    what should happen
- Actual:      what happens instead
- Confirmed via: unit test | Playwright CLI | Playwright MCP — which tool proved it
- Evidence:    repro test (`./repros/<test>`) + verbatim output / screenshot (`./evidence/<file>`) / console + network errors / logs
- Root-cause hypothesis: best current explanation of why
- Suggested fix: a recommendation for the team — this skill does not apply it
- Notes / assumptions: anything that affects interpretation
```

## Regression check (warm hunts)

When the knowledge base has prior findings for this target (see `knowledge-base.md`), the report
**opens** with a short regression table — before any new findings:

| Prior finding (fingerprint) | Severity | Repro | Result |
|---|---|---|---|
| `<file · symbol · root cause>` | High | `./repros/<file>` | fixed / still open / **regressed** |

- **regressed** (previously fixed, failing again) indicates a broken fix — order it above
  same-severity open bugs and call it out in the chat summary.
- New findings are deduped against these fingerprints: a match updates the table row, it does not
  appear again as a new finding.

## Reporting discipline

- **Don't inflate.** Stating one confirmed Critical plus three honest Suspecteds is more useful than
  ten findings dressed up as certainties.
- **No false positives.** If a repro unexpectedly passes, report that the code appears correct rather
  than straining to call it a bug.
- **This skill reports; it never applies fixes.** A suggested-fix line is a recommendation for the
  team, not an action the skill takes — fixing is out of scope for a QA hunt.
- **Make every Confirmed reproducible by someone else** from the steps and evidence alone.
- **Exact reproduction steps are mandatory for every finding.** A finding without precise, numbered,
  runnable steps is incomplete and must not be labeled Confirmed. For Confirmed bugs the steps include
  the exact repro invocation (the test command or the click-by-click sequence) plus any precondition or
  environment setup; for Suspected, give the exact steps you attempted and what blocked confirmation.
- **Manual reproduction is required on every finding too** — by-hand steps through a UI/API/CLI surface,
  or an honest `Not manually reproducible — <reason>` note, marked walked-by-hand vs derived (see the
  *Manual reproduction* section above). This is additional to, never a replacement for, *Steps to
  reproduce*.
- **Never write a secret into the report.** Scrub tokens, `Authorization` headers, cookies, and
  passwords (replace with `***`). A token the user pasted into chat must not appear in the report file.
