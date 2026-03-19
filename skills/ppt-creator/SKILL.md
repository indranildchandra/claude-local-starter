---
disable-model-invocation: true
name: ppt-creator
triggers: ["/create-ppt", "build a presentation", "create a deck", "make slides", "personal presentation", "conference talk", "meetup slides"]
---

# ppt-creator

Produces a presentation-ready .pptx in the personal design system derived from
RAG Done Right Production.pptx. Suitable for conference talks, meetups, internal
presentations, and any non-work-branded decks.

All design values are sourced from `references/design-system.md`. Do not invent
colour values, spacing, or typography outside that file.

## Reference Files

Read only at the stage they are needed — never all at once.

| File | Read when |
|------|-----------|
| `personal-info.md` | At invocation — speaker name, title, QR path, defaults |
| `references/design-system.md` | At invocation — C palette, primitives, layout grid |
| `references/slide-templates.md` | At GENERATE only — layout skeletons |
| `references/boilerplate.js` | At GENERATE — copy verbatim as deck file base, do not read into context |
| `references/infographic-workflow.md` | Only when an infographic candidate is identified — do not load otherwise |
| `references/artifact-guide.md` | At ARTIFACTS checkpoint only — export settings and embed rules for napkin.ai, draw.io, carbon.now.sh, Mermaid, NotebookLM |
| `references/design-system-override-guide.md` | Only at DESIGN-DISCOVERY — when user requests a custom/alternative design system |

```bash
# Run at invocation:
cat ~/.claude/skills/ppt-creator/personal-info.md
cat ~/.claude/skills/ppt-creator/references/design-system.md

# Run only when GENERATE begins:
cat ~/.claude/skills/ppt-creator/references/slide-templates.md

# At GENERATE: copy the file, do not cat it
cp ~/.claude/skills/ppt-creator/references/boilerplate.js /path/to/[deck-name].js

# Run ONLY when an infographic candidate is identified (not before):
cat ~/.claude/skills/ppt-creator/references/infographic-workflow.md

# Run ONLY at the ARTIFACTS checkpoint (not before):
cat ~/.claude/skills/ppt-creator/references/artifact-guide.md

# Run ONLY at DESIGN-DISCOVERY (not before):
cat ~/.claude/skills/ppt-creator/references/design-system-override-guide.md
```

---

## Workflow

```
RESEARCH → ALIGN [CHECKPOINT] → STRUCTURE (→ DECK-PLAN.md) → ARTIFACTS [CHECKPOINT] → DESIGN [CHECKPOINT] → GENERATE → REVIEW [CHECKPOINT] → CLOSE
```

---

### Stage 1 — RESEARCH

**First action: ask source mode. Do not search until answered.**

```
RESEARCH SOURCE MODE
──────────────────────────────────────────────
How should I source content for this deck?

  A  Internet only
  B  Local files / documents you provide
  C  Hybrid — web first, you supplement

A / B / C ?
──────────────────────────────────────────────
```

**Mode A:** Run 5–8 web searches immediately.

**Mode B:** Say "Please share your files or paste your content." Wait. Do not search.
Treat everything provided as primary source.

**Mode C:** Run 3–5 web searches. Present findings. Ask: "Anything to add, replace,
or correct?" Incorporate user material as primary, overriding conflicts.

**Research standard (A and C):** Specific numbers, named sources, dateable claims.
Not summaries. Cover: current state, quantitative benchmarks, failure modes,
competitive context, audience priors.

**Citation rule:** Every web-sourced data point gets a superscript assigned here
(¹ ² ³ …). Same number = same source throughout the entire deck.
Internal / user-provided data = `[Internal]`. No citation number needed.

**Synthesis output:**

```
RESEARCH SYNTHESIS — [Topic]
──────────────────────────────────────────────────────────────────
SOURCE MODE: [A / B / C]

CORE FINDING:
One sentence — the single most important thing this research establishes.

KEY DATA POINTS:
¹  [Claim or metric] — [Why it matters]
   [Publication, Year] — [URL]

²  [Claim or metric] — [Why it matters]
   [Publication, Year] — [URL]

(5+ points for A/C; all available material for B)

NARRATIVE TENSION:
The gap between current state and what should be true.
This is what the deck resolves.

AUDIENCE LIKELY BELIEVES:
The assumption that needs to shift before the deck lands.

GAPS:
• What is unverified or missing
• What would strengthen the argument
──────────────────────────────────────────────────────────────────
```

After presenting, ask: "Does this capture what you need, or do you want
to redirect, add material, or correct any findings?"

Wait. Re-number citations if data points change.

---

