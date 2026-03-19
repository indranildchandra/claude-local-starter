# Reference Artifacts Guide
### Read during the ARTIFACTS checkpoint — not at invocation.
### Covers export settings, naming conventions, and embed rules for each supported tool.

---

## Supported Artifact Types

| Tool | Artifact type | Embed as | Layout |
|------|--------------|----------|--------|
| napkin.ai | Infographic PNG | `addImage()` | INFOGRAPHIC-EMBED or ARTIFACT-SPLIT |
| draw.io | Architecture / system diagram PNG | `addImage()` | INFOGRAPHIC-EMBED or ARTIFACT-SPLIT |
| Mermaid JS | Sequence / flow diagram (.mmd or PNG) | compile + `addImage()` | INFOGRAPHIC-EMBED |
| carbon.now.sh | Code snippet PNG | `addImage()` | DARK-CODE-SCREENSHOT |
| NotebookLM | Outline / notes (text) | content source only | any |
| Datawrapper / Flourish | Chart PNG | `addImage()` | INFOGRAPHIC-EMBED |
| Excalidraw | Sketch / whiteboard PNG | `addImage()` | INFOGRAPHIC-EMBED or ARTIFACT-SPLIT |

---

## ARTIFACTS Checkpoint — How to Run It

During the workflow, after ALIGN, before STRUCTURE:

```
ARTIFACTS CHECK
──────────────────────────────────────────────────────────────────
Do you have reference artifacts to bring in for this deck?

Examples:
  • napkin.ai infographic PNGs
  • draw.io architecture diagram exports
  • carbon.now.sh code screenshot PNGs
  • Mermaid .mmd source files
  • NotebookLM notes or outline

If yes: for each artifact, tell me:
  1. The file path (absolute, e.g. ~/Downloads/arch-diagram.png)
  2. Which slide/topic it belongs to
  3. Whether it needs a caption or annotation callouts

If no: I'll generate all visuals natively.
──────────────────────────────────────────────────────────────────
```

**Cataloguing the response:**
Build an artifact registry for the session:

```
ARTIFACT REGISTRY
──────────────────────────────────────────────────────────────────
A1  ~/Downloads/rag-architecture.png     → Slide 04 (Architecture)    draw.io PNG
A2  ~/Downloads/latency-chart.png        → Slide 07 (Latency)         napkin.ai
A3  ~/Downloads/code-retriever.png       → Slide 09 (Code)            carbon.now.sh
A4  ~/Downloads/pipeline-flow.mmd        → Slide 11 (Pipeline)        Mermaid source
──────────────────────────────────────────────────────────────────
```

Reference these as `[A1]`, `[A2]` etc. in the STRUCTURE slide plan.
At GENERATE: substitute each `[AN]` with the resolved absolute path.

---

## Per-Tool Export Settings

### napkin.ai

napkin.ai generates high-quality SVG/PNG infographics from text prompts.

**Export steps:**
1. Generate your infographic in napkin.ai
2. Click the download icon → **PNG** → **High resolution (2x)**
3. Rename: `napkin-s[NN]-[topic].png`

**Notes:**
- napkin.ai exports on white/transparent bg — embed on `LS()` or use `INFOGRAPHIC-EMBED` with `isDark: false`
- If you need it on a dark slide: add a `#282828` rectangle behind it at the same x/y/w/h
- Typical size: 9.4" × 3.36" fills the full INFOGRAPHIC-EMBED slot. If it's portrait, use ARTIFACT-SPLIT

---

### draw.io (diagrams.net)

For architecture, system, and flow diagrams.

**Export steps:**
1. File → Export as → PNG
2. Settings: **Scale: 200%**, **Transparent background: ✓**, **Fit page: ✓**
3. Rename: `drawio-s[NN]-[topic].png`

**Notes:**
- Scale 200% = effectively 2x for a 96dpi screen → ~192dpi physical — sufficient for projection
- For dark slides: File → Edit → Format → Background color → `#282828` before export, OR embed transparently and add a dark rectangle behind it
- draw.io diagrams often need `ARTIFACT-SPLIT` (diagram left, key points right) rather than full-canvas embed

---

### carbon.now.sh

For code snippet screenshots with syntax highlighting.

