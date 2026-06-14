---
name: qa-bug-hunter
description: >-
  Find, reproduce, and confirm bugs in a codebase and report them with evidence — a read-only QA pass
  that never modifies code. Use this ONLY when the user explicitly asks to find / hunt / audit for
  bugs, QA a target, or reproduce or confirm a specific bug — e.g. "find bugs in X", "QA this PR",
  "audit this module for defects", "reproduce this bug", "is this a bug?". A mixed request that
  explicitly asks to both find a bug and fix it ("find the bug in X and fix it") is still a bug hunt:
  apply this skill, confirm and report the bug, and decline the fix as out of scope — never modify the
  code. This skill does NOT apply to building, implementing, refactoring, debugging-to-fix, or fixing
  code when no bug-finding is asked ("fix the login bug", "this crashes, fix it"), or to any other task:
  for those it is inert and must not constrain the work or other tools. When the user wants code written
  or changed rather than a bug hunt, do not apply this skill.
---

# QA Bug Hunter

A disciplined process for finding defects, **proving** they are real, and reporting them so a team
can act. The core principle: a claim is not a bug until it has been reproduced. Everything here
exists to separate confirmed defects from hunches and to produce evidence, not opinions.

## What this skill is for — and what it is not

Finding and confirming bugs in code the user points you at — a file, a directory, a module, a PR
diff, or a running feature. The deliverable is a **bug report with evidence**, written to a file. This
is purely a QA tool: while hunting, it finds, reproduces, and reports bugs — it **never modifies code,
even if asked**; the only files it writes are repro tests and run artifacts inside `qa-bug-hunt/`.
False positives waste more of a team's time than a missed nitpick, so honesty about uncertainty matters
more than volume of findings.

**Scope boundary — read this first.** This skill applies *only* when the user explicitly wants a bug
hunt (find / hunt / audit-for / reproduce / confirm bugs, or "QA this"). It is **inert for everything
else** — building, implementing, refactoring, debugging-in-order-to-fix, or fixing code, and any use of
other tools. It must never block, delay, or constrain that work, and the "doesn't modify code" stance
above is a property of the *hunt only*, not a global restriction on the session. If the user asks for
code to be written or changed, this skill does not apply — proceed normally without it. The one
exception is a mixed request that explicitly asks to *find* a bug **and** fix it: that is still a bug
hunt — run it, report the confirmed bug (with a suggested-fix recommendation in the report), and state
plainly that applying the fix is out of scope for this skill. If it's unclear whether they want a hunt
or implementation, ask, or default to *not* applying this skill.

## Rules that govern the whole run

1. **Think before acting; ask only when it genuinely matters.** Don't assume silently — but don't
   interrogate either. The one question to ask up front (unless the request already answers it) is the
   **scope to scan** — a commit, a branch, recent changes, or the whole codebase — since it drives both
   coverage and token cost. Beyond that, most hunts need no questions; when a real ambiguity would
   change what you do, ask at most 1–2 key questions (as pickable options, plain language), only about
   things a QA can answer — never about the code or framework, which you work out yourself. Confirm
   before any consequential action. See the section below, `references/intake-and-confirmation.md`, and
   `references/scope-and-tokens.md`.
2. **Unit tests are the primary way to confirm a bug.** Always try to reproduce a defect with the
   smallest possible unit (or component) test first. The Playwright browser is a **fallback** for
   defects a unit test genuinely cannot observe — not a parallel default. Reach for the browser only
   after concluding a unit-level test can't demonstrate the bug (see phase 4).
3. **Everything the run produces lives in `qa-bug-hunt/`** at the project root, and that folder is
   always gitignored. Repro tests, evidence, sessions, and the final report all go there — see below.
4. **Work token-efficiently.** Scope to the changeset the user chose, locate-then-read (grep, then
   ranged reads), and let the project's own tools — linter, type-checker, existing tests — do the cheap
   first pass before you read source. Quality comes from attention on what matters, not from reading
   everything. See `references/scope-and-tokens.md`.

## The working folder

