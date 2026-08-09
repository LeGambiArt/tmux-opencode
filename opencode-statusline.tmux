#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/scripts/utils.sh"

main() {
  install_opencode_plugin
  setup_status_bar
  set_refresh_interval
}

main
