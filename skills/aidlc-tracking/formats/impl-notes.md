# Format: docs/impl-notes/<timestamp>_<slug>.md

One file per spec per iteration. Never overwrite an existing file.
Multiple iterations of the same module produce multiple timestamped files — that is correct behaviour.

## Filename derivation

```
YYYY-MM-DDTHH-MM-SS_<slug>.md
```

**Timestamp** — local timezone, derived at the moment the `<SPEC>` is received:
```bash
date '+%Y-%m-%dT%H-%M-%S'
```

**Slug** — in priority order:
1. `title` attribute if present: `<SPEC title="auth-module">` → `auth-module`
2. First non-empty line of the spec content, lowercased, spaces/punctuation → hyphens, max 48 chars

Examples:
```
2026-05-18T20-56-00_auth-module.md
2026-05-18T21-30-00_payment-flow-redesign.md
2026-08-12T09-15-00_auth-module.md    ← second iteration, same module
```

## Index file

After creating or updating any impl-notes file, regenerate `docs/impl-notes/index.md`.
Read all `*.md` files in the directory (excluding index.md itself), extract the title, status line,
and started line from each, then write the index newest-first.

Index template:

```markdown
# Implementation Notes — Index

{{COUNT}} spec(s) · last updated {{UPDATED}}

| Started | Spec | Status |
|---------|------|--------|
{{ENTRIES}}
```

Each `{{ENTRIES}}` row:
```
| {{STARTED}} | [{{SPEC_TITLE}}]({{FILENAME}}) | {{STATUS}} |
```

## impl-notes file template

Produce this structure for each new spec. Fill all `{{PLACEHOLDERS}}`.

```markdown
# {{SPEC_TITLE}}
<!-- meta status:{{STATUS}} started:{{STARTED}} session:{{SESSION_ID}} -->

**Session:** {{SESSION_ID}}
**Started:** {{STARTED}}
**File:** docs/impl-notes/{{FILENAME}}
**Status:** {{STATUS}}

---

## Spec

```
{{SPEC_CONTENT}}
```

---

## Design Decisions

_No decisions recorded yet._

---

## Deviations

_No deviations recorded yet._

---

## Tradeoffs

_No tradeoffs recorded yet._

---

## Open Questions

_No open questions._
```

## Entry formats

Once real entries exist, remove the `_No X recorded yet._` placeholder and add entries using the patterns below.

**Decision entry:**
```markdown
**[decision]** {{TITLE}} — {{TIMESTAMP}}

{{REASONING}}
```

**Deviation entry:**
```markdown
**[deviation]** {{TITLE}} — {{TIMESTAMP}}

- Spec said: {{SPEC_SAID}}
- We did: {{WHAT_WE_DID}}
- Because: {{REASON}}
```

**Tradeoff entry:**
```markdown
**[tradeoff]** {{TITLE}} — {{TIMESTAMP}}

Chosen: **{{CHOSEN}}** vs ~~{{REJECTED}}~~
{{REASONING}}
```

**Open question entry:**
```markdown
**[open]** {{QUESTION}} — {{TIMESTAMP}}

{{CONTEXT}}
```

**Resolved question entry** (update in-place, change tag):
```markdown
**[resolved]** {{QUESTION}} — {{TIMESTAMP}}

{{CONTEXT}}
Answer: {{ANSWER}}
```

Separate multiple entries within a section with a blank line.

## Field reference

| Field | Value |
|-------|-------|
| `{{SPEC_TITLE}}` | `title` attribute if present; otherwise first non-empty line of spec, max 48 chars |
| `{{SLUG}}` | `{{SPEC_TITLE}}` lowercased, spaces/punctuation → hyphens |
| `{{FILENAME}}` | `YYYY-MM-DDTHH-MM-SS_{{SLUG}}.md` using local timezone |
| `{{STARTED}}` | Local timezone datetime: `date '+%Y-%m-%d %H:%M:%S %Z'` |
| `{{SESSION_ID}}` | `$CLAUDE_SESSION_ID` or "unknown" |
| `{{STATUS}}` | `in-progress` → `complete` → `blocked` |
| `{{SPEC_CONTENT}}` | Full spec verbatim, unmodified |
| `{{TIMESTAMP}}` | Local timezone datetime of each entry |

## Update rules

- **Never overwrite** an existing impl-notes file — each `<SPEC>` invocation creates a new timestamped file
- **Update in-place** within the current session's file — sections are edited, not appended as new files
- **Remove `_No X recorded yet._` placeholders** as real entries are added to each section
- **Resolve questions** by changing `[open]` → `[resolved]`, adding the answer inline
- **Set status `complete`** when implementation is done and all questions resolved or explicitly deferred; update the `<!-- meta ... -->` comment and the `**Status:**` line
- **Regenerate index.md** after every create or status update
