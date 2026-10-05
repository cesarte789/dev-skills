---
name: generate-pr-from-issue
description: >-
  Turn a GitHub issue into a complete, tested pull request. Use when the user
  wants an issue implemented end-to-end: read issue N, branch, implement with
  tests, and open a draft PR that closes it. Pass the issue number (e.g. "42").
---

# Generate PR from issue

> Commands below use the `gh` CLI. If `gh` isn't available in this session, do
> the same operations with the GitHub MCP tools (`mcp__github__*`) instead.

Implement a GitHub issue and open a draft PR for `polish-pr` to bring to
merge-ready. One PR, one idea: solve the issue with the minimal set of changes.

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
- Keep the docs matching the code and the README to its core: what the project
  is, how to install, set up and use it, one line per feature if it keeps a
  feature list, and where the detail lives. Touch the README only when install,
  setup or the commands change, or to add, rename or remove the one-line entry of
  a feature the change adds, renames or removes. Describe the feature itself in
  the feature docs the repo keeps (e.g. `docs/features.md`), and delete what they
  say about removed code.

Run the relevant tests/build and make them pass before opening the PR.

## 4. Open the PR

Commit with a conventional-commit message, push, and open the PR as a **draft**,
linking the issue so it auto-closes on merge:

```bash
git push -u origin <branch>
gh pr create --draft --title "<conventional title>" --body "<summary>

Closes #<N>"
```

A draft because review rounds push often and CI only has to pass on the result:
`polish-pr` marks the PR ready once its review is clean, and a repo whose CI
skips drafts runs it once there instead of on every round. Do **not** wait for
CI here — report the PR URL right away, and that it is a draft: run `polish-pr`
on it (or `gh pr ready <N>`) before it can merge.

End commit messages with the Co-Authored-By trailer used in this repo. Report the
PR URL and a short summary of what you changed and how it's tested. If, after
analysis, no code change is warranted, comment that on the issue and open no PR.
