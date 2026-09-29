---
name: propose-and-ship
description: >-
  Go from nothing to a merge-ready PR: propose a new issue, implement it as a
  tested PR, then review-and-fix until clean. Use to autonomously explore and ship
  an improvement. Pass the kind ("feature", "simplification", "removal", or
  "architecture", optionally with an area). Chains propose-issues ->
  generate-pr-from-issue -> polish-pr. NOTE: Claude chooses what to build with
  no human vetting of the idea — best for low-stakes / exploratory work.
---

# Propose and ship

> The other skills named here ship in the same `dev-skills` plugin. Invoke them
> with the Skill tool by the name the session lists, `dev-skills:<name>` (e.g.
> `dev-skills:polish-pr`), or the bare name where the skills are installed
> unprefixed.

End-to-end pipeline that invents an improvement and ships it. Each stage is an
existing skill — invoke them in order and stop early if a stage says to.

> ⚠️ This runs unattended from idea to PR. No one reviews *what* gets built before
> it's implemented. Use it where a speculative PR is welcome (you'll still review
> the PR before merge). For anything you care about scoping yourself, write the
> issue and use `resolve-issue` instead — note that one also merges the PR once it
> polishes clean.

## Stage 1 — Propose

Run the **propose-issues** skill with the requested kind and area.

- If it files an issue: capture the issue number and continue.
- If it concludes there's no worthwhile proposal and files nothing: **stop** and
  report that — there's nothing to build.

## Stage 2 — Generate the PR

Run the **generate-pr-from-issue** skill on the issue from Stage 1.

- If it opens a PR: capture the PR number and continue.
- If it determines no code change is warranted: **stop** and report.

## Stage 3 — Polish to merge-ready

Run the **polish-pr** skill on the PR from Stage 2 (review → fix → verify loop
until clean, or until it stops without a clean result, e.g. its cap, a
steering abort, or a review failure).

## Report

Summarize the run: the proposed issue, the PR URL, polish iterations, final
test/build status, and anything left open. Make clear the PR still needs your
review before merge — this skill ships *to* a PR, not past it.