Before doing anything else, set up the run's home so nothing leaks into the codebase or into git:

- Ensure a `qa-bug-hunt/` directory exists at the project root.
- **Always gitignore everything the plugin creates — do this first, every run, idempotently.** Ensure
  `qa-bug-hunt/.gitignore` exists containing a single line `*`. This makes the **entire folder
  self-ignore** regardless of the repo's root `.gitignore`, so you never touch a file the team owns and
  nothing the plugin writes (reports, repros, evidence, **sessions/auth**) can ever be committed or
  show up in `git status`. Write this `.gitignore` **before** creating any other file under
  `qa-bug-hunt/`.
- **If `qa-bug-hunt/` is already git-tracked** (someone committed it before installing the plugin), the
  ignore won't take effect for tracked files. Surface this and recommend untracking it (without
  deleting the files): `git rm -r --cached qa-bug-hunt/`. Never run it without telling the user.
- **The knowledge vault self-ignores too when it lives inside a repo.** If `$QA_KNOWLEDGE_DIR` resolves
  to a path inside the current git repo (and the user hasn't deliberately committed it as a shared
  team vault), drop the same `*` `.gitignore` into the vault directory so the registry/cards can't be
  committed by accident. The default vault (`~/.qa-bug-hunter/`) is outside any repo, so this is a
  no-op there.
- Layout used throughout the run:
  ```
  qa-bug-hunt/
  ├── .gitignore                                  # contains: *
  ├── bug-report-<UTC-timestamp>-<slug>.md        # the deliverable (unique name, see phase 5)
  ├── repros/                                      # the failing tests written to confirm bugs (kept)
  ├── evidence/                                    # screenshots, traces, console/network captures
  └── .auth/                                        # storage-state session files, if used
  ```
- Create subfolders (`repros/`, `evidence/`, `.auth/`) lazily, as each is first needed.

## Before hunting — clarify only what's needed

The user may be a QA who doesn't know the repo's code or its language/framework, so figure out all
technical detail yourself and keep any questions plain and minimal. Full guidance in
`references/intake-and-confirmation.md`. In short:

- **A remote URL is a valid target.** If the user points at a repo URL (GitHub, GitLab, Azure DevOps,
  Bitbucket, or any git remote) instead of a local path, clone it locally first and then hunt the
  clone like any local repo — see `references/remote-targets.md`. Do this before the scope question, so
  the scope resolves against the real checkout.
- **Always start with the scope question** (unless the request already pins it down): *what should I
  scan?* — (a) a specific commit · (b) a branch (its diff vs. main) · (c) recent changes (your
  uncommitted work, or the last few commits) · (d) the whole codebase *(slowest, most token-heavy)*.
  It sets both coverage and cost, and a QA can answer it without knowing the code. If the request
  already names a commit, branch, "my changes," or a specific file/folder, take that as the scope and
  skip the question. Resolve each scope, and keep token use low, per `references/scope-and-tokens.md`.
  **If the scope is the whole codebase, follow the structured high-quality pipeline in
  `references/whole-codebase-hunt.md`** — don't read the repo end to end in one pass.
- **Ask anything else only when a real ambiguity would change what you do**, and you can't resolve it by
  reading the code. Default to proceeding. When you do ask, keep it to **1–2 key questions, up front, as
  a short list of options the user picks by letter**, with a "you decide" choice — never require an
  answer.
- **Only ask what a QA can answer** — which feature/area to focus on, expected vs. actual behaviour,
  the triggering input or step, which environment is safe, report-only vs. fix. **Never** ask which
  test framework, unit-vs-integration, or any code-internal detail; detect and decide those yourself.
- **State low-stakes assumptions in one line and move on** instead of asking.
- **Confirm before anything consequential** — running something that could change data or hits a
  shared environment, driving the browser off local, or applying a fix. Reading code and running
  isolated read-only repros need no confirmation.

## The workflow

Work through these phases in order. Skip phases that don't apply, but never skip straight to "this is a
bug" without reproducing it. For a whole-codebase scope, these phases run inside each partition of the
pipeline in `references/whole-codebase-hunt.md` rather than once over the whole repo.

