---
name: ansible-docs-local
description: |
  Answer Ansible module/syntax/parameter questions and check code against
  official module documentation, using the local `ansible-doc` CLI. Covers
  ansible-core and any installed collections (ansible.builtin, community.*,
  etc). Use when the user asks "how do I use module X", "what params does Y
  take", "check this task against the docs", or names deprecations. Not for
  Red Hat CoP style/compliance review (use ansible-cop-review) or
  simplicity review (use ansible-zen).
metadata:
  origin: >-
    Local reimplementation of leogallego/claude-ansible-skills' ansible-docs
    skill (github.com/leogallego/claude-ansible-skills). The original hard-
    requires the ansible-know MCP server with "no standalone fallback";
    this version replaces it entirely with the `ansible-doc` CLI, which
    ships with ansible-core and is already installed here — fully offline,
    no MCP, no network call, covers ~9,200 modules across installed
    collections.
---

# Ansible Docs (local)

Everything here runs through `ansible-doc`, `ansible-galaxy collection list`,
and `ansible-lint`, all already installed. No MCP server, no network call.

## Look up a module

```bash
ansible-doc <fqcn-or-short-name>          # e.g. ansible-doc ansible.builtin.copy
ansible-doc -s <fqcn>                     # short/snippet form: just the parameter skeleton
ansible-doc -j <fqcn>                     # JSON — use when parsing params programmatically
```

Always resolve to the FQCN first if the user gives a short name (`copy` →
`ansible.builtin.copy`) — ambiguous short names may resolve to a collection
other than the one intended; `ansible-doc -j <short-name>` still works and
its output includes the resolved FQCN.

## Search for a module by keyword

```bash
ansible-doc -l | grep -i <keyword>          # list all modules, grep by name
ansible-doc -l -t module | grep -i <keyword>
```

`ansible-doc -l` lists ~9,000+ modules across every installed collection —
always grep, never dump the full list into the conversation.

## List installed collections

```bash
ansible-galaxy collection list
```

Use this before answering "does module X exist" questions — if the
relevant collection isn't installed, say so and give the `ansible-galaxy
collection install <name>` command rather than guessing at docs for an
uninstalled collection.

## Validating a task against module docs

1. Extract the module name and parameters from the task.
2. `ansible-doc -j <fqcn>` and parse `options` from the JSON.
3. Check:
   - Every `required: true` option is present in the task.
   - Parameter names match either the primary key or a listed `aliases`
     entry.
   - Values with a `choices` list are one of the listed choices.
   - No `deprecated` options are in use — if the doc has a `deprecated`
     block, surface the replacement.
4. If the module itself is marked deprecated in `ansible-doc -j` output,
   suggest the replacement named in its `deprecated` block.

## Suggesting a module for a raw command

Heuristic mapping from `command:`/`shell:` tasks to dedicated modules:

| Command pattern | Suggested module |
|---|---|
| `systemctl`/`service` | `ansible.builtin.service` or `ansible.builtin.systemd_service` |
| `useradd`/`usermod` | `ansible.builtin.user` |
| `cp`/`mv`/`install` | `ansible.builtin.copy` or `ansible.builtin.file` |
| `yum`/`dnf`/`apt` | `ansible.builtin.package` (or the package-manager-specific module) |
| `firewall-cmd`/`ufw` | `ansible.posix.firewalld` or the relevant firewall module — confirm with `ansible-doc -l \| grep -i firewall` |

## Deprecation and version questions

`ansible --version` reports the installed ansible-core version — check it
before answering version-specific questions, since module availability and
deprecation timelines vary by release:

```bash
ansible --version
```

## Output discipline

- Never paste raw `ansible-doc -l` output (9,000+ lines) — always grep first.
- Quote only the relevant `options`/`examples` block from a module's docs,
  not the entire page, unless the user asked to see everything.
