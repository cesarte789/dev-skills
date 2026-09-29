---
name: simplify-loop
description: >-
  Continuously simplify the codebase, one change at a time, with minimal human
  involvement: propose a simplification issue, ship it as a tested PR, polish it
  to merge-ready, merge it, then re-analyze the now-simpler code and repeat. Use
  for an autonomous cleanup run. Optionally pass a max number of iterations and/or
  an area (e.g. "5 src/ui"). Chains propose-issues -> generate-pr-from-issue ->
  polish-pr -> merge, in a loop. NOTE: merges to main without human vetting of
  each idea or PR — use only where that is acceptable.
---

# Simplify loop

> Commands below use the `gh` CLI. If `gh` isn't available in this session, do
> the same operations with the GitHub MCP tools (`mcp__github__*`) instead.

> The other skills named here ship in the same `dev-skills` plugin. Invoke them
> with the Skill tool by the name the session lists, `dev-skills:<name>` (e.g.
> `dev-skills:polish-pr`), or the bare name where the skills are installed
> unprefixed.

Run an autonomous simplification loop. Each pass finds **one** worthwhile
simplification, ships it through to a merged PR, then re-analyzes the updated
codebase for the next one. Sequential by design: the next proposal is made
against the code *after* the previous simplification has landed, so each pass
builds on a strictly simpler tree.

> ⚠️ This runs unattended and **merges to `main`** on its own. No human vets each
> idea or reviews each PR before it lands. Use it only on a repo/branch where that
> is acceptable (e.g. low-stakes cleanup, or a protected `main` with required CI
> gating the merge). If you want to review before merge, use `propose-and-ship`
> with kind `simplification` instead — it ships *to* a PR and stops.

## Arguments

`[<max-iterations>] [<area>]` — both optional.

- `<max-iterations>` — leading integer; the hard cap on simplifications to land
  this run. Default **3**. This is the loop's safety stop; never run unbounded.
- `<area>` — remaining words narrow the focus (a module, path, or layer), passed
  straight through to `propose-issues` (e.g. `src/ui`, `api/billing`).

## Each iteration

Run these stages in order. Capture the issue and PR numbers as you go.

1. **Sync.** Make sure local `main` is current so the analysis sees the latest
   merged state:

   ```bash
   git checkout main && git pull --ff-only
   ```

2. **Propose.** Run the **propose-issues** skill with kind `simplification` and
   the area. It studies the current code and files one sharp issue.
   - If it concludes there is no worthwhile simplification left and files nothing:
     **stop the loop** — the codebase is clean for now. Report and exit.
   - Otherwise capture the issue number.

3. **Generate the PR.** Run the **generate-pr-from-issue** skill on that issue.
   - If it opens a PR: capture the PR number.
   - If it determines no code change is warranted: skip this issue (close it with a
     short note) and **continue to the next iteration** without counting it.

4. **Polish to merge-ready.** Run the **polish-pr** skill on the PR (review → fix →
   verify loop until clean).
   - If polish reaches **clean** (its done condition met): continue to merge.
   - If polish stops for any other reason (e.g. its cap, a steering abort, a
     review failure): **do not merge.** Leave the PR open, report it as needing
     attention, and **stop the loop** — do not pile more autonomous merges on
     top of an unresolved PR.

5. **Merge.** Only after a clean polish, and only with green CI. `polish-pr`
   checks CI after every push, so by now the checks are usually already green —
   confirm with a snapshot, and while anything is still pending take another
   every 15 seconds rather than blocking on `--watch`, which shows nothing until
   it ends:

   ```bash
   gh pr checks <PR>; status=$?
   while [ "$status" -eq 8 ]; do sleep 15; gh pr checks <PR>; status=$?; done  # 8 = still pending
   gh pr merge <PR> --squash --delete-branch
   ```

   Never merge while checks are red or pending. This closes the linked issue
   automatically (the PR body closes it). Confirm the merge succeeded; if GitHub
   blocks it (failing required check, conflict, branch protection needing a
   human), **stop the loop** and report — never force it.

6. **Loop.** Increment the landed-count. If it is below `<max-iterations>`, go back
   to stage 1 and analyze the freshly-merged tree for the next simplification.

## Stop conditions

End the run when **any** holds, and report which one:

- the landed-count reaches `<max-iterations>`,
- `propose-issues` finds nothing worth doing,
- `polish-pr` stops without a clean result (PR left open for review),
- a merge is blocked (CI failure, conflict, or branch protection).

## Report

Summarize the whole run: each iteration's issue → PR → merge (with URLs), how many
simplifications landed, which stop condition ended the loop, and anything left open
(e.g. a PR that stalled in polish). End on `main`, synced to the last merge.

## Tip

For a hands-off long run you can wrap a single invocation with the built-in
`/loop`, but the loop above is self-contained — one invocation already iterates to
its cap or a stop condition.
