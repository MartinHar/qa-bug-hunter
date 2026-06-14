#!/usr/bin/env bash
# evals/check-structure.sh — FREE structural checks for the plugin. No API tokens, no model calls.
#
# Safe to run on every PR/push. Verifies the things that, if wrong, ship a broken release:
#   - plugin.json / marketplace.json version parity,
#   - every references/*.md that SKILL.md links to actually exists,
#   - every eval scenario is fully wired (prompt+check OR scenario.sh, plus a non-empty fixture).
#
# This is the cheap always-on safety net; the token-costing behavioral evals (evals/run.sh) run
# separately, only on release or manual dispatch.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$ROOT/skills/qa-bug-hunter/SKILL.md"
REFDIR="$ROOT/skills/qa-bug-hunter/references"
fail=0
ok()  { printf '  \033[32m✓\033[0m %s\n' "$*"; }
bad() { printf '  \033[31m✗\033[0m %s\n' "$*"; fail=1; }

echo "▶ manifest version parity"
pv="$(grep -oE '"version"[[:space:]]*:[[:space:]]*"[^"]+"' "$ROOT/.claude-plugin/plugin.json" | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
if [ -z "$pv" ]; then bad "could not read version from plugin.json"; fi
# marketplace.json carries the version twice (metadata + the plugin entry); both should match plugin.json.
while IFS= read -r mv; do
  if [ "$mv" = "$pv" ]; then ok "marketplace.json version $mv == plugin.json $pv"
  else bad "version mismatch: marketplace.json $mv != plugin.json $pv"; fi
done < <(grep -oE '"version"[[:space:]]*:[[:space:]]*"[^"]+"' "$ROOT/.claude-plugin/marketplace.json" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')

echo "▶ SKILL.md reference links resolve"
# Every references/<name>.md mentioned in SKILL.md must exist on disk.
nrefs=0
while IFS= read -r r; do
  nrefs=$((nrefs + 1))
  if [ -f "$ROOT/skills/qa-bug-hunter/$r" ]; then ok "$r"; else bad "$r referenced by SKILL.md but missing"; fi
done < <(grep -oE 'references/[A-Za-z0-9_-]+\.md' "$SKILL" | sort -u)
[ "$nrefs" -gt 0 ] || bad "SKILL.md links no references — unexpected"

echo "▶ every reference file is linked from SKILL.md (no orphans)"
for f in "$REFDIR"/*.md; do
  base="references/$(basename "$f")"
  if grep -qF "$base" "$SKILL"; then ok "$(basename "$f") linked"; else bad "$(basename "$f") is an orphan (not linked from SKILL.md)"; fi
done

echo "▶ eval scenarios are fully wired"
for dir in "$ROOT"/evals/[0-9]*/; do
  name="$(basename "$dir")"
  [ -f "$dir/SCENARIO.md" ] || bad "$name: missing SCENARIO.md"
  if [ -f "$dir/scenario.sh" ]; then
    ok "$name: custom driver (scenario.sh)"
  elif [ -f "$dir/prompt.txt" ] && [ -f "$dir/check.sh" ]; then
    ok "$name: standard (prompt.txt + check.sh)"
  else
    bad "$name: needs either scenario.sh, or both prompt.txt and check.sh"
  fi
  if [ -d "$dir/fixture" ] && [ -n "$(find "$dir/fixture" -type f 2>/dev/null | head -1)" ]; then
    ok "$name: fixture is non-empty"
  else
    bad "$name: fixture/ is missing or empty"
  fi
done

echo
if [ "$fail" -eq 0 ]; then echo "================  structural checks passed  ================"; else echo "================  structural checks FAILED  ================"; fi
exit "$fail"
