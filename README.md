# tmux-opencode

A [Tmux Plugin Manager (TPM)](https://github.com/tmux-plugins/tpm) plugin
that adds an OpenCode status bar to tmux. Displays model, git branch,
context window usage, session cost, and active session name.

Fully standalone — no theme plugin dependency required. Ships with
13 built-in themes selected with a single option.

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
| `default` | Plain tmux colours, Nerd Font icons, gradient bar |
| `classic` | Dark grey bg, white text, block bar |
| `dashboard` | Dark green bg, bright green text, session-aware |
| `neon-punk` | Black bg, hot-pink text, emoji icons |
| `cyberpunk` | Dark navy bg, neon-yellow text, diamond bar |
| `retrowave` | Deep purple bg, pink text, cyan rectangular bar |
| `steel` | Dark bg, steel-blue text, block bar |
| `orange` | Grey bg, orange text, dot `●○` bar |
| `minimal` | Dark bg, cyan text — no progress bar |
| `redalert` | White bg, red text, heavy-circle bar |
| `matrix` | True-black bg, bright-green text, heavy-circle bar |
| `diamond` | Deep-purple bg, cyan text, diamond ◆◇ bar |
| `purple` | Dark bg, light-purple text, rectangular bar |

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

Leave `bar-filled-color` unset for the built-in green→yellow→red gradient.

### Icons

    # Switch to emoji (works without Nerd Fonts)
    set -g @opencode-statusline-icon-model   "✨"
    set -g @opencode-statusline-icon-branch  "🌿"
    set -g @opencode-statusline-icon-bar     "🧠"
    set -g @opencode-statusline-icon-cost    "💰"
    set -g @opencode-statusline-icon-session "💻"

    # Hide an icon
    set -g @opencode-statusline-icon-cost ""

| Option | Default glyph | Codepoint | Emoji fallback |
|--------|--------------|-----------|---------------|
| `@opencode-statusline-icon-model` | nf-md-globe_model | U+F08E9 | `✨` |
| `@opencode-statusline-icon-branch` | nf-cod-git_branch | U+EC6F | `🌿` |
| `@opencode-statusline-icon-bar` | nf-fae-brain | U+E28C | `🧠` |
| `@opencode-statusline-icon-cost` | nf-fa-money_bill | U+F0D6 | `💰` |
| `@opencode-statusline-icon-session` | nf-cod-terminal_bash | U+EBCA | `💻` |

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
