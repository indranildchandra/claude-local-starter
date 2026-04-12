# Claude Code: Quick Reference

---

## Keyboard Shortcuts

### General
| Shortcut | Action |
|----------|--------|
| `Ctrl+C` | Cancel input / stop generation |
| `Ctrl+D` | Exit session |
| `Ctrl+L` | Redraw screen |
| `Ctrl+O` | Toggle verbose / transcript mode |
| `Ctrl+R` | Reverse search history |
| `Ctrl+B` | Background the running task |
| `Esc Esc` | Rewind last turn or summarize |
| `Ctrl+S` | Stash current prompt (save for later) |
| `Ctrl+G` / `Ctrl+X Ctrl+E` | Open prompt in external editor |
| `Ctrl+X Ctrl+K` | Kill all background agents |

### Mode & Model
| Shortcut | Action |
|----------|--------|
| `Shift+Tab` | Cycle permission modes (Edit → Auto-accept → Plan) |
| `Meta+P` | Open model picker (`Meta` = Cmd on Mac, Alt on Linux/Win) |
| `Meta+T` | Toggle extended thinking |
| `Meta+O` | Toggle fast mode |

### Input
| Shortcut | Action |
|----------|--------|
| `\ + Enter` or `Ctrl+J` | Insert newline |
| `!` prefix | Run as bash command |
| `@` prefix | Mention a file (with autocomplete) |
| `Ctrl+V` | Paste image |

---

## Slash Commands

### Session
| Command | Action |
|---------|--------|
| `/clear` | Clear conversation history |
| `/compact [compaction instruction]` | Compress context (optionally guide what to keep) |
| `/resume` | Resume or switch to a previous session |
| `/rewind` | Roll back conversation + code to a prior checkpoint |
| `/export` | Export conversation |
| `/status` | Show usage statistics and activity |
| `/cost` | Show token usage and cost breakdown (useful in API-plan mode) |

### Config
| Command | Action |
|---------|--------|
| `/model` | Switch model interactively |
| `/fast` | Toggle fast mode |
| `/theme` | Change color theme |
| `/effort [level]` | Set effort: `low` `medium` `high` `max` |
| `/permissions` | View / update tool permissions |

### Utility
| Command | Action |
|---------|--------|
| `/init` | Auto-generate a `CLAUDE.md` for the current project |
| `/memory` | Browse and manage auto-memory files |
| `/plan` | Enter plan mode |
| `/btw` | Ask a side question — no context cost |
| `/voice` | Push-to-talk dictation (20 languages, spacebar to talk) |
| `/powerup` | Interactive lessons with animated demos |
| `/doctor` | Show keybinding warnings + diagnostics |
| `/team-onboarding` | Generate teammate ramp-up guide from session history |
| `/batch` | Run large-scale changes in parallel across multiple worktrees |
| `/loop` | Recurring scheduled task (e.g. `/loop 5m /mycommand`) |
| `/mcp` | Interactive MCP server management UI |

---

## CLI Reference

### Core Commands
```bash
claude                          # interactive mode
claude "prompt"                 # start with a prompt
claude -p "prompt"              # headless (non-interactive)
claude -c                       # continue last session
claude -r "session-name"        # resume session by name / session id
claude update                   # update Claude Code
```

### Key Flags
| Flag | Purpose |
|------|---------|
| `--model <id>` | Set model |
| `--permission-mode plan` | Start in plan mode |
| `--effort <level>` | `low` / `medium` / `high` / `max` |
| `--max-budget-usd <n>` | Hard cost cap for the session |
| `--output-format json` | Structured JSON output (headless) |
| `--worktree <name>` / `-w` | Isolated git worktree session |
| `--tmux` | Launch in a tmux pane (pair with `--worktree`) |
| `--bare` | Minimal headless — no hooks, no LSP |

---

## Config & Environment

### Config File Precedence
```
/etc/claude-code/managed-settings.d/   ← org policy (highest)
~/.claude/settings.json                ← user (all projects)
.claude/settings.json                  ← project (team-shared, version-controlled)
.claude/settings.local.json            ← local only (gitignored)
```

### Key Environment Variables
| Variable | Purpose |
|----------|---------|
| `ANTHROPIC_API_KEY` | API key |
| `ANTHROPIC_MODEL` | Model override |
| `CLAUDE_CODE_EFFORT_LEVEL` | `low` / `medium` / `high` / `max` / `auto` |
| `MAX_THINKING_TOKENS` | Max thinking budget; `0` = off |
| `CLAUDE_CODE_DISABLE_1M_CONTEXT` | Disable 1M context window |
| `CLAUDE_ENABLE_STREAM_WATCHDOG=1` | Enable streaming idle watchdog |
| `CLAUDE_STREAM_IDLE_TIMEOUT_MS` | Watchdog timeout in ms (default 90000; requires watchdog enabled) |
| `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1` | Disable auto-memory |
| `CLAUDE_CODE_AUTO_MEMORY_PATH` | Override auto-memory directory |

---

## Memory & Files

### CLAUDE.md Locations
| Path | Scope |
|------|-------|
| `/etc/claude-code/` | Org-wide (managed) |
| `~/.claude/CLAUDE.md` | Personal (all projects) |
| `./CLAUDE.md` | Project (team-shared, version-controlled) |

### Rules Files
```
.claude/rules/*.md          ← project-scoped rules
~/.claude/rules/*.md        ← user-scoped rules
```
Rules files support `paths:` frontmatter for path-specific activation.  
Use `@path/to/file` in `CLAUDE.md` to import additional files.

