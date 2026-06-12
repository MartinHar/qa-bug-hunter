# Reproducing and running the repro

The repro is how a suspected bug becomes Confirmed. Stay generic: detect what the project already
uses and follow its conventions — never introduce a new test framework or runner.

## 1. Detect the toolchain

Before writing anything, identify the project's test framework and its build/run tool from the repo
itself: the dependency manifest and lockfile, the test/build configuration, the CI config, and the
existing test files. Mirror what's already there — the existing tests are the best guide to structure,
naming, assertions, and fixtures.

## 2. Write the smallest failing test

Write the minimal test that fails if and only if the bug exists, in the project framework's idioms. It
must **fail while the bug is present** so it doubles as a regression test once the code is fixed. Show
it to the user before running it, and capture its output verbatim — that output is the evidence.

## 3. Where the repro lives — decide by one property

The deciding question is **not the language name** but: *does a test in this project run as a
standalone file, or must it be compiled/built against the project first?*

- **Runs standalone** (the test file executes on its own): put the repro in `qa-bug-hunt/repros/` and
  run it by path. The source tree is never touched.

- **Must be built against the project** (the test compiles/runs through the project's build, so a
  loose file can't resolve the project's types or dependencies). While hunting, this skill stays
  **read-only on the source tree**, so the repro must stay contained — never added to the project's own
  source/test tree:
  1. **Contained test target** — create a throwaway test target *inside* `qa-bug-hunt/repros/` that
     references the project (a separate build unit pointing at the project's sources/output) and run
     that. Build output stays under `qa-bug-hunt/` and is gitignored; the source tree is never touched.
     For example, in .NET: a small xUnit project under `qa-bug-hunt/repros/` with a `<ProjectReference>`
     to the project, run with `dotnet test`.
  2. **Logic-only checks** — a language REPL (e.g. `jshell --class-path <build-output>`) or a tiny
     throwaway program run against the project's compiled output confirms the behavior with no test
     scaffolding and nothing in the source tree.
  3. **If neither is possible** (the build genuinely can't reference an external target, e.g. some
     Maven/Gradle setups), do **not** add a test to the project's `src/` — that's a source edit the
     skill won't make. Instead confirm via a standalone program against the compiled output, or leave
     the finding **Suspected** with the reason. Never modify the project's own test tree.

Run the repro by the most explicit means available (a specific file, target, or name filter) so it
neither depends on nor disturbs the project's normal test discovery.

## 4. When there's no test setup, or it can't be reproduced

Confirm with the smallest runnable program in the language and note in the report that confirmation was
via a standalone program, not the project's suite. If it can't be reproduced at all, the finding stays
**Suspected**, with the reason stated.

## Project-specific shortcuts (optional — extend as you like)

The steps above are framework-agnostic and need no per-language entries. If you want exact commands for
the stacks you hit most, add them here as shortcuts — they don't change the logic, they just save a
detection step:

```
# <stack>: standalone — write repro at <path>, run with <command>
# <stack>: builds-against-project — throwaway test unit in qa-bug-hunt/repros/ referencing <project>, run with <command>
```
