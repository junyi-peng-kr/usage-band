#!/bin/bash
# Tests for statusline/usage-band.sh. Run: bash statusline/test.sh
set -u
here=$(cd "$(dirname "$0")" && pwd)
script="$here/usage-band.sh"
fail=0
pass=0

ESC=$'\033'
strip() { sed -E "s/${ESC}\[[0-9;]*m//g"; }

check() { # name, expected, actual
  if [ "$2" = "$3" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf 'FAIL %s\n  expected: %q\n  actual:   %q\n' "$1" "$2" "$3"
  fi
}
contains() { # name, needle, haystack
  case "$3" in
    *"$2"*) pass=$((pass + 1)) ;;
    *) fail=$((fail + 1)); printf 'FAIL %s\n  missing: %q\n  in:      %q\n' "$1" "$2" "$3" ;;
  esac
}

# A throwaway git repo so the branch part is deterministic.
repo=$(mktemp -d)
git -C "$repo" init -q -b main
plain=$(mktemp -d)

now=$(date +%s)
in2h=$((now + 2 * 3600))
in3d=$((now + 3 * 86400))
hhmm=$(date -r "$in2h" +%H:%M 2>/dev/null || date -d "@$in2h" +%H:%M)
day=$(date -r "$in3d" +%a 2>/dev/null || date -d "@$in3d" +%a)

full=$(cat <<JSON
{
  "cwd": "$repo",
  "workspace": { "current_dir": "$repo" },
  "model": { "id": "claude-fable-5-1", "display_name": "Fable" },
  "cost": { "total_cost_usd": 0.4213, "total_duration_ms": 3900000 },
  "context_window": { "used_percentage": 12, "total_input_tokens": 24400, "context_window_size": 200000 },
  "rate_limits": {
    "five_hour": { "used_percentage": 75.4, "resets_at": $in2h },
    "seven_day": { "used_percentage": 95, "resets_at": $in3d }
  }
}
JSON
)
out=$(printf '%s' "$full" | bash "$script")
check "full line, plain text" \
  "$repo (main)  ctx 12% █░░░░░░░ 24k/200k  5h 75% ██████░░ →$hhmm  7d 95% ████████ →$day  \$0.42  fable-5-1 · 1h05m" \
  "$(printf '%s' "$out" | strip)"
contains "ctx under 70% is magenta" "${ESC}[35m12% █░░░░░░░" "$out"
contains "5h at 75% is yellow"      "${ESC}[33m75% ██████░░" "$out"
contains "7d at 95% is red"         "${ESC}[31m95% ████████" "$out"
contains "cost is green"            "${ESC}[32m\$0.42"      "$out"
contains "branch is cyan"           "${ESC}[36m(main)"      "$out"

blue=$(cat <<JSON
{
  "cwd": "$plain",
  "model": { "id": "claude-sonnet-5-5" },
  "cost": { "total_duration_ms": 300000 },
  "context_window": { "used_percentage": 50, "total_input_tokens": 100000, "context_window_size": 200000 },
  "rate_limits": {
    "five_hour": { "used_percentage": 23, "resets_at": $in2h },
    "seven_day": { "used_percentage": 41, "resets_at": $in3d }
  }
}
JSON
)
out=$(printf '%s' "$blue" | bash "$script")
contains "5h under 70% is blue"        "${ESC}[34m23% ██░░░░░░" "$out"
contains "7d under 70% is bright blue" "${ESC}[94m41% ███░░░░░" "$out"
check "no branch, no cost: parts are omitted" \
  "$plain  ctx 50% ████░░░░ 100k/200k  5h 23% ██░░░░░░ →$hhmm  7d 41% ███░░░░░ →$day  sonnet-5-5 · 5m" \
  "$(printf '%s' "$out" | strip)"

bare=$(cat <<JSON
{ "cwd": "$plain", "model": { "id": "claude-opus-5-5" }, "context_window": { "context_window_size": 200000 } }
JSON
)
out=$(printf '%s' "$bare" | bash "$script")
check "before first response: only path, ctx 0 and model" \
  "$plain  ctx 0% ░░░░░░░░ 0/200k  opus-5-5 · 0m" \
  "$(printf '%s' "$out" | strip)"

past=$(cat <<JSON
{ "cwd": "$plain", "model": { "id": "claude-opus-5-5" }, "context_window": { "used_percentage": 1, "total_input_tokens": 900, "context_window_size": 200000 },
  "rate_limits": { "five_hour": { "used_percentage": 5, "resets_at": $((now - 60)) } } }
JSON
)
out=$(printf '%s' "$past" | bash "$script" | strip)
contains "reset in the past says resetting" "5h 5% ░░░░░░░░ resetting" "$out"
contains "tokens under 1000 are not rounded to k" "900/200k" "$out"

rm -rf "$repo" "$plain"
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
