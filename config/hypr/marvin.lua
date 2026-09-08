-- Marvin: the part of the design system a theme file cannot carry.
-- Loaded from ~/.config/hypr/hyprland.lua after Omarchy's defaults, so every
-- value here wins over default/hypr/looknfeel.lua and the generated theme
-- hyprland.lua. Colours stay in the theme; this file is geometry and motion.

-- ---------------------------------------------------------------- geometry
-- Base 4, module 8, unit 32. Radius 24, and it is the one radius: the shell
-- reads decoration:rounding for every card and control. A 32px control is a
-- pill at any radius from 16 up. gaps_out = 24 puts padding-equals-radius at
-- the screen edge.
hl.config({
  general = {
    gaps_in = 8,
    gaps_out = 24,
    -- Focus must stay visible. One hairline, coloured by the theme
    -- (hyprland_active_border at 55% foreground, inactive at 12%).
    border_size = 1,
  },

  decoration = {
    rounding = 24,

    -- Depth comes from surfaces, not outlines. The shadow is what replaces
    -- the border on every card.
    -- Wide and faint: the card floats, nothing outlines it.
    shadow = {
      enabled = true,
      range = 40,
      render_power = 2,
      color = "rgba(0000001f)",
      color_inactive = "rgba(0000000f)",
    },

    blur = {
      enabled = false,
    },
  },

  -- The group bar (tabbed windows) is the one piece of Hyprland chrome with
  -- text. Inter at body size, a 32px row, a 2px indicator: the bar's rules.
  group = {
    groupbar = {
      font_family = "Inter",
      font_size = 13,
      font_weight_active = "medium",
      font_weight_inactive = "normal",
      height = 32,
      indicator_height = 2,
      indicator_gap = 4,
      gradient_rounding = 24,
      gradient_round_only_edges = false,
      gaps_in = 8,
      gaps_out = 0,
    },
  },

  animations = {
    enabled = true,
  },
})

-- ---------------------------------------------------------------- motion
-- Durations come from a scale, not a slider: 120 / 200 / 320 ms, which in
-- Hyprland's deciseconds is 1.2 / 2.0 / 3.2. Exits run at 0.6 of their
-- entrance, one ratio everywhere. Nothing over 320 ms responds to a direct
-- action; the only thing allowed that long is the workspace slide, which is
-- the most spatially meaningful transition in a tiling compositor and the
-- one upstream disables.
--
-- Three curves. Enter settles (ease-out). Leave accelerates away (ease-in);
-- linear exits read as mechanical. Move is the standard in-out.
-- A gentler settle than upstream's easeOutQuint: the same fast start, but the
-- last third eases in more gradually so entrances read as smooth, not snapped.
-- Durations are unchanged — the 120/200/320 scale stays; only the shape softens.
hl.curve("marvinEnter", { type = "bezier", points = { { 0.22, 1 }, { 0.44, 1 } } })
hl.curve("marvinLeave", { type = "bezier", points = { { 0.70, 0 }, { 0.84, 0 } } })
hl.curve("marvinMove",  { type = "bezier", points = { { 0.40, 0 }, { 0.20, 1 } } })

hl.animation({ leaf = "global",        enabled = true,  speed = 2.0, bezier = "marvinMove" })
hl.animation({ leaf = "windows",       enabled = true,  speed = 2.0, bezier = "marvinMove" })
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 2.0, bezier = "marvinEnter", style = "popin 92%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 1.2, bezier = "marvinLeave", style = "popin 92%" })
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 1.2, bezier = "marvinEnter" })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 0.8, bezier = "marvinLeave" })
hl.animation({ leaf = "fade",          enabled = true,  speed = 1.2, bezier = "marvinEnter" })
hl.animation({ leaf = "fadeSwitch",    enabled = false })
hl.animation({ leaf = "layers",        enabled = true,  speed = 2.0, bezier = "marvinEnter" })
hl.animation({ leaf = "layersIn",      enabled = true,  speed = 2.0, bezier = "marvinEnter", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true,  speed = 1.2, bezier = "marvinLeave", style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true,  speed = 1.2, bezier = "marvinEnter" })
hl.animation({ leaf = "fadeLayersOut", enabled = true,  speed = 0.8, bezier = "marvinLeave" })
-- Upstream animates a border recolour for 539 ms — the slowest thing on
-- screen is the least important event. It gets the short step.
hl.animation({ leaf = "border",        enabled = true,  speed = 1.2, bezier = "marvinEnter" })
hl.animation({ leaf = "workspaces",    enabled = true,  speed = 3.2, bezier = "marvinMove",  style = "slide" })
