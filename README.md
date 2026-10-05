# dev-skills

Claude Code skills that automate the issue → PR → review → merge loop, plus one output style, packaged as a plugin so every repo uses the same copy instead of drifting forks.

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

Update with `claude plugin marketplace update dev-skills`, then `claude plugin update dev-skills@dev-skills`.

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
| `resolve-issue` | `/dev-skills:resolve-issue <N>` | vet → rewrite-issue (if vague) → evaluate-issue (if it grows the system) → generate-pr-from-issue → polish-pr → merge | Any issue → a merged PR, or the issue closed as not planned with a verdict. A durable rejection also lands a comment-only PR recording the decision in the code, merged only on green CI: without CI it stays open and the run stops. ⚠️ Merges to `main`, rewrites and closes issues unattended. |
| `resolve-issues` | `/dev-skills:resolve-issues [<max-issues>]` | resolve-issue × each open issue | Clears the backlog oldest first, re-syncing `main` between issues. Skips epics, claimed and held issues. Default cap 5. ⚠️ Merges to `main` and closes issues unattended. |
| `simplify-loop` | `/dev-skills:simplify-loop [<max-iterations>] [area]` | (propose-issues `simplification` → resolve-issue) × N | One simplification per pass, re-analyzing the merged tree each time. Default cap 3, rejected proposals included. ⚠️ Merges to `main` and closes issues unattended. |

## Output style

`i-have-adhd` is an [output style](https://code.claude.com/docs/en/output-styles), not a skill: it shapes every reply for an ADHD reader (next action first, numbered steps, no tangents). Turn it on for a repo by adding `"outputStyle": "dev-skills:i-have-adhd"` to the `.claude/settings.json` above, or for yourself under `/config` → Output style.

## What the consuming repo must provide

- A `CLAUDE.md` stating the conventions and **the exact test/build commands**, including a narrow per-area command if there is one. `polish-pr` and `generate-pr-from-issue` run whatever it names.
- Anything that must be regenerated alongside a change (generated types, schema snapshots) and the command that does it.
- Where docs live and which doc owns which fact, if there is more than a README.
- Branch protection on `main` requiring CI that runs real tests, before running any merging orchestrator: they wait for green checks, and with no meaningful checks everything is green.
- Optionally, CI that skips draft PRs and runs on `ready_for_review`. `generate-pr-from-issue` opens PRs as drafts and `polish-pr` marks them ready only once review is clean, so such CI runs once per PR rather than once per review round.

## More

- Contributing (checks, versioning, evals): [`.claude/CLAUDE.md`](.claude/CLAUDE.md).
- `output-styles/i-have-adhd.md` is adapted from [ayghri/i-have-adhd@4c76175](https://github.com/ayghri/i-have-adhd/tree/4c76175) by Ayoub Ghriss, under its MIT license (`output-styles/LICENSE`).