### 0. Establish ground truth

**Warm start first.** Check the knowledge base for a card on this target (see
`references/knowledge-base.md`). If one exists, reuse its toolchain, map, and risk hotspots instead of
re-deriving them, gauging staleness from whatever signal is available: a *local* git diff against the
last-hunted commit when the target is a git checkout (local only — no GitHub/Azure/GitLab access
needed), or the card's cheap file fingerprints, or just a quick re-verify when there's no git at all.
Every check is best-effort — if git isn't available or the old commit isn't in the clone, fall back
rather than failing. Cached knowledge is a warm start, never a verdict — findings still require fresh
reproduction.

**Check the resource registry too.** Before searching the filesystem for — or asking the user about —
any external resource the code depends on (shared data models, a schema package, a dependency repo),
consult the user-level resource registry first; if it has the path and the path still resolves, use it
silently. When the user gives you a path to such a resource during the hunt, record it there
immediately so you never have to ask again. See `references/resource-memory.md`.

A bug is a deviation from *intended* behavior, so first nail down what the code is supposed to do.
Read the target **and its contract**: type signatures, docstrings/JSDoc, adjacent tests, the API
schema, and the ticket/spec if one was given. If intended behavior is genuinely ambiguous, that
ambiguity is itself a finding — record it rather than inventing a spec and "finding" a violation of
your own invention.

Also locate, early, how the project runs and tests itself — its test framework and its build/run tool,
read off the repo's own manifest, config, and existing tests. You'll need the test runner in phase 3.

### 1. Risk-rank the surface

Do not read linearly. Go where bugs actually live: boundary and null/empty inputs, error and
exception paths, money/precision math, concurrency and idempotency, state and persistence,
authorization checks, time/timezone/locale handling, and the contracts between layers. Read the
target function together with its callers and its existing tests — many bugs are mismatches between
what a function promises and what its callers assume.

For the concrete catalog of high-yield bug classes and what to inspect/grep for each, read:
- **Backend / API / data:** `references/backend-bug-patterns.md`
- **Frontend / UI / client state:** `references/frontend-bug-patterns.md`
- **Security (read when the surface handles external input, auth, URLs/paths, file access,
  serialization, or secrets):** `references/security-bug-patterns.md`

If the target calls (or is called by) **another service** and a bug may cross that boundary, you can't
verify it from this repo alone. Follow `references/cross-service.md`: ask the user for that service's
folder/repo path — or to continue without it — and only when a finding actually depends on it. A
finding you can't verify across the boundary stays **Suspected**, never Confirmed.

### 2. Form precise hypotheses

For each suspected defect, write it down as **precondition / input → expected → actual (suspected)**.
A hypothesis you can't phrase that crisply isn't ready to test yet. This framing is also exactly what
the unit test in the next phase needs to assert.

### 3. Confirm with a unit test (primary path)

This is the default way every bug gets proven. Write the *smallest* unit or component test that fails
if and only if the bug exists, using the **project's own test framework and build tool** — detect what
the project already uses and follow its conventions; never introduce a new framework. Keep it isolated
and deterministic — no network or shared state unless that's the bug itself.

Where the repro lives is decided by **one property, not the language**: does a test in this project run
as a standalone file, or must it be compiled/built against the project first?

- **Runs standalone** → the repro file lives in **`qa-bug-hunt/repros/`** and runs by path, so it
  never enters the source tree, never runs in CI, and never pollutes the suite.
- **Must build against the project** → a loose file can't resolve the project's types, so keep it
  **contained**: a throwaway test target inside `qa-bug-hunt/repros/` that references the project (or a
  REPL for logic-only checks). Because this skill is read-only on the codebase, repros are never placed
  in the project's own source/test tree.

**Read `references/repro-execution.md` for the full procedure** — toolchain detection, the
contained-test-target / REPL approach for compiled languages, and where to add your own per-stack
shortcuts.

