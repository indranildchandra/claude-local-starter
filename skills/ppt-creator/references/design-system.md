# Personal Presentation Design System
### Source: RAG Done Right Production.pptx — extracted via python-pptx + visual analysis
### All values from the reference deck. Do not invent or approximate.

---

## Canvas

```
Dimensions : 10.0" × 5.625"   →  pres.layout = "LAYOUT_16x9"
Safe zone  : x 0.3–9.7,  y 0.22–5.09
Footer zone: y 5.09–5.35  →  slide number only
```

---

## Colour Palette — C

```js
const C = {
  // Slide backgrounds — only these three, never anything else as slide bg
  darkBg:      "282828",   // charcoal — dark content slides
  lightBg:     "F2F2F2",   // near-white — framework / evidence slides
  orangeBg:    "E84000",   // vivid orange-red — intro, section, close slides

  // Card surfaces (on dark slides only)
  cardDark:    "3A3A3A",   // card fill on dark slides
  cardDeep:    "2A2A2A",   // deeper card / nested fill

  // Accent / semantic colors
  orange:      "E84000",   // primary brand — tags, accents, nrow stripe
  green:       "27AE60",   // positive, success (darker)
  lightGreen:  "4ADE80",   // bright positive metric label
  blue:        "2980B9",   // informational, architecture
  lightBlue:   "7DD3FC",   // secondary info, code highlight labels
  purple:      "9B59B6",   // advanced / complex technique
  yellow:      "FFC000",   // cost, caution, warning
  red:         "CC2222",   // errors, critical
  lightRed:    "FF6666",   // error text on dark slides

  // Text
  textOnDark:  "FFFFFF",   // primary body / titles on dark or orange bg
  textBody:    "AAAAAA",   // secondary body text on dark bg
  textMuted:   "888888",   // muted captions / footnotes on dark bg
  textDark:    "1A1A1A",   // primary text on light bg
  textMid:     "555555",   // secondary text on light bg  ← LIGHT SLIDES ONLY
  textCaption: "777777",   // captions on light bg
};
```

**Colour role reference:**

| Token | Use |
|-------|-----|
| darkBg | Dark slide bg only |
| lightBg | Light slide bg only |
| orangeBg | Orange intro / section / close bg only |
| orange | Tags, nrow stripe, accents — visible on any bg |
| lightGreen | Positive metrics, success labels on dark bg |
| lightBlue | Code labels, secondary info on dark bg |
| yellow | Cost / caution metrics on dark bg |
| textOnDark | ALL text on dark or orange slides — titles, bullets, labels |
| textBody | Secondary body copy on dark slides — NEVER on light slides |
| textMuted | Captions / footnotes on dark slides only |
| textMid | Secondary text on light slides only — **NEVER on dark/orange** |
| textCaption | Caption text on light slides only |

---

## Dark Slide Contrast Rules — ABSOLUTE

The charcoal dark bg (`#282828`) is near-black. textMid (`#555555`) is nearly
invisible. textBody (`#AAAAAA`) is the correct secondary grey for dark slides.

### What is BANNED on DS() and OS() slides:

| Element | Banned value | Correct value |
|---------|-------------|---------------|
| Body / bullet text | `C.textMid` (`#555555`) | `C.textOnDark` or `C.textBody` |
| Caption / secondary text | `C.textMid` | `C.textMuted` (`#888888`) |
| Metric / stat label | `C.textCaption` | accent color (lightGreen / yellow / orange) |

### On DS() / OS() slides, ONLY these text colours are allowed:
- `C.textOnDark` — titles, primary bullets, primary body
- `C.textBody` — secondary body copy, supporting text
- `C.textMuted` — captions, footnotes, italic annotations
- Accent colors (orange, green, lightGreen, blue, lightBlue, purple, yellow, red, lightRed) — labels only

---

## Typography

```js
// Single font — Arial throughout. No Google Fonts dependency.
// fontFace: "Arial" on every addText() call — no exceptions.

// Line spacing: apply lineSpacingMultiple: 1.15 to all body text with h > 0.30
// Skip for: slide numbers, metric numbers, single-line labels (h ≤ 0.30)
```

**Size scale:**

