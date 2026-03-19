# /create-ppt

Triggers the ppt-creator skill. Builds a presentation-ready .pptx
in the personal design system derived from RAG Done Right Production.pptx.

## Usage

```
/create-ppt [topic or brief]
```

Or just `/create-ppt` — the skill will ask for context.

## What Happens

```
RESEARCH → ALIGN [CHECKPOINT] → STRUCTURE → GENERATE → REVIEW [CHECKPOINT] → CLOSE
```

RESEARCH starts with a source mode question (internet / local files / hybrid)
before any searches run. Every web data point gets a citation number that
carries through the slide plan, slide footnotes, and speaker notes.

STRUCTURE produces a slide-by-slide plan with narrative rationale and citation
index. The plan is a suggestion — slide count, sequence, layouts, and content
are all yours to reshape before generation begins.

GENERATE builds the .pptx, runs LibreOffice QA (geometry check only), and
delivers for review.

Full workflow, code standards, and QA rules are in:
`~/.claude/skills/ppt-creator/SKILL.md`
