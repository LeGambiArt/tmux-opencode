#!/usr/bin/env bash

STATE="$HOME/.config/opencode/plugins/tmux-opencode/statusline-state.sh"

[[ -f "$STATE" ]] || exit 0

# shellcheck source=/dev/null
source "$STATE"

is_stale() {
  local now
  now="$(date +%s)"
  (( now - UPDATED_AT > 1800 ))
}

build_marks() {
  local marks=""
  [[ "${STAGED:-0}" == "1" ]] && marks="${marks}+"
  [[ "${DIRTY:-0}"  == "1" ]] && marks="${marks}●"
  echo "$marks"
}

build_bar() {
  local pct="${1:-0}" width=10
  local filled=$(( pct * width / 100 ))
  local empty=$(( width - filled ))
  local bar="" i
  for (( i=0; i<filled; i++ )); do bar="${bar}█"; done
  for (( i=0; i<empty;  i++ )); do bar="${bar}░"; done
  echo "$bar"
}

format_cost() {
  printf "%.2f" "${1:-0}"
}

render() {
  local marks bar cost_fmt
  marks="$(build_marks)"
  bar="$(build_bar "${CONTEXT_PCT:-0}")"
  cost_fmt="$(format_cost "${COST_USD:-0}")"

  local out="✨ ${MODEL:-opencode}"
  [[ -n "${BRANCH:-}" ]] && out="${out} 🌿 ${BRANCH}${marks}"
  out="${out} ${bar} ${CONTEXT_PCT:-0}% \$${cost_fmt}"
  echo "$out"
}

main() {
  is_stale && exit 0
  render
}

main