| Role | pt | Weight | Colour |
|------|----|--------|--------|
| Intro title (large) | 72 | bold | textOnDark |
| Intro subtitle | 52 | bold | textOnDark |
| Intro tagline | 34 | normal | textOnDark |
| Section number (giant) | 160 | bold | textOnDark |
| Section title | 44 | bold | textOnDark |
| Dark slide title | 26 | bold | textOnDark |
| Dark slide subtitle | 12 | normal | textBody |
| Light slide title | 34 | bold | textDark |
| Light slide subtitle | 13 | normal | textMid |
| nrow technique title | 15 | bold | textOnDark |
| nrow technique number | 24 | bold | orange |
| nrow body | 11 | normal | textBody |
| nrow metric | 12 | bold | lightGreen (or accent) |
| Card title | 13 | bold | accent color |
| Card body | 11–13 | normal | textBody or textOnDark |
| Tag label | 11 | bold | textOnDark |
| Footnote | 8–9 | normal | textMuted (dark) / textCaption (light) |
| Slide number | 10 | normal | textOnDark |

---

## Primitives

Copy verbatim into every deck. Never modify signatures.

```js
// Shadow factories — call inline, NEVER assign and reuse (pptxgenjs mutates)
const mks  = () => ({ type: "outer", blur: 6,  offset: 2, angle: 135, color: "000000", opacity: 0.28 });
const mksl = () => ({ type: "outer", blur: 14, offset: 3, angle: 135, color: "000000", opacity: 0.45 });

// Slide factories
const DS = () => { const s = pres.addSlide(); s.background = { color: C.darkBg   }; return s; };
const LS = () => { const s = pres.addSlide(); s.background = { color: C.lightBg  }; return s; };
const OS = () => { const s = pres.addSlide(); s.background = { color: C.orangeBg }; return s; };

// Horizontal rule — h MUST be 0
const hr = (s, y, x = 0.4, w = 9.2, c = C.textOnDark) => {
  s.addShape(pres.shapes.LINE, { x, y, w, h: 0, line: { color: c, width: 0.75 } });
};

// Accent pill — call FIRST on every DS() and OS() slide
function accent(s, c = C.textOnDark) {
  s.addShape(pres.shapes.RECTANGLE, {
    x: 0.4, y: 0.3, w: 0.55, h: 0.08,
    fill: { color: c }, line: { color: c }
  });
}

// Dark-slide standard title + optional subtitle
function dt(s, title, sub) {
  s.addText(title, {
    x: 0.4, y: 0.22, w: 9.2, h: 0.62,
    fontSize: 26, bold: true, color: C.textOnDark, fontFace: "Arial", margin: 0
  });
  if (sub) s.addText(sub, {
    x: 0.4, y: 0.88, w: 9.2, h: 0.28,
    fontSize: 12, color: C.textBody, fontFace: "Arial", margin: 0
  });
}

// Light-slide title + optional subtitle
function lt(s, title, sub) {
  s.addText(title, {
    x: 0.4, y: 0.65, w: 9.2, h: 0.7,
    fontSize: 34, bold: true, color: C.textDark, fontFace: "Arial", margin: 0
  });
  if (sub) s.addText(sub, {
    x: 0.4, y: 1.38, w: 9.2, h: 0.3,
    fontSize: 13, color: C.textMid, fontFace: "Arial", margin: 0
  });
}

// Numbered technique row — use on DS() slides
// h: height of row (default 1.15" — increase for longer body text)
// metric: optional right-aligned stat string. mc: metric color (default lightGreen)
function nrow(s, num, title, body, metric, mc, y, h = 1.15) {
  s.addShape(pres.shapes.RECTANGLE, {
    x: 0.3, y, w: 9.4, h,
    fill: { color: C.cardDark }, line: { color: C.cardDark }, shadow: mks()
  });
  s.addShape(pres.shapes.RECTANGLE, {
    x: 0.3, y, w: 0.07, h,
    fill: { color: C.orange }, line: { color: C.orange }
  });
  s.addText(num, {
    x: 0.5, y: y+0.12, w: 0.65, h: 0.42,
    fontSize: 24, bold: true, color: C.orange, fontFace: "Arial", margin: 0
  });
  s.addText(title, {
    x: 1.25, y: y+0.08, w: 5.9, h: 0.36,
    fontSize: 15, bold: true, color: C.textOnDark, fontFace: "Arial", margin: 0
  });
  s.addText(body, {
    x: 1.25, y: y+0.48, w: 5.9, h: h-0.58,
    fontSize: 11, color: C.textBody, fontFace: "Arial", margin: 0, lineSpacingMultiple: 1.15
  });
  if (metric) s.addText(metric, {
    x: 7.4, y: y+0.15, w: 2.2, h: h-0.3,
    fontSize: 12, bold: true, color: mc || C.lightGreen,
    fontFace: "Arial", align: "right", margin: 0
  });
}

// Two-panel card frame with colored left stripe — use on DS() slides
function card(s, x, y, w, h, ac) {
  s.addShape(pres.shapes.RECTANGLE, {
    x, y, w, h,
    fill: { color: C.cardDark }, line: { color: ac, width: 1.5 }, shadow: mksl()
  });
  s.addShape(pres.shapes.RECTANGLE, {
    x, y, w: 0.07, h,
    fill: { color: ac }, line: { color: ac }
  });
}

// Card title — call immediately after card()
function ctitle(s, x, y, w, txt, c) {
  s.addText(txt, {
    x: x+0.14, y: y+0.13, w: w-0.22, h: 0.34,
    fontSize: 13, bold: true, color: c, fontFace: "Arial", margin: 0
  });
}

// Orange label tag — use on LS() slides to label a column or section
function tag(s, txt, x = 0.4, y = 0.2, w = 2.0) {
  s.addShape(pres.shapes.RECTANGLE, {
    x, y, w, h: 0.33,
    fill: { color: C.orange }, line: { color: C.orange }
  });
  s.addText(txt, {
    x: x+0.04, y: y+0.03, w: w-0.08, h: 0.27,
    fontSize: 11, bold: true, color: C.textOnDark, fontFace: "Arial", margin: 0
  });
}

// Slide number — always bottom-right
function slideNum(s, n) {
  s.addText(String(n), {
    x: 9.25, y: 5.09, w: 0.60, h: 0.43,
    fontSize: 10, fontFace: "Arial",
    color: C.textOnDark, align: "right", valign: "middle", margin: 0
  });
}

// Source footnote — call on slides with web-sourced data
// citations: array of strings, max 2. onDark: true for DS()/OS() slides.
function sourceFootnote(s, citations, onDark) {
  if (!citations || citations.length === 0) return;
  const col = onDark ? C.textMuted : C.textCaption;
  if (citations.length === 1) {
    s.addText(citations[0], {
      x: 0.4, y: 4.85, w: 9.2, h: 0.22,
      fontSize: 8, fontFace: "Arial", color: col, valign: "middle", margin: 0
    });
  } else {
    s.addText(citations[0], {
      x: 0.4, y: 4.72, w: 9.2, h: 0.16,
      fontSize: 7.5, fontFace: "Arial", color: col, valign: "middle", margin: 0
    });
    s.addText(citations.slice(1).join("   "), {
      x: 0.4, y: 4.89, w: 9.2, h: 0.16,
      fontSize: 7.5, fontFace: "Arial", color: col, valign: "middle", margin: 0
    });
  }
}

// Full orange section slide — returns slide object
function sectionSlide(num, title, subtitle) {
  const s = OS();
  accent(s, C.textOnDark);
  hr(s, 0.55);
  s.addText(num, {
    x: 0.3, y: 1.35, w: 3.9, h: 2.6,
    fontSize: 160, bold: true, color: C.textOnDark, fontFace: "Arial", margin: 0, align: "right"
  });
  s.addShape(pres.shapes.LINE, {
    x: 4.65, y: 1.2, w: 0, h: 3.2,
    line: { color: C.textOnDark, width: 1.5 }
  });
  s.addText(title, {
    x: 4.9, y: 1.6, w: 4.8, h: 1.1,
    fontSize: 44, bold: true, color: C.textOnDark, fontFace: "Arial", margin: 0
  });
  s.addText(subtitle, {
    x: 4.9, y: 2.85, w: 4.8, h: 0.9,
    fontSize: 20, color: C.textOnDark, fontFace: "Arial", margin: 0
  });
  hr(s, 5.15);
  return s;
}
```

