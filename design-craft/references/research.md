# Research Method (No Paid API)

This skill's research is **mandatory** but runs entirely on local, zero-cost tools.
There is no Refero MCP and no metered design API. Replace "call the design API" with
the sources below.

## Three research layers

Same model as the original methodology, different engine:

1. **Visual direction / taste** — how the product should look and feel.
2. **Product patterns / screens** — what a given screen must contain and how real
   products solve it.
3. **Journey logic / flows** — multi-step sequences (onboarding, checkout, cancellation).

## Research sources, in priority order

1. **User-provided references.** Screenshots, Figma frames, a URL to match, an existing
   design system, brand guidelines. Always the strongest signal — ask for them if the
   task is non-trivial and none were given.
2. **Real product pages via the `websearch` skill.** Pull up 3–5 real, well-designed
   products in the relevant category and read how they handle type, color, layout,
   spacing, section rhythm, component treatments, and copy. Prefer named strong products
   (Linear, Stripe, Vercel, Attio, Raycast, shadcn, etc.) over generic galleries.
3. **The `browser` skill** for JS-heavy pages, or when you need to see the actual
   rendered page, inspect responsive behaviour, or capture a screenshot to compare
   against.
4. **Bundled craft references** in this folder — typography, color, motion, icons,
   craft-details, copywriting, anti-ai-slop. These encode senior-designer defaults; use
   them to execute, not as a substitute for looking at real products.

Never call any paid or metered design/inspiration API. If no network tool is available,
say so, work from the bundled craft references plus the user's brief, and flag that the
visual research was limited.

## Research loop

1. Form a short brief (see SKILL.md "Discovery").
2. Search 3–5 different angles: one broad aesthetic, one domain/category, one
   known-strong-product, plus screen/flow queries when structure or sequencing matters.
3. Study several strong references — do not stop at the first good one.
4. Extract concrete traits (see the extraction lists in SKILL.md): visual thesis, type
   personality, color roles + accent discipline, spacing density, layout/section rhythm,
   surface/border/shadow treatment, imagery role, one memorable move, do/don't rules.
5. Choose **one** primary foundation; borrow 1–2 specific details from others.
6. Write the reference lock and decision ledger before implementing.
7. After building substantial visual work, compare the render against the lock and fix
   drift (see visual-workflow.md).

## What weak research looks like

- "Modern SaaS style" with no named references.
- One reference copied wholesale.
- Several strong references averaged into a safe cream/serif/muted-clay middle.
- Tokens lifted from a reference but used for the wrong role.
- Craft references quoted while no real product was ever looked at.
