#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  claude-local-starter / install.sh
#
#  Lift-and-shift Claude Code setup onto any machine.
#
#  Default mode is --update (safe, non-destructive, backs up first).
#  Pass --clean-install to overwrite everything from scratch.
#
#  Usage:
#    bash install.sh                # safe update (default)
#    bash install.sh --clean-install  # full overwrite from repo
#    bash install.sh --dry-run        # preview only, no changes
#
#  Source: https://github.com/indranildchandra/claude-local-starter
# ════════════════════════════════════════════════════════════════

set -euo pipefail

# ── Flags ──────────────────────────────────────────────────────
CLEAN_INSTALL=false
DRY_RUN=false
for arg in "$@"; do
  case $arg in
    --clean-install) CLEAN_INSTALL=true ;;
    --dry-run)       DRY_RUN=true ;;
  esac
done
# Default behaviour is always update-safe
UPDATE=true

# Preserve flags -- set by interactive prompts below (update mode only)
PRESERVE_CLAUDEMD=false
PRESERVE_STATES=false

# ── Colours ────────────────────────────────────────────────────
R='\033[0;31m' G='\033[0;32m' Y='\033[1;33m'
C='\033[0;36m' M='\033[0;35m' B='\033[0;34m'
BOLD='\033[1m' RESET='\033[0m'

CLAUDE_DIR="${HOME}/.claude"
WORK_DIR="${HOME}/.claude-work"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SHELL_RC="${HOME}/.zshrc"
[ ! -f "$SHELL_RC" ] && SHELL_RC="${HOME}/.bashrc"

TS="$(date '+%Y%m%d_%H%M%S')"
BACKUP_DIR=""   # set in step 1 if backup is taken

# ── Helpers ────────────────────────────────────────────────────
log()  { echo -e "${C}[install]${RESET} $*"; }
ok()   { echo -e "${G}[done]${RESET}   $*"; }
warn() { echo -e "${Y}[skip]${RESET}   $*"; }
info() { echo -e "${B}[info]${RESET}   $*"; }
err()  { echo -e "${R}[error]${RESET}  $*"; }
step() { echo -e "\n${BOLD}${M}── $* ${RESET}"; }
run()  {
  if $DRY_RUN; then echo -e "${Y}[dry-run]${RESET} $*"
  else eval "$@"; fi
}
check_dep() {
  command -v "$1" &>/dev/null || { err "Required: $1 not found. Install it first."; exit 1; }
}

# ══════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}  claude-local-starter / install.sh${RESET}"
echo -e "  Target : ${CLAUDE_DIR}"
echo -e "  Mode   : $($CLEAN_INSTALL && echo 'clean install' || echo 'update (safe)')$($DRY_RUN && echo ' [dry-run]' || echo '')"
echo ""

# ── Update-mode prompts (existing install only, skipped on clean-install / dry-run) ──
if ! $CLEAN_INSTALL && ! $DRY_RUN && [ -d "${HOME}/.claude" ]; then
  echo -e "${BOLD}  Existing installation detected. Customize this update:${RESET}"
  echo ""
  printf "  Preserve your existing ~/.claude/CLAUDE.md? [y/N] (default: n) "
  read -r _ans_md
  [[ "$_ans_md" =~ ^[Yy] ]] && PRESERVE_CLAUDEMD=true

  printf "  Preserve existing MCP / plugin / skill enable-disable states? [Y/n] (default: y) "
  read -r _ans_states
  [[ -z "$_ans_states" || "$_ans_states" =~ ^[Yy] ]] && PRESERVE_STATES=true
  echo ""
fi

step "Pre-flight"
check_dep git
check_dep node
check_dep npm
check_dep python3

# Bun -- required by claude-mem stop hook and several other plugins
if command -v bun &>/dev/null; then
  warn "bun already installed"
else
  log "Installing Bun (required by claude-mem and other plugins)..."
  run "curl -fsSL https://bun.sh/install | bash 2>/dev/null || true"
  # Add bun to PATH for this session so subsequent steps can use it
  export BUN_INSTALL="$HOME/.bun"
  export PATH="$BUN_INSTALL/bin:$PATH"
  if command -v bun &>/dev/null; then
    ok "bun installed"
  else
    warn "bun install may require shell restart -- run: source ~/.zshrc"
  fi
fi

info "All dependencies present"

# ════════════════════════════════════════════════════════════════
step "1 / Backup -- snapshot mutable components before any changes"
# ════════════════════════════════════════════════════════════════
# Only runs on --clean-install. In update mode we never touch existing
# files (cp -rn, no overwrites) so there is nothing to back up.

if $CLEAN_INSTALL && [ -d "$CLAUDE_DIR" ]; then
  NEEDS_BACKUP=false
  [ -f "${CLAUDE_DIR}/CLAUDE.md" ] && NEEDS_BACKUP=true
  [ -d "${CLAUDE_DIR}/skills" ]   && [ "$(ls -A "${CLAUDE_DIR}/skills" 2>/dev/null)" ]   && NEEDS_BACKUP=true
  [ -d "${CLAUDE_DIR}/commands" ] && [ "$(ls -A "${CLAUDE_DIR}/commands" 2>/dev/null)" ] && NEEDS_BACKUP=true

  if $NEEDS_BACKUP; then
    BACKUP_DIR="${WORK_DIR}/backups/${TS}"
    run "mkdir -p '${BACKUP_DIR}'"
    log "Backing up mutable components..."

    [ -f "${CLAUDE_DIR}/CLAUDE.md" ] && {
      run "cp '${CLAUDE_DIR}/CLAUDE.md' '${BACKUP_DIR}/CLAUDE.md'"
      ok "  CLAUDE.md -> backups/${TS}/"
    }
    [ -d "${CLAUDE_DIR}/skills" ] && [ "$(ls -A "${CLAUDE_DIR}/skills" 2>/dev/null)" ] && {
      run "cp -r '${CLAUDE_DIR}/skills' '${BACKUP_DIR}/skills'"
      ok "  skills/   -> backups/${TS}/"
    }
    [ -d "${CLAUDE_DIR}/commands" ] && [ "$(ls -A "${CLAUDE_DIR}/commands" 2>/dev/null)" ] && {
      run "cp -r '${CLAUDE_DIR}/commands' '${BACKUP_DIR}/commands'"
      ok "  commands/ -> backups/${TS}/"
    }

    # Also sync backup into ~/.claude-work/ directly so it is
    # immediately loadable via 'cw' without knowing the timestamp.
    # We merge rather than overwrite so any existing work context is preserved.
    log "Merging backup into ~/.claude-work/..."
    run "mkdir -p '${WORK_DIR}/skills' '${WORK_DIR}/commands'"

    [ -f "${BACKUP_DIR}/CLAUDE.md" ] && {
      if [ ! -f "${WORK_DIR}/CLAUDE.md" ]; then
        run "cp '${BACKUP_DIR}/CLAUDE.md' '${WORK_DIR}/CLAUDE.md'"
        ok "  CLAUDE.md synced to ~/.claude-work/"
      else
        warn "  ~/.claude-work/CLAUDE.md exists -- not overwritten (edit manually if needed)"
      fi
    }
    [ -d "${BACKUP_DIR}/skills" ] && {
      run "cp -rn '${BACKUP_DIR}/skills/.' '${WORK_DIR}/skills/'"
      ok "  skills/ synced to ~/.claude-work/skills/ (no overwrites)"
    }
    [ -d "${BACKUP_DIR}/commands" ] && {
      run "cp -rn '${BACKUP_DIR}/commands/.' '${WORK_DIR}/commands/'"
      ok "  commands/ synced to ~/.claude-work/commands/ (no overwrites)"
    }

    info "Dated backup: ${BACKUP_DIR}"
    info "Live context: ${WORK_DIR}  (load with: cw)"
  else
    info "~/.claude is empty or new -- no backup needed"
  fi