### Checkpoint — ALIGN

Present all three questions with suggestions derived from the research. The user
picks from the suggestions or writes their own — they should never have to start
from a blank prompt.

Generate the suggestions from what the research actually revealed. Do not use
generic placeholders — they must be specific to this topic and audience.

```
Before I build the structure, three quick questions. Pick one or write your own:

──────────────────────────────────────────────────────────────────
1. Who's the audience and what's the one thing they should walk
   away believing or deciding?

   A  [Specific audience + belief derived from research — e.g.
      "ML engineers at DevFest who should believe RAG outperforms
      fine-tuning for most production use cases"]
   B  [Alternative framing — different audience or belief]
   C  [A more action-oriented version — "should decide to..."]
   D  Write your own

──────────────────────────────────────────────────────────────────
2. What's one concrete thing they should leave able to DO?

   A  [Specific technique or action — e.g. "Implement a hybrid
      retrieval pipeline using BM25 + dense vectors"]
   B  [A decision or evaluation skill — e.g. "Evaluate whether
      their team should use RAG vs fine-tuning"]
   C  [Something smaller and more immediate]
   D  Write your own

──────────────────────────────────────────────────────────────────
3. What's the one thing you most want to avoid this deck implying?

   A  [A common misread of this topic — e.g. "That RAG is a
      drop-in replacement for a proper data pipeline"]
   B  [A credibility risk — e.g. "That this is only theoretical,
      not battle-tested"]
   C  [An audience alienation risk]
   D  Write your own
──────────────────────────────────────────────────────────────────
```

Wait for all three answers. Use Q1+Q2 to define `INTENDED OUTCOME` in the slide plan.
Use Q3 to audit every slide for accidental implication before presenting the plan.

---

### Stage 2 — STRUCTURE

Build the slide plan. This is where the narrative architecture happens.

A strong structure has:
- An opening that creates tension, not just announces a topic
- A credibility beat at slide 2 (ORANGE-SPEAKER) before any data is shown
- A data layer that earns the argument before making it
- A diagnosis slide that names what is actually broken, not just symptomatic
- Options or a path forward with trade-offs named honestly
- A close that ties back to the opening tension

**Credibility beat — ORANGE-SPEAKER at slide 2:**
Include unless the user explicitly says to skip it or the event context makes it redundant
(e.g., the speaker is already well-known to the entire room). Credentials must be
specific and earned — never generic buzzwords.

**Context detection — apply before choosing layouts:**
Detect audience context from the user's description and adjust layout emphasis:
- Developer/GDG/meetup → more DARK-NROW (techniques), code slides, architecture diagrams
- Enterprise/conclave/CXO → more LIGHT slides (frameworks), metrics, business impact framing
- Keynote/main stage → single bold claim per slide, max visual impact, minimal text
- Workshop/tutorial → step-by-step DARK-NROW heavy, code screenshots, higher slide count

**Content density — enforce before presenting the plan:**
Every slide must stay within budget (from design-system.md). If a planned slide is
over budget, split it or cut content before presenting to the user.

**Infographic evaluation — run for every content slide:**

After drafting the narrative structure, review each slide and ask:
> "Would this slide be clearer and more memorable as a visual rather than text?"

Flag any slide that matches these patterns with `[INFOGRAPHIC?]` in the plan:
- 3+ data points forming a relationship, trend, or comparison
- A process flow with 4+ steps (especially with branching)
- A hierarchy or tree relationship
- Numeric-heavy content where >60% of the slide is numbers
- A before/after with quantified delta

For each flagged slide, include an infographic proposal block in the STRUCTURE output:

```
[INFOGRAPHIC?] Slide [N] — [current layout]
  Proposed: [chart type — why it is clearer than text]
  Tool:     [chartjs-node-canvas | Mermaid CLI]
  Data:     [the actual data points that would be visualised]
  Approve?  yes / no / describe change
```

**Rules:**
- Do NOT generate infographics speculatively — only after user approval
- Do NOT load `infographic-workflow.md` until at least one slide is approved
- If user declines all infographics, proceed with text layouts — no retry
- Infographic generation runs as an isolated sub-agent after STRUCTURE sign-off,
  before GENERATE begins — see `references/infographic-workflow.md`

**The slide plan is a suggestion.** Every element is open to change:
slide count, sequence, layouts, titles, content briefs. The only
non-negotiable is the design system. Present it as a starting point.

**If source mode was B (local only):** Omit all `Citations:` lines from the plan.
**If source mode was A or C:** Include citation refs per slide as shown.

