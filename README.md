# QA Bug Hunter

A Claude Code plugin that finds, **reproduces**, and confirms bugs in frontend or backend code, then
writes a report with evidence. It **only runs when you ask it to hunt bugs**, and while it does it is
**read-only — it never fixes or writes code.** When you're not asking for a bug hunt, it does nothing
and never blocks normal development, code-writing, or other tools. It contains:

- **`qa-bug-hunter` skill** — the methodology: establish intended behavior → risk-rank the code →
  form precise hypotheses → **confirm with a unit test** → (only if a unit test can't see it) verify
  in a real browser → write a Confirmed-vs-Suspected report with evidence. It activates only on
  explicit bug-hunting requests and is inert for build/implement/fix work.
- **Browser-based UI verification, decided by the plugin.** For UI bugs it writes a **Playwright CLI**
  test first (no setup, used automatically). When the CLI genuinely can't prove a bug, the plugin
  escalates to a **Playwright MCP** (a real interactive browser) **on its own** — you never have to ask
  for it. The MCP isn't loaded during non-UI hunts (so they carry no browser overhead); the first time
  one is needed the plugin sets it up itself (a one-time step), and after that it's used automatically.
- **An optional read-only hook** (`hooks/`, **disabled by default**) — for dedicated hunt-only
  sessions, hard-blocks writes outside `qa-bug-hunt/`. Off by default precisely so it never interferes
  with normal development; see `hooks/README.md` before enabling.

## How it behaves (the rules)

1. **It thinks before acting, and asks only when it matters.** Its one up-front question (unless your
   request already answers it) is **scope** — find bugs in a specific commit, a branch, recent changes,
   or the whole codebase (the last being the slowest and most token-heavy). Beyond that it doesn't
   assume silently but doesn't interrogate either: only when something genuinely ambiguous would change
   what it does, it asks 1–2 key questions as pickable options, in plain language, and only about things
   a QA can answer (which feature, expected vs. actual, which environment) — never about the code or
   framework, which it works out itself. It confirms before any consequential action (changing data,
   hitting a shared environment). This blends Andrej Karpathy's "think before coding" guidelines with
   the superpowers plugin's lightweight brainstorming and its failing-test-first / root-cause
   discipline.
2. **It works token-efficiently.** Scoping to a commit/branch/recent-changes is the main cost lever, so
   it defaults you there and treats whole-codebase as the expensive fallback. It locates with grep then
   reads only the relevant ranges, runs your linter/type-checker/tests (and LSP, if installed) to catch
   the cheap defects before reading source, and fans out with subagents on large scopes — spending its
   reading budget on the logic and edge cases that actually need a careful look. See
   `skills/qa-bug-hunter/references/scope-and-tokens.md`.

   For **whole-codebase** runs there's a dedicated high-quality
   pipeline, because the real risk there is attention decay, not tokens: it maps the repo, risk-ranks
   and partitions it, deep-scans each partition in its **own subagent context** so attention stays
   sharp, runs a **cross-cutting seam pass** for the inter-module/contract bugs per-file reading misses,
   then consolidates and **clusters findings by root cause** — and leaves a coverage record of what was
   examined and where the blind spots are. See `skills/qa-bug-hunter/references/whole-codebase-hunt.md`.
3. **Unit tests are the primary confirmation path.** Every suspected bug is first reproduced with the
   smallest possible unit/component test in your existing runner. The browser is only used when a
   defect genuinely can't be seen at the unit level (visual breakage, hydration, focus/keyboard,
   client-state races, expired-session handling, end-to-end flows).
4. **Everything the run produces goes in `qa-bug-hunt/`** at your project root, and that folder is
   always gitignored.

**It only acts when you ask for a bug hunt, and it never modifies your code.** Outside an explicit
bug-hunting request it stays out of the way — it won't trigger on, block, or constrain feature work,
fixes, or other tools. While hunting, the repro tests it writes are its only output and they live
inside `qa-bug-hunt/`; a report may *recommend* a fix in text, but applying fixes is out of scope. The
"no code changes" guarantee is behavioral and scoped to the hunt; if you want it hard-enforced for
dedicated hunt sessions, enable the optional hook (`hooks/README.md`) — it's off by default so it can't
interfere with normal development.

## Cross-service awareness (on demand)

