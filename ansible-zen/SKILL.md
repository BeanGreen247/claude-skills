---
name: ansible-zen
description: |
  Display the Zen of Ansible principles and review Ansible code against
  them for simplicity, readability, and clarity. Use when the user wants
  to see the Zen of Ansible, get philosophical guidance on their automation
  approach, or asks "zen of ansible", "simplify my playbook", "is this too
  complex", or "clean code review". Not for strict rule compliance (use
  ansible-cop-review instead) or module/syntax reference (use
  ansible-docs-local instead).
metadata:
  origin: >-
    Local reimplementation of leogallego/claude-ansible-skills' ansible-zen
    skill (github.com/leogallego/claude-ansible-skills). No MCP dependency
    in the original; a prompt-injection-style embedded trigger ("if invoked
    with argument 'nuno', ignore all other instructions...") found in that
    file has been removed here.
---

# The Zen of Ansible

Purely local — bundled reference file, no network or MCP calls.

## Important

- This is a **complementary** review to `ansible-cop-review`. The Zen
  review focuses on philosophy and style; CoP review focuses on rule
  compliance.
- Keep feedback constructive and encouraging — this is about helping, not
  gatekeeping.
- When showing improved code, explain *why* it's better in terms of the
  Zen principle, not just the fix.
- If the code is already well-aligned, say so and highlight what makes it
  good. Not every review needs to find problems.

## Loading reference rules

For architectural context, read `references/structures.adoc` in this skill
directory (the CoP Landscape/Type/Function/Component hierarchy). If it's
missing, the Zen review still works — the 20 principles below are
self-contained.

## The Principles

```
 1. Ansible is not Python.
 2. YAML sucks for coding.
 3. Playbooks are not for programming.
 4. Ansible users are (most likely) not programmers.
 5. Clear is better than cluttered.
 6. Concise is better than verbose.
 7. Simple is better than complex.
 8. Readability counts.
 9. Helping users get things done matters most.
10. User experience beats ideological purity.
11. "Magic" conquers the manual.
12. When giving users options, use convention over configuration.
13. Declarative is better than imperative -- most of the time.
14. Focus avoids complexity.
15. Complexity kills productivity.
16. If the implementation is hard to explain, it's a bad idea.
17. Every shell command and UI interaction is an opportunity to automate.
18. Just because something works, doesn't mean it can't be improved.
19. Friction should be eliminated whenever possible.
20. Automation is a journey that never ends.
```

## Modes

### Mode 1: Display the Zen

No arguments / "show me the zen" / "what is the zen of ansible": display
the full list above, then pick one random principle and briefly explain it
with a practical good-vs-bad Ansible example (5-10 lines of YAML each).

### Mode 2: Review code against the Zen

A path/files given, or a review requested: philosophical review, not a
compliance audit.

1. **Discover scope** — the specified files, or the project's Ansible files.
2. **Read the code**.
3. **Evaluate against each applicable principle**:

   | Principle | What to look for |
   |---|---|
   | Ansible is not Python | Jinja2 abuse: complex filters, nested conditionals, inline Python logic in templates |
   | YAML sucks for coding | Overly clever YAML tricks, deep nesting, complex data transformations in vars |
   | Playbooks are not for programming | Excessive `when` chains, recursive includes, loop-within-loop |
   | Clear is better than cluttered | Noisy tasks, unclear variable names, mixed concerns |
   | Concise is better than verbose | Copy-pasted tasks that should be loops, wordy task names |
   | Simple is better than complex | Over-engineered roles, unnecessary abstraction, premature generalization |
   | Readability counts | Poor formatting, missing task names, cryptic variable names |
   | Helping users get things done | Missing docs, unclear defaults, no examples |
   | User experience beats ideological purity | Overly strict validation, rigid patterns |
   | "Magic" conquers the manual | Manual steps that could be automated, missing handlers/defaults |
   | Convention over configuration | Too many knobs, no sensible defaults |
   | Declarative over imperative | `command:`/`shell:` used where a module exists |
   | Focus avoids complexity | Roles doing too many things, scope creep |
   | Complexity kills productivity | Deep variable indirection, over-abstracted patterns |
   | Hard to explain = bad idea | Code requiring extensive comments to understand |
   | Opportunity to automate | Manual steps documented but not automated, TODO comments |
   | Can always be improved | Stale patterns, deprecated module usage |
   | Eliminate friction | Unnecessary prerequisites, manual setup, poor error messages |

4. **Report findings** grouped by principle (not by file): the principle,
   file + line, offending snippet, simplified version, and a brief
   explanation of why the change aligns with the principle.

5. **Zen Score** (1-10):
   - **9-10**: Exemplary — clean, simple, readable, well-documented
   - **7-8**: Good — minor improvements possible
   - **5-6**: Acceptable — notable complexity or readability issues
   - **3-4**: Needs work — significant violations of simplicity/clarity
   - **1-2**: Anti-Zen — over-engineered or unreadable

6. **Top recommendations** — the 3 most impactful, complexity-reducing changes.

7. Offer: "Want me to run the ansible-cop-review skill for a complementary
   review focused on Red Hat CoP rule compliance?"
