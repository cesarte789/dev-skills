# dev-skills

Claude Code skills that automate the issue → PR → review → merge loop, plus one output style, packaged as a plugin so every repo uses the same copy instead of drifting forks.

The skills are repo-agnostic. Each one takes its standards from the **consuming repo's** `CLAUDE.md` (and `AGENTS.md` where present): how to run tests, what must be regenerated, where docs go, which language comments are in. Put those facts there, not in the skills.

**Why skills instead of GitHub Actions?** Actions need an `ANTHROPIC_API_KEY` and bill per token. Skills run in interactive Claude Code, in a local terminal or on `claude.ai/code`, and are billed under the Claude subscription.

## Install in a repo

Commit this to the consuming repo's `.claude/settings.json`, so every session opened on that repo (local or `claude.ai/code`) offers the plugin:

```json
{
  "extraKnownMarketplaces": {
    "dev-skills": {
      "source": { "source": "github", "repo": "cesarte789/dev-skills" }
    }
  },
  "enabledPlugins": {
    "dev-skills@dev-skills": true
  }
}
```

Or install it for yourself from any terminal:

```bash
claude plugin marketplace add cesarte789/dev-skills
claude plugin install dev-skills@dev-skills
```

Skills are namespaced by the plugin: `/dev-skills:resolve-issue 42`.

**Private repo caveat:** if this repo is private, whatever machine or cloud session installs the plugin needs git read access to it. Locally that is your normal GitHub credentials. In `claude.ai/code` sessions, confirm the plugin actually loads (`/plugin` lists it) before relying on it; making this repo public removes the question, and it holds nothing secret.

Update with `claude plugin marketplace update dev-skills`, then `claude plugin update dev-skills@dev-skills`.

Bump `version` in `.claude-plugin/plugin.json` with every change to what the plugin ships. Claude Code compares that field, not the git commit, so an unbumped change never reaches existing installs. Check changes before pushing with:

```bash
claude plugin validate . --strict
```

## Building blocks

| Skill | Invoke | What it does |
|---|---|---|
| `propose-issues` | `/dev-skills:propose-issues feature\|simplification\|removal\|architecture [area]` | Analyze the code and file one well-scoped GitHub issue. `removal` ranks what the project ships by how much each feature earns its keep and proposes deleting the weakest, blast radius included. |
| `generate-pr-from-issue` | `/dev-skills:generate-pr-from-issue <N>` | Implement issue N end-to-end as a tested PR. |
| `incorporate-pr-feedback` | `/dev-skills:incorporate-pr-feedback [<N>]` | Apply review comments and reply to the threads. |
| `rewrite-issue` | `/dev-skills:rewrite-issue <N>` | Clarify a vague issue, or split an epic into sub-tasks. |
| `evaluate-issue` | `/dev-skills:evaluate-issue <N>` | Judge whether an issue is worth building, weighing the idea against the permanent cost it adds. Comments a build / narrow / decline verdict and changes nothing else. |
| `polish-pr` | `/dev-skills:polish-pr [<N>]` | Review → fix → verify loop until merge-ready; posts an approving comment when clean. |
| `review-diff` | `/dev-skills:review-diff [<N>]` | Read-only review of a PR or the local diff: fresh reviewer subagents report verified findings and nothing gets fixed. |
| `update-readme` | `/dev-skills:update-readme [area]` | Bring the README, feature docs and ARCHITECTURE back in sync with the code. |

## Orchestrators

