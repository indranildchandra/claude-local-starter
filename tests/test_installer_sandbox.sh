#!/usr/bin/env bash
# tests/test_installer_sandbox.sh
#
# Runs install.sh in an isolated sandbox HOME to verify that all artefacts
# are correctly deployed against a simulated pre-existing Claude Code environment.
#
# Usage:
#   bash tests/test_installer_sandbox.sh
#
# Exit 0 if all checks pass; exit 1 with a failure count on any failures.

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SANDBOX="/tmp/claude-sandbox-installer-test-$$"

PASS=0
FAIL=0

# ── Helpers ──────────────────────────────────────────────────────────────────

pass() { echo "  ✓  $1"; PASS=$((PASS+1)); }
fail() { echo "  ✗  FAIL: $1"; FAIL=$((FAIL+1)); }

check_exists() {
  local desc="$1" path="$2"
  [ -e "$path" ] && pass "$desc" || fail "$desc — missing: $path"
}

check_contains() {
  local desc="$1" path="$2" pattern="$3"
  grep -q "$pattern" "$path" 2>/dev/null && pass "$desc" || fail "$desc — pattern '$pattern' not found in $path"
}

check_not_contains() {
  local desc="$1" path="$2" pattern="$3"
  ! grep -q "$pattern" "$path" 2>/dev/null && pass "$desc" || fail "$desc — pattern '$pattern' should not be in $path"
}

# ── Resolve expected model value from repo settings.json ─────────────────────
EXPECTED_MODEL="$(python3 -c "import json; print(json.load(open('$REPO/settings.json')).get('model',''))")"

# ── Setup: fake HOME with a pre-existing Claude Code environment ──────────────

mkdir -p "$SANDBOX/.claude/skills/my-custom-skill"
mkdir -p "$SANDBOX/.claude/commands"
mkdir -p "$SANDBOX/.claude/scripts"

# Existing settings.json — simulates a user who already has Claude Code installed
# with custom values that should survive a merge (preserve_states=true path)
cat > "$SANDBOX/.claude/settings.json" << 'JSON'
{
  "model": "claude-opus-4-5",
  "enabledPlugins": {
    "context-mode": true,
    "typescript-lsp@claude-plugins-official": true,
    "my-private-plugin": true
  },
  "mcpServers": {
    "context7": {
      "type": "url",
      "url": "https://mcp.context7.com/mcp"
    },
    "my-custom-mcp": {
      "type": "command",
      "command": "echo",
      "args": ["custom"]
    }
  },
  "hooks": {
    "Stop": [
      { "hooks": [{ "type": "command", "command": "echo pre-existing-hook" }] }
    ]
  }
}
JSON

# Existing user skill — must survive cp -rn (no overwrite)
cat > "$SANDBOX/.claude/skills/my-custom-skill/SKILL.md" << 'MD'
---
name: my-custom-skill
---
# My Custom Skill
User's private skill — must not be overwritten.
MD

# Pre-existing shell rc file
cat > "$SANDBOX/.bashrc" << 'BASHRC'
# Pre-existing .bashrc content
export MY_CUSTOM_VAR="preserved"
BASHRC

# ── Mock wrappers: make heavy tools appear installed so the installer skips them
# Prevents npm install -g, playwright install, gitnexus setup etc. from running
# while still exercising the installer's "already installed" skip logic.
MOCKBIN="$SANDBOX/.mockbin"
mkdir -p "$MOCKBIN"

for cmd in uipro playwright-cli typescript-language-server; do
  printf '#!/usr/bin/env bash\necho "[mock] %s $@"\nexit 0\n' "$cmd" > "$MOCKBIN/$cmd"
  chmod +x "$MOCKBIN/$cmd"
done

# npm: pass through version/root queries; fake install/update
cat > "$MOCKBIN/npm" << 'NPMOCK'
#!/usr/bin/env bash
if [[ "$*" == *"install"* ]] || [[ "$*" == *"update"* ]]; then
  echo "[mock] npm $@ (skipped in sandbox)"
  exit 0
fi
exec /opt/node22/bin/npm "$@"
NPMOCK
chmod +x "$MOCKBIN/npm"

