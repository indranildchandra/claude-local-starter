#!/usr/bin/env bash
# scripts/claudeignore-guard.sh — PreToolUse hook: blocks Read/Edit/Write on .claudeignore patterns
# Exit 2 = skip (Claude Code treats this as "tool call skipped, not an error")

stdin_json=$(cat)
tool_name=$(echo "$stdin_json" | python3 -c \
  "import sys,json; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null) || tool_name=""

# Only guard file-access tools
case "$tool_name" in
  Read|Edit|Write) ;;
  *) exit 0 ;;
esac

file_path=$(echo "$stdin_json" | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" \
  2>/dev/null) || file_path=""
[ -z "$file_path" ] && exit 0

# Resolve to absolute path for reliable matching.
# Fail-closed: if realpath resolution fails, block the tool call rather than
# allowing an unresolved path (e.g. "../../.env") to slip past fnmatch patterns.
abs_path=$(python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$file_path" 2>/dev/null) || {
  echo "claudeignore-guard: path resolution failed for '$file_path' — blocking as precaution" >&2
  exit 2
}

check_ignore_file() {
  local ignore_file="$1"
  [ -f "$ignore_file" ] || return 0
  while IFS= read -r pattern || [ -n "$pattern" ]; do
    [[ "$pattern" =~ ^#.*$ || -z "$pattern" ]] && continue
    matched=$(python3 -c "
import fnmatch, sys, os
pattern, path = sys.argv[1], sys.argv[2]
basename = os.path.basename(path)
if fnmatch.fnmatch(basename, pattern) or fnmatch.fnmatch(path, pattern):
    print('yes')
" "$pattern" "$abs_path" 2>/dev/null)
    if [ "$matched" = "yes" ]; then
      echo "Blocked by .claudeignore ($ignore_file, pattern: '$pattern'): $file_path" >&2
      exit 2
    fi
  done < "$ignore_file"
}

# Global ignore (applies to all sessions)
check_ignore_file "$HOME/.claude/.claudeignore"
# Project-level ignore (repo-specific sensitive files)
check_ignore_file "$(pwd)/.claudeignore"
