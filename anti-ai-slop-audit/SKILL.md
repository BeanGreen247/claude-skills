---
name: anti-ai-slop-audit
description: |
  Detects and fixes the visual/UX tells that mark a frontend as AI-generated —
  overused fonts, purple-to-blue gradients, nested cards, gray-on-color text,
  rounded-square icon tiles, bounce easing, and generic SaaS-template layout.
  Use before shipping any UI, after generating a new page/component, or when
  asked to "polish", "audit", "critique", "harden", or "make this look less AI"
  for a frontend. Local reimplementation of the Impeccable design skill's
  anti-pattern checklist and command vocabulary — no external binary or API.
metadata:
  origin: "local reimplementation, inspired by https://github.com/pbakaus/impeccable"
---

# Anti-AI-Slop Design Audit

Every model trained on the same SaaS templates converges on the same tells. This skill is a checklist-driven pass to catch and remove them. It complements the fuller `design-craft` skill (reference-first methodology) — reach for this one specifically for the fast "does this look AI-generated" pass.

## The tells to hunt for

**Typography**
- Inter, Arial, or system-default font used for everything with no pairing or hierarchy
- Only 2 font sizes on the page (heading + body), no intermediate scale
- Centered body text in paragraphs longer than one line

**Color**
- Purple-to-blue (or pink-to-orange) gradient used as the primary brand treatment
- Gray text directly on a saturated/colored background (fails contrast, looks washed out)
- Pure black (#000) or pure gray (#808080-family) instead of a tinted near-black/near-white
- Every interactive element the same single accent color with no state variation

**Layout**
- Cards nested inside cards, or a card wrapping a single stat with nothing else
- A rounded-square icon tile sitting above every section heading (the "feature grid" tell)
- Symmetric 3-column feature grids used regardless of whether the content has 3 natural items
- Excessive whitespace padding that reads as empty rather than intentional
- Hero section: giant centered headline + centered subhead + centered CTA button, no asymmetry

**Motion**
- Bounce/elastic easing on any transition (reads dated, not delightful)
- Fade-in-on-scroll applied uniformly to every element with no variation in timing/distance
- Hover states that only change opacity, never scale/shadow/color together

**Copy**
- Generic microcopy: "Get Started", "Learn More", "Unlock your potential", "Empowering X to Y"
- Placeholder-sounding testimonials or stat counters with round suspicious numbers (10,000+, 99.9%)

**Structure/robustness** (the "harden" pass)
- No empty state designed (list/table with zero items just renders blank)
- No error state designed (form failure has no visible feedback)
- Long text/usernames untested — check for overflow/truncation
- No loading state between action and result

## Commands (run any of these as a mode)

Invoke by asking for the mode by name, e.g. "run an anti-ai-slop polish pass on the settings page":

- **audit** — walk the tells above against the target, list every match with file:line, no fixes yet
- **critique** — UX review: hierarchy, clarity, does the page communicate one clear thing first
- **polish** — final pass: fix everything `audit` found, alignment/spacing/consistency sweep
- **bolder** — the design is too safe/generic; push contrast, scale, and color further
- **quieter** — the design is trying too hard; strip decoration, increase restraint
- **distill** — remove everything that doesn't serve the page's one job
- **harden** — add missing empty/error/loading states and check text-overflow edge cases
- **typeset** — fix font choice, type scale, and hierarchy specifically
- **layout** — fix spacing, alignment, and visual rhythm specifically
- **colorize** — introduce one deliberate accent color relationship instead of a gradient default

## Workflow

1. Read the target file(s)/page fully before judging — don't flag from a screenshot alone if the code is available.
2. Match against the tells list above; for each hit, cite the specific line/class/style.
3. If a live dev server is available, use the `browser` skill to actually look at the rendered page before and after — don't judge from markup alone when layout/spacing is the concern.
4. Apply fixes directly (this is not a read-only report unless the user asked for `audit` specifically).
5. Prefer specific, opinionated choices over safe middle-ground ones — the goal is a page that looks like someone made deliberate decisions, not one that avoids all tells by being bland.
