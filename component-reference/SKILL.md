---
name: component-reference
description: |
  Finds and adapts real, high-quality UI component implementations (not
  invented from scratch) for a given need — a pricing table, a command
  palette, a testimonial grid, etc. Use when asked to build a UI component
  and a well-established reference pattern likely exists, or when told to
  "search for a component" or "find inspiration" for a piece of UI. Local
  reimplementation of what the 21st.dev Magic MCP's search/get_component
  tools did, using the browser/websearch skills instead of a paid API —
  no API key, no generation credits.
metadata:
  origin: "local reimplementation, inspired by https://github.com/21st-dev/magic-mcp"
---

# Component Reference

The 21st Dev "Magic MCP" server searched a hosted component registry and generated matching code through a paid AI endpoint. This skill gets equivalent value locally: search for and adapt real, existing implementations instead of generating from a blank page, using only the local `websearch` and `browser` skills (both free/local — never call a paid component-generation API to fill this role).

## When to use

- User asks for a specific, commonly-built UI piece: pricing table, command palette (cmdk-style), testimonial carousel, pattern for auth forms, dashboard stat cards, a particular animation/interaction.
- User says "find inspiration for X" or "how do other sites do X."
- You're about to hand-invent a component from scratch and a well-known reference pattern almost certainly exists — check first, don't reinvent.

## Workflow

1. **Search for real references**, not synthetic examples. Use the `websearch` skill to look for:
   - Open-source component libraries that ship the pattern already (shadcn/ui, Radix primitives, Headless UI, Ariakit, Tailwind UI free samples, Park UI)
   - The 21st.dev public component gallery itself (browsable without an API key at 21st.dev — read-only lookup via the `browser` skill counts as free)
   - Real production sites known for good execution of this pattern
2. **Pull the actual reference**, don't paraphrase from memory. Use `browser` (Playwright) to open the page/component demo and inspect the rendered DOM/CSS, or `websearch` to fetch the library's source file directly (most OSS libraries publish raw source on GitHub — fetch with curl, it's free).
3. **Adapt, don't clone verbatim** unless the license allows and the user wants an exact copy. Match the target project's existing design tokens (colors, spacing scale, font) — see `anti-ai-slop-audit` and `design-craft` for what "looks native to this project" means.
4. **Check the license** of anything copied near-verbatim (MIT/Apache component libraries are fine to adapt; be careful with anything unlicensed or explicitly proprietary) and mention it to the user if it's not permissive.
5. If no good reference turns up after a real search, say so plainly and build from first principles — don't fabricate a "reference" that doesn't exist.

## What this intentionally does not replicate

The Magic MCP's `generate`/`iterate_generation` tools ran a hosted AI model on 21st's paid credits to synthesize novel component code. That's not reproducible locally without calling a metered API, which is against this session's hard rules. This skill covers the free half of Magic MCP (`search`, `get_component`) by doing the equivalent lookup yourself with local tools — the generation step is just you (the agent) writing the adapted code directly, which you're already good at.
