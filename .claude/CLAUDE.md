# dev-skills

<!-- Lives in .claude/ rather than the repo root: a root CLAUDE.md fails `claude plugin validate … --strict`, which says plugins don't load it. Claude Code still loads this one as project memory. -->

A Claude Code plugin: skills under `skills/`, one output style under `output-styles/`. No build and no test suite; the checks below are the gate, plus a small eval suite run by hand.

## Before pushing

```bash
scripts/check.sh origin/main
```

It runs both `claude plugin validate … --strict` commands, parses every `output-styles/*.md` frontmatter, shape-checks every `evals/**/case.yaml` (parse only, never run — see [Evals](#evals)), fails on a `gh` or `git` command outside the `## Operations` section of a skill that has one, fails when the skills' `<!-- repo-conventions -->` blocks differ or a skill names the repo conventions without carrying one (each skill loads on its own, so the rule is inlined, not shared), and fails when `skills/`, `output-styles/` or `.claude-plugin/plugin.json` changed without a higher version. CI (`.github/workflows/validate.yml`) runs the same script on every PR against its base, and on every push to `main` against the previous tip. Mark its `validate` check as required on `main` so the merging orchestrators have something real to wait for. Needs `claude`, `python3` and PyYAML.

This plugin is public and its skills run in private repos. To keep their names and data out of it, list terms one per line in `~/.config/dev-skills/private-terms` (or the file `DEV_SKILLS_PRIVATE_TERMS` names): the check then fails when one appears in a tracked or untracked file or path, or in any commit since the base ref (HEAD without one): its files, paths, message, author or committer, or the branch name. It prints each matching line. Matching ignores case for ASCII letters only, so list accented terms in each case they appear. The list stays outside the repo so it never leaks either; CI has none and skips the step.

## Why the skills don't call `/review` or `/code-review`

A skill can invoke only what the session's Skill listing shows. `security-review`, `simplify` and `loop` are built in and listed, so these skills may call them (`polish-pr` runs `security-review` on security-sensitive diffs). `/review` never appears in the listing, and `/code-review` is present in some sessions and not others, so nothing here depends on either. `polish-pr` reviews through `review-diff`'s subagents instead, which is what lets the orchestrators run unattended.

## Evals

`scripts/check.sh` checks shape, not behavior — including each `evals/**/case.yaml`: that it parses, carries a non-empty `name`, a prompt (inline `execution.prompt` or a sibling `prompt.md`) and graders (an inline `graders` list or a sibling `graders/*.md`), that every inline grader has a `name` and a type the eval CLI accepts, and that a `context.scaffold_script` names an existing file. It accepts whatever the framework does, so a valid case is never failed. That is all parse-time; the cases themselves are never run from the check (CI holds no secrets and a run needs a sandbox), so a broken case is caught at PR time instead of at the next by-hand run. `evals/review-diff/` pins the one verdict an edit could silently break: `review-diff`'s `no findings`, which lets `polish-pr` end clean and the orchestrators merge to `main` unattended. Its cases require a planted bug to be reported and a steering comment to come back as a `steering:` finding, without the review editing the committed files, creating files, or moving HEAD or a branch.

`evals/evaluate-issue/` pins the `dev-skills-ops` override: a sample one in the scaffold replaces every operation `evaluate-issue` uses with local files, and the run must use it and never `gh`. A human runs these, by hand, before bumping the version on a change to `review-diff` or to either skill's Operations section (`--case 'evaluate-issue/*'` for the second). The cases run that skill alone, so they say nothing about `polish-pr`. An agent or skill never runs it, and it is not part of any PR's checks. It bills real sessions on the credential, and `--scaffold` runs the cases' bash as you, so read any changed `scaffold.sh` first:

```bash
claude plugin eval . --case 'review-diff/*' --scaffold --trust-plugin --allow-tools Bash --ablation none --no-publish
```

`--ablation none` skips the default no-plugin baseline arm, which cannot run the skill and would double the cost. `review-diff` needs Bash for `git`. With Bash granted, a run is refused unless Claude Code's sandbox backend is installed (`bubblewrap` and `socat` on Linux). CI holds no secrets, so it never runs this. Results land in `evals/results/` (git-ignored). Installs copy `evals/` with the rest of the repo but never load it, so changing it needs no version bump.

## Writing skills

Text a skill hands to a subagent (a contract, a checklist, a prompt) must stand on its own: the subagent sees only what it is given, so never name a term, file or command there that only another part of the skill defines.

A new way for a skill to stop must end in an outcome its callers already handle (`resolve-issue`'s outcome names, `review-diff`'s `review failed:`), so an unattended orchestrator never stalls on it or misreads it.

Text inlined into several skills must hold in each one: read every skill it lands in for an instruction it contradicts or forbids.

## Versioning

Raise `version` in `.claude-plugin/plugin.json` in the same change as any edit to what the plugin ships (`skills/`, `output-styles/`, `plugin.json` itself): patch for a fix or simplification, minor for a new or changed behavior. Claude Code compares that field, not the git commit, so an unbumped change never reaches existing installs. Docs-only changes need no bump.