| Skill | Invoke | Pipeline | Notes |
|---|---|---|---|
| `propose-and-ship` | `/dev-skills:propose-and-ship <kind> [area]` | propose-issues → generate-pr-from-issue → polish-pr | Nothing → merge-ready PR. ⚠️ Nobody vets the idea; you still review the PR before merge. |
| `resolve-issue` | `/dev-skills:resolve-issue <N>` | vet → rewrite-issue (if vague) → evaluate-issue (if it grows the system) → generate-pr-from-issue → polish-pr → merge | Any issue → a merged PR, or the issue closed as not planned with a verdict. A durable rejection also lands a comment-only PR recording the decision in the code. ⚠️ Merges to `main`, rewrites and closes issues unattended. |
| `resolve-issues` | `/dev-skills:resolve-issues [<max-issues>]` | resolve-issue × each open issue | Clears the backlog oldest first, re-syncing `main` between issues. Skips epics, claimed and held issues. Default cap 5. ⚠️ Merges to `main` and closes issues unattended. |
| `simplify-loop` | `/dev-skills:simplify-loop [<max-iterations>] [area]` | (propose-issues `simplification` → generate-pr-from-issue → polish-pr → merge) × N | One simplification per pass, re-analyzing the merged tree each time. Default cap 3. ⚠️ Merges to `main` unattended. |

⚠️ The orchestrators that merge are only safe where `main` is protected by **required CI that runs real tests**. They wait for green checks; with no meaningful checks, everything is green.

## Output style

| Skill | Invoke | What it does |
|---|---|---|
| `i-have-adhd` | `/dev-skills:i-have-adhd` | Shapes replies for an ADHD reader: the next action first, multi-step work numbered, state restated each turn, tangents held back, concrete time estimates. Stays on until you say "stop adhd mode". Invoke-only (`disable-model-invocation`), so it never switches itself on. |

`i-have-adhd` is by [Ayoub Ghriss](https://github.com/ayghri), from [ayghri/i-have-adhd](https://github.com/ayghri/i-have-adhd), and is vendored unmodified under its MIT license (`skills/i-have-adhd/LICENSE`).

To have it on from the start of every session in a repo, as LifeOS does, the repo keeps its own copy of `SKILL.md` and imports it with an `@` line in `CLAUDE.md`:

- **Import from `CLAUDE.md`.** By default Claude Code reads `AGENTS.md` only when a project has no `CLAUDE.md`, and consuming repos must have one (below). So an import that lives in `AGENTS.md` is skipped unless `CLAUDE.md` contains `@AGENTS.md`, or the built-in AGENTS.md plugin's `instructionFiles` option is set to load both files.
- **Keep the copy inside the repo.** An import can point outside the repo, but not usefully at the plugin's copy: its cache path contains the plugin version, so it breaks on the next update. Outside-the-repo imports also load only after an approval prompt, saved per project on that machine. Cloud sessions, and `claude -p` runs where nobody approved it interactively first, never get that approval, so they skip the import.
- **Copy the license with it.** The MIT license requires its copyright and permission notice in every copy, and `SKILL.md` carries neither. Put `skills/i-have-adhd/LICENSE` next to the copy.

## What the consuming repo must provide

- A `CLAUDE.md` stating the conventions and **the exact test/build commands**, including a narrow per-area command if there is one. `polish-pr` and `generate-pr-from-issue` run whatever it names.
- Anything that must be regenerated alongside a change (generated types, schema snapshots) and the command that does it.
- Where docs live and which doc owns which fact, if there is more than a README.
- Branch protection on `main` requiring CI, before running any merging orchestrator.

## Why the skills don't call `/review` or `/code-review`

A skill can invoke only what the session's Skill listing shows. `security-review`, `simplify` and `loop` are built in and listed, so these skills may call them (`polish-pr` runs `security-review` on security-sensitive diffs). `/review` never appears in the listing, and `/code-review` is present in some sessions and not others, so nothing here depends on either. `polish-pr` reviews through `review-diff`'s subagents instead, which is what lets the orchestrators run unattended.

## GitHub access

The skills are written against the `gh` CLI. Cloud sessions on `claude.ai/code` may not have `gh`; each skill tells the agent to use the GitHub MCP tools instead in that case.

## Provenance

The workflow skills were extracted from `cesarte789/lifeos`, with the LifeOS-specific rules (test commands, generated API types, feature-doc format, UI language) moved out of the skills and into that repo's `CLAUDE.md`. `i-have-adhd` is third-party; see Output style above for its author and license.
