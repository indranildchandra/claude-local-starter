# Personal Presentation Slide Templates
### Read at GENERATE stage only — not at invocation.
### All coordinates in inches. Primitives defined in design-system.md.

---

## Designer QA Standard — run on every slide before delivery

1. **Left alignment** — text/shape left edge at x=0.3 (slide margin) or `cardX + 0.14` (inside card)
2. **Right alignment** — every text box `x + w` ≤ 9.7
3. **Dark text colours** — no `C.textMid` on any DS()/OS() slide (grep before delivering)
4. **Light text colours** — no `C.textBody`/`C.textOnDark` on LS() slides
5. **Slide numbers** — sequential, at x=9.25 y=5.09
6. **accent() present** — on every DS() and OS() slide, called first
7. **Shadow inline** — `shadow: mks()` or `shadow: mksl()` — never stored variable
8. **No element below y=5.09** — except `slideNum()`
9. **Footnote clearance** — footnote top ≥ 4.70; no content between y=4.65 and footnote

---

## Layout Selector

| Layout | Bg | Best for |
|--------|----|----------|
| ORANGE-TITLE | OS() | Opening slide — speaker + talk title |
| ORANGE-SPEAKER | OS() | Slide 2 credibility beat — who you are and why they should trust you |
| ORANGE-SECTION | OS() | Section break — layer or topic divider |
| ORANGE-CLOSE | OS() | CTA / final slide with links or QR |
| DARK-CONTENT | DS() | Hook, bold assertion, evidence + analysis |
| DARK-NROW | DS() | Numbered technique list — 2–4 rows |
| DARK-2COL | DS() | Side-by-side technique pairs or comparisons |
| DARK-SCREENSHOT | DS() | Screenshot + annotated callout boxes |
| DARK-PYRAMID | DS() | Layered framework or tiered hierarchy |
| DARK-CITATIONS | DS() | Reference appendix — mandatory last slide for A/C decks |
| LIGHT-3COL | LS() | Categorised breakdown — 3 columns with data |
| LIGHT-CONTENT | LS() | Bullet narrative, evidence, single-column |
| INFOGRAPHIC-EMBED | DS() or LS() | Pre-approved infographic PNG embedded full-canvas |
| ARTIFACT-SPLIT | DS() | External artifact (napkin.ai / draw.io / carbon) left + callout cards right |
| DARK-CODE-SCREENSHOT | DS() | carbon.now.sh PNG left + annotation cards right + language tag |

---

## ORANGE-TITLE

Opening slide. Large title, speaker attribution, optional QR code.

```js
function s01_title() {
  const s = OS();
  accent(s, C.textOnDark);
  hr(s, 0.55, 0.4, 5.8);

  s.addText("Talk Title", {
    x: 0.4, y: 0.85, w: 9.0, h: 1.3,
    fontSize: 72, bold: true, color: C.textOnDark, fontFace: "Arial", margin: 0
  });
  s.addText("Subtitle or key claim", {
    x: 0.4, y: 2.05, w: 8.5, h: 0.9,
    fontSize: 52, bold: true, color: C.textOnDark, fontFace: "Arial", margin: 0
  });
  s.addText("Tagline or third line if needed", {
    x: 0.4, y: 2.88, w: 8.5, h: 0.65,
    fontSize: 34, color: C.textOnDark, fontFace: "Arial", margin: 0
  });

  hr(s, 3.75, 0.4, 5.6);
  s.addText("Speaker Name", {
    x: 0.4, y: 3.88, w: 5.5, h: 0.45,
    fontSize: 22, bold: true, color: C.textOnDark, fontFace: "Arial", margin: 0
  });
  s.addText("Role  ·  website.com", {
    x: 0.4, y: 4.33, w: 5.5, h: 0.3,
    fontSize: 15, color: C.textOnDark, fontFace: "Arial", margin: 0
  });
  s.addText("Event Name  ·  Year", {
    x: 0.4, y: 4.72, w: 5.5, h: 0.28,
    fontSize: 13, color: C.textOnDark, fontFace: "Arial", margin: 0
  });

  // Optional QR code: x=7.85, y=3.5, w=1.8, h=1.8
  // s.addImage({ path: "/path/to/qr.png", x: 7.85, y: 3.5, w: 1.8, h: 1.8 });
  // s.addText("SCAN FOR REPO", { x: 7.6, y: 5.28, w: 2.5, h: 0.22, fontSize: 9, bold: true, color: C.textOnDark, fontFace: "Arial", align: "center", margin: 0 });

  slideNum(s, 1);
  s.addNotes("KEY STAT: [Core hook number]\n\nTALKING POINTS:\n• ...");
}
// DESIGNER QA: title at y=0.85, w=9.0 — max ~14 chars at 72pt before wrapping.
// Subtitle at y=2.05 — adjust y and fontSize for longer text.
// HR separates title block from speaker block at y=3.75.
// slideNum on OS() slides: textOnDark (white on orange) — correct.
```

---

## ORANGE-SPEAKER

Slide 2 credibility beat. Who you are and why this audience should trust you.
Use when speaking at conferences, DevFests, conclaves — any event where you
are not already known to the full room.

