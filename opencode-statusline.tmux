#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/scripts/utils.sh"

install() {
  register_opencode_plugin
  load_theme
  apply_status_style
  setup_status_bar
  set_refresh_interval
}

uninstall() {
  unregister_opencode_plugin
  cleanup_plugin_cache
  teardown_status_bar
  cleanup_state_dir
  cleanup_tpm_plugin
  echo ""
  echo "Uninstall complete."
  echo "Remove or comment out the tmux-opencode line in ~/.tmux.conf, then run:"
  echo "  tmux source-file ~/.tmux.conf"
}

main() {
  local cmd="${1:-install}"
  case "$cmd" in
    install)   install ;;
    uninstall) uninstall ;;
    *) echo "Usage: $(basename "$0") [install|uninstall]" >&2; exit 1 ;;
  esac
}

main "$@"