For suspected **concurrency/idempotency** bugs, read `references/concurrency-confirmation.md` —
it shows how to actually trigger the race and capture it as a consistently failing test, instead
of leaving every race Suspected-by-inspection.

Then:
- **Run isolated/read-only repros directly; confirm first only if a repro could change data or hit a
  shared environment** (see `references/intake-and-confirmation.md`). Briefly show what you're running.
- Capture the exact output verbatim into the run — that output is the evidence.

Write the test so it **fails while the bug is present**, and **deliver it failing (red)** — that red
run is the evidence. It doubles as a regression test that *would* flip green once **the team** fixes the
code, but **you never apply that fix to make it pass**. Do not edit, even momentarily and even if you
would revert it, any file outside `qa-bug-hunt/` to turn the repro green: a repro that passes because
*you* changed the source is not a hunt result, it is a read-only violation. The green state is
hypothetical — describe it, never produce it. Keep the repro file in `qa-bug-hunt/repros/` as part of
the run record — do not delete it.

A finding is **Confirmed** only if the repro fails as predicted. If it unexpectedly passes, the code
is probably correct (or the hypothesis was wrong) — say so plainly. If no unit-level repro is
possible because the defect isn't observable at that level, go to phase 4.

### 4. Escalate to the browser only when a unit test can't see it

Some defects cannot be observed by any unit/component test: visual/layout breakage, hydration
mismatches, focus and keyboard behavior, client-state races, expired-session handling, full
end-to-end flows. For these, escalate in cost order — **cheapest tool that can prove it wins**:

1. **Playwright CLI first.** Write a real Playwright test (`@playwright/test`, run headless with
   `npx playwright test`) as the repro, in `qa-bug-hunt/repros/`. It's deterministic, reusable, and
   cheap — the same "smallest failing test" discipline as phase 3, just at the browser level.
2. **Playwright MCP only when the CLI isn't enough** — a login you can't script, live DOM exploration,
   or watching an unknown failure happen to work out the repro. **This is your call, not the user's:**
   when you judge the CLI can't prove it, escalate yourself — don't ask the user "should I use the
   MCP?". Where feasible, codify the result back into a CLI test for the record.

Reach for the MCP only after concluding the CLI can't get there. If a component test could have caught
it, prefer that and don't open a browser at all. See `references/ui-verification.md`.

- How to authenticate the browser: `references/auth-and-sessions.md`
- How to drive the browser to reproduce and capture evidence: `references/ui-verification.md`
- Save all browser evidence (screenshots, traces, logs) under **`qa-bug-hunt/evidence/`**.

The Playwright MCP is **off by default**, so non-UI hunts load no browser tools. When you decide you
need it and it isn't connected, **provision it yourself** — run
`claude mcp add playwright -- npx @playwright/mcp@latest --caps=storage` via the shell, tell the user
you've added the browser and that the connection takes effect after a reload (`/reload-plugins` or
restart), then continue once it's live. This is a one-time setup per machine: after the first time it
stays connected, so later hunts escalate to it with no setup at all. Don't make the user choose to
enable it — provisioning is your action, not their decision. Reproduce against a **local or staging**
URL, never production, unless the user explicitly says otherwise — verification can mutate state.
**Confirm before driving the browser against any non-local environment** (see *Before hunting*).

### 5. Write the report to a file

Write the findings to a single **uniquely-named markdown file inside `qa-bug-hunt/`**, using the
severity rubric and template in `references/bug-report-format.md`.

- Filename: `bug-report-<UTC-timestamp>-<slug>.md`, where the timestamp is `YYYYMMDD-HHMMSS` from the
  system clock (`date -u +%Y%m%d-%H%M%S`) and `<slug>` is a short kebab-case tag for the target
  (e.g. `auth-login`, `csv-parser`). The timestamp keeps every run's report unique.
- One report file per run; it holds all findings from that run.
- Reference evidence by relative path (`./evidence/...`, `./repros/...`) so the report and its
  evidence travel together.

