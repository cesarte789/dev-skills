---
name: evaluate-issue
description: >-
  Judge whether a GitHub issue is worth building at all, and say so in a verdict
  comment. Weighs what the idea is worth against the permanent cost it adds — a
  migration, an endpoint, a module tab, more code to keep working — and lands on
  build it, narrow it, or decline it. Use before committing to an issue,
  especially a feature that would grow the system, and whenever the backlog is
  growing faster than the appetite to maintain it. Pass the issue number (e.g.
  "42"). Recommends only: it never edits, labels or closes the issue.
---

# Evaluate issue

> Commands below use the `gh` CLI. If `gh` isn't available in this session, do
> the same operations with the GitHub MCP tools (`mcp__github__*`) instead.

Answer one question about an issue: **is this worth building?** Not "is it a
valid request" — whether the project is better off with it than without it, once
the code it adds has to be maintained forever.

Every feature is permanent. A migration cannot be un-run in a database of record,
a public endpoint must keep its contract, a new screen or tab stays on screen, and every
file added is a file that must keep passing CI, keep matching `CLAUDE.md`, and be
read by whoever touches that area next. For a solo owner or a small team the scarce
resource is rarely time — it is how much system the people (and the agents
working for them) can keep coherent.

This skill only recommends. It posts its verdict and stops: the issue keeps its
state, its labels and its title, and a human decides.

## Which one to use

- **This skill** — should we build it at all? Ends in a recommendation.
- **`resolve-issue`** — its Stage 1 vets whether an issue is *valid* (real,
  correct premise, not a duplicate, in scope, actionable) and then builds and
  merges it. Validity is not worth: a perfectly valid feature can still be one
  the project is better off without, which is why its Stage 1c runs this skill
  on anything that would grow the system and acts on the verdict — building the
  narrowed scope, or closing a decline. Run this skill on its own when you want
  the judgement without the run that follows it.
- **`rewrite-issue`** — the intent is right but the wording is vague. Sharpening
  is not judging.

## Arguments

`<issue-number>` — required, e.g. `42`.

## 1. Read the issue, then read what it would touch

```bash
gh issue view <N> --json number,title,body,state,labels,comments,url
```

Take the issue at its word about *what* it wants, never about what it costs. Go
find that out in the code:

- Which module does it land in, and how big is that module already?
- Does it need a new table or migration, a new endpoint, a new route, screen or
  tab, a new dependency?
- Is there something in the repo that already does most of it? Search before
  believing the gap is real:

```bash
gh issue list --search "<key terms>" --state all --limit 10
```

An evaluation written without opening the code is a guess, and a guess is worse
than no verdict at all.

## 2. Weigh it

**What it is worth**

- Who asks for it, and how often would it actually be used? A thing used weekly
  earns far more than a thing used once.
- Does it make something existing better, or bolt on a new thing beside it?
  Deepening a module the owner already uses beats widening the app.
- What breaks or stays annoying if it is never built? If the honest answer is
  "nothing", that is the answer.

**What it costs, forever**

- **Schema**: a migration is permanent and its table will be read by future
  queries, backups and the schema validator.
- **API surface**: every endpoint or public function widens the surface (and any
  generated clients or types), and must keep its contract.
- **UI surface**: a new screen, tab or route is space on screen and one more
  thing to keep consistent with the project's UI conventions and covered by tests.
- **Code to keep working**: roughly how many files, and in which of the areas
  that are already the biggest?
- **Concepts**: the real cost of a feature is often the new vocabulary a reader
  has to learn before they can safely change anything nearby.

**The cheaper alternatives** — always name them, because the choice is rarely
build-or-nothing:

- a smaller version that gets most of the value,
- reusing or extending something that already exists,
- doing it by hand for now, given a single operator,
- leaving it and seeing whether it is asked for a second time.

## 3. Land on one of three

- **Build it** — the value is clear and the cost is proportionate. Say what the
  smallest honest version is, so it doesn't grow on the way in.
- **Narrow it** — the idea is good, the scope is not. Name exactly what to cut
  and what to keep; that is the version to implement.
- **Decline it** — the cost outlives the value. Name the cheaper alternative that
  covers the need, or say plainly that nothing breaks without it.

Be decisive. "It depends" is not a verdict, and a hedge helps nobody decide. If
the value genuinely turns on something only the owner knows (how often they'd use
it), say which fact would flip the verdict, and give your recommendation for the
likelier case anyway.

Declining is not a criticism of the idea, and building is not a promise it is
easy. Say which it is and why, in the fewest words that carry the reasoning.

## 4. Post the verdict

One comment, standing on its own for a reader who hasn't seen your analysis: the
verdict, what the feature is worth, what it costs (with the files, tables and
endpoints you actually found), the alternative you'd take instead, and the fact
that would change your mind.

```bash
gh issue comment <N> --body "<verdict>"
```

Then **stop**. Do not close, label, retitle or rewrite the issue, and do not
start implementing a "build it" verdict — those are separate skills, run
deliberately (`resolve-issue`, `generate-pr-from-issue`). The point of a
recommendation is that someone else gets to take it or leave it.

## Report

State the verdict first — build, narrow, or decline — then the value, the cost
with the evidence behind it, the alternative you weighed, and the comment URL.
