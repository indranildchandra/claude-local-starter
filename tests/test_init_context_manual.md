# Manual Integration Test: /init-context

These tests must be run manually inside an active Claude Code session.
Automated bats tests cannot exercise slash commands.

## Prerequisites
- Claude Code installed and running
- `/init-context` command synced to `~/.claude/commands/` (run install.sh first)
- A project with `tasks/` and `docs/` structure (run `/init-repo` in test project)

---

## Test 1: Silent skip on fresh session (no marker)

**Setup:**
```bash
rm -f tasks/.session-handover
```

**Action:** Start a new Claude Code session and type anything.

**Expected:** `/init-context` fires via SessionStart hook, detects NO_HANDOVER, completes silently. User sees no context-loading output.

**Pass criteria:** [ ] No "HANDOVER_FOUND" output, session starts normally

---

## Test 2: Context loads when marker exists

**Setup:**
```bash
touch tasks/.session-handover
echo "# Tracker\n## 2026-03-21\n- Task: Implement watchdog\n- Status: in_progress\n- Next: Run bats tests" > tasks/tracker.md
echo "# Todo\n## In Progress\n- [ ] Run bats tests\n## Up Next\n- [ ] Update install.sh" > tasks/todo.md
echo "# Plan Log\n---\n2026-03-21 - Implement Ollama switchover" > docs/plan.md
```

**Action:** Start a new Claude Code session.

**Expected:** SessionStart hook detects marker, runs `/init-context`, Claude outputs a 1-paragraph briefing about the in-progress task.

**Pass criteria:**
- [ ] Claude outputs a briefing paragraph
- [ ] Briefing mentions the in-progress task ("Run bats tests")
- [ ] `tasks/.session-handover` is deleted after load
- [ ] `ls tasks/.session-handover` returns non-zero (file gone)

---

## Test 3: Marker deleted after load

**Verify after Test 2:**
```bash
ls tasks/.session-handover
# Should return: No such file or directory
```

**Pass criteria:** [ ] Marker file does not exist

---

## Test 4: Missing AIDLC files triggers /init-repo

**Setup:**
```bash
touch tasks/.session-handover
rm -f tasks/tracker.md tasks/todo.md docs/plan.md
```

**Action:** Start a new Claude Code session.

**Expected:** `/init-context` detects marker, finds missing files, runs `/init-repo` to create stubs, then outputs briefing.

**Pass criteria:**
- [ ] `/init-repo` output visible in session
- [ ] Stub files created
- [ ] Context briefing still produced (from stubs)

---

## Full Cycle Simulation (End-to-End)

```bash
# 1. Simulate limit hit
echo "hit your limit · resets 12:30am" > /tmp/fake-transcript.txt
echo "{\"transcript_path\":\"/tmp/fake-transcript.txt\",\"cwd\":\"$(pwd)\"}" \
  | bash ~/.claude/scripts/limit-watchdog.sh

# 2. Verify override exists
cat ~/.claude/.ollama-override
# → export ANTHROPIC_AUTH_TOKEN=ollama
# → export ANTHROPIC_API_KEY=""
# → export ANTHROPIC_BASE_URL=http://localhost:11434

# 3. Verify handover marker exists
ls tasks/.session-handover  # → file exists

# 4. Start Claude Code (routes to Ollama due to override)
source ~/.claude/.ollama-override
claude --model smollm2:360m
# → Claude starts, SessionStart hook fires, /init-context loads context

# 5. Simulate switchback
bash ~/.claude/scripts/switch-to-anthropic.sh "$(pwd)"
# → override removed, new handover marker written

# 6. Start Claude Code again (back to Anthropic)
claude
# → SessionStart hook fires, /init-context loads context from new marker
```
