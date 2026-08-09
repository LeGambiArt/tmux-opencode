# Developer Guide

How to extend tmux-opencode with new themes and plugins.

---

## Architecture

```
opencode-statusline.tmux    TPM entry point; calls install()/uninstall()
scripts/utils.sh            Plugin registration, theme loading, status bar setup
scripts/status.sh           Renders the status bar segment every N seconds
themes/default.conf         Base defaults loaded before every theme
themes/<name>.conf          Named theme — overrides only what it defines
opencode/tmux-opencode.js   OpenCode plugin that writes state to disk
```

State is written by the OpenCode plugin to:

    ~/.config/opencode/plugins/tmux-opencode/statusline-state.sh

`status.sh` sources this file on every render cycle to read `MODEL_DISPLAY`,
`CONTEXT_PCT`, `COST_USD`, `BRANCH`, `SESSION_TITLE`, etc.

---

## Option Namespaces

| Namespace | Who uses it | Example |
|-----------|-------------|---------|
| `@opencode-theme-*` | theme files + `default.conf` | `@opencode-theme-fg` |
| `@opencode-statusline-*` | end users | `@opencode-statusline-fg` |

User options always win. Theme options are defaults the user can override.

---

## Colour Resolution Chain

For each plugin's foreground colour, `status.sh` checks in order:

1. `@opencode-statusline-<plugin>-fg` — per-plugin user override
2. `@opencode-statusline-fg` — global user override
3. `@opencode-theme-<plugin>-fg` — per-plugin theme colour
4. `@opencode-theme-fg` — global theme colour
5. Hardcoded bash fallback

Background follows the same chain with `-bg`.

---

## Creating a New Theme

1. **Create** `themes/<name>.conf` in the repo.
2. **Set** `@opencode-theme-status-bg` and `@opencode-theme-status-fg`
   for the overall status bar look.
3. **Set** `@opencode-theme-fg` as the global text colour fallback.
4. **Optionally set** per-plugin colours, bar chars, bar colours, icons,
   plugin list. Anything you don't set inherits from `default.conf`.

### Minimal theme template

```bash
# ── My Theme ──────────────────────────────────────────────────────────────────
# One-line description of the look.

set -g @opencode-theme-status-bg "colour235"   # dark background
set -g @opencode-theme-status-fg "colour255"   # light foreground
set -g @opencode-theme-fg "colour255"

set -g @opencode-theme-bar-filled-color "colour81"
set -g @opencode-theme-bar-empty-color  "colour237"
set -g @opencode-theme-bar-filled-char  "█"
set -g @opencode-theme-bar-empty-char   "░"

set -g @opencode-theme-plugins "model branch progressbar percentage cost"
```

### Available `@opencode-theme-*` options

| Option | Default | Description |
|--------|---------|-------------|
| `@opencode-theme-status-bg` | *(unset)* | Status bar background colour |
| `@opencode-theme-status-fg` | *(unset)* | Status bar foreground colour |
| `@opencode-theme-fg` | *(unset)* | Global text fg fallback |
| `@opencode-theme-bg` | *(unset)* | Global text bg fallback |
| `@opencode-theme-model-fg/bg` | *(unset)* | Per-plugin colour |
| `@opencode-theme-branch-fg/bg` | *(unset)* | Per-plugin colour |
| `@opencode-theme-pct-fg/bg` | *(unset)* | Per-plugin colour |
| `@opencode-theme-cost-fg/bg` | *(unset)* | Per-plugin colour |
| `@opencode-theme-session-fg/bg` | *(unset)* | Per-plugin colour |
| `@opencode-theme-separator-fg` | *(unset)* | Separator colour |
| `@opencode-theme-icon-model` | nf-md-globe_model | Model icon |
| `@opencode-theme-icon-branch` | nf-cod-git_branch | Branch icon |
| `@opencode-theme-icon-bar` | nf-fae-brain | Bar icon |
| `@opencode-theme-icon-cost` | nf-fa-money_bill | Cost icon |
| `@opencode-theme-icon-session` | nf-cod-terminal_bash | Session icon |
| `@opencode-theme-separator` | `│` | Separator character |
| `@opencode-theme-bar-filled-char` | `█` | Bar filled character |
| `@opencode-theme-bar-empty-char` | `░` | Bar empty character |
| `@opencode-theme-bar-filled-color` | *(gradient)* | Bar filled colour |
| `@opencode-theme-bar-empty-color` | `colour236` | Bar empty colour |
| `@opencode-theme-bar-width` | `10` | Bar width in chars |
| `@opencode-theme-plugins` | `model branch ...` | Plugin list |
| `@opencode-theme-session-max-len` | `20` | Session title max chars |
| `@opencode-theme-refresh` | `5` | Refresh interval (seconds) |

### Testing your theme locally

```bash
# 1. Add theme file to the themes/ directory
# 2. In your ~/.tmux.conf or ~/.tmux/opencode.conf:
set -g @opencode-tmux-theme "mytheme"
# 3. Reload:
tmux source-file ~/.tmux.conf
# 4. Trigger plugin init (if TPM installed):
# Press prefix + I
```

### Contributing a theme

1. Fork the repo: https://github.com/LeGambiArt/tmux-opencode
2. Add `themes/<name>.conf`
3. Add a screenshot to `img/theme-<name>.png`
4. Add a section to `docs/examples.md`
5. Open a pull request

---

## Creating a New Plugin Segment

> Note: a plugin API for custom segments is planned for a future release.
> For now, add a new `case` branch to `render()` in `scripts/status.sh`.

1. Add a new `case` entry in the `for plugin in $plugins` loop.
2. Use `resolve_fg 'myplugin' 'fallback_colour'` for colours.
3. Read any options with `resolve_opt '@opencode-statusline-...' '@opencode-theme-...' 'default'`.
4. Append to `parts+=("...")`.
5. Document the new plugin in `README.md` and `themes/default.conf`.

---

## State File Reference

`~/.config/opencode/plugins/tmux-opencode/statusline-state.sh` is a shell
variable assignment file sourced by `status.sh` on each render:

| Variable | Type | Description |
|----------|------|-------------|
| `MODEL` | string | Raw model ID |
| `MODEL_DISPLAY` | string | Human-readable model name |
| `SESSION_TITLE` | string | OpenCode session title |
| `BRANCH` | string | Current git branch |
| `DIRTY` | 0\|1 | Unstaged changes present |
| `STAGED` | 0\|1 | Staged changes present |
| `CONTEXT_PCT` | integer | Context window usage 0–100 |
| `COST_USD` | float | Cumulative session cost |
| `UPDATED_AT` | unix ts | Last update timestamp |

`status.sh` exits silently if the state file is absent or stale (>30 min).
