---
name: resolve-issue
description: >-
  Resolve a GitHub issue end-to-end, or explain why it shouldn't be worked on.
  First vets whether the issue actually makes sense against the codebase,
  clarifying it when it is sound but too vague to implement and judging whether
  a feature is worth its permanent cost; then implements it as a tested PR,
  polishes it to merge-ready and merges it; if it doesn't make sense or isn't
  worth building, closes the issue with a comment describing exactly why and
  records the reasoning as a comment in the code when the reason is a durable
  property of the code. Use when you want an issue handled autonomously from
  triage to merge, however rough the issue is. Pass the issue number (e.g.
  "42"). Chains vet -> rewrite-issue (only when vague) -> evaluate-issue (only
  when it would grow the system) -> generate-pr-from-issue -> polish-pr ->
  merge.
---

# Resolve issue

> Commands below use the `gh` CLI. If `gh` isn't available in this session, do
> the same operations with the GitHub MCP tools (`mcp__github__*`) instead.

> The other skills named here ship in the same `dev-skills` plugin. Invoke them
> with the Skill tool by the name the session lists, `dev-skills:<name>` (e.g.
> `dev-skills:polish-pr`), or the bare name where the skills are installed
> unprefixed.

Take one GitHub issue, however rough, and reach a definitive outcome: either a
**merged PR** that fixes it, or a **closed issue** carrying a written verdict that
explains why it doesn't make sense to implement — plus, when the reason lives in
the code, a comment in the code so the idea doesn't come back. An issue that is
sound but too vague to build is clarified first rather than guessed at or handed
back; only when clarifying splits it into an epic does the run end in sub-issues
instead. A valid issue that would grow the system is then weighed on whether it
is worth its permanent cost, because a run this unattended should not be able to
build things the project is better off without. Never leave the issue in an
ambiguous state.

> ⚠️ Both outcomes are unattended: the happy path **merges to `main`** without a
> human reviewing the PR, and the reject path **closes the issue** without a
> human confirming the verdict, then merges a comment-only PR recording it. A
> rough issue is also **rewritten in place** without anyone confirming the
> clarified version, and a declined one is closed on the evaluation's judgement
> alone. Use it where that is acceptable (low-stakes work, or a `main` protected
> by required CI).

## Arguments

`<issue-number>` — required, e.g. `42`.

## Stage 1 — Vet the issue

Read the issue and everything it depends on:

```bash
gh issue view <N> --json number,title,body,state,labels,comments,url
```

Then **verify its claims against the actual code** — don't take the issue at its
word. Read the files it names, run the relevant test or reproduction if it
reports a bug, and search for prior art:

```bash
gh issue list --search "<key terms>" --state all --limit 10
gh pr list --search "<key terms>" --state all --limit 10
```

An issue **makes sense** when all of these hold:

1. **Real** — the described bug reproduces, or the described gap genuinely exists
   in the current code. A bug report you cannot reproduce on `main` fails here.
2. **Correct premise** — it isn't based on a misreading of the code, a stale
   version, or behavior that is intentional and documented.
3. **Not already handled** — no duplicate open issue, no merged/open PR already
   doing it, not already fixed on `main`.
4. **In scope** — it belongs to this project and doesn't contradict `CLAUDE.md`
   or the documented architecture.
5. **Actionable** — you can tell what "done" looks like well enough to implement
   and test it without guessing at the requester's intent.

If all five hold, go to **Stage 1c**. If **only** #5 fails, the issue needs
clarification rather than a verdict — go to **Stage 1b**. If any of #1–#4 fails,
go to **Stage 5 — Reject**, which closes the issue.

Note what this stage does *not* ask: whether the issue is worth building. A
request can be real, correct, novel, in scope and perfectly actionable and still
leave the project worse off. That question is Stage 1c's.

## Stage 1b — Clarify a vague issue

An otherwise sound issue is not rejected for being underspecified — and not
implemented by guessing at the missing requirement either. Run the
**rewrite-issue** skill on the issue number; it sharpens the issue without
changing what its author asked for.

- Rewritten **in place**: re-read the clarified issue and continue to Stage 1c
  with it. The clarified body is what gets judged, and then implemented.
- Split into an **epic with sub-tasks**: **stop here.** There is no single PR to
  generate. Report the sub-issue numbers/URLs and say each one can be resolved on
  its own.

Rewriting sharpens an intent that is there; it cannot supply one that isn't. If
you cannot tell what the author wanted — not merely how to build it — clarifying
would mean inventing the requirement. That is #5 failing unrecoverably: go to
**Stage 5** and reject, naming what would make the issue workable.

## Stage 1c — Judge whether it is worth building

