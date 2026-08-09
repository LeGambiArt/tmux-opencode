# tmux-opencode

A [Tmux Plugin Manager (TPM)](https://github.com/tmux-plugins/tpm) plugin
that adds an OpenCode status bar to tmux. Displays model, git branch,
context window usage, session cost, and active session name.

Fully standalone — no theme plugin dependency required. Ships with
15 built-in themes selected with a single option.

## Requirements

- [OpenCode](https://opencode.ai) ≥ 1.18
- tmux ≥ 3.0
- bash ≥ 4.2
- jq ≥ 1.6
- [Nerd Fonts](https://www.nerdfonts.com) (recommended for default icons;
  the `neon-punk` theme uses emoji and works without Nerd Fonts)

## Install

Add to `~/.tmux.conf` before the `run` line that loads TPM:

    set -g @plugin 'LeGambiArt/tmux-opencode'

Press `prefix + I` inside a tmux session to install.

### Manual uninstall

    ~/.tmux/plugins/tmux-opencode/opencode-statusline.tmux uninstall

Then remove or comment out the `@plugin` line and run
`tmux source-file ~/.tmux.conf`.

## Themes

Select a theme with one line:

    set -g @opencode-tmux-theme "matrix"

Available themes:

| Theme | Look |
|-------|------|
| `default` | Plain tmux colours, blue bar, all text inherits terminal fg |
| `classic` | Dark grey bg, white text, green→yellow→red gradient bar |
| `forest` | Dark green bg, bright green text, session-aware |
| `neon-punk` | Black bg, hot-pink text, emoji icons — no Nerd Font needed |
| `darkblue` | Dark navy bg, neon-yellow text, diamond `◆◇` bar |
| `cyberpunk` | Black bg, magenta+yellow+cyan neon — heavy-circle `▰▱` bar |
| `retrowave` | Deep purple bg, pink text, cyan rectangular `▮▯` bar |
| `steel` | Dark bg, steel-blue text, block bar |
| `orange` | Grey bg, orange text, dot `●○` bar |
| `minimal` | Dark bg, cyan text — no progress bar |
| `redalert` | White bg, red text, heavy-circle `▰▱` bar |
| `matrix` | True-black bg, bright-green text, heavy-circle `▰▱` bar |
| `diamond` | Deep-purple bg, cyan text, diamond `◆◇` bar |
| `purple` | Dark bg, light-purple text, rectangular `▮▯` bar |
| `circle` | Deep ocean bg, per-plugin neon colours, dot `●○` bar, 💵 cost |

See the [examples gallery](docs/examples.md) for screenshots of every theme.

## Configuration

All options go in `~/.tmux.conf`. Theme settings take effect on the next
`tmux source-file ~/.tmux.conf` (or `prefix + I` reinstall).

### Cooperating with other status-right plugins

The plugin **appends** to your existing `status-right` — it never replaces it.
Battery, cpu, date/time, powerline, and other plugins remain untouched:

    # Your existing status-right content is preserved
    set -g status-right "#{battery_icon} #{cpu_percentage}%  %H:%M"
    # tmux-opencode appends its segment automatically

### Override individual colours

User options (`@opencode-statusline-*`) always win over theme defaults:

    # Global fg for all plugins
    set -g @opencode-statusline-fg "colour82"

    # Per-plugin fg (overrides global)
    set -g @opencode-statusline-model-fg "colour200"
    set -g @opencode-statusline-cost-fg  "colour220"

    # Per-plugin bg
    set -g @opencode-statusline-model-bg "colour235"

Available plugin names: `model`, `branch`, `pct`, `cost`, `session`, `separator`

### Plugin list

    # Choose what to display and in what order
    set -g @opencode-statusline-plugins "session model branch progressbar percentage cost"

| Name | Shows | Default |
|------|-------|---------|
| `model` | Current AI model name | ✓ |
| `branch` | Git branch + dirty/staged marks | ✓ |
| `progressbar` | Context window fill bar | ✓ |
| `percentage` | Context window percentage | ✓ |
| `cost` | Cumulative session cost in USD | ✓ |
| `session` | OpenCode session title | — |

`branch` is silently skipped outside git repositories.
`session` is skipped until OpenCode generates a title.

### Bar appearance

    set -g @opencode-statusline-bar-filled-char  "▰"
    set -g @opencode-statusline-bar-empty-char   "▱"
    set -g @opencode-statusline-bar-filled-color "colour46"
    set -g @opencode-statusline-bar-empty-color  "colour22"
    set -g @opencode-statusline-bar-width        "12"

Each named theme sets its own bar characters and colours. To use the
built-in green→yellow→red gradient, unset `bar-filled-color`:

    set -gu @opencode-statusline-bar-filled-color

### Icons

Default icons require a [Nerd Font](https://www.nerdfonts.com) installed and
configured in your terminal emulator. If a glyph renders as a box, use the
emoji fallback shown below.

    # Switch to emoji fallbacks (works without Nerd Fonts)
    set -g @opencode-statusline-icon-model   "🔮"
    set -g @opencode-statusline-icon-branch  "🌿"
    set -g @opencode-statusline-icon-bar     "🧠"
    set -g @opencode-statusline-icon-cost    "💰"
    set -g @opencode-statusline-icon-session "💻"

    # Hide an icon
    set -g @opencode-statusline-icon-cost ""

| Option | Default glyph | Codepoint | Emoji fallback |
|--------|--------------|-----------|----------------|
| `@opencode-statusline-icon-model` | nf-md-crystal_ball | U+F1102 | `🔮` |
| `@opencode-statusline-icon-branch` | nf-md-source_branch | U+F062C | `🌿` |
| `@opencode-statusline-icon-bar` | nf-fae-brain | U+E28C | `🧠` |
| `@opencode-statusline-icon-cost` | nf-md-coin | U+F0DEA | `💰` or `💵` |
| `@opencode-statusline-icon-session` | nf-md-monitor | U+F0379 | `💻` |

### Other options

    set -g @opencode-statusline-refresh         "2"   # refresh every 2s (default: 5)
    set -g @opencode-statusline-session-max-len "15"  # truncate session title at 15 chars
    set -g @opencode-statusline-separator       "·"   # custom separator between segments

### Colour reference

tmux accepts colours in three formats:

- **`colourN`** — 256-colour palette 0–255 (most portable).
  [256 Colors Cheat Sheet](https://www.ditig.com/256-colors-cheat-sheet)
- **Named** — `black`, `red`, `green`, `yellow`, `blue`, `magenta`, `cyan`,
  `white`, `default`, and bright variants (`brightred`, etc.)
- **Hex `#rrggbb`** — requires tmux ≥ 3.2

## Examples

See the [theme gallery](docs/examples.md) for screenshots and
one-line config for every theme.

## Contributing / Extending

See [docs/dev-guide.md](docs/dev-guide.md) for how to create new themes
and plugins.

## License

[GPL-3.0-only](LICENSE)