# npx: intercept skills add / gitnexus / playwright-cli; pass through anything else
cat > "$MOCKBIN/npx" << 'NPXMOCK'
#!/usr/bin/env bash
case "$*" in
  *"skills add"*|*"gitnexus"*|*"playwright-cli"*)
    echo "[mock] npx $@ (skipped in sandbox)"
    exit 0
    ;;
  *)
    exec /opt/node22/bin/npx "$@"
    ;;
esac
NPXMOCK
chmod +x "$MOCKBIN/npx"

# playwright: mock install chromium
cat > "$MOCKBIN/playwright" << 'PLAYMOCK'
#!/usr/bin/env bash
echo "[mock] playwright $@ (skipped in sandbox)"
exit 0
PLAYMOCK
chmod +x "$MOCKBIN/playwright"

# ── Run the installer ─────────────────────────────────────────────────────────
# Pipe interactive answers:
#   "n" = don't preserve existing CLAUDE.md (install from repo)
#   "y" = preserve existing plugin/skill enable-disable states

echo "Running install.sh in sandbox: $SANDBOX"
echo ""

export HOME="$SANDBOX"
export PATH="$MOCKBIN:/opt/node22/bin:/usr/local/bin:/usr/bin:/bin"

cd "$REPO"
echo -e "n\ny" | bash install.sh > "$SANDBOX/install.log" 2>&1
INSTALL_EXIT=$?

if [ $INSTALL_EXIT -ne 0 ]; then
  echo "install.sh exited with code $INSTALL_EXIT — last 20 lines of log:"
  tail -20 "$SANDBOX/install.log"
fi

# ── Verification ──────────────────────────────────────────────────────────────

echo ""
echo "── Directory structure ──"
check_exists "~/.claude/ created"               "$SANDBOX/.claude"
check_exists "~/.claude/skills/ created"        "$SANDBOX/.claude/skills"
check_exists "~/.claude/commands/ created"      "$SANDBOX/.claude/commands"
check_exists "~/.claude/scripts/ created"       "$SANDBOX/.claude/scripts"
check_exists "~/.claude-work/ created"          "$SANDBOX/.claude-work"
check_exists "~/.claude-work/CLAUDE.md seeded"  "$SANDBOX/.claude-work/CLAUDE.md"
check_exists "~/.claude-work/context/README.md" "$SANDBOX/.claude-work/context/README.md"

echo ""
echo "── Core files ──"
check_exists "CLAUDE.md installed"                 "$SANDBOX/.claude/CLAUDE.md"
check_exists "settings.json present"              "$SANDBOX/.claude/settings.json"
check_exists "statusline-command.sh deployed"     "$SANDBOX/.claude/statusline-command.sh"
check_exists "claude-local-starter.html deployed" "$SANDBOX/.claude/claude-local-starter.html"
check_exists "ollama.conf deployed"               "$SANDBOX/.claude/ollama.conf"
check_exists ".claudeignore created"              "$SANDBOX/.claude/.claudeignore"
check_exists "plugin_commands.sh written"         "$SANDBOX/.claude/plugin_commands.sh"
check_exists "install.sh copied to ~/.claude/"    "$SANDBOX/.claude/install.sh"

echo ""
echo "── Hook scripts ──"
check_exists "limit-watchdog.sh"      "$SANDBOX/.claude/scripts/limit-watchdog.sh"
check_exists "aidlc-guard.sh"         "$SANDBOX/.claude/scripts/aidlc-guard.sh"
check_exists "claudeignore-guard.sh"  "$SANDBOX/.claude/scripts/claudeignore-guard.sh"
check_exists "switch-to-ollama.sh"    "$SANDBOX/.claude/scripts/switch-to-ollama.sh"
check_exists "switch-to-anthropic.sh" "$SANDBOX/.claude/scripts/switch-to-anthropic.sh"