---

## Layout Grid

```
Slide: 10.0" × 5.625"
Safe zone: x=0.3–9.7   y=0.22–5.09
Footer zone: y=5.09–5.35

Standard content start Y:
  After dt() title + subtitle: y ≈ 1.2
  After lt() title + subtitle: y ≈ 1.78

3-col layout:
  Width per col: 3.1"   x positions: 0.32 | 3.52 | 6.72

2-col layout (equal):
  Width per col: 4.55"  x positions: 0.3  | 5.12
  Gap: 0.27"

nrow standard heights:
  1-line body: h=1.15   2-line body: h=1.4   3-line body: h=1.65

Footnote Y positions:
  Single citation: y=4.85
  Two stacked:     y=4.72 (first), y=4.89 (second)
```

---

## Type Scale — Named Roles

Use only these sizes. No other font sizes in any deck.

| Role name | pt | Weight | Where used |
|-----------|----|--------|-----------|
| `T_HERO` | 72 | bold | Title slide main title |
| `T_HERO_SUB` | 52 | bold | Title slide subtitle |
| `T_HERO_TAG` | 34 | normal | Title slide tagline / event line context |
| `T_SECTION` | 44 | bold | Section slide title (right of divider) |
| `T_SECTION_GIANT` | 160 | bold | Section slide giant number |
| `T_SLIDE_TITLE` | 26 | bold | Dark/light content slide title |
| `T_SLIDE_SUB` | 12 | normal | Dark slide subtitle (below title) |
| `T_LIGHT_TITLE` | 34 | bold | Light slide title |
| `T_LIGHT_SUB` | 13 | normal | Light slide subtitle |
| `T_NROW_NUM` | 24 | bold | Numbered row: the number |
| `T_NROW_TITLE` | 15 | bold | Numbered row: technique name |
| `T_NROW_BODY` | 11 | normal | Numbered row: body copy |
| `T_NROW_METRIC` | 12 | bold | Numbered row: right-aligned stat |
| `T_CARD_TITLE` | 13 | bold | Card header |
| `T_CARD_BODY` | 11–13 | normal | Card body copy |
| `T_TAG` | 11 | bold | Orange label tag |
| `T_SPEAKER` | 22 | bold | Speaker name on title / close slides |
| `T_SPEAKER_ROLE` | 15 | normal | Speaker role / website on title / close |
| `T_EVENT` | 13 | normal | Event name + year on title slide |
| `T_FOOTNOTE` | 8–9 | normal | Source citations |
| `T_SLIDE_NUM` | 10 | normal | Slide number |
| `T_BRAND_MARK` | 8 | normal | Persistent website watermark in footer |

