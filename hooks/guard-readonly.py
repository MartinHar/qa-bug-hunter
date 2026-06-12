#!/usr/bin/env python3
"""Read-only-on-source guard for QA Bug Hunter (OPTIONAL — disabled by default).

This hook is NOT registered by default: the plugin ships `hooks/hooks.json.disabled`, so QA Bug Hunter
never blocks normal development. The skill is read-only on your code by behavior (it only writes repro
tests under `qa-bug-hunt/`), active only while a hunt is running. Enable this hook only for dedicated
bug-hunting sessions where you want a hard guarantee — see hooks/README.md (it blocks ALL writes outside
qa-bug-hunt/ session-wide while active).

When enabled, any Write/Edit/MultiEdit/NotebookEdit whose target is outside the run's `qa-bug-hunt/`
folder is denied. Repro tests and run artifacts (which live under qa-bug-hunt/) are allowed.

Limitation: this guards the file-editing tools, not arbitrary shell redirections. A strong guard, not
a sandbox.
"""
import sys
import json
import os


def main() -> int:
    try:
        data = json.load(sys.stdin)
    except Exception:
        # Can't parse the event — don't block (fail open).
        return 0

    tool_input = data.get("tool_input") or {}
    cwd = data.get("cwd") or os.getcwd()

    # Paths this tool would write to.
    candidates = []
    for key in ("file_path", "notebook_path"):
        val = tool_input.get(key)
        if isinstance(val, str) and val:
            candidates.append(val)

    if not candidates:
        return 0  # nothing path-like to check

    allowed_root = os.path.realpath(os.path.join(cwd, "qa-bug-hunt"))

    def inside(p: str) -> bool:
        ap = os.path.realpath(p if os.path.isabs(p) else os.path.join(cwd, p))
        return ap == allowed_root or ap.startswith(allowed_root + os.sep)

    blocked = [p for p in candidates if not inside(p)]
    if blocked:
        reason = (
            "QA Bug Hunter is read-only on the codebase: it finds, reproduces, and reports bugs — it "
            "does not modify code. The only writable location is qa-bug-hunt/. Blocked write to: "
            + ", ".join(blocked)
            + ". Put repro tests in qa-bug-hunt/repros/ instead."
        )
        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": reason,
            }
        }))
        return 0  # JSON is read only on exit 0

    return 0  # allowed


if __name__ == "__main__":
    sys.exit(main())
