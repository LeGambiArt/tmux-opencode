#!/usr/bin/env bash
set -euo pipefail

STATE="$HOME/.config/opencode/plugins/tmux-opencode/statusline-state.sh"

[[ -f "$STATE" ]] || exit 0

# shellcheck source=/dev/null
source "$STATE"

# ---------------------------------------------------------------------------
# Nerd Font hardcoded fallbacks (emergency only — set via utils.sh load_theme)
# ---------------------------------------------------------------------------
_ICON_MODEL=$'\U000F1102'    # 🔮  nf-md-crystal_ball
_ICON_BRANCH=$'\U000F062C'   # 🌿  nf-md-source_branch
_ICON_BAR=$'\uE28C'          # 🧠  nf-fae-brain
_ICON_COST=$'\uF0D6'         # 💰  nf-fa-money_bill
_ICON_SESSION=$'\U000F0379'  # 💻  nf-md-monitor

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

tmux_opt() {
  local key="$1" default="${2:-}"
  local val
  val="$(tmux show-option -gqv "$key" 2>/dev/null || true)"
  [[ -n "$val" ]] && printf '%s' "$val" || printf '%s' "$default"
}

# resolve_opt: user key → theme key → hardcoded fallback
# Use for non-colour options: icons, chars, plugin list, separator.
resolve_opt() {
  local user_key="$1" theme_key="$2" fallback="$3"
  local val
  val="$(tmux_opt "$user_key" '')"; [[ -n "$val" ]] && { printf '%s' "$val"; return; }
  val="$(tmux_opt "$theme_key" '')"; [[ -n "$val" ]] && { printf '%s' "$val"; return; }
  printf '%s' "$fallback"
}

# resolve_fg: per-plugin user → global user → per-plugin theme → global theme → fallback
# plugin: e.g. "model", "branch", "pct", "cost", "session"
resolve_fg() {
  local p="$1" fb="$2"
  local val
  val="$(tmux_opt "@opencode-statusline-${p}-fg" '')"; [[ -n "$val" ]] && { printf '%s' "$val"; return; }
  val="$(tmux_opt "@opencode-statusline-fg"       '')"; [[ -n "$val" ]] && { printf '%s' "$val"; return; }
  val="$(tmux_opt "@opencode-theme-${p}-fg"       '')"; [[ -n "$val" ]] && { printf '%s' "$val"; return; }
  val="$(tmux_opt "@opencode-theme-fg"            '')"; [[ -n "$val" ]] && { printf '%s' "$val"; return; }
  printf '%s' "$fb"
}

# resolve_bg: same chain for background colours
resolve_bg() {
  local p="$1" fb="$2"
  local val
  val="$(tmux_opt "@opencode-statusline-${p}-bg" '')"; [[ -n "$val" ]] && { printf '%s' "$val"; return; }
  val="$(tmux_opt "@opencode-statusline-bg"       '')"; [[ -n "$val" ]] && { printf '%s' "$val"; return; }
  val="$(tmux_opt "@opencode-theme-${p}-bg"       '')"; [[ -n "$val" ]] && { printf '%s' "$val"; return; }
  val="$(tmux_opt "@opencode-theme-bg"            '')"; [[ -n "$val" ]] && { printf '%s' "$val"; return; }
  printf '%s' "$fb"
}

# global_fg: user global → theme global → fallback
# Used to restore text colour after progress bar overwrites fg.
global_fg() {
  local fb="${1:-colour255}"
  local val
  val="$(tmux_opt '@opencode-statusline-fg' '')"; [[ -n "$val" ]] && { printf '%s' "$val"; return; }
  val="$(tmux_opt '@opencode-theme-fg'      '')"; [[ -n "$val" ]] && { printf '%s' "$val"; return; }
  printf '%s' "$fb"
}

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

