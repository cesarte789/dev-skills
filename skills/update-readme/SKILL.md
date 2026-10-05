---
name: update-readme
description: >-
  Scan the codebase and bring the project docs (README.md, plus any feature
  docs such as docs/features.md and ARCHITECTURE.md where present) back in sync with how the code actually behaves and
  is set up, and trim the README down to its core. Use when docs have drifted or
  grown, or as a deliberate "refresh the docs" pass. Optionally pass an area to
  focus on.
---

# Update README

> Commands below use the `gh` CLI. If `gh` isn't available in this session, do
> the same operations with the GitHub MCP tools (`mcp__github__*`) instead.

The goal is docs that say what the code actually does, and nothing else. Every
claim in the README and the feature docs must match something that exists in the
code today: fix what is stale, delete what describes code that is gone, and do not
invent content. Within that, keep the README to its core.

## The README core

The README holds only:
- what the project is, in a line or two;
- how to install or set it up;
- how to run or use it (the commands);
- where the detail lives, if anywhere (feature docs, `ARCHITECTURE.md`, `CLAUDE.md`).

Test every line: **would a newcomer fail to install, set up or use the project
without it?** If not, it does not belong in the README, however correct it is.

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

## 3. Fix the drift and trim the README

Edit the docs to fix the drift you found. Then apply the core test to every line
of the README, correct or not. A line that fails it:
- moves to the doc that owns that kind of fact (feature docs, `ARCHITECTURE.md`,
  per `CLAUDE.md`) when it is still relevant and indispensable — true, and not
  something the code, `--help` or another doc already says;
- stays in the README when it is indispensable but the repo keeps no such doc;
- is deleted otherwise.

Add to the README only what passes the test. A pass that leaves it longer than it
was must be able to say which new line a newcomer would fail without. Match the
existing tone and formatting. Do not touch the generated section/notice of any
auto-generated file. If `CLAUDE.md` prescribes a format
for feature lines (for example a README map linking into `docs/features.md`
headings), follow it exactly, and keep linked lines, headings and anchors in step
when an entry is added, renamed or reordered. If nothing is
stale and the README is already its core, say so and change nothing.

## 4. Land it via a PR

Every change goes through a PR. If you are on `main`,
branch first:

```bash
git fetch origin --quiet && git checkout -b docs/refresh-readme origin/main
```

Commit with a conventional-commit message (`docs: ...`), push, and open the PR:

```bash
git push -u origin <branch>
gh pr create --title "docs: refresh the docs to match current behavior" --body "<what drifted and was corrected, and what was cut or moved>"
```

End the commit message with the repo's Co-Authored-By trailer. Report the PR URL
and a short list of what you corrected, cut and moved. If you are already on a feature branch
whose work changed behavior, update the docs in place on that branch instead of
opening a separate PR.
