---
name: brain
description: Regenerates and opens the Claude memory "brain" visualization — a lightweight local graph of local memory, the claude-memory-bank, skills, and git project repos under $HOME, with a live view of the actual task in progress (repo -> skill/tool -> NOW) across any session, as it happens. Use when the user asks to see, open, or refresh their memory graph/brain visualization.
---

Source: [github.com/BeanGreen247/claude-brain](https://github.com/BeanGreen247/claude-brain)
(local clone: `~/git/claude-brain`). `~/.claude/scripts/brain_*.py` and
`install-brain-deps.sh` are symlinks into that repo — edit the files there,
not through the symlinks, so changes are actually version-controlled. Full
architecture/gotchas writeup: that repo's `README.md`.

Run this, then tell the user it opened (name the path):

```
python3 ~/.claude/scripts/brain_viz.py --open
```

This regenerates `~/.claude/brain/index.html` and `~/.claude/brain/graph.json` from:
- local per-project memory: `~/.claude/projects/*/memory/*.md`
- the git memory bank: `~/claude-memory-bank/{projects,preferences,reference,people}/*.md`
- skills: `~/.claude/skills/*/SKILL.md`
- git project repos found under `$HOME` (up to 4 dirs deep)

It also regenerates silently (no window popup) on every SessionStart hook, so the
data is usually already fresh — `--open` just needs to launch the window.

## How the window opens (in priority order)

1. **pywebview**, via the dedicated venv at `~/.claude/brain/.venv` — a real native
   window (GTK/WebKit2 backend), no separate browser process. Preferred whenever
   its GTK/WebKit2 system libs are present (`pywebview_available()` in
   `brain_viz.py` checks this at runtime). If not yet installed:
   `sudo apt install -y gir1.2-webkit2-4.1 libwebkit2gtk-4.1-0` (one-time, needs
   the user's password — ask them to run it, don't attempt sudo yourself).
2. **A real installed `chromium`/`chromium-browser`** binary, launched in
   `--app=` mode with its own isolated `--user-data-dir` — no banner, no
   collision with the user's daily browser profile.
3. **The user's daily-driver browser** (Brave/Chrome), same isolated-profile
   `--app=` launch.
4. **The Chromium bundled for the `browser` skill's Playwright setup**
   (`~/.cache/ms-playwright/chromium-*/chrome-linux64/chrome`) — always
   available if that skill has been used, but shows a "Chrome for Testing"
   banner that can't be suppressed via flags. Last resort only.
5. `webbrowser.open()` as the final fallback.

## Live task reactions

A `PreToolUse` hook with **no matcher** (catches every tool call, from any
session — command `brain_event.py`) logs each one to
`~/.claude/brain/events.jsonl`: tool name, a short label (skill name for
`Skill` calls; a description/filename for `Bash`/`Edit`/`Write`/`Read`/etc.),
and the repo it fired in (`cwd` walked up to the nearest `.git` root).
`events.jsonl` is capped at 200 lines — the page tracks the last-seen
event's **timestamp**, not the line count, to detect new ones (a count
comparison breaks permanently once the file fills to its cap, since the
count then never changes again).

Built-in tools (`Bash`, `Read`, `Edit`, etc.) get their own static nodes
(`BUILTIN_TOOLS` in `brain_viz.py`), distinct cyan color, same as skills get
skill nodes — so a plain tool call has something specific to land on, not
just a bare repo pulse. The page polls `events.jsonl` over
`http://127.0.0.1:8765` (a `python3 -m http.server` bound to loopback,
started on demand by `--open`) and, for each new event, fires NOW's **real,
already-on-screen epoch-ray edge** to the resolved skill/tool node and to
the repo node independently (`fireEpochRay/fireLiveTargets`) — not a
fabricated edge directly between them, since skill and repo nodes don't
otherwise connect to each other and a made-up line looked disconnected from
the graph's real synapse network. This is why whatever Claude is doing
right now, in whichever repo, shows up live without needing to be a skill
invocation.

Firing is throttled to one animated burst per 500ms (`PATH_FIRE_THROTTLE_MS`)
so a burst of rapid tool calls (many `Read`/`Edit` in a row) reads as one
steady glow instead of a strobe; the HUD status label still updates on every
event even when the burst itself is skipped. A small green dot bottom-right
shows when the live feed is connected. The page is served over localhost
rather than opened as a bare `file://` page because browsers block `fetch`
of local files from `file://`.

Ambient (idle, non-live) fires happen every 2.5s and pick a random
non-epoch node — since every node's edge set includes its own epoch ray,
these almost always include a pulse toward NOW too, which is not itself
meaningful; the event log (bottom-right, above the node count) labels these
`idle animation, not real activity` to distinguish them from genuine `live`
task events.

## Rendering notes

- Resize detection does **not** trust `window.innerWidth`/`resize`/
  `ResizeObserver` — in the Brave app-mode fallback, none of those update
  for a window-manager-driven resize (confirmed by testing this exact
  window, not just in isolation). The canvas checks its own
  `getBoundingClientRect()` every animation frame instead, which stays
  correct regardless of how the resize happened; changes are still
  debounced 300ms before reallocating the canvas backing store, and the
  view auto-fits pan/zoom to the current node layout once the resize
  settles (`fitToScreen`) — including one guaranteed fit ~2.3s after load
  even if no resize is ever detected, since a window that's opened and
  never touched again otherwise never gets fit to its actual size (the
  physics constants are fixed absolute pixels, not relative to window
  size).
- In the **native pywebview window**, a window-manager-driven resize
  updates the outer GTK window correctly but WebKit2GTK's internal
  viewport doesn't reliably re-measure to match (nodes render as ovals,
  not circles) — `window.events.resized` never fires for that resize path,
  and calling `window.resize()` back with the current size is treated as a
  no-op. `brain_window.py` polls `window.width`/`height` (which do query
  the GTK backend live) and, once a new size has held for two consecutive
  polls (~1s, to avoid a reload storm during an active drag), forces a
  genuine `window.load_url()` reload — that's the one thing that actually
  makes WebKit re-lay-out against the real current size.
- Every node gets a faint permanent glow via a pre-rendered per-color sprite
  blitted with `drawImage` (`glowSpriteFor`) — cheap at 210 nodes/60fps,
  unlike a live gradient or `shadowBlur` per node per frame.
- Idle synapse (edge) opacity is intentionally higher than a typical
  force-graph default (0.22 regular / 0.12 epoch rays) so the connections
  are readable without hovering.
- The physics repulsion force floors at `d2 = 4` (not `0` or a near-zero
  epsilon) and per-frame node speed is clamped to 14px — random launch
  positions landing close together no longer spike the repulsion force and
  teleport nodes across the screen on the first few frames.

## Known gotchas (already hit and fixed once — don't reintroduce)

- Never `pkill -f` by a URL substring or similar broad pattern to close the
  brain window — it can match and kill the user's real browser process
  (happened once; killed their whole Brave session). Close by exact PID or
  window ID only.
- Never share a browser profile dir between different Chromium
  vendors/builds — mismatched prefs/locks silently break rendering. Profile
  dirs are already keyed by browser binary path under
  `~/.claude/brain/.browser-profile/`.
