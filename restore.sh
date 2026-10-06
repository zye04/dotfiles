#!/usr/bin/env bash
# Fresh Arch install -> this setup. Safe to re-run.
set -euo pipefail
cd "$(dirname "$0")"

sudo pacman -Syu --needed - < packages/pacman.txt

if ! command -v yay >/dev/null; then
  tmp=$(mktemp -d)
  git clone https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
  (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
  rm -rf "$tmp"
fi
yay -S --needed - < packages/aur.txt

# illogical-impulse: install its deps/services at the pinned commit; config comes from home/ below.
ii="$HOME/.cache/dots-hyprland"
[ -d "$ii" ] || git clone https://github.com/end-4/dots-hyprland "$ii"
git -C "$ii" checkout "$(cat packages/ii-commit.txt)"
(cd "$ii" && ./setup install-deps && ./setup install-setups)

# illogical-impulse fork: these live in the repo and are symlinked into $HOME
LINKED=(.config/quickshell .config/hypr .config/matugen .config/illogical-impulse)
rsync -a "${LINKED[@]/#/--exclude=/}" home/ "$HOME/"
for p in "${LINKED[@]}"; do
  if [ -e "$HOME/$p" ] && [ ! -L "$HOME/$p" ]; then mv "$HOME/$p" "$HOME/$p.pre-dotfiles"; fi
  ln -sfn "$PWD/home/$p" "$HOME/$p"
done

git config core.hooksPath hooks

sudo cp -r system/etc/. /etc/
./install-sddm-theme.sh

systemctl --user daemon-reload
sudo systemctl enable sddm

echo "Done. Not restored (secrets, re-create by hand): ~/.ssh keys, gh auth."
