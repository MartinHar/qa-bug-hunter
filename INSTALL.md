# Install, use & update — QA Bug Hunter

How to add this plugin to Claude Code, use it, and move to (or cut) a new version. For what the plugin
*does* and its workflow, see [README.md](README.md).

---

## Add the plugin

### 1. From GitHub (recommended) — the way to install today

This repo is itself a Claude Code marketplace. In Claude Code, run:

```
/plugin marketplace add MartinHar/qa-bug-hunter
/plugin install qa-bug-hunter@qa-bug-hunter
```

`marketplace add` accepts the `owner/repo` GitHub shorthand (or the full
`https://github.com/MartinHar/qa-bug-hunter` URL). Verify with `/plugin` or `claude plugin list`. Get
updates later with `/plugin marketplace update`.

> The plugin isn't in Anthropic's `claude-community` marketplace yet, so adding this GitHub repo is how
> you install it right now.

### 2. Try it for a single session (no install)

```bash
git clone https://github.com/MartinHar/qa-bug-hunter
claude --plugin-dir ./qa-bug-hunter
```

Active only for that session — good for trialling a change before installing.

### 3. Personal skills dir (skill only, no marketplace)

Copy just the skill into your user skills directory:

```bash
git clone https://github.com/MartinHar/qa-bug-hunter
cp -r qa-bug-hunter/skills/qa-bug-hunter ~/.claude/skills/qa-bug-hunter
```

It loads next session as `qa-bug-hunter@skills-dir`. This installs the skill only — not the optional
read-only hook (which is off by default anyway).

### 4. Team (shared via a project repo)

Commit the skill into the target project at `.claude/skills/qa-bug-hunter/`. It loads for everyone who
opens the repo in Claude Code (after they accept the workspace-trust prompt). Launch Claude Code from
the repo root.

> After any manifest edit, validate before relying on it: `claude plugin validate ./` (run from the
> repo root). It should report **passed** with no warnings.

---

## Use it

Point Claude at a target and ask for a bug hunt — it only activates on explicit bug-hunting requests:

- "Find bugs in `src/services/auth.py` — focus on edge cases."
- "QA this PR diff and confirm anything you find with a test."
- "Find bugs in the whole repo." (runs the whole-codebase pipeline)

It asks one scope question (commit / branch / recent changes / whole codebase), reproduces each finding
with a test, and writes a report to `qa-bug-hunt/` at the project root. Full usage and the optional
browser/auth setup are in [README.md](README.md).

### Optional pieces (off by default)

- **Browser for UI bugs** — the skill writes a Playwright CLI test first and, when that isn't enough,
  pulls in the Playwright MCP **itself** (you don't enable it). The first time, it runs the setup and
  you do one `/reload-plugins` to connect it; after that it's automatic.
- **Hard read-only enforcement** — for dedicated hunt-only sessions, see [hooks/README.md](hooks/README.md).
- **Resource registry** — hand it a path to your data models / shared repos once and it remembers it
  across hunts (`~/.qa-bug-hunter/knowledge/`, or set `$QA_KNOWLEDGE_DIR`). See
  [resource-memory.md](skills/qa-bug-hunter/references/resource-memory.md).

---

## Update to a new version (consumer)

How you update depends on how you added it:

- **GitHub marketplace (method 1):** run `/plugin marketplace update` in Claude Code, then
  `/plugin install qa-bug-hunter@qa-bug-hunter` if it doesn't auto-update. Check the version with
  `claude plugin list`.
- **Single session (method 2):** `git pull` in your clone — each launch uses whatever is on disk.
- **Personal skills dir (method 3):** re-copy over the old one, then reload:
  ```bash
  git -C qa-bug-hunter pull && cp -r qa-bug-hunter/skills/qa-bug-hunter ~/.claude/skills/qa-bug-hunter
  ```
  Then `/reload-plugins` in Claude Code, or restart it.
- **Team repo (method 4):** pull the project's latest, then `/reload-plugins` or restart.

> SKILL.md edits take effect immediately in-session; changes to references, hooks, or manifests need
> `/reload-plugins`.

---

## Release a new version (maintainer)

Releases publish through GitHub: this repo is a live marketplace, so **pushing to `master` ships the
update** — consumers pick it up with `/plugin marketplace update`. Once the plugin is accepted into
Anthropic's `claude-community` marketplace, that pipeline re-runs validation + safety screening and
**auto-bumps the pinned commit on every push** (with a nightly catalog sync).

1. **Make the change on a branch:**
   ```bash
   git checkout -b my-change
   ```
2. **Bump the version in both manifests** (keep them in sync), using
   [semver](https://semver.org/) — patch for fixes, minor for new behavior, major for breaking changes:
   - `.claude-plugin/plugin.json` → `"version"`
   - `.claude-plugin/marketplace.json` → both the marketplace `metadata.version` and the plugin
     entry's `version`
3. **Validate:**
   ```bash
   claude plugin validate ./
   ```
4. **Sanity-check behavior** with the scenarios in [evals/](evals/README.md) (manual — they run in
   interactive Claude Code sessions).
5. **Merge to `master` and push** (the push is the release):
   ```bash
   git checkout master && git merge --no-ff my-change && git branch -d my-change && git push origin master
   ```

Design notes and implementation plans for past changes live under `docs/superpowers/`.


Created by **Martin Harutyunyan**.