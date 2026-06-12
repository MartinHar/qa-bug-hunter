# Authentication & sessions for browser verification

This answers "how does the browser get past login?" when verifying UI bugs with the Playwright MCP.
(The MCP is off by default — enable it first; see `ui-verification.md`.)

## The principle (also the cleanest engineering choice)

Claude never types passwords and never creates accounts. The human authenticates once, or a
pre-captured session/token is supplied. Credentials never appear in the repo, in a test, or in the
chat. This isn't only a safety rule — it's also the most robust pattern, because it decouples "being
logged in" from "knowing the password," exactly like a `storageState` fixture in a normal Playwright
suite. Always verify against a **local or staging** environment; a logged-in browser can mutate data.

There are three ways to get an authenticated browser, in rough order of how often you'll want them.

## Option A — Persistent profile (default; best for interactive hunting)

The Playwright MCP runs with a **persistent browser profile by default**. Logged-in state and cookies
survive between sessions, and each workspace gets its own profile automatically (the profile dir is
keyed by a workspace hash), so different projects don't collide.

Workflow:
1. Ask the MCP to navigate to the app's login page.
2. **The human logs in by hand** in the browser window the MCP opened.
3. From then on the session persists — later runs in the same workspace start already authenticated.

Profile location (override with `--user-data-dir`): macOS `~/Library/Caches/ms-playwright/`,
Linux `~/.cache/ms-playwright/`, Windows `%USERPROFILE%\AppData\Local\ms-playwright\` — folder
`mcp-{channel}-{workspace-hash}`. Delete it to force a clean re-login. Note: a persistent profile can
only be used by one browser at a time, so for parallel runs use `--isolated` or distinct
`--user-data-dir`s.

Use this when: you're hunting interactively on your own machine and don't mind logging in once.

## Option B — Storage state file (best for repeatable / CI / shareable runs)

Capture the authenticated state (cookies + localStorage) to a JSON file once, then load it into a
fresh isolated browser on every run. Repeatable, no persistent profile, and the same artifact works
in a standalone `playwright test` suite.

Two ways to produce the file:

1. **Via the MCP's storage capability.** The enable command includes `--caps=storage`, which exposes a
   `browser_storage_state` tool. After a manual login (Option A flow), have the MCP save the state to
   a file under the run folder, e.g. `qa-bug-hunt/.auth/state.json`.

2. **Via the helper script** `scripts/save-auth-state.mjs` — opens a real browser, you log in by
   hand, it writes the state file. No credentials touch the script:
   ```bash
   # in the target project (needs Playwright: npm i -D @playwright/test && npx playwright install chromium)
   BASE_URL=http://localhost:3000 OUT=qa-bug-hunt/.auth/state.json node path/to/save-auth-state.mjs
   ```

Then point the MCP at it by switching the server to isolated mode with the state file:
```json
{ "mcpServers": { "playwright": { "command": "npx",
  "args": ["@playwright/mcp@latest", "--isolated", "--storage-state=./qa-bug-hunt/.auth/state.json"] } } }
```

The state file lives in `qa-bug-hunt/`, which is already gitignored — but never copy it elsewhere,
since it's a live session. Regenerate it when it expires (re-run the login).

Use this when: you want deterministic, repeatable verification, or to reuse the session in a real
test suite or CI.

The **same** `state.json` is used by both the Playwright CLI repro (`test.use({ storageState })`) and
the MCP — capture it once, use it either way.

## Option C — Token / header auth (APIs and token-based SPAs)

For backend/API bugs, "auth" usually means a bearer token or API key — there's no browser involved.
When a hunt needs one, **never ask the user to paste it into chat.** Have them put it in an environment
variable (or the plugin's sensitive `userConfig`, stored in the OS keychain) and have repro scripts
read it from the environment, e.g.:

> To reproduce this against staging I need a bearer token for the orders API. Don't paste it here —
> export it in your shell as `ORDERS_TOKEN=...` (a short-lived/staging token is ideal) and I'll read it
> from the environment.

A token must **never** be written to disk by the skill (a card, the report, evidence, a committed file,
or the registry) and must never appear in chat. For SPAs that read a token from
`localStorage`/`sessionStorage`, seed it with the MCP's `--init-script` reading from that environment
variable rather than hardcoding it. Tokens are scrubbed from saved evidence and the report (see
`ui-verification.md` and `bug-report-format.md`).

Use this when: testing APIs directly, or a token-based client where a full interactive login is
overkill.

## Authorization testing needs more than one session

To find authorization bugs (IDOR, missing role checks, privilege escalation) you need to act **as one
user against another user's data**, or as a non-admin against admin-only actions. Capture a separate
storage-state file per identity (`qa-bug-hunt/.auth/userA.json`, `.../userB.json`, `.../admin.json`)
and load the relevant one to reproduce. "User A can load User B's record by changing the id in the
URL" is a classic confirmed-with-evidence authz bug.

## Quick decision guide

- Hunting interactively, one project, don't mind logging in once → **Option A**.
- Want it repeatable / want to reuse the session in CI or a test suite → **Option B**.
- Pure API testing, or token-in-localStorage SPA → **Option C**.
- Testing who-can-access-what → **Option B with multiple identity files**.