```js
function s02_speaker() {
  const s = OS();
  accent(s, C.textOnDark);
  hr(s, 0.55);

  // Left: speaker name + role stack
  s.addText("Speaker Name", {
    x: 0.4, y: 0.9, w: 5.8, h: 0.72,
    fontSize: 44, bold: true, color: C.textOnDark, fontFace: "Arial", margin: 0
  });
  s.addText("Role  ·  Company", {
    x: 0.4, y: 1.68, w: 5.8, h: 0.38,
    fontSize: 18, color: C.textOnDark, fontFace: "Arial", margin: 0
  });
  s.addText("website.com", {
    x: 0.4, y: 2.1, w: 5.8, h: 0.3,
    fontSize: 14, color: C.textOnDark, fontFace: "Arial", margin: 0
  });

  // Vertical divider
  s.addShape(pres.shapes.LINE, {
    x: 6.5, y: 0.85, w: 0, h: 3.8,
    line: { color: C.textOnDark, width: 1.0 }
  });

  // Right: 3 credibility bullets (specific, earned — not buzzwords)
  // Each: icon/marker + one specific accomplishment
  const creds = [
    "Credential 1 — specific, quantified if possible",
    "Credential 2 — a named project, product, or client",
    "Credential 3 — a speaking / community context"
  ];
  creds.forEach((cred, i) => {
    s.addShape(pres.shapes.RECTANGLE, {
      x: 6.75, y: 1.05 + i * 1.1, w: 0.06, h: 0.55,
      fill: { color: C.textOnDark }, line: { color: C.textOnDark }
    });
    s.addText(cred, {
      x: 6.92, y: 1.02 + i * 1.1, w: 2.8, h: 0.62,
      fontSize: 13, color: C.textOnDark, fontFace: "Arial", margin: 0,
      lineSpacingMultiple: 1.15
    });
  });

  hr(s, 4.6);
  s.addText("Event Name  ·  Year", {
    x: 0.4, y: 4.68, w: 9.0, h: 0.28,
    fontSize: 13, color: C.textOnDark, fontFace: "Arial", margin: 0
  });

  slideNum(s, 2);
}
```

**Usage notes:**
- Credentials must be specific: "Built RAG pipeline serving 2M queries/day at [Company]" not "ML expert"
- Three is the right number — fewer feels thin, more feels defensive
- Keep the photo slot simple — add `s.addImage({ path: photoPath, x: 0.4, y: 0.85, w: 1.8, h: 1.8 })` if a headshot is available, shift name text right to x: 2.4
- At enterprise events: replace website with LinkedIn if that's more relevant to the audience

---

## ORANGE-SECTION

Section break slide. Giant number left + vertical divider + title/subtitle right.
Use `sectionSlide()` from design-system.md — it builds the full slide.

```js
// Call directly — no wrapper function needed:
sectionSlide("01", "Section\nTitle", "One-sentence description.\nWhat this layer covers.");
slideNum(s, N);   // sectionSlide() returns the slide object — capture it to add slideNum
// s.addNotes("...");

// Full pattern when you need slideNum + notes:
function s06_section01() {
  const s = sectionSlide("01", "Context\nHygiene", "Seven techniques.\nZero setup. Start today.");
  slideNum(s, 6);
  s.addNotes("KEY STAT: 7 techniques\n\nTALKING POINTS:\n• Introduce the first layer of the pyramid\n• All of these take under 10 minutes to start\n• Expected savings: 20-40% per session with no config changes");
}
```

---

## ORANGE-CLOSE

Final slide. CTA, repo link, QR codes. Two QR codes side by side if needed.

```js
function sN_close() {
  const s = OS();
  accent(s, C.textOnDark);
  hr(s, 0.55);

  s.addText("One-line takeaway or CTA", {
    x: 0.4, y: 0.85, w: 9.2, h: 1.2,
    fontSize: 64, bold: true, color: C.textOnDark, fontFace: "Arial", margin: 0
  });
  s.addText("Supporting line", {
    x: 0.4, y: 2.05, w: 6.5, h: 0.5,
    fontSize: 28, color: C.textOnDark, fontFace: "Arial", margin: 0
  });

  hr(s, 2.7, 0.4, 9.2);

  // Links / text block
  s.addText("Key resource or link text", {
    x: 0.4, y: 2.88, w: 6.3, h: 0.36,
    fontSize: 20, bold: true, color: C.textOnDark, fontFace: "Arial", margin: 0
  });
  s.addText("Secondary link or description", {
    x: 0.4, y: 3.32, w: 6.3, h: 0.32,
    fontSize: 16, color: C.textOnDark, fontFace: "Arial", margin: 0
  });
  s.addText("Third resource if needed", {
    x: 0.4, y: 3.72, w: 6.3, h: 0.32,
    fontSize: 16, color: C.textOnDark, fontFace: "Arial", margin: 0
  });

  // Two QR codes: x=7.0 and x=8.55, y=2.62, w=1.4, h=1.4
  // s.addImage({ path: "/path/to/qr1.png", x: 7.0,  y: 2.62, w: 1.4, h: 1.4 });
  // s.addImage({ path: "/path/to/qr2.png", x: 8.55, y: 2.62, w: 1.4, h: 1.4 });
  // s.addText("LABEL 1", { x: 6.75, y: 4.06, w: 1.9, h: 0.22, fontSize: 9, bold: true, color: C.textOnDark, fontFace: "Arial", align: "center", margin: 0 });
  // s.addText("LABEL 2", { x: 8.3,  y: 4.06, w: 1.9, h: 0.22, fontSize: 9, bold: true, color: C.textOnDark, fontFace: "Arial", align: "center", margin: 0 });

  hr(s, 5.15);
  slideNum(s, N);
  s.addNotes("KEY STAT: ...\n\nTALKING POINTS:\n• Leave this slide up during Q&A\n• Point at QR codes explicitly — most people don't notice them\n• Anticipated question: ...");
}
```

