---
name: resolve-issues
description: >-
  Work through the repository's open-issue backlog: list the issues that are open
  right now and hand them one at a time to the resolve-issue skill (vet -> PR ->
  polish -> merge, or close with a verdict), oldest first, until every one is
  resolved or a cap is reached. Use when you want the existing backlog cleared
  autonomously rather than resolving a single issue by number. Optionally pass a
  max number of issues to resolve (e.g. "3"), default 5. NOTE: merges to main and
  closes issues without human vetting — use only where that is acceptable.
---

# Resolve open issues

> Commands below use the `gh` CLI. If `gh` isn't available in this session, do
> the same operations with the GitHub MCP tools (`mcp__github__*`) instead.

> The other skills named here ship in the same `dev-skills` plugin. Invoke them
> with the Skill tool by the name the session lists, `dev-skills:<name>` (e.g.
> `dev-skills:polish-pr`), or the bare name where the skills are installed
> unprefixed.

Sweep the backlog. Take the issues that are open **now**, and give each one to
`resolve-issue`, which reaches a definitive outcome for it — a merged PR, or the
issue closed with a written verdict. One issue at a time, oldest first.

> ⚠️ This runs unattended and both **merges to `main`** and **closes issues** on
> its own. No human vets each issue or reviews each PR before it lands. Use it
> only where that is acceptable (low-stakes work, or a `main` protected by
> required CI).

## Which one to use

- **This skill** — clears the backlog that is already there, whoever filed it and
  whenever.
- **`resolve-issue`** — one issue you name. This skill is that skill in a loop;
  everything about vetting, merging and rejecting lives there.

## Arguments

`[<max-issues>]` — optional leading integer, the hard cap on how many issues this
sweep resolves. Default **5**. This is the safety stop on a sweep that merges to
`main` on its own; never run it unbounded.

## 1. Sync

Make sure local `main` is current, so every issue is vetted — and every fix
branches off — the landed state:

```bash
git checkout main && git pull --ff-only
```

## 2. Collect the backlog

Snapshot the open issues once, at the start:

```bash
gh issue list --state open --limit 100 --json number,title,url,createdAt,labels,assignees
```

The snapshot is the work list for the whole run: issues filed *while* the sweep
is running belong to the next one, not this one. The list comes back newest
first, so raise `--limit` if the repo has more open issues than that — a limit
that truncates drops the oldest, which are exactly the ones the sweep starts
with. `gh issue list` already excludes
pull requests, so everything it returns is a candidate — minus these, which you
skip and name in the report:

- **Epics / tracking issues** — an issue whose body is a checklist of sub-issues
  holds no code change of its own. Its sub-tasks are in the list on their own
  merit; resolve those instead.
- **Someone else's work in progress** — assigned to a person, or with an open PR
  already set to close it (`gh pr list --state open --search "closes #<N> in:body"`).
  Resolving it underneath them wastes both efforts.
- **Explicitly held** — labelled to say so (`blocked`, `on-hold`, `wontfix`,
  `needs-discussion` or the repo's equivalent).

Order what is left **oldest first** (ascending number). That is the candidate
list; stage 3 works down it and stops at `<max-issues>` **resolved** issues, so
list every candidate rather than pre-cutting to the cap — an issue that turns out
to be already closed shouldn't cost the run a slot. If nothing survives the
filters, that is a clean result rather than a failure: **stop** and report that
the backlog is clear.

## 3. Resolve each, one at a time

Walk the candidate list in order until it is exhausted or `<max-issues>` issues
have reached an outcome, whichever comes first. Only an issue `resolve-issue`
actually finished — merged or rejected — counts against the cap; a skip costs
nothing, because the cap is there to bound unattended merges. Report the
candidates you never reached — the sweep is rerunnable and picks them up next
time. For each:

1. **Confirm it is still open.** An earlier resolution in this same run may have
   closed it — one PR can close several issues, and a rejection can close a
   duplicate:

   ```bash
   gh issue view <N> --json state --jq .state
   ```

   If it is no longer `OPEN`, skip it and move on.

2. **Run the `resolve-issue` skill** on its number. It vets the issue against the
   code and then either implements, polishes and merges a PR, or closes the issue
   with a verdict comment.

3. **Sync `main` again** (stage 1) before the next issue, so its vetting sees
   whatever just landed.

Sequential, never in parallel: each resolution merges to `main`, and the next
issue has to be vetted against that updated `main`. That is also what makes
overlapping issues safe — a request an earlier merge already satisfied is
rejected by `resolve-issue` as already handled, instead of being built twice.

Per issue, `resolve-issue` ends in one of these, and the sweep reacts:

- **Merged** — the change landed. Continue to the next issue.
- **Rejected and closed** — the issue didn't hold up against the code, or its
  evaluation declined it as not worth its permanent cost. That is a completed
  outcome too: continue. It still is when the comment-only PR recording the
  decision could not merge (e.g. no CI checks): that PR changes only comments,
  so nothing later builds on it. List it in the report as left open.
- **PR left open** (polish stopped without a clean result, e.g. its cap, a
  steering abort, or a review failure) or **merge blocked** (failing or no CI
  checks, conflict, branch protection) — **stop the sweep.** Leave the PR open
  and report it; never pile more unattended merges on an unresolved PR, and
  never force a blocked merge.
- **Split into an epic** — `resolve-issue` clarified a vague issue and it broke
  into sub-tasks, so no PR came out of it. That blocks only that issue, not the
  backlog: report the sub-issues and **continue** with the next one. They belong
  to the next sweep, not this one — the snapshot was taken before they existed.

## Stop conditions

End the run when **any** holds, and report which one:

- every candidate has reached an outcome or been skipped,
- the number of issues resolved reaches `<max-issues>`,
- no open issue survives the stage-2 filters (backlog clear),
- `resolve-issue` leaves a PR open or is blocked from merging.

## Report

Summarize the whole sweep: how many issues the snapshot held and how many became
candidates, then per candidate its number, title and outcome (merged PR, closed
with a verdict, skipped and why) with URLs. Then the totals — how many changes landed,
how many issues were rejected, how many skipped — which stop condition ended the
sweep, and everything left open or never attempted, so the user knows exactly
what a rerun would pick up. End on `main`, synced to the last merge.
