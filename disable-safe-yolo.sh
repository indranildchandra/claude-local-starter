#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  disable-safe-yolo.sh
#
#  Removes ONLY the permissions that are listed in
#  ~/.claude/claude-safe-yolo-permissions.txt from .claude/settings.json.
#
#  IDEMPOTENT: any permissions manually added to .claude/settings.json that
#  are NOT in the yolo permissions file are left completely untouched.
#
#  - If allow/deny arrays become empty after removal, the keys are cleaned up.
#  - If settings.json becomes empty {}, the file is deleted.
#  - If settings.json has no permissions block, exits cleanly with no changes.
#
#  Usage:
#    disable-safe-yolo                  # target = current working directory
#    disable-safe-yolo --dir=PATH       # target = PATH
#    disable-safe-yolo --dry-run        # preview, no changes
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
      echo "Usage: disable-safe-yolo [--dir=PATH] [--dry-run] [--yes|-y]"
      echo "  --dir=PATH   Target repo directory (default: current working directory)"
      echo "  --dry-run    Preview what would happen, no changes"
      echo "  --yes / -y   Skip confirmation prompt (for scripted/Claude session use)"
      exit 0 ;;
    *) err "Unknown argument: $arg"; exit 1 ;;
  esac
done

TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
SETTINGS_FILE="${TARGET_DIR}/.claude/settings.json"

echo ""
echo -e "  Target : ${TARGET_DIR}"
echo -e "  File   : ${SETTINGS_FILE}"
echo ""

# ── Nothing to do ─────────────────────────────────────────────────────────────
if [ ! -f "$SETTINGS_FILE" ]; then
  warn "No .claude/settings.json found — safe-yolo is not enabled here."
  exit 0
fi

PERMS_FILE="${HOME}/.claude/claude-safe-yolo-permissions.txt"
if [ ! -f "$PERMS_FILE" ]; then
  err "Permissions file not found: $PERMS_FILE"
  err "Run install.sh first, or copy claude-safe-yolo-permissions.txt to ~/.claude/"
  exit 1
fi

# ── Parse permissions file ────────────────────────────────────────────────────
ALLOW_TMP="$(mktemp)"
DENY_TMP="$(mktemp)"

