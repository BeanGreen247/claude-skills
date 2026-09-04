---
name: xylonic-frontend
description: Principal frontend workflow for Xylonic's shared Vite/React/TypeScript layer (src/**, public/index.html, styling, shared business logic used by both Electron and Android). Use for any implementation, debugging, refactor, or review touching the shared UI/component/service layer — not Electron main/preload or Android/Capacitor native code, which have their own skills (xylonic-electron, xylonic-mobile). Enforces preserving existing style/architecture, minimal diffs, and build-only validation (no commits/releases).
---

This skill handles Xylonic's shared Vite/React/TypeScript frontend layer:
components, hooks, context, services, utils, styles, types, and build
configuration. Code here runs in both Electron's renderer and Android's
WebView — platform-neutrality is a hard constraint, not a preference.

## Scope
This skill owns the platform-agnostic layer: `src/**` (components, hooks,
context, services, utils, styles, types), `public/index.html`, and
`vite.config.ts`. It does not own Electron main/preload (`public/electron.js`,
`public/preload.js`, `public/mpris.js` — see `xylonic-electron`) or the
native Android/Capacitor layer (`android/**`, `capacitor.config.ts` — see
`xylonic-mobile`). If a task spans layers, handle the shared piece here
and note what belongs to the sibling skills.

## Reasoning workflow (follow in order)
1. Inspect existing conventions, architecture, and UI patterns before
   writing anything — read the relevant files, don't assume.
2. Confirm the change truly belongs in the shared layer rather than
   leaking platform-specific logic (Electron IPC calls, Capacitor plugin
   calls) into `src/**`. Platform-specific access should go through the
   existing abstraction in `src/platform/`, not be called directly from
   components.
3. Preserve existing style and behavior unless the user explicitly asks
   for a redesign or behavior change.
4. Implement the smallest correct change.
5. Verify edge cases, build impact, and runtime implications.
6. Report anything that should be tested manually across platforms
   (since shared code runs inside both Electron's renderer and Android's
   WebView).

## Architecture rules
- Keep shared business logic reusable and platform-agnostic; route any
  platform-specific behavior through the existing `src/platform/`
  abstraction rather than branching inline on platform checks.
- Avoid leaky abstractions that make platform code harder to maintain.
- If existing architecture looks wrong, explain the issue clearly and
  propose the smallest robust improvement — don't silently rewrite it.

## Styling and UI rules
- Treat the current stylesheet, component design, spacing, typography,
  and interaction patterns as a first-class constraint.
- Match existing classes, tokens, variables, and visual rhythm exactly.
- Reuse existing components/utilities instead of introducing new ones.
- Never introduce visual redesigns, CSS framework swaps, or style-system
  changes unless the user explicitly requests it.
- New UI must look native to the existing project, and must render
  correctly in both the Electron renderer and the Android WebView.

## Technical standards
- TypeScript-first; follow the project's existing typing conventions.
- Vite: keep builds correct, code-split sensibly, handle env vars cleanly,
  keep the legacy plugin target working (`@vitejs/plugin-legacy`).
- Watch performance: avoid unnecessary rerenders and redundant asset
  processing (album art, `music-metadata` parsing, etc.).
- Remember this code ships to a WebView on Android (older engine quirks,
  memory pressure on large libraries) as well as Electron's Chromium —
  don't assume desktop-only resources.

## Coding style
- Clean, production-grade, readable, explicit.
- Meaningful names; avoid unnecessary abstraction.
- Comment only when logic is genuinely non-obvious.
- When editing existing code, minimize diff size while maximizing
  correctness.

## External API constraint
Never call, build, or suggest UI/service-layer code that calls the
Anthropic/Claude API (`api.anthropic.com` or any Claude/Anthropic-branded
SDK/wrapper), for any reason — no exceptions unless the user's current
request is explicitly about building a Claude API integration on purpose.

## Validation and release rules
- Only validate that the project builds successfully (`npm run build`).
- Do not run final compile/packaging/release steps.
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
- Report what changed, what needs cross-platform manual testing (Electron
  + Android WebView), and any risks — nothing more.

## When uncertain
Ask targeted clarifying questions only when a wrong guess would mean
real rework — otherwise proceed with the smallest reasonable
interpretation.

## Commit message formatting (standing rule)

Commit messages are always a single line in conventional-commit format:
`type(scope): message` (e.g. `feat(input.cpp): add launcher keybind`) -- never
multi-line prose subject+body. No Co-Authored-By trailers, Claude-Session links, or any other AI/Claude attribution lines or trailers -- ever, unless the user explicitly asks for one in that exact commit.

When just reporting what the commit message *would be* (not executing the
commit), give the plain oneliner text only -- never wrap it in a
`git commit -m "$(cat <<'EOF' ... EOF)"` heredoc block; that form is for
actually running the commit, not for displaying the message as text.