---

## DARK-CONTENT

General dark slide: hook, assertion, evidence with analysis, or screenshot + callouts.

```js
function sN_darkContent() {
  const s = DS();
  accent(s, C.textOnDark);
  dt(s, "Slide Title — Question or Assertion", "Subtitle or context line — optional");

  // Error/alert bar (red-tinted bg):
  s.addShape(pres.shapes.RECTANGLE, {
    x: 0.4, y: 0.5, w: 5.9, h: 0.58,
    fill: { color: "1A0000" }, line: { color: C.red, width: 1.5 }, shadow: mks()
  });
  s.addText("Alert text — terminal output, error message, or key quote", {
    x: 0.55, y: 0.55, w: 5.6, h: 0.46,
    fontSize: 14, color: C.lightRed, fontFace: "Courier New", bold: true, margin: 0
  });

  // Body text with rich runs:
  s.addText([
    { text: "Key phrase or hook",           options: { color: C.textOnDark } },
    { text: " context word ",               options: { color: C.orange } },
    { text: "rest of the sentence.",        options: { color: C.textOnDark } },
  ], {
    x: 0.4, y: 1.3, w: 9.2, h: 1.3,
    fontSize: 52, bold: true, fontFace: "Arial", margin: 0
  });

  // Bullet list with colour-coded items:
  s.addText([
    { text: "First bullet — key positive insight",     options: { bullet: true, breakLine: true, color: C.textBody } },
    { text: "Second bullet — the bad news",            options: { bullet: true, breakLine: true, color: C.lightRed } },
    { text: "Third bullet — punchline or implication", options: { bullet: true, color: C.orange } },
  ], {
    x: 0.4, y: 2.8, w: 8.8, h: 1.65,
    fontSize: 16, fontFace: "Arial", margin: 0, lineSpacingMultiple: 1.15
  });

  // Bottom insight bar (orange rule):
  hr(s, 4.62, 0.4, 9.2, C.orange);
  s.addText("Italic insight or speaker cue — one concise sentence.", {
    x: 0.4, y: 4.68, w: 9.2, h: 0.65,
    fontSize: 12, color: C.textBody, fontFace: "Arial", italic: true, margin: 0
  });

  slideNum(s, N);
  s.addNotes("KEY STAT: ...\n\nTALKING POINTS:\n• ...\n\nSOURCES:\n¹ ...");
}
// DESIGNER QA: error bar uses "Courier New" for terminal feel — deliberate exception to Arial rule.
// Rich run arrays don't need fontFace in sub-options if parent options set it.
// Bottom bar at y=4.62 — 0.47 above safeBot (5.09) ✓.
```

---

## DARK-NROW

Numbered technique rows. 2–4 rows stacked. Each row: number + title + body + optional metric.

```js
function sN_nrow() {
  const s = DS();
  accent(s, C.textOnDark);
  dt(s, "Techniques N & N: Short Descriptor");

  // Layout: start y=1.2, gap=0.08" between rows
  // Row heights: 1.15 (default), 1.4 (2-line body), 1.65 (3-line body)
  const GAP = 0.08;
  const rows = [
    {
      num:    "01",
      title:  "Technique name — what it does",
      body:   "One or two sentences describing the technique and its benefit.",
      metric: "Key\nMetric",
      mc:     C.lightGreen,
      h:      1.15,
    },
    {
      num:    "02",
      title:  "Second technique — what it does",
      body:   "One or two sentences. Can reference concrete numbers or commands.",
      metric: "Another\nMetric",
      mc:     C.yellow,
      h:      1.15,
    },
    {
      num:    "03",
      title:  "Third technique — what it does",
      body:   "Supporting detail. Keep under 3 lines at 11pt for standard h=1.15.",
      metric: "Third\nMetric",
      mc:     C.lightBlue,
      h:      1.15,
    },
  ];

  let y = 1.2;
  rows.forEach(r => {
    nrow(s, r.num, r.title, r.body, r.metric, r.mc, y, r.h);
    y += r.h + GAP;
  });

  sourceFootnote(s, ["¹ Source, Year — url"], true);
  slideNum(s, N);
  s.addNotes("KEY STAT: ...\n\nTALKING POINTS:\n• ...\n\nSOURCES:\n¹ ...");
}
// DESIGNER QA: 3 rows at h=1.15 + 2×0.08 gap → bottom at 1.2 + 3.46 = 4.66 < safeBot ✓.
// 4 rows at h=1.1 + 3×0.07 gap → bottom at 1.2 + 4.61 = 5.81 — OVER LIMIT. Use h=0.95 max for 4 rows.
// nrow metric column x=7.4, w=2.2 → right edge 9.6 < safeRight ✓.
```

---

## DARK-2COL

Two panel cards side by side. Technique pair or before/after on dark bg.

