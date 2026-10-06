#!/usr/bin/env bash
# Install the SDDM theme from the repo; re-run after editing it.
# Not a symlink: the sddm user can't read inside $HOME.
# generated/ is left alone: matugen writes the palette + wallpaper there on every wallpaper change.
set -euo pipefail
cd "$(dirname "$0")"
theme=/usr/share/sddm/themes/hyprlock-match
sudo rsync -a "system$theme/" "$theme/"
sudo install -d -o "$USER" -g "$USER" "$theme/generated"