```
SLIDE PLAN — [Topic]
──────────────────────────────────────────────────────────────────
NARRATIVE ARC:    [The one-sentence story this deck tells]
INTENDED OUTCOME: [What the audience does or believes after the last slide]

01  [LAYOUT]   [Role of this slide — not just its title]
    Content:   [What goes on it and why]
    Citations: [¹ Source, Year] or none

02  [LAYOUT]   [Role]
    Content:   [What and why]
    Citations: [refs] or none

... (continue for all slides)

──────────────────────────────────────────────────────────────────
Total: N   Orange: N   Dark: N   Light: N
Time at 2 min/slide: ~N minutes

CITATION INDEX:
¹  [Full source, Year] — [URL]
²  [Full source, Year] — [URL]
(all superscripts used — omit section if source mode B)

This is a suggestion. Tell me what to add, remove, reorder, or change
before I build. Slide count and structure are entirely yours to shape.
──────────────────────────────────────────────────────────────────
```

Wait for explicit confirmation or changes. Incorporate all edits.

**After sign-off: write the approved plan to `DECK-PLAN.md`** in the working directory.
This file is what the user takes away to create external artifacts (napkin.ai infographics,
draw.io diagrams, carbon.now.sh screenshots, etc.) before generation begins.

```bash
# After plan sign-off:
cat > /path/to/DECK-PLAN.md << 'EOF'
[paste the approved SLIDE PLAN block verbatim, including narrative arc, all slides, citation index]
EOF
```

---

### Checkpoint — ARTIFACTS

The slide plan is locked. Offer — do not require — an artifacts pause.

```
ARTIFACTS CHECKPOINT
──────────────────────────────────────────────────────────────────
DECK-PLAN.md written to [path].

Before I build: if you have external visuals to incorporate —
napkin.ai infographics, draw.io or Mermaid diagrams, carbon.now.sh
code screenshots — share them now and I'll embed them in the right
slides.

Skip if you'd like me to start building straight away.
──────────────────────────────────────────────────────────────────
```

**If artifacts are provided:**
1. Read `references/artifact-guide.md` now
2. Register each artifact: `[A1] napkin-overview.png — overview infographic, planned for slide 4`
3. Confirm export spec per tool (resolution, background, format) — request re-export if spec not met
4. Map each artifact to its target slide from DECK-PLAN.md
5. Then proceed to GENERATE

**If user skips:** proceed to GENERATE immediately — do not load `artifact-guide.md`.

---

### Checkpoint — DESIGN

Every deck passes through this gate before generation — even if no artifacts were provided.

```
DESIGN CHECKPOINT
──────────────────────────────────────────────────────────────────
Slide plan is locked[, artifacts registered: A1–AN].

Two options for the visual design:

  1  Keep the default design system — orange / charcoal / light,
     your established speaker brand. Reference artifacts inform
     content and layout only, not the colour scheme or typography.

  2  Extract and use the design system from a reference deck —
     I'll analyse its colour palette, type scale, and layout
     philosophy and build this deck in that style instead.

Which would you like?
──────────────────────────────────────────────────────────────────
```

**If option 1 (default — most common):** proceed to GENERATE immediately.

**If option 2 (extract from reference):**
1. Read `references/design-system-override-guide.md`
2. Run DESIGN-DISCOVERY on the reference file (VQA extraction)
3. Present the extracted system for approval (palette, type scale, mood)
4. On approval: proceed to GENERATE using the custom system
5. The custom system applies to this deck only — next session reverts to default

---

### Stage 3 — GENERATE

**Deck file naming — use this convention every time:**
```
<TalkSlug>-<EventSlug>-<AuthorSlug>-<YYYY>.pptx
# e.g.: rag-production-devfest-blr-indranil-2026.pptx
#       llm-evaluation-pycon-india-indranil-2026.pptx
#       data-mesh-conclave-indranil-2026.pptx
```

Rules:
- Derive `TalkSlug` from the talk title: 2–4 meaningful words, lowercase, hyphens
- Derive `EventSlug` from the event name: shorten to the distinctive part (e.g. "devfest-blr", "pycon-india", "conclave")
- `AuthorSlug`: first name only from `personal-info.md` (e.g. "indranil") — keep it short
- `YYYY`: year only — month is noise unless the same talk runs twice in a year
- If the title or event is short enough (≤ 4 words), use it verbatim; slug only when needed to keep the filename under 60 chars total

**Now read slide-templates.md and copy boilerplate.js:**
```bash
cat ~/.claude/skills/ppt-creator/references/slide-templates.md
cp ~/.claude/skills/ppt-creator/references/boilerplate.js /path/to/[deck-name].js
```

