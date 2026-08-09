# Theme Gallery

All 15 built-in themes for tmux-opencode. Select any theme with:

    set -g @opencode-tmux-theme "<name>"

Screenshots are taken after `tmux source-file ~/.tmux.conf` with a live
OpenCode session running.

> **Font note** — most themes require a [Nerd Font](https://www.nerdfonts.com)
> installed and configured in your terminal emulator (JetBrainsMono NF and
> Hack NF are tested). The `neon-punk` theme uses emoji icons and works without
> Nerd Fonts. If glyphs render as boxes, switch to emoji fallbacks:
> `set -g @opencode-statusline-icon-model "🔮"`

---

## default

Plain tmux colours. Blue progress bar, all text inherits the terminal's
own foreground colour. Works on any terminal without configuration.

![default theme](../img/theme-default.png)

    set -g @opencode-tmux-theme "default"

---

## classic

Dark charcoal background, white text, dynamic green→yellow→red gradient bar.
Clean, professional dark terminal look.

![classic theme](../img/theme-classic.png)

    set -g @opencode-tmux-theme "classic"

---

## forest

Dark green background, bright green text, block bar. Includes session title.
Operator/dashboard feel.

![forest theme](../img/theme-forest.png)

    set -g @opencode-tmux-theme "forest"

---

## neon-punk

True black background, hot-pink text, heavy-circle `▰▱` bar. 80s spray-paint
wall neon. Uses emoji icons — no Nerd Font required for icons.

![neon-punk theme](../img/theme-neon-punk.png)

    set -g @opencode-tmux-theme "neon-punk"

---

## darkblue

Dark navy background, neon-yellow text, diamond `◆◇` bar. Night-city aesthetic.

![darkblue theme](../img/theme-darkblue.png)

    set -g @opencode-tmux-theme "darkblue"

---

## cyberpunk

True black background, hot-magenta text, neon-yellow filled `▰▱` bar, electric-cyan
branch, orange cost. Classic cyberpunk neon city palette: magenta + yellow + cyan.

![cyberpunk theme](../img/theme-cyberpunk.png)

    set -g @opencode-tmux-theme "cyberpunk"

---

## retrowave

Deep purple background, hot-pink text, electric-cyan rectangular `▮▯` bar,
gold cost. 80s synthwave sunset palette.

![retrowave theme](../img/theme-retrowave.png)

    set -g @opencode-tmux-theme "retrowave"

---

## steel

Dark charcoal background, steel-blue text, block bar. Cool industrial aesthetic.

![steel theme](../img/theme-steel.png)

    set -g @opencode-tmux-theme "steel"

---

## orange

Grey background, warm orange text, dot `●○` bar, amber empty dots.

![orange theme](../img/theme-orange.png)

    set -g @opencode-tmux-theme "orange"

---

## minimal

Dark background, cyan text. Model, percentage and cost only — no progress bar.
Maximum status bar width efficiency.

![minimal theme](../img/theme-minimal.png)

    set -g @opencode-tmux-theme "minimal"

---

## redalert

White background, bright red text, heavy-circle `▰▱` bar. For urgency signalling
or high-contrast visibility.

![redalert theme](../img/theme-redalert.png)

    set -g @opencode-tmux-theme "redalert"

---

## matrix

True black background, bright green text, heavy-circle `▰▱` bar with green fill
and dark-green empty. Matrix digital-rain feel.

![matrix theme](../img/theme-matrix.png)

    set -g @opencode-tmux-theme "matrix"

---

## diamond

Deep purple background, cyan text, green diamond `◆◇` bar. Rich purple and cyan
palette.

![diamond theme](../img/theme-diamond.png)

    set -g @opencode-tmux-theme "diamond"

---

## purple

Dark charcoal background, light-purple text, rectangular `▮▯` bar with purple fill
and slate empty.

![purple theme](../img/theme-purple.png)

    set -g @opencode-tmux-theme "purple"

---

## circle

Deep ocean background, each plugin in its own distinct neon colour (magenta
session, cyan model, green branch, yellow percentage, orange cost). Dot `●○`
progress bar — the theme's namesake. Cost uses the 💵 money-bill icon.

![circle theme](../img/theme-circle.png)

    set -g @opencode-tmux-theme "circle"

---

## dracula

Authentic Dracula palette. Dark `colour234` background, Dracula purple
`colour141` text, green branch, orange cost, rectangular `▮▯` bar with purple
fill. Segments flow together on a shared `colour236` pill interior with no
separator. Solid-triangle edge glyphs (Nerd Font required) create the capsule
boundary. Set `@opencode-theme-left-edge-bg` to match your adjacent clock or
battery widget background to eliminate the square artifact.

![dracula theme](../img/theme-dracula.png)

    set -g @opencode-tmux-theme "dracula"

---

## Customising a theme

Override any individual setting after setting the theme name:

    set -g @opencode-tmux-theme "matrix"

    # Override a single colour
    set -g @opencode-statusline-cost-fg "colour82"

    # Change bar width
    set -g @opencode-statusline-bar-width "15"

    # Use emoji instead of Nerd Font icon
    set -g @opencode-statusline-icon-model "🔮"

    # Use the gradient instead of the theme's fixed bar colour
    set -gu @opencode-statusline-bar-filled-color

User options (`@opencode-statusline-*`) always win over theme defaults.
See [docs/dev-guide.md](dev-guide.md) for the full list of available options.