else
  info "Update mode -- skipping backup (existing files are never overwritten)"
fi

# ════════════════════════════════════════════════════════════════
step "2 / ~/.claude -- directory structure"
# ════════════════════════════════════════════════════════════════

for dir in \
  "${CLAUDE_DIR}" \
  "${CLAUDE_DIR}/skills" \
  "${CLAUDE_DIR}/plugins" \
  "${CLAUDE_DIR}/commands"; do
  if [ ! -d "$dir" ]; then
    run "mkdir -p '$dir'"
    ok "created $dir"
  else
    warn "$dir exists"
  fi
done

# ════════════════════════════════════════════════════════════════
step "3 / settings.json"
# ════════════════════════════════════════════════════════════════
# Default (update): deep-merge repo values into existing file.
# --clean-install:  overwrite entirely from repo.

SETTINGS="${CLAUDE_DIR}/settings.json"
REPO_SETTINGS="${SCRIPT_DIR}/settings.json"

if [ -f "$REPO_SETTINGS" ]; then
  if [ ! -f "$SETTINGS" ] || $CLEAN_INSTALL; then
    run "cp '$REPO_SETTINGS' '$SETTINGS'"
    ok "settings.json installed"
  else
    # Safe merge: repo keys win for new entries; existing states preserved when requested
    PRESERVE_STATES_PY="${PRESERVE_STATES}" python3 - <<PYEOF
import json, os

repo_path = "${REPO_SETTINGS}"
live_path = "${SETTINGS}"
preserve_states = os.environ.get("PRESERVE_STATES_PY", "false").lower() == "true"

with open(repo_path) as f:
    repo = json.load(f)
with open(live_path) as f:
    live = json.load(f)

# env: always merge (no state to preserve)
if "env" in repo:
    live.setdefault("env", {})
    live["env"].update(repo["env"])

# mcpServers: new servers get repo defaults; existing servers keep their disabled
# flag when preserve_states is true
if "mcpServers" in repo:
    live.setdefault("mcpServers", {})
    for name, cfg in repo["mcpServers"].items():
        if name not in live["mcpServers"]:
            live["mcpServers"][name] = cfg
        elif preserve_states:
            existing_disabled = live["mcpServers"][name].get("disabled")
            live["mcpServers"][name].update(cfg)
            if existing_disabled is not None:
                live["mcpServers"][name]["disabled"] = existing_disabled
            elif "disabled" in live["mcpServers"][name]:
                del live["mcpServers"][name]["disabled"]
        else:
            live["mcpServers"][name].update(cfg)

# enabledPlugins: new plugins get repo defaults; existing plugins keep their
# true/false value when preserve_states is true
if "enabledPlugins" in repo:
    live.setdefault("enabledPlugins", {})
    for name, val in repo["enabledPlugins"].items():
        if name not in live["enabledPlugins"]:
            live["enabledPlugins"][name] = val
        elif not preserve_states:
            live["enabledPlugins"][name] = val
        # else: preserve_states=true and entry exists -- leave as-is

# hooks: always deep-merge (additive, no state concept)
if "hooks" in repo:
    live.setdefault("hooks", {})
    for event, hook_list in repo["hooks"].items():
        live["hooks"].setdefault(event, [])
        existing_cmds = {h.get("hooks", [{}])[0].get("command", "") for h in live["hooks"][event]}
        for entry in hook_list:
            cmd = entry.get("hooks", [{}])[0].get("command", "")
            if cmd not in existing_cmds:
                live["hooks"][event].append(entry)

# permissions: additive merge — never remove user entries; defaultMode only set if absent
if "permissions" in repo:
    live.setdefault("permissions", {})
    for lst in ("allow", "deny"):
        if lst in repo["permissions"]:
            live["permissions"].setdefault(lst, [])
            existing = set(live["permissions"][lst])
            for entry in repo["permissions"][lst]:
                if entry not in existing:
                    live["permissions"][lst].append(entry)
    if "defaultMode" in repo["permissions"] and "defaultMode" not in live["permissions"]:
        live["permissions"]["defaultMode"] = repo["permissions"]["defaultMode"]

# model: always set from repo (ensures opusplan is always the default)
if "model" in repo:
    live["model"] = repo["model"]

# statusLine: always set from repo (ensures statusline script is always wired up)
if "statusLine" in repo:
    live["statusLine"] = repo["statusLine"]

with open(live_path, "w") as f:
    json.dump(live, f, indent=2)
print("  merged")
PYEOF
    ok "settings.json merged (states $($PRESERVE_STATES && echo 'preserved' || echo 'reset to repo defaults'))"
  fi
else
  warn "No settings.json in repo -- skipping"
fi

# ════════════════════════════════════════════════════════════════
step "4 / statusline-command.sh"
# ════════════════════════════════════════════════════════════════

STATUSLINE_SRC="${SCRIPT_DIR}/statusline-command.sh"
STATUSLINE_DST="${CLAUDE_DIR}/statusline-command.sh"

if [ -f "$STATUSLINE_SRC" ]; then
  run "cp '$STATUSLINE_SRC' '$STATUSLINE_DST' && chmod +x '$STATUSLINE_DST'"
  ok "statusline-command.sh installed → ~/.claude/statusline-command.sh"
else
  warn "No statusline-command.sh in repo -- skipping"
fi

# ════════════════════════════════════════════════════════════════
step "5 / CLAUDE.md"
# ════════════════════════════════════════════════════════════════

CLAUDE_MD="${CLAUDE_DIR}/CLAUDE.md"
REPO_MD="${SCRIPT_DIR}/claude-md-master/CLAUDE.md"

if [ -f "$REPO_MD" ]; then
  if $PRESERVE_CLAUDEMD; then
    warn "CLAUDE.md preserved (user chose to keep existing)"
  else
    run "cp '$REPO_MD' '$CLAUDE_MD'"
    ok "CLAUDE.md installed (overwritten from claude-md-master)"
  fi
else
  warn "No claude-md-master/CLAUDE.md in repo -- skipping"
fi

# ════════════════════════════════════════════════════════════════
step "6 / Skills -- install via npx skills add"
# ════════════════════════════════════════════════════════════════
# npx skills add installs directly from the skills registry into
# ~/.claude/skills/ without needing an interactive Claude Code session.
# We run all skill installs from CLAUDE_DIR so they land in the right place.
#
# Skills installed here:
#   frontend-design       official Anthropic skill
#   ui-ux-pro-max         design intelligence (161 rules, 67 styles)
#   shadcn-ui             shadcn/ui deep knowledge  (npx skills add shadcn/ui)
#   web-design-guidelines Vercel Labs web design best practices
#   humanizer             strips AI writing patterns (blader)
#   codereview-roasted    Linus-style opinionated code review (OpenHands)