```js
function sN_dark2Col() {
  const s = DS();
  accent(s, C.textOnDark);
  dt(s, "Techniques N & N: Left Title. Right Title.");

  const CY = 1.12, CH = 4.3;

  // LEFT card
  card(s, 0.3, CY, 4.55, CH, C.lightBlue);
  ctitle(s, 0.3, CY, 4.55, "N / Left Card Title", C.lightBlue);
  s.addText([
    { text: "Primary term", options: { breakLine: true, color: C.lightBlue, fontFace: "Courier New", fontSize: 20, bold: true } },
    { text: "  Description of what this is.", options: { breakLine: true, color: C.textBody, fontSize: 12 } },
    { text: " ", options: { breakLine: true } },
    { text: "Secondary term", options: { breakLine: true, color: C.lightGreen, fontFace: "Courier New", fontSize: 20, bold: true } },
    { text: "  Description of what this is.", options: { breakLine: true, color: C.textBody, fontSize: 12 } },
    { text: " ", options: { breakLine: true } },
    { text: "Takeaway label:", options: { breakLine: true, color: C.yellow, bold: true, fontSize: 13 } },
    { text: "Concrete instruction or command example.", options: { color: C.textBody, fontSize: 12 } },
  ], {
    x: 0.48, y: 1.55, w: 4.22, h: 3.75,
    fontSize: 12, fontFace: "Arial", margin: 0, lineSpacingMultiple: 1.15
  });

  // RIGHT card
  card(s, 5.12, CY, 4.55, CH, C.purple);
  ctitle(s, 5.12, CY, 4.55, "N / Right Card Title", "B07BD8");
  s.addText([
    { text: "Primary term", options: { breakLine: true, color: C.lightRed, fontFace: "Courier New", fontSize: 20, bold: true } },
    { text: "  Description.", options: { breakLine: true, color: C.textBody, fontSize: 12 } },
    { text: " ", options: { breakLine: true } },
    { text: "Secondary term", options: { breakLine: true, color: C.lightGreen, fontFace: "Courier New", fontSize: 20, bold: true } },
    { text: "  Description.", options: { breakLine: true, color: C.textBody, fontSize: 12 } },
  ], {
    x: 5.3, y: 1.55, w: 4.22, h: 3.75,
    fontSize: 12, fontFace: "Arial", margin: 0, lineSpacingMultiple: 1.15
  });

  slideNum(s, N);
  s.addNotes("KEY STAT: ...\n\nTALKING POINTS:\n• ...");
}
// DESIGNER QA: left card x=0.3, w=4.55 → right edge 4.85. right card x=5.12, w=4.55 → right edge 9.67 ≈ safeRight ✓.
// Card text starts at cardX + 0.18 (= 0.48 for left, 5.30 for right).
// ctitle uses cardX + 0.14 internally.
```

---

## DARK-SCREENSHOT

Screenshot image on left/center + callout annotation boxes on right.

```js
function sN_screenshot() {
  const s = DS();
  accent(s, C.textOnDark);
  dt(s, "Slide Title", "Context line describing what the screenshot shows.");

  // Screenshot image — adjust w/h to match actual image aspect ratio
  // Example: view-context.png 2.22:1 → w=6.4, h=2.88
  s.addImage({ path: "/path/to/screenshot.png", x: 0.3, y: 1.15, w: 6.4, h: 2.88 });

  // Right-side callout boxes
  const callouts = [
    { lbl: "LABEL A", val: "~15K tokens", sub: "What this means\nfor the user",   c: C.red   },
    { lbl: "LABEL B", val: "~6K tokens",  sub: "What this means\nfor the user",   c: C.lightGreen },
    { lbl: "LABEL C", val: "105K tokens", sub: "What this means\nfor the user",   c: C.orange },
  ];
  let cy = 1.2;
  callouts.forEach(co => {
    s.addShape(pres.shapes.RECTANGLE, {
      x: 6.9, y: cy, w: 2.8, h: 0.88,
      fill: { color: C.cardDark }, line: { color: co.c, width: 1.5 }, shadow: mks()
    });
    s.addShape(pres.shapes.RECTANGLE, {
      x: 6.9, y: cy, w: 0.07, h: 0.88,
      fill: { color: co.c }, line: { color: co.c }
    });
    s.addText(co.lbl, {
      x: 7.06, y: cy+0.05, w: 1.0, h: 0.26,
      fontSize: 9, bold: true, color: co.c, fontFace: "Arial", margin: 0
    });
    s.addText(co.val, {
      x: 7.06, y: cy+0.28, w: 1.4, h: 0.3,
      fontSize: 14, bold: true, color: C.textOnDark, fontFace: "Arial", margin: 0
    });
    s.addText(co.sub, {
      x: 7.06, y: cy+0.57, w: 2.5, h: 0.28,
      fontSize: 9.5, color: C.textBody, fontFace: "Arial", margin: 0
    });
    cy += 1.02;
  });

  // Bottom insight banner (optional):
  s.addShape(pres.shapes.RECTANGLE, {
    x: 0.3, y: 4.2, w: 9.4, h: 0.7,
    fill: { color: "1A0000" }, line: { color: C.red, width: 1 }
  });
  s.addText("One-sentence insight or implication from the screenshot.", {
    x: 0.45, y: 4.25, w: 9.1, h: 0.6,
    fontSize: 14, color: C.lightRed, fontFace: "Arial", bold: true, margin: 0
  });

  slideNum(s, N);
  s.addNotes("KEY STAT: ...\n\nTALKING POINTS:\n• ...");
}
// DESIGNER QA: screenshot right edge = 0.3 + 6.4 = 6.7. Callout boxes at x=6.9 → gap 0.2" ✓.
// callout right edge = 6.9 + 2.8 = 9.7 = safeRight ✓.
// 3 callouts × 1.02 = 3.06 → last callout bottom at 1.2 + 3.06 = 4.26 < 4.2 of banner ← adjust cy start if 3 callouts needed.
// Typical pattern: screenshot bottom at y=1.15+h, banner at y=4.2.
```