**Code rules:**
- One named function per slide: `function s01_title() { ... }`
- `slideNum(s, N)` — N is the actual slide number, not a placeholder
- Every `addText()` specifies `fontFace: "Arial"` — no exceptions
- Accent pill: call `accent(s)` first on every DS() and OS() slide
- Shadow factories: call `mks()` or `mksl()` inline — never assign to a variable and reuse
- Never reuse option objects across addShape/addText calls (pptxgenjs mutates)
- Every body text block with `h > 0.30` must include `lineSpacingMultiple: 1.15`
  — applies to: bullets, card body text, statement text, description blocks
  — skip for: slide numbers, metric numbers, short single-line labels (h ≤ 0.30)
- Speaker info: read from `personal-info.md` — expand `~` to absolute path for QR images

**Speaker brand mark:** After reading `personal-info.md`, call `speakerMark(s, website)` on
every DS() and LS() body slide. Skip OS() slides. If `website` is blank in personal-info.md,
omit the call entirely.

**Code snippet slides:** Use the DARK-CODE layout from slide-templates.md.
The code block is a dark rectangle with monospace text runs. Each token type
(keyword, string, comment, function name) gets its own colour run using pptxgenjs
rich text arrays. Do NOT use carbon.now.sh unless the user explicitly requests
a carbon screenshot — the DARK-CODE layout is native and editable in the .pptx.

**Dark slide colour rules — enforced at code-write time:**
- Body text: `C.textOnDark` (primary) or `C.textBody` (secondary) — NEVER `C.textMid`
- Captions/muted text: `C.textMuted` — NEVER `C.textMid` on dark slides
- No `C.textOnDark` or `C.textBody` on light slides — use `C.textDark` / `C.textMid`

**Citation rules:**
- Superscript Unicode inline on the data point: ¹ ² ³ ⁴ ⁵ ⁶ ⁷ ⁸ ⁹
- Call `sourceFootnote(s, [...], onDark)` on slides with web-sourced data
- Max 2 citations per `sourceFootnote()` call
- Full citation in speaker notes: `SOURCE ¹: [Publication, Year] — [URL]`
- Source mode B (internal only): no citations needed

**Citations slide — mandatory for source mode A and C decks:**
- ALWAYS generate a DARK-CITATIONS slide as the penultimate or final slide
- Use the `sN_citations(allCitations)` template from slide-templates.md

**Speaker notes — every slide:**
```
KEY STAT: [Most important number or claim on this slide]

TALKING POINTS:
• [What to say first — context]
• [Main point]
• [So-what / implication]
• [Anticipated objection]

SOURCES:                          ← omit if no web data on this slide
¹ [Publication, Year] — [URL]
```

**Build and QA:**
```bash
cd [working-dir]
npm install pptxgenjs --save 2>/dev/null || true
node [deck-name].js 2>&1

soffice --headless --convert-to pdf --outdir /tmp/ppt_qa [deck-name].pptx 2>/dev/null
pdftoppm -r 150 -png /tmp/ppt_qa/[deck-name].pdf /tmp/ppt_qa/slide
```

**Build error handling — do not skip or paper over errors:**

| Error | Cause | Fix |
|-------|-------|-----|
| `Cannot find module 'pptxgenjs'` | npm install failed or wrong dir | `cd` to correct dir, re-run npm install |
| `TypeError: pres.addSlide is not a function` | pptxgenjs version mismatch | Check `node_modules/pptxgenjs/package.json` version — must be v3.x |
| `ENOENT: no such file or directory` (image path) | QR or infographic path wrong | Expand `~` to absolute path, verify file exists |
| `RangeError` / infinite loop in slide function | Mutated options object reused across calls | Find and fix the reused object literal |
| soffice produces 0-page PDF | .pptx corrupt | Re-run `node [deck].js` — check for silent write errors |
| pdftoppm produces no PNGs | soffice failed silently | Run without `2>/dev/null` to see the error |

If any build error occurs: fix the root cause in the deck .js file and rebuild.
Do not proceed to QA or REVIEW until `node [deck].js` exits with code 0.

QA checklist:
- [ ] Every title fits on one line, no wrapping
- [ ] No text or shape below y=5.09 (except slideNum and speakerMark)
- [ ] No element overlap within any slide
- [ ] accent() called first on every DS() and OS() slide
- [ ] Slide numbers sequential at x=9.25 y=5.09
- [ ] No blank slides
- [ ] No `C.textMid` on any dark/orange slide (grep the code)
- [ ] Citations slide present as last slide (source mode A/C only)
- [ ] All body text blocks with h > 0.30 have `lineSpacingMultiple: 1.15`
- [ ] Shadow factories called inline (never reused)
- [ ] Personal info fields populated (name, title, website, QR path expanded)
- [ ] speakerMark() called on every DS() and LS() body slide (skip OS())
- [ ] Layout sequence grammar followed (no 4+ consecutive dark slides, no consecutive orange)
- [ ] Content density within budget (max words/bullets per slide type)
- [ ] No font sizes outside the Type Scale table in design-system.md
- [ ] ORANGE-SPEAKER present at slide 2 (unless explicitly skipped)

