#!/bin/bash
input=$(cat)

# Colours
CYAN=$'\033[36m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
MAGENTA=$'\033[38;5;75m'
DIM=$'\033[2m'
BOLD=$'\033[1m'
RESET=$'\033[0m'

model=$(echo "$input" | jq -r '.model.display_name // "Unknown"')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
effort=$(jq -r '.effortLevel // empty' "$HOME/.claude/settings.json" 2>/dev/null)

# Shorten cwd: replace $HOME with ~
home="$HOME"
short_cwd="${cwd/#$home/\~}"

# Build context progress bar (10 chars wide) — colour by fill level
if [ -n "$used" ]; then
  filled=$(printf "%.0f" "$(echo "$used / 10" | bc -l)")
  pct=$(printf "%.0f" "$used")

  if   [ "$pct" -ge 80 ]; then bar_color="$YELLOW"
  else                          bar_color="$GREEN"
  fi

  bar=""
  for i in $(seq 1 10); do
    if [ "$i" -le "$filled" ]; then bar="${bar}█"; else bar="${bar}░"; fi
  done
  ctx_str="${DIM} | ${RESET}${bar_color}[${bar} ${pct}%]${RESET}"
else
  ctx_str=""
fi

# Effort level
if [ -n "$effort" ]; then
  case "$effort" in
    high)   effort_color="$YELLOW" ;;
    medium) effort_color="$GREEN" ;;
    *)      effort_color="$CYAN" ;;
  esac
  effort_str="${DIM} | ${RESET}${DIM}effort:${RESET} ${effort_color}${effort}${RESET}"
else
  effort_str=""
fi

# Rate limit: 5-hour bucket
five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_resets=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')

# Rate limit: 7-day bucket
week_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
week_resets=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

rate_str=""

if [ -n "$five_pct" ]; then
  five_pct_fmt=$(printf "%.0f" "$five_pct")
  if [ "$five_pct_fmt" -ge 80 ]; then pct_color="$YELLOW"; else pct_color="$GREEN"; fi
  if [ -n "$five_resets" ]; then
    five_time=$(date -r "$five_resets" "+%H:%M" 2>/dev/null || date -d "@$five_resets" "+%H:%M" 2>/dev/null)
    rate_str="${rate_str}${DIM} | ${RESET}${DIM}5h:${RESET} ${pct_color}${five_pct_fmt}%${RESET} ${DIM}resets${RESET} ${CYAN}${five_time}${RESET}"
  else
    rate_str="${rate_str}${DIM} | ${RESET}${DIM}5h:${RESET} ${pct_color}${five_pct_fmt}%${RESET}"
  fi
fi

if [ -n "$week_pct" ]; then
  week_pct_fmt=$(printf "%.0f" "$week_pct")
  if [ "$week_pct_fmt" -ge 80 ]; then pct_color="$YELLOW"; else pct_color="$GREEN"; fi
  if [ -n "$week_resets" ]; then
    week_time=$(date -r "$week_resets" "+%a %H:%M" 2>/dev/null || date -d "@$week_resets" "+%a %H:%M" 2>/dev/null)
    rate_str="${rate_str}${DIM} | ${RESET}${DIM}7d:${RESET} ${pct_color}${week_pct_fmt}%${RESET} ${DIM}resets${RESET} ${CYAN}${week_time}${RESET}"
  else
    rate_str="${rate_str}${DIM} | ${RESET}${DIM}7d:${RESET} ${pct_color}${week_pct_fmt}%${RESET}"
  fi
fi

printf '%s' "${MAGENTA}${short_cwd}${RESET}  ${BOLD}${model}${RESET}${ctx_str}${effort_str}${rate_str}"
