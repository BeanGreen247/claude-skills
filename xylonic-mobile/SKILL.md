---
name: xylonic-mobile
description: Principal Android and iOS/Capacitor workflow for Xylonic's native mobile layer (android/**, ios/**, capacitor.config.ts, @capacitor/* plugin usage, build scripts). Use for any implementation, debugging, refactor, or review touching Android or iOS native code, Capacitor plugins, device lifecycle/permissions/storage, or mobile packaging — not the shared Vite/React frontend or Electron main/preload, which have their own skills (xylonic-frontend, xylonic-electron). Enforces preserving existing architecture, minimal diffs, and build-only validation (no commits/releases).
---

This skill handles Xylonic's native mobile layer for both Android and iOS:
Capacitor plugin implementation, platform lifecycle management, permissions,
storage, background/foreground behavior, threading, and mobile packaging.
Applies Android SDK, iOS SDK, Capacitor, Kotlin/Java, and Swift/ObjC
conventions correctly for the target constraints of each platform.

## Scope
- **Android**: `android/**` (native project, Gradle config), `@capacitor/android`,
  `@capacitor/core`, `@capacitor/filesystem`, `@capacitor/preferences`,
  `build-android.sh` (or equivalent build scripts).
- **iOS**: `ios/**` (native project, Xcode config), `@capacitor/ios`,
  iOS-equivalent build scripts.
- **Shared mobile**: `capacitor.config.ts`, any `@capacitor/*` plugin
  configuration shared across platforms.

This skill does **not** own the shared React/Vite UI (`src/**` — see
`xylonic-frontend`) or the Electron desktop shell (`public/electron.js`,
`public/preload.js` — see `xylonic-electron`). If a task spans layers,
handle the mobile/Capacitor piece here and note what belongs to sibling skills.

## Reasoning workflow (follow in order)
1. Identify the target platform(s) — Android, iOS, or both. Changes that
   affect both platforms must be verified for each independently.
2. Inspect existing conventions, architecture, and native code before
   writing anything — read the relevant files, don't assume.
3. Decide whether the change belongs in native Android/iOS code, a Capacitor
   plugin call, or should live in the shared renderer code instead
   (see `xylonic-frontend`) via the `src/platform/` abstraction.
4. Preserve existing style and behavior unless the user explicitly asks
   for a redesign or behavior change.
5. Implement the smallest correct change.
6. Verify edge cases, build impact, and runtime implications:
   - **Android**: process-model edge cases (WebView renderer vs. main app
     process), lifecycle, background/foreground-service behavior, wakelock.
   - **iOS**: app lifecycle (foreground/background/suspended), AVAudioSession
     behavior, Background Modes entitlements, WKWebView constraints.
7. Report anything that needs manual testing on a real device or emulator/
   simulator — state which platform(s) require it.

## Architecture rules
- Keep platform-specific behavior in its proper layer (Capacitor plugin /
  native code), not leaked into shared React code.
- Route shared platform access through the existing `src/platform/`
  abstraction rather than branching inline on platform checks in components.
- Respect the boundary between the sandboxed WebView renderer and the main
  app process on both platforms.
- Avoid leaky abstractions that make platform code harder to maintain.
- If existing architecture looks wrong, explain the issue and propose the
  smallest robust improvement — don't silently rewrite it.

## Android-specific standards
- Respect Android lifecycle, threading (including single-threaded
  `ExecutorService` queuing patterns already in use), permissions,
  storage, and native platform conventions (minSdk 24 / Android 7 target).
- Get wakelock and foreground-service semantics right for long-running
  playback/downloads — extended screen-off sessions and bulk overnight
  downloads are load-bearing use cases, not theoretical ones.
- Mind `volatile` visibility guarantees and cross-thread state sharing.
- Watch performance: avoid unnecessary WebView reloads, redundant asset
  processing, and memory pressure at real-library scale.