**Export settings (use these exactly):**
- Background: `rgba(39, 40, 34, 1)` (dark monokai) OR `rgba(40, 40, 40, 1)` (matches deck dark bg)
- Theme: `monokai` or `one-dark`
- Window controls: off (`wc=false`)
- Drop shadow: off (`ds=false`)
- Padding: `24px` vertical, `28px` horizontal
- Font: `Hack` or `Fira Code`, size `15px`
- Export: click arrow next to Export → **2x** (not 1x)
- Rename: `carbon-s[NN]-[topic].png`

**URL pattern for reproducible screenshots:**
```
https://carbon.now.sh?bg=rgba(40%2C40%2C40%2C1)&t=monokai&wt=none&l=[LANG]&ds=false&wc=false&wa=true&pv=24px&ph=28px&ln=false&fm=Hack&fs=15px&code=[URL_ENCODED_CODE]
```
Bookmark the URL — it encodes the code content. Any future edit: change `&code=` param, re-export.

**Embed layout on slides:**
- Use `DARK-CODE-SCREENSHOT` layout (see slide-templates.md)
- Carbon screenshot sits in the left or center panel
- Right panel or bottom: key callout boxes explaining the code
- Width/height in `addImage()`: calculate from image aspect ratio:
  - `w = 4.0` (half slide) → `h = w / aspectRatio`
  - `w = 6.4` (two-thirds) → `h = w / aspectRatio`

---

### Mermaid JS (.mmd source files)

For sequence diagrams, flowcharts, state machines.

**If user provides `.mmd` source:**
```bash
# Write the personal theme config (only needed once per session)
cat > /tmp/personal-mermaid-theme.json << 'EOF'
{
  "theme": "base",
  "themeVariables": {
    "background": "#282828", "mainBkg": "#3A3A3A",
    "nodeBorder": "#E84000", "clusterBkg": "#2A2A2A",
    "titleColor": "#FFFFFF", "edgeLabelBackground": "#282828",
    "nodeTextColor": "#FFFFFF", "lineColor": "#7DD3FC",
    "primaryColor": "#3A3A3A", "primaryTextColor": "#FFFFFF",
    "primaryBorderColor": "#E84000", "secondaryColor": "#27AE60",
    "tertiaryColor": "#2980B9", "fontFamily": "Arial, sans-serif", "fontSize": "16px"
  }
}
EOF

# Render at 300dpi equivalent
mmdc \
  -i /path/to/diagram.mmd \
  -o /tmp/mermaid-s[NN]-[topic].png \
  -c /tmp/personal-mermaid-theme.json \
  -b transparent \
  -w 2820 \
  -H 1008
```

**If user provides a pre-rendered PNG:** embed directly — skip mmdc.

**Notes:**
- Run mmdc as an isolated sub-agent (see infographic-workflow.md pattern)
- For sequence diagrams: the diagram is often taller than 3.36". Use h=4.0" and start at y=0.9 (just below subtitle), accept some cropping at bottom or use ARTIFACT-SPLIT

---

### NotebookLM

NotebookLM does not produce images — it produces structured notes, outlines, and podcast transcripts.

**How to use it:**
- If user shares a NotebookLM outline → treat it as **source mode B material** (local content)
- Extract key claims, data points, and narrative structure from the outline
- Map each NotebookLM section to a slide slot in STRUCTURE
- Do NOT embed NotebookLM output as-is — rephrase for slide density
- NotebookLM audio overviews → transcribe the key points as talking points in speaker notes

**Recommended handoff:**
1. User exports NotebookLM outline as PDF or copies text
2. Paste into the chat at RESEARCH stage
3. Claude synthesizes it alongside web research

---

### Datawrapper / Flourish / Observable

For data-driven charts (bar, line, area, scatter).

**Export steps (Datawrapper):**
1. Publish the chart → Share/Embed → Download PNG → **2x resolution**
2. Rename: `chart-s[NN]-[topic].png`

**Notes:**
- Datawrapper PNGs have white backgrounds → use on `LS()` slides or add dark rectangle behind
- Flourish exports include branding — crop or use the paid version to remove

---

### Excalidraw

For hand-drawn style sketches, whiteboard diagrams.

**Export steps:**
1. Menu → Export image → **PNG** → **Scale: 3x**, **Background: ✓ transparent**
2. Rename: `excalidraw-s[NN]-[topic].png`

**Notes:**
- Excalidraw's sketchy aesthetic works well on light slides (`LS()`)
- On dark slides: export with dark bg (`#282828`) or use a light slide for this one

