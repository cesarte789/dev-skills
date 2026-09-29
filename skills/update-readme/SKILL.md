---
name: update-readme
description: >-
  Scan the codebase and bring the project docs (README.md, plus any feature
  docs such as docs/features.md and ARCHITECTURE.md where present) back in sync with how the code actually behaves and
  is set up. Use when docs have drifted, or as a deliberate "refresh the docs"
  pass. Optionally pass an area to focus on.
---

# Update README

> Commands below use the `gh` CLI. If `gh` isn't available in this session, do
> the same operations with the GitHub MCP tools (`mcp__github__*`) instead.

Reconcile the documentation with reality. Update **only what is actually stale** —
do not rewrite prose that is already correct, and do not invent content.

## 1. Read the current docs

Read `README.md` and, where they exist, the feature docs (e.g. `docs/features.md`)
and `ARCHITECTURE.md`. Note
what they claim about features, setup/installation, configuration, commands, and
how to run/deploy.

## 2. Compare against the code

Explore the codebase to find where the docs and reality diverge. Look for:
- Setup/run/deploy steps that no longer match (scripts, env vars, commands, ports).
- Features described that were removed, shipped features not documented, or a
  map line that no longer says what its entry does.
- Config/options (env vars, settings) that changed.
- Endpoints, modules, or architecture described inaccurately.

If an area was given as an argument, scope the pass to it; otherwise review the
whole project. Honor `CLAUDE.md` wherever it says which doc owns which kind of fact
(feature descriptions, setup, deployment, API contracts) — put each fix there.

## 3. Make minimal, accurate edits

Edit the docs to fix the drift you found. Match the existing tone, structure, and
formatting. Keep changes surgical. Do not touch the generated section/notice of any
auto-generated file. If `CLAUDE.md` prescribes a format
for feature lines (for example a README map linking into `docs/features.md`
headings), follow it exactly, and keep linked lines, headings and anchors in step
when an entry is added, renamed or reordered. If nothing is
stale, say so and change nothing — docs left unchanged because they are correct
is the right outcome.

## 4. Land it via a PR

Every change goes through a PR. If you are on `main`,
branch first:

```bash
git fetch origin --quiet && git checkout -b docs/refresh-readme origin/main
```

Commit with a conventional-commit message (`docs: ...`), push, and open the PR:

```bash
git push -u origin <branch>
gh pr create --title "docs: refresh the docs to match current behavior" --body "<what drifted and was corrected>"
```

End the commit message with the repo's Co-Authored-By trailer. Report the PR URL
and a short list of what you corrected. If you are already on a feature branch
whose work changed behavior, update the docs in place on that branch instead of
opening a separate PR.
