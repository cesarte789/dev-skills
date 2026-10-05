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

# evals/ ships alongside the plugin but is never loaded at install time, and CI
# never runs the cases (they bill real sessions and need a sandbox), so a broken
# case.yaml would sit undetected until the next by-hand run. Shape-check them here
# — parse only, never run — the way the output-style frontmatter is checked above.
python3 - <<'PY'
import glob
import os
import sys

import yaml

# The grader types `claude plugin eval` accepts (from its own validation
# message: "type: (regex | tool_order | tool_used | file_exists | llm |
# baseline)"). Reject only a type the framework itself would reject, so a
# valid future case is never failed here; widen this if the CLI gains one.
GRADER_TYPES = {"regex", "tool_order", "tool_used", "file_exists", "llm", "baseline"}

failed = False
for path in sorted(glob.glob("evals/**/case.yaml", recursive=True)):
    case_dir = os.path.dirname(path)
    try:
        case = yaml.safe_load(open(path, encoding="utf-8"))
    except (OSError, UnicodeDecodeError, yaml.YAMLError) as e:
        print(f"error: {path}: failed to parse: {e}", file=sys.stderr)
        failed = True
        continue
    problems = []
    if not isinstance(case, dict):
        problems.append("is not a YAML mapping")
        case = {}
    if not isinstance(case.get("name"), str) or not case["name"].strip():
        problems.append("needs a non-empty 'name'")
    # A prompt may live inline or in a sibling prompt.md — the framework accepts
    # either ("execution.prompt is required: a prompt.md body, or execution.prompt
    # in case.yaml"), so requiring the inline form would fail a valid split case.
    execution = case.get("execution")
    prompt = execution.get("prompt") if isinstance(execution, dict) else None
    if not (isinstance(prompt, str) and prompt.strip()) \
            and not os.path.isfile(os.path.join(case_dir, "prompt.md")):
        problems.append("needs execution.prompt or a sibling prompt.md")
    # Likewise graders may be an inline list or a sibling graders/*.md directory.
    graders = case.get("graders")
    inline = graders if isinstance(graders, list) else []
    graders_dir = os.path.join(case_dir, "graders")
    has_graders_dir = os.path.isdir(graders_dir) and any(
        name.endswith(".md") for name in os.listdir(graders_dir))
    if not inline and not has_graders_dir:
        problems.append("needs a non-empty 'graders' list or sibling graders/*.md files")
    for i, grader in enumerate(inline):
        where = f"graders[{i}]"
        if not isinstance(grader, dict):
            problems.append(f"{where} is not a mapping")
            continue
        if not isinstance(grader.get("name"), str) or not grader["name"].strip():
            problems.append(f"{where} needs a non-empty 'name'")
        gtype = grader.get("type")
        if gtype not in GRADER_TYPES:
            problems.append(f"{where} has type {gtype!r}, not one of {sorted(GRADER_TYPES)}")
    context = case.get("context")
    if isinstance(context, dict) and "scaffold_script" in context:
        script = context["scaffold_script"]
        if not isinstance(script, str) or not script.strip():
            problems.append("context.scaffold_script is empty")
        elif not os.path.isfile(os.path.join(case_dir, script)):
            problems.append(f"context.scaffold_script '{script}' names no existing file")
    for problem in problems:
        print(f"error: {path}: {problem}", file=sys.stderr)
    failed = failed or bool(problems)
    if not problems:
        print(f"{path}: case ok")
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
