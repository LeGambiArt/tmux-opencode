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
  local pct="${1:-0}" width=20
  local filled=$(( pct * width / 100 ))
  local empty=$(( width - filled ))
  local bar="" i
  for (( i=0; i<filled; i++ )); do bar="${bar}█"; done
  for (( i=0; i<empty;  i++ )); do bar="${bar}░"; done
  echo "$bar"
}

bar_color() {
  local pct="${1:-0}"
  (( pct < 50 )) && { echo "colour43";  return; }
  (( pct < 75 )) && { echo "colour221"; return; }
  (( pct < 85 )) && { echo "colour209"; return; }
  echo "colour197"
}

format_cost() {
  printf "%.2f" "${1:-0}"
}

render() {
  local marks bar color cost_fmt
  marks="$(build_marks)"
  bar="$(build_bar "${CONTEXT_PCT:-0}")"
  color="$(bar_color "${CONTEXT_PCT:-0}")"
  cost_fmt="$(format_cost "${COST_USD:-0}")"

  local model_str="#[fg=colour198,bold]✨#[fg=colour87,nobold] ${MODEL:-opencode}"
  local branch_str=""
  [[ -n "${BRANCH:-}" ]] && \
    branch_str=" #[fg=colour243]│ #[fg=colour141]🌿 ${BRANCH}${marks}#[default]"
  local ctx_str=" #[fg=colour243]│ #[fg=${color}]🧠 ${bar} ${CONTEXT_PCT:-0}%%#[default]"
  local cost_str=" #[fg=colour243]│ #[fg=colour114]💰 \$${cost_fmt}#[default]"

  printf '%s' "${model_str}${branch_str}${ctx_str}${cost_str}"
}

main() {
  is_stale && exit 0
  render
}

main
