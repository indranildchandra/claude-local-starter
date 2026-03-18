---
description: Trigger a review-council session for a codebase, module, or specific design decision. Pass a scope argument or leave blank to review the full repo. Uses dynamic expert personas, parallel subagent analysis, structured debate, and human input to reach a verdict.
---

You are orchestrating a design review. This command is a thin entry point — the full council protocol lives in the `review-council` skill.

## Step 1 — Determine scope

**If an argument was provided** (e.g. `/design-review src/auth/` or `/design-review "the new caching strategy"`):
- Use the argument as the review scope directly.

**If no argument was provided:**
- Run a quick scan: check recent git changes (`git log --oneline -20`), list top-level directories, and read the root CLAUDE.md if present.
- Identify the highest-risk area: the most recently changed module, the most complex subsystem, or anything flagged in CLAUDE.md as a known constraint.
- Propose this as scope in one sentence.

## Step 2 — Assemble scope brief

Write a scope brief (1 short paragraph, max 5 sentences):
- What is being reviewed
- Why it warrants a review now
- Any context from CLAUDE.md relevant to this scope

## Step 3 — Invoke review-council skill

Hand off to the `review-council` skill with:
- The scope brief from Step 2
- Any argument passed by the user

The review-council skill will run the full Phase 0–7 protocol:
- Phase 0: confirm scope and gather early human input
- Phase 1: domain fingerprinting
- Phase 2: persona selection
- Phase 3: independent parallel persona reviews
- Phase 4: council debate
- Phase 5: human input solicitation
- Phase 6: synthesis and verdict
- Phase 7: record to docs/design-review.md and tasks/tracker.md
