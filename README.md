# Claude Skills

Personal Claude Code skill library. Each subfolder is a skill: a `SKILL.md`
with `name`/`description` frontmatter that Claude Code auto-loads and
auto-invokes based on the description matching the current task.

## Behavior & economy (apply broadly, most sessions)

| Skill | Purpose |
|---|---|
| [`token-economy`](token-economy) | Minimizes token spend across context, output, and reasoning-effort — active by default, no skip condition. |
| [`silent-executor`](silent-executor) | Stricter output contract: work silently, reply only with a `FINISHED` block, no narration. |
| [`no-unsolicited-opinions`](no-unsolicited-opinions) | Executes instructions as given instead of volunteering critique or alternative approaches — safety/clarification exceptions still apply. |
| [`skill-safety-review`](skill-safety-review) | Security-scans agent skills with NVIDIA SkillSpector (static analysis only) before they are trusted or installed. |

## Software delivery lifecycle

Curated from [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills), picked for code-review/development impact.

| Skill | Purpose |
|---|---|
| [`planning-and-task-breakdown`](planning-and-task-breakdown) | Breaks a spec or requirement into ordered, implementable tasks. |
| [`incremental-implementation`](incremental-implementation) | Delivers multi-file changes in small, landable steps instead of one big diff. |
| [`api-and-interface-design`](api-and-interface-design) | Guides stable API/module-boundary/interface design. |
| [`test-driven-development`](test-driven-development) | Drives implementation and bug fixes with tests first. |
| [`debugging-and-error-recovery`](debugging-and-error-recovery) | Systematic root-cause debugging instead of guessing. |
| [`code-simplification`](code-simplification) | Refactors for clarity without changing behavior. |
| [`code-review-and-quality`](code-review-and-quality) | Multi-axis review before a change merges. |
| [`security-and-hardening`](security-and-hardening) | Hardens code that handles untrusted input, auth, or external integrations. |
| [`performance-optimization`](performance-optimization) | Diagnoses and fixes performance regressions across the stack. |
| [`observability-and-instrumentation`](observability-and-instrumentation) | Adds logging/metrics/tracing so production behavior is diagnosable. |
| [`ci-cd-and-automation`](ci-cd-and-automation) | Sets up or modifies build/deploy pipelines and quality gates. |
| [`git-workflow-and-versioning`](git-workflow-and-versioning) | Branching, commits, conflict resolution, releases, changelogs. |
| [`documentation-and-adrs`](documentation-and-adrs) | Records architectural decisions and context for future readers. |

## Domain / stack specific

| Skill | Purpose |
|---|---|
| [`python-engineer`](python-engineer) | Engineering rigor for Python web frameworks, systems tooling, and the Cloudera/Hadoop big-data stack. |
| [`browser`](browser) | Drives the user's Chrome via Playwright CDP — navigation, screenshots, form-fill assist, live-reload watching. Originally from [Karel Mozdren](https://github.com/mozdren), modified here for Windows compatibility. |
| [`websearch`](websearch) | Zero-API-cost web search via lynx/links2/curl, falling back to the `browser` skill for JS-heavy pages. |

## Project: Xylonic

| Skill | Purpose |
|---|---|
| [`xylonic-electron`](xylonic-electron) | Electron main/preload, IPC, D-Bus/MPRIS, desktop packaging. |
| [`xylonic-frontend`](xylonic-frontend) | Shared Vite/React/TypeScript layer used by both Electron and Android. |
| [`xylonic-mobile`](xylonic-mobile) | Android/iOS native layer, Capacitor plugins, mobile packaging. |

## Adding a skill

1. Create `<skill-name>/SKILL.md` with YAML frontmatter:
   ```yaml
   ---
   name: skill-name        # must match the folder name
   description: One-line trigger description Claude matches against the task.
   ---
   ```
2. Write the body as plain markdown — rules, examples, exceptions.
3. Keep `name` identical to the folder name (Claude Code and the lint check below both key off it).

A quick validator for the whole set:
```bash
python3 - <<'EOF'
import os, glob, yaml
for path in sorted(glob.glob(os.path.expanduser("~/.claude/skills/*/SKILL.md"))):
    d = os.path.basename(os.path.dirname(path))
    text = open(path).read()
    fm = yaml.safe_load(text.split("---")[1])
    assert fm.get("name") == d, f"{d}: name mismatch"
    assert fm.get("description"), f"{d}: missing description"
print("all skills valid")
EOF
```