## iOS-specific standards
- Respect iOS app lifecycle (UIApplicationDelegate / SceneDelegate states),
  WKWebView constraints, and the iOS permission model (explicit user prompts
  required for media, storage, notifications).
- Get `AVAudioSession` category and activation right for background audio
  playback — `AVAudioSessionCategoryPlayback` with the appropriate Background
  Modes entitlement (`audio`) is required for music to continue playing when
  the screen locks or the app is backgrounded.
- Use `BackgroundTasks` framework for any deferred/download work rather than
  relying on completion handlers that the OS may terminate.
- Mind WKWebView memory pressure — it is more constrained than Android's
  WebView on lower-end devices with large libraries.
- Do not assume filesystem paths match Android conventions; use Capacitor's
  `Filesystem` plugin or iOS-appropriate APIs (`NSFileManager`,
  app-container-relative paths).

## Coding style
- Clean, production-grade, readable, explicit.
- Meaningful names; avoid unnecessary abstraction.
- Comment only when logic is genuinely non-obvious.
- When editing existing code, minimize diff size while maximizing correctness.
- Match the language and style already used in each platform's native code
  (Kotlin/Java for Android, Swift for iOS) — don't introduce the other
  language without an explicit reason.

## External API constraint
Never call, build, or suggest native/plugin code that calls the
Anthropic/Claude API (`api.anthropic.com` or any Claude/Anthropic-branded
SDK/wrapper), for any reason — no exceptions unless the user's current
request is explicitly about building a Claude API integration on purpose.

## Validation and release rules
- Only validate that the project builds successfully (build-only targets),
  not full release/install cycles.
- Do not run final compile/packaging/release steps.
- Do not commit, amend, squash, or create commits.
- Do not push, tag, or perform any version control release actions.
- Leave final compile, install, signing, and release execution to the user.

## Project memory
This project's `CLAUDE.md` already lists the memory files to keep current
(`docs/todos.md`, `docs/session_summary.md`, `docs/module_notes.md`,
`ARCHITECTURE.md`, etc. — see there for the full list). When a change
affects any of them, update them as part of the same task rather than
leaving them stale.

## Collaborator context

The engineer behind this project:
- Traces bugs to actual failure modes (Android process model, iOS lifecycle
  states, WKWebView/WebView constraints, Capacitor event delivery) — not
  surface symptoms.
- Works with a large-scale music library, bulk overnight downloads, and
  extended sessions — edge cases are load-bearing, not theoretical.
- Understands platform internals: Android foreground service/wakelock
  semantics, iOS AVAudioSession behavior, cross-thread visibility guarantees.
- Debugs natively: logcat on Android, Xcode console / os_log on iOS, traces
  event delivery across the JS/native boundary without scaffolding.

Skip foundational explanations. Explain reasoning and tradeoffs directly;
they will evaluate and push back if something is wrong.

## Token efficiency
- Read only the files relevant to this change. Use targeted grep/offset reads
  for large files instead of whole-file reads.
- Batch independent file reads in a single turn.
- Do not re-read a file immediately after editing it.
- When a change affects both platforms, report Android and iOS impacts
  together rather than in separate passes.
- Report what changed, what needs manual device testing (and on which
  platform), and any risks — nothing more.

## When uncertain
Ask targeted clarifying questions only when a wrong guess would mean real
rework (e.g. whether a behavior change should apply to both platforms or
only one) — otherwise proceed with the smallest reasonable interpretation.

## Commit message formatting (standing rule)

Commit messages are always a single line in conventional-commit format:
`type(scope): message` (e.g. `feat(input.cpp): add launcher keybind`) -- never
multi-line prose subject+body. No Co-Authored-By trailers, Claude-Session links, or any other AI/Claude attribution lines or trailers -- ever, unless the user explicitly asks for one in that exact commit.

When just reporting what the commit message *would be* (not executing the
commit), give the plain oneliner text only -- never wrap it in a
`git commit -m "$(cat <<'EOF' ... EOF)"` heredoc block; that form is for
actually running the commit, not for displaying the message as text.
