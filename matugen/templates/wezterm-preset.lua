-- NEXA generated WezTerm theme
-- Do not edit manually.

local colorscheme = {
   foreground = '{{colors.on_surface}}',
   background = '{{colors.background}}',
   cursor_bg = '{{colors.primary}}',
   cursor_border = '{{colors.primary}}',
   cursor_fg = '{{colors.on_primary}}',
   selection_bg = '{{colors.primary_container}}',
   selection_fg = '{{colors.on_primary_container}}',
   ansi = {
      '{{colors.surface}}',
      '{{colors.error}}',
      '{{colors.success}}',
      '{{colors.warning}}',
      '{{colors.primary}}',
      '{{colors.tertiary}}',
      '{{colors.info}}',
      '{{colors.on_surface}}',
   },
   brights = {
      '{{colors.outline}}',
      '{{colors.error}}',
      '{{colors.success}}',
      '{{colors.warning}}',
      '{{colors.primary}}',
      '{{colors.tertiary}}',
      '{{colors.info}}',
      '{{colors.on_background}}',
   },
   tab_bar = {
      background = '{{colors.background}}',
      active_tab = {
         bg_color = '{{colors.primary}}',
         fg_color = '{{colors.on_primary}}',
      },
      inactive_tab = {
         bg_color = '{{colors.surface_container}}',
         fg_color = '{{colors.on_surface_variant}}',
      },
      inactive_tab_hover = {
         bg_color = '{{colors.surface_container_high}}',
         fg_color = '{{colors.on_surface}}',
      },
      new_tab = {
         bg_color = '{{colors.surface_container}}',
         fg_color = '{{colors.on_surface}}',
      },
      new_tab_hover = {
         bg_color = '{{colors.primary}}',
         fg_color = '{{colors.on_primary}}',
         italic = true,
      },
   },
   visual_bell = '{{colors.error}}',
   scrollbar_thumb = '{{colors.outline_variant}}',
   split = '{{colors.outline}}',
   compose_cursor = '{{colors.tertiary}}',
}

return colorscheme
