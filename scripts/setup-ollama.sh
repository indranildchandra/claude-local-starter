#!/usr/bin/env bash
# scripts/setup-ollama.sh
# Installs Ollama and pulls models for the auto-switchover system.
# Usage: bash scripts/setup-ollama.sh [--test-mode]

set -euo pipefail

TEST_MODE=false

for arg in "$@"; do
  case "$arg" in
    --test-mode) TEST_MODE=true ;;
  esac
done

check_ollama_installed() {
  if command -v ollama &>/dev/null; then
    echo "[setup-ollama] ollama already on PATH: $(command -v ollama)"
    return 0
  fi

  if [ "$TEST_MODE" = true ]; then
    echo "[setup-ollama] ERROR: ollama not found on PATH (test-mode, brew skipped)" >&2
    exit 1
  fi

  echo "[setup-ollama] ollama not found — installing via brew..."
  brew install ollama
}

model_already_pulled() {
  local model="$1"
  # Strip :tag suffix for comparison so "glm-4.7-flash" matches "glm-4.7-flash:latest"
  local base="${model%%:*}"
  ollama list 2>/dev/null | awk 'NR>1 {print $1}' | sed 's/:.*//' | grep -qxF "$base"
}

pull_model() {
  local model="$1"
  if [ "$TEST_MODE" = true ]; then
    echo "[setup-ollama] would pull $model"
    return 0
  fi
  if model_already_pulled "$model"; then
    echo "[setup-ollama] $model already present — skipping"
    return 0
  fi
  echo "[setup-ollama] pulling $model ..."
  ollama pull "$model"
}

prompt_optional_model() {
  local model="$1"
  local description="$2"
  if [ "$TEST_MODE" = true ]; then
    echo "[setup-ollama] skipping optional model prompt for $model (test-mode)"
    return 0
  fi
  if model_already_pulled "$model"; then
    echo "[setup-ollama] $model already present — skipping"
    return 0
  fi
  echo ""
  echo "$description"
  read -r -p "Pull $model now? [y/n] " answer
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    pull_model "$model"
  else
    echo "[setup-ollama] skipping $model"
  fi
}

main() {
  echo "[setup-ollama] Starting Ollama setup..."

  check_ollama_installed

  echo ""
  echo "[setup-ollama] Pulling required model: smollm2:360m"
  pull_model "smollm2:360m"

  # Officially recommended Claude Code models (from docs.ollama.com/integrations/claude-code)
  prompt_optional_model "glm-4.7-flash" \
    "glm-4.7-flash: fast local model for Claude Code. 128K context, fits in 8GB RAM."

  prompt_optional_model "kimi-k2.5:cloud" \
    "kimi-k2.5:cloud: best quality cloud model — use this if your machine lacks 8GB+ free RAM.
  No local GPU/RAM needed, but requires:
    1. A free Ollama account: https://ollama.com
    2. Device Key registered at: https://ollama.com/settings/keys
  Note: Ollama cloud models have session and weekly usage limits.
  Track your usage at: https://ollama.com/settings"

  prompt_optional_model "qwen3:4b" \
    "qwen3:4b: compact local model. 4B params, 2.5GB RAM, 128K context. Good for fast iteration."

  prompt_optional_model "qwen3:30b" \
    "qwen3:30b: high-quality local model. 30B params, requires 20GB+ RAM. Best local reasoning."

  prompt_optional_model "qwen2.5-coder:7b" \
    "qwen2.5-coder:7b: strong code generation. 7B params, 4.7GB RAM, 32K context."

  echo ""
  echo "[setup-ollama] Note: smollm2:360m requires ~500MB RAM (bats tests only)."
  echo "[setup-ollama] For Claude Code sessions, glm-4.7-flash or kimi-k2.5:cloud is recommended."
  echo "[setup-ollama] See OLLAMA-SETUP-GUIDE.md for full model comparison."
  echo "[setup-ollama] Setup complete."
}

main
