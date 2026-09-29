---
name: incorporate-pr-feedback
description: >-
  Apply reviewer feedback on a pull request: read the review comments, make the
  requested changes, reply to each thread, and push. Use when a PR has review
  comments to address. Pass the PR number (e.g. "42"); defaults to the PR for the
  current branch.
---

# Incorporate PR feedback

> Commands below use the `gh` CLI. If `gh` isn't available in this session, do
> the same operations with the GitHub MCP tools (`mcp__github__*`) instead.

Address the open review comments on a PR, then reply so the reviewer can see what
changed.

## 1. Find the PR and its comments

If no number is given, resolve the current branch's PR:

```bash
gh pr view --json number,title,headRefName
```

Fetch the review comments (inline + review summaries):

```bash
gh pr view <N> --json reviews,comments
gh api repos/{owner}/{repo}/pulls/<N>/comments   # inline review comments with path/line/id
```

Make sure your local checkout is on the PR's head branch and up to date before
editing.

## 2. Triage each comment

For every actionable comment, decide:
- **Apply** — make the change. Follow `CLAUDE.md` standards (tests for changed
  behavior, minimal diff, regenerate any generated files it names, etc.).
- **Discuss** — if you disagree or the request is ambiguous, don't silently skip
  it: reply asking for clarification or explaining the tradeoff.

Group related comments so you don't thrash the same file repeatedly. Re-run the
affected tests/build after your edits.

## 3. Commit and push

```bash
git add -A && git commit -m "<conventional message describing the fixes>"
git push
```

## 4. Reply to threads

Reply to each addressed inline comment so the reviewer has context (use the
comment id from the API list):

```bash
gh api repos/{owner}/{repo}/pulls/<N>/comments/<comment_id>/replies \
  -f body="Done — <what changed> (commit <sha>)."
```

Post a short summary comment on the PR listing what you addressed and anything you
pushed back on. Re-request review if appropriate:

```bash
gh pr comment <N> --body "<summary of changes made>"
```

Report which comments you resolved and which you left for the reviewer to weigh in
on.
