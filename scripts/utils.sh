#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PLUGIN_DIR="$( cd "$CURRENT_DIR/.." && pwd )"

readonly PLUGIN_SPEC="tmux-opencode@git+https://github.com/mrbrandao/tmux-opencode.git"
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
  local tpm_plugin_dir="$HOME/.tmux/plugins/tmux-opencode"
  [[ -d "$tpm_plugin_dir" ]] || return
  rm -rf "$tpm_plugin_dir"
  echo "Removed TPM plugin dir: $tpm_plugin_dir"
}

# ---------------------------------------------------------------------------
# tmux status bar setup and teardown
# ---------------------------------------------------------------------------

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
  [[ "$current_right" == *"$script"* ]] && return
  tmux set-option -ga status-right " #($script)"
  tmux set-option -g status-right-length 200
}

teardown_status_bar() {
  local dracula_dir
  if dracula_dir="$(detect_dracula)"; then
    rm -f "$dracula_dir/opencode-statusline"
    return
  fi
  local script="$PLUGIN_DIR/scripts/status.sh"
  local entry=" #($script)"
  local current_right
  current_right="$(tmux show-option -gv "status-right" 2>/dev/null || true)"
  [[ "$current_right" == *"$script"* ]] || return
  tmux set-option -g status-right "${current_right/$entry/}"
}

set_refresh_interval() {
  local interval
  interval="$(get_tmux_option "@opencode-statusline-refresh" "5")"
  tmux set-option -g status-interval "$interval"
}
