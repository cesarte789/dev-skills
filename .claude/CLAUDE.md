# dev-skills

A Claude Code plugin: skills under `skills/`, one output style under `output-styles/`. No build and no test suite; the checks below are the gate.

## Before pushing

```bash
scripts/check.sh origin/main
```

It runs both `claude plugin validate … --strict` commands, parses every `output-styles/*.md` frontmatter, and fails when `skills/` or `output-styles/` changed without a version bump. CI (`.github/workflows/validate.yml`) runs the same script on every PR and on `main`. Needs `claude`, `python3` and PyYAML.

## Versioning

Bump `version` in `.claude-plugin/plugin.json` in the same change as any edit under `skills/` or `output-styles/`: patch for a fix or simplification, minor for a new or changed behavior. Claude Code compares that field, not the git commit, so an unbumped change never reaches existing installs. Docs-only changes need no bump.
