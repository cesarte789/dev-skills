---
name: simplify-loop
description: >-
  Continuously simplify the codebase, one change at a time, with minimal human
  involvement: propose a simplification issue, ship it as a tested PR, polish it
  to merge-ready, merge it, then re-analyze the now-simpler code and repeat. Use
  for an autonomous cleanup run. Optionally pass a max number of iterations and/or
  an area (e.g. "5 src/ui"). Chains propose-issues -> resolve-issue (vet -> PR
  -> polish -> merge, or close with a verdict), in a loop. NOTE: merges to main
  and closes issues without human vetting of each idea or PR — use only where
  that is acceptable.
---

# Simplify loop

> The other skills named here ship in the same `dev-skills` plugin. Invoke them
> with the Skill tool by the name the session lists, `dev-skills:<name>` (e.g.
> `dev-skills:polish-pr`), or the bare name where the skills are installed
> unprefixed.

Run an autonomous simplification loop. Each pass finds **one** worthwhile
simplification, ships it through to a merged PR, then re-analyzes the updated
codebase for the next one. Sequential by design: the next proposal is made
against the code *after* the previous simplification has landed, so each pass
builds on a strictly simpler tree.

> ⚠️ This runs unattended and **merges to `main`** and **closes issues** on its
> own, with everything `resolve-issue` warns about. No human vets each idea or
> reviews each PR before it lands. Use it only on a repo/branch where that
> is acceptable (e.g. low-stakes cleanup, or a protected `main` with required CI
> gating the merge). If you want to review before merge, use `propose-and-ship`
> with kind `simplification` instead — it ships *to* a PR and stops.

## Arguments

`[<max-iterations>] [<area>]` — both optional.

- `<max-iterations>` — leading integer; the hard cap on proposals this run
  resolves, merged or rejected. Default **3**. This is the loop's safety stop;
  never run unbounded. Rejections count too: a rejection can still merge a
  comment-only PR, and the cap is there to bound unattended merges.
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

3. **Resolve.** Run the **resolve-issue** skill on that issue number. It vets
   the issue, implements it as a PR, polishes it and merges it — or closes it
   with a verdict. Everything about building, polishing and merging lives
   there; react only to how it ended:
   - **Merged** — continue to stage 4.
   - **Rejected and closed**, with no PR of its own left open (vetting found
     nothing to do, or no code change turned out to be warranted) — continue
     to stage 4.
   - **Anything else — stop the loop.** That covers a PR left open (polish
     stopped without a clean result, or a rejection's comment-only PR was
     blocked), a blocked merge (failing check, conflict, branch protection),
     an issue left open because a step failed, and a split into an epic, which
     a sharp proposal shouldn't produce. Never pile more autonomous merges on
     top of an unresolved PR or issue.

4. **Loop.** Increment the resolved-count. If it is below `<max-iterations>`, go
   back to stage 1 and analyze the freshly-merged tree for the next
   simplification.

## Stop conditions

End the run when **any** holds, and report which one:

- the resolved-count reaches `<max-iterations>`,
- `propose-issues` finds nothing worth doing,
- `resolve-issue` ends in anything but merged or rejected-and-closed.

## Report

Summarize the whole run: each iteration's issue and outcome with URLs — merged
PR, or closed with a verdict (plus any comment-only PR it merged) — how many
simplifications landed and how many proposals were rejected, which stop
condition ended the loop, and anything left open (a PR that stalled in polish,
a blocked merge, sub-issues from a split). End on `main`, synced to the last
merge.

## Tip

For a hands-off long run you can wrap a single invocation with the built-in
`/loop`, but the loop above is self-contained — one invocation already iterates to
its cap or a stop condition.