while IFS= read -r line; do
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  [[ -z "$line" || "$line" == \#* ]] && continue
  if [[ "$line" == \!* ]]; then
    echo "${line#!}" >> "$DENY_TMP"
  else
    echo "$line" >> "$ALLOW_TMP"
  fi
done < "$PERMS_FILE"

# ── Compute result via python3 ────────────────────────────────────────────────
RESULT="$(python3 - "$SETTINGS_FILE" "$ALLOW_TMP" "$DENY_TMP" <<'PYEOF'
import json, sys, os

settings_path = sys.argv[1]
allow_file    = sys.argv[2]
deny_file     = sys.argv[3]

with open(allow_file) as f:
    yolo_allow = set(l.strip() for l in f if l.strip())
with open(deny_file) as f:
    yolo_deny  = set(l.strip() for l in f if l.strip())

with open(settings_path) as f:
    data = json.load(f)

perms = data.get("permissions", {})
existing_allow = perms.get("allow", [])
existing_deny  = perms.get("deny",  [])

# Remove only entries that came from the yolo permissions file
removed_allow = [e for e in existing_allow if e in yolo_allow]
removed_deny  = [e for e in existing_deny  if e in yolo_deny]
kept_allow    = [e for e in existing_allow if e not in yolo_allow]
kept_deny     = [e for e in existing_deny  if e not in yolo_deny]

if kept_allow:
    data.setdefault("permissions", {})["allow"] = kept_allow
else:
    data.get("permissions", {}).pop("allow", None)

if kept_deny:
    data.setdefault("permissions", {})["deny"] = kept_deny
else:
    data.get("permissions", {}).pop("deny", None)

# Clean up empty permissions key
if "permissions" in data and not data["permissions"]:
    del data["permissions"]

# Signal full deletion if settings.json is now empty
delete_file = (data == {})

result = {
    "json":          json.dumps(data, indent=2) if not delete_file else "",
    "delete_file":   delete_file,
    "removed_allow": removed_allow,
    "removed_deny":  removed_deny,
    "kept_allow":    kept_allow,
    "kept_deny":     kept_deny,
}
print(json.dumps(result))
PYEOF
)"

rm -f "$ALLOW_TMP" "$DENY_TMP"

FINAL_JSON="$(echo "$RESULT"       | python3 -c "import json,sys; print(json.load(sys.stdin)['json'])")"
DELETE_FILE="$(echo "$RESULT"      | python3 -c "import json,sys; print(json.load(sys.stdin)['delete_file'])")"
REMOVED_ALLOW="$(echo "$RESULT"    | python3 -c "import json,sys; d=json.load(sys.stdin); print('\n'.join(d['removed_allow']))")"
REMOVED_DENY="$(echo "$RESULT"     | python3 -c "import json,sys; d=json.load(sys.stdin); print('\n'.join(d['removed_deny']))")"
KEPT_ALLOW="$(echo "$RESULT"       | python3 -c "import json,sys; d=json.load(sys.stdin); print('\n'.join(d['kept_allow']))")"

REMOVED_ALLOW_COUNT=$(echo "$REMOVED_ALLOW" | grep -c . || true)
REMOVED_DENY_COUNT=$(echo "$REMOVED_DENY"   | grep -c . || true)
KEPT_ALLOW_COUNT=$(echo "$KEPT_ALLOW"       | grep -c . || true)
[ -z "$REMOVED_ALLOW" ] && REMOVED_ALLOW_COUNT=0
[ -z "$REMOVED_DENY"  ] && REMOVED_DENY_COUNT=0
[ -z "$KEPT_ALLOW"    ] && KEPT_ALLOW_COUNT=0

B='\033[1m' RESET='\033[0m'

# ── Nothing was managed by yolo ───────────────────────────────────────────────
if [ "$REMOVED_ALLOW_COUNT" -eq 0 ] && [ "$REMOVED_DENY_COUNT" -eq 0 ]; then
  echo ""
  echo -e "${B}  ┌─ disable-safe-yolo ──────────────────────────────────────────┐${RESET}"
  echo -e "${B}  │${RESET}  Directory : ${TARGET_DIR}"
  echo -e "${B}  └──────────────────────────────────────────────────────────────┘${RESET}"
  echo ""
  warn "No safe-yolo permissions found in settings.json — nothing to remove."
  [ "$KEPT_ALLOW_COUNT" -gt 0 ] && info "Manually-added permissions present (untouched): ${KEPT_ALLOW_COUNT} entries"
  echo ""
  exit 0
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${B}  ┌─ disable-safe-yolo ──────────────────────────────────────────┐${RESET}"
echo -e "${B}  │${RESET}  Directory : ${TARGET_DIR}"
echo -e "${B}  │${RESET}  File      : ${SETTINGS_FILE}"
echo -e "${B}  └──────────────────────────────────────────────────────────────┘${RESET}"
echo ""

if [ "$REMOVED_ALLOW_COUNT" -gt 0 ]; then
  echo -e "  ${Y}Will remove from allow (${REMOVED_ALLOW_COUNT}):${RESET}"
  while IFS= read -r e; do [ -n "$e" ] && echo "    -  ${e}"; done <<< "$REMOVED_ALLOW"
  echo ""
fi
if [ "$REMOVED_DENY_COUNT" -gt 0 ]; then
  echo -e "  ${Y}Will remove from deny (${REMOVED_DENY_COUNT}):${RESET}"
  while IFS= read -r e; do [ -n "$e" ] && echo "    -  ${e}"; done <<< "$REMOVED_DENY"
  echo ""
fi
if [ "$KEPT_ALLOW_COUNT" -gt 0 ]; then
  echo -e "  ${G}Manually-added permissions preserved (untouched):${RESET}"
  while IFS= read -r e; do [ -n "$e" ] && echo "    ✓  ${e}"; done <<< "$KEPT_ALLOW"
  echo ""
fi
if [ "$DELETE_FILE" = "True" ]; then
  info "settings.json will be deleted (no other content remains)"
  echo ""
fi

if $DRY_RUN; then
  warn "Dry run — nothing written."
  echo ""
  exit 0
fi

# ── Confirmation ──────────────────────────────────────────────────────────────
if ! $YES; then
  printf "  Disable safe-yolo in this directory? [y/n] "
  read -r _confirm
  echo ""
  if [[ ! "$_confirm" =~ ^[Yy]$ ]]; then
    warn "Aborted — no changes made."
    echo ""
    exit 0
  fi
fi

# ── Apply ─────────────────────────────────────────────────────────────────────
if [ "$DELETE_FILE" = "True" ]; then
  rm "$SETTINGS_FILE"
  rmdir "${TARGET_DIR}/.claude" 2>/dev/null || true
  ok "Deleted ${SETTINGS_FILE}"
else
  echo "$FINAL_JSON" > "$SETTINGS_FILE"
  ok "Updated ${SETTINGS_FILE}"
fi

echo ""
info "Safe-yolo disabled in: ${TARGET_DIR}"
info "Claude Code will prompt for approvals again (except any manually-kept permissions)."
echo ""
