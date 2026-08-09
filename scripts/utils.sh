#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PLUGIN_DIR="$( cd "$CURRENT_DIR/.." && pwd )"

readonly PLUGIN_SPEC="tmux-opencode@git+https://github.com/LeGambiArt/tmux-opencode.git"
readonly OPENCODE_CONFIG_DIR="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"
readonly OPENCODE_CACHE_DIR="${OPENCODE_CACHE_DIR:-$HOME/.cache/opencode}"

# ---------------------------------------------------------------------------
# tmux helpers
# ---------------------------------------------------------------------------

get_tmux_option() {
  local option="$1"
  local default="$2"
  local value
  value="$(tmux show-option -gqv "$option")"
  [[ -z "$value" ]] && echo "$default" || echo "$value"
}

# ---------------------------------------------------------------------------
# opencode plugin registration
# ---------------------------------------------------------------------------

_resolve_config_file() {
  local config_file=""
  [[ -f "$OPENCODE_CONFIG_DIR/opencode.jsonc" ]] && \
    config_file="$OPENCODE_CONFIG_DIR/opencode.jsonc"
  [[ -z "$config_file" && -f "$OPENCODE_CONFIG_DIR/opencode.json" ]] && \
    config_file="$OPENCODE_CONFIG_DIR/opencode.json"
  echo "$config_file"
}

register_opencode_plugin() {
  if ! command -v jq &>/dev/null; then
    echo "Error: jq is required to register the opencode plugin." >&2
    return 1
  fi

  local config_file
  config_file="$(_resolve_config_file)"

  if [[ -z "$config_file" ]]; then
    mkdir -p "$OPENCODE_CONFIG_DIR"
    config_file="$OPENCODE_CONFIG_DIR/opencode.jsonc"
    printf '{"plugin":["%s"]}\n' "$PLUGIN_SPEC" > "$config_file"
    echo "Created $config_file with tmux-opencode plugin entry."
    return
  fi

  if jq -e --arg spec "$PLUGIN_SPEC" \
       '.plugin // [] | contains([$spec])' "$config_file" > /dev/null 2>&1; then
    return
  fi

  local tmpfile
  tmpfile="$(mktemp)"
  jq --arg spec "$PLUGIN_SPEC" '
    if .plugin then .plugin += [$spec]
    else . + {"plugin": [$spec]}
    end
  ' "$config_file" > "$tmpfile" && mv "$tmpfile" "$config_file"

  echo "Registered tmux-opencode in $config_file"
}

unregister_opencode_plugin() {
  if ! command -v jq &>/dev/null; then
    echo "Error: jq is required to unregister the opencode plugin." >&2
    return 1
  fi

  local config_file
  config_file="$(_resolve_config_file)"

  [[ -z "$config_file" ]] && return

  if ! jq -e --arg spec "$PLUGIN_SPEC" \
        '.plugin // [] | contains([$spec])' "$config_file" > /dev/null 2>&1; then
    return
  fi

  local tmpfile
  tmpfile="$(mktemp)"
  jq --arg spec "$PLUGIN_SPEC" '.plugin -= [$spec]' \
    "$config_file" > "$tmpfile" && mv "$tmpfile" "$config_file"

  echo "Unregistered tmux-opencode from $config_file"
}

# ---------------------------------------------------------------------------
# opencode plugin cache and state cleanup
# ---------------------------------------------------------------------------

cleanup_plugin_cache() {
  local cache_base="$OPENCODE_CACHE_DIR/packages"
  for path in "$cache_base"/tmux-opencode@*; do
    [[ -d "$path" ]] || continue
    rm -rf "$path"
    echo "Removed plugin cache: $path"
  done
}

cleanup_state_dir() {
  local state_dir="$OPENCODE_CONFIG_DIR/plugins/tmux-opencode"
  [[ -d "$state_dir" ]] || return
  rm -rf "$state_dir"
  echo "Removed state dir: $state_dir"
}

