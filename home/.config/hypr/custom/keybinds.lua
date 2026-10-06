hl.bind("CTRL+SUPER+ALT+Slash", hl.dsp.exec_cmd("xdg-open ~/.config/hypr/custom/keybinds.lua"), {description = "Edit user keybinds"} )

-- The default SUPER+Slash cheatsheet bind cannot fire on the pt layout: slash sits
-- at a shift level, and code: bindings are not translated by the lua wrapper.
hl.bind("SUPER + SHIFT + H", hl.dsp.global("quickshell:cheatsheetToggle"),
    { description = "Shell: Toggle cheatsheet" })

hl.bind("SUPER + SHIFT + W", hl.dsp.exec_cmd("~/.config/quickshell/ii/scripts/colors/random/random_wallhaven_wall.sh"),
    { description = "Shell: Random wallpaper (Wallhaven)" })

hl.bind("SUPER + ALT + B", hl.dsp.exec_cmd("~/.local/bin/toggle-hdr"),
    { description = "Display: Toggle HDR" })
