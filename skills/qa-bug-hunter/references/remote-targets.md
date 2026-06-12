# Hunting a remote repo (clone, then hunt)

A target doesn't have to be local. The user can point the hunt at a **repo URL** — GitHub, GitLab,
Azure DevOps, Bitbucket, or any git remote — and the plugin clones it locally and hunts the clone
exactly like a local repo.

## Recognize a remote target

Treat the target as remote (not a local path) when it looks like a git URL:

- HTTPS: `https://github.com/owner/repo`, `https://gitlab.com/group/sub/repo`,
  `https://dev.azure.com/org/project/_git/repo`, `https://bitbucket.org/owner/repo`, any `…/repo.git`.
- SSH: `git@github.com:owner/repo.git`, `git@gitlab.com:group/repo.git`, etc.
- A web URL that points at a branch/commit/subpath: GitHub `…/tree/<branch>` or `…/blob/<branch>/…`,
  GitLab `…/-/tree/<branch>`, Azure `…?version=GB<branch>`. Keep the ref it encodes for checkout.

If it's a local filesystem path, this file doesn't apply — hunt it directly.

## Where to clone (ask the user)

Clone into a **folder the user names** — ask where to put it. If they don't care, propose a sensible
default and state it (e.g. `./<repo-name>` in the current directory), then proceed. Don't clone into
the user's existing project root where it would nest confusingly. Whatever folder is used, the run's
`qa-bug-hunt/` working folder is created at the **clone's** root (and self-ignores as always).

## Clone it

1. **Normalize the URL.** From a web URL, derive the clone URL (drop `/tree/<branch>`, `/blob/<…>`,
   `/-/tree/<branch>`, query strings) and remember any branch/commit it encoded.
2. **Clone:** `git clone <clone-url> <dest>`. Use a normal clone (not `--depth 1`) so commit / branch /
   recent-changes scopes resolve against real history; deepen later (`git fetch --deepen N` /
   `--unshallow`) only if a chosen scope needs more.
3. **Checkout the ref** if one was specified (in the URL or by the user): `git -C <dest> checkout <ref>`.
4. Briefly tell the user what you cloned and to where.

## Auth for private repos

Rely on the user's **existing** git credentials — `gh` auth, SSH keys, a credential helper, or git
config. **Never ask the user to paste a token, and never embed a token in the clone URL** (it's a
secret and would land on disk and in shell history). If the clone fails with an auth error, say so and
offer the standard fixes, then retry:

- `gh auth login` (GitHub), or the host's CLI/login;
- use the **SSH** URL instead of HTTPS (if they have keys set up);
- configure a git credential helper.

Azure DevOps and some GitLab setups need a PAT configured in the credential helper / git config — point
the user to set that up on their machine, don't handle the token yourself.

## Then hunt normally

Treat the clone as the target repo and run the standard flow — scope resolution
(`scope-and-tokens.md`), the phases in `SKILL.md`, and the repo's own tests, just like a local hunt.

**Read-only still holds:** never `git push`, never open a PR, never modify the cloned code outside its
`qa-bug-hunt/` folder. The clone is third-party code and running its tests executes its code (same as
any local repo you didn't write), so the usual guardrails apply: verify against local/staging not
production, and confirm before anything that changes data or hits a shared environment.

## Cleanup & warm re-hunts

The clone stays in the folder the user named — it's theirs to keep or delete (mention they can remove
it). The knowledge base keys a target's card by a **stable id that includes the remote URL** (see
`knowledge-base.md`), so a repeat hunt on the same remote starts **warm**: re-`git fetch` and diff
against the last-hunted commit instead of re-reading, even if it's re-cloned to a different folder. A
whole-codebase remote hunt follows `whole-codebase-hunt.md` as usual.
