#!/usr/bin/env bash
# Security-scan Claude / Claude Code agent skills with NVIDIA SkillSpector.
# Static analysis only (--no-llm): no paid or Anthropic-branded API is ever called.
#
# SkillSpector does not support baselines on recursive multi-skill scans, so this
# wrapper scans each skill directory individually (with its own committed
# <skill>/.skillspector-baseline.yaml when present) and aggregates the results.
#
# Usage:
#   ./scan-skills.sh [SKILLS_DIR]          # default: ~/.claude/skills
#   ./scan-skills.sh /path/to/one-skill    # a dir containing SKILL.md
#   ./scan-skills.sh --accept [SKILLS_DIR] # write/refresh per-skill baselines
#                                          # (records current findings as reviewed)
#
# Exit codes: 0 = every skill within threshold, 1 = a skill scored HIGH/CRITICAL
# or recommends DO_NOT_INSTALL, 2 = setup/scan error.

set -uo pipefail

ACCEPT=0
if [[ "${1:-}" == "--accept" ]]; then ACCEPT=1; shift; fi

SKILLS_DIR="${1:-$HOME/.claude/skills}"
# Reports live OUTSIDE any skill tree so a scan of this skill can't ingest them.
REPORT_DIR="${SKILL_SAFETY_REPORT_DIR:-$HOME/.cache/skill-safety-review}"
TS="$(date +%Y%m%d-%H%M%S)"

[[ -d "$SKILLS_DIR" ]] || { echo "error: not a directory: $SKILLS_DIR" >&2; exit 2; }

export PATH="$HOME/.local/bin:$PATH"
if ! command -v skillspector >/dev/null 2>&1; then
  if command -v uv >/dev/null 2>&1; then
    echo ">> installing SkillSpector via uv ..." >&2
    uv tool install git+https://github.com/NVIDIA/skillspector.git >&2 || exit 2
  else
    echo "error: skillspector not found; install with:" >&2
    echo "  uv tool install git+https://github.com/NVIDIA/skillspector.git" >&2
    exit 2
  fi
fi

# Build the list of skill directories to process.
SKILL_DIRS=()
if [[ -f "$SKILLS_DIR/SKILL.md" ]]; then
  SKILL_DIRS=("$SKILLS_DIR")
