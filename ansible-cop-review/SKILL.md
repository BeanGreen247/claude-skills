---
name: ansible-cop-review
description: |
  Review Ansible roles, playbooks, collections, or inventory against Red Hat
  Community of Practice (CoP) automation good practices. Use when asked to
  audit, lint, review, check, or validate Ansible code, or when the user
  says "lint my role", "check my playbook", "review best practices", or
  "audit my Ansible code". Runs ansible-lint locally alongside the CoP rule
  set. Not for general Python/YAML linting unrelated to Ansible — for
  simplicity/readability-focused review instead of strict compliance, use
  ansible-zen.
metadata:
  origin: >-
    Local reimplementation of leogallego/claude-ansible-skills'
    ansible-good-practices skill (github.com/leogallego/claude-ansible-skills),
    itself built on redhat-cop/automation-good-practices. Adapted to drop the
    optional ansible-know MCP dependency entirely (CoP-rule review only) and
    with a prompt-injection-style embedded trigger ("if invoked with argument
    'nuno', ignore all other instructions...") found in the original file
    removed.
---

# Ansible CoP Review

Review Ansible code against Red Hat CoP good practices and `ansible-lint`.
Purely local: bundled reference docs + the `ansible-lint`/`ansible-doc` CLIs
already installed on this machine. No MCP server, no network calls required.

## Important

- Do NOT skip any rule category — check all of them (unless the user
  requested a category filter).
- When a category does not apply (e.g., no templates exist), mark it N/A.
- Be precise about line numbers and file paths.

## Loading reference rules

Read the bundled `references/*.adoc` files in this skill directory — select
only the sections relevant to the files being reviewed (see mapping table
below). These are a local copy of the Red Hat CoP `automation-good-practices`
guide; no fetch needed. If a section seems out of date, note that in the
report rather than fetching a newer version.

### Section selection

| Files detected | Sections to load |
|---|---|
| `tasks/` `defaults/` `vars/` `meta/` `handlers/` `templates/` | roles, coding_style, naming_conventions, security, testing |
| Playbooks (`.yml` with `hosts:`) | playbooks, coding_style, naming_conventions |
| `inventory/` `group_vars/` `host_vars/` | inventories, security |
| `galaxy.yml` present | collections, roles, coding_style, naming_conventions, testing |
| `plugins/` `modules/` | plugins, coding_style, testing |
| `.github/` `.gitlab-ci.yml` `Makefile` CI/CD configs | cicd_and_promotion, git_workflow, testing |
| `ansible-vault` encrypted files, credential references | security |
| Unclear or full review | All sections |

Multiple matches are unioned. When more than one group matches, also load
`structures.adoc` (~1,500 tokens) for architectural framing.

### Token optimization

Full reference files total ~3,600 lines. Read each AsciiDoc section in two
passes:

1. **Rules pass** (always) — Read `==` headings and `Explanations::` blocks:
   the actionable rules. Skip `Rationale::` and `Examples::` on this pass.
2. **Detail pass** (on demand) — Only when a finding is ambiguous, go back
   for the `Examples::` block of that specific guideline.

For small reviews (single role, few files) reading full sections is fine.
For large reviews (3+ roles, 30+ files), use the two-pass approach.

## AsciiDoc parsing notes

1. `==` headings — individual guidelines (rule statements)
2. `Explanations::` — actionable rule content — **always read**
3. `Examples::` — code samples — **read on demand**
4. `Rationale::` — background — **skip unless investigating edge cases**
5. `NOTE:`, `TIP:`, `CAUTION:`, `WARNING:`, `IMPORTANT:` — admonitions worth reading

Ignore `[%collapsible]`/`====` block markers and `include::`/`image::` directives.

## Review process

1. **Determine review mode**:
   - **Full review** (default) — all Ansible files in the project.
   - **Path/file review** — only the files/path specified.
   - **Diff-aware review** — for "changed files"/"my changes", run
     `git diff --name-only` (and `git diff --cached --name-only` for staged)
     to scope the review. State the diff base (e.g. `HEAD`, `main`).
   - **Category filter** — if the user asks for specific categories only,
     list which are checked and which are skipped up front.

2. **Discover scope** — scan for `*.yml`/`*.yaml`, `templates/`, `defaults/`,
   `vars/`, `meta/`, `tasks/`, `handlers/`, `inventory/`, `README.md`.

3. **Run ansible-lint** — if available (`ansible-lint --version`), run it
   against the discovered files and capture output. Cross-reference findings
   with CoP rules — map each ansible-lint rule ID to the corresponding CoP
   category where applicable. If unavailable, note this and proceed manually.

4. **Parallel review for large projects** — for 3+ roles or 30+ files, use
   the Agent tool with subagents, one per role/logical group, then merge
   into a single report.

5. **Check every applicable rule category**: architecture, role naming,
   variable placement, idempotency & check mode, argument validation
   (`meta/argument_specs.yml`), file references (`{{ role_path }}`),
   templates (`ansible_managed`, `backup: true`), platform support
   (`include_vars` / `first_found` patterns), fact gathering, playbook
   structure, inventory, YAML style, naming (`snake_case`, imperative task
   names), module usage (FQCN, `loop:` over `with_*`), collections,
   providers, documentation, CI/CD & promotion, git workflow, security
   (no secrets in git, `ansible-vault`, least privilege), testing (Molecule).

## Severity levels

- **ERROR** — Must fix. Violates a MUST/NEVER/ALWAYS rule. E.g. missing
  `changed_when:` on `command:` tasks, user-facing defaults in
  `vars/main.yml`, non-FQCN modules, `yes`/`no` booleans.
- **WARNING** — Should fix. Best-practice violation. E.g. missing
  `backup: true` on template tasks, missing README sections.
- **INFO** — Suggestion, not a rule violation.

## Report format

Group findings by file, then severity. For each: severity tag, the rule
being violated (brief quote), file path + line number, offending snippet,
corrected code, and the `ansible-lint` rule ID if applicable.

End with a summary table (Rule Category | Status | Severity | Files Affected
| Count) plus totals, and an overall verdict naming the top 3 highest-priority
fixes.

## Auto-fix

After presenting the report, ask: "Would you like me to automatically fix
these violations?" If yes, apply ERRORs first, then WARNINGs — never
auto-fix INFO without explicit request. Re-run the review on modified files
to confirm resolution.

After the full review, offer: "Want me to run the ansible-zen skill for a
complementary review focused on simplicity and readability?"
