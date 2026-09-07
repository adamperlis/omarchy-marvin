-- Marvin: the part of the design system a theme file cannot carry.
-- Loaded from ~/.config/hypr/hyprland.lua after Omarchy's defaults, so every
-- value here wins over default/hypr/looknfeel.lua and the generated theme
-- hyprland.lua. Colours stay in the theme; this file is geometry and motion.

-- ---------------------------------------------------------------- geometry
-- Base 4, module 8, unit 32. Radius 16 is half the unit, and it is the one
-- radius: the shell reads decoration:rounding for every card and control.
-- gaps_out = 16 puts the padding-equals-radius rule at the screen edge.
hl.config({
  general = {
    gaps_in = 8,
    gaps_out = 16,
    -- Focus must stay visible. One hairline, coloured by the theme
    -- (hyprland_active_border at 55% foreground, inactive at 12%).
    border_size = 1,
  },

  decoration = {
    rounding = 16,

    -- Depth comes from surfaces, not outlines. The shadow is what replaces
    -- the border on every card.
    shadow = {
      enabled = true,
      range = 24,
      render_power = 3,
      color = "rgba(0000003d)",
      color_inactive = "rgba(0000001f)",
    },

    blur = {
      enabled = false,
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
hl.curve("marvinEnter", { type = "bezier", points = { { 0.16, 1 }, { 0.30, 1 } } })
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
