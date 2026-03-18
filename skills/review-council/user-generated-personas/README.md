# User-Generated Personas

This directory grows over time as custom personas are defined during `/design-review` sessions.

When a user requests a persona not in `standard-personas/`, Claude:
1. Generates the persona using the schema below
2. Saves it here as `<kebab-case-name>.md`
3. Uses it immediately in the current council session
4. It is then available for all future sessions globally

---

## Persona file schema

```markdown
---
name: <Display Name>
domain: <Primary Domain>
model: sonnet | haiku
council-domains: [comma, separated, domain, tags]
---

## Role
What this persona is responsible for in a council review.
1-2 sentences. Specific, not generic.

## Review Lens
What they look for. What they challenge. What they protect.
5-7 bullet points as questions.

## Typical Concerns
3-5 patterns this persona reliably flags in reviews.
Be specific — not "security issues" but "JWT tokens without expiry".

## Challenge Style
How this persona engages with others in the debate round.
Are they scenario-driven, numerical, standards-referenced?
What makes them concede a point?
```

---

## Model selection guide

| Use haiku when | Use sonnet when |
|----------------|-----------------|
| Review is checklist-based or mechanical | Review requires multi-step reasoning |
| Domain is narrow and well-defined | Domain involves architectural tradeoffs |
| Speed matters more than depth | Depth matters more than speed |

Do not use opus — cost is not justified for council reviews.

---

## Naming convention

File name = display name in lowercase-kebab-case.
- `Blockchain Security Expert` → `blockchain-security-expert.md`
- `iOS Mobile Engineer` → `ios-mobile-engineer.md`
