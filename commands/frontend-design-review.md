# /frontend-design-review

Run a full five-step design critique audit on an attached UI design.
Each step is a focused diagnostic with specific, ranked fixes.

## Usage

```
/frontend-design-review [optional: describe the design context]
```

Attach a screenshot or image of the design **once** — it will be analysed across all five steps without re-attachment.

---

## Before you begin

Ask the user for the following if not already provided:

1. **Business or communication goal** — what is this design meant to make the user do or feel? (Required for Step 1 to assess intended vs actual hierarchy.)
2. **Design context** — is this a landing page, dashboard, mobile app, email, etc.?

If $ARGUMENTS contains this context, use it directly and skip the questions.

---

## Steps

Work through each step in order. Steps must run sequentially — each prior step provides context that informs the next diagnosis.

**Step 1 — Visual Hierarchy**
Load and apply: `skills/frontend-design-review/prompts/01-visual-hierarchy-surgeon.md`

**Step 2 — Typography**
Load and apply: `skills/frontend-design-review/prompts/02-typography-interrogation.md`

**Step 3 — Whitespace & Spacing**
Load and apply: `skills/frontend-design-review/prompts/03-whitespace-pressure-test.md`

**Step 4 — Color & Contrast**
Load and apply: `skills/frontend-design-review/prompts/04-color-contrast-stress-test.md`

**Step 5 — Production Quality**
Load and apply: `skills/frontend-design-review/prompts/05-why-does-this-look-cheap.md`

---

## Final Summary — Cross-Cutting Pattern Analysis

After all five steps, synthesise findings into a **Priority Fix List**:

> 1. Identify any issue that appeared in **more than one step** — these are systemic, not isolated. Flag them as "cross-cutting" and consolidate into a single recommendation.
> 2. Separate fixes into two tiers: **Systemic** (root causes affecting multiple dimensions) and **Tactical** (isolated, quick wins).
> 3. Rank all fixes by ROI. Present the top 5 with: the element, the problem, the exact fix, and why it matters.
> 4. End with one sentence: the single highest-leverage change in this entire design.