install_skill() {
  local pkg="$1"   # e.g. anthropics/skills
  local name="$2"  # e.g. frontend-design
  local dir="${CLAUDE_DIR}/skills/${name}"

  # In update mode, skip entirely -- skills are managed by Claude Code's plugin
  # marketplace and should not be reinstalled on every run.
  # Use --clean-install to force reinstall on a new machine.
  if ! $CLEAN_INSTALL; then
    warn "skill:${name} -- update mode, skipping (use --clean-install to install)"
    return
  fi

  # On clean-install, skip if already present
  if [ -d "${dir}" ]; then
    warn "skill:${name} already present -- skipping"
    return
  fi

  log "Installing skill:${name} from ${pkg}..."
  if ! $DRY_RUN; then
    # -g = global (~/.claude/skills/), -a claude-code = target agent, -y = non-interactive
    npx skills add "${pkg}" --skill "${name}" -g -a claude-code -y 2>&1 \
      && ok "skill:${name} installed to ~/.claude/skills/" \
      || warn "skill:${name} failed -- try manually: npx skills add ${pkg} --skill ${name} -g -a claude-code -y"
  else
    echo -e "${Y}[dry-run]${RESET} npx skills add ${pkg} --skill ${name} -g -a claude-code -y"
  fi
}

# Anthropic official skills
install_skill "anthropics/skills"                              "frontend-design"

# Community skills
install_skill "nextlevelbuilder/ui-ux-pro-max-skill"           "ui-ux-pro-max"
install_skill "shadcn/ui"                                      "shadcn"
install_skill "vercel-labs/agent-skills"                       "web-design-guidelines"
install_skill "openhands/extensions"                           "codereview-roasted"

# Patch community skills: inject disable-model-invocation: true if missing.
# Skills remain installed and user-invocable via /skill-name but cost
# zero tokens at session start (not listed in Claude's context).
for skill in frontend-design ui-ux-pro-max shadcn web-design-guidelines codereview-roasted; do
  skill_md="${CLAUDE_DIR}/skills/${skill}/SKILL.md"
  if [ -f "$skill_md" ] && ! grep -q "disable-model-invocation" "$skill_md"; then
    if ! $DRY_RUN; then
      skill_md_escaped="${skill_md}"
      python3 -c "
p = '${skill_md_escaped}'
c = open(p).read()
if c.startswith('---'):
    c = c.replace('---\n', '---\ndisable-model-invocation: true\n', 1)
else:
    c = '---\ndisable-model-invocation: true\n---\n' + c
open(p,'w').write(c)
"
      ok "skill:${skill} patched: disable-model-invocation: true"
    else
      echo -e "${Y}[dry-run]${RESET} would patch ${skill}/SKILL.md"
    fi
  elif [ -f "$skill_md" ]; then
    ok "skill:${skill} invocation control already set"
  fi
done

# docx, pdf, pptx, xlsx ship with Claude Code and seed on first run
BUNDLED_SKILLS=(docx pdf pptx xlsx)
BUNDLED_MISSING=false
for skill in "${BUNDLED_SKILLS[@]}"; do
  [ ! -d "${CLAUDE_DIR}/skills/${skill}" ] && BUNDLED_MISSING=true && break
done

if $BUNDLED_MISSING; then
  log "Bundled skills (docx/pdf/pptx/xlsx) not yet seeded -- they appear automatically on first 'claude' run"
else
  for skill in "${BUNDLED_SKILLS[@]}"; do
    ok "skill:${skill} present"
  done
fi

# ════════════════════════════════════════════════════════════════
step "7 / blader/humanizer skill"
# ════════════════════════════════════════════════════════════════

HUMANIZER="${CLAUDE_DIR}/skills/humanizer"
if [ -d "$HUMANIZER" ]; then
  log "Updating humanizer..."
  # Stash any local patches (e.g. disable-model-invocation) before pulling,
  # then re-apply them after. This prevents the pull from aborting due to the
  # SKILL.md patch that install.sh injects on every run.
  if ! $DRY_RUN; then
    git -C "$HUMANIZER" stash --quiet 2>/dev/null || true
    git -C "$HUMANIZER" pull --ff-only
    git -C "$HUMANIZER" stash pop --quiet 2>/dev/null || true
  else
    echo -e "${Y}[dry-run]${RESET} git -C '$HUMANIZER' stash && pull --ff-only && stash pop"
  fi
  ok "humanizer updated"
else
  log "Cloning blader/humanizer..."
  run "git clone --depth 1 https://github.com/blader/humanizer.git '$HUMANIZER'"
  ok "humanizer installed"
fi

# Patch humanizer with disable-model-invocation: true if missing
HUMANIZER_MD="${HUMANIZER}/SKILL.md"
if [ -f "$HUMANIZER_MD" ] && ! grep -q "disable-model-invocation" "$HUMANIZER_MD"; then
  if ! $DRY_RUN; then
    python3 -c "
p = '${HUMANIZER}/SKILL.md'
c = open(p).read()
if c.startswith('---'):
    c = c.replace('---\n', '---\ndisable-model-invocation: true\n', 1)
else:
    c = '---\ndisable-model-invocation: true\n---\n' + c
open(p,'w').write(c)
"
    ok "humanizer patched: disable-model-invocation: true"
  fi
elif [ -f "$HUMANIZER_MD" ]; then
  ok "humanizer: invocation control already set"
fi

# ════════════════════════════════════════════════════════════════
step "8 / uipro-cli (ui-ux-pro-max)"
# ════════════════════════════════════════════════════════════════

if command -v uipro &>/dev/null; then
  log "Updating uipro-cli..."
  run "npm update -g uipro-cli"
  ok "uipro-cli updated"
else
  log "Installing uipro-cli globally..."
  run "npm install -g uipro-cli"
  ok "uipro-cli installed"
fi
info "Per-project (disabled by default): cd <project> && uipro init --ai claude"
info "  enable-skill ui-ux-pro-max  to let Claude auto-load it when relevant"

# ════════════════════════════════════════════════════════════════
step "9 / LSP -- language server binaries"
# ════════════════════════════════════════════════════════════════
# ENABLE_LSP_TOOL is already baked into settings.json.
# This adds the shell export as a fallback and installs binaries.

if grep -q "ENABLE_LSP_TOOL" "$SHELL_RC" 2>/dev/null; then
  warn "ENABLE_LSP_TOOL already in $SHELL_RC"
else
  run "echo 'export ENABLE_LSP_TOOL=1  # Claude Code LSP' >> '$SHELL_RC'"
  ok "ENABLE_LSP_TOOL added to $SHELL_RC"
fi

# TypeScript language server
if command -v typescript-language-server &>/dev/null; then
  warn "typescript-language-server already installed"
else
  log "Installing typescript-language-server..."
  run "npm install -g typescript-language-server"
  ok "typescript-language-server installed"
fi

# Pyright (Python)
if command -v pyright &>/dev/null; then
  warn "pyright already installed"
else
  log "Installing pyright..."
  run "pip install pyright --break-system-packages 2>/dev/null || pip install pyright"
  ok "pyright installed"
fi

# gopls (Go) -- only if Go is present
if command -v go &>/dev/null; then
  if command -v gopls &>/dev/null; then
    warn "gopls already installed"
  else
    log "Installing gopls..."
    run "go install golang.org/x/tools/gopls@latest"
    ok "gopls installed"
  fi
else
  info "Go not found -- skipping gopls"
fi

