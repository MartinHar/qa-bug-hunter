# Optional read-only enforcement (OFF by default)

This folder contains a hard read-only guard. **It is disabled by default and the plugin registers no
hook** — so QA Bug Hunter never blocks normal development, code-writing, or any other tool. The skill
is read-only on your code *by behavior* (it only writes repro tests under `qa-bug-hunt/`), and that
behavior only applies while you're actually running a bug hunt.

## Should you enable it?

Only if you run **dedicated bug-hunting-only sessions** and want a hard guarantee that nothing touches
your source. **Do not enable it for normal development:** a Claude Code hook is session-global, so once
active it blocks *every* file write outside `qa-bug-hunt/` for the whole session — including your own
feature/fix work — regardless of whether the bug-hunter skill is in use.

## Enable

Rename the registration file and reload:

```bash
mv hooks/hooks.json.disabled hooks/hooks.json
# then /reload-plugins (CLI) or restart Claude Code
```

`guard-readonly.py` denies any Write/Edit/MultiEdit/NotebookEdit outside `<cwd>/qa-bug-hunt/`. It
guards the file-editing tools, not arbitrary shell redirections — a strong guard, not a sandbox. It
needs `python3` on PATH.

## Disable again

```bash
mv hooks/hooks.json hooks/hooks.json.disabled
# then reload / restart
```