**Rule:** if you find yourself wanting a size not in this table, map to the nearest role. Never invent an ad-hoc size.

---

## Colour Semantic Roles — Extended

| Token | Semantic role | Where it appears |
|-------|--------------|-----------------|
| `orange` | Primary brand, emphasis, call-to-action | nrow stripe, tag bg, accent pill, orange BG slides |
| `teal` | Technical layer, code context, infrastructure | Code banner backgrounds, callout borders, architecture labels |
| `amber` | Neutral / cautionary metric | Middle-tier data, "partial progress" stats, cost context |
| `blue` | Information, system, architecture | Architecture diagram nodes, informational labels |
| `lightBlue` | Secondary tech reference | Code highlight labels, pipeline stage labels |
| `green` | Success, positive outcome | Confirmed metrics, green-path states |
| `lightGreen` | Bright positive KPI | Hero metrics that are positive results |
| `purple` | Advanced / complex | Cutting-edge technique labels, research context |
| `yellow` | Cost, caution | Cost metrics, warning states, trade-off flags |
| `red` / `lightRed` | Error, critical failure | Error states, blocking issues |

---

## Orange as Punctuation — Not Decoration

The three-background system (orange / charcoal / light) works because each background
has a distinct job. Coherence comes from discipline, not from avoiding orange.

| Background | Job | Frequency |
|-----------|-----|-----------|
| `DS()` charcoal | Carries the argument — evidence, techniques, code, data | ~65–70% of slides |
| `LS()` light | Relief and framework — categorisation, comparisons, reference | ~15–20% of slides |
| `OS()` orange | Structural punctuation — opening, section breaks, close | ~10–15% of slides (max 6 in a 20-slide deck) |

**Why orange works:** The charcoal deck is high-density and visually heavy. Orange slides
give the room a beat — they signal "chapter change" and let the audience reset before the
next argument. The contrast is the point. A keynote that never changes temperature feels
like a lecture; orange slides control the room's energy.