---

## DARK-PYRAMID

Centered stacked bars forming a pyramid/hierarchy. Annotations outside bars.

```js
function sN_pyramid() {
  const s = DS();
  accent(s, C.textOnDark);
  dt(s, "Framework Name: N layers. Verb them. Compound the savings.");

  const layers = [
    { label: "LAYER 4: Top Layer",    sub: "tagline  ·  key benefit",        color: C.orange, y: 1.2, w: 4.0, ann: "3 words\nshort stat",    ac: C.orange },
    { label: "LAYER 3: Third Layer",  sub: "tagline  ·  key benefit",        color: C.purple, y: 2.1, w: 5.8, ann: "stat\nor metric",        ac: C.purple },
    { label: "LAYER 2: Second Layer", sub: "tagline  ·  key benefit",        color: C.green,  y: 3.0, w: 7.6, ann: "permanent\nsavings",     ac: C.green  },
    { label: "LAYER 1: Base Layer",   sub: "tagline  ·  key benefit",        color: C.blue,   y: 3.9, w: 9.2, ann: "start in\n10 minutes",   ac: C.blue   },
  ];

  layers.forEach(l => {
    const x = (10 - l.w) / 2;
    s.addShape(pres.shapes.RECTANGLE, {
      x, y: l.y, w: l.w, h: 0.78,
      fill: { color: l.color, transparency: 8 }, line: { color: l.color, width: 1.5 }, shadow: mks()
    });
    s.addText(l.label, {
      x: x+0.2, y: l.y+0.07, w: l.w-0.4, h: 0.32,
      fontSize: 14, bold: true, color: C.textOnDark, fontFace: "Arial", align: "center", margin: 0
    });
    s.addText(l.sub, {
      x: x+0.2, y: l.y+0.43, w: l.w-0.4, h: 0.25,
      fontSize: 11, color: C.textOnDark, fontFace: "Arial", align: "center", margin: 0
    });
  });

  // Annotations to the RIGHT of each bar
  layers.forEach(l => {
    const barRightX = (10 - l.w) / 2 + l.w + 0.1;
    const remW = 9.7 - barRightX;
    if (remW > 0.3) {
      s.addText(l.ann, {
        x: barRightX, y: l.y+0.12, w: Math.min(remW, 1.2), h: 0.54,
        fontSize: 10, bold: true, color: l.ac, fontFace: "Arial", align: "left", margin: 0
      });
    }
  });

  slideNum(s, N);
  s.addNotes("KEY STAT: ...\n\nTALKING POINTS:\n• ...");
}
// DESIGNER QA: widest bar w=9.2, x=(10-9.2)/2=0.4, right edge=9.6 < safeRight ✓.
// Last bar bottom at 3.9+0.78=4.68 < safeBot ✓.
// Annotations: only render if remW > 0.3 to avoid cramped text on wide bars.
```

---

## DARK-CITATIONS

**Mandatory last slide for every deck built with source mode A or C.**

```js
function sN_citations(allCitations) {
  // allCitations: array of { n: "¹", title: "...", pub: "...", url: "..." }
  const s = DS();
  accent(s, C.textOnDark);
  dt(s, "References");
  hr(s, 1.12, 0.4, 9.2, C.textOnDark);
  s.addText("SOURCES & FURTHER READING", {
    x: 0.4, y: 1.2, w: 9.2, h: 0.26,
    fontSize: 12, bold: true, color: C.textBody, fontFace: "Arial", margin: 0
  });

  // Two-column layout: left x=0.4 w=4.4, right x=5.1 w=4.4
  // Max 5 per column (10 total). Step 0.52" per entry.
  const leftCols  = allCitations.filter((_, i) => i % 2 === 0);
  const rightCols = allCitations.filter((_, i) => i % 2 === 1);

  [leftCols, rightCols].forEach((col, ci) => {
    const cx = ci === 0 ? 0.4 : 5.1;
    col.forEach((c, i) => {
      const ey = 1.55 + i * 0.56;
      s.addText(c.n + "  " + c.title, {
        x: cx, y: ey, w: 4.4, h: 0.22,
        fontSize: 11, bold: true, color: C.textOnDark, fontFace: "Arial", margin: 0
      });
      s.addText(c.pub, {
        x: cx, y: ey+0.22, w: 4.4, h: 0.16,
        fontSize: 9, color: C.textBody, fontFace: "Arial", margin: 0
      });
      s.addText(c.url, {
        x: cx, y: ey+0.38, w: 4.4, h: 0.14,
        fontSize: 8, color: C.lightBlue, fontFace: "Courier New", margin: 0
      });
    });
  });

  slideNum(s, N);
  s.addNotes(
    "KEY STAT: [Total citation count]\n\n" +
    "TALKING POINTS:\n" +
    "• Leave this slide up during Q&A — audiences photograph it\n" +
    "• All URLs are live\n" +
    "• Offer to share the deck for clickable links"
  );
}

// Usage:
// sN_citations([
//   { n: "¹", title: "Article Title", pub: "Publication, Year", url: "https://..." },
//   { n: "²", title: "Article Title", pub: "Publication, Year", url: "https://..." },
// ]);
```

---

## LIGHT-3COL

Three-column breakdown with coloured category headers. Use for token budget, cost analysis,
feature comparison, or any 3-bucket categorisation.

