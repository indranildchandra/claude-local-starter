#!/usr/bin/env bash
# tests/helpers/setup.bash
# Shared bats test helper — sourced by all test files via: load 'helpers/setup'

setup() {
  export TMP_HOME
  TMP_HOME=$(mktemp -d)
  export TMP_PROJECT
  TMP_PROJECT=$(mktemp -d)
  export HOME="$TMP_HOME"
  mkdir -p "$TMP_HOME/.claude"
  mkdir -p "$TMP_PROJECT/tasks"

  # mock `at` as no-op
  mkdir -p "$TMP_HOME/bin"
  printf '#!/bin/bash\nexit 0\n' > "$TMP_HOME/bin/at"
  chmod +x "$TMP_HOME/bin/at"

  # mock `osascript` as no-op
  printf '#!/bin/bash\nexit 0\n' > "$TMP_HOME/bin/osascript"
  chmod +x "$TMP_HOME/bin/osascript"

  # mock `launchctl` as no-op (prevents real launchctl running in tests)
  printf '#!/bin/bash\nexit 0\n' > "$TMP_HOME/bin/launchctl"
  chmod +x "$TMP_HOME/bin/launchctl"

  # Set SWITCHBACK_DELAY=0 so switch-to-anthropic.sh Phase 2 runs synchronously in tests
  # (avoids race conditions with backgrounded Phase 2 subprocess)
  export SWITCHBACK_DELAY=0

  # create LaunchAgents dir so watchdog's launchctl branch is taken (not at fallback)
  mkdir -p "$TMP_HOME/Library/LaunchAgents"

  export PATH="$TMP_HOME/bin:$PATH"
}

teardown() {
  rm -rf "$TMP_HOME" "$TMP_PROJECT"
}
