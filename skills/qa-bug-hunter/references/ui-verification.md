# Driving the browser to reproduce a UI bug

The browser is a **fallback**, used only after concluding no unit/component test can observe the defect
(see SKILL.md phases 3–4). When you do need it, prefer the cheaper tool first.

## CLI first (default)

Write a Playwright **CLI** test as the repro: `@playwright/test`, run headless with
`npx playwright test`, file kept in `qa-bug-hunt/repros/` (e.g. `qa-bug-hunt/repros/<slug>.spec.ts`).
This is deterministic, reusable, cheap, and doubles as a regression test.

- Detect whether the project already has `@playwright/test` (check `package.json` / `node_modules`). If
  not, tell the user the one-liner: `npm i -D @playwright/test && npx playwright install chromium`.
- Authenticate via the **same storage-state file** the MCP would use (`qa-bug-hunt/.auth/state.json`,
  see `auth-and-sessions.md`) — `test.use({ storageState: '...' })`. CLI and MCP share it.
- Drive the exact precondition and steps from your hypothesis; assert on the broken state; on failure,
  capture a screenshot to `qa-bug-hunt/evidence/`.

## MCP only when the CLI isn't enough

Escalate to the Playwright MCP for what the CLI can't do blind: a login you can't script, live DOM
exploration, or watching an unknown failure to form the repro. **You decide this and act on it — don't
ask the user whether to use the MCP.** The MCP is **off by default**, so it usually isn't connected the
first time you need it. When that happens, **provision it yourself**:

```bash
claude mcp add playwright -- npx @playwright/mcp@latest --caps=storage
```

Then tell the user you've added the browser and that it connects after a reload (`/reload-plugins` or
restart), and continue once it's live. This is a **one-time setup per machine** — after the first time
the MCP stays connected, and later hunts escalate to it automatically with no setup and no questions.
(For a team, add the equivalent to the project's `.mcp.json` with `-s project`.) When you've reproduced
it interactively, codify it back into a CLI test where feasible. Either way evidence goes under
**`qa-bug-hunt/evidence/`**.

## Flow

1. **Authenticate** if the screen requires it — see `auth-and-sessions.md`. Use a local/staging URL.
2. **Navigate** to the screen, and set up the exact precondition (the data, the query params, the
   prior steps) that the bug needs. A bug that needs an empty list, a specific record, or a slow
   response only shows up once that condition is real.
3. **Reproduce** by performing the precise steps from your hypothesis — click, type, submit, wait.
4. **Observe** with the accessibility snapshot plus the console and network logs. The snapshot is the
   most reliable thing to assert against (roles, names, visible text); console errors and failed
   network requests are often the smoking gun.
5. **Capture a screenshot at the moment of failure.** Save it under `qa-bug-hunt/evidence/`
   (e.g. `qa-bug-hunt/evidence/<short-bug-slug>.png`) and reference that path in the report.
6. **Close the browser** when done. (In isolated mode, closing discards that session's state — that's
   expected; reload the storage-state file next time.)

## Make the repro deterministic

Flaky evidence is weak evidence. To keep reproductions stable:
- Pin a fixed viewport size so layout bugs are reproducible.
- Wait on **state** (an element/text/condition appearing) rather than fixed timeouts.
- If animations cause flicker, disable them via an `--init-script` that injects
  `* { transition: none !important; animation: none !important; }`.
- Force the specific condition (throttle the network, point at a seeded record) instead of hoping it
  recurs.

## Evidence to collect for the report

- The screenshot at the failure point (path).
- The exact reproduction steps (so anyone can repeat them).
- Any console errors and failed/`4xx`/`5xx` network requests observed.
- **Redact secrets from saved evidence.** Before saving network captures/HARs/logs, strip
  `Authorization` headers, cookies, and token values (replace with `***`). A pasted token must never
  land in `qa-bug-hunt/evidence/` or the report.
- The URL/state and which identity was used (relevant for authz bugs).

## Scope reminder

Reproduce against local or staging only, unless the user explicitly authorizes production. Driving a
real browser performs real actions — treat anything that writes or deletes as something to confirm
with the user first.
