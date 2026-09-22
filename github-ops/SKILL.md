---
name: github-ops
description: |
  Manage GitHub issues, pull requests, Actions runs, and releases across your
  repos using the `gh` CLI. Use when asked to list/create/comment on issues
  or PRs, check CI/Actions run status, view workflow logs, cut a release, or
  find/triage repos by activity. Local reimplementation of
  github/github-mcp-server using `gh` (already authenticated) — no API
  token handling, no MCP server process.
metadata:
  origin: "local reimplementation, inspired by https://github.com/github/github-mcp-server"
---

# GitHub Ops (gh CLI)

All operations go through the already-authenticated `gh` CLI — never construct
raw GitHub REST/GraphQL calls or ask for a token. Check auth once per session:

```bash
gh auth status
```

## Repo discovery

```bash
gh repo list <owner> --limit 200 --json name,description,updatedAt,isPrivate,pushedAt
gh repo view <owner>/<repo> --json name,description,defaultBranchRef,pushedAt
```

Sort/filter client-side (e.g. with `python3 -c` or `jq` if present) rather than
paging manually — `gh` returns full JSON in one call.

## Issues

```bash
gh issue list -R <owner>/<repo> --state open --limit 30 --json number,title,labels,updatedAt
gh issue view <number> -R <owner>/<repo>
gh issue create -R <owner>/<repo> --title "..." --body "..."
gh issue comment <number> -R <owner>/<repo> --body "..."
gh issue close <number> -R <owner>/<repo>
```

## Pull requests

```bash
gh pr list -R <owner>/<repo> --state open --json number,title,author,reviewDecision,statusCheckRollup
gh pr view <number> -R <owner>/<repo>
gh pr diff <number> -R <owner>/<repo>
gh pr checks <number> -R <owner>/<repo>
gh pr create -R <owner>/<repo> --title "..." --body "..." --base main
gh pr merge <number> -R <owner>/<repo> --squash
```

Creating, merging, or closing a PR is a shared-state, hard-to-reverse action —
confirm with the user before running create/merge/close, same as any git push.

## Actions / CI

```bash
gh run list -R <owner>/<repo> --limit 10 --json databaseId,status,conclusion,workflowName,createdAt
gh run view <run-id> -R <owner>/<repo>
gh run view <run-id> -R <owner>/<repo> --log-failed   # only the failing step's log
gh workflow list -R <owner>/<repo>
gh workflow run <workflow> -R <owner>/<repo>            # confirm first — triggers a real run
```

Prefer `--log-failed` over `--log` to avoid dumping an entire successful run's
log into context.

## Releases

```bash
gh release list -R <owner>/<repo> --limit 10
gh release view <tag> -R <owner>/<repo>
gh release create <tag> -R <owner>/<repo> --title "..." --notes "..."
```

Confirm the tag and notes with the user before `gh release create` — releases
are public and hard to fully undo.

## Cross-repo triage

For "what needs attention across my repos" style requests, loop `gh issue list`
/ `gh pr list` / `gh run list --status failure` over `gh repo list <owner> --json name`
and summarize — don't dump raw JSON, extract the handful of rows that matter.

## Output discipline

- Always pass `--json <fields>` with only the fields needed, never the default
  human table plus a second JSON call.
- Cap `--limit` to what's actually needed (10–30), not the max.
- Summarize in prose; don't paste raw `gh` JSON into the reply.