# rust-analyzer -- only if rustup is present
if command -v rustup &>/dev/null; then
  if rustup component list --installed 2>/dev/null | grep -q "rust-analyzer"; then
    warn "rust-analyzer already installed"
  else
    log "Adding rust-analyzer via rustup..."
    run "rustup component add rust-analyzer"
    ok "rust-analyzer added"
  fi
else
  info "rustup not found -- skipping rust-analyzer"
fi

# jdtls (Java) -- eclipse.jdt.ls via Homebrew (macOS) or apt (Linux)
if command -v jdtls &>/dev/null; then
  warn "jdtls already installed"
elif command -v brew &>/dev/null; then
  log "Installing jdtls (Java language server) via Homebrew..."
  run "brew install jdtls"
  ok "jdtls installed"
elif command -v apt-get &>/dev/null; then
  log "Installing jdtls (Java language server) via apt..."
  run "sudo apt-get install -y jdtls 2>/dev/null || true"
  ok "jdtls install attempted via apt"
else
  info "Java LSP (jdtls) not installed -- install manually: brew install jdtls"
  info "  Source: https://github.com/eclipse-jdtls/eclipse.jdt.ls"
fi

# Playwright CLI -- browser automation and visual testing
if command -v playwright-cli &>/dev/null; then
  warn "playwright-cli already installed"
else
  log "Installing @playwright/cli globally..."
  run "npm install -g @playwright/cli@latest"
  ok "@playwright/cli installed"
fi
# Skills and Chromium: always install (idempotent -- safe to re-run)
log "Installing playwright-cli skills..."
run "cd '${HOME}' && playwright-cli install --skills"
ok "playwright-cli skills installed"
log "Installing Chromium for playwright..."
run "playwright install chromium"
ok "Chromium installed"
info "  Usage: playwright-cli open <url>   # record interactions"
info "  Usage: playwright-cli screenshot <url> --output out.png"
info "  Docs:  https://github.com/microsoft/playwright-cli"

# ════════════════════════════════════════════════════════════════
step "9 / MCP servers -- register globally"
# ════════════════════════════════════════════════════════════════
# MCP servers are registered in settings.json (already done via step 3).
# We also run npx gitnexus setup which auto-detects editors and writes
# the global MCP config for Claude Code, Cursor, Windsurf etc in one go.
# Per-repo indexing: cd into any repo and run: npx gitnexus analyze

# GitNexus -- global MCP setup (one-time, covers all repos)
if ! npx -y gitnexus@latest status &>/dev/null || $CLEAN_INSTALL; then
  log "Setting up GitNexus MCP..."
  run "npx -y gitnexus@latest setup 2>/dev/null || true"
  ok "GitNexus MCP configured (per-repo: cd <repo> && npx gitnexus analyze)"
else
  warn "GitNexus MCP already configured"
fi

# Filesystem MCP uses ${HOME} in settings.json -- no patching needed.
# Claude Code expands environment variables in MCP server args natively.
info "Filesystem MCP configured with \${HOME} -- resolves automatically"

info "MCP servers configured in settings.json:"
info "  context7    docs on demand (URL-based, active immediately)"
info "  gitnexus    codebase graph (command-based, per-repo: npx gitnexus analyze)"
info "  filesystem  local file access (command-based, uses \${HOME} automatically)"
info "  vercel      deploy and logs (URL-based)"
info "  supabase    database queries (URL-based)"
info "  claude-mem  session memory (URL-based, active after claude-mem plugin is installed)"

# ════════════════════════════════════════════════════════════════
step "10 / Plugins -- write plugin_commands.sh (manual step)"
# ════════════════════════════════════════════════════════════════
# /plugin commands only work inside an active Claude Code session.
# claude --print silently ignores them -- confirmed closed as not planned:
# github.com/anthropics/claude-code/issues/19522
#
# All commands are written to ~/.claude/plugin_commands.sh.
# Open Claude Code and paste them in to install everything.

if ! $DRY_RUN; then
  cat > "${CLAUDE_DIR}/plugin_commands.sh" <<'PLUGINCMDS'
# ~/.claude/plugin_commands.sh
# Paste these inside an active Claude Code session. Order matters.

# Add marketplaces first
/plugin marketplace add anthropics/skills
/plugin marketplace add mksglu/claude-context-mode
/plugin marketplace add Piebald-AI/claude-code-lsps
/plugin marketplace add thedotmack/claude-mem
/plugin marketplace add kepano/obsidian-skills
/plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill

# Official (anthropics/claude-plugins-official)
/plugin install ralph-loop@claude-plugins-official
/plugin install code-review@claude-plugins-official
/plugin install hookify@claude-plugins-official
/plugin install feature-dev@claude-plugins-official
/plugin install pr-review-toolkit@claude-plugins-official
/plugin install superpowers@claude-plugins-official
/plugin install claude-md-management@claude-plugins-official
/plugin install claude-code-setup@claude-plugins-official

# Community
/plugin install context-mode@context-mode
/plugin install claude-mem@thedotmack
/plugin install obsidian@obsidian-skills
/plugin install ui-ux-pro-max@ui-ux-pro-max-skill

# LSP -- official marketplace (claude-plugins-official)
/plugin install typescript-lsp@claude-plugins-official
/plugin install pyright-lsp@claude-plugins-official
/plugin install gopls-lsp@claude-plugins-official
/plugin install rust-analyzer-lsp@claude-plugins-official
/plugin install jdtls-lsp@claude-plugins-official

# LSP -- community marketplace (Piebald-AI) as fallback if official not available
# /plugin marketplace add Piebald-AI/claude-code-lsps
# /plugin install vtsls@claude-code-lsps
PLUGINCMDS
fi
ok "plugin_commands.sh written to ~/.claude/"
info "Open Claude Code and paste: cat ~/.claude/plugin_commands.sh"

# ════════════════════════════════════════════════════════════════
step "11 / ~/.claude-work -- structure and templates"
# ════════════════════════════════════════════════════════════════

mkdir -p "${WORK_DIR}/skills" "${WORK_DIR}/commands" "${WORK_DIR}/context" "${WORK_DIR}/backups"
ok "~/.claude-work structure ready"

# Only seed CLAUDE.md if one wasn't already synced from backup in step 1
if [ ! -f "${WORK_DIR}/CLAUDE.md" ]; then
  if ! $DRY_RUN; then
    cat > "${WORK_DIR}/CLAUDE.md" <<'WORKMD'
# Private / Work Context

> **On demand only** — not loaded by default.
> Launch with: `cw` or `claude --add-dir ~/.claude-work`
> To go without it: exit and run plain `claude`.

---

## Preferences
<!-- Personal preferences beyond ~/.claude/CLAUDE.md.
     Examples: tone, verbosity, preferred libraries, review style. -->

## Environment Notes
<!-- Internal tooling, deployment targets, credentials locations, access patterns. -->
WORKMD
  fi
  ok "~/.claude-work/CLAUDE.md created (seeded from template)"
else
  warn "~/.claude-work/CLAUDE.md already present (from backup sync or prior run)"
fi

if [ ! -f "${WORK_DIR}/context/README.md" ]; then
  if ! $DRY_RUN; then
    cat > "${WORK_DIR}/context/README.md" <<'CTXMD'
# Context Files

Drop architecture docs, runbooks, and reference material here.
Claude reads these when ~/.claude-work is loaded.

Suggested files:
  architecture.md   system design and service map
  conventions.md    coding standards and patterns
  tooling.md        internal tools and workflows
  decisions.md      architectural decisions (ADRs)