cleanup_tpm_plugin() {
  local tpm_plugin_dir="$PLUGIN_DIR"
  [[ -d "$tpm_plugin_dir" ]] || return
  rm -rf "$tpm_plugin_dir"
  echo "Removed TPM plugin dir: $tpm_plugin_dir"
}

# ---------------------------------------------------------------------------
# Theme loading
# ---------------------------------------------------------------------------

# load_theme: always sources themes/default.conf first (sets all defaults),
# then sources the selected theme (overrides only what it defines).
# If theme is "default", only default.conf is sourced.
load_theme() {
  local theme
  theme="$(get_tmux_option '@opencode-tmux-theme' 'default')"
  # Step 1: always load defaults (colours, bar chars, plugins, separator, etc.)
  tmux source-file "$PLUGIN_DIR/themes/default.conf"
  # Step 2: set icon defaults via bash — tmux source-file cannot parse
  # $'\uXXXX' Unicode escape sequences; bash interprets them correctly here.
  # Named themes that want different icons set the actual UTF-8 glyph directly
  # (e.g. set -g @opencode-theme-icon-model "✨") and are sourced after these.
  tmux set-option -g '@opencode-theme-icon-model'   $'\U000F1102'  # 🔮  crystal_ball
  tmux set-option -g '@opencode-theme-icon-branch'  $'\U000F062C'  # 🌿  source_branch
  tmux set-option -g '@opencode-theme-icon-bar'     $'\uE28C'      # 🧠  brain
  tmux set-option -g '@opencode-theme-icon-cost'    $'\uF0D6'      # 💰  money_bill
  tmux set-option -g '@opencode-theme-icon-session' $'\U000F0379'  # 💻  monitor
  # Step 3: load selected theme on top (skipped when theme == "default")
  if [[ "$theme" != "default" ]]; then
    local theme_file="$PLUGIN_DIR/themes/${theme}.conf"
    if [[ -f "$theme_file" ]]; then
      tmux source-file "$theme_file"
    else
      tmux display-message \
        "opencode-statusline: unknown theme '${theme}', using default"
    fi
  fi
}

# apply_status_style: reads @opencode-theme-status-bg/fg (set by theme)
# and applies status-style. When no theme defines colours (default theme),
# resets status-style to tmux's own default so previous theme colours
# do not bleed through on theme switch.
apply_status_style() {
  local bg fg
  bg="$(get_tmux_option '@opencode-theme-status-bg' '')"
  fg="$(get_tmux_option '@opencode-theme-status-fg' '')"
  if [[ -n "$bg" && -n "$fg" ]]; then
    tmux set-option -g status-style "bg=${bg},fg=${fg}"
  else
    tmux set-option -gu status-style
  fi
}

# ---------------------------------------------------------------------------
# tmux status bar setup and teardown
# ---------------------------------------------------------------------------

# setup_status_bar: APPENDS to status-right — never replaces.
# Cooperates with battery, cpu, powerline, and other status-right consumers.
setup_status_bar() {
  local script="$PLUGIN_DIR/scripts/status.sh"
  local current_right
  current_right="$(tmux show-option -gv 'status-right' 2>/dev/null || true)"
  # Idempotent: skip if the script is already in status-right
  [[ "$current_right" == *"$script"* ]] && return
  tmux set-option -ga status-right " #($script)"
  tmux set-option -g  status-right-length 200
}

teardown_status_bar() {
  local script="$PLUGIN_DIR/scripts/status.sh"
  local entry=" #($script)"
  local current_right
  current_right="$(tmux show-option -gv 'status-right' 2>/dev/null || true)"
  [[ "$current_right" == *"$script"* ]] || return
  tmux set-option -g status-right "${current_right/$entry/}"
}

set_refresh_interval() {
  local interval
  interval="$(get_tmux_option '@opencode-statusline-refresh' \
              "$(get_tmux_option '@opencode-theme-refresh' '5')")"
  tmux set-option -g status-interval "$interval"
}