echo ""
echo "── Bundled skills synced ──"
check_exists "aidlc-tracking/SKILL.md"         "$SANDBOX/.claude/skills/aidlc-tracking/SKILL.md"
check_exists "review-council/SKILL.md"         "$SANDBOX/.claude/skills/review-council/SKILL.md"
check_exists "frontend-design-review/SKILL.md" "$SANDBOX/.claude/skills/frontend-design-review/SKILL.md"
check_exists "karpathy-guidelines/SKILL.md"    "$SANDBOX/.claude/skills/karpathy-guidelines/SKILL.md"

echo ""
echo "── karpathy-guidelines specifics ──"
check_contains "karpathy-guidelines context-on (disable-model-invocation: false)" \
  "$SANDBOX/.claude/skills/karpathy-guidelines/SKILL.md" \
  "disable-model-invocation: false"
check_contains "karpathy-guidelines has Think Before Coding section" \
  "$SANDBOX/.claude/skills/karpathy-guidelines/SKILL.md" \
  "Think Before Coding"
check_contains "karpathy-guidelines has Surgical Changes section" \
  "$SANDBOX/.claude/skills/karpathy-guidelines/SKILL.md" \
  "Surgical Changes"

echo ""
echo "── Humanizer skill ──"
check_exists "humanizer/SKILL.md cloned" "$SANDBOX/.claude/skills/humanizer/SKILL.md"
check_contains "humanizer patched context-off" \
  "$SANDBOX/.claude/skills/humanizer/SKILL.md" \
  "disable-model-invocation: true"

echo ""
echo "── Slash commands synced ──"
check_exists "commands/init-repo.md"               "$SANDBOX/.claude/commands/init-repo.md"
check_exists "commands/design-review.md"           "$SANDBOX/.claude/commands/design-review.md"
check_exists "commands/frontend-design-review.md"  "$SANDBOX/.claude/commands/frontend-design-review.md"
check_exists "commands/log-context.md"             "$SANDBOX/.claude/commands/log-context.md"

echo ""
echo "── settings.json merge correctness ──"
# Model should be overwritten with the repo value (not the sandbox pre-existing value)
check_contains "model set to repo value ($EXPECTED_MODEL)" \
  "$SANDBOX/.claude/settings.json" \
  "\"$EXPECTED_MODEL\""
# New MCP server from repo should be added
check_contains "gitnexus MCP merged in" \
  "$SANDBOX/.claude/settings.json" "gitnexus"
# User's custom MCP should be preserved
check_contains "user's custom MCP preserved" \
  "$SANDBOX/.claude/settings.json" "my-custom-mcp"
# Pre-existing Stop hooks preserved (additive merge)
check_contains "pre-existing hook preserved" \
  "$SANDBOX/.claude/settings.json" "pre-existing-hook"
# Repo hooks added alongside existing
check_contains "limit-watchdog hook added" \
  "$SANDBOX/.claude/settings.json" "limit-watchdog"
# User's private plugin survives (preserve_states=true was answered)
check_contains "private plugin preserved (preserve_states=true)" \
  "$SANDBOX/.claude/settings.json" "my-private-plugin"

echo ""
echo "── Custom user skill not overwritten (cp -rn) ──"
check_contains "user's private skill content intact" \
  "$SANDBOX/.claude/skills/my-custom-skill/SKILL.md" \
  "must not be overwritten"

echo ""
echo "── Shell functions injected into .bashrc ──"
check_contains "claude-local-starter managed block present" \
  "$SANDBOX/.bashrc" "claude-local-starter managed"
check_contains "enable-skill function" \
  "$SANDBOX/.bashrc" "enable-skill"
check_contains "disable-skill function" \
  "$SANDBOX/.bashrc" "disable-skill"
check_contains "list-skills function" \
  "$SANDBOX/.bashrc" "list-skills"
check_contains "switch-back function" \
  "$SANDBOX/.bashrc" "switch-back"
check_contains "pre-existing MY_CUSTOM_VAR untouched" \
  "$SANDBOX/.bashrc" "MY_CUSTOM_VAR"

# ── Summary ───────────────────────────────────────────────────────────────────

rm -rf "$SANDBOX"

echo ""
echo "══════════════════════════════════════════════"
echo "  Results: $PASS passed, $FAIL failed"
echo "══════════════════════════════════════════════"

exit $FAIL