CTXMD
  fi
  ok "~/.claude-work/context/README.md created"
fi

# ════════════════════════════════════════════════════════════════
step "12 / Cleanup -- remove stale launchd switchback job (v1 artifact)"
# ════════════════════════════════════════════════════════════════
_stale_plist="${HOME}/Library/LaunchAgents/com.claude.switchback.plist"
if [ -f "$_stale_plist" ]; then
  run "launchctl bootout 'gui/$(id -u)' '$_stale_plist' 2>/dev/null || true"
  run "rm -f '$_stale_plist'"
  ok "Removed stale launchd switchback plist"
else
  info "No stale launchd switchback plist found -- skipping"
fi

# ════════════════════════════════════════════════════════════════
step "13 / Shell aliases and functions -- ${SHELL_RC}" # (was 12)
# ════════════════════════════════════════════════════════════════

# On --update or default run, remove the old managed block and rewrite it
if grep -q "claude-local-starter managed" "$SHELL_RC" 2>/dev/null; then
  python3 - <<PYEOF
import re, os
path = os.path.expanduser("${SHELL_RC}")
with open(path) as f:
    content = f.read()
content = re.sub(
    r'\n# ── claude-local-starter managed.*?# ── end claude-local-starter ──\n',
    '',
    content,
    flags=re.DOTALL
)
with open(path, "w") as f:
    f.write(content)
PYEOF
  info "Old alias block removed -- rewriting"
fi

if ! $DRY_RUN; then
  cat >> "$SHELL_RC" <<'ZSHBLOCK'

# ── claude-local-starter managed ─────────────────────────────────────
# Auto-generated by install.sh -- re-run install.sh to regenerate.

# ~/.claude on PATH -- gives direct access to enable-safe-yolo and any other scripts there
export PATH="${HOME}/.claude:${PATH}"

# Load private context on demand (per-session -- exit and run 'claude' to go without it)
alias cw="claude --add-dir ~/.claude-work"
alias claude-work="claude --add-dir ~/.claude-work"

# ── Skill toggles (via disable-model-invocation frontmatter) ─────────
# enable-skill <n>  -> disable-model-invocation: false (Claude auto-loads when relevant)
# disable-skill <n> -> disable-model-invocation: true  (user-invocable only, zero tokens)

_find_skill_md() {
  local name="$1"
  for base in "${HOME}/.claude/skills" "${HOME}/.claude-work/skills"; do
    [ -f "${base}/${name}/SKILL.md" ] && echo "${base}/${name}/SKILL.md" && return
  done
}

enable-skill() {
  local name="$1"
  local p
  p="$(_find_skill_md "$name")"
  if [ -z "$p" ]; then
    echo "skill:${name} not found in ~/.claude/skills/ or ~/.claude-work/skills/"
    return 1
  fi
  python3 -c "
p = '$p'
c = open(p).read()
if 'disable-model-invocation: false' in c:
    print('skill:$name is already enabled')
elif 'disable-model-invocation: true' in c:
    open(p,'w').write(c.replace('disable-model-invocation: true','disable-model-invocation: false'))
    print('ENABLED: skill:$name (Claude will auto-load when relevant)')
else:
    open(p,'w').write(c.replace('---\n','---\ndisable-model-invocation: false\n',1))
    print('ENABLED: skill:$name (field added)')
"
}

disable-skill() {
  local name="$1"
  local p
  p="$(_find_skill_md "$name")"
  if [ -z "$p" ]; then
    echo "skill:${name} not found in ~/.claude/skills/ or ~/.claude-work/skills/"
    return 1
  fi
  python3 -c "
p = '$p'
c = open(p).read()
if 'disable-model-invocation: true' in c:
    print('skill:$name is already disabled')
elif 'disable-model-invocation: false' in c:
    open(p,'w').write(c.replace('disable-model-invocation: false','disable-model-invocation: true'))
    print('DISABLED: skill:$name (user-invocable via /$name, zero token cost)')
else:
    open(p,'w').write(c.replace('---\n','---\ndisable-model-invocation: true\n',1))
    print('DISABLED: skill:$name (field added)')
"
}

list-skills() {
  local primary="${HOME}/.claude/skills"
  local work="${HOME}/.claude-work/skills"
  local skill_dir name smd state

  # Primary skills
  if [ -d "$primary" ]; then
    echo "── ${primary}/"
    for skill_dir in "$primary"/*/; do
      [ -d "$skill_dir" ] || continue
      name="${skill_dir%/}"; name="${name##*/}"
      smd="${skill_dir}SKILL.md"
      { [ -f "$smd" ] && grep -q "disable-model-invocation: true" "$smd" 2>/dev/null; } \
        && state="[context-off]" || state="[context-on]"
      printf "  %-32s %s\n" "$name" "$state"
    done
  fi

  # Work-exclusive skills only (skip anything already in primary)
  if [ -d "$work" ]; then
    local printed_header=false
    for skill_dir in "$work"/*/; do
      [ -d "$skill_dir" ] || continue
      name="${skill_dir%/}"; name="${name##*/}"
      [ -d "${primary}/${name}" ] && continue
      $printed_header || { echo "── ${work}/"; printed_header=true; }
      smd="${skill_dir}SKILL.md"
      { [ -f "$smd" ] && grep -q "disable-model-invocation: true" "$smd" 2>/dev/null; } \
        && state="[context-off]" || state="[context-on]"
      printf "  %-32s %s\n" "$name" "$state"
    done
  fi
}

# ── Plugin toggles (via settings.json enabledPlugins) ────────────────
# pyright-lsp stays true by default; other LSPs default false (enable per-project with enable-plugin).
# Restart Claude Code or /reload-plugins after toggling.

_find_plugin_key() {
  local name="$1"
  python3 -c "
import json
data = json.load(open('${HOME}/.claude/settings.json'))
plugins = data.get('enabledPlugins', {})
match = next((k for k in plugins if k.startswith('$name') or k == '$name'), None)
print(match or '')
"
}

enable-plugin() {
  local name="$1"
  python3 -c "
import json, sys
path = '${HOME}/.claude/settings.json'
data = json.load(open(path))
plugins = data.get('enabledPlugins', {})
match = next((k for k in plugins if k.startswith('$name') or k == '$name'), None)
if not match:
    print('plugin:$name not found in settings.json')
    sys.exit(1)
if plugins[match]:
    print('plugin:' + match + ' is already enabled')
else:
    plugins[match] = True
    data['enabledPlugins'] = plugins
    json.dump(data, open(path,'w'), indent=2)
    print('ENABLED: ' + match)
    print('Restart Claude Code (or /reload-plugins) to apply.')
"
}

disable-plugin() {
  local name="$1"
  python3 -c "
import json, sys
path = '${HOME}/.claude/settings.json'
data = json.load(open(path))
plugins = data.get('enabledPlugins', {})
match = next((k for k in plugins if k.startswith('$name') or k == '$name'), None)
if not match:
    print('plugin:$name not found in settings.json')
    sys.exit(1)
if not plugins[match]:
    print('plugin:' + match + ' is already disabled')
else:
    plugins[match] = False
    data['enabledPlugins'] = plugins
    json.dump(data, open(path,'w'), indent=2)
    print('DISABLED: ' + match)
    print('Restart Claude Code (or /reload-plugins) to apply.')
"
}

