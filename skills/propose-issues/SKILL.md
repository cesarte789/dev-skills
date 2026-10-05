---
name: propose-issues
description: >-
  Analyze the codebase and file a well-defined GitHub issue proposing the next
  step. Use when the user wants a feature idea, a simplification/cleanup, a
  proposal to delete the feature that has stopped earning its keep ("less is
  more"), or an architectural next step turned into an actionable issue. Pass
  the kind as an argument: "feature", "simplification", "removal", or
  "architecture" (optionally with an area to focus on, e.g. "feature rating
  module").
---

# Propose issues

> Commands below use the `gh` CLI. If `gh` isn't available in this session, do
> the same operations with the GitHub MCP tools (`mcp__github__*`) instead.

Generate **one** sharp, actionable GitHub issue of the requested kind and file it
with `gh`. Quality over quantity: a single well-scoped proposal beats a vague list.

## 1. Determine the kind

Read the arguments. The first word selects the kind:

- `feature` — a new, valuable capability.
- `simplification` — cut complexity or redundancy behind a feature that stays.
- `removal` — delete the whole feature that has stopped earning its keep.
- `architecture` — the next logical step for the project's growth.

Any remaining words narrow the focus (e.g. an area, module, or path). If no kind
is given, ask which one. Default focus is the whole repository.

## 2. Study the code first

Explore the relevant code before proposing anything. Understand the existing
patterns, the domains in play, and what already exists — never propose something
that's already there. Honor `CLAUDE.md`.

Constraints:
- If the area is one layer (e.g. UI-only), do **not** propose work that needs new
  capabilities from another layer that don't exist. Every proposal must be implementable within this repo.
- Be critical of scope. If a simpler version delivers the value, propose that.

## 3. Shape the proposal by kind

- **feature** — Identify a real gap. Describe the capability and its user benefit.
  Title prefix `feat:`. Label `feature-proposal`.
- **simplification** — Find overly complex code or redundant logic behind a feature
  that stays. Describe the change and its maintainability payoff. Title prefix
  `refactor:`. Label `simplification-proposal`. Propose `removal` instead when the
  honest answer is that the whole feature should go.
- **removal** — Less is more. Rank what the project actually ships (the `README.md`
  feature list and any feature docs it keeps, its screens, commands, entry points
  and background jobs) by how much each one earns its keep — how often it is plausibly
  used and what would be missed, against the storage, API surface, screen space and
  vocabulary it costs forever — and propose deleting the weakest. Name the
  evidence that it is the weakest, and map the blast radius (schema,
  APIs, routes or screens, background jobs, docs — whichever the project has) so the deletion is directly
  actionable. Title prefix `refactor!:`; it removes user-facing behavior.
  Label `removal-proposal`.
- **architecture** — Briefly note any obvious security/architectural flaw, then
  propose the Minimum Logical Progress: the next step that is functional on its own,
  delivers immediate value, and needs minimal effort. Title prefix `feat:`.
  Label `architect-proposal`. Use this issue body structure:

  ```markdown
  ### Context
  [why this is the logical next step, grounded in the code you read]

  ### Tasks
  - ...

  ### Acceptance Criteria
  - ...
  ```

Titles follow conventional-commit style. Bodies are markdown, concrete, and
reference real files/paths you found.

## 4. Check it isn't already settled

The code shows what landed, not what was proposed or turned down: a rejected
proposal usually leaves the code unchanged, and the same analysis keeps finding
it. Before filing, search the issues, both open ones and those closed as not
planned, for the same idea:

```bash
gh issue list --state open --search "<key terms>" --json number,title,url
gh issue list --state closed --search "<key terms> reason:\"not planned\"" --json number,title,url
```

Read the body and the closing comments of every close match. The candidate is
**settled** when an open issue already proposes it, or when a closed one turned
it down and nothing its verdict named as decisive has changed since. Drop a
settled candidate and take your next-best one through this same check. A
rejected idea whose decisive fact did change is not settled: file it, link the
old issue and say what changed.

## 5. File it

Ensure the label exists, then create the issue:

```bash
gh label create "<label>" --color BFD4F2 --description "AI-proposed <kind>" 2>/dev/null || true
gh issue create --title "<title>" --body "<body>" --label "<label>"
```

Report the created issue URL. If you genuinely cannot find a worthwhile proposal
that isn't settled, say so and file nothing — do not invent filler. Name the
issues that settled the candidates you dropped, so the caller can tell "nothing
left to do" from "already proposed or turned down".