Validity is not worth. Nothing else in this run asks whether the project is
better off with the issue than without it, and everything after this stage is
committed to building it — so an idea that shouldn't exist has to be stopped
here or not at all.

**Run it when the issue would grow the system**, which is where the cost is
permanent: a new table or migration, a new endpoint, a new module, route or tab,
a new skill or workflow, a new dependency, or a feature bolted beside an existing
one rather than deepening it.

**Skip it otherwise**, and say in the report that you did. A bug fix, a
correction, a simplification, a removal, a doc update or a test has already paid
for itself — evaluating it spends a judgement call on a question with an obvious
answer. When in doubt about a middle case, run it: a verdict costs one comment,
and an unwanted feature costs every future reader of that module.

After Stage 1b, never before it: a verdict on a vague issue judges a guess at the
issue rather than the issue.

Run the **evaluate-issue** skill on the issue number. It weighs the idea against
what it permanently adds and lands on one of three, each with its own way out of
this stage:

- **Build it** — continue to Stage 2 with the smallest honest version its verdict
  names.
- **Narrow it** — continue to Stage 2 building **only** the narrowed scope the
  verdict names, not the issue as written. Say so in the PR body, so the
  difference between what was asked and what landed is on the record.
- **Decline it** — go to **Stage 5**. Its comment is already on the issue, so
  don't restate it: add only what your own vetting adds, then close.

`evaluate-issue` recommends and stops by design — it never closes anything
itself. Acting on its verdict is this skill's job, and closing a declined issue
is the same unattended close Stage 5 already performs for an invalid one.

## Stage 2 — Implement as a PR

Run the **generate-pr-from-issue** skill on the issue number. It branches off
`main`, implements with tests per `CLAUDE.md`, and opens a PR that closes the
issue.

- If it opens a PR: capture the PR number and continue.
- If it concludes on closer inspection that no code change is warranted: treat
  that as a late rejection — go to **Stage 5** with its reasoning. Note that it
  will already have commented on the issue itself; don't restate that comment,
  just add what your vetting adds, then close the issue.

## Stage 3 — Polish to merge-ready

Run the **polish-pr** skill on that PR (review → fix → verify loop).

- Clean (polish-pr met its done condition): record the commit it reviewed and
  pushed — `git rev-parse HEAD` on the PR branch it left checked out, not the
  PR's current head on GitHub, which a later push may already have moved — and
  continue to Stage 4.
- Any other stop (e.g. its iteration cap, a steering abort, a review failure):
  **do not merge.** Leave the PR open, report exactly why polish stopped, and
  stop.

## Stage 4 — Merge

Only after a clean polish. That is the CI gate: `polish-pr` ends clean only with
CI green on its latest push, so there is nothing left to wait for — what matters
now is merging exactly that head, not one pushed after the review:

```bash
gh pr merge <PR> --squash --delete-branch --match-head-commit <sha from Stage 3>
git checkout main && git pull --ff-only && git fetch --prune
```

(The GitHub MCP merge tool takes the same pin as `expectedHeadSha`.)

The PR body closes the issue on merge — confirm the issue actually went to
closed. If GitHub refuses the merge (the head moved since Stage 3, a failing
required check, a conflict, branch protection needing a human), **stop and
report**; never force it. A moved head means the PR changed after its review,
so it is a stop, not a retry.

## Stage 5 — Reject: comment the verdict, then close

An issue that doesn't make sense — or that isn't worth building — is closed, not
left hanging. Always do both steps, in this order — comment first so the
explanation is on the issue before it closes.

Post one comment that stands on its own for a reader who hasn't seen your
analysis:

- that you are **closing** the issue, and why: which criterion from Stage 1 it
  fails, or that Stage 1c declined it,
- the **evidence**: the file and line, the command you ran and its output, the
  duplicate issue/PR number — not just an assertion. On a decline, the evaluation
  comment already carries it; point at it instead of repeating it,
- what would make the issue workable (a repro, a version, a narrower scope), if
  anything would, and an invitation to reopen with it. On a decline, that is the
  fact the evaluation said would flip its verdict.

```bash
gh issue comment <N> --body "<verdict>"
gh issue close <N> --reason "not planned"
```

The verdict comment is the explanation, so close without a second one. Never
close silently: if the comment fails to post, stop and report rather than
closing an issue with no reason on it.

Closing here is cheap to undo — the requester reopens with the missing repro or
scope. Leaving a rejected issue open is what strands it. So do not soften a
rejection into "leave it open and let a human decide"; if you cannot state a
criterion it fails, or a decline with its reasoning, it isn't a rejection at all
— it belongs in Stage 2, or in Stage 1b when only #5 fails.