list-plugins() {
  python3 -c "
import json
data = json.load(open('${HOME}/.claude/settings.json'))
plugins = data.get('enabledPlugins', {})
print('── ~/.claude/settings.json')
for k, v in sorted(plugins.items()):
    state = 'enabled ' if v else 'disabled'
    print(f'  {k:<50} [{state}]')
"
}

list-commands() {
  for base in "${HOME}/.claude/commands" "${HOME}/.claude-work/commands"; do
    [ -d "$base" ] || continue
    echo "── ${base}/"
    ls -1 "$base" 2>/dev/null | while read -r s; do
      printf "  %s\n" "$s"
    done
  done
}

# ── MCP server toggles (via settings.json mcpServers[name].disabled) ─────────
# Restart Claude Code after toggling.

enable-mcp() {
  local name="$1"
  python3 -c "
import json, sys
path = '${HOME}/.claude/settings.json'
data = json.load(open(path))
servers = data.get('mcpServers', {})
if '$name' not in servers:
    print('mcp:$name not found in settings.json')
    sys.exit(1)
if not servers['$name'].get('disabled', False):
    print('mcp:$name is already enabled')
else:
    servers['$name'].pop('disabled', None)
    data['mcpServers'] = servers
    json.dump(data, open(path,'w'), indent=2)
    print('ENABLED: mcp:$name')
    print('Restart Claude Code to apply.')
"
}

disable-mcp() {
  local name="$1"
  python3 -c "
import json, sys
path = '${HOME}/.claude/settings.json'
data = json.load(open(path))
servers = data.get('mcpServers', {})
if '$name' not in servers:
    print('mcp:$name not found in settings.json')
    sys.exit(1)
if servers['$name'].get('disabled', False):
    print('mcp:$name is already disabled')
else:
    servers['$name']['disabled'] = True
    data['mcpServers'] = servers
    json.dump(data, open(path,'w'), indent=2)
    print('DISABLED: mcp:$name')
    print('Restart Claude Code to apply.')
"
}

list-mcps() {
  python3 -c "
import json
data = json.load(open('${HOME}/.claude/settings.json'))
servers = data.get('mcpServers', {})
print('── ~/.claude/settings.json')
for k, v in sorted(servers.items()):
    state = 'disabled' if v.get('disabled') else 'enabled '
    kind  = v.get('type', 'command')
    print(f'  {k:<25} [{state}]  ({kind})')
"
}

# ── Ollama routing — limit-triggered auto-switchover ─────────────────

_claude_notify() {
  local msg="$1" title="${2:-Claude Code}"
  if command -v osascript &>/dev/null; then
    osascript -e 'display notification "'"$msg"'" with title "'"$title"'"' 2>/dev/null || true
  elif command -v notify-send &>/dev/null; then
    notify-send "$title" "$msg" 2>/dev/null || true
  fi
  echo "$title: $msg"
}

_claude_pick_model() {
  local conf="$HOME/.claude/ollama.conf"
  local default_model="kimi-k2.5:cloud"
  [ -f "$conf" ] && { source "$conf" 2>/dev/null; default_model="${OLLAMA_DEFAULT_MODEL:-$default_model}"; }

  local saved_model
  saved_model=$(cat "$HOME/.claude/.ollama-model" 2>/dev/null | tr -d '[:space:]')
  local chosen_model="${saved_model:-$default_model}"

  if [ -t 0 ] && [ -t 1 ] && command -v ollama &>/dev/null; then
    local models=()
    while IFS= read -r line; do
      models+=("$line")
    done < <(ollama list 2>/dev/null | awk 'NR>1 {print $1}')

    if [ "${#models[@]}" -gt 0 ]; then
      echo ""
      echo "Ollama models available:"
      local i=1
      for m in "${models[@]}"; do
        [ "$m" = "$chosen_model" ] && echo "  $i) $m  ← default" || echo "  $i) $m"
        (( i++ ))
      done
      echo ""
      read -r -p "Select model [Enter = $chosen_model]: " selection || selection=""
      if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#models[@]}" ]; then
        # Walk array with counter — portable across bash (0-indexed) and zsh (1-indexed)
        local _idx=1
        for _m in "${models[@]}"; do
          if [ "$_idx" -eq "$selection" ]; then chosen_model="$_m"; break; fi
          (( _idx++ ))
        done
      fi
      echo "$chosen_model" > "$HOME/.claude/.ollama-model"
    fi
  fi
  export OLLAMA_MODEL="$chosen_model"
}

claude() {
  local override="$HOME/.claude/.ollama-override"
  local reset_file="$HOME/.claude/.ollama-reset-time"
  local registry="$HOME/.claude/.active-projects"
  local conf="$HOME/.claude/ollama.conf"
  local ollama_host="http://localhost:11434"
  [ -f "$conf" ] && { source "$conf" 2>/dev/null; ollama_host="${OLLAMA_HOST:-$ollama_host}"; }

  if [ -f "$override" ]; then
    local reset_epoch now_epoch reset_human manual_flag
    reset_epoch=""
    manual_flag="$HOME/.claude/.ollama-manual"
    [ -f "$reset_file" ] && reset_epoch=$(cat "$reset_file" 2>/dev/null | tr -d '[:space:]')
    now_epoch=$(date '+%s')

    local override_age=0
    override_age=$(( now_epoch - $(date -r "$override" '+%s' 2>/dev/null || echo "$now_epoch") ))

    # Auto-cleanup if: reset time passed (valid epoch),
    # OR no reset time AND override is >5 hours old AND switch was automatic (no manual flag)
    if { [[ "$reset_epoch" =~ ^[0-9]+$ ]] && (( now_epoch >= reset_epoch )); } || \
       { [[ -z "$reset_epoch" ]] && (( override_age > 18000 )) && [[ ! -f "$manual_flag" ]]; }; then
      # Limit has cleared — clean up automatically, no prompt needed
      if [[ "$reset_epoch" =~ ^[0-9]+$ ]]; then
        reset_human=$(date -r "$reset_epoch" '+%H:%M' 2>/dev/null \
          || date -d "@$reset_epoch" '+%H:%M' 2>/dev/null \
          || echo "epoch $reset_epoch")
        echo "Anthropic limit reset (was due: $reset_human). Switching back automatically."
      else
        echo "Ollama override is over 5 hours old with no reset time. Switching back automatically."
      fi
      rm -f "$override" "$reset_file" "$HOME/.claude/.pre-switchback" "$manual_flag"
      if [ -f "$registry" ]; then
        local tmp; tmp=$(mktemp) || return 0
        grep -vxF "$PWD" "$registry" > "$tmp" 2>/dev/null && mv "$tmp" "$registry" || rm -f "$tmp"
      fi
      unset ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN OLLAMA_MODEL
      command claude --add-dir ~/.claude-work "$@"
      return
    fi

    # Override still active — tell the user and ask before doing anything
    if [[ "$reset_epoch" =~ ^[0-9]+$ ]]; then
      reset_human=$(date -r "$reset_epoch" '+%H:%M' 2>/dev/null \
        || date -d "@$reset_epoch" '+%H:%M' 2>/dev/null \
        || echo "epoch $reset_epoch")
      echo "Ollama override active (Anthropic limit resets at $reset_human)."
    else
      echo "Ollama override active (no reset time recorded)."
    fi
    printf "yes(Y) use Ollama  /  reset(r) switch back to Anthropic: "
    read -r _route_ans
    if [[ "$_route_ans" =~ ^[Rr] ]]; then
      rm -f "$override" "$reset_file" "$HOME/.claude/.pre-switchback" "$manual_flag"
      if [ -f "$registry" ]; then
        local tmp; tmp=$(mktemp) || return 0
        grep -vxF "$PWD" "$registry" > "$tmp" 2>/dev/null && mv "$tmp" "$registry" || rm -f "$tmp"
      fi
      unset ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN OLLAMA_MODEL
      echo "Switched back to Anthropic."
      command claude --add-dir ~/.claude-work "$@"
      return
    fi

    if ! curl -sf "${ollama_host}/api/tags" >/dev/null 2>&1; then
      echo "Ollama is not running at ${ollama_host}. Start it with: ollama serve"
      echo "Aborted. Start Ollama, or type 'r' on next launch to switch back to Anthropic."
      return 1
    fi

    # shellcheck disable=SC1090
    source "$override" || { echo "Failed to load Ollama override — check ~/.claude/.ollama-override"; return 1; }
    _claude_pick_model
    echo "Routing to Ollama ($OLLAMA_MODEL)"
    command claude --add-dir ~/.claude-work "$@"

  else
    if [ -f "$registry" ]; then
      local tmp; tmp=$(mktemp) || return 0
      grep -vxF "$PWD" "$registry" > "$tmp" 2>/dev/null && mv "$tmp" "$registry" || rm -f "$tmp"
    fi
    command claude --add-dir ~/.claude-work "$@"
  fi
}