else
  for d in "$SKILLS_DIR"/*/; do
    [[ -f "$d/SKILL.md" ]] && SKILL_DIRS+=("${d%/}")
  done
fi
[[ ${#SKILL_DIRS[@]} -gt 0 ]] || { echo "error: no SKILL.md found under $SKILLS_DIR" >&2; exit 2; }

# ------------------------------------------------------------------ --accept ---
if [[ "$ACCEPT" == "1" ]]; then
  for d in "${SKILL_DIRS[@]}"; do
    name="$(basename "$d")"
    bl="$d/.skillspector-baseline.yaml"
    # This skill's own baseline is hand-authored with drift-tolerant glob rules
    # (fingerprints break on every SKILL.md edit); never regenerate it.
    if [[ "$name" == "skill-safety-review" ]]; then
      echo ">> baseline $name (hand-authored, skipped)" >&2
      continue
    fi
    # SkillSpector caps findings per scan and varies slightly run to run, so a
    # single pass can miss some. Run 3 passes and UNION the fingerprints.
    for _ in 1 2 3; do
      fresh="$(mktemp)"
      skillspector baseline "$d" --no-llm -o "$fresh" \
        --reason "Reviewed via skill-safety-review $TS" >/dev/null 2>&1 || true
      python3 - "$bl" "$fresh" <<'PY'
import os, sys
bl, fresh = sys.argv[1], sys.argv[2]
def fps(p):
    try: txt = open(p).read()
    except OSError: return []
    out, cur = [], {}
    for line in txt.splitlines():
        s = line.strip()
        if s.startswith("- hash:"):
            if cur: out.append(cur)
            cur = {"hash": s.split(":", 1)[1].strip()}
        elif s.startswith("rule_id:"): cur["rule_id"] = s.split(":", 1)[1].strip()
        elif s.startswith("file:"):    cur["file"] = s.split(":", 1)[1].strip()
        elif s.startswith("reason:"):  cur["reason"] = s.split(":", 1)[1].strip()
    if cur: out.append(cur)
    return out
seen, merged = set(), []
for fp in fps(bl) + fps(fresh):
    h = fp.get("hash")
    if h and h not in seen:
        seen.add(h); merged.append(fp)

# Preserve any hand-authored 'rules:' block from the existing baseline verbatim;
# only the machine-generated 'fingerprints:' list is regenerated.
rules_block = []
try:
    prev = open(bl).read().splitlines()
    for i, ln in enumerate(prev):
        if ln.rstrip() == "rules:" or ln.startswith("rules:") and ln.strip() != "rules: []":
            for ln2 in prev[i:]:
                if ln2.startswith("fingerprints:"):
                    break
                rules_block.append(ln2)
            break
except OSError:
    pass

lines = ["# SkillSpector baseline — reviewed false positives, suppressed on future scans.",
         "# Regenerate with: skill-safety-review/scan-skills.sh --accept",
         "version: 2", "scanner_version: 2.11.0"]
lines += rules_block or ["rules: []"]
lines.append("fingerprints:")
for fp in merged:
    lines.append(f"- hash: {fp['hash']}")
    if fp.get("rule_id"): lines.append(f"  rule_id: {fp['rule_id']}")
    lines.append(f"  file: {fp.get('file','SKILL.md')}")
    lines.append(f"  reason: {fp.get('reason','Reviewed false positive')}")
open(bl, "w").write("\n".join(lines) + "\n")
os.unlink(fresh)
PY
    done
    cnt=$(grep -c '^- hash:' "$bl" 2>/dev/null); cnt=${cnt:-0}
    # Drop empty baselines: a clean skill carries no file.
    [[ "$cnt" -eq 0 ]] && rm -f "$bl"
    echo ">> baseline $name ($cnt suppressed)" >&2
  done
  echo "Per-skill .skillspector-baseline.yaml files written; review the diffs before committing." >&2
  exit 0
fi

# -------------------------------------------------------------------- scan -----
mkdir -p "$REPORT_DIR"
JSON="$REPORT_DIR/skill-scan-$TS.json"
MD="$REPORT_DIR/skill-scan-$TS.md"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

i=0
for d in "${SKILL_DIRS[@]}"; do
  i=$((i+1))
  name="$(basename "$d")"
  bflag=()
  [[ -f "$d/.skillspector-baseline.yaml" ]] && bflag=(--baseline "$d/.skillspector-baseline.yaml")
  printf '  [%2d/%2d] %s\n' "$i" "${#SKILL_DIRS[@]}" "$name" >&2
  skillspector scan "$d" --no-llm "${bflag[@]}" --format json --output "$TMP/$name.json" \
    >/dev/null 2>&1 || true
  [[ -s "$TMP/$name.json" ]] || echo '{"__scan_error__":true}' > "$TMP/$name.json"
done

python3 - "$TMP" "$JSON" "$MD" <<'PY'
import glob, json, os, sys
tmp, json_out, md_out = sys.argv[1], sys.argv[2], sys.argv[3]
BAD = {"HIGH", "CRITICAL"}
rows, combined, worst, gate_fail = [], [], 0, False

for f in sorted(glob.glob(os.path.join(tmp, "*.json"))):
    name = os.path.splitext(os.path.basename(f))[0]
    try:
        d = json.load(open(f))
    except Exception:
        d = {"__scan_error__": True}
    combined.append({"name": name, "report": d})
    if d.get("__scan_error__"):
        rows.append((name, -1, "ERROR", 0)); gate_fail = True; continue
    ra = d.get("risk_assessment", {})
    score = ra.get("score", d.get("max_risk_score", 0)) or 0
    sev = (ra.get("severity") or d.get("risk_severity") or "?").upper()
    issues = d.get("issues", [])
    rows.append((name, score, sev, len(issues), issues))
    worst = max(worst, score)
    if sev in BAD or d.get("risk_recommendation") == "DO_NOT_INSTALL":
        gate_fail = True

json.dump({"scanned_at": os.path.basename(json_out), "skills": combined},
          open(json_out, "w"), indent=2)

def emit(line=""):
    print(line); md.append(line)

md = []
emit(f"# Skill safety scan\n")
emit(f"{len(rows)} skills scanned with SkillSpector (static analysis only).\n")
emit(f"| Skill | Score | Severity | Findings |")
emit(f"|---|---:|---|---:|")
for r in sorted(rows, key=lambda x: -(x[1] if x[1] >= 0 else 999)):
    name, score, sev, n = r[0], r[1], r[2], r[3]
    sc = "err" if score < 0 else str(score)
    flag = "  <-- REVIEW" if sev in BAD or sev == "ERROR" else ""
    emit(f"| {name} | {sc} | {sev} | {n}{flag} |")

flagged = [r for r in rows if len(r) > 4 and r[2] in {"HIGH", "CRITICAL", "MEDIUM"}]
if flagged:
    emit("\n## Findings on MEDIUM+ skills (confirm each at its file:line)\n")
    for r in flagged:
        for it in r[4]:
            loc = it.get("location") or {}
            emit(f"- `[{it.get('severity','?')}]` **{r[0]}** — {it.get('category')} / "
                 f"{it.get('pattern')} → `{loc.get('file')}:{loc.get('start_line')}`")

emit(f"\nworst score: {worst}  ·  gate: {'FAIL' if gate_fail else 'pass'}")
open(md_out, "w").write("\n".join(md) + "\n")
sys.exit(1 if gate_fail else 0)
PY
GATE=$?

echo
echo "reports: $JSON"
echo "         $MD"
exit $GATE