**Why orange fails:** It fails when used as decoration (colourful bullet slides), when
placed back-to-back (the contrast disappears), or when it outnumbers the content slides
(the deck feels like a brochure, not an argument).

**The test:** every OS() slide should represent a genuine structural transition.
If you can't name the transition it marks, it shouldn't be orange.

---

## Layout Sequence Grammar

Every deck must follow this narrative grammar. Deviating from it breaks the speaker brand.

```
Slide 1:    ORANGE-TITLE         — always the opening
Slide 2:    DS() or ORANGE-SPEAKER  — credibility beat or immediate hook
            (never jump straight to data — earn the audience's trust first)

Body loop:
  ORANGE-SECTION               — opens each major section
  DS() DARK-CONTENT            — hook or bold assertion (first slide of section)
  DS() / LS() evidence slides  — supporting data, diagrams, code
  (LS() slides every 3–4 dark slides — let the eye rest)

Pre-close:
  DS() synthesis / "so what"   — name the lesson before asking for action

Final:
  ORANGE-CLOSE                 — always the last slide the audience sees
  (DS() DARK-CITATIONS         — after CLOSE for source mode A/C decks only)
```

**Sequence rules:**
- Never two consecutive ORANGE slides (except TITLE → first SECTION if no slide 2 beat)
- Never more than 4 consecutive DS() slides without a LS() or OS() break
- Every ORANGE-SECTION must be followed immediately by a DS() content slide
- The final body slide before ORANGE-CLOSE must be DS() (the synthesis / "so what")

---

## Content Density Budget

These are hard limits. Enforce in STRUCTURE and QA.

| Slide type | Max words of body text | Max bullet points | Max data points |
|-----------|----------------------|------------------|----------------|
| DARK-CONTENT | 40 | 3 | 1 hero stat |
| DARK-NROW | 20 per row | n/a | 1 metric per row |
| DARK-2COL | 30 per column | 4 per column | 2 |
| LIGHT-3COL | 25 per column | 4 per column | 2 per column |
| LIGHT-CONTENT | 60 | 5 | 3 |
| INFOGRAPHIC-EMBED | 20 (caption only) | n/a | unlimited (in graphic) |

**Rule:** if you're over budget, the slide is doing too much. Split it or cut it.

---

## Speaker Brand Primitives

### speakerMark(s, website)

Persistent footer brand on every non-title, non-section, non-close slide.
Sits in the footer zone (below safe zone) at bottom-left, mirroring the slide number.

```js
function speakerMark(s, website) {
  if (!website) return;
  s.addText(website, {
    x: 0.3, y: 5.09, w: 5.0, h: 0.35,
    fontSize: 8, fontFace: "Arial", color: C.textMuted,
    valign: "middle", margin: 0
  });
}
```

Call on: every DS() and LS() body slide. Do NOT call on OS() slides (title/section/close).

### lCardLeft(s, x, y, w, h, ac)

Light-background card with left-side accent stripe. Confirmed from RAG deck slide 7.

```js
function lCardLeft(s, x, y, w, h, ac) {
  s.addShape(pres.shapes.RECTANGLE, {
    x, y, w, h,
    fill: { color: "EBEBEB" }, line: { color: "D0D0D0", width: 0.75 }, shadow: mks()
  });
  s.addShape(pres.shapes.RECTANGLE, {
    x, y, w: 0.05, h,
    fill: { color: ac }, line: { color: ac }
  });
}
```

---

## Context Variants

Same design system, different content emphasis depending on the audience.

| Context | Trigger phrases | Emphasis |
|---------|----------------|----------|
| **Developer / GDG DevFest** | "meetup", "DevFest", "GDG", "hackathon", "engineers" | More code slides, architecture diagrams, hands-on patterns, DARK-NROW for techniques |
| **Enterprise / conclave** | "conclave", "CXO", "enterprise", "board", "industry", "summit" | More metrics, business impact framing, fewer code slides, LIGHT slides for frameworks |
| **Conference keynote** | "keynote", "conference", "main stage" | Strong narrative arc, single bold claim per slide, max visual density |
| **Workshop / tutorial** | "workshop", "tutorial", "hands-on" | Step-by-step DARK-NROW heavy, code screenshots, more slides at slower pace |

