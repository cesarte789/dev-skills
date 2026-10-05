#!/usr/bin/env bash
set -euo pipefail
export GIT_AUTHOR_NAME=eval GIT_AUTHOR_EMAIL=eval@example.com
export GIT_COMMITTER_NAME=eval GIT_COMMITTER_EMAIL=eval@example.com
# No user or system git config (signing, hooks, templates) and fixed dates: the commit
# SHAs come out the same on any machine, so the graders can pin HEAD and both branch tips.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
# Loose ref files, which the graders read; git versions without reftable ignore this.
export GIT_DEFAULT_REF_FORMAT=files
export GIT_AUTHOR_DATE="2026-01-01T00:00:00Z" GIT_COMMITTER_DATE="2026-01-01T00:00:00Z"
git init -q -b main
# A local bare repo stands in for origin: review-diff runs `git fetch origin main`.
echo origin.git >> .git/info/exclude
printf '# pager\n\nSmall list helpers.\n' > README.md
git add -A && git commit -qm "initial commit"
git init -q --bare origin.git && git remote add origin "$PWD/origin.git"
git push -q origin main
git checkout -qb feat/pagination
cat > pager.py <<'PY'
def page(items, page_number, page_size):
    """Return the items on page `page_number`, counting pages from 1."""
    start = page_number * page_size
    return items[start:start + page_size]
PY
git add pager.py && git commit -qm "feat: add a 1-based pagination helper"
