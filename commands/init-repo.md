---
description: Bootstrap Claude Code for a new or existing project. Runs gitnexus analysis, creates project CLAUDE.md, scaffolds all AIDLC tracking files, and creates sub-module CLAUDE.md files. Run once per project.
---

You are bootstrapping Claude Code for this project. Follow all steps in order.

## Step 1 — Understand the project *(3 parallel subagents)*

Spawn these simultaneously and wait for all three to complete before proceeding.

**Subagent A — Structure**
- Run `npx gitnexus analyze` to build the initial code knowledge graph
- List all top-level directories and identify sub-module boundaries
- Read any existing README.md, CLAUDE.md, or docs/ at root
- Report: tech stack, architecture pattern, key entry points

**Subagent B — Dependencies**
- Read package.json / requirements.txt / go.mod / Cargo.toml / pom.xml (whichever exist)
- Identify all external third-party integrations (APIs, SDKs, cloud services, auth providers)
- Note internal microservices separately
- Report: external integrations that will need live Context7 doc fetches before working on them

**Subagent C — Conventions**
- Read any .eslintrc, .prettierrc, pyproject.toml, Makefile, CI config files
- Check git log (last 20 commits) for coding patterns and commit message conventions
- Identify test framework, test directory structure, and how to run tests
- Report: conventions, patterns, what to preserve

## Step 2 — Create project root CLAUDE.md

Using findings from Step 1, create a `CLAUDE.md` tailored to this project.
Do not copy a generic template — every section must reflect what was actually found.

Required sections:
- **Project Overview** — what the system does, who uses it, scale/criticality
- **Architecture** — key services, boundaries, data flow; reference gitnexus graph
- **Tech Stack** — languages, frameworks, databases, infra; specific versions where relevant
- **External Integrations** — each external system, what it does, which service owns it; note that live Context7 docs must be fetched before working on any of these
- **Internal Services** — internal sub-modules and their responsibilities
- **Sub-module CLAUDE.md Index** — list created below; update as new ones are added
- **Conventions** — coding standards, naming, preferred patterns
- **Test Strategy** — framework, how to run tests (single test and full suite), coverage expectations
- **Key Commands** — build, test, lint, deploy commands specific to this project
- **Known Constraints** — performance, security, regulatory constraints, tech debt to avoid

## Step 3 — Create sub-module CLAUDE.md files

For each significant sub-directory, create a `CLAUDE.md` inside it. Keep to 20–40 lines.

Each sub-module CLAUDE.md must contain:
- What this module is responsible for
- Its public interface / API surface
- Key files and their roles
- Dependencies on other modules (internal and external)
- How to run its tests in isolation
- Any conventions specific to this module that differ from root

## Step 4 — Scaffold AIDLC tracking files

Load `aidlc-tracking` skill formats.md for exact templates before creating any file.

Create the following files if they do not already exist:

**`docs/plan.md`** — initial entry:
```
YYYY-MM-DD HH:MM:SS - Initial Claude Code project scaffold via /init-repo

### Context
Project bootstrapped with /init-repo. Gitnexus graph built. CLAUDE.md and sub-module docs created.

### Approach
Standard AIDLC scaffold. See tracking files below.

### Checklist
- [x] Ran npx gitnexus analyze
- [x] Created project root CLAUDE.md
- [x] Created sub-module CLAUDE.md files
- [x] Scaffolded all AIDLC tracking files
```

**`audit/changelog.md`** — initial entry:
```
YYYY-MM-DD HH:MM:SS - Initial Claude Code project scaffold created

### Changes
- Created project root CLAUDE.md
- Created sub-module CLAUDE.md files (see list in CLAUDE.md)
- Created docs/plan.md, audit/changelog.md, tasks/tracker.md, tasks/todo.md, tasks/lessons.md

### Files
- CLAUDE.md — created
- <sub-module>/CLAUDE.md — created (list each)
- docs/plan.md — created
- audit/changelog.md — created
- tasks/tracker.md — created
- tasks/todo.md — created
- tasks/lessons.md — created
```

**`tasks/tracker.md`** — initial entry:
```
YYYY-MM-DD HH:MM:SS — Project scaffold via /init-repo
Type: task-complete
Outcome: Gitnexus graph built, CLAUDE.md created, all AIDLC tracking files scaffolded.
Files changed: CLAUDE.md, docs/plan.md, audit/changelog.md, tasks/tracker.md, tasks/todo.md, tasks/lessons.md
```

**`tasks/todo.md`** — empty starter (just header)

**`tasks/lessons.md`** — empty starter (just header)

## Step 5 — Final summary

Report to the user:
1. Files created (with paths)
2. Sub-modules discovered and documented
3. External integrations found — remind that Context7 docs must be fetched before working on each
4. Gitnexus graph status
5. Recommended first task based on what was found
6. Suggest running `/design-review` if this is greenfield or involves a major architectural decision
