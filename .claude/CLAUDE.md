# dev-skills

<!-- Lives in .claude/ rather than the repo root: a root CLAUDE.md fails `claude plugin validate … --strict`, which says plugins don't load it. Claude Code still loads this one as project memory. -->

A Claude Code plugin: skills under `skills/`, one output style under `output-styles/`. No build and no test suite; the checks below are the gate, plus a small eval suite run by hand.

## Before pushing

```bash
scripts/check.sh origin/main
```

It runs both `claude plugin validate … --strict` commands, parses every `output-styles/*.md` frontmatter, shape-checks every `evals/**/case.yaml` (parse only, never run — see [Evals](#evals)), and fails when `skills/`, `output-styles/` or `.claude-plugin/plugin.json` changed without a higher version. CI (`.github/workflows/validate.yml`) runs the same script on every PR against its base, and on every push to `main` against the previous tip. Mark its `validate` check as required on `main` so the merging orchestrators have something real to wait for. Needs `claude`, `python3` and PyYAML.

## Why the skills don't call `/review` or `/code-review`

A skill can invoke only what the session's Skill listing shows. `security-review`, `simplify` and `loop` are built in and listed, so these skills may call them (`polish-pr` runs `security-review` on security-sensitive diffs). `/review` never appears in the listing, and `/code-review` is present in some sessions and not others, so nothing here depends on either. `polish-pr` reviews through `review-diff`'s subagents instead, which is what lets the orchestrators run unattended.

## Evals

`scripts/check.sh` checks shape, not behavior — including each `evals/**/case.yaml`: that it parses, carries a non-empty `name`, `execution.prompt` and `graders` list, that every grader has a `name` and a known `type`, and that a `context.scaffold_script` names a file next to the case. That is all parse-time; the cases themselves are never run from the check (CI holds no secrets and a run needs a sandbox), so a broken case is caught at PR time instead of at the next by-hand run. `evals/review-diff/` pins the one verdict an edit could silently break: `review-diff`'s `no findings`, which lets `polish-pr` end clean and the orchestrators merge to `main` unattended. Its cases require a planted bug to be reported and a steering comment to come back as a `steering:` finding, without the review editing the committed files, creating files, or moving HEAD or a branch.

A human runs it, by hand, before bumping the version on a change to `review-diff`. The cases run that skill alone, so they say nothing about `polish-pr`. An agent or skill never runs it, and it is not part of any PR's checks. It bills real sessions on the credential, and `--scaffold` runs the cases' bash as you, so read any changed `scaffold.sh` first:

```bash
claude plugin eval . --case 'review-diff/*' --scaffold --trust-plugin --allow-tools Bash --ablation none --no-publish
```

`--ablation none` skips the default no-plugin baseline arm, which cannot run the skill and would double the cost. `review-diff` needs Bash for `git`. With Bash granted, a run is refused unless Claude Code's sandbox backend is installed (`bubblewrap` and `socat` on Linux). CI holds no secrets, so it never runs this. Results land in `evals/results/` (git-ignored). Installs copy `evals/` with the rest of the repo but never load it, so changing it needs no version bump.

## Versioning

Raise `version` in `.claude-plugin/plugin.json` in the same change as any edit to what the plugin ships (`skills/`, `output-styles/`, `plugin.json` itself): patch for a fix or simplification, minor for a new or changed behavior. Claude Code compares that field, not the git commit, so an unbumped change never reaches existing installs. Docs-only changes need no bump.
