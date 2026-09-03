---
name: skill-safety-review
description: Security-scan Claude / Claude Code agent skills with NVIDIA SkillSpector before trusting or installing them. Use when adding, updating, auditing, or reviewing a skill (a SKILL.md plus its scripts/assets), when vetting a third-party or downloaded skill, or when asked to check that skills are safe. Runs static analysis only by default — never calls a paid or Anthropic-branded API.
---

# Skill Safety Review

## Overview

Agent skills load with implicit trust: their `SKILL.md` text becomes model
instructions and their bundled scripts run with the user's privileges. A
malicious or careless skill can carry prompt injection, data-exfiltration
steps, credential probes, or destructive commands. This skill gates that
risk by running [NVIDIA SkillSpector](https://github.com/NVIDIA/skillspector)
(71 vuln patterns / 17 categories: prompt injection, data exfiltration,
privilege escalation, supply chain, excessive agency, output handling,
system-prompt leakage, memory poisoning, tool misuse, rogue agent,
anti-refusal, trigger abuse, dangerous code AST, taint tracking, YARA
signatures, MCP least-privilege, MCP tool poisoning) over one skill or a
whole skill library, then triaging the report.

## When to Use

- Before adding a new skill to `~/.claude/skills/` or a project's skills dir.
- Before running or trusting any skill downloaded from a third party, a
  gist, a repo, or a zip.
- When updating an existing skill — re-scan and diff against its baseline.
- When asked to "check the skills are safe", audit the skill library, or
  review a `SKILL.md` for security.
- As a pre-commit / CI gate on a repo that ships skills.

## Hard constraints

- **Default to `--no-llm` (static analysis only).** SkillSpector's optional
  semantic stage calls an external LLM. Do **not** enable it with the
  `anthropic` / `anthropic_proxy` / `bedrock` providers or any
  Anthropic-branded / paid endpoint. LLM mode is opt-in only, only with a
  provider the user has explicitly approved, and never as the default.
- Treat SkillSpector findings as **input for human judgement**, not a
  verdict. Documentation-heavy skills (security guides, git guides) trip
  keyword heuristics ("sudo", "credential", "curl | sh") with legitimate
  prose — confirm each finding against the cited line before reporting it
  as real.
- Never edit or "fix" a scanned skill silently. Report; let the user decide.

## Procedure

1. **Ensure the scanner is available** (one-time, user-approved install):
   ```bash
   uv tool install git+https://github.com/NVIDIA/skillspector.git
   ```
   `uv tool update skillspector` refreshes it later. Docker
   (`docker build -t skillspector .` from the repo) is the no-Python path.

2. **Run the wrapper** (`SS=~/.claude/skills/skill-safety-review/scan-skills.sh`):
   ```bash
   "$SS" [SKILLS_DIR]          # default: ~/.claude/skills
   "$SS" /path/to/one-skill    # a dir containing SKILL.md → single scan
   "$SS" --accept [SKILLS_DIR] # write per-skill baselines for reviewed findings
   ```
   SkillSpector has no recursive-scan baseline support, so the wrapper scans
   **each skill directory individually** (applying that skill's own
   `.skillspector-baseline.yaml` when present) and aggregates. It installs the
   scanner if missing, writes
   `~/.cache/skill-safety-review/skill-scan-<timestamp>.{json,md}` (outside any
   skill tree, override with `SKILL_SAFETY_REPORT_DIR`), prints a per-skill
   score table, and **exits non-zero** if any skill scores `HIGH`/`CRITICAL`
   or recommends `DO_NOT_INSTALL` after baseline suppression.

3. **Triage every finding** that survives the baseline:
   - Open the cited `file:line`. Decide: real risk, or heuristic hit on
     legitimate documentation/code?
   - Real risk → report it, name the category and line, recommend not
     installing / not running until fixed.
   - False positive on a skill you trust → record it in that skill's
     `.skillspector-baseline.yaml` (via `--accept`, or
     `skillspector baseline <skill-dir> --no-llm -o <skill-dir>/.skillspector-baseline.yaml`)
     so future re-scans only surface *new* issues.

4. **Report**: a short table (skill, score, severity, finding count) plus,
   for anything MEDIUM+, a line per surviving finding with the category and
   the file:line, and a plain-language "safe to use / review first / do not
   run" call per flagged skill.

## Reading the score

| Severity | Score | Default action |
|---|---|---|
| LOW | 0–29 | Safe to use; skim any findings. |
| MEDIUM | 30–59 | Review each finding at its line before trusting. |
| HIGH | 60–89 | Do not run until each finding is explained or fixed. |
| CRITICAL | 90–100 | Do not install. Treat as hostile until proven otherwise. |

A HIGH score on a skill whose whole job is security topics (a hardening
guide that names a cloud metadata endpoint, or shows a pipe-to-shell
anti-pattern) is usually heuristic noise — confirm at the line, don't
assume.

Reviewed false positives are recorded per skill in
`<skill>/.skillspector-baseline.yaml`. `--accept` writes machine
`fingerprints:` (exact, but they break on any edit to the skill). For a
skill that legitimately trips analyzers by *topic* — this one
(`analysis-evasion`, because it documents triaging/suppressing findings)
and `security-and-hardening` (`Credential Access` / `SSRF` on teaching
prose) — hand-author drift-tolerant `rules:` entries instead (glob on
`id` + `path`); `--accept` preserves an existing `rules:` block and skips
`skill-safety-review` entirely.

## Manual invocation

```bash
skillspector scan ./my-skill/ --no-llm                       # one skill, terminal
skillspector scan ~/.claude/skills/ --recursive --no-llm      # whole library
skillspector scan <dir> --no-llm -f sarif -o report.sarif     # CI / IDE
skillspector scan <dir> --no-llm -b .skillspector-baseline.yaml
skillspector scan https://github.com/user/skill --no-llm      # remote, before cloning
```

Inputs: directory, single `SKILL.md`, git URL, or zip. `--transitive`
follows external references the skill points at.

## Version control

Do not commit generated reports or baselines unless the user asks. If
baselines are committed, review the diff — a shrinking baseline is good, a
silently growing one hides new findings.
