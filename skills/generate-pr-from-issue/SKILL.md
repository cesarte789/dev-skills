---
name: generate-pr-from-issue
description: >-
  Turn a GitHub issue into a complete, tested pull request. Use when the user
  wants an issue implemented end-to-end: read issue N, branch, implement with
  tests, and open a PR that closes it. Pass the issue number (e.g. "42").
---

# Generate PR from issue

> Commands below use the `gh` CLI. If `gh` isn't available in this session, do
> the same operations with the GitHub MCP tools (`mcp__github__*`) instead.

Implement a GitHub issue and open a merge-ready PR. One PR, one idea: solve the
issue with the minimal set of changes.

## 1. Read the issue and plan

```bash
gh issue view <N> --json number,title,body,labels
```

Understand the request. Study the existing code and patterns in the affected area
so your change feels native to the codebase. Form a step-by-step plan that names
the files to create/modify **and how you will test it**. If the issue is too vague
or out of scope to implement responsibly, comment on it asking for clarification
and stop — do not guess.

## 2. Branch

Branch off `main` (never commit to `main`). Name it for the work, e.g.
`feat/<short-slug>` or `fix/<short-slug>`:

```bash
git fetch origin --quiet && git checkout -b <branch> origin/main
```

## 3. Implement

Follow `CLAUDE.md` exactly — it is the source of standards for this repo. In
particular:
- Write all code in English.
- Work test-first wherever `CLAUDE.md` calls for tests.
- Handle errors explicitly at boundaries.
- Keep the diff minimal and focused; match surrounding style.
- If the change touches anything `CLAUDE.md` says must be regenerated or kept in
  sync (generated types or clients, schema snapshots, lockfiles), do it in the
  same change with the repo's own tooling.
- Update `README.md` if user-facing behavior or setup changes, and any feature docs
  the repo keeps (e.g. `docs/features.md`) with it.

Run the relevant tests/build and make them pass before opening the PR.

## 4. Open the PR

Commit with a conventional-commit message, push, and open the PR linking the issue
so it auto-closes on merge:

```bash
git push -u origin <branch>
gh pr create --title "<conventional title>" --body "<summary>

Closes #<N>"
```

Opening the PR kicks off its CI run immediately. Do **not** wait for it here —
report the PR URL right away and let the checks run in the background; the
downstream stages (`polish-pr`, merge) read their status while they work and
verify green before any merge. If you have a spare moment before reporting, a
quick `gh pr checks <N>` snapshot is welcome, but never sit in a long watch.

End commit messages with the Co-Authored-By trailer used in this repo. Report the
PR URL and a short summary of what you changed and how it's tested. If, after
analysis, no code change is warranted, comment that on the issue and open no PR.