Services that call services hide their worst bugs at the boundaries. The hunter works one repo at a
time, so when a finding actually depends on another service it **asks you for that service** — it tells
you which dependency it needs and why, and you either give it the folder/repo path or tell it to
continue without. It never guesses across the boundary and never requires a path to proceed:

- **Give a path** → it reads that repo read-only and targeted (just the relevant contract), uses it to
  confirm or refute, and caches a short **service card** so it's asked once, not every hunt.
- **Continue without** → anything depending on the unseen service is reported **Suspected**, not
  Confirmed, with an "unverified — needs <service>" note.

Cards are plain markdown under `$QA_KNOWLEDGE_DIR` (default `~/.qa-bug-hunter/knowledge/services/`) —
which doubles as an **Obsidian vault** you can open directly (graph/backlinks/search) with no MCP or
plugin, since it's just a folder of `.md`. Cards are treated as hints to verify, with a `refreshed:`
date so staleness is visible. (Optional: point Claude at the vault via a filesystem Obsidian MCP —
`claude mcp add obsidian -- npx @bitbonsai/mcpvault@latest <vault>` — only if you want Obsidian's own
search; the filesystem path needs nothing.) See `references/cross-service.md`.

**It also learns across runs.** Each card carries a tool-maintained *hunt profile* — toolchain, map,
risk hotspots, and a known-issues ledger — that the hunter writes at the end of a run and reads at the
start of the next one. A repeat hunt on the same target starts **warm**: it skips re-deriving the
toolchain and structure, and re-examines only what changed since last time. When the target is a git
checkout it works that out with a *local* git diff against the last-hunted commit (no remote access —
never touches GitHub/Azure/GitLab); when there's no usable git history (not a checkout, a shallow CI
clone, no git binary) it falls back to cheap file fingerprints, or just re-verifies. Prior findings
become a regression checklist — it re-runs their repros to see if they're fixed or have regressed (no
git needed for that). Findings carry a stable fingerprint, so repeat runs dedupe against the ledger
instead of re-reporting known bugs, and a previously-fixed bug that fails again is flagged
**regressed**. Cached facts are a warm start, never a verdict; every finding is still freshly
reproduced. See `references/knowledge-base.md`.

**It also remembers where your shared resources live.** Hand it a path once — your data models, a
shared schema package, a dependency repo — and it records that in a user-level **resource registry**
(`~/.qa-bug-hunter/knowledge/resources.md`, or wherever `$QA_KNOWLEDGE_DIR` points). Every later hunt,
on any service, checks the registry before searching or asking, so it never re-hunts for the same path.
If a remembered path moves, it tells you and asks for the new one instead of failing. Point
`$QA_KNOWLEDGE_DIR` at a shared path to share the registry across a team. See
`references/resource-memory.md`.

## The `qa-bug-hunt/` working folder

On each run the skill ensures this exists at the project root and **self-ignores** via its own
`.gitignore` containing `*` — so it never appears in `git status` and you never have to edit your
repo's root `.gitignore`:

```
qa-bug-hunt/
├── .gitignore                                  # contains: *  (ignores the whole folder)
├── bug-report-<UTC-timestamp>-<slug>.md        # the deliverable, one per run, unique name
├── repros/                                      # the failing tests written to confirm bugs (kept)
├── evidence/                                    # screenshots, traces, console/network captures
└── .auth/                                        # storage-state session files, if used
```

The report is a markdown file named `bug-report-YYYYMMDD-HHMMSS-<slug>.md`; the timestamp makes every
run unique. It references its evidence by relative path so report + evidence travel together.

