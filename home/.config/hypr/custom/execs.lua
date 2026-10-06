hl.on("hyprland.start", function ()
    hl.exec_cmd("polychromatic-tray-applet")
    hl.exec_cmd("systemctl --user start openrgb-theme.path openrgb-theme.service")
end)
