#!/usr/bin/env bats
# tests/test_claudeignore_guard.bats
# Tests for scripts/claudeignore-guard.sh — PreToolUse hook that blocks file access
# based on .claudeignore patterns.
load 'helpers/setup'

# Helper: pipe JSON to the guard script from current directory
_run_guard() {
  printf '%s' "$1" | bash "$BATS_TEST_DIRNAME/../scripts/claudeignore-guard.sh"
}

# ---------------------------------------------------------------------------
# 1. Exits 0 for non-file-access tools (e.g. Bash)
# ---------------------------------------------------------------------------
@test "CIG-01: exits 0 for non-file-access tool (Bash)" {
  run _run_guard '{"tool_name":"Bash","tool_input":{"command":"ls"}}'
  [ "$status" -eq 0 ]
}

@test "CIG-01b: exits 0 for non-file-access tool (ListFiles)" {
  run _run_guard '{"tool_name":"ListFiles","tool_input":{"path":"/tmp"}}'
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# 2. Exits 0 when no .claudeignore files exist and tool is Read
# ---------------------------------------------------------------------------
@test "CIG-02: exits 0 when no .claudeignore exists and tool is Read" {
  rm -f "$TMP_HOME/.claude/.claudeignore"
  rm -f "$TMP_PROJECT/.claudeignore"
  cd "$TMP_PROJECT"
  run _run_guard '{"tool_name":"Read","tool_input":{"file_path":"/some/path/readme.txt"}}'
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# 3. Exits 2 when global .claudeignore matches a .env file
# ---------------------------------------------------------------------------
@test "CIG-03: exits 2 when global .claudeignore matches .env file" {
  printf '.env\n' > "$TMP_HOME/.claude/.claudeignore"
  cd "$TMP_PROJECT"
  run _run_guard '{"tool_name":"Read","tool_input":{"file_path":"/some/path/.env"}}'
  [ "$status" -eq 2 ]
}

# ---------------------------------------------------------------------------
# 4. Exits 2 when pattern matches *.secret
# ---------------------------------------------------------------------------
@test "CIG-04: exits 2 when global .claudeignore pattern *.secret matches mysecrets.secret" {
  printf '*.secret\n' > "$TMP_HOME/.claude/.claudeignore"
  cd "$TMP_PROJECT"
  run _run_guard '{"tool_name":"Read","tool_input":{"file_path":"/home/user/mysecrets.secret"}}'
  [ "$status" -eq 2 ]
}

# ---------------------------------------------------------------------------
# 5. Exits 0 when file does NOT match any pattern
# ---------------------------------------------------------------------------
@test "CIG-05: exits 0 when file path does not match any .claudeignore pattern" {
  printf '.env\n*.secret\n' > "$TMP_HOME/.claude/.claudeignore"
  cd "$TMP_PROJECT"
  run _run_guard '{"tool_name":"Read","tool_input":{"file_path":"/home/user/safe-file.txt"}}'
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# 6. Project-level .claudeignore in $TMP_PROJECT matches
# ---------------------------------------------------------------------------
@test "CIG-06: exits 2 when project-level .claudeignore matches the file" {
  # No global ignore
  rm -f "$TMP_HOME/.claude/.claudeignore"
  # Write project-level ignore
  printf 'custom-secret.txt\n' > "$TMP_PROJECT/.claudeignore"
  # Must cd to project so $(pwd)/.claudeignore is found
  cd "$TMP_PROJECT"
  run _run_guard "{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$TMP_PROJECT/custom-secret.txt\"}}"
  [ "$status" -eq 2 ]
}

# ---------------------------------------------------------------------------
# 7. Comments and blank lines in .claudeignore are skipped
# ---------------------------------------------------------------------------
@test "CIG-07: comments and blank lines in .claudeignore do not cause false blocks" {
  printf '# this is a comment\n\n   \n# another comment\n.env\n' > "$TMP_HOME/.claude/.claudeignore"
  cd "$TMP_PROJECT"
  # This file does NOT match .env — should exit 0 (not blocked by comment lines)
  run _run_guard '{"tool_name":"Read","tool_input":{"file_path":"/home/user/normal-file.txt"}}'
  [ "$status" -eq 0 ]
}

@test "CIG-07b: comment line that looks like a pattern does not block non-matching file" {
  # Pattern '#.env' as a comment should not block a file named '.env'
  # (the script skips lines starting with #)
  printf '# .env\n' > "$TMP_HOME/.claude/.claudeignore"
  cd "$TMP_PROJECT"
  run _run_guard '{"tool_name":"Read","tool_input":{"file_path":"/some/path/.env"}}'
  # The only line in the file is a comment — should NOT block
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Additional edge cases
# ---------------------------------------------------------------------------
@test "CIG-08: exits 2 for Edit tool matching a blocked pattern" {
  printf '*.key\n' > "$TMP_HOME/.claude/.claudeignore"
  cd "$TMP_PROJECT"
  run _run_guard '{"tool_name":"Edit","tool_input":{"file_path":"/home/user/private.key"}}'
  [ "$status" -eq 2 ]
}

@test "CIG-09: exits 2 for Write tool matching a blocked pattern" {
  printf 'credentials.json\n' > "$TMP_HOME/.claude/.claudeignore"
  cd "$TMP_PROJECT"
  run _run_guard '{"tool_name":"Write","tool_input":{"file_path":"/app/credentials.json"}}'
  [ "$status" -eq 2 ]
}

@test "CIG-10: exits 0 when file_path is empty (guard is a no-op)" {
  printf '.env\n' > "$TMP_HOME/.claude/.claudeignore"
  cd "$TMP_PROJECT"
  run _run_guard '{"tool_name":"Read","tool_input":{"file_path":""}}'
  [ "$status" -eq 0 ]
}
