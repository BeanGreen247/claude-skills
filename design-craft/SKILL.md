---
name: design-craft
description: "Research-first methodology and senior-designer craft references for UI/product/web design, landing pages, dashboards, product screens, redesigns, visual polish, frontend/CSS styling, design systems, components, responsive design, typography, color, spacing, motion, icons, accessibility, copywriting, conversion, and anti-AI-slop work. Use whenever you are about to design or restyle a real interface or marketing page. Research is mandatory: ground every design in real references (user-provided, or real products pulled up with the websearch/browser skills) plus the bundled craft references before implementing. Provides reference locks, decision ledgers, anti-averaging quality gates. Not for Claude Design canvas mockups (use `design`) or charts (use `dataviz`)."
---

# Design Craft

Research-first design methodology plus bundled craft knowledge. Use it before design
work instead of relying on the model's generic design taste.

This is an MCP-free adaptation of [`referodesign/refero_skill`](https://github.com/referodesign/refero_skill)
(MIT). All live "design API" research is replaced by local, zero-cost research: the
user's own references, real product pages via the `websearch` and `browser` skills, and
the craft references in `references/`. See [references/research.md](references/research.md).
Never call a paid or metered design/inspiration API.

Three research layers:

1. **Visual direction** — look, feel, taste.
2. **Product patterns** — concrete UI a screen must contain, from real products.
3. **Journey logic** — multi-step sequences (onboarding, checkout, cancellation).

Best results combine layers: visual direction for mood, real screens for patterns,
sequencing for multi-step tasks.

## Non-Negotiables

- **Research before design work.** Every design must be grounded in references before
  implementation. Do not rely on generic design taste.
- **Do not copy one reference.** Study several strong references and synthesize a new
  direction for the user's product.
- **Do not average references into a safe middle.** When references conflict, choose one
  dominant direction and preserve its sharp traits. Secondary references add narrow
  details only.
- **Do not change token meanings.** If a reference uses a color, font, radius, shadow,
  gradient, or component for a specific role, use it only for that role or omit it.
- **Respect imagery guidance.** Preserve the media role of a reference. Use real,
  generated, or stock assets when available; otherwise an intentional placeholder with
  fixed dimensions and art direction. Do not fake complex imagery with weak CSS.
- **Research output must be specific.** Name the references, describe concrete choices,
  explain what will be adapted.
- **No design from vibe memory.** Every major visual, layout, content, or interaction
  decision must trace to research, the user's brief, or a craft reference.
- **Synthesize before implementation.** Turn research into a concept, token direction,
  and decision ledger before drawing or coding.
- **A brief is not a build target.** Before implementation, lock a user-provided visual
  source, an existing product/design-system target, a selected mockup, or an explicit
  reference-locked direction approved for direct build.
- **Validate after building visual work.** Compare the render against the locked target
  before handoff. Fix actionable drift instead of treating research as sufficient.

## Research Inputs

Research is mandatory; the engine is local. In priority order:

1. **User-provided references** — screenshots, Figma frames, a URL to match, an existing
   design system, brand guidelines. Ask for them when the task is non-trivial and none
   were given.
2. **Real product pages via the `websearch` skill** — 3–5 real, well-designed products
   in the category; read how they handle type, color, layout, spacing, section rhythm,
   components, copy.
3. **The `browser` skill** — for JS-heavy pages, rendered inspection, responsive checks,
   or screenshots to compare against.
4. **Bundled craft references** — to execute like a senior designer, not as a substitute
   for looking at real products.

Full method: [references/research.md](references/research.md).

## Discovery

Form a short design brief. Ask only for missing information that would materially change
the result; otherwise make reasonable assumptions and proceed.

Clarify: what is being designed; platform (web/iOS/both); audience and technical level;
primary user goal; desired feeling / brand direction; objections to overcome;
constraints (brand, framework, deadline, accessibility, content); whether the task needs
visual direction, concrete patterns, journey logic, or a mix; whether it goes straight
to code, produces visual options first, or generates assets.

```text
Designing [WHAT] for [WHO] on [PLATFORM].
Goal: [PRIMARY USER GOAL].
Tone: [DESIRED FEELING].
Main objection/risk: [OBJECTION].
Must remember: [HOOK OR DISTINCTIVE IDEA].
Constraints: [CONSTRAINTS].
Research needed: [visual direction / screens / flows].
Path: [direct build / visual exploration / audit / asset generation].
```

## Workflow Routing

Choose the lightest workflow that produces a high-quality result.

- **Direct build** — small UI fixes, clear production edits, existing design-system work,
  or a concrete source to match. Research and lock the direction, then code.
- **Visual exploration** — variants, a new visual language, a major redesign, a landing
  page, or another high-visibility surface with several plausible directions. Default to
  three reference-locked options and ask the user to choose; see
  [references/visual-workflow.md](references/visual-workflow.md).
- **Audit** — use captured screenshots or real reference screens as evidence before
  critique.
- **Asset generation** — generated imagery only when the reference lock needs bitmap
  media that code, icons, or existing assets cannot faithfully provide; see
  [references/visual-workflow.md](references/visual-workflow.md).

## Research Workflow

### 1. Visual direction

For any visual task, start here. Loop:

1. Search 3–5 different visual angles (one broad aesthetic, one domain/category, one
   known-strong-product).
2. Study 3–4 strong references in depth. Do not stop at the first good one.
3. Compare what each contributes.
4. Choose one primary foundation; borrow 1–2 specific details from others.
5. Lock the primary reference's signature traits before implementation.

Extract from references: north star / visual thesis; typography personality and type
scale; color roles and accent discipline; spacing density and rhythm; layout system,
section rhythm, composition; card/button/surface treatments; borders, shadows, radius;
elevation rules; component and implementation notes; imagery / illustration / screenshot
treatment; media asset strategy; do/don't rules; one memorable visual move to adapt.

Synthesis rule: primary reference owns mood, density, structure; secondary references
contribute specific borrowed details; adapt everything to the product, audience, task.
Do **not** use the average of all references. If one is dark, one acid, one serif, the
answer is not warm cream + muted orange + polite serif.

Reference lock (write before implementing):

```text
Primary reference/direction: [one dominant source]
Preserve: [3-5 traits that must survive: canvas, type, accent, layout, density, media]
Borrow only: [1-2 specific secondary details]
Role rules: [source token/component meanings to preserve, e.g. CTA-only, code-only, decorative-only]
Media strategy: [real/generated/stock/code-native/placeholder, with aspect ratio and art direction]
Reject: [defaults/averages that would collapse the direction]
Token commitments: [background, type, accent, radius, border/shadow, imagery treatment, with roles]
```

If implementation drifts from the lock, stop and correct it. Do not soften distinctive
traits into safer colors, fonts, radius, or generic section layouts. When combining
sources, give each a bounded job (one owns canvas/type, one owns code-window treatment,
one owns primary CTA) and never move a token outside its source role.

### 2. Screens for product detail

Use real product screens when you need to know what an interface should contain or how
real products solve a specific UI problem. Search by facts on the screen: page type,
component, state, product, on-screen text. Do not use screens as the primary style
source for a visual task — establish visual direction first.

Extract: layout structure; information hierarchy; component choices; CTA patterns;
content/copy patterns; states and edge cases; trust/conversion tactics; concrete details
worth adapting.

### 3. Flows for journey logic

Use when there are multiple steps or the user changes state over time (signup,
onboarding, checkout, cancellation, account deletion, password reset, settings changes).

Extract: entry point and exit state; step count; user decisions; friction reducers;
required confirmations; save/recovery states; error handling; retention moments; system
response at each step.

## Research Depth

- **Quick visual improvement:** 2–3 reference angles, 2–3 studied in depth, 1 short
  synthesis.
- **New landing page / brand direction / major redesign:** 3–5 angles, 3–4 studied,
  screen research for concrete sections, a clear locked direction before implementation.
- **Product workflow:** references for visual language, screens for key states, flows
  for sequencing.
- **High-stakes / ambiguous:** several angles, later results, strong and unusual
  references compared, tradeoffs documented before designing.

## Present Findings

Give a short research summary before designing when the task is non-trivial. Do not dump
every result.

```text
Research summary:
- References reviewed: [count] across [directions]
- Screens reviewed: [count], if used
- Flows reviewed: [count], if used

Visual direction:
- [primary foundation]
- [reference lock / signature traits to preserve]
- [borrowed detail 1]
- [borrowed detail 2]

Product patterns:
- [concrete UI decisions from screens]

Journey logic:
- [flow decisions, if applicable]

Recommendation:
- [what to design and why]
```

Then convert research into a decision ledger:

| Decision | Source | Source rule / role | Why |
|----------|--------|--------------------|-----|
| [palette/type/layout/media/content choice] | [reference/screen/flow/user constraint/craft rule] | [token/component/media role to preserve] | [specific rationale] |

If a major choice has no source, do not ship it as a design decision. Research more, tie
it to the user's constraints, or remove it.

## Design Craft

After research, execute like a senior product designer. Load a reference only when
relevant — not all of them by default.

- Typography: [references/typography.md](references/typography.md)
- Color: [references/color.md](references/color.md)
- Motion: [references/motion.md](references/motion.md)
- Icons: [references/icons.md](references/icons.md)
- Forms, focus, images, touch, performance, accessibility: [references/craft-details.md](references/craft-details.md)
- Copywriting and persuasion: [references/copywriting.md](references/copywriting.md)
- Anti-AI-slop checks: [references/anti-ai-slop.md](references/anti-ai-slop.md)
- Visual exploration, generated assets, visual QA: [references/visual-workflow.md](references/visual-workflow.md)
- Worked example: [references/example-workflow.md](references/example-workflow.md)

Core craft rules:

- Define tokens before implementation: type scale, colors, spacing, radius, shadows.
- Preserve the primary reference's strongest traits instead of normalizing them.
- Preserve token roles: do not turn a CTA accent into a background, a code-only color
  into UI chrome, or a decorative gradient into an interface surface.
- Preserve imagery roles: capable assets when available, otherwise an honest, well-sized
  placeholder over a poor fake.
- Use brand-appropriate colors from research. Do not default to indigo/violet.
- Treat "calm editorial" (warm ivory canvas, oversized serif, one italic word, muted
  clay/olive) as a current AI-slop risk. Do not use it by default.
- Avoid generic hero → features grid → pricing → FAQ → CTA unless research supports it.
- Use real product evidence for copy, trust signals, objection handling, section order.
- Create at least one memorable detail users would remember.
- Balance headings with `text-wrap: balance`; use `text-wrap: pretty` selectively for
  prose. Check breakpoints for orphan words.
- Keep accessibility and responsive behavior in the design, not as a late pass.

## Quality Gate

Before final delivery, confirm:

- Did I research real references for visual taste rather than design from memory?
- Did I avoid copying one reference directly?
- Did I synthesize multiple references into a unique direction?
- Did I avoid averaging references into a safe centroid?
- Did I preserve the primary reference's signature traits?
- Did I preserve source token/component roles?
- Did I preserve required imagery/media roles with real assets, primitives, or
  intentional placeholders?
- Did I use screens when concrete UI patterns were needed, and flows for multi-step
  tasks?
- Can I name which references influenced the design and why?
- Can every major choice be traced to a reference, user constraint, or craft rule?
- Did I produce a concept and decision ledger before implementation?
- Does the implementation avoid generic AI design defaults (indigo, default cards, dark
  by default, decorative serif word swaps, emoji icons, left accent stripes)?
- Does the result fit the user's product, audience, and constraints?

If the answer is no, research or refine more before delivering. For substantial visual
work, run the visual QA pass in
[references/visual-workflow.md](references/visual-workflow.md) before handoff.
