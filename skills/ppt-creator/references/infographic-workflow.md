# Infographic Sub-Agent Workflow
### Read when an infographic candidate is identified during STRUCTURE or REVIEW.
### Do NOT read at invocation — load only when needed to protect context window.

---

## When to Trigger

Evaluate every slide during STRUCTURE. Propose infographic replacement if the slide matches
any of these patterns:

| Slide content | Infographic type | Tool |
|---------------|-----------------|------|
| 3+ metrics with trend or comparison | Bar / grouped bar chart | Chart.js + chartjs-node-canvas |
| Distribution or part-of-whole | Donut / pie chart | Chart.js + chartjs-node-canvas |
| Time series or progression | Line chart | Chart.js + chartjs-node-canvas |
| Process flow with 4+ steps | Flowchart | Mermaid CLI |
| Hierarchy or tree | Tree / org diagram | Mermaid CLI |
| 4+ sequential pipeline stages | Sequence / pipeline diagram | Mermaid CLI |
| Two-variable scatter or bubble | Scatter chart | Chart.js + chartjs-node-canvas |
| Waterfall / before-after delta | Waterfall bar | Chart.js (custom) |

**Never replace with infographic:** single-stat slides, pure-text argument slides,
citation slides, close slides.

---

## Approval Gate — MANDATORY

Before generating any infographic, present the proposal in the STRUCTURE output:

```
INFOGRAPHIC PROPOSAL — Slide [N]
──────────────────────────────────────────────────────────────────
Current layout:  [LAYOUT-NAME] — [brief description of text content]
Proposed visual: [Chart type] — [what it will show and why it is clearer]
Tool:            [chartjs-node-canvas | Mermaid CLI]
Palette:         [which C tokens map to which data series]

Example sketch:
  [ASCII or text mock of what the infographic will look like]

→ Approve infographic for slide [N]? (yes / no / describe change)
──────────────────────────────────────────────────────────────────
```

**Wait for explicit approval.** Do not generate until yes.
If no: keep original text layout. If changes: confirm revised design before generating.

---

## Tool Stack

### Tool 1 — Chart.js + chartjs-node-canvas (data charts)

```bash
npm install chart.js chartjs-node-canvas --save
```

Capabilities: bar, line, pie, donut, scatter, radar, bubble.
Output: PNG buffer → write to file.

**Personal theme config for Chart.js:**
```js
const { ChartJSNodeCanvas } = require('chartjs-node-canvas');

// Canvas dimensions for INFOGRAPHIC-EMBED slot: 9.4" × 3.36" @ 300dpi (2x for crisp display)
// 300dpi ensures sharpness on projectors and after Google Slides import/export
const WIDTH  = 2820;   // 9.4 * 300
const HEIGHT = 1008;   // 3.36 * 300

const chartJSNodeCanvas = new ChartJSNodeCanvas({
  width: WIDTH, height: HEIGHT,
  backgroundColour: 'transparent',
  chartCallback: (ChartJS) => {
    ChartJS.defaults.font.family = 'Arial, sans-serif';
    ChartJS.defaults.font.size   = 28;   // 2x font size matches 2x canvas
    ChartJS.defaults.color       = '#AAAAAA';   // C.textBody — visible on dark bg
  },
});

// Personal palette as Chart.js colours
const P = {
  orange:     '#E84000', green:      '#27AE60',
  lightGreen: '#4ADE80', blue:       '#2980B9',
  lightBlue:  '#7DD3FC', purple:     '#9B59B6',
  yellow:     '#FFC000', red:        '#CC2222',
  white:      '#FFFFFF', textBody:   '#AAAAAA',
};

async function renderChart(config, outputPath) {
  const buffer = await chartJSNodeCanvas.renderToBuffer(config);
  require('fs').writeFileSync(outputPath, buffer);
  console.log('Infographic written:', outputPath);
}
```

**Example — bar chart:**
```js
await renderChart({
  type: 'bar',
  data: {
    labels: ['Label A', 'Label B', 'Label C'],
    datasets: [{
      label: 'Dataset',
      data: [42, 78, 61],
      backgroundColor: [P.lightGreen, P.blue, P.orange],
      borderRadius: 4,
      borderSkipped: false,
    }]
  },
  options: {
    plugins: { legend: { display: false }, title: { display: false } },
    scales: {
      x: { grid: { color: '#444444' }, ticks: { color: P.textBody } },
      y: { grid: { color: '#444444' }, ticks: { color: P.textBody } },
    },
    animation: false,
  }
}, '/tmp/infographic_s05.png');
```

---

### Tool 2 — @mermaid-js/mermaid-cli (diagrams and flows)

```bash
npm install -g @mermaid-js/mermaid-cli
# or local:
npm install @mermaid-js/mermaid-cli --save-dev
```

Capabilities: flowchart, sequence, class, state, gantt, mindmap, timeline.
Output: PNG via `mmdc -i input.mmd -o output.png`.

