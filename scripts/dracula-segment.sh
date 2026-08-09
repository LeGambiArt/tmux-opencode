#!/usr/bin/env bash
set -euo pipefail

STATE="$HOME/.config/opencode/plugins/tmux-opencode/statusline-state.sh"

[[ -f "$STATE" ]] || exit 0

# shellcheck source=/dev/null
source "$STATE"

# ---------------------------------------------------------------------------
# Nerd Font glyph defaults — requires a Nerd Font installed and configured
# If a glyph appears as a box or question mark, copy the emoji shown in the
# comment and use it as your tmux option value instead, for example:
#   set -g @opencode-statusline-icon-model "✨"
# ---------------------------------------------------------------------------
DEFAULT_ICON_MODEL=$'\U000F08E9'    # ✨  nf-md-globe_model
DEFAULT_ICON_BRANCH=$'\uEC6F'       # 🌿  nf-cod-git_branch
DEFAULT_ICON_BAR=$'\uE28C'          # 🧠  nf-fae-brain
DEFAULT_ICON_COST=$'\uEFC8'         # 💰  nf-fa-money_bill_1_wave
DEFAULT_ICON_SESSION=$'\uEBCA'      # 💻  nf-cod-terminal_bash  (alt: $'\uF489' nf-oct-terminal)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

is_stale() {
  local now
  now="$(date +%s)"
  (( now - ${UPDATED_AT:-0} > 1800 ))
}

build_marks() {
  local marks=""
  [[ "${STAGED:-0}" == "1" ]] && marks="${marks}+"
  [[ "${DIRTY:-0}"  == "1" ]] && marks="${marks}●"
  echo "$marks"
}

build_bar() {
  # build_bar pct width filled_char empty_char filled_color empty_color
  # Emits inline #[fg=...] tmux style codes so each half has its own colour.
  local pct="${1:-0}"         width="${2:-10}"
  local filled_char="${3:-█}" empty_char="${4:-░}"
  local filled_color="${5:-}" empty_color="${6:-colour236}"
  local filled=$(( pct * width / 100 ))
  local empty=$(( width - filled ))
  local bar="" i
  if (( filled > 0 )); then
    bar+="#[fg=${filled_color}]"
    for (( i=0; i<filled; i++ )); do bar+="${filled_char}"; done
  fi
  if (( empty > 0 )); then
    bar+="#[fg=${empty_color}]"
    for (( i=0; i<empty; i++ )); do bar+="${empty_char}"; done
  fi
  bar+="#[default]"
  echo "$bar"
}

bar_color() {
  local pct="${1:-0}"
  if   (( pct < 50 )); then echo "colour43";  return; fi
  if   (( pct < 75 )); then echo "colour221"; return; fi
  if   (( pct < 85 )); then echo "colour209"; return; fi
  echo "colour197"
}

format_cost() {
  printf "%.2f" "${1:-0}"
}

tmux_opt() {
  local key="$1" default="${2:-}"
  local val
  val="$(tmux show-option -gqv "$key" 2>/dev/null || true)"
  [[ -n "$val" ]] && echo "$val" || echo "$default"
}

# ---------------------------------------------------------------------------
# Render (plain text — Dracula theme handles colours)
# ---------------------------------------------------------------------------

render() {
  # --- read all options up front ---
  local plugins bar_width session_max
  local icon_model icon_branch icon_bar icon_cost icon_session

  plugins="$(tmux_opt    '@opencode-statusline-plugins'          'model branch progressbar percentage cost')"
  bar_width="$(tmux_opt  '@opencode-statusline-bar-width'        '10')"
  session_max="$(tmux_opt '@opencode-statusline-session-max-len' '20')"

  icon_model="$(tmux_opt   '@opencode-statusline-icon-model'   "$DEFAULT_ICON_MODEL")"
  icon_branch="$(tmux_opt  '@opencode-statusline-icon-branch'  "$DEFAULT_ICON_BRANCH")"
  icon_bar="$(tmux_opt     '@opencode-statusline-icon-bar'     "$DEFAULT_ICON_BAR")"
  icon_cost="$(tmux_opt    '@opencode-statusline-icon-cost'    "$DEFAULT_ICON_COST")"
  icon_session="$(tmux_opt '@opencode-statusline-icon-session' "$DEFAULT_ICON_SESSION")"

  # --- build parts ---
  local parts=()
  local plugin bar marks cost_fmt name title

  for plugin in $plugins; do
    case "$plugin" in
      model)
        name="${MODEL_DISPLAY:-${MODEL:-opencode}}"
        parts+=("${icon_model} ${name}")
        ;;
      branch)
        [[ -n "${BRANCH:-}" ]] || continue
        marks="$(build_marks)"
        parts+=("${icon_branch} ${BRANCH}${marks}")
        ;;
      progressbar)
        local fill_color empty_color filled_char empty_char
        fill_color="$(tmux_opt '@opencode-statusline-bar-filled-color' '')"
        [[ -z "$fill_color" ]] && fill_color="$(bar_color "${CONTEXT_PCT:-0}")"
        empty_color="$(tmux_opt '@opencode-statusline-bar-empty-color' 'colour236')"
        filled_char="$(tmux_opt '@opencode-statusline-bar-filled-char' '█')"
        empty_char="$(tmux_opt  '@opencode-statusline-bar-empty-char'  '░')"
        bar="$(build_bar "${CONTEXT_PCT:-0}" "$bar_width" \
               "$filled_char" "$empty_char" "$fill_color" "$empty_color")"
        parts+=("${icon_bar} ${bar}")
        ;;
      percentage)
        parts+=("${CONTEXT_PCT:-0}%")
        ;;
      cost)
        cost_fmt="$(format_cost "${COST_USD:-0}")"
        parts+=("${icon_cost} \$${cost_fmt}")
        ;;
      session)
        [[ -n "${SESSION_TITLE:-}" ]] || continue
        title="${SESSION_TITLE:0:$session_max}"
        if [[ "${#SESSION_TITLE}" -gt "$session_max" ]]; then
          title="${title}…"
        fi
        parts+=("${icon_session} ${title}")
        ;;
      *) continue ;;
    esac
  done

  # --- join with space separator (Dracula handles visual separators) ---
  local out="" i
  for (( i=0; i<${#parts[@]}; i++ )); do
    if [[ $i -gt 0 ]]; then out+=" "; fi
    out+="${parts[$i]}"
  done

  echo "$out"
}

main() {
  if is_stale; then exit 0; fi
  render
}

main
