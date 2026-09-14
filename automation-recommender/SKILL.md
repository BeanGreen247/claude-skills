---
name: automation-recommender
description: |
  Analyzes the current project and recommends the top hooks, skills,
  subagents, and slash commands worth setting up for it — read-only, no
  files modified. Use when asked to "recommend automations", "help me set
  up Claude Code for this project", or "what hooks/skills should I use
  here". Local reimplementation of the official claude-code-setup plugin.
metadata:
  origin: "local reimplementation, inspired by https://github.com/anthropics/claude-plugins-official/tree/main/plugins/claude-code-setup"
---

# Automation Recommender

Scans a codebase and recommends the highest-leverage Claude Code automations for it. Read-only — analyze, report, and get the user's go-ahead before creating anything (creating hooks/skills/subagents is a `update-config`-skill job, not this one).

## Workflow

1. **Fingerprint the project.** Language(s), framework, package manager, test runner, CI config, monorepo vs single-package, whether it's a library/service/CLI/frontend. Read `package.json`/`pyproject.toml`/`go.mod`/etc. and any existing `CLAUDE.md`.
2. **Recommend across five categories, top 1-2 picks per category, not an exhaustive list:**
   - **Hooks** — e.g. auto-format on save (prettier/black/gofmt) if a formatter is configured but not enforced; auto-lint; a pre-commit block on files matching `.env`/secrets patterns; a test-runner hook on file save for TDD-heavy repos.
   - **Skills** (this session's local skill library, `~/.claude/skills/`) — match existing skills to what the project actually needs: e.g. `security-and-hardening` + `security-review` for anything with auth/payments/user data, `anti-ai-slop-audit` + `design-craft` for a frontend, `python-engineer` for a Python web/systems project, `ci-cd-and-automation` if CI config is thin or missing.
   - **Subagents** — specialized reviewers worth having on tap: a security-focused reviewer for anything handling payments/PII, an accessibility reviewer for a public-facing frontend, a performance reviewer for anything with hot paths/high traffic.
   - **Slash commands** — repeatable workflows worth turning into a command: `/test`, `/pr-review`, project-specific deploy or release steps that currently live only in a README or in someone's head.
   - **MCP servers** — only recommend one if a real local/free option doesn't already cover it; for this environment, note that web search and browser automation are already covered locally (`websearch`, `browser` skills) so an MCP isn't needed for those.
3. **Justify each recommendation with a concrete observation from the scan** ("no `.prettierrc` enforcement hook, but prettier is a devDependency" — not a generic "you should have linting").
4. **Present as a short list**, not a report document — this is a conversation output, not a file to write, unless the user asks to save it.
5. Never create/modify hooks, settings, or files during this pass. If the user picks a recommendation to actually set up, hand off to the `update-config` skill for hooks/permissions/settings changes.
