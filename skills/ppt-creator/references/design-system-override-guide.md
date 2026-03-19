# Custom Design System Override
### Read ONLY when the user requests a new or alternative design system.
### Do NOT read at invocation — load only when triggered.

---

## When to Trigger

The user explicitly asks for a non-default design:

- "Use the design from this [NotebookLM / Canva / Google Slides] deck"
- "Generate in a different style — blue/corporate/minimal"
- "Match the colour scheme from [reference image or file]"
- "Create a new design system from scratch"

Trigger the DESIGN-DISCOVERY stage described below.

---

## DESIGN-DISCOVERY Stage

Runs before RESEARCH if the user provides a reference at the start, or can be
triggered mid-session (before STRUCTURE) if the user requests it later.

### Step 1 — Extract design DNA

**If a reference file is provided (PPTX, PDF, PNG, screenshot):**

Run VQA on it (soffice → pdftoppm → Read tool visual inspection):

```bash
soffice --headless --convert-to pdf --outdir /tmp/ds_discovery [reference.pptx] 2>/dev/null
pdftoppm -r 100 -png /tmp/ds_discovery/[reference].pdf /tmp/ds_discovery/slide
```

Extract:
1. **Background colors** — what are the slide background hex values?
2. **Primary brand color** — the dominant accent (buttons, headings, highlights)
3. **Secondary accent** — the supporting color for variety
4. **Text colors** — on dark bg / on light bg / on colored bg
5. **Typography** — font family? size scale? bold patterns?
6. **Layout philosophy** — dense or airy? centered or left-aligned? structured grid or freeform?
7. **Overall mood** — enterprise formal / startup punchy / academic structured / Google Material

**If no file — ask these 5 questions (one at a time):**

```
DESIGN DISCOVERY
──────────────────────────────────────────────────────────────────
I'll build a custom design system for this deck. Quick questions:

1. What is the primary brand colour? (hex or describe: "Google blue",
   "deep navy", "forest green")

2. Light or dark background as the default for body slides?

3. What is the accent / highlight colour?

4. Mood: formal/corporate, technical/developer, bold/punchy, minimal/clean?

5. Any reference I can look at — a URL, a brand guide, or a deck to borrow from?
──────────────────────────────────────────────────────────────────
```

---

### Step 2 — Generate the custom design system

After extracting the DNA, generate a new file at `/tmp/design-system-custom.md`
using the template below. Every field must be filled from the extracted values —
no guessing, no defaults borrowed from the base system.

```markdown
# Custom Design System — [Name / Event / Style]
### Generated from: [source reference]
### Generated: [date]

## Canvas
Dimensions: 10.0" × 5.625"   →   pres.layout = "LAYOUT_16x9"
Safe zone:  x 0.3–9.7,  y 0.22–5.09
Footer zone: y 5.09–5.35

## Colour Palette

const C = {
  // Backgrounds
  primaryBg:   "[hex]",   // main body slide bg
  altBg:       "[hex]",   // secondary bg variant
  accentBg:    "[hex]",   // title/section/close bg

  // Accent
  primary:     "[hex]",   // primary brand colour
  secondary:   "[hex]",   // secondary accent
  tertiary:    "[hex]",   // optional third accent

  // Semantic (inherit if not specified by reference)
  success:     "[hex]",
  warning:     "[hex]",
  error:       "[hex]",

  // Text
  textOnDark:  "[hex]",   // text on primaryBg / accentBg
  textBody:    "[hex]",   // secondary text on dark
  textMuted:   "[hex]",   // captions on dark
  textDark:    "[hex]",   // primary text on light bg
  textMid:     "[hex]",   // secondary text on light bg
};

## Typography

Font family: [Arial | Inter | Roboto | ... — match reference or use Arial as fallback]

Type scale:
  Hero title:     [pt] bold
  Hero subtitle:  [pt] bold
  Section title:  [pt] bold
  Slide title:    [pt] bold
  Body:           [pt] normal
  Caption:        [pt] normal
  Footer mark:    8pt normal

## Layout Philosophy

Background pattern: [dark-dominant / light-dominant / equal mix]
Alignment:         [left-aligned / centered / grid]
Density:           [airy (1 idea/slide) / standard (3-4 points) / dense (data-heavy)]
Card style:        [top-stripe / left-stripe / bordered / flat]

## Primitives to Override

[List which base primitives change — e.g., DS() bg color, accent() colour,
card() fill color. If a primitive is unchanged, say "inherited".]
```

---

### Step 3 — Generate custom boilerplate

Once the design system file is approved, generate a custom `boilerplate-[name].js`
that overrides the following from the standard boilerplate:

- `const C` — replace with custom palette
- `const DS`, `const LS`, `const OS` — update background colors
- `accent()` — update fill color
- Font family if different from Arial

Write to `/tmp/boilerplate-[name].js`.

---

### Step 4 — Confirm before proceeding

```
CUSTOM DESIGN SYSTEM — [Name]
──────────────────────────────────────────────────────────────────
Primary background:  [hex]  [████]
Brand accent:        [hex]  [████]
Secondary accent:    [hex]  [████]
Font:                [family]
Layout:              [philosophy summary]

This replaces the default orange/charcoal system for this deck only.

Does this look right, or should I adjust anything before I start?
──────────────────────────────────────────────────────────────────
```

Wait for confirmation. Only after approval proceed to RESEARCH (or STRUCTURE if
research has already been done).

---

## Restoring the Default

The custom design system applies to ONE deck only. The next `/create-ppt` session
automatically reverts to the default orange/charcoal system from `design-system.md`.

To make a custom system permanent: save the generated file to
`~/.claude/skills/ppt-creator/references/design-system-[name].md` and update
`personal-info.md` with a `default_design_system` field pointing to it.

---

## Quality Rules for Custom Systems

1. **Contrast check** — every text colour against its background must pass WCAG AA (4.5:1 ratio for normal text, 3:1 for large)
2. **Projector test** — yellows and light greens on white are invisible on projectors. Test mentally against a blown-out screen.
3. **Brand coherence** — if the reference is a Google/Microsoft/client deck, the output must be recognisably in that brand family. If it's a personal style, it must feel intentional, not accidental.
4. **Consistency gate** — every slide in the deck must use only the custom palette. No orange bleeding in from the default system.