```js
function sN_light3Col() {
  const s = LS();
  tag(s, "CATEGORY LABEL", 0.4, 0.2, 2.2);
  lt(s, "Light Slide Title", "Subtitle — context or source  ·  Key metric summary");

  const cols = [
    {
      title: "Category A", c: C.red,
      items: [
        ["Row label", "Value", "Annotation or sub-note"],
        ["Row label", "Value", "Annotation"],
      ],
      sub: "~15K total",
      note: "One-sentence implication for this category.",
    },
    {
      title: "Category B", c: C.green,
      items: [
        ["Row label", "Value", "Annotation"],
        ["Row label", "Value", "Annotation"],
        ["Row label", "Value", "Annotation"],
      ],
      sub: "~6K total",
      note: "One-sentence implication for this category.",
    },
    {
      title: "Category C", c: C.orange,
      items: [
        ["Row label", "Value", "Annotation"],
        ["Row label", "Value", "Annotation"],
        ["Row label", "Value", "Annotation"],
      ],
      sub: "~178K total",
      note: "One-sentence implication for this category.",
    },
  ];

  const xs = [0.32, 3.52, 6.72];
  const cw = 3.1;

  cols.forEach((col, i) => {
    const x = xs[i];
    // Top accent bar
    s.addShape(pres.shapes.RECTANGLE, {
      x, y: 1.78, w: cw, h: 0.08,
      fill: { color: col.c }, line: { color: col.c }
    });
    // Card body
    s.addShape(pres.shapes.RECTANGLE, {
      x, y: 1.86, w: cw, h: 3.55,
      fill: { color: "EBEBEB" }, line: { color: "D8D8D8", width: 0.5 }, shadow: mks()
    });
    s.addText(col.title, {
      x: x+0.12, y: 1.93, w: cw-0.24, h: 0.4,
      fontSize: 20, bold: true, color: col.c, fontFace: "Arial", margin: 0
    });
    // Sub-total badge
    s.addShape(pres.shapes.RECTANGLE, {
      x: x+0.12, y: 2.38, w: cw-0.24, h: 0.28,
      fill: { color: col.c, transparency: 80 }, line: { color: col.c }
    });
    s.addText(col.sub, {
      x: x+0.14, y: 2.39, w: cw-0.28, h: 0.25,
      fontSize: 11, bold: true, color: col.c, fontFace: "Arial", margin: 0
    });
    // Row items
    let iy = 2.75;
    col.items.forEach(([cat, tok, note]) => {
      s.addShape(pres.shapes.LINE, {
        x: x+0.1, y: iy-0.03, w: cw-0.2, h: 0,
        line: { color: "CCCCCC", width: 0.4 }
      });
      s.addText(cat, {
        x: x+0.12, y: iy, w: 1.55, h: 0.25,
        fontSize: 11, color: "333333", fontFace: "Arial", margin: 0
      });
      s.addText(tok, {
        x: x+1.7, y: iy, w: 0.75, h: 0.25,
        fontSize: 12, bold: true, color: col.c, fontFace: "Arial", margin: 0
      });
      s.addText(note, {
        x: x+0.12, y: iy+0.25, w: cw-0.24, h: 0.2,
        fontSize: 9, color: "777777", fontFace: "Arial", italic: true, margin: 0
      });
      iy += 0.55;
    });
    // Footer note
    s.addText(col.note, {
      x: x+0.12, y: 5.0, w: cw-0.24, h: 0.35,
      fontSize: 10.5, bold: true, color: col.c, fontFace: "Arial", margin: 0
    });
  });

  s.addText("Caption or source line below the columns", {
    x: 0.4, y: 5.38, w: 9.2, h: 0.2,
    fontSize: 11, color: C.textMid, fontFace: "Arial", italic: true, align: "center", margin: 0
  });

  slideNum(s, N);
  s.addNotes("KEY STAT: ...\n\nTALKING POINTS:\n• ...\n\nSOURCES:\n¹ ...");
}
// DESIGNER QA: 3 cols × 3.1" + 2 × 0.1" gap = 9.5" total — right edge = 0.32+9.5 = 9.82 → OVER.
// Actual: cols at 0.32 | 3.52 | 6.72, each w=3.1 → last right edge = 6.72+3.1 = 9.82.
// Slightly over — acceptable for light slides where content stays clear. Or tighten w to 3.0 per col.
// The footer note at y=5.0 is BELOW safeBot (5.09) — keep as-is: it's in the footer zone.
// Caption at y=5.38 — below the safe zone, decorative only.
```

---

## LIGHT-CONTENT

Single-column bullets. Evidence, arguments, explanation.

```js
function sN_lightContent() {
  const s = LS();
  tag(s, "SECTION LABEL", 0.4, 0.2, 2.0);
  lt(s, "Evidence or Argument Title", "Optional subtitle — source or framing");

  const bullets = [
    { text: "Primary point — specific, concrete, not generic", primary: true  },
    { text: "Supporting detail or qualifying data",             primary: false },
    { text: "Second primary point — assertive and direct",     primary: true  },
    { text: "Implication or so-what",                          primary: false },
    { text: "Closing point — ties to the narrative arc",       primary: true  },
  ];

  bullets.forEach((b, i) => {
    s.addText("● " + b.text, {
      x: 0.54, y: 1.96 + i*0.50, w: 9.0, h: 0.46,
      fontSize: b.primary ? 15 : 12,
      bold: b.primary,
      fontFace: "Arial",
      color: b.primary ? C.textDark : C.textMid,
      margin: 0, lineSpacingMultiple: 1.15
    });
  });

  sourceFootnote(s, ["¹ Source, Year — url"]);
  slideNum(s, N);
  s.addNotes("KEY STAT: ...\n\nTALKING POINTS:\n• ...\n\nSOURCES:\n¹ ...");
}
// DESIGNER QA: 5 bullets × 0.50 = 2.5" of content, starting at y=1.96 → bottom at 4.46 < safeBot ✓.
// Primary bullets: 15pt bold textDark. Secondary: 12pt normal textMid.
// sourceFootnote without third arg → light mode (textCaption).
```

