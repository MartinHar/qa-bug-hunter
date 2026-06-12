# Cross-service knowledge (on demand)

Services that call other services hide their worst bugs at the boundaries — contract mismatches,
version skew, broken assumptions about what the other side returns or guarantees. The hunter works on
**one repo at a time**, so when a bug depends on another service it **asks you for that service** rather
than guessing or silently giving up.

## When to ask

Ask for another service's code only when **both** hold:
1. a finding genuinely depends on that service (the bug hinges on what it returns/accepts, or a
   contract mismatch at the boundary), **and**
2. having its code would actually change the outcome — turn a **Suspected** finding into one you can
   **Confirm or refute**, or materially raise your confidence. If you can already confirm or refute the
   finding without it, do not ask.

In short: ask only when you're confident the access improves the result. If a dependency is irrelevant
to the bug in hand, or you can settle the finding without it, don't ask — same "ask only when it
matters" discipline as the rest of intake.

**Before asking, consult the resource registry** (`references/resource-memory.md`): if the service's
path is already recorded and still resolves, use it without asking. Only fall through to the ask below
when the registry has no usable entry.

## The ask

Pause and ask in plain language — batched if several services are involved, each with a skip option:

> Testing this properly needs visibility into **<service>** — your code calls it at `<where>` and the
> finding depends on its behavior. How should I handle it?
> (a) use my saved note on <service> from <date>      ← only shown if a current card exists
> (b) point me to <service>'s folder or repo:  <you give the path>
> (c) continue without it — I'll flag anything that depends on <service> as unverified

Option (c) is always available. **Never require a path to proceed**, and never block the hunt waiting
on one.

## If you get a path

Read that repo **read-only and targeted** — just the contract relevant to *this* bug (its route/
handler, the response shape, the event schema), using locate-then-read, not a full scan. Use it to
confirm or refute the finding. Never modify the other service's code; it's read-only, exactly like the
service under test. Then cache what you learned as a **service card** (template below) so you're asked
once, not on every future hunt. Also record the service's path in the resource registry
(`references/resource-memory.md`) so any *other* service's hunt can reuse it, not just this one.

## If you continue without it

Proceed, but any finding that depends on the unseen service is reported **Suspected**, never Confirmed,
with an explicit "unverified — needs <service>" line and what would confirm it. A cross-service bug you
couldn't see both sides of is a lead, not a verdict — reporting it as Confirmed would be exactly the
false positive this skill is built to avoid.

## The knowledge vault (folder-as-vault — no MCP needed)

Cards live as `<service>.md` under the knowledge dir: `$QA_KNOWLEDGE_DIR` if set, otherwise
`~/.qa-bug-hunter/knowledge/services/`. It's a plain folder of markdown, so you can open it directly in
Obsidian as a vault (graph, backlinks, search) with no MCP or plugin — Obsidian is just your viewer
over the same files. Reuse a card if it looks current; if the service has changed since the card's
`refreshed:` line, offer to refresh by re-pointing at the path. Cards are **hints to verify**, not
ground truth — keep the Confirmed/Suspected discipline; a stale card is a reason to re-check, not to
trust.

> If the optional read-only hook (`hooks/`) is enabled, it blocks writes outside `qa-bug-hunt/`, so
> card-caching is suppressed in that mode — the on-demand reading still works, it just won't persist a
> card. (The hook is off by default.)
>
> To let Claude search a large vault via Obsidian's own engine instead of the filesystem, add a
> filesystem-type Obsidian MCP, opt-in like the browser:
> `claude mcp add obsidian -- npx @bitbonsai/mcpvault@latest <vault-path>`

## Service card template

See `templates/service-card.md`. It captures the boundary-relevant facts — public surface, upstream
calls (with the assumptions made about them), downstream consumers, shared schemas, auth, invariants,
and known footguns — not the build/test trivia a repo's `CLAUDE.md` already covers. Seed it from the
service's `CLAUDE.md` if one exists, then fill the contract details from a targeted scan.