---

## Artifact Embed Rules

### Sizing: how to calculate h from w

```js
// Get actual pixel dimensions first:
// identify -format "%wx%h" /path/to/artifact.png
// Then: aspectRatio = pixelWidth / pixelHeight

// INFOGRAPHIC-EMBED slot (full width):
const w = 9.4, h = w / aspectRatio;
// Cap h at 3.8 — if taller, use ARTIFACT-SPLIT instead

// ARTIFACT-SPLIT left panel (half width):
const w = 4.55, h = w / aspectRatio;
// Cap h at 4.3 — if taller, crop or use full-width

// DARK-CODE-SCREENSHOT (two-thirds):
const w = 6.4, h = w / aspectRatio;
```

**Shell command to get dimensions:**
```bash
identify -format "%wx%h\n" /path/to/artifact.png
# or without ImageMagick:
python3 -c "from PIL import Image; im=Image.open('/path/to/artifact.png'); print(im.size)"
```

### Placement: standard positions

| Slot | x | y | w | h |
|------|---|---|---|---|
| Full canvas below title | 0.3 | 1.15 | 9.4 | calc |
| Left two-thirds | 0.3 | 1.15 | 6.4 | calc |
| Left half | 0.3 | 1.15 | 4.55 | calc |
| Right half | 5.12 | 1.15 | 4.55 | calc |
| Center with margin | 0.8 | 1.2 | 8.4 | calc |

### Dark slide treatment for light-bg artifacts

If artifact has a white/light background and is being embedded on a DS() slide:

**Option A — add a dark mat:**
```js
// White mat behind the artifact
s.addShape(pres.shapes.RECTANGLE, {
  x: artX - 0.1, y: artY - 0.1, w: artW + 0.2, h: artH + 0.2,
  fill: { color: "F2F2F2" }, line: { color: "CCCCCC", width: 0.5 }
});
s.addImage({ path: artifactPath, x: artX, y: artY, w: artW, h: artH });
```

**Option B — use LS() for that slide and continue the deck.**
Mixing slide types within a deck is fine — one light slide in a dark section is acceptable if the artifact requires it.

---

## ARTIFACT-SPLIT Layout

For artifacts that work better side-by-side with annotations or key points.

```js
function sN_artifactSplit(artifactPath, artifactAspectRatio, isDark) {
  const s = isDark ? DS() : LS();
  if (isDark) accent(s, C.textOnDark);

  isDark
    ? dt(s, "Slide Title", "Subtitle")
    : lt(s, "Slide Title", "Subtitle");

  // Left: artifact image
  const artW = 5.6;
  const artH = Math.min(artW / artifactAspectRatio, 4.0);
  const artY = 1.15 + (4.0 - artH) / 2;   // vertically center in content area

  s.addImage({ path: artifactPath, x: 0.3, y: artY, w: artW, h: artH });

  // Right: annotation cards (3 callout boxes)
  const callouts = [
    { lbl: "KEY POINT A", val: "Short statement", sub: "Supporting detail", c: C.orange },
    { lbl: "KEY POINT B", val: "Short statement", sub: "Supporting detail", c: C.teal   },
    { lbl: "KEY POINT C", val: "Short statement", sub: "Supporting detail", c: C.green  },
  ];
  let cy = 1.2;
  callouts.forEach(co => {
    s.addShape(pres.shapes.RECTANGLE, {
      x: 6.1, y: cy, w: 3.6, h: 0.98,
      fill: { color: isDark ? C.cardDark : "EBEBEB" },
      line: { color: co.c, width: 1.5 }, shadow: mks()
    });
    s.addShape(pres.shapes.RECTANGLE, {
      x: 6.1, y: cy, w: 0.06, h: 0.98,
      fill: { color: co.c }, line: { color: co.c }
    });
    s.addText(co.lbl, {
      x: 6.22, y: cy+0.06, w: 2.4, h: 0.22,
      fontSize: 9, bold: true, color: co.c, fontFace: "Arial", margin: 0
    });
    s.addText(co.val, {
      x: 6.22, y: cy+0.28, w: 3.3, h: 0.28,
      fontSize: 13, bold: true, color: isDark ? C.textOnDark : C.textDark,
      fontFace: "Arial", margin: 0
    });
    s.addText(co.sub, {
      x: 6.22, y: cy+0.58, w: 3.3, h: 0.34,
      fontSize: 10, color: isDark ? C.textBody : C.textMid,
      fontFace: "Arial", margin: 0, lineSpacingMultiple: 1.15
    });
    cy += 1.10;
  });

  slideNum(s, N);
  s.addNotes("KEY STAT: ...\n\nTALKING POINTS:\n• ...");
}
// Left panel: x=0.3, w=5.6 → right edge 5.9. Right panel: x=6.1, w=3.6 → right edge 9.7 ✓.
// Gap between artifact and callouts: 6.1 - 5.9 = 0.2".
```

