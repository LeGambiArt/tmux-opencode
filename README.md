# tmux-opencode

A [Tmux Plugin Manager (TPM)](https://github.com/tmux-plugins/tpm) plugin
that adds an OpenCode status bar to tmux. Displays model, git branch,
context window usage, and session cost. Supports raw tmux and the
[Dracula theme](https://github.com/dracula/tmux).

## Requirements

- [OpenCode](https://opencode.ai) ≥ 1.18
- tmux ≥ 3.0
- bash ≥ 4.0
- jq ≥ 1.6

## Install

Add to `~/.tmux.conf` before the `run` line that loads TPM:

    set -g @plugin 'mrbrandao/tmux-opencode'

Press `prefix + I` inside a tmux session to install.

## Configuration

Add to `~/.tmux.conf` before the TPM `run` line or the manual
`source`/`run` line:

    # Refresh interval in seconds (default: 5)
    set -g @opencode-statusline-refresh 5

## Dracula theme

If you use the [Dracula tmux theme](https://github.com/dracula/tmux),
the plugin auto-detects it and installs a segment automatically. After
installation, add `custom:opencode-statusline` to your `@dracula-plugins`
list in `~/.tmux.conf`:

    set -g @dracula-plugins "cpu-usage battery time custom:opencode-statusline"

To set the segment colors, also add:

    set -g @dracula-custom-plugin-colors "cyan dark_gray"

Available Dracula colors: `dark_gray` `gray` `dark_purple` `light_purple`
`cyan` `green` `orange` `red` `pink` `yellow` `white`

## License

[GPL-3.0-only](LICENSE)