switch-back() {
  unset ANTHROPIC_BASE_URL
  unset ANTHROPIC_AUTH_TOKEN
  unset OLLAMA_MODEL

  local key_backup="$HOME/.claude/.ollama-anthropic-key-backup"
  local api_key=""

  if [ -f "$key_backup" ]; then
    api_key=$(cat "$key_backup" 2>/dev/null | tr -d '[:space:]')
    rm -f "$key_backup"
  fi

  # Path 2: Linux / cross-platform — Claude Code native credential store
  if [ -z "$api_key" ] && [ -f "$HOME/.claude/.credentials" ]; then
    api_key=$(python3 -c "
import json, os, sys
p = os.path.join(os.path.expanduser('~'), '.claude', '.credentials')
try:
    d = json.load(open(p))
    k = d.get('anthropicApiKey', '') or d.get('apiKey', '')
    print(k.strip() if k else '')
except Exception:
    pass
" 2>/dev/null) || api_key=""
  fi

  if [ -z "$api_key" ] && command -v security &>/dev/null; then
    api_key=$(security find-generic-password -a claude -s "Claude API Key" -w 2>/dev/null || echo "")
  fi

  if [ -n "$api_key" ]; then
    export ANTHROPIC_API_KEY="$api_key"
    echo "ANTHROPIC_API_KEY restored."
  else
    echo "Could not restore API key automatically."
    echo "Set manually: export ANTHROPIC_API_KEY='sk-ant-...'"
    echo "See KNOWN-ISSUES.md -- 'API key restoration on Linux' for details."
  fi

  rm -f "$HOME/.claude/.ollama-override" \
        "$HOME/.claude/.ollama-reset-time" \
        "$HOME/.claude/.pre-switchback" \
        "$HOME/.claude/.ollama-manual"

  local registry="$HOME/.claude/.active-projects"
  if [ -f "$registry" ]; then
    local tmp; tmp=$(mktemp) || return 0
    grep -vxF "$PWD" "$registry" > "$tmp" 2>/dev/null && mv "$tmp" "$registry" || rm -f "$tmp"
  fi

  _claude_notify "Switched back to Anthropic manually." "Claude Code"
  echo "Ready. Run: claude"
}

# ── end claude-local-starter ──
ZSHBLOCK
fi
ok "Shell functions written to $SHELL_RC"

# ════════════════════════════════════════════════════════════════
step "14 / Sync repo artefacts -> ~/.claude"
# ════════════════════════════════════════════════════════════════

HTML_SRC="${SCRIPT_DIR}/claude-local-starter.html"
[ -f "$HTML_SRC" ] && {
  run "cp '$HTML_SRC' '${CLAUDE_DIR}/claude-local-starter.html'"
  ok "claude-local-starter.html -> ~/.claude/"
  # Inject settings.json + CLAUDE.md content into dashboard
  INSTALLED_HTML="${CLAUDE_DIR}/claude-local-starter.html"
  if [ -f "${CLAUDE_DIR}/settings.json" ] && [ -f "${CLAUDE_DIR}/CLAUDE.md" ]; then
    inject_err=$(python3 - 2>&1 <<PYEOF
import json, os, sys
claude_dir = os.path.expanduser("~/.claude")
html_path  = os.path.join(claude_dir, "claude-local-starter.html")
settings_path = os.path.join(claude_dir, "settings.json")
claude_md_path = os.path.join(claude_dir, "CLAUDE.md")
try:
    with open(html_path) as f:  html = f.read()
    with open(settings_path) as f:  settings = json.load(f)
    with open(claude_md_path) as f:  claude_md = f.read()
    html = html.replace('"__SETTINGS_JSON_PLACEHOLDER__"', json.dumps(settings))
    html = html.replace('"__CLAUDE_MD_PLACEHOLDER__"',     json.dumps(claude_md))
    with open(html_path, "w") as f:  f.write(html)
    print("  settings.json + CLAUDE.md embedded into dashboard")
except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(1)
PYEOF
)
    inject_exit=$?
    if [ $inject_exit -eq 0 ]; then
      ok "Dashboard content injected"
    else
      warn "Dashboard content injection failed: ${inject_err}"
      warn "Dashboard will show placeholder content — file still copied to ~/.claude/"
    fi
  else
    warn "settings.json or CLAUDE.md not found — dashboard viewers will show placeholder"
  fi
} || warn "claude-local-starter.html not found in repo"

# Sync yolo tools: permissions file + enable-safe-yolo.sh + disable-safe-yolo.sh
YOLO_PERMS="${SCRIPT_DIR}/scripts/config/claude-safe-yolo-permissions.txt"
YOLO_ENABLE="${SCRIPT_DIR}/scripts/enable-safe-yolo.sh"
YOLO_DISABLE="${SCRIPT_DIR}/scripts/disable-safe-yolo.sh"

if [ -f "$YOLO_PERMS" ]; then
  run "cp '$YOLO_PERMS' '${CLAUDE_DIR}/claude-safe-yolo-permissions.txt'"
  ok "claude-safe-yolo-permissions.txt -> ~/.claude/"
else
  warn "claude-safe-yolo-permissions.txt not found in repo -- skipping"
fi

for script in "$YOLO_ENABLE" "$YOLO_DISABLE"; do
  name="$(basename "$script")"
  if [ -f "$script" ]; then
    run "cp '$script' '${CLAUDE_DIR}/${name}'"
    run "chmod +x '${CLAUDE_DIR}/${name}'"
    ok "${name} -> ~/.claude/  (available as '${name%.sh}' after shell reload)"
  else
    warn "${name} not found in repo -- skipping"
  fi
done

# Sync commands/ from repo into ~/.claude/commands/
# Merges repo commands into existing -- no overwrites of user-added commands
CMD_SRC="${SCRIPT_DIR}/commands"
if [ -d "$CMD_SRC" ]; then
  run "mkdir -p '${CLAUDE_DIR}/commands'"
  run "cp -rn '$CMD_SRC/.' '${CLAUDE_DIR}/commands/' || true"  # -n: no overwrite; || true: existing files return non-zero on macOS
  ok "commands/ synced -> ~/.claude/commands/"
  info "  $(ls -1 "$CMD_SRC" 2>/dev/null | wc -l | tr -d ' ') command(s) available"
else
  warn "No commands/ directory in repo"
fi

# Sync skills/ from repo into ~/.claude/skills/
# Community skills are installed disabled by default (see step 5)
# Repo skills go in enabled by default since they are project-specific
SKILLS_SRC="${SCRIPT_DIR}/skills"
if [ -d "$SKILLS_SRC" ] && [ "$(ls -A "$SKILLS_SRC" 2>/dev/null)" ]; then
  run "mkdir -p '${CLAUDE_DIR}/skills'"
  run "cp -rn '$SKILLS_SRC/.' '${CLAUDE_DIR}/skills/' || true"  # -n: no overwrite; || true: existing files return non-zero on macOS
  ok "skills/ synced -> ~/.claude/skills/"
  info "  $(ls -1 "$SKILLS_SRC" 2>/dev/null | wc -l | tr -d ' ') skill(s) available"
else
  info "No custom skills in repo skills/ directory -- add SKILL.md files there to distribute"
fi

# Deploy hook scripts to ~/.claude/scripts/
run "mkdir -p '${CLAUDE_DIR}/scripts'"
for _script in limit-watchdog.sh aidlc-guard.sh switch-to-anthropic.sh switch-to-ollama.sh claudeignore-guard.sh; do
  _src="${SCRIPT_DIR}/scripts/${_script}"
  if [ -f "$_src" ]; then
    run "cp '$_src' '${CLAUDE_DIR}/scripts/${_script}'"
    run "chmod +x '${CLAUDE_DIR}/scripts/${_script}'"
    ok "${_script} -> ~/.claude/scripts/"
  else
    warn "${_script} not found in repo/scripts/ -- skipping"
  fi
done

# Deploy ollama.conf — only if not already present (user customisations survive re-runs)
_ollama_conf_src="${SCRIPT_DIR}/ollama.conf"
_ollama_conf_dst="${CLAUDE_DIR}/ollama.conf"
if [ -f "$_ollama_conf_src" ]; then
  if [ ! -f "$_ollama_conf_dst" ]; then
    run "cp '$_ollama_conf_src' '$_ollama_conf_dst'"
    ok "ollama.conf -> ~/.claude/  (first install only)"
  else
    info "ollama.conf already exists at ~/.claude/ -- skipping (user customisations preserved)"
  fi
fi

# Deploy default .claudeignore — only if not already present
_claudeignore_dst="${CLAUDE_DIR}/.claudeignore"
if [ ! -f "$_claudeignore_dst" ]; then
  if ! $DRY_RUN; then
    cat > "$_claudeignore_dst" <<'CLAUDEIGNORE'
# ~/.claude/.claudeignore — files Claude will never read or edit
# Syntax: one pattern per line, gitignore-style basename or path matching
# Comments start with #. Add a .claudeignore in any repo root for project-specific rules.

# Environment / secrets
.env
.env.*
.envrc
*.secret

# Private keys and certificates
*.pem
*.key
*.p12
*.pfx
id_rsa
id_ed25519
id_ecdsa
*.ppk

# Cloud credentials
.aws/credentials
.aws/config
gcloud/credentials.db
service-account*.json

# Application credential files
*credentials*
*secrets*
.htpasswd
.netrc
CLAUDEIGNORE
    ok ".claudeignore -> ~/.claude/  (default sensitive-file protection)"
  else
    echo -e "${Y}[dry-run]${RESET} Would write default ~/.claude/.claudeignore"
  fi
else
  info ".claudeignore already exists at ~/.claude/ -- skipping"
fi

SCRIPT_DST="${CLAUDE_DIR}/install.sh"
SCRIPT_ABS="${SCRIPT_DIR}/install.sh"
[ "$SCRIPT_ABS" != "$SCRIPT_DST" ] && {
  run "cp '$SCRIPT_ABS' '$SCRIPT_DST'"
  run "chmod +x '$SCRIPT_DST'"
  ok "install.sh -> ~/.claude/"
}

# ════════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}  Done.${RESET}"
echo ""

if $CLEAN_INSTALL && [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
  echo -e "${G}  Backup:${RESET}"
  echo "    Dated  : ${BACKUP_DIR}"
  echo "    Live   : ${WORK_DIR}  (load with: cw)"
  echo ""
fi

echo -e "${Y}  Skills: all installed with disable-model-invocation: true (zero token cost)${RESET}"
echo "    enable-skill <n>   # let Claude auto-load it when relevant"
echo "    disable-skill <n>  # user-invocable only, zero token cost"
echo "    list-skills        # see all skills + context state"
echo "    list-plugins       # see all plugins + enabled state"
echo "    list-mcps          # see all MCP servers + enabled state"
echo "    enable-mcp <n>     # enable an MCP server in Claude Code"
echo "    disable-mcp <n>    # disable an MCP server in Claude Code"
echo "    list-commands      # see all slash commands"
echo ""
echo -e "${Y}  Plugins (restart Claude Code or /reload-plugins after toggling):${RESET}"
echo "    enable-plugin superpowers  # example: enable a plugin"
echo "    disable-plugin superpowers # example: disable a plugin"
echo ""
echo -e "${Y}  Safe-yolo mode (auto-approve tools in a specific repo):${RESET}"
echo "    enable-safe-yolo                        # run inside a repo to enable"
echo "    enable-safe-yolo --dir=PATH             # or pass a path explicitly"
echo "    enable-safe-yolo --dry-run              # preview what would be written"
echo "    disable-safe-yolo                       # remove permissions block from repo"
echo "    disable-safe-yolo --dir=PATH            # or pass a path explicitly"
echo "    Edit: ~/.claude/claude-safe-yolo-permissions.txt  # to change allowed tools"
echo ""
echo -e "${Y}  Per-project (run inside each project directory):${RESET}"
echo "    npx skills add shadcn/ui            # shadcn/ui projects"
echo "    npx shadcn@latest init              # init shadcn/ui in the project"
echo "    npx gitnexus analyze --skills       # repos you want graphed"
echo "    uipro init --ai claude              # ui-ux-pro-max per project"
echo ""
echo -e "${Y}  Plugins -- manual install inside Claude Code:${RESET}"
echo "    cat ~/.claude/plugin_commands.sh   # see all commands"
echo "    Then open Claude Code and paste them one by one."
echo ""
echo -e "${G}  Reload shell, then:${RESET}"
echo "    source ${SHELL_RC}"
echo "    cw                 # load ~/.claude-work context"
echo "    list-skills        # see skills + context state"
echo ""

_html_file="${HOME}/.claude/claude-local-starter.html"
if [ -f "$_html_file" ]; then
  echo -e "${Y}════════════════════════════════════════════════${RESET}"
  echo -e "${G}  Dashboard — open this file to view your setup:${RESET}"
  echo ""
  echo "    open $_html_file"
  echo ""
  echo -e "${Y}  (Always open the installed copy above — not the repo source file)${RESET}"
  echo -e "${Y}════════════════════════════════════════════════${RESET}"
  echo ""
else
  warn "Dashboard URL skipped — file not found at: $_html_file"
fi
