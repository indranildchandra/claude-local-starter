---
description: Scaffold an agent-teams structure inside the current project's .claude/ directory. Creates numbered subfolders for orchestration, context management, slash commands, and hooks — with working templates for each.
---

You are scaffolding agent-team infrastructure for this project. The goal is a numbered `.claude/` layout that Claude Code reads in order, with an orchestrator that coordinates specialised sub-agents each operating in their own context window.

## Pre-flight

1. Confirm `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is set — check by running:
   ```bash
   echo $CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS
   ```
   If blank, it will be set by the project-level `enable-flag.json` created in Step 1.

2. Identify the project's primary domains (e.g. api, frontend, infra, test) — you will create one specialist agent template per domain.

3. Read the project `CLAUDE.md` if it exists so agent templates can reference the real tech stack.

## Step 1 — Create directory structure

```
.claude/
  1-agent-teams/
    enable-flag.json       ← project-level flag (belt + suspenders)
    orchestrator.md        ← coordinates all sub-agents
    setup-agent.md         ← project setup / scaffolding tasks
    <domain>-agent.md      ← one per domain found in pre-flight (api, frontend, etc.)
  2-context-management/
    CLAUDE.local.md        ← private overrides, gitignored
  3-slash-commands/        ← project-specific commands (optional, can mirror ~/.claude/commands/)
  4-hooks/
    register.json          ← project-level hooks registration
```

Create all directories and files in one pass.

## Step 2 — Write `1-agent-teams/enable-flag.json`

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

## Step 3 — Write `1-agent-teams/orchestrator.md`

Tailor to the actual project. Template:

```markdown
# Orchestrator

You are the orchestrator. You break work into parallel streams, spawn specialist agents, and synthesise their results. You do NOT implement — you coordinate.

## Rules
- Spawn agents simultaneously for independent work; never serial when parallel is possible
- Each agent gets a self-contained prompt with full context (they share no memory with you)
- Every agent prompt must end with AIDLC closeout: write tracker.md entry, mark plan.md checklist, capture lessons
- Wait for all agents to complete before synthesising
- Surface conflicts and integration concerns to the user before merging agent outputs

## Agent roster
<!-- Filled in by /init-agent-teams based on detected domains -->

## Spawning pattern
"Spawn [n] agents in parallel. Agent 1: [task A]. Agent 2: [task B]. Wait for all, then..."
```

## Step 4 — Write `1-agent-teams/setup-agent.md`

```markdown
# Setup Agent

You handle project initialisation, dependency installation, environment configuration, and scaffolding tasks.

## Responsibilities
- Install / update dependencies
- Configure environment files (.env, config/*)
- Run database migrations
- Scaffold boilerplate files from templates

## Rules
- Never modify business logic — only infrastructure and configuration
- Always verify a step succeeded before proceeding
- Report exact commands run and their exit codes
```

## Step 5 — Write one `<domain>-agent.md` per detected domain

For each domain (api, frontend, infra, test, etc.), create a specialist agent file:

```markdown
# <Domain> Agent

You are a specialist for the <domain> layer of this project.

## Scope
- Files: <list relevant paths>
- Responsibilities: <what this agent owns>
- Off-limits: <what it must NOT touch — other agents' domains>

## Tech stack for this layer
<!-- Copy relevant section from project CLAUDE.md -->

## Rules
- Stay within your scope — cross-domain changes must be flagged to the orchestrator
- Write tests for every behaviour change
- Follow project conventions (see root CLAUDE.md)
```

## Step 6 — Write `2-context-management/CLAUDE.local.md`

```markdown
# CLAUDE.local.md — Private project overrides

This file is gitignored. Use it for:
- Personal API keys or tokens referenced by name only (never values)
- Local path overrides
- Temporary debugging flags
- Notes you don't want in the shared CLAUDE.md
```

Add `.claude/2-context-management/CLAUDE.local.md` to `.gitignore` if not already present.

## Step 7 — Write `4-hooks/register.json`

```json
{
  "hooks": {
    "PostToolUse": [],
    "PreToolUse": [],
    "Stop": []
  },
  "_note": "Project-level hooks. Register commands here; they merge with ~/.claude/settings.json hooks."
}
```

## Step 8 — Report

Tell the user:
1. All files created (with paths)
2. Domains detected → agent files created
3. How to use: "To start a multi-agent task, open Claude Code and describe the work. The orchestrator.md will coordinate agents automatically when CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 is active."
4. Remind: personalise each agent file with real scope boundaries from the project's architecture
