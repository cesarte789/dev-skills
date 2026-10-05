#!/usr/bin/env bash
set -euo pipefail
export GIT_AUTHOR_NAME=eval GIT_AUTHOR_EMAIL=eval@example.com
export GIT_COMMITTER_NAME=eval GIT_COMMITTER_EMAIL=eval@example.com
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
