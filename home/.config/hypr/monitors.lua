-- HDR is controlled manually with Super+Alt+B.
hl.config({ render = { cm_auto_hdr = 0 } })

hl.monitor({
    output = "DP-3",
    mode = "2560x1440@180",
    position = "0x0",
    scale = 1,
    bitdepth = 8,
    cm = "srgb",
    sdr_max_luminance = 200,
    sdrbrightness = 1.0,
    sdrsaturation = 1.0
})
