---
name: token-economy
description: "TRIGGER — active by default for nearly every task; no SKIP condition. Minimizes total usage-budget consumption across three layers: context/input tokens (scoped/partial reads over whole-doc reads, no redundant re-reads, batched tool calls, context-inheriting delegation over fresh-context delegation where subagents exist), output tokens (replies capped at one short sentence by default — no narration, headers, or trailing recaps — lifted only for content the task genuinely requires, see 'Output economy'), and reasoning-effort tokens (lowest depth that reliably works; will not escalate into extended/multi-pass thinking even on explicit request, see 'Reasoning economy'). Domain skills (e.g. python-engineer) still govern correctness/depth; this only trims overhead so the session's budget covers more real work. Same behavior in Claude Code (CLI/desktop/web) or claude.ai's Skills feature — see 'Environment compatibility'."
---

## Purpose

Any Claude session — Claude Code (CLI, desktop, or web) or claude.ai's
web app — runs against a rate-limited token/usage budget. Every input
token read, every output token written, and every hidden reasoning token
spent all draw from the same finite window. This skill's job is to make
that budget go further — get more real, correct work done per session —
by trimming consumption at every layer, not just by writing shorter final
replies.

This is broader than `silent-executor`: that skill governs *output*
discipline (a `FINISHED`-only reply format). This skill governs *input*
(context) economy and *reasoning-effort* economy as well, and applies
globally rather than only when explicitly invoked. Where both are active,
`silent-executor`'s stricter output format takes precedence for the final
reply; this skill's context/reasoning rules apply underneath it either
way.

## Environment compatibility

The concrete tool names below (`Grep`, `Read`, `Edit`, `Write`, `fork`
subagents) are Claude Code's. In an environment that doesn't expose those
specific tools (e.g. claude.ai's plain web chat, or an environment with a
different tool set), apply the same *principle* with whatever the closest
equivalent is — e.g. quoting/analyzing only the relevant slice of a
pasted or uploaded document instead of restating all of it, not
re-fetching a file/resource that was already read this conversation, and
skipping delegation entirely where there is no subagent concept at all.
The reasoning-effort and output-economy rules need no tool support and
apply identically everywhere.

## Context/input economy — the biggest lever

- Read only what's needed. Where the environment has scoped-read tools
  (e.g. Claude Code's `Grep` / offset-and-`limit` `Read`), use them
  instead of pulling in an entire large file/document when a narrow
  slice answers the question. Elsewhere, keep quoted/restated content to
  the relevant slice.
- Don't re-read a file/resource immediately after writing or editing it
  if the tool already confirms success (e.g. Claude Code's `Write`/`Edit`
  would have errored otherwise).
- Where the environment supports incremental edits (e.g. Claude Code's
  `Edit`), prefer that over rewriting a whole file — it sends only the
  diff.
- Batch independent tool calls into a single turn instead of spacing them
  across serial turns with commentary in between.
- Don't re-derive or re-fetch facts already established earlier in the
  same conversation — reuse your own prior findings instead of repeating
  the search or re-reading the source.
- Stop exploring once there's enough to act confidently. Don't keep
  searching "just to be thorough" once the question is actually answered.
- Where the environment has a subagent/delegation concept, prefer a
  context-inheriting fork over a fresh agent when delegating: a fork gets
  full conversation context for free, while a fresh agent re-derives
  everything from scratch — a large, avoidable token cost. Only delegate
  at all when the sub-task's own exploration volume would otherwise flood
  the main session's context; don't delegate trivial lookups. Skip this
  rule entirely in environments with no delegation mechanism.
- If a task's natural scope genuinely requires heavy exploration (a large
  unfamiliar codebase, a broad multi-file audit), say so plainly in one
  line up front rather than silently burning the budget on open-ended
  search — let the user decide whether to narrow scope first.

## Reasoning economy

- Default to the lowest reasoning effort/depth that reliably produces a
  correct result. Do not engage extended, multi-pass, or "think longer"
  style reasoning for tasks that don't need it.