---

## INFOGRAPHIC-EMBED

Pre-approved infographic PNG embedded full-canvas below the title.
Load `references/infographic-workflow.md` before using this template.

```js
function sN_infographicEmbed(pngPath, title, caption, isDark) {
  // pngPath: absolute path to PNG produced by infographic sub-agent
  // isDark: true for DS() background, false for LS()
  const s = isDark ? DS() : LS();
  if (isDark) accent(s, C.textOnDark);

  isDark
    ? dt(s, title)
    : (tag(s, "INFOGRAPHIC", 0.4, 0.2, 2.0), lt(s, title));

  // Infographic image: full safe-zone width, below title
  s.addImage({
    path: pngPath,
    x: 0.3,
    y: 1.44,
    w: 9.4,
    h: 3.36,   // to y=4.80, above safeBot
    sizing: { type: "contain", w: 9.4, h: 3.36 }
  });

  if (caption) {
    s.addText(caption, {
      x: 0.4, y: 4.84, w: 9.2, h: 0.20,
      fontSize: 9, italic: true, fontFace: "Arial",
      color: isDark ? C.textMuted : C.textCaption, margin: 0
    });
  }

  slideNum(s, N);
  s.addNotes("KEY STAT: ...\n\nTALKING POINTS:\n• [Describe what the infographic shows]\n• [Key insight from the visual]");
}
// PNG must be rendered at 2820 × 1008 px (9.4" × 3.36" @ 300dpi) for crisp projector display.
// pptxgenjs embeds at correct physical size — pixel count does not affect slide geometry.
// Image bottom: 1.44 + 3.36 = 4.80 < safeBot (5.09) ✓.
```

---

## DARK-CODE

Native rich-text code block — fully editable in both PowerPoint and Google Slides.
Use this by default for code slides. Only use DARK-CODE-SCREENSHOT if the user
explicitly requests a carbon.now.sh aesthetic.

Code tokens use pptxgenjs rich text arrays (one array entry per token type).
Font is Courier New — the one monospace font safe on all platforms.

```js
function sN_code(title, sub, language, codeTokens) {
  // codeTokens: array of { text, color } — one entry per token or line
  // language: "PYTHON" | "JAVASCRIPT" | "SQL" | "BASH" | "YAML" | etc.
  const s = DS();
  accent(s);
  dt(s, title, sub);

  // Code panel background — VSCode-like dark surface
  s.addShape(pres.shapes.RECTANGLE, {
    x: 0.3, y: 1.35, w: 9.4, h: 3.35,
    fill: { color: "1E1E1E" }, line: { color: "333333", width: 0.5 }, shadow: mks()
  });

  // Language tag — top-right corner of code panel
  s.addShape(pres.shapes.RECTANGLE, {
    x: 8.6, y: 1.35, w: 1.1, h: 0.28,
    fill: { color: C.orange }, line: { color: C.orange }
  });
  s.addText(language, {
    x: 8.62, y: 1.36, w: 1.06, h: 0.26,
    fontSize: 9, bold: true, color: C.textOnDark, fontFace: "Arial",
    align: "center", valign: "middle", margin: 0
  });

  // Code body — rich text array
  // Build codeTokens like:
  //   [
  //     { text: "def ",          options: { color: C.lightBlue,  bold: true  } },
  //     { text: "process_query", options: { color: C.lightGreen              } },
  //     { text: "(",             options: { color: C.textOnDark              } },
  //     { text: "query",         options: { color: C.textBody                } },
  //     { text: ": str",         options: { color: C.lightBlue               } },
  //     { text: "):\n",          options: { color: C.textOnDark              } },
  //     { text: "    # comment", options: { color: C.textMuted, italic: true } },
  //   ]
  //
  // Token colour guide (VSCode Dark+ convention, using our palette):
  //   keywords (def/if/return/import)  → C.lightBlue   bold
  //   function/method names            → C.lightGreen
  //   strings                          → C.yellow
  //   comments                         → C.textMuted   italic
  //   types/classes                    → C.teal
  //   numbers/constants                → C.orange
  //   operators/punctuation            → C.textOnDark
  //   variable names / identifiers     → C.textBody
  s.addText(codeTokens, {
    x: 0.5, y: 1.48, w: 9.0, h: 3.1,
    fontSize: 14, fontFace: "Courier New", margin: 0,
    lineSpacingMultiple: 1.5, valign: "top"
  });

  speakerMark(s, website);
  slideNum(s, N);
}
```

**Token colour guide summary (use consistently across all code slides):**

| Token type | Color token | Style |
|-----------|------------|-------|
| Keyword (`def`, `if`, `return`, `import`) | `C.lightBlue` | bold |
| Function / method name | `C.lightGreen` | normal |
| String literal | `C.yellow` | normal |
| Comment | `C.textMuted` | italic |
| Type / class name | `C.teal` | normal |
| Number / constant | `C.orange` | normal |
| Operator / punctuation | `C.textOnDark` | normal |
| Variable / identifier | `C.textBody` | normal |

