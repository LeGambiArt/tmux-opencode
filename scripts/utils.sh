#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PLUGIN_DIR="$( cd "$CURRENT_DIR/.." && pwd )"

get_tmux_option() {
  local option="$1"
  local default="$2"
  local value
  value="$(tmux show-option -gqv "$option")"
  [[ -z "$value" ]] && echo "$default" || echo "$value"
}

install_opencode_plugin() {
  local config_dir="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"
  local plugin_dir="$config_dir/plugins"
  mkdir -p "$plugin_dir"
  cp "$PLUGIN_DIR/opencode/statusline-plugin.js" \
    "$plugin_dir/statusline-plugin.js"
}

detect_dracula() {
  local paths=(
    "$HOME/.tmux/plugins/tmux/scripts"
    "$HOME/.tmux/plugins/dracula/scripts"
    "${XDG_CONFIG_HOME:-$HOME/.config}/tmux/plugins/tmux/scripts"
    "${XDG_CONFIG_HOME:-$HOME/.config}/tmux/plugins/dracula/scripts"
  )
  local p
  for p in "${paths[@]}"; do
    [[ -d "$p" ]] && echo "$p" && return 0
  done
  return 1
}

setup_status_bar() {
  local dracula_dir
  if dracula_dir="$(detect_dracula)"; then
    cp "$PLUGIN_DIR/scripts/dracula-segment.sh" \
      "$dracula_dir/opencode-statusline"
    chmod +x "$dracula_dir/opencode-statusline"
    tmux display-message \
      "opencode-statusline: add 'custom:opencode-statusline' to @dracula-plugins"
    return
  fi
  local script="$PLUGIN_DIR/scripts/status.sh"
  local current_right
  current_right="$(tmux show-option -gv "status-right" 2>/dev/null || true)"
  [[ "$current_right" == *"$script"* ]] && return 0
  tmux set-option -ga status-right " #($script)"
  tmux set-option -g status-right-length 200
}

set_refresh_interval() {
  local interval
  interval="$(get_tmux_option "@opencode-statusline-refresh" "5")"
  tmux set-option -g status-interval "$interval"
}