After writing the file, give the user a short summary in chat **and the path to the report file**.
Lead with the most severe finding, and label every finding Confirmed vs Suspected. Every finding also
carries a **Manual reproduction** entry — by-hand steps through a UI/API/CLI surface, or an honest
"not manually reproducible" note, marked walked-by-hand vs derived (per `references/bug-report-format.md`)
— in addition to, never instead of, the automated repro. The report may include a root-cause hypothesis
and a suggested-fix *recommendation* for the team, but this skill never applies it.

### 6. Update the knowledge base

After reporting, write or refresh this target's card in the knowledge vault (see
`references/knowledge-base.md`): toolchain and map if newly learned or changed, updated risk hotspots,
this run's findings appended to the known-issues ledger (with repro paths and status), and a fresh
`refreshed:` stamp at the current commit. Keep it concise — facts and pointers, never secrets or data.
So the next hunt on this target starts warm. (Suppressed if the optional read-only hook is enabled,
since it blocks writes outside `qa-bug-hunt/`.)

## Guardrails

These protect the user's environments and data, and they keep findings trustworthy:

- **Never modify application code while hunting.** This is a QA pass: it finds, reproduces, and reports
  bugs — it does not fix them, even if asked (fixing is a separate task; if the user wants it, that's a
  different request handled outside this skill). This holds **even when the request says "fix it," even
  to demonstrate that a fix works, and even if you intend to revert it** — never run Edit/Write/MultiEdit
  on the **target project's own files**: its application code, its tests, its configs, anything in the
  repo being hunted *except* `qa-bug-hunt/`. If you catch yourself about to edit a project source file,
  stop: the report *recommends* the fix in prose, it never applies it. A report that says the fix was
  "not applied" while the source file is actually changed is a **correctness failure — worse than missing
  the bug**, because it lies about the working tree. Inside the repo, the only files it writes are repro
  tests and run artifacts under `qa-bug-hunt/`. (Writing the knowledge vault / resource registry at
  `$QA_KNOWLEDGE_DIR` — normally outside the repo — is a separate, intended write, not target code; see
  phases 0 and 6.) This is enforced by behavior, scoped to the hunt; an *optional*, off-by-default hook
  (`hooks/`) can hard-enforce it for dedicated hunt sessions, but it is not active by default and the
  skill never blocks normal development.
- **Before reporting, verify you stayed read-only.** As the last step before writing the report, confirm
  you changed no file in the **target project** except under `qa-bug-hunt/` — on a git checkout,
  `git status --short` of the target repo should show only `qa-bug-hunt/` paths (and those are
  gitignored, so ideally the tree is clean). The knowledge vault lives outside the repo, so it never
  appears here anyway. If a project source file shows as modified, you broke the invariant: revert is not
  the remedy — say so plainly in the chat and do not ship a report whose "not applied" claim contradicts
  the working tree.
- **Never type passwords or create accounts, and never put secrets in tests, the repo, or chat.** The
  human authenticates, or supplies a token via an environment variable / the OS keychain — never pasted
  into chat. A token is used for the run only and is **never written to disk** (not in tests, cards, the
  report, evidence, or the registry), and is scrubbed from saved evidence and the report. See
  `references/auth-and-sessions.md`.
- **Verify against local/staging, not production**, unless explicitly told. Prefer read-only
  investigation; ask before running anything that writes, migrates, deletes, or hits a shared
  environment.
- **Understand the root cause before writing a finding** (so the report explains *why*, not just
  *what*); and if you've tried to reproduce the same thing about three times without progress, stop,
  summarize what you tried and what's still unclear, and ask one focused question rather than thrashing.
- **Treat a flaky existing test as a signal, not a confirmed bug.** When the project's own suite
  surfaces a failure, rule out flakiness (re-run; check for order/time/network dependence) before
  reporting it — an intermittent failure is worth noting, but don't log it as a deterministic defect.
  Full triage procedure (flaky vs known-failing vs in-scope regression) in
  `references/scope-and-tokens.md`.
- **Don't inflate.** Confirmed and Suspected are different words for a reason; uncertainty stated
  honestly is more useful than a long list of maybes presented as facts.