### Auto-Memory
- Location: `~/.claude/projects/<project>/memory/`
- Entry point: `MEMORY.md` + optional topic files
- Loaded at session start (first 200 lines / 25KB of `MEMORY.md`)
- Override location: `autoMemoryDirectory` in `settings.json` or `CLAUDE_CODE_AUTO_MEMORY_PATH`

---

## Hooks

Hooks run shell commands in response to Claude Code events. Configured in `settings.json` under the `hooks` key.

### Hook Types
| Event | When it fires |
|-------|--------------|
| `PreToolUse` | Before any tool call (can block) |
| `PostToolUse` | After a tool call completes |
| `PreCompact` | Before context compaction |
| `Stop` | When the agent turn ends |
| `StopFailure` | When the agent turn ends with an error |
| `SessionStart` | At the start of each session |
| `PermissionDenied` | When a tool call is blocked by permissions |
| `TaskCreated` | When a background task is spawned |
| `CwdChanged` | When working directory changes |
| `FileChanged` | When a file is written |

### Structure
```json
"hooks": [
  {
    "event": "PreToolUse",
    "matcher": "Bash",
    "command": "bash ~/.claude/scripts/my-guard.sh",
    "timeout": 10000
  }
]
```

### Controlling Execution
- **Exit 0** → allow / proceed
- **Exit non-zero** → block the tool call (stdout shown to Claude as reason)
- **JSON response** → `{"decision": "deny", "reason": "..."}` for `PreToolUse`
- **`"defer"`** decision → delegate to user in headless sessions

---

## MCP Servers

### Adding Servers
```bash
claude mcp add --transport stdio --scope project <name> <command>   # local process
claude mcp add --transport http --scope user <name> <url>           # remote HTTP
claude mcp add --transport sse --scope user <name> <url>            # remote SSE
claude mcp list                                                # list all servers
claude mcp serve                                               # run Claude Code as an MCP server
```

### Scopes
| Scope | File | Shared? |
|-------|------|---------|
| `local` | `.claude.json` | No |
| `project` | `.mcp.json` | Yes (VCS) |
| `user` | `~/.claude.json` | Global |

### Notes
- **Tool Search / lazy loading** — MCP tools load on demand; reduces context overhead significantly.
- **Elicitation** — MCP servers can request user input mid-task via the elicitation protocol.
- Manage interactively with `/mcp`.

---

## Skills & Agents

### Built-in Skills (invoke as `/skill-name`)
| Skill | What it does |
|-------|-------------|
| `/simplify` | Code review via 3 parallel agents |
| `/batch` | Parallel changes across 5–30 worktrees |
| `/debug` | Troubleshoot from a debug log |
| `/loop` | Recurring scheduled task |

### Built-in Agent Types (via `Agent` tool)
| Type | Model | Use for |
|------|-------|---------|
| `Explore` | Haiku (fast) | Read-only research and codebase exploration |
| `Plan` | Opus | Design and architecture planning |
| `general-purpose` | Configurable | Full tools, complex multi-step tasks |
| `Bash` | — | Terminal execution, isolated context |

### Custom Skills & Commands
```
skills/<name>/SKILL.md      ← skill definition (repo source of truth)
commands/<name>.md          ← slash command definition (repo source of truth)

.claude/skills/             ← project-scoped skills (runtime)
~/.claude/skills/           ← personal skills, all projects (runtime)
```
- Set `disable-model-invocation: true` in `SKILL.md` to prevent the skill from spawning sub-models (reduces token cost).
- Use `$ARGUMENTS` as a placeholder for user-provided input in commands.
- Ship executables alongside a skill via `plugin bin/`.

---

## Permissions & Safety

### Permission Modes
| Mode | Behaviour |
|------|-----------|
| Edit | Prompts for approval on sensitive operations |
| Auto | Accepts most operations (use with caution) |
| Plan | Read-only; no writes or executions |
| `--dangerously-skip-permissions` | Bypasses all prompts (CI / trusted scripts only) --> avoid! |

Cycle modes with `Shift+Tab` or start with `--permission-mode plan`.

### Fine-grained Tool Permissions
Add `allow` / `deny` lists to `.claude/settings.json`:
```json
"permissions": {
  "allow": ["Bash(git *)", "Bash(npm test)"],
  "deny": ["Bash(rm -rf *)"]
}
```

### .claudeignore
Works like `.gitignore` — Claude will not read, edit, or write matched paths.  
Place at repo root or any subdirectory.

---

## Workflows

### Plan Mode
```bash
claude --permission-mode plan   # start in plan mode
```
Or press `Shift+Tab` twice from Normal mode. Claude reads and plans but makes no changes until you approve.

### Thinking & Effort
- **`Meta+T`** toggles extended thinking.
- Say **"ultrathink"** in your prompt for maximum effort on one turn.
- `/effort` or `--effort` sets the session default: `○ low  ◐ medium  ●  high  ★ max`

### Context Management
- `/compact [focus]` compresses context; add a focus hint to guide what's kept.
- Auto-compact triggers at ~95% context capacity.
- `CLAUDE.md` always survives compaction.
- Run `/log-context` before `/compact` to preserve a session snapshot.

### Git Worktrees
```bash
claude --worktree feature-x     # isolated branch per feature
claude --worktree -              # auto-named worktree
```
`/batch` auto-creates worktrees for large parallel changes and opens PRs automatically.

### Headless / CI
```bash
claude -p "run the tests and report failures" --output-format json
claude -p "..." --bare --permission-mode plan
```
Use `--bare` to skip hooks and LSP in CI contexts.
