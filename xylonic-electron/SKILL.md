---
name: xylonic-electron
description: Principal Electron workflow for Xylonic's desktop shell (public/electron.js, public/preload.js, public/mpris.js, electron-builder packaging config). Use for any implementation, debugging, refactor, or review touching Electron main/preload, IPC, native desktop integration (D-Bus/MPRIS), or desktop packaging — not the shared Vite/React frontend or Android/Capacitor native code, which have their own skills (xylonic-frontend, xylonic-mobile). Enforces secure IPC patterns, minimal diffs, and build-only validation (no commits/releases).
---

This skill handles Xylonic's Electron desktop shell: main/preload process
implementation, secure IPC design, Linux D-Bus/MPRIS integration, and
electron-builder packaging configuration. Applies Electron, Node.js, and
Linux desktop integration conventions correctly for the target constraints.

## Scope
This skill owns `public/electron.js` (main process), `public/preload.js`
(preload bridge), `public/mpris.js` (Linux D-Bus/MPRIS media integration),
and the `electron-builder` packaging configuration
(`electron-builder.json`, the `electron:build*` npm scripts). It does not
own the shared React/Vite UI (`src/**` — see `xylonic-frontend`) or the
native Android/Capacitor layer (`android/**` — see `xylonic-mobile`). If
a task spans layers, handle the Electron piece here and note what belongs
to the sibling skills.

## Reasoning workflow (follow in order)
1. Inspect existing conventions in `electron.js`/`preload.js` before
   writing anything — read the relevant files, don't assume.
2. Decide whether the change belongs in main, preload, or should really
   live in the shared renderer code instead (see `xylonic-frontend`).
3. Preserve existing style and behavior unless the user explicitly asks
   for a redesign or behavior change.
4. Implement the smallest correct change.
5. Verify edge cases, build impact, and runtime implications — including
   what happens on platforms without D-Bus (non-Linux) for `mpris.js`
   paths.
6. Report anything that should be tested manually (packaging output,
   OS-level media-key/MPRIS integration) that can't be verified from here.

## Architecture rules
- Keep Electron-specific code strictly inside main/preload boundaries;
  nothing Node-privileged should be reachable from the renderer except
  through the preload bridge.
- Keep the D-Bus/MPRIS integration isolated in `mpris.js`, guarded so it
  degrades cleanly on non-Linux platforms.
- Avoid leaky abstractions that make platform code harder to maintain.
- If existing architecture looks wrong, explain the issue clearly and
  propose the smallest robust improvement — don't silently rewrite it.

## Technical standards
- Context isolation, preload bridges only, minimal IPC surface — no
  direct Node/unsafe access from the renderer.
- Keep IPC channels explicit and narrow; validate anything crossing the
  boundary rather than trusting renderer input.
- Watch performance: avoid IPC chatter and blocking operations on the
  main process (which would stall the whole app, not just a tab).
- Keep packaging/signing/release reproducibility in mind when touching
  `electron-builder.json` or build scripts, but do not execute those
  steps (see Validation rules below).

## Coding style
- Clean, production-grade, readable, explicit.
- Meaningful names; avoid unnecessary abstraction.
- Comment only when logic is genuinely non-obvious.
- When editing existing code, minimize diff size while maximizing
  correctness.

## External API constraint
Never call, build, or suggest IPC/main-process code that calls the
Anthropic/Claude API (`api.anthropic.com` or any Claude/Anthropic-branded
SDK/wrapper), for any reason — no exceptions unless the user's current
request is explicitly about building a Claude API integration on purpose.

## Validation and release rules
- Only validate that the project builds successfully.
- Do not run final compile/packaging/release steps
  (`electron:build*`, `release:all`, `debug:all`).
- Do not commit, amend, squash, or create commits.
- Do not push, tag, or perform any version control release actions.
- Leave final compile and release execution to the user.

## Project memory
This project's `CLAUDE.md` already lists the memory files to keep current
(`docs/todos.md`, `docs/session_summary.md`, `docs/module_notes.md`,
`ARCHITECTURE.md`, etc. — see there for the full list). When a change
affects any of them, update them as part of the same task rather than
leaving them stale.

## Collaborator context

The engineer behind this project:
- Traces bugs to actual failure modes — no papering over symptoms.
- Works with a large-scale music library, bulk overnight downloads, and
  extended sessions — the bugs found are the bugs you only find by using
  the product hard, not by testing happy paths.
- Favors focused, minimal solutions to specific failure modes.

Skip foundational explanations. Explain reasoning and tradeoffs directly;
they will evaluate and push back if something is wrong.

## Token efficiency
- Read only the files relevant to this change. Use targeted
  grep/offset reads for large files instead of whole-file reads.
- Batch independent file reads in a single turn.
- Do not re-read a file immediately after editing it.
- Report what changed, what needs manual desktop testing, and any
  risks — nothing more.

## When uncertain
Ask targeted clarifying questions only when a wrong guess would mean
real rework — otherwise proceed with the smallest reasonable
interpretation.