Open no PR in this stage — the only PR a rejection can produce is the
comment-only one in Stage 6.

## Stage 6 — Record the decision in code (rejections only)

A verdict buried in a closed issue is invisible to the next person or agent
reading the code, so the same idea comes back. When the rejection rests on
something durable about the code, leave a comment where the code invites the
suggestion, so the next reader meets the reasoning before proposing it again.

**Do it** when the reason is a property of the code that still holds next month:

- an architectural decision — a boundary kept deliberately, a dependency
  direction, a pattern chosen over the obvious alternative,
- behavior that looks like a bug but is intentional,
- a deliberate omission — no cache, no retry, no index here, and why,
- a non-obvious constraint being respected: ordering, precision, a third-party
  API quirk being worked around,
- a Stage 1c decline whose reasoning is about the code rather than about this
  issue — the module deliberately stops where it stops, the feature would cost a
  table that this data does not earn. Anchor it where someone would start
  building the declined thing.

**Skip it** when the rejection says nothing about the code, where a comment
would be noise: duplicate of another issue, already fixed on `main`, cannot
reproduce, reported against a stale version, out of scope for the project, or
too vague to act on. Skip it too when a comment already there says it — extend
that one only if it states the decision but not the reason.

**Where.** Anchor at the code someone would actually edit to "fix" it: the
function, the branch, the missing call, the constant. A comment at the top of an
unrelated file prevents nothing. If several places invite the same suggestion,
comment the one that is the real decision point and leave the others alone.

**How to write it.** The comment must stand entirely on its own:

- In the file's existing comment language and style.
- No issue number, URL, "rejected", "as discussed", date, or person's name. It
  reads as a standing decision, not as a reply to a thread — a reader who never
  saw the issue gets the whole reason from the comment alone.
- State the decision, the reason, **and the alternative not taken** — naming the
  alternative is what stops the re-suggestion. E.g. "Sorted here rather than in
  the query: the result set is capped at 200, and the index the DB would need
  costs more on every write than this sort costs on read."
- Add the condition that would flip the decision when there is one: "revisit if
  this ever pages beyond one screen of results."
- Two to four lines. If it needs more, it is a document: put it under `docs/`
  and leave a one-line pointer at the code.
- Explain only why it isn't the other thing; never restate what the code does.

**Land it** as a comment-only PR — no change escapes a PR:

```bash
git fetch origin --quiet && git checkout -b docs/<short-slug> origin/main
# add the comment(s)
git diff   # verify: comments only
git commit -am "docs: <what the comment records>"
git push -u origin docs/<short-slug>
gh pr create --title "docs: <what the comment records>" --body "<summary>

Follows #<N>"
gh pr checks; status=$?
while [ "$status" -eq 8 ]; do sleep 15; gh pr checks; status=$?; done  # 8 = still pending
gh pr merge --squash --delete-branch
git checkout main && git pull --ff-only && git fetch --prune
```

Use `Follows #<N>`, never `Closes` — the issue is already closed, and the
cross-reference is what keeps the decision traceable to the discussion without
the comment itself naming it. A comment-only diff changes no observable
behavior, so it carries no test and skips `polish-pr` —
there is nothing for a review loop to find. If the diff turns out to touch
anything but comments, stop: that is a code change, and it does not belong to a
rejected issue. As in Stage 4, if GitHub blocks the merge, leave the PR open and
report it; never force it.

If no place in the code is the right anchor, skip the stage and say so.

## Report

Open with exactly one outcome, named as below. Callers (`simplify-loop`,
`resolve-issues`) branch on this name alone, so every way this skill can end
maps to one of them:

- **`merged`** — Stage 4 merged the PR and the issue went to closed.
- **`rejected`** — Stage 5 closed the issue with a verdict, and no PR from this
  run is left open (Stage 6 merged its comment-only PR, or was skipped).
- **`split`** — Stage 1b split the issue into an epic; list the sub-issues.
- **`stopped`** — anything else: polish stopped without a clean result
  (Stage 3), the merge was blocked (Stage 4), the verdict comment failed to
  post and the issue is still open (Stage 5), or the comment-only PR was
  blocked (Stage 6). Name what is left open.

Then the details: the issue URL, the vetting verdict and the
evidence behind it, whether Stage 1b rewrote the issue before implementing it (and
the sub-issues if it split), whether Stage 1c evaluated it (its verdict and
comment URL) or why it was skipped, the PR URL and how many polish iterations ran,
the final test/build status, and anything left open. When a *narrow it* verdict
was followed, say what was cut. On a rejection, say whether Stage 6 recorded the
decision in code — with the file and the PR URL — or why nothing was worth
anchoring. On the merge path, end on `main` synced to the merge.
