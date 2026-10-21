#!/bin/bash
# usage-band status line: the same figures as the usage band, as a CLI status line.
#
#   <cwd> (<branch>)  ctx 12% █░░░░░░░ 24k/200k  5h 23% ██░░░░░░ →14:30  7d 41% ███░░░░░ →Fri  $0.42  fable-5-1 · 1h05m
#
# Each section has its own colour so it can be found without reading the label
# (ctx magenta, 5h blue, 7d bright blue, cost green); a figure turns yellow at
# 70% and red at 90%, so yellow and red only ever mean "getting full".
#
# Install: in ~/.claude/settings.json
#   "statusLine": { "type": "command", "command": "bash /path/to/usage-band/statusline/usage-band.sh" }
#
# Needs jq. Works on macOS and Linux.

input=$(cat)

WARN=70
BAD=90

ESC=$'\033'
DIM="${ESC}[2m"
RESET="${ESC}[0m"
CYAN="${ESC}[36m"
MAGENTA="${ESC}[35m"
BLUE="${ESC}[34m"
BRIGHT_BLUE="${ESC}[94m"
GREEN="${ESC}[32m"
YELLOW="${ESC}[33m"
RED="${ESC}[31m"

j() { printf '%s' "$input" | jq -r "$1"; }

# Colour for a percentage: the section's own colour, or yellow/red past the thresholds.
tone() { # percent, base colour
  if [ "$1" -ge "$BAD" ]; then printf '%s' "$RED"
  elif [ "$1" -ge "$WARN" ]; then printf '%s' "$YELLOW"
  else printf '%s' "$2"
  fi
}

bar() { # percent, 8 cells
  local filled=$(( ($1 * 8 + 50) / 100 ))
  [ "$filled" -gt 8 ] && filled=8
  [ "$filled" -lt 0 ] && filled=0
  local i out=""
  for ((i = 0; i < filled; i++)); do out+="█"; done
  for ((i = filled; i < 8; i++)); do out+="░"; done
  printf '%s' "$out"
}

k() { # token count → 24k, or the number itself under 1000
  if [ "$1" -ge 1000 ]; then printf '%dk' $(( ($1 + 500) / 1000 )); else printf '%d' "$1"; fi
}

# "→14:30" within 24h, "→Fri" beyond, "resetting" once passed.
reset_label() { # epoch seconds
  local at=$1 now
  now=$(date +%s)
  local ms=$((at - now))
  if [ "$ms" -le 0 ]; then printf 'resetting'; return; fi
  if [ "$ms" -lt 86400 ]; then
    printf '→%s' "$(date -r "$at" +%H:%M 2>/dev/null || date -d "@$at" +%H:%M)"
  else
    printf '→%s' "$(date -r "$at" +%a 2>/dev/null || date -d "@$at" +%a)"
  fi
}

elapsed() { # milliseconds → 1h05m or 5m
  local min=$(( $1 / 60000 ))
  local h=$((min / 60)) m=$((min % 60))
  if [ "$h" -gt 0 ]; then printf '%dh%02dm' "$h" "$m"; else printf '%dm' "$m"; fi
}

# Round a possibly-fractional percentage to an integer.
pct() { printf '%.0f' "$1"; }

parts=()

# Path and branch
cwd=$(j '.workspace.current_dir // .cwd // ""')
branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
loc="${DIM}${cwd}${RESET}"
[ -n "$branch" ] && loc+=" ${CYAN}(${branch})${RESET}"
parts+=("$loc")

# Context window
ctx_pct=$(pct "$(j '.context_window.used_percentage // 0')")
ctx_tokens=$(j '.context_window.total_input_tokens // 0')
ctx_window=$(j '.context_window.context_window_size // 0')
parts+=("${DIM}ctx${RESET} $(tone "$ctx_pct" "$MAGENTA")${ctx_pct}% $(bar "$ctx_pct")${RESET} ${DIM}$(k "$ctx_tokens")/$(k "$ctx_window")${RESET}")

# Rate-limit windows, only once the first response has reported them
limit_part() { # label, jq path, base colour
  local used
  used=$(j "$2.used_percentage // empty")
  [ -z "$used" ] && return
  local p resets label=""
  p=$(pct "$used")
  resets=$(j "$2.resets_at // empty")
  [ -n "$resets" ] && label=" ${DIM}$(reset_label "$resets")${RESET}"
  parts+=("${DIM}$1${RESET} $(tone "$p" "$3")${p}% $(bar "$p")${RESET}${label}")
}
limit_part 5h .rate_limits.five_hour "$BLUE"
limit_part 7d .rate_limits.seven_day "$BRIGHT_BLUE"

# Cost, when reported
usd=$(j '.cost.total_cost_usd // empty')
[ -n "$usd" ] && parts+=("${GREEN}$(printf '$%.2f' "$usd")${RESET}")

# Model and session length
model=$(j '.model.id // .model.display_name // ""' | sed 's/^claude-//')
dur=$(j '.cost.total_duration_ms // 0')
parts+=("${DIM}${model} · $(elapsed "$dur")${RESET}")

out=""
for p in "${parts[@]}"; do out+="${out:+  }$p"; done
printf '%s' "$out"