> If your local test discovery picks up `qa-bug-hunt/repros/` during normal runs, exclude it in your
> runner. In CI it's a non-issue — the folder is gitignored so it isn't checked out. For compiled
> stacks (C#/Java/Go), where a test must build against the project, the repro is kept **contained**
> under `qa-bug-hunt/` (never in your source tree) — see
> `skills/qa-bug-hunter/references/repro-execution.md`.

## Permissions & data

What this plugin reads, writes, and runs — so there are no surprises:

- **Read-only on your code.** During a hunt it never modifies application code, even if asked. The only
  files it writes in your project are repro tests and run artifacts under `qa-bug-hunt/` (always
  gitignored). An optional, **off-by-default** hook can hard-enforce this (`hooks/`).
- **Writes outside the workspace (home dir).** It keeps a small knowledge vault at `~/.qa-bug-hunter/`
  (override with `$QA_KNOWLEDGE_DIR`) — per-codebase cards and a resource registry of local paths you
  give it. It stores **paths and non-sensitive notes only, never secrets or data**. Delete the folder
  any time to reset.
- **Credentials.** It never types passwords, creates accounts, or asks you to paste tokens into chat.
  You authenticate the browser by hand, or supply a token via an environment variable / OS keychain.
  Tokens are never written to disk and are scrubbed from the report and saved evidence.
- **Session files.** If you capture a browser session for repeatable UI checks, the live
  `storage-state` lives under `qa-bug-hunt/.auth/` (gitignored) — treat it like a credential.
- **Nothing auto-runs on install.** There is no bundled `.mcp.json`, so enabling the plugin starts no
  background processes and no MCP. Browser tooling is pulled in **only during a UI bug hunt, only when
  needed**: the plugin runs the project's own tests and the repro tests it writes, and — when a UI bug
  can't be proven with the Playwright CLI — it provisions the Playwright MCP itself via `npx`
  (`claude mcp add playwright …`) and tells you. The optional Obsidian vault MCP
  (`npx @bitbonsai/mcpvault`) is never auto-run. It always asks before anything that could change data
  or hit a shared/non-local environment.

## Install

Install straight from GitHub — this repo is itself a Claude Code marketplace. In Claude Code, run:

```
/plugin marketplace add MartinHar/qa-bug-hunter
/plugin install qa-bug-hunter@qa-bug-hunter
```

Verify with `/plugin` (or `claude plugin list`). Update later with `/plugin marketplace update`.

**Trial for one session (no install):**
```bash
git clone https://github.com/MartinHar/qa-bug-hunter
claude --plugin-dir ./qa-bug-hunter
```

> This is the way to install today — the plugin isn't in Anthropic's `claude-community` marketplace
> yet. For other methods (personal skills dir, sharing with a team) and the maintainer release flow,
> see [INSTALL.md](INSTALL.md). Validate the manifest after edits with `claude plugin validate ./` from
> the repo root.

## The browser (only for UI bugs) — handled for you

For UI bugs a unit test can't catch, the skill verifies in cost order: it writes a **Playwright CLI
test** first (`@playwright/test`, headless, cheap and reusable, kept in `qa-bug-hunt/repros/`), and
only escalates to the **Playwright MCP** when the CLI isn't enough — an unscriptable login, live DOM
exploration, or watching an unknown failure to form the repro. **The plugin makes that call itself —
you never have to ask it to use the MCP.**

The MCP isn't loaded during non-UI hunts (zero browser overhead). The first time a hunt actually needs
it, the plugin runs the setup itself:

```bash
claude mcp add playwright -- npx @playwright/mcp@latest --caps=storage
```

It self-installs via `npx` (if the browser binary is missing it runs `npx playwright install
chromium`). Adding an MCP connects after a reload, so that first time you'll do one `/reload-plugins`
or restart — a **one-time step per machine**. After that the browser stays connected and the plugin
escalates to it automatically, no setup and no prompts. (For a team, add `-s project` or drop the
equivalent into the project's `.mcp.json`.)

## Auth in 30 seconds

You don't hand Claude any credentials. Sessions and any auth files live in `qa-bug-hunt/.auth/`
(gitignored). Pick the fit — full detail in `skills/qa-bug-hunter/references/auth-and-sessions.md`:

- **Interactive:** Claude opens the login page, **you log in by hand**, the session persists.
- **Repeatable / CI:** capture the session once to `qa-bug-hunt/.auth/state.json` (via the MCP's
  storage tool or `scripts/save-auth-state.mjs`), then run the MCP with
  `--isolated --storage-state=./qa-bug-hunt/.auth/state.json`.
- **APIs / token SPAs:** keep the token in an env var (or a sensitive setting); seed
  token-in-localStorage apps with the MCP's `--init-script`.
- **Authorization bugs:** keep one session file per identity (`userA`, `userB`, `admin`) and swap.

## How to use it

Point Claude at a target and ask it to hunt. Examples:

- "Find bugs in `src/services/auth.py` — focus on edge cases and error handling."
- "QA this PR diff and confirm anything you find with a test."
- "Audit `components/LoginForm.vue` for state and validation bugs."
- "Find bugs in the whole repo." (triggers the whole-codebase pipeline)
- "Hunt bugs in `https://github.com/owner/repo`." (clones the remote, then hunts it — see below)

### Hunt a remote repo by URL

The target can be a **repo URL** instead of a local path — GitHub, GitLab, Azure DevOps, Bitbucket, or
any git remote (HTTPS or SSH, and web URLs that point at a branch/commit work too). The plugin clones
it to a folder you name and then hunts the clone like any local repo. Private repos use your existing
git credentials (`gh` auth / SSH keys / credential helper) — you're never asked to paste a token. A
repeat hunt on the same remote starts warm (re-fetch + diff). See
[remote-targets.md](skills/qa-bug-hunter/references/remote-targets.md).

It first asks the scope question (commit / branch / recent changes / whole codebase) unless you've
already said, reads the code and its contract, writes the smallest failing test in your project's own
framework (shown before it runs; in `qa-bug-hunt/repros/`), escalates to the browser only when a unit
test can't see the bug, and writes a Confirmed-vs-Suspected report to `qa-bug-hunt/`. It detects and
uses each project's own test framework and build tool, so it works the same whatever the language.

### Example run (shape)

```
You:    Find bugs in the utils module.
Claude: What should I scan?
        (a) a specific commit  (b) a branch  (c) recent changes  (d) the whole utils module
You:    d
Claude: [reads utils/, runs the type-checker + existing tests, flags a suspicious default arg]
        Hypothesis: append_to() reuses one shared list across calls (mutable default), so a fresh
        call doesn't start empty. Writing a repro:
        [shows qa-bug-hunt/repros/test_append_to.py, runs it — it fails as predicted]
        Confirmed. Report written to qa-bug-hunt/bug-report-20260530-141233-utils.md
        - [Medium] append_to() shares state via a mutable default argument (utils/lists.py:7)
          Evidence: ./repros/test_append_to.py  ·  Suggested fix (for your team): default to None and
          create the list inside the function.
```

## Evals

`evals/` holds small scenarios (a planted bug it should catch, correct code it should *not* flag, a
"never fix" check) with rubrics, so you can confirm the skill still behaves after you edit it. See
`evals/README.md`.

## Recommended companions

For real-time diagnostics while hunting, install the official LSP plugins (binaries installed
separately): `pyright-lsp` (`pip install pyright`) and `typescript-lsp`
(`npm i -g typescript-language-server typescript`). They make step 2 of the token strategy cheaper and
sharper.

## Customizing

- Edit `skills/qa-bug-hunter/SKILL.md` for the workflow and guardrails (SKILL.md changes apply
  immediately in-session; other component changes need `/reload-plugins`).
- Edit the catalogs in `references/` (backend, frontend, security, concurrency-confirmation) to
  encode your domain's invariants (money/rounding, idempotency).
- The browser is read-only-safe and optional; tune its flags when you enable it (isolated vs.
  persistent, viewport, proxy) — see `references/auth-and-sessions.md`.
- Hard read-only enforcement is **optional and off by default** (`hooks/`), so the plugin never blocks
  normal development. The skill is read-only by behavior while hunting; enable the hook only for
  dedicated hunt sessions — see `hooks/README.md`.

## Layout

```
qa-bug-hunter/
├── .claude-plugin/plugin.json     # manifest
├── hooks/                         # OPTIONAL read-only guard — OFF by default
│   ├── hooks.json.disabled        # rename to hooks.json to enable (see hooks/README.md)
│   ├── guard-readonly.py          # denies writes outside qa-bug-hunt/ (only when enabled)
│   └── README.md                  # when/how to enable, and the warning
├── skills/qa-bug-hunter/
│   ├── SKILL.md                   # the methodology (the brain)
│   ├── references/                # loaded on demand
│   │   ├── intake-and-confirmation.md
│   │   ├── scope-and-tokens.md
│   │   ├── whole-codebase-hunt.md
│   │   ├── cross-service.md
│   │   ├── knowledge-base.md
│   │   ├── backend-bug-patterns.md
│   │   ├── frontend-bug-patterns.md
│   │   ├── security-bug-patterns.md
│   │   ├── concurrency-confirmation.md
│   │   ├── repro-execution.md
│   │   ├── auth-and-sessions.md
│   │   ├── ui-verification.md
│   │   └── bug-report-format.md
│   ├── templates/service-card.md  # per-service knowledge card
│   └── scripts/save-auth-state.mjs
├── evals/                         # scenarios + rubrics to test the skill
├── .gitignore
└── README.md
```

> Created by **Martin Harutyunyan**.