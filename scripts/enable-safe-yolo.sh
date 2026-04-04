#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  enable-safe-yolo.sh
#
#  Merges permissions from ~/.claude/claude-safe-yolo-permissions.txt into
#  .claude/settings.json in the target directory.
#
#  IDEMPOTENT: only ADDS entries not already present. Any permissions manually
#  added to .claude/settings.json are left completely untouched.
#
#  File format:
#    Tool(*)           → added to permissions.allow
#    Bash(cmd *)       → added to permissions.allow
#    !Bash(cmd *)      → added to permissions.deny (leading ! = deny)
#    @defaultMode=VAL  → sets permissions.defaultMode (e.g. acceptEdits)
#    # comment         → ignored
#    blank lines       → ignored
#
#  Usage:
#    enable-safe-yolo                  # target = current working directory
#    enable-safe-yolo --dir=PATH       # target = PATH
#    enable-safe-yolo --dry-run        # preview, no changes
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

G='\033[0;32m' Y='\033[1;33m' R='\033[0;31m' C='\033[0;36m' RESET='\033[0m'
ok()   { echo -e "${G}[ok]${RESET}    $*"; }
warn() { echo -e "${Y}[warn]${RESET}  $*"; }
err()  { echo -e "${R}[error]${RESET} $*" >&2; }
info() { echo -e "${C}[info]${RESET}  $*"; }

# ── Args ──────────────────────────────────────────────────────────────────────
TARGET_DIR="$(pwd)"
DRY_RUN=false
YES=false

for arg in "$@"; do
  case "$arg" in
    --dir=*)        TARGET_DIR="${arg#--dir=}" ;;
    --dry-run)      DRY_RUN=true ;;
    --yes|-y)       YES=true ;;
    -h|--help)
      echo "Usage: enable-safe-yolo [--dir=PATH] [--dry-run] [--yes|-y]"
      echo "  --dir=PATH   Target repo directory (default: current working directory)"
      echo "  --dry-run    Preview what would be written, no changes"
      echo "  --yes / -y   Skip confirmation prompt (for scripted/Claude session use)"
      exit 0 ;;
    *) err "Unknown argument: $arg"; exit 1 ;;
  esac
done

TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

PERMS_FILE="${HOME}/.claude/claude-safe-yolo-permissions.txt"
if [ ! -f "$PERMS_FILE" ]; then
  err "Permissions file not found: $PERMS_FILE"
  err "Run install.sh first, or copy claude-safe-yolo-permissions.txt to ~/.claude/"
  exit 1
fi

SETTINGS_FILE="${TARGET_DIR}/.claude/settings.json"

# ── Parse permissions file into two temp files ────────────────────────────────
ALLOW_TMP="$(mktemp)"
DENY_TMP="$(mktemp)"
DEFAULT_MODE_VAL=""

while IFS= read -r line; do
  # strip leading/trailing whitespace
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  [[ -z "$line" || "$line" == \#* ]] && continue
  if [[ "$line" == \!* ]]; then
    echo "${line#!}" >> "$DENY_TMP"
  elif [[ "$line" == @defaultMode=* ]]; then
    DEFAULT_MODE_VAL="${line#@defaultMode=}"
  else
    echo "$line" >> "$ALLOW_TMP"
  fi
done < "$PERMS_FILE"

ALLOW_COUNT=$(wc -l < "$ALLOW_TMP" | tr -d ' ')
DENY_COUNT=$(wc -l < "$DENY_TMP" | tr -d ' ')

# ── Merge into settings.json via python3 ─────────────────────────────────────
RESULT="$(python3 - "$SETTINGS_FILE" "$ALLOW_TMP" "$DENY_TMP" "$DEFAULT_MODE_VAL" <<'PYEOF'
import json, sys, os

settings_path    = sys.argv[1]
allow_file       = sys.argv[2]
deny_file        = sys.argv[3]
default_mode_val = sys.argv[4]

with open(allow_file) as f:
    new_allow = [l.strip() for l in f if l.strip()]
with open(deny_file) as f:
    new_deny  = [l.strip() for l in f if l.strip()]

data = {}
if os.path.exists(settings_path):
    with open(settings_path) as f:
        data = json.load(f)

data.setdefault("permissions", {})
existing_allow = data["permissions"].get("allow", [])
existing_deny  = data["permissions"].get("deny",  [])

# Merge: add only entries not already present (idempotent)
existing_allow_set = set(existing_allow)
existing_deny_set  = set(existing_deny)

added_allow = [e for e in new_allow if e not in existing_allow_set]
added_deny  = [e for e in new_deny  if e not in existing_deny_set]

data["permissions"]["allow"] = existing_allow + added_allow
if new_deny:
    data["permissions"]["deny"] = existing_deny + added_deny

# Handle defaultMode
mode_added   = False
mode_skipped = False
mode_changed = False
if default_mode_val:
    existing_mode = data["permissions"].get("defaultMode")
    if existing_mode == default_mode_val:
        mode_skipped = True
    elif existing_mode and existing_mode != default_mode_val:
        data["permissions"]["defaultMode"] = default_mode_val
        mode_changed = True  # was set to something different — log clearly
    else:
        data["permissions"]["defaultMode"] = default_mode_val
        mode_added = True

# Clean up empty permissions key
if not data["permissions"].get("allow"):
    data["permissions"].pop("allow", None)
if not data["permissions"].get("deny"):
    data["permissions"].pop("deny", None)
if not data["permissions"]:
    data.pop("permissions", None)

result = {
    "json":          json.dumps(data, indent=2),
    "added_allow":   added_allow,
    "added_deny":    added_deny,
    "skipped_allow": len(new_allow) - len(added_allow),
    "skipped_deny":  len(new_deny)  - len(added_deny),
    "mode_added":    mode_added,
    "mode_skipped":  mode_skipped,
    "mode_changed":  mode_changed,
    "default_mode":  default_mode_val,
}
print(json.dumps(result))
PYEOF
)"

rm -f "$ALLOW_TMP" "$DENY_TMP"

FINAL_JSON="$(echo "$RESULT"    | python3 -c "import json,sys; print(json.load(sys.stdin)['json'])")"
ADDED_ALLOW="$(echo "$RESULT"   | python3 -c "import json,sys; d=json.load(sys.stdin); print('\n'.join(d['added_allow']))")"
ADDED_DENY="$(echo "$RESULT"    | python3 -c "import json,sys; d=json.load(sys.stdin); print('\n'.join(d['added_deny']))")"
SKIPPED_ALLOW="$(echo "$RESULT" | python3 -c "import json,sys; print(json.load(sys.stdin)['skipped_allow'])")"
SKIPPED_DENY="$(echo "$RESULT"  | python3 -c "import json,sys; print(json.load(sys.stdin)['skipped_deny'])")"
MODE_ADDED="$(echo "$RESULT"    | python3 -c "import json,sys; print(json.load(sys.stdin)['mode_added'])")"
MODE_SKIPPED="$(echo "$RESULT"  | python3 -c "import json,sys; print(json.load(sys.stdin)['mode_skipped'])")"
MODE_CHANGED="$(echo "$RESULT"  | python3 -c "import json,sys; print(json.load(sys.stdin)['mode_changed'])")"

ADDED_ALLOW_COUNT=$(echo "$ADDED_ALLOW" | grep -c . || true)
ADDED_DENY_COUNT=$(echo "$ADDED_DENY"   | grep -c . || true)
[ -z "$ADDED_ALLOW" ] && ADDED_ALLOW_COUNT=0
[ -z "$ADDED_DENY"  ] && ADDED_DENY_COUNT=0

# ── Summary + confirmation ────────────────────────────────────────────────────
B='\033[1m' RESET='\033[0m'

echo ""
echo -e "${B}  ┌─ enable-safe-yolo ───────────────────────────────────────────┐${RESET}"
echo -e "${B}  │${RESET}  Directory : ${TARGET_DIR}"
echo -e "${B}  │${RESET}  File      : ${SETTINGS_FILE}"
echo -e "${B}  └──────────────────────────────────────────────────────────────┘${RESET}"
echo ""

if [ "$ADDED_ALLOW_COUNT" -eq 0 ] && [ "$ADDED_DENY_COUNT" -eq 0 ] && [ "$MODE_ADDED" = "False" ] && [ "$MODE_CHANGED" = "False" ]; then
  warn "Nothing to add — all ${SKIPPED_ALLOW} allow, ${SKIPPED_DENY} deny entries already present${MODE_SKIPPED:+, defaultMode already set}."
  echo ""
  exit 0
fi

if [ "$MODE_ADDED" = "True" ]; then
  echo -e "  ${G}Permission mode — defaultMode = ${DEFAULT_MODE_VAL}${RESET}"
  echo ""
fi
if [ "$MODE_CHANGED" = "True" ]; then
  echo -e "  ${Y}Permission mode changed — defaultMode overwritten to ${DEFAULT_MODE_VAL}${RESET}"
  echo ""
fi
if [ "$ADDED_ALLOW_COUNT" -gt 0 ]; then
  echo -e "  ${G}Auto-approve (allow) — ${ADDED_ALLOW_COUNT} entries:${RESET}"
  while IFS= read -r e; do [ -n "$e" ] && echo "    ✓  ${e}"; done <<< "$ADDED_ALLOW"
  echo ""
fi
if [ "$ADDED_DENY_COUNT" -gt 0 ]; then
  echo -e "  ${R}Hard-block (deny) — ${ADDED_DENY_COUNT} entries:${RESET}"
  while IFS= read -r e; do [ -n "$e" ] && echo "    ✗  ${e}"; done <<< "$ADDED_DENY"
  echo ""
fi
if [ "$SKIPPED_ALLOW" -gt 0 ] || [ "$SKIPPED_DENY" -gt 0 ] || [ "$MODE_SKIPPED" = "True" ]; then
  _skipped_msg="Already present (skipped): ${SKIPPED_ALLOW} allow, ${SKIPPED_DENY} deny"
  [ "$MODE_SKIPPED" = "True" ] && _skipped_msg="${_skipped_msg}, defaultMode"
  info "$_skipped_msg"
  echo ""
fi

if $DRY_RUN; then
  warn "Dry run — nothing written."
  echo ""
  exit 0
fi

# ── Confirmation ──────────────────────────────────────────────────────────────
if ! $YES; then
  printf "  Enable safe-yolo in this directory? [y/n] "
  read -r _confirm
  echo ""
  if [[ ! "$_confirm" =~ ^[Yy]$ ]]; then
    warn "Aborted — no changes made."
    echo ""
    exit 0
  fi
fi

# ── Write ─────────────────────────────────────────────────────────────────────
mkdir -p "${TARGET_DIR}/.claude"
[ -f "$SETTINGS_FILE" ] && info "Merging into existing settings.json (other keys preserved)"

echo "$FINAL_JSON" > "$SETTINGS_FILE"
echo ""
ok "Written: ${SETTINGS_FILE}"
echo ""
info "Claude Code will auto-approve allowed tools in: ${TARGET_DIR}"
info "To remove: disable-safe-yolo [--dir=PATH]"
echo ""