---

## DARK-CODE-SCREENSHOT Layout

For carbon.now.sh screenshots with annotation callouts.

```js
function sN_codeScreenshot(carbonPngPath, aspectRatio) {
  const s = DS();
  accent(s, C.textOnDark);
  dt(s, "Code Slide Title", "What this code does — one sentence");

  // Code image (two-thirds width)
  const imgW = 6.4;
  const imgH = Math.min(imgW / aspectRatio, 3.8);
  s.addImage({ path: carbonPngPath, x: 0.3, y: 1.15, w: imgW, h: imgH });

  // Right: 2–3 annotation boxes pointing at the code
  const annotations = [
    { lbl: "WHAT IT DOES",  text: "Brief explanation of this block",   c: C.lightBlue },
    { lbl: "KEY DETAIL",    text: "The important thing to notice here", c: C.yellow    },
    { lbl: "GOTCHA",        text: "Common mistake to avoid",            c: C.orange    },
  ];
  let ay = 1.2;
  annotations.forEach(an => {
    s.addShape(pres.shapes.RECTANGLE, {
      x: 6.9, y: ay, w: 2.8, h: 0.92,
      fill: { color: C.cardDark }, line: { color: an.c, width: 1.5 }, shadow: mks()
    });
    s.addShape(pres.shapes.RECTANGLE, {
      x: 6.9, y: ay, w: 0.06, h: 0.92,
      fill: { color: an.c }, line: { color: an.c }
    });
    s.addText(an.lbl, {
      x: 7.02, y: ay+0.06, w: 2.5, h: 0.20,
      fontSize: 8, bold: true, color: an.c, fontFace: "Arial", margin: 0
    });
    s.addText(an.text, {
      x: 7.02, y: ay+0.28, w: 2.6, h: 0.56,
      fontSize: 10.5, color: C.textBody, fontFace: "Arial", margin: 0, lineSpacingMultiple: 1.15
    });
    ay += 1.04;
  });

  // Language tag (top-right, matches RAG deck pattern)
  const lang = "PYTHON";   // or "TYPESCRIPT", "BASH", etc.
  const tagW = lang.length * 0.12 + 0.3;
  s.addShape(pres.shapes.RECTANGLE, {
    x: 9.6 - tagW, y: 0.22, w: tagW, h: 0.32,
    fill: { color: C.orange }, line: { color: C.orange }
  });
  s.addText(lang, {
    x: 9.6 - tagW + 0.08, y: 0.24, w: tagW - 0.16, h: 0.28,
    fontSize: 10, bold: true, color: C.textOnDark, fontFace: "Arial", margin: 0
  });

  slideNum(s, N);
  s.addNotes("KEY STAT: ...\n\nTALKING POINTS:\n• Walk through the code left-to-right\n• ...");
}
// Code image: x=0.3, w=6.4 → right edge 6.7. Annotation column: x=6.9 → gap 0.2" ✓.
// 3 annotations × 1.04 = 3.12 → last bottom at 1.2+3.12=4.32 < safeBot ✓.
```

---

## Quality Rules for External Artifacts

Before embedding any external artifact, verify:

- [ ] Pixel dimensions retrieved (`identify` or PIL)
- [ ] Aspect ratio calculated correctly
- [ ] h does not push image below y=5.09
- [ ] On dark slides: white-bg artifacts get a mat shape or use LS()
- [ ] carbon.now.sh PNGs: background matches deck dark (`#282828`) — if not, add mat
- [ ] napkin.ai / Datawrapper: white bg → use on LS() or add `#F2F2F2` mat
- [ ] draw.io: transparent bg exports work on both DS() and LS()
- [ ] Mermaid PNGs: rendered with personal theme (not default blue theme)
- [ ] All paths are absolute — expand `~` to `/Users/username`
