---
service: <name>
purpose: <one line — what it does>
repo: <path or url>
refreshed: <YYYY-MM-DD> (commit <sha>)
---
# <name>

**Owns:** <data / responsibilities this service owns>

## Public surface (what others rely on)
- <HTTP endpoints / events published / messages consumed — the contracts, with shapes>

## Calls (upstream dependencies)
- [[<service>]] — <how: REST / gRPC / queue>, <when>, <key assumption, e.g. "must be idempotent">

## Called by (downstream consumers)
- [[<service>]], [[<service>]]

## Shared contracts / schemas
- <shared types / enums and where they're defined and versioned>

## Auth
- <how callers authenticate to it; how it authenticates to its own dependencies>

## Invariants & cross-service assumptions
- <invariants enforced here, and assumptions made about other services>

## Known footguns / past incidents
- <YYYY-MM: what bit us at this boundary>

---

## Hunt profile (maintained by QA Bug Hunter — see references/knowledge-base.md)
last hunted: <YYYY-MM-DD> · commit <sha or n/a>
fingerprints: deps-lock <hash> · hotspots <file:size-or-mtime, ...>   # git-independent freshness check

### Toolchain
- tests: <framework> — run with `<command>`
- build/run: `<command>`   ·   lint / type-check: `<command>`

### Map & risk hotspots
- <structure / entry points / where code and tests live>
- highest-risk areas (hunt first): <list>

### Known issues (findings ledger)
- [open] [High] <title> — fp: <file · symbol · root-cause> — repro: qa-bug-hunt/repros/<file> — found <YYYY-MM-DD>
- [fixed] [Medium] <title> — fp: <file · symbol · root-cause> — found <YYYY-MM-DD>, verified fixed <YYYY-MM-DD>
- [regressed] [High] <title> — fp: <file · symbol · root-cause> — repro: qa-bug-hunt/repros/<file> — fixed <YYYY-MM-DD>, regressed <YYYY-MM-DD>
