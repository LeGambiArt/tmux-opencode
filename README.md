# tmux-opencode

A [Tmux Plugin Manager (TPM)](https://github.com/tmux-plugins/tpm) plugin
that adds an OpenCode status bar to tmux. Displays model, git branch,
context window usage, session cost, and active session name. Supports raw
tmux and the [Dracula theme](https://github.com/dracula/tmux).

## Requirements

- [OpenCode](https://opencode.ai) ≥ 1.18
- tmux ≥ 3.0
- bash ≥ 4.2
- jq ≥ 1.6
- [Nerd Fonts](https://www.nerdfonts.com) (recommended for default icons)

## Install

Add to `~/.tmux.conf` before the `run` line that loads TPM:

    set -g @plugin 'mrbrandao/tmux-opencode'

Press `prefix + I` inside a tmux session to install.

### Manual uninstall

    ~/.tmux/plugins/tmux-opencode/opencode-statusline.tmux uninstall

Then remove or comment out the `@plugin` line in `~/.tmux.conf` and run
`tmux source-file ~/.tmux.conf`.

## Configuration

All options are set in `~/.tmux.conf` and take effect on the next tmux
refresh (no restart needed for display options, plugin restart needed for
icon changes).

### Plugins — choose what to display

    set -g @opencode-statusline-plugins "model branch progressbar percentage cost"

Control which components are shown and in what order. Available names:

| Name | Shows | Default |
|------|-------|---------|
| `model` | Current AI model name | ✓ |
| `branch` | Git branch + dirty/staged marks | ✓ |
| `progressbar` | Context window fill bar | ✓ |
| `percentage` | Context window percentage | ✓ |
| `cost` | Cumulative session cost in USD | ✓ |
| `session` | OpenCode session title | — |

`branch` is silently skipped when not inside a git repository.
`session` is skipped until OpenCode generates a title for the session.

**Compact example** (saves ~15 columns):

    set -g @opencode-statusline-plugins "model branch percentage cost"

**Session-aware example**:

    set -g @opencode-statusline-plugins "session model branch percentage cost"

### Bar width

    # Context window fill bar width in characters (default: 10)
    set -g @opencode-statusline-bar-width 10

### Bar appearance

Control the characters and colours used for the filled and empty portions of
the progress bar independently.

| Option | Default | Description |
|--------|---------|-------------|
| `@opencode-statusline-bar-filled-char` | `█` | Character for filled blocks |
| `@opencode-statusline-bar-empty-char` | `░` | Character for empty blocks |
| `@opencode-statusline-bar-filled-color` | *(gradient)* | tmux colour for fill; leave unset to keep the green → yellow → red gradient |
| `@opencode-statusline-bar-empty-color` | `colour236` | tmux colour for empty blocks (`#303030`, dark grey) |

The default empty colour (`colour236`, `#303030`) works on both Dracula's
`dark_gray` segment background (`#44475a`) and plain dark terminals.

#### Colour reference

tmux accepts colours in three formats:

- **`colourN`** — 256-colour palette number, 0–255 (most portable, works on all
  tmux versions). See the full table:
  [256 Colors Cheat Sheet](https://www.ditig.com/256-colors-cheat-sheet).
- **Named** — `black`, `red`, `green`, `yellow`, `blue`, `magenta`, `cyan`,
  `white`, `default`, and the bright variants (`brightred`, etc.).
- **Hex `#rrggbb`** — requires tmux ≥ 3.2.

Full colour and style syntax is documented in the
[tmux manual — STYLES section](https://man7.org/linux/man-pages/man1/tmux.1.html#STYLES).

The grayscale ramp (colours 232–255) is useful for bar tuning:

| colourN | Hex | Brightness | Good for |
|---------|-----|-----------|---------|
| `colour232` | `#080808` | 3% | near black |
| `colour235` | `#262626` | 14% | very dark empty blocks |
| `colour236` | `#303030` | 18% | **default empty** — Dracula + dark terminals |
| `colour237` | `#3a3a3a` | 22% | |
| `colour238` | `#444444` | 26% | ⚠ almost invisible on Dracula dark_gray |
| `colour239` | `#4e4e4e` | 30% | slightly lighter empty |
| `colour240` | `#585858` | 34% | visible lighter empty |
| `colour243` | `#767676` | 46% | mid-grey, good for dash/line style |

#### Preset examples

```bash
# ── Default: two-tone block bar ──────────────────────────────────────
# Works on Dracula dark_gray (#44475a) and standard dark terminals.
# Filled blocks use the green→yellow→red gradient; empty are dark grey.
set -g @opencode-statusline-bar-filled-char  "█"
set -g @opencode-statusline-bar-empty-char   "░"
set -g @opencode-statusline-bar-empty-color  "colour236"   # #303030

# ── Higher contrast: medium-shade empty blocks ────────────────────────
set -g @opencode-statusline-bar-filled-char  "█"
set -g @opencode-statusline-bar-empty-char   "▓"
set -g @opencode-statusline-bar-empty-color  "colour239"   # #4e4e4e

# ── Dash track: ████──────────────────────────────────────────────────
set -g @opencode-statusline-bar-filled-char  "█"
set -g @opencode-statusline-bar-empty-char   "─"
set -g @opencode-statusline-bar-empty-color  "colour243"   # #767676

# ── Fixed fill colour (override the gradient) ─────────────────────────
set -g @opencode-statusline-bar-filled-color "colour81"    # SteelBlue1  #5fd7ff
# set -g @opencode-statusline-bar-filled-color "colour80"  # Turquoise   #5fd7d7
# set -g @opencode-statusline-bar-filled-color "colour213" # Orchid1     #ff87ff
```

### Session title length

    # Maximum characters shown for session title before truncation (default: 20)
    set -g @opencode-statusline-session-max-len 20

### Refresh interval

    # Status bar refresh interval in seconds (default: 5)
    set -g @opencode-statusline-refresh 5

### Icons

Default icons use [Nerd Fonts](https://www.nerdfonts.com) glyphs. Each icon
can be overridden independently. If a glyph renders as a box or blank, use
the emoji fallback shown in the table below.

| Option | Default glyph | Codepoint | Emoji fallback |
|--------|--------------|-----------|---------------|
| `@opencode-statusline-icon-model` | nf-md-globe_model | U+F08E9 | `✨` |
| `@opencode-statusline-icon-branch` | nf-cod-git_branch | U+EC6F | `🌿` |
| `@opencode-statusline-icon-bar` | nf-fae-brain | U+E28C | `🧠` |
| `@opencode-statusline-icon-cost` | nf-fa-money_bill_1_wave | U+EFC8 | `💰` |
| `@opencode-statusline-icon-session` | nf-cod-terminal_bash | U+EBCA | `💻` |

**Example — switch to emoji fallbacks:**

    set -g @opencode-statusline-icon-model   "✨"
    set -g @opencode-statusline-icon-branch  "🌿"
    set -g @opencode-statusline-icon-bar     "🧠"
    set -g @opencode-statusline-icon-cost    "💰"
    set -g @opencode-statusline-icon-session "💻"

**Example — hide an icon:**

    set -g @opencode-statusline-icon-cost ""

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

All `@opencode-statusline-*` options work identically in Dracula mode.

## License

[GPL-3.0-only](LICENSE)
