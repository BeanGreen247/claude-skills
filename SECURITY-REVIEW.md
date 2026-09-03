# Skill library security review

**Date:** 2026-09-03
**Tool:** [NVIDIA SkillSpector](https://github.com/NVIDIA/skillspector) v2.11.0
**Mode:** static analysis only (`--no-llm`) — no external / LLM / paid API called
**Scope:** all 22 skills in this directory, each scanned individually
**Runner:** [`skill-safety-review/scan-skills.sh`](skill-safety-review/SKILL.md)

## Verdict — safe

No malicious or unsafe skill. Every finding is a heuristic keyword / AST
match on legitimate documentation prose or an example command inside a
`SKILL.md`. Nothing exfiltrates data, escalates privilege, fetches-and-runs
remote code, or hides instructions.

Reviewed false positives are recorded per skill in
`<skill>/.skillspector-baseline.yaml`, so future `scan-skills.sh` runs
surface only **new** findings. After baselining, the gate **passes** with
no HIGH/CRITICAL and no MEDIUM+ findings (worst score 12 / LOW —
`browser`, `ci-cd-and-automation`, `websearch` carry a few sub-threshold
keyword hits on `sudo apt-get install` / `.env` prose).

`security-and-hardening` and `skill-safety-review` trip analyzers by
*subject* (teaching attacker technique; documenting finding-suppression);
their baselines use hand-authored drift-tolerant `rules:` (glob on
`id` + `path`) rather than edit-fragile fingerprints.

## Raw findings, all triaged as false positive

| Skill | Raw score | Finding(s) | Why benign |
|---|---:|---|---|
| security-and-hardening | 68 HIGH | YARA "hidden instructions"; SSRF cloud-metadata; 7× credential-access | Hardening guide — names the metadata endpoint and `.env`/secret-handling patterns to *teach defense*. |
| browser | 37 MED | tool "chaining abuse"; 5× sudo/root; session persistence | `which inotifywait \|\| sudo apt-get install …` install hint; background watch loop. |
| ci-cd-and-automation | 27 MED | credential-access; 7× "MCP rug pull" | `.env` / CI-secrets handling table; prose on pinning action versions. |
| silent-executor | 25 MED | 2× tool-parameter-abuse | The Destructive Action Exception *lists* `rm -rf`, `git push --force`, `git reset --hard` as things never to do silently — a guardrail. |
| git-workflow-and-versioning | 23 MED | tool-parameter-abuse; MCP rug pull | Prose mentions `git reset --hard HEAD` as recovery. |
| code-simplification | 21 MED | "self-modification"; scope-creep | "Apply changes incrementally / one simplification at a time." |
| api-and-interface-design | 20 LOW | tool-parameter-abuse | Example API-contract text. |
| python-engineer | 20 LOW | credential-access | Section on reading secrets from env / secrets managers (correct guidance). |
| performance-optimization | 10 LOW | 2× MCP rug pull | Prose about dependency/version changes. |
| websearch | 10 LOW | 2× sudo/root | `sudo apt-get install` hints for `lynx` / `links2`. |
| incremental-implementation, planning-and-task-breakdown, test-driven-development | 7 LOW | 1 each | Planning prose about making decisions / following steps. |
| the other 8 | 0 LOW | none | clean. |

## Notes

- SkillSpector caps findings per scan and varies slightly run to run, so a
  single `--accept` can miss a few; `scan-skills.sh --accept` runs 3 passes
  and unions the fingerprints. `browser` / `ci-cd-and-automation` /
  `websearch` still show 1–3 LOW hits some runs — all confirmed benign,
  all below the MEDIUM review threshold. Re-run `--accept` to absorb them.
- Findings with a null `pattern` cannot be re-fingerprinted after an edit;
  those skills (`security-and-hardening`, `skill-safety-review`) use
  `rules:` globs, which `--accept` preserves.

## Re-running

```bash
skill-safety-review/scan-skills.sh            # gated re-scan, exits non-zero on HIGH/CRITICAL
skill-safety-review/scan-skills.sh --accept   # re-record current findings as reviewed
```

Delete a skill's `.skillspector-baseline.yaml` to see its raw findings again.