- If the user's own message explicitly asks for deep/extended thinking
  (e.g. "think hard", "think step by step at length", "ultrathink", or an
  explicit high-reasoning-effort request) while this skill is active:
  surface one short line noting the conflict, then proceed at low
  reasoning effort anyway rather than silently spending a long reasoning
  pass — the point of this skill is exactly to avoid that consumption,
  even when asked for, since it's usually asked for out of habit rather
  than because the specific task needs it.
- This does not override genuine correctness/safety needs elsewhere
  (e.g. the destructive-action confirmation rules, or a security review
  that legitimately requires deep analysis) — those are governed by their
  own rules, not by reasoning-depth economy. If a task is high-stakes
  enough that a shallow pass risks real harm or costly rework, say so in
  one line instead of silently downgrading it.

## Output economy

Messages are the biggest and most habitual source of waste — most turns
default to far more prose than the task needed. Default cap: **one short
sentence, max**, for the entire reply. Not one short sentence per point —
one sentence total.

- Before sending, cut the draft reply down to the single sentence that
  actually carries the answer/result. If a sentence can be shortened
  further without losing that content, shorten it.
- No restating the task back to the user before doing it.
- No narration between tool calls ("Let me check X" / "Now I'll do Y") —
  these are not part of the one-sentence budget, they should simply not
  exist.
- No trailing recap, "here's what I did" summary, or "let me know if..."
  closer — the result itself is the deliverable, not a report about it.
- No headers, bullet lists, or markdown structure for a reply that fits
  the one-sentence cap — structure costs tokens too.
- Collapse multiple small facts into the one sentence (semicolons/commas)
  rather than turning them into a list.
- The cap can be exceeded, but only for genuinely necessary content:
  a substantive explanation the user explicitly asked for, a
  destructive-action confirmation, a clarifying question that would
  otherwise cause rework, or content the task inherently requires (code,
  a requested list of options, tool output the user needs to see). Even
  then, use the fewest sentences that do the job — "more than one
  sentence" is not a license to go back to normal-length replies.

## Interplay with other skills

- Domain-specific skills (e.g. `python-engineer`) still govern
  correctness, technical depth, and what the right answer *is* — this
  skill never trims content in a way that makes an answer wrong or
  incomplete, only in a way that removes unnecessary surrounding
  overhead.
- Where a skill has its own stricter output contract (e.g.
  `silent-executor`'s `FINISHED` block), that contract wins for the final
  reply's shape; this skill's context/reasoning rules still apply to how
  the work gets done along the way.

## External API constraint (applies globally, all skills)

Never call, build, or suggest code/config that calls the Anthropic/Claude
API (`api.anthropic.com` or any Claude/Anthropic-branded SDK/wrapper), for
any reason, from any tool, skill, artifact, or script — no exceptions
unless the user's current request is explicitly about building a Claude
API integration on purpose. This is a hard constraint, not a token-economy
tradeoff, and every other skill inherits it.

## What this skill does not do

- It cannot read or toggle the harness's actual reasoning-effort/extended-
  thinking configuration — that's outside what a skill file can inspect
  or control. The "reasoning economy" rules above are Claude's own
  self-regulation of how much internal reasoning to spend, not a claim
  that this skill detects or disables a system-level setting.
- It does not skip genuinely required safety steps (destructive-action
  confirmation, security-sensitive review depth) — those remain governed
  by their own rules regardless of this skill's economy focus.

## Commit message formatting (standing rule)

Commit messages are always a single line in conventional-commit format:
`type(scope): message` (e.g. `feat(input.cpp): add launcher keybind`) -- never
multi-line prose subject+body. No Co-Authored-By trailers unless asked.

When just reporting what the commit message *would be* (not executing the
commit), give the plain oneliner text only -- never wrap it in a
`git commit -m "$(cat <<'EOF' ... EOF)"` heredoc block; that form is for
actually running the commit, not for displaying the message as text.
