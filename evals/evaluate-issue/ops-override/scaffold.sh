#!/usr/bin/env bash
set -euo pipefail
# An offline repo with no forge: a project skill named dev-skills-ops replaces
# every operation evaluate-issue uses with local files, so the run can only
# succeed through the override, and the case grants no Bash to reach gh at all.
mkdir -p .claude/skills/dev-skills-ops issues
cat > .claude/skills/dev-skills-ops/SKILL.md <<'MD'
---
name: dev-skills-ops
description: >-
  Operation overrides for the dev-skills plugin in this repo, which has no
  issue tracker online. dev-skills skills load it and use these entries by name.
---

# dev-skills operations (local files)

- **read the issue** — read `issue.md`; the issue number is ignored.
- **search issues** — search the files under `issues/` for the key terms.
- **comment on the issue** — write the comment body to `verdict.md`.
MD
cat > issue.md <<'MD'
# Add a --json flag to `todo.py list`

`todo.py list` prints one task per line. Add `--json` so scripts can read the
list as a JSON array of `{"id", "title", "done"}` objects.
MD
cat > issues/0-sort-by-date.md <<'MD'
# Sort `todo.py list` by due date (closed: tasks have no due date)
MD
cat > todo.py <<'PY'
import sys

TASKS = [{"id": 1, "title": "write tests", "done": False}]


def main(argv):
    if argv[:1] == ["list"]:
        for task in TASKS:
            print(f"{task['id']} {'x' if task['done'] else ' '} {task['title']}")


if __name__ == "__main__":
    main(sys.argv[1:])
PY
