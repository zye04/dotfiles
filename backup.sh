#!/usr/bin/env bash
# Copy the live config on this machine into the repo. Review with `git diff`, then commit.
# quickshell, hypr, matugen, illogical-impulse and the SDDM theme are not copied: they live in the repo (see restore.sh).
set -euo pipefail
cd "$(dirname "$0")"

HOME_PATHS=(
  .zshrc .aliases .bashrc .bash_profile .gitconfig .gtkrc-2.0 .ssh/config
  .config/kitty .config/foot .config/fuzzel .config/fish .config/zshrc.d .config/starship.toml
  .config/btop .config/cava .config/mpv .config/fontconfig .config/gtk-3.0 .config/gtk-4.0
  .config/Kvantum .config/wlogout .config/xdg-desktop-portal .config/MangoHud
  .config/OpenRGB .config/openrazer .config/polychromatic .config/lact
  .config/systemd/user
  .config/kdeglobals .config/dolphinrc .config/konsolerc
  .config/mimeapps.list .config/user-dirs.dirs .config/user-dirs.locale
  .config/chrome-flags.conf .config/code-flags.conf .config/thorium-flags.conf
  .local/bin/openrgb-theme-sync .local/bin/toggle-hdr .local/bin/hydra
)

SYSTEM_PATHS=(
  /etc/sddm.conf.d
)

EXCLUDES=(--exclude '*.bak' --exclude '*.lock' --exclude '*.log' --exclude 'api-key' --exclude '*.key')

for p in "${HOME_PATHS[@]}"; do
  src="$HOME/$p"
  if [ ! -e "$src" ]; then echo "skip (missing): ~/$p"; continue; fi
  mkdir -p "home/$(dirname "$p")"
  if [ -d "$src" ]; then
    rsync -a --delete "${EXCLUDES[@]}" "$src/" "home/$p/"
  else
    rsync -a "$src" "home/$p"
  fi
done

for p in "${SYSTEM_PATHS[@]}"; do
  [ -e "$p" ] || continue
  mkdir -p "system$(dirname "$p")"
  rsync -a --delete "$p/" "system$p/"
done

mkdir -p packages
pacman -Qqen > packages/pacman.txt
pacman -Qqem | grep -v '^illogical-impulse-' > packages/aur.txt
git -C "$HOME/.cache/dots-hyprland" rev-parse HEAD > packages/ii-commit.txt

echo "Done. Review with: git -C $(pwd) status && git -C $(pwd) diff"