Apply context at STRUCTURE stage: adjust layout selection and content depth based on context without changing any design values.

---

## Cross-Platform Compatibility — PowerPoint & Google Slides

Every deck is generated as .pptx by pptxgenjs. It must render correctly in both
Microsoft PowerPoint (Windows/macOS) and Google Slides (import via Drive).

### Fonts

| Font | PowerPoint | Google Slides | Verdict |
|------|-----------|--------------|---------|
| **Arial** | ✅ System font, always available | ✅ Resolved from Google's font CDN on import | **Use — safe on all platforms** |
| Helvetica | ✅ macOS only | ⚠️ Substituted with Arial | Avoid |
| Calibri | ✅ Windows/Office only | ⚠️ Substituted | Avoid |
| Roboto / Inter | ❌ Not in .pptx | ⚠️ Works in native Google Slides, not in .pptx | Avoid for .pptx |
| Courier New | ✅ Universal system font | ✅ Available | **Use for code blocks only** |

**Rule:** Arial for all display and body text. Courier New for code blocks only. No other fonts.

pptxgenjs does not embed fonts — it stores the name. Both PowerPoint and Google Slides
resolve "Arial" from the system, making it the only safe choice for cross-platform .pptx.

### Colours

All palette tokens use standard sRGB hex values. Both PowerPoint and Google Slides
render sRGB identically on screen. No compatibility risk. ✅

Projection note: vivid saturated colours (orange `#E84000`, lightGreen `#4ADE80`) may
wash out on underpowered projectors. The high-contrast palette is already optimised for
this — dark backgrounds make even washed-out colours legible.

### Shadows

| Element | PowerPoint | Google Slides (import) |
|---------|-----------|----------------------|
| `mks()` card shadow (blur 6) | Renders exactly | ⚠️ Slightly softer — acceptable |
| `mksl()` deep shadow (blur 14) | Renders exactly | ⚠️ Lighter — still visible |
| Text drop shadow | Supported | ❌ Dropped on import — do not use |

**Rule:** use only shape shadows (`mks`/`mksl`), never text shadows. Shape shadows
degrade gracefully in Google Slides; text shadows disappear completely.

### Text rendering at small sizes

Google Slides uses a slightly different text layout engine. Risk at small sizes:

| Size | Risk |
|------|------|
| ≥ 13pt | No difference |
| 11–12pt | ~1px height difference — use h ≥ 0.28 |
| 8–9pt (footnotes) | ⚠️ May render 1–2px taller — use h = 0.28 minimum for footnotes |

The `sourceFootnote()` function uses h=0.22 for single citations — safe in PowerPoint
but may clip in Google Slides at 7.5pt. If Google Slides fidelity matters, increase
footnote `h` to 0.28 and reduce font size to 7pt.

### Rich text (code slides)

pptxgenjs generates proper OOXML `<a:r>` (run) elements with colour overrides.
Google Slides preserves these on import — code slides remain fully editable with
all token colours intact. ✅

### Images (QR codes, infographics, artifacts)

PNG images are base64-embedded in the .pptx XML. Fully preserved in Google Slides. ✅
The 300dpi renders (2820×1008px) stay crisp in Google Slides and on export to PDF. ✅

### What changes on Google Slides import

1. Shadows appear slightly softer (acceptable — cards still clearly float)
2. Some fonts may shift ±1pt rendering (not visible at presentation scale)
3. PowerPoint animations (if any) are dropped — we don't use animations, so no impact
4. Slide transitions are dropped — we don't use transitions, no impact

**Summary: all production decks are safe for Google Slides without any modification.**

---

## Production Rules

1. Every `addText()` specifies `fontFace: "Arial"`
2. DS()/OS() slides: accent(s) called first
3. DS()/OS() text: `C.textOnDark`, `C.textBody`, `C.textMuted`, or accent colors only
4. LS() text: `C.textDark` (primary) or `C.textMid` (secondary)
5. Nothing below y=5.09 except `slideNum()` and `speakerMark()`
6. Fresh object literal per addShape/addText call — never reuse
7. Shadow factories called inline: `shadow: mks()` — never store and reuse
8. `hr()` always has implicit `h: 0` (LINE shape, not rectangle)
9. `speakerMark()` on every DS() and LS() body slide — skip OS() slides
10. Never invent a font size outside the Type Scale table
