---
name: brain
description: Regenerates and opens the Claude memory "brain" visualization — a lightweight local graph of local memory, the claude-memory-bank, skills, and git project repos under $HOME, with a live view of skills firing as they're used. Use when the user asks to see, open, or refresh their memory graph/brain visualization.
---

Source: [github.com/BeanGreen247/claude-memory-brain](https://github.com/BeanGreen247/claude-memory-brain)
(local clone: `~/git/claude-memory-brain`). `~/.claude/scripts/brain_*.py` and
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

## Live skill-fire reactions

A `PreToolUse` hook (matcher: `Skill`, command `brain_event.py`) logs every skill
invocation to `~/.claude/brain/events.jsonl`. The page polls that file over
`http://127.0.0.1:8765` (a `python3 -m http.server` bound to loopback, started
on demand by `--open`) and fires that skill's node live — a small green dot
bottom-right shows when the live feed is connected. This is why the page is
served over localhost rather than opened as a bare `file://` — browsers block
`fetch` of local files from a `file://` page.

## Known gotchas (already hit and fixed once — don't reintroduce)

- Never `pkill -f` by a URL substring or similar broad pattern to close the
  brain window — it can match and kill the user's real browser process
  (happened once; killed their whole Brave session). Close by exact PID or
  window ID only.
- Never share a browser profile dir between different Chromium
  vendors/builds — mismatched prefs/locks silently break rendering. Profile
  dirs are already keyed by browser binary path under
  `~/.claude/brain/.browser-profile/`.