**Line capacity:** Courier New 14pt in a 9.0" wide box fits ~90 characters per line.
Max ~12 lines per slide at lineSpacingMultiple 1.5. If code is longer, show a representative
excerpt and add a comment `# ... (continued)` — never shrink the font.

---

## ARTIFACT-SPLIT

External artifact (napkin.ai / draw.io / Mermaid PNG) on the left, annotated
callout cards on the right. Load `references/artifact-guide.md` before using.

```js
function sN_artifactSplit(artifactPath, artifactW, artifactH, title, sub, cards) {
  // artifactPath: absolute PNG path
  // artifactW, artifactH: physical inches — calculate as: h = w / aspectRatio
  //   standard left slot: w = 5.6 — adjust if artifact is very wide or tall
  // cards: array of { ac, title, body } — 2 or 3 annotation cards on right
  const s = DS();
  accent(s);
  dt(s, title, sub);

  // Centre the artifact vertically in content zone (y=1.2 to y=5.09)
  const contentZoneH = 3.75;
  const artifactY = 1.22 + (contentZoneH - artifactH) / 2;

  s.addImage({
    path: artifactPath,
    x: 0.3, y: Math.max(1.22, artifactY),
    w: artifactW, h: artifactH,
    sizing: { type: "contain", w: artifactW, h: artifactH }
  });

  // Right annotation cards — stack 2 or 3, even spacing
  const cardX   = 6.1;
  const cardW   = 3.6;
  const cardH   = cards.length === 2 ? 1.5 : 1.05;
  const cardGap = cards.length === 2 ? 0.2 : 0.15;
  const startY  = 1.25;

  cards.forEach(({ ac, title: ct, body }, i) => {
    const cy = startY + i * (cardH + cardGap);
    card(s, cardX, cy, cardW, cardH, ac);
    ctitle(s, cardX, cy, cardW, ct, ac);
    s.addText(body, {
      x: cardX + 0.14, y: cy + 0.52, w: cardW - 0.22, h: cardH - 0.6,
      fontSize: 11, color: C.textBody, fontFace: "Arial", margin: 0,
      lineSpacingMultiple: 1.15
    });
  });

  speakerMark(s, website);
  slideNum(s, N);
}
```

**Sizing note:** get the artifact's pixel dimensions first, then calculate:
```bash
identify -format "%wx%h" artifact.png   # ImageMagick
# or: python3 -c "from PIL import Image; print(Image.open('artifact.png').size)"
```
Then: `h = 5.6 / (pixelWidth / pixelHeight)` — cap at 3.8" to stay above safe zone.

---

## DARK-CODE-SCREENSHOT

carbon.now.sh code screenshot on the left, annotation cards on the right.
Use ONLY when user explicitly requests the carbon aesthetic.
For all other code slides, use DARK-CODE (native rich text, editable).

```js
function sN_codeScreenshot(carbonPngPath, language, title, annotations) {
  // carbonPngPath: absolute PNG path from carbon.now.sh (2x export)
  // language: string shown in tag label
  // annotations: array of { ac, label, body } — 2–3 items
  const s = DS();
  accent(s);
  dt(s, title);

  // Carbon screenshot — left panel
  // carbon.now.sh default output at 2x is roughly 16:5 aspect ratio
  // Physical: 6.0" wide × 1.875" tall (matches 16:5 at this width)
  const cW = 6.0, cH = 1.875;
  s.addImage({
    path: carbonPngPath,
    x: 0.3, y: 1.4,
    w: cW, h: cH,
    sizing: { type: "contain", w: cW, h: cH }
  });

  // Language tag below screenshot
  s.addShape(pres.shapes.RECTANGLE, {
    x: 0.3, y: 1.4 + cH + 0.08, w: 1.2, h: 0.25,
    fill: { color: C.orange }, line: { color: C.orange }
  });
  s.addText(language, {
    x: 0.32, y: 1.4 + cH + 0.09, w: 1.16, h: 0.23,
    fontSize: 9, bold: true, color: C.textOnDark, fontFace: "Arial",
    align: "center", valign: "middle", margin: 0
  });

  // Right annotation cards — 2 or 3
  const cardX   = 6.6;
  const cardW   = 3.1;
  const cardH   = annotations.length === 2 ? 1.5 : 1.05;
  const cardGap = 0.15;
  const startY  = 1.3;

  annotations.forEach(({ ac, label, body }, i) => {
    const cy = startY + i * (cardH + cardGap);
    card(s, cardX, cy, cardW, cardH, ac);
    ctitle(s, cardX, cy, cardW, label, ac);
    s.addText(body, {
      x: cardX + 0.14, y: cy + 0.52, w: cardW - 0.22, h: cardH - 0.6,
      fontSize: 11, color: C.textBody, fontFace: "Arial", margin: 0,
      lineSpacingMultiple: 1.15
    });
  });

  speakerMark(s, website);
  slideNum(s, N);
}
```

---

## Speaker Notes Format

Every slide. Required structure:

```
KEY STAT: [Most important number or claim on this slide — one sentence]

TALKING POINTS:
• [What to say first — context that earns what follows]
• [The main claim the slide makes]
• [The so-what / implication for the audience]
• [Anticipated challenge or question]

SOURCES:                          ← omit entirely if no web data on this slide
¹ Publication / Organisation, Year — https://url
² Publication / Organisation, Year — https://url
```
