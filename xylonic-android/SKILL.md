---
name: xylonic-android
description: Principal Android/Capacitor workflow for Xylonic's native mobile layer (android/**, capacitor.config.ts, @capacitor/* plugin usage, build-android.sh). Use for any implementation, debugging, refactor, or review touching Android native code, Capacitor plugins, device lifecycle/permissions/storage, or Android packaging — not the shared Vite/React frontend or Electron main/preload, which have their own skills (xylonic-frontend, xylonic-electron). Enforces preserving existing architecture, minimal diffs, and build-only validation (no commits/releases).
---

This skill handles Xylonic's native Android layer: Capacitor plugin
implementation, Android lifecycle management, permissions, storage, wakelock
and foreground-service semantics, threading, and Android packaging. Applies
Android SDK, Capacitor, Kotlin, and Java conventions correctly for the
target constraints (minSdk 24, real-world scale).

## Scope
This skill owns `android/**` (native project, Gradle config),
`capacitor.config.ts`, usage of `@capacitor/android`, `@capacitor/core`,
`@capacitor/filesystem`, `@capacitor/preferences`, and `build-android.sh`.
It does not own the shared React/Vite UI (`src/**` — see
`xylonic-frontend`) or the Electron desktop shell (`public/electron.js`,
`public/preload.js` — see `xylonic-electron`). If a task spans layers,
handle the Android/Capacitor piece here and note what belongs to the
sibling skills.

## Reasoning workflow (follow in order)
1. Inspect existing conventions, architecture, and native code before
   writing anything — read the relevant files, don't assume.
2. Decide whether the change belongs in native Android code, a Capacitor
   plugin call, or should really live in the shared renderer code instead
   (see `xylonic-frontend`) via the `src/platform/` abstraction.
3. Preserve existing style and behavior unless the user explicitly asks
   for a redesign or behavior change.
4. Implement the smallest correct change.
5. Verify edge cases, build impact, and runtime implications — especially
   process-model edge cases (WebView renderer vs. main app process),
   lifecycle, and background/foreground-service behavior.
6. Report anything that should be tested manually on a device/emulator
   that can't be verified from here.

## Architecture rules
- Keep Android-specific behavior in its proper layer (Capacitor plugin /
  native code), not leaked into shared React code.
- Respect the boundary between the sandboxed WebView renderer subprocess
  and the main app process when reasoning about state, memory, and
  crashes.
- Avoid leaky abstractions that make platform code harder to maintain.
- If existing architecture looks wrong, explain the issue clearly and
  propose the smallest robust improvement — don't silently rewrite it.

## Technical standards
- Respect Android lifecycle, threading (including single-threaded
  `ExecutorService` queuing patterns already in use), permissions,
  storage, and native platform conventions (minSdk 24 / Android 7
  target).
- Get wakelock and foreground-service semantics right for long-running
  playback/downloads — this app is used for bulk overnight downloads and
  extended screen-off sessions, so these edge cases are load-bearing, not
  theoretical.
- Mind `volatile` visibility guarantees and other cross-thread state
  sharing carefully.
- Watch performance: avoid unnecessary WebView reloads, redundant asset
  processing, and memory pressure at real-library scale (thousands of
  tracks).
- Keep packaging/signing reproducibility in mind when touching
  `build-android.sh` or Gradle config, but do not execute those steps
  (see Validation rules below).

## Coding style
- Clean, production-grade, readable, explicit.
- Meaningful names; avoid unnecessary abstraction.
- Comment only when logic is genuinely non-obvious.
- When editing existing code, minimize diff size while maximizing
  correctness.

## Validation and release rules
- Only validate that the project builds successfully
  (`android:build-only:*`), not full release/install cycles.
- Do not run final compile/packaging/release steps
  (`android:build:release`, `android:build:both`, `release:all`).
- Do not commit, amend, squash, or create commits.
- Do not push, tag, or perform any version control release actions.
- Leave final compile, install, and release execution to the user.

## Project memory
This project's `CLAUDE.md` already lists the memory files to keep current
(`docs/todos.md`, `docs/session_summary.md`, `docs/module_notes.md`,
`ARCHITECTURE.md`, etc. — see there for the full list). When a change
affects any of them, update them as part of the same task rather than
leaving them stale.

## Collaborator context

The engineer behind this project:
- Traces bugs to actual failure modes (Android process model, V8 heap
  pressure, wakelock timeout mechanics, Capacitor event delivery across
  WebView restarts) — not surface symptoms.
- Works with a large-scale music library, bulk overnight downloads, and
  extended screen-off sessions — edge cases are load-bearing, not theoretical.
- Understands the sandboxed WebView renderer subprocess vs. main app
  process distinction, foreground service wakelock refresh semantics,
  single-threaded `ExecutorService` queuing, and `volatile` visibility
  guarantees across threads.
- Reads logcat, takes device screenshots, traces event delivery across
  the JS/native boundary without scaffolding.

Skip foundational explanations. Explain reasoning and tradeoffs directly;
they will evaluate and push back if something is wrong.

## Token efficiency
- Read only the files relevant to this change. Use targeted
  grep/offset reads for large files instead of whole-file reads.
- Batch independent file reads in a single turn.
- Do not re-read a file immediately after editing it.
- Report what changed, what needs manual device/emulator testing, and any
  risks — nothing more.

## When uncertain
Ask targeted clarifying questions only when a wrong guess would mean
real rework — otherwise proceed with the smallest reasonable
interpretation.
