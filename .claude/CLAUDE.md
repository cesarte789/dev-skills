# dev-skills

<!-- Lives in .claude/ rather than the repo root: a root CLAUDE.md fails `claude plugin validate … --strict`, which says plugins don't load it. Claude Code still loads this one as project memory. -->

A Claude Code plugin: skills under `skills/`, one output style under `output-styles/`. No build and no test suite; the checks below are the gate, plus a small eval suite run by hand.

## Before pushing

```bash
scripts/check.sh origin/main
```

It runs both `claude plugin validate … --strict` commands, parses every `output-styles/*.md` frontmatter, and fails when `skills/`, `output-styles/` or `.claude-plugin/plugin.json` changed without a higher version. CI (`.github/workflows/validate.yml`) runs the same script on every PR against its base, and on every push to `main` against the previous tip. Needs `claude`, `python3` and PyYAML.

## Evals

`scripts/check.sh` checks shape, not behavior. `evals/review-diff/` pins the one verdict an edit could silently break: `review-diff`'s `no findings`, which lets `polish-pr` end clean and the orchestrators merge to `main` unattended. Its cases require a planted bug to be reported and a steering comment to come back as a `steering:` finding, without the review editing `pager.py`, creating files or running a git write.

A human runs it, by hand, before bumping the version on a change to `review-diff` or `polish-pr`. An agent or skill never runs it, and it is not part of any PR's checks. It bills real sessions on the credential, and `--scaffold` runs the cases' bash as you, so read any changed `scaffold.sh` first:

```bash
claude plugin eval . --case 'review-diff/*' --scaffold --trust-plugin --allow-tools Bash --ablation none --no-publish
```

`--ablation none` skips the default no-plugin baseline arm, which cannot run the skill and would double the cost. `review-diff` needs Bash for `git`. With Bash granted, a run is refused unless Claude Code's sandbox backend is installed (`bubblewrap` and `socat` on Linux). CI holds no secrets, so it never runs this. Results land in `evals/results/` (git-ignored). Installs copy `evals/` with the rest of the repo but never load it, so changing it needs no version bump.

## Versioning

Raise `version` in `.claude-plugin/plugin.json` in the same change as any edit to what the plugin ships (`skills/`, `output-styles/`, `plugin.json` itself): patch for a fix or simplification, minor for a new or changed behavior. Claude Code compares that field, not the git commit, so an unbumped change never reaches existing installs. Docs-only changes need no bump.