Do not deliver until QA passes.

---

### Checkpoint — REVIEW

REVIEW has two phases: Visual QA (automated, runs before the user sees anything),
then user review. The user should never have to report a layout bug — catch them first.

**Phase 1 — Visual QA (mandatory, runs before presenting to user)**

The QA PNGs are already rendered during GENERATE. View every slide now:

```bash
# PNGs are at /tmp/ppt_qa/slide-*.png — view each one
```

For each slide, check visually:

| Category | What to look for |
|----------|-----------------|
| **Text overflow** | Any text cut off at right edge or bottom of slide |
| **Title wrapping** | Any title running onto a second line |
| **Element collision** | Overlapping text boxes, shapes bleeding into each other |
| **Bottom bleed** | Content visually cut off below the slide boundary |
| **Colour legibility** | Any text that is hard to read against its background (especially greys on dark) |
| **Orange rhythm** | Orange slides are spaced — never two consecutive, never more than one per section |
| **Speaker mark** | Visible (but not dominant) in footer of every body slide |
| **Infographic fit** | Infographic fills its slot cleanly — no white border gap, not cropped |
| **Slide number** | Present, bottom-right, every slide |

For every issue found: fix the code, rebuild, re-render the affected slide PNG, re-check.
Do not proceed to Phase 2 until all Visual QA issues are resolved.

**Phase 2 — Present to user**

Once Visual QA is clean:

```
SLIDE REVIEW
──────────────────────────────────────────────────────────────────
Visual QA: passed — N slides, 0 issues found.

##  Layout               Title (40 chars)                  Notes
01  [ORANGE-TITLE]       "Opening title..."
02  [ORANGE-SPEAKER]     "About the speaker"
03  [DARK-CONTENT]       "Hook slide..."                   ¹
04  [LIGHT-3COL]         "Three pillars..."                ²³
...
──────────────────────────────────────────────────────────────────
Anything you'd like changed?
──────────────────────────────────────────────────────────────────
```

After any user-requested changes: re-run Visual QA on affected slides, fix any
regressions, then re-present the updated table.

---

### Stage 4 — CLOSE

```
DELIVERY NOTES
──────────────────────────────────────────────────────────────────
FILE: [deck-name].pptx — [N] slides

BEFORE YOU PRESENT:
• Slide [N] — [specific reason this slide will draw a challenge]
• Data point ¹ on slide [N] — [context a questioner will probe]
• Likely question: "[specific question]" — answer is on slide [N]

ONE FOLLOW-ON DECK THIS SETS UP:
• [Specific title and audience]
──────────────────────────────────────────────────────────────────
```

---

## QA Error Reference

| Symptom | Cause | Fix |
|---------|-------|-----|
| Dark slide body text invisible | Used `C.textMid` on dark slide | Replace with `C.textBody` or `C.textOnDark` |
| Light card text invisible | Used `C.textBody` on light slide | Replace with `C.textDark` or `C.textMid` |
| Card text bleeds into left stripe | Text x too close to card x | Text starts at `cardX + 0.14` minimum |
| Section slide number clips | Wrong y on font size 160 | Keep y=1.35, h=2.6 |
| Footnote overlaps slide number | y too low | Single: y=4.85. Two stacked: y=4.72/4.89 |
| Shadow mutation | Reused `mks()` result | Call inline: `shadow: mks()` every time |
| Content cut off at bottom | Element below y=5.09 | Move into safe zone |
| Personal info missing | Forgot to read personal-info.md | `cat ~/.claude/skills/ppt-creator/personal-info.md` |
| Speaker mark missing | speakerMark() not called on body slides | Add to every DS()/LS() slide function |
| Deck feels inconsistent | Layout sequence grammar broken | Check: no 4+ consecutive DS(), no consecutive OS() except TITLE+SECTION |
| Slide feels cluttered | Over content density budget | Count words; split or cut — see density table in design-system.md |
| Non-standard font size | Ad hoc size not in Type Scale | Map to nearest named role in design-system.md |
| Credibility missing | No ORANGE-SPEAKER at slide 2 | Add unless user explicitly removed it |
