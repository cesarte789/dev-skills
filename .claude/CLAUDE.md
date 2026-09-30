# dev-skills

<!-- Lives in .claude/ rather than the repo root: a root CLAUDE.md fails `claude plugin validate … --strict`, which says plugins don't load it. Claude Code still loads this one as project memory. -->

A Claude Code plugin: skills under `skills/`, one output style under `output-styles/`. No build and no test suite; the checks below are the gate.

## Before pushing

```bash
scripts/check.sh origin/main
```

It runs both `claude plugin validate … --strict` commands, parses every `output-styles/*.md` frontmatter, and fails when `skills/`, `output-styles/` or `.claude-plugin/plugin.json` changed without a higher version. CI (`.github/workflows/validate.yml`) runs the same script on every PR against its base, and on every push to `main` against the previous tip. Needs `claude`, `python3` and PyYAML.

## Versioning

Raise `version` in `.claude-plugin/plugin.json` in the same change as any edit to what the plugin ships (`skills/`, `output-styles/`, `plugin.json` itself): patch for a fix or simplification, minor for a new or changed behavior. Claude Code compares that field, not the git commit, so an unbumped change never reaches existing installs. Docs-only changes need no bump.
