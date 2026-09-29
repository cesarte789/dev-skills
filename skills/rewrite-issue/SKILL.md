---
name: rewrite-issue
description: >-
  Clean up a vague GitHub issue, or split an epic into actionable sub-task issues.
  Use when an issue needs sharpening before work starts. Pass the issue number
  (e.g. "42").
---

# Rewrite issue

> Commands below use the `gh` CLI. If `gh` isn't available in this session, do
> the same operations with the GitHub MCP tools (`mcp__github__*`) instead.

Clarify an issue without changing its intent. **Preserve the original author's
meaning** — clarify and structure, don't add new requirements.

## 1. Read the issue

```bash
gh issue view <N> --json number,title,body,labels,comments
```

## 2. Decide: single task or epic

Use judgment. **Prefer a single, comprehensive issue.** Only split into an epic
when the request is clearly several distinct, actionable engineering tasks that
cannot reasonably land in one pull request.

## 3a. If it's a single task — rewrite in place

- Rewrite the body to state the primary objective clearly and briefly.
- Give it a concise conventional title (`feat: ...`, `fix: ...`, `refactor: ...`).
- Preserve the original first: post the original title/body as a comment, then
  update the issue.

```bash
gh issue comment <N> --body "_Original issue, preserved before rewrite:_

**<original title>**

<original body>"
gh issue edit <N> --title "<new title>" --body "<rewritten body>"
```

## 3b. If it's an epic — split into sub-tasks

- Break the work into smaller, concrete sub-tasks, each resolvable entirely with
  code (no research/design-only tasks). Order them logically for implementation.
- Create one issue per sub-task; reference the parent.
- Turn the parent into a tracking issue listing the sub-tasks, then close it if it
  no longer holds standalone work.

```bash
gh issue create --title "<sub-task title>" --body "<body>

Part of #<N>."
# repeat per sub-task, then update the parent body with the checklist of new issues
```

## 4. Report

List what you changed: the rewritten title, or the sub-task issue numbers/URLs you
created. If the issue is already clear and actionable, say so and leave it
untouched rather than churning it.
