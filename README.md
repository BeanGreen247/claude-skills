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
| [`module-extraction-verification`](module-extraction-verification) | Verifies a code extraction (splitting a monolith into modules/mixins) is complete and behavior-preserving — diff-then-lint before trusting it. |
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
| [`design-craft`](design-craft) | Research-first UI/product/web design methodology + senior-designer craft references (type, color, motion, icons, copy, anti-AI-slop). MCP-free adaptation of [`referodesign/refero_skill`](https://github.com/referodesign/refero_skill) (MIT) — live research replaced by user references + the `websearch`/`browser` skills, no paid API. See [`design-craft/NOTICE.md`](design-craft/NOTICE.md). |

## Google Cloud / Google products

Curated from [google/skills](https://github.com/google/skills) (135 skills, mostly
GCP/GKE/Ads/Analytics). Picked for overlap with this setup: Python/big-data
(`python-engineer`), the Xylonic mobile/desktop app, and general AI-agent work.
All nine passed [`skill-safety-review`](skill-safety-review) (SkillSpector static
scan); surviving findings were reviewed as heuristic false positives and recorded
in each skill's `.skillspector-baseline.yaml`.

| Skill | Purpose |
|---|---|
| [`finding-google-skills`](finding-google-skills) | On-demand loader — fetches `google/skills`' catalog and pulls the right skill for any Google product/API not already vendored here (curl to public GitHub, no API key). |
| [`gcloud`](gcloud) | Safety validation, guardrails, and output reduction for `gcloud` CLI operations across GCP. |
| [`cloud-run-basics`](cloud-run-basics) | Deploy and manage Cloud Run services, jobs, and worker pools. |
| [`firebase-basics`](firebase-basics) | Firebase CLI setup, login, project selection, and app config-file retrieval (`google-services.json`, `GoogleService-Info.plist`). References external `xcode-project-setup` / `genkit-ai/skills` that aren't vendored — degrades gracefully. |
| [`bigquery-basics`](bigquery-basics) | Datasets, tables, jobs, SQL, and basic ingestion in BigQuery. |
| [`developing-genkit-js`](developing-genkit-js) | Build AI flows/agents/tools with Genkit in Node.js/TypeScript. |
| [`developing-genkit-python`](developing-genkit-python) | Build AI flows/agents/tools with Genkit in Python. |
| [`managed-airflow-dag-authoring`](managed-airflow-dag-authoring) | Author and validate Airflow DAGs for Managed Service for Apache Airflow (Cloud Composer). |
| [`managed-airflow-dag-troubleshooting`](managed-airflow-dag-troubleshooting) | Diagnose failed Managed Airflow DAG runs and task instances. |

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