**Personal theme config for Mermaid (save as `/tmp/personal-mermaid-theme.json`):**
```json
{
  "theme": "base",
  "themeVariables": {
    "background":           "#282828",
    "mainBkg":              "#3A3A3A",
    "nodeBorder":           "#E84000",
    "clusterBkg":           "#2A2A2A",
    "titleColor":           "#FFFFFF",
    "edgeLabelBackground":  "#282828",
    "nodeTextColor":        "#FFFFFF",
    "lineColor":            "#7DD3FC",
    "primaryColor":         "#3A3A3A",
    "primaryTextColor":     "#FFFFFF",
    "primaryBorderColor":   "#E84000",
    "secondaryColor":       "#27AE60",
    "tertiaryColor":        "#2980B9",
    "fontFamily":           "Arial, sans-serif",
    "fontSize":             "14px"
  }
}
```

**CLI command:**
```bash
mmdc \
  -i /tmp/diagram.mmd \
  -o /tmp/infographic_s05.png \
  -c /tmp/personal-mermaid-theme.json \
  -b transparent \
  -w 2820 \
  -H 1008
```
# 2820×1008 = 9.4"×3.36" @ 300dpi — crisp on projectors and Google Slides

**Example Mermaid source:**
```
flowchart LR
  R["RESEARCH\nExplore codebase"] --> HG1{{"HUMAN\nReview findings"}}
  HG1 --> P["PLAN\nExplicit steps"] --> HG2{{"HUMAN\nApprove plan"}}
  HG2 --> I["IMPLEMENT\nLow-context execution"]
  style R    fill:#2980B9,color:#fff,stroke:#2980B9
  style HG1  fill:#E84000,color:#fff,stroke:#E84000
  style P    fill:#9B59B6,color:#fff,stroke:#9B59B6
  style HG2  fill:#E84000,color:#fff,stroke:#E84000
  style I    fill:#27AE60,color:#fff,stroke:#27AE60
```

---

## Sub-Agent Workflow

Run infographic generation as an **isolated sub-agent** to avoid loading
chart code and npm output into the main deck context window.

### Main agent does:
1. Identifies infographic candidate during STRUCTURE
2. Presents approval proposal (see gate above)
3. Waits for user approval
4. **On approval:** spawns infographic sub-agent with focused prompt below
5. Sub-agent returns PNG path
6. Main agent uses `INFOGRAPHIC-EMBED` layout with that path
7. Main agent views the slide in QA PNG for final visual confirmation

### Sub-agent prompt template:

```
You are an infographic rendering agent. Your only job is to generate
a single PNG infographic file and report the output path.

SLIDE CONTEXT:
[Paste the slide content — data points, labels, relationships]

CHART TYPE: [bar / line / donut / flowchart / etc.]

OUTPUT PATH: /tmp/infographic_s[N].png

CANVAS: 2820 × 1008 px at 300dpi (2x for projector/Google Slides sharpness)

PERSONAL PALETTE (use only these):
  orange     #E84000   green      #27AE60
  lightGreen #4ADE80   blue       #2980B9
  lightBlue  #7DD3FC   purple     #9B59B6
  yellow     #FFC000   white      #FFFFFF
  textBody   #AAAAAA

TOOL: [chartjs-node-canvas | mermaid-cli]

FONT: Arial, sans-serif

STEPS:
1. Write the chart/diagram code to /tmp/infographic_s[N].[js|mmd]
2. Run it to produce /tmp/infographic_s[N].png
3. Verify file exists and size > 0
4. Report: "Infographic written to /tmp/infographic_s[N].png"
   Do not return image content — just the path.

Do NOT: install packages other than chartjs-node-canvas / @mermaid-js/mermaid-cli.
Do NOT: load the PNG binary into your context.
Do NOT: do anything other than produce the PNG.
```

### After sub-agent completes:
1. Main agent embeds PNG using `sN_infographicEmbed(pngPath, title, caption, isDark)`
2. Run QA — view the slide PNG and verify:
   - Infographic fills the slot cleanly (no whitespace gaps at edges)
   - Colors match personal palette (no default Chart.js blue)
   - Text readable at presentation scale
   - No chart legend overlapping axes or data
3. Present the slide in REVIEW: **"Infographic for slide [N] — approve or request changes?"**
4. Only proceed to final GENERATE after confirmation

---

## Output Size Reference

All infographics rendered at 300dpi (2x) for crisp display on projectors and after Google Slides import.
pptxgenjs embeds the PNG at the correct physical size regardless of pixel count.

| Slot | Physical size | DPI | Pixels |
|------|--------------|-----|--------|
| INFOGRAPHIC-EMBED (standard) | 9.4" × 3.36" | 300 | 2820 × 1008 |
| Half-width left | 4.55" × 3.36" | 300 | 1365 × 1008 |
| Half-width right | 4.55" × 3.36" | 300 | 1365 × 1008 |

**Why 300dpi:** Google Slides resamples images on import and on export to PDF/PNG.
At 150dpi, bar chart text and thin lines appear blurry on a 4K projector or when
the audience zooms in. 300dpi stays sharp at any zoom level with ~2× file size overhead
(typically 200–400 KB per infographic — acceptable).

---

## Installed package check

```bash
node -e "require('chartjs-node-canvas')" 2>/dev/null && echo "chartjs-node-canvas OK" || npm install chartjs-node-canvas chart.js --save
mmdc --version 2>/dev/null || npm install -g @mermaid-js/mermaid-cli
```
