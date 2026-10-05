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

Bump `version` in `.claude-plugin/plugin.json` with every change to what the plugin ships (`skills/`, `output-styles/`, `plugin.json` itself). Claude Code compares that field, not the git commit, so an unbumped change never reaches existing installs. Check changes before pushing with:

```bash
scripts/check.sh origin/main
```

It runs `claude plugin validate . --strict` and `claude plugin validate .claude-plugin/plugin.json --strict`, parses every `output-styles/*.md` frontmatter, and fails when `skills/`, `output-styles/` or `plugin.json` changed without a higher version. It needs `claude`, `python3` and PyYAML. Both validate commands are needed. On the repo root, `validate` checks only `marketplace.json`. Validating `plugin.json` is what parses each skill's `SKILL.md` frontmatter, and a skill whose frontmatter fails to parse still loads, silently, with every frontmatter field dropped. Neither parses output-style frontmatter, which is why the script does.

The `validate` workflow (`.github/workflows/validate.yml`) runs the same script with no secrets: on every PR against its base, and on every push to `main` against the previous tip. Mark its `validate` check as required on `main` so the merging orchestrators have something real to wait for.

## Building blocks

| Skill | Invoke | What it does |
|---|---|---|
| `propose-issues` | `/dev-skills:propose-issues feature\|simplification\|removal\|architecture [area]` | Analyze the code and file one well-scoped GitHub issue. `removal` ranks what the project ships by how much each feature earns its keep and proposes deleting the weakest, blast radius included. |
| `generate-pr-from-issue` | `/dev-skills:generate-pr-from-issue <N>` | Implement issue N end-to-end as a tested draft PR, for `polish-pr` to mark ready. |
| `incorporate-pr-feedback` | `/dev-skills:incorporate-pr-feedback [<N>]` | Apply review comments and reply to the threads. |
| `rewrite-issue` | `/dev-skills:rewrite-issue <N>` | Clarify a vague issue, or split an epic into sub-tasks. |
| `evaluate-issue` | `/dev-skills:evaluate-issue <N>` | Judge whether an issue is worth building, weighing the idea against the permanent cost it adds. Comments a build / narrow / decline verdict and changes nothing else. |
| `polish-pr` | `/dev-skills:polish-pr [<N>]` | Review → fix → verify loop until merge-ready; marks a draft PR ready once review is clean and posts an approving comment when CI is green. |
| `review-diff` | `/dev-skills:review-diff [<N>]` | Read-only review of a PR or the local diff: fresh reviewer subagents report verified findings and nothing gets fixed. |
| `update-readme` | `/dev-skills:update-readme [area]` | Bring the README, feature docs and ARCHITECTURE back in sync with the code, and trim the README to its core. |

## Orchestrators

| Skill | Invoke | Pipeline | Notes |
|---|---|---|---|
| `propose-and-ship` | `/dev-skills:propose-and-ship <kind> [area]` | propose-issues → generate-pr-from-issue → polish-pr | Nothing → merge-ready PR. ⚠️ Nobody vets the idea; you still review the PR before merge. |
| `resolve-issue` | `/dev-skills:resolve-issue <N>` | vet → rewrite-issue (if vague) → evaluate-issue (if it grows the system) → generate-pr-from-issue → polish-pr → merge | Any issue → a merged PR, or the issue closed as not planned with a verdict. A durable rejection also lands a comment-only PR recording the decision in the code. ⚠️ Merges to `main`, rewrites and closes issues unattended. |
| `resolve-issues` | `/dev-skills:resolve-issues [<max-issues>]` | resolve-issue × each open issue | Clears the backlog oldest first, re-syncing `main` between issues. Skips epics, claimed and held issues. Default cap 5. ⚠️ Merges to `main` and closes issues unattended. |
| `simplify-loop` | `/dev-skills:simplify-loop [<max-iterations>] [area]` | (propose-issues `simplification` → resolve-issue) × N | One simplification per pass, re-analyzing the merged tree each time. Default cap 3, rejected proposals included. ⚠️ Merges to `main` and closes issues unattended. |

⚠️ The orchestrators that merge are only safe where `main` is protected by **required CI that runs real tests**. They wait for green checks; with no meaningful checks, everything is green.

## Output style

`i-have-adhd` shapes replies for an ADHD reader: the next action first, multi-step work numbered, state restated each turn, tangents held back, concrete time estimates. It is a plugin [output style](https://code.claude.com/docs/en/output-styles), not a skill, so it applies to every reply in the main conversation while it is selected. Subagents don't get it, except forks, which inherit the main conversation's system prompt.

To have it on in every session on a repo, add `outputStyle` to the committed `.claude/settings.json` from the install step above:

```json
{
  "extraKnownMarketplaces": {
    "dev-skills": {
      "source": { "source": "github", "repo": "cesarte789/dev-skills" }
    }
  },
  "enabledPlugins": {
    "dev-skills@dev-skills": true
  },
  "outputStyle": "dev-skills:i-have-adhd"
}
```

To use it on your machine only, pick it under `/config` → Output style. That saves it to the project's `.claude/settings.local.json`, so it stays on for later sessions there. Any pick there, this style or another, overrides the committed `outputStyle` until you delete the key from `settings.local.json`. Selecting it replaces any other output style, since only one can be active at a time. While it is selected, saying "stop adhd mode" makes Claude reply in its default style for the rest of the current session; the selection itself stays.

## What the consuming repo must provide

- A `CLAUDE.md` stating the conventions and **the exact test/build commands**, including a narrow per-area command if there is one. `polish-pr` and `generate-pr-from-issue` run whatever it names.
- Anything that must be regenerated alongside a change (generated types, schema snapshots) and the command that does it.
- Where docs live and which doc owns which fact, if there is more than a README.
- Branch protection on `main` requiring CI, before running any merging orchestrator.
- Optionally, CI that skips draft PRs and runs on `ready_for_review`. `generate-pr-from-issue` opens PRs as drafts and `polish-pr` marks them ready only once review is clean, so such CI runs once per PR rather than once per review round.

## Why the skills don't call `/review` or `/code-review`

A skill can invoke only what the session's Skill listing shows. `security-review`, `simplify` and `loop` are built in and listed, so these skills may call them (`polish-pr` runs `security-review` on security-sensitive diffs). `/review` never appears in the listing, and `/code-review` is present in some sessions and not others, so nothing here depends on either. `polish-pr` reviews through `review-diff`'s subagents instead, which is what lets the orchestrators run unattended.

## GitHub access

The skills are written against the `gh` CLI. Cloud sessions on `claude.ai/code` may not have `gh`; each skill tells the agent to use the GitHub MCP tools instead in that case.

## Provenance

`output-styles/i-have-adhd.md` is by [Ayoub Ghriss](https://github.com/ayghri), adapted from [ayghri/i-have-adhd@4c76175](https://github.com/ayghri/i-have-adhd/tree/4c76175) (v0.3.0) under its MIT license (`output-styles/LICENSE`): the skill frontmatter became output-style frontmatter, and the Persistence section and one harness reference were reworded for an output style.
