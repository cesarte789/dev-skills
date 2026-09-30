#!/usr/bin/env bash
# The pre-push checks for this plugin. CI runs this same script
# (.github/workflows/validate.yml), so a green local run means a green check.
#
# Usage: scripts/check.sh [<base-ref>]
#   With a base ref (e.g. origin/main), also require a higher plugin.json
#   version when what the plugin ships changed since the branch left it.
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
    lines = open(path, encoding="utf-8-sig").read().splitlines()
    closing = next((i for i, line in enumerate(lines[1:], 1) if line.strip() == "---"), None)
    if not lines or lines[0].strip() != "---" or closing is None:
        print(f"error: {path}: no '---' frontmatter block at the top", file=sys.stderr)
        failed = True
        continue
    try:
        meta = yaml.safe_load("\n".join(lines[1:closing]))
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
if ! git rev-parse --verify --quiet "$base^{commit}" >/dev/null; then
  echo "error: base ref '$base' not found. Fetch it first (git fetch origin main)." >&2
  exit 1
fi

# Claude Code compares plugin.json's version, not the git commit, so a change to
# what the plugin ships without a higher version never reaches existing installs.
# Both sides come from commits, so uncommitted work can't pass here and fail in CI.
# What changed is measured from the fork point; the version to beat is the base
# tip's, which is what CI's merge checkout sees once the base has moved on.
shipped=(skills output-styles .claude-plugin/plugin.json)
fork_point="$(git merge-base "$base" HEAD)"
if git diff --quiet "$fork_point" HEAD -- "${shipped[@]}"; then
  echo "${shipped[*]} unchanged since $base: no version bump needed."
  exit 0
fi
python3 - "$base" <<'PY'
import json
import subprocess
import sys

def version(commit):
    manifest = subprocess.run(["git", "show", f"{commit}:.claude-plugin/plugin.json"],
                              capture_output=True, text=True, check=True).stdout
    raw = json.loads(manifest)["version"]
    try:
        return raw, tuple(int(part) for part in raw.split("."))
    except ValueError:
        sys.exit(f"error: plugin.json version '{raw}' is not dotted numbers")

(old, old_key), (new, new_key) = version(sys.argv[1]), version("HEAD")
if new_key <= old_key:
    sys.exit(f"error: what the plugin ships changed but .claude-plugin/plugin.json version went {old} -> {new}.\n"
             "Raise it: Claude Code compares that field, so a change without a higher version never reaches existing installs.")
print(f"plugin.json version bumped: {old} -> {new}")
PY