# build_bar: emits inline #[fg=...] codes for filled and empty portions.
# Does NOT append #[default] — caller restores text colour explicitly.
build_bar() {
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
  printf '%s' "$bar"
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

# ---------------------------------------------------------------------------
# Render
# ---------------------------------------------------------------------------

render() {

  # Helper: build a plugin part with optional per-plugin background.
  # When a bg is set, adds a leading space (block padding). No trailing space
  # so that an empty separator glues blocks directly together.
  # When no bg, plain fg-only text — the separator provides spacing.
  plugin_part() {
    local pfg="$1" pbg="$2" content="$3"
    if [[ -n "$pbg" ]]; then
      printf '%s' "#[bg=${pbg}]#[fg=${pfg}] ${content}"
    else
      printf '%s' "#[fg=${pfg}]${content}"
    fi
  }

  # get_separator: resolves the separator properly, distinguishing between
  # "explicitly set to empty string" (circle theme) and "not set" (fallback).
  # tmux show-option -gq prints the key line when set (even to ""), nothing
  # when not set — unlike -gqv which cannot distinguish the two cases.
  get_separator() {
    if [[ -n "$(tmux show-option -gq '@opencode-statusline-separator' 2>/dev/null)" ]]; then
      tmux show-option -gqv '@opencode-statusline-separator' 2>/dev/null || true
      return
    fi
    if [[ -n "$(tmux show-option -gq '@opencode-theme-separator' 2>/dev/null)" ]]; then
      tmux show-option -gqv '@opencode-theme-separator' 2>/dev/null || true
      return
    fi
    printf '%s' " │ "
  }

  local plugins bar_width session_max separator

  plugins="$(resolve_opt \
    '@opencode-statusline-plugins' \
    '@opencode-theme-plugins' \
    'model branch progressbar percentage cost')"
  bar_width="$(resolve_opt \
    '@opencode-statusline-bar-width' \
    '@opencode-theme-bar-width' '10')"
  session_max="$(resolve_opt \
    '@opencode-statusline-session-max-len' \
    '@opencode-theme-session-max-len' '20')"
  separator="$(get_separator)"

  local icon_model icon_branch icon_bar icon_cost icon_session
  icon_model="$(resolve_opt \
    '@opencode-statusline-icon-model'   '@opencode-theme-icon-model'   "$_ICON_MODEL")"
  icon_branch="$(resolve_opt \
    '@opencode-statusline-icon-branch'  '@opencode-theme-icon-branch'  "$_ICON_BRANCH")"
  icon_bar="$(resolve_opt \
    '@opencode-statusline-icon-bar'     '@opencode-theme-icon-bar'     "$_ICON_BAR")"
  icon_cost="$(resolve_opt \
    '@opencode-statusline-icon-cost'    '@opencode-theme-icon-cost'    "$_ICON_COST")"
  icon_session="$(resolve_opt \
    '@opencode-statusline-icon-session' '@opencode-theme-icon-session' "$_ICON_SESSION")"

  # Anchor the background for our entire segment.
  # Any inline #[bg=...] from preceding status-right content is overridden here,
  # ensuring the theme's background applies consistently across all plugins.
  # When no theme bg is set (default theme) the prefix is empty — no-op.
  local theme_bg prefix=""
  theme_bg="$(tmux_opt '@opencode-theme-status-bg' '')"
  [[ -n "$theme_bg" ]] && prefix="#[bg=${theme_bg}]"

  local parts=()
  local plugin bar marks cost_fmt name title fg bg text_color

  for plugin in $plugins; do
    case "$plugin" in
      model)
        fg="$(resolve_fg 'model' 'colour87')"
        bg="$(resolve_bg 'model' '')"
        name="${MODEL_DISPLAY:-${MODEL:-opencode}}"
        parts+=("$(plugin_part "$fg" "$bg" "${icon_model} ${name}")")
        ;;
      branch)
        [[ -n "${BRANCH:-}" ]] || continue
        fg="$(resolve_fg 'branch' 'colour141')"
        bg="$(resolve_bg 'branch' '')"
        marks="$(build_marks)"
        parts+=("$(plugin_part "$fg" "$bg" "${icon_branch} ${BRANCH}${marks}")")
        ;;
      progressbar)
        local fill_color empty_color filled_char empty_char
        fill_color="$(resolve_opt \
          '@opencode-statusline-bar-filled-color' \
          '@opencode-theme-bar-filled-color' '')"
        [[ -z "$fill_color" ]] && fill_color="$(bar_color "${CONTEXT_PCT:-0}")"
        empty_color="$(resolve_opt \
          '@opencode-statusline-bar-empty-color' \
          '@opencode-theme-bar-empty-color' 'colour236')"
        filled_char="$(resolve_opt \
          '@opencode-statusline-bar-filled-char' \
          '@opencode-theme-bar-filled-char' '█')"
        empty_char="$(resolve_opt \
          '@opencode-statusline-bar-empty-char' \
          '@opencode-theme-bar-empty-char' '░')"
        bar="$(build_bar "${CONTEXT_PCT:-0}" "$bar_width" \
               "$filled_char" "$empty_char" "$fill_color" "$empty_color")"
        # Restore global text colour after bar's two-colour inline codes.
        bg="$(resolve_bg 'bar' '')"
        text_color="$(global_fg 'colour255')"
        if [[ -n "$bg" ]]; then
          parts+=("#[bg=${bg}]#[fg=${text_color}] ${icon_bar} ${bar}#[fg=${text_color}] ")
        else
          parts+=("${icon_bar} ${bar}#[fg=${text_color}]")
        fi
        ;;
      percentage)
        fg="$(resolve_fg 'pct' "$(bar_color "${CONTEXT_PCT:-0}")")"
        bg="$(resolve_bg 'pct' '')"
        # Single % — tmux does NOT strftime-expand #(command) output
        parts+=("$(plugin_part "$fg" "$bg" "${CONTEXT_PCT:-0}%")")
        ;;
      cost)
        fg="$(resolve_fg 'cost' 'colour114')"
        bg="$(resolve_bg 'cost' '')"
        cost_fmt="$(format_cost "${COST_USD:-0}")"
        parts+=("$(plugin_part "$fg" "$bg" "${icon_cost} \$${cost_fmt}")")
        ;;
      session)
        [[ -n "${SESSION_TITLE:-}" ]] || continue
        fg="$(resolve_fg 'session' 'colour243')"
        bg="$(resolve_bg 'session' '')"
        title="${SESSION_TITLE:0:$session_max}"
        if [[ "${#SESSION_TITLE}" -gt "$session_max" ]]; then
          title="${title}…"
        fi
        parts+=("$(plugin_part "$fg" "$bg" "${icon_session} ${title}")")
        ;;
      *) continue ;;
    esac
  done

  local sep_fg
  sep_fg="$(resolve_fg 'separator' 'colour243')"
  # Restore theme bg between plugin parts.
  local sep_bg_reset=""
  [[ -n "$theme_bg" ]] && sep_bg_reset="#[bg=${theme_bg}]"
  # separator is emitted as-is — spaces are the separator value's responsibility.
  # default.conf uses " │ " (spaces embedded). circle uses "" (glue blocks).
  local sep_str
  if [[ -n "$separator" ]]; then
    sep_str="${sep_bg_reset}#[fg=${sep_fg}]${separator}"
  else
    sep_str="${sep_bg_reset}"
  fi

  local out="" i
  for (( i=0; i<${#parts[@]}; i++ )); do
    [[ $i -gt 0 ]] && out+="$sep_str"
    out+="${parts[$i]}"
  done

  # ── Edge glyphs ─────────────────────────────────────────────────────────────
  # Left edge: rendered before the first segment to avoid collision with
  # adjacent status-right content (clock, window list, etc.).
  # Right edge: rendered after the last segment as a visual closing boundary.
  # FG colour resolves: @opencode-statusline-*-edge-fg → @opencode-theme-*-edge-fg → sep_fg
  local left_edge right_edge
  left_edge="$(tmux show-option -gqv '@opencode-statusline-left-edge'  2>/dev/null || \
               tmux show-option -gqv '@opencode-theme-left-edge'        2>/dev/null || true)"
  right_edge="$(tmux show-option -gqv '@opencode-statusline-right-edge' 2>/dev/null || \
                tmux show-option -gqv '@opencode-theme-right-edge'       2>/dev/null || true)"

  if [[ -n "$left_edge" ]]; then
    local le_fg
    le_fg="$(tmux show-option -gqv '@opencode-statusline-left-edge-fg' 2>/dev/null || \
             tmux show-option -gqv '@opencode-theme-left-edge-fg'       2>/dev/null || \
             echo "$sep_fg")"
    local le_bg_reset=""
    [[ -n "$theme_bg" ]] && le_bg_reset="#[bg=${theme_bg}]"
    out="${le_bg_reset}#[fg=${le_fg}]${left_edge}${out}"
  fi

  if [[ -n "$right_edge" ]]; then
    local re_fg
    re_fg="$(tmux show-option -gqv '@opencode-statusline-right-edge-fg' 2>/dev/null || \
             tmux show-option -gqv '@opencode-theme-right-edge-fg'       2>/dev/null || \
             echo "$sep_fg")"
    out+="#[bg=default]#[fg=${re_fg}]${right_edge}#[bg=default]"
  fi

  printf '%s' "${prefix}${out}"
}

main() {
  if is_stale; then exit 0; fi
  render
}

main
