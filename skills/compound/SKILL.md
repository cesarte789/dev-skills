---
name: compound
description: >-
  Turn what review and CI caught into guards that stop it happening again: a
  lint rule, a test, or one line in the repo's CLAUDE.md, shipped as one PR in
  the current repo. Use after a PR is polished (pass its number), or as a
  periodic sweep over recently merged PRs ("recent", optionally with how many).
  Writes only to the repo it runs in.
---

# Compound

> Commands below use the `gh` CLI. If `gh` isn't available in this session, do
> the same operations with the GitHub MCP tools (`mcp__github__*`) instead.

Review fixes a defect once. This skill makes the repo refuse it from then on, so
each change leaves the next one cheaper.

## Boundary

This plugin is public and runs in private repos. Hold these without exception:

- Write only to the repository this session runs in. Never open issues, PRs or
  comments anywhere else, the repository that ships this plugin included, even
  when the session could.
- A lesson about one of this plugin's own skills is not fixed here. It goes in
  the report under **Plugin suggestions**, for a human to file, written so it
  could be published: no name, path, identifier, data or link from this repo.
  Describe the flaw in general terms, with a made-up minimal repro.

## Arguments

- `<PR>` — one PR; defaults to the current branch's. A caller that just
  polished it (`polish-pr`) also passes its findings digest.
- `recent [N]` — the last N merged PRs, default 20.

## 1. Collect lessons

A lesson is a defect that review, CI or a reviewer caught and a commit fixed.
Per PR, read:

- the findings digest, when the caller passed one;
- otherwise the commits after the first: each review round's commit says what
  it fixed (`gh pr view <N> --json commits`);
- failed check runs and what fixed them (`gh pr checks <N>`);
- review threads and PR comments
  (`gh api repos/{owner}/{repo}/pulls/<N>/comments`, `gh pr view <N> --comments`).

Keep a lesson only when it names a **class** of defect another change could
repeat ("a new endpoint without an auth check"), not an instance ("typo in this
label"). In `recent` mode, group lessons across PRs and rank classes by how many
PRs hit them; one that recurs outranks one seen once.

## 2. Pick a guard

Skip a lesson an existing lint rule, test or `CLAUDE.md` line already covers;
if that guard failed to stop it, the lesson is about the guard: fix that
instead. Otherwise take the most deterministic guard that fits:

1. **Lint rule or config** — fails the build, costs no reading.
2. **Test** — pins the behavior that broke, asserting public behavior.
3. **One line in `CLAUDE.md`** (or wherever the repo keeps its agent rules) —
   only when no check can express it. Every line is read by every session, so
   state the rule, not the story behind it.

A new lint rule that flags existing code follows the repo's convention for
existing violations (fix them, or baseline them if the repo keeps a baseline);
never ship it disabled.

Then prune: delete any `CLAUDE.md` line a new check now enforces.

## 3. Ship

All guards go in one PR, separate from the PR they came from:

```bash
git fetch origin --quiet && git checkout -b chore/compound-<slug> origin/main
# add the guards; prove each: it fails on the defect, passes on the fix
git push -u origin chore/compound-<slug>
gh pr create --draft --title "chore: guard against <classes>" --body "<lesson → guard, one line each>"
```

Run the checks `CLAUDE.md` requires before pushing. Open it as a draft for
`polish-pr`. No lesson worth a guard means no PR: say so.

## Report

- each lesson kept, and the guard it got or why it was skipped;
- the PR URL, or that there was nothing to guard;
- **Plugin suggestions**, when any, in the publishable form the Boundary
  section requires.
