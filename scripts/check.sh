#!/usr/bin/env bash
# The pre-push checks for this plugin. CI runs this same script
# (.github/workflows/validate.yml), so a green local run means a green check.
#
# Usage: scripts/check.sh [<base-ref>]
#   With a base ref (e.g. origin/main), also require a plugin.json version bump
#   when skills/ or output-styles/ changed since the branch left it.
set -euo pipefail
cd "$(dirname "$0")/.."

# Both are needed: on the repo root, validate checks only marketplace.json;
# validating plugin.json is what parses each skill's SKILL.md frontmatter.
claude plugin validate . --strict
claude plugin validate .claude-plugin/plugin.json --strict

# validate never parses output-style frontmatter, and a broken one loads silently.
python3 - <<'PY'
import glob
import sys

import yaml

failed = False
for path in sorted(glob.glob("output-styles/*.md")):
    text = open(path, encoding="utf-8").read()
    head, sep, _ = text.partition("\n---\n")
    if not text.startswith("---\n") or not sep:
        print(f"error: {path}: no '---' frontmatter block at the top", file=sys.stderr)
        failed = True
        continue
    try:
        meta = yaml.safe_load(head[len("---\n"):])
    except yaml.YAMLError as e:
        print(f"error: {path}: frontmatter failed to parse: {e}", file=sys.stderr)
        failed = True
        continue
    missing = [k for k in ("name", "description")
               if not isinstance(meta, dict) or not isinstance(meta.get(k), str) or not meta[k].strip()]
    for key in missing:
        print(f"error: {path}: frontmatter needs a non-empty '{key}'", file=sys.stderr)
    failed = failed or bool(missing)
    if not missing:
        print(f"{path}: frontmatter ok")
sys.exit(1 if failed else 0)
PY

base="${1:-}"
[ -z "$base" ] && exit 0

# Claude Code compares plugin.json's version, not the git commit, so a change to
# what the plugin ships without a bump never reaches existing installs.
fork_point="$(git merge-base "$base" HEAD)"
if git diff --quiet "$fork_point" HEAD -- skills output-styles; then
  echo "skills/ and output-styles/ unchanged since $base: no version bump needed."
  exit 0
fi
version_at() { python3 -c 'import json, sys; print(json.load(sys.stdin)["version"])'; }
old="$(git show "$fork_point:.claude-plugin/plugin.json" | version_at)"
new="$(version_at < .claude-plugin/plugin.json)"
if [ "$old" = "$new" ]; then
  echo "error: skills/ or output-styles/ changed but .claude-plugin/plugin.json version is still $old." >&2
  echo "Bump it: Claude Code compares that field, so an unbumped change never reaches existing installs." >&2
  exit 1
fi
echo "plugin.json version bumped: $old -> $new"
