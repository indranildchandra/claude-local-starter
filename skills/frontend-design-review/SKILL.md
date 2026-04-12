---
name: frontend-design-review
description: Five-step design critique audit — hierarchy, typography, spacing, color, and production quality. Diagnostic, not generative. Attach a design screenshot and work through each prompt in order.
disable-model-invocation: true
---

# frontend-design-review

A surgical, five-step audit for catching visual quality issues in UI designs.
Each step is a focused diagnostic with specific, ranked fixes — no vague feedback.

## When to use

- You have a design (screenshot, mockup, or live UI) that "feels off" and you can't name why
- You want a pre-shipping quality check across the key design dimensions
- You need actionable fixes with specific values, not general direction

## How it works

Invoke via `/frontend-design-review`. Attach your design image or describe the design.
The command runs all five prompts in sequence and ends with a ranked summary.

## Prompt index

| Step | File | What it diagnoses |
|------|------|------------------|
| 01 | `prompts/01-visual-hierarchy-surgeon.md` | Where the eye goes vs where it should go |
| 02 | `prompts/02-typography-interrogation.md` | Pairing, scale, spacing, weight signal |
| 03 | `prompts/03-whitespace-pressure-test.md` | Macro/micro spacing, breathing room, perceived value |
| 04 | `prompts/04-color-contrast-stress-test.md` | Palette logic, emotion, accessibility, sophistication |
| 05 | `prompts/05-why-does-this-look-cheap.md` | Root cause diagnosis + 10x treatment |

## Rules

- Run steps in order — each builds on the prior diagnosis
- Give specific values (px, rem, contrast ratios) not directions ("make it bigger")
- Name the element, name the fix
- Rank all fixes by impact
- Be direct — this is a design doctor, not a design cheerleader
