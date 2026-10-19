#!/usr/bin/env bash
# The pre-push checks for this plugin. CI runs this same script
# (.github/workflows/validate.yml), so a green local run means a green check.
#
# Usage: scripts/check.sh [<base-ref>]
#   With a base ref (e.g. origin/main), also require a higher plugin.json
#   version when what the plugin ships changed since the branch left it.
set -euo pipefail
cd "$(dirname "$0")/.."

# Skills learn from private repos, and a lesson copied back here could leak their
# names or data. The term list lives outside the repo so it never leaks either;
# CI has none, so there this step is skipped. A push publishes commits, not the
# working tree, so every commit since <base-ref> (or HEAD alone) is scanned too:
# its files, paths, message, author and committer, plus the branch name.
private_terms="${DEV_SKILLS_PRIVATE_TERMS:-$HOME/.config/dev-skills/private-terms}"
if [ -n "${DEV_SKILLS_PRIVATE_TERMS:-}" ] && [ ! -f "$private_terms" ]; then
  echo "error: DEV_SKILLS_PRIVATE_TERMS names no file: $private_terms" >&2
  exit 1
fi
found_terms() {
  local status=0
  "$@" || status=$?
  if [ "$status" -gt 1 ]; then
    echo "error: $1 failed searching for private terms" >&2
    exit 1
  fi
  [ "$status" -eq 0 ]
}
if [ -f "$private_terms" ]; then
  terms="$(sed -e 's/\r$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$private_terms")"
  term_args=()
  while IFS= read -r term; do
    [ -n "$term" ] && term_args+=(-e "$term")
  done <<<"$terms"
  if [ "${#term_args[@]}" -gt 0 ]; then
    revs=(HEAD)
    if [ -n "${1:-}" ] && git rev-parse --verify --quiet "$1^{commit}" >/dev/null; then
      revs=()
      while IFS= read -r rev; do revs+=("$rev"); done < <(git rev-list "$1..HEAD")
    fi
    paths_and_messages="$(
      git -c core.quotePath=false ls-files --cached --others --exclude-standard | sed 's|^|path: |'
      git rev-parse --abbrev-ref HEAD | sed 's|^|branch: |'
      for rev in ${revs[@]+"${revs[@]}"}; do
        git -c core.quotePath=false ls-tree -r --name-only "$rev" | sed "s|^|$rev path: |"
        git log -1 --format='%B%n%an <%ae>%n%cn <%ce>' "$rev" | sed "s|^|$rev message: |"
      done
    )"
    leaked=0
    found_terms git grep -n -i -F "${term_args[@]}" --untracked && leaked=1
    [ "${#revs[@]}" -gt 0 ] && found_terms git grep -n -i -F "${term_args[@]}" "${revs[@]}" && leaked=1
    found_terms grep -i -F "${term_args[@]}" <<<"$paths_and_messages" && leaked=1
    if [ "$leaked" -eq 1 ]; then
      echo "error: the lines above contain a term from $private_terms" >&2
      exit 1
    fi
    echo "no private terms found"
  fi
fi

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

# Each skill loads on its own, so the repo-conventions rule is inlined in every
# skill that uses it rather than shared from one file. Keep the copies identical,
# and present wherever a skill relies on the term.
python3 - <<'PY'
import glob
import re
import sys

BLOCK = re.compile(r"<!-- repo-conventions -->\n.*?\n<!-- /repo-conventions -->", re.S)

failed = False
blocks = {}
for path in sorted(glob.glob("skills/*/SKILL.md")):
    text = open(path, encoding="utf-8").read()
    found = BLOCK.findall(text)
    opens, closes = text.count("<!-- repo-conventions -->"), text.count("<!-- /repo-conventions -->")
    if len(found) > 1 or opens != len(found) or closes != len(found):
        print(f"error: {path}: needs exactly one balanced repo-conventions block", file=sys.stderr)
        failed = True
    elif found:
        blocks[path] = found[0]
    elif re.search(r"repo\s+conventions", text, re.I):
        print(f"error: {path}: says 'repo conventions' but carries no repo-conventions block", file=sys.stderr)
        failed = True
if len(set(blocks.values())) > 1:
    first = next(iter(blocks))
    for path, block in blocks.items():
        if block != blocks[first]:
            print(f"error: {path}: repo-conventions block differs from {first}'s; copy it word for word", file=sys.stderr)
    failed = True
if not failed:
    print(f"repo-conventions block identical in {len(blocks)} skills")
sys.exit(1 if failed else 0)
PY

# A skill with an Operations section promises that a port, or a dev-skills-ops
# override, needs to replace that section alone, so no gh or git command may
# appear outside it. Skills without the section are not checked yet.
python3 - <<'PY'
import glob
import re
import sys

COMMAND = re.compile(r"(?:^|[`\s(])(gh|git) [a-z][a-z-]*", re.M)

failed = False
checked = 0
for path in sorted(glob.glob("skills/*/SKILL.md")):
    lines = open(path, encoding="utf-8").read().split("\n")
    start = next((i for i, line in enumerate(lines) if line.startswith("## Operations")), None)
    if start is None:
        continue
    checked += 1
    end = next((i for i in range(start + 1, len(lines)) if lines[i].startswith("## ")), len(lines))
    for i, line in enumerate(lines):
        if start <= i < end:
            continue
        match = COMMAND.search(line)
        if match:
            print(f"error: {path}:{i + 1}: `{match.group(1)}` command outside the Operations section; "
                  "move it there and refer to it by name", file=sys.stderr)
            failed = True
if not failed:
    print(f"no gh or git commands outside the Operations section in {checked} skills")
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
