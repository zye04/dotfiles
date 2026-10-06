# dotfiles

My Arch Linux + Hyprland desktop. It is a personal fork of
[illogical-impulse](https://github.com/end-4/dots-hyprland) (end-4's dots-hyprland, a Quickshell-based
Material You shell), pinned to the upstream commit in `packages/ii-commit.txt` and modified from there.
Upstream updates are not merged in.

## What's changed from upstream

- **Mouse-only unlock**: an on-screen keyboard on the lock screen (toggle next to the password field) and on
  the SDDM login screen, styled like ii's own OSK. It types straight into the password field, so it works
  regardless of the active keyboard layout.
- **SDDM theme `hyprlock-match`**: login screen that mirrors the lock screen. Its colors and background follow
  the current wallpaper through a matugen template, like the rest of the desktop.
- **Left sidebar AI chat**: trimmed to local models served by llama-swap through an OpenAI-compatible API
  (Gemini/Mistral backends removed), with a command menu and an animated orb. The model server itself is not
  part of this repo.
- Tweaks to the bar (resources, media), media controls, wallpaper selector (adds a Wallhaven random
  wallpaper script) and settings pages.

## Layout

| Path | What it is | How it gets onto the machine |
| --- | --- | --- |
| `home/.config/{quickshell,hypr,matugen,illogical-impulse}` | The ii fork itself | Symlinked into `~/.config`. Edit in place; changes land in the repo directly |
| `home/` (everything else) | Shell, terminals, GTK/Qt themes, RGB/GPU tools, user services | Snapshot. `backup.sh` copies the live files in, `restore.sh` copies them out |
| `system/` | Mirrors `/`: SDDM config and the `hyprlock-match` theme | `restore.sh` / `install-sddm-theme.sh` (sddm can't read `$HOME`, so no symlink) |
| `packages/` | Explicit pacman and AUR packages, pinned ii commit | `restore.sh` |
| `hooks/` | Git hooks (secret and author-email check before every commit) | `git config core.hooksPath hooks`, set by `restore.sh` |

## Fresh install

On a fresh Arch install with a user account:

```sh
sudo pacman -S --needed git github-cli rsync
gh repo clone zye04/dotfiles ~/dotfiles
~/dotfiles/restore.sh
```

`restore.sh` installs the packages (and `yay`), runs upstream ii's dependency setup at the pinned commit,
links/copies the configs and installs the SDDM theme. It expects the repo at `~/dotfiles`. The login
screen gets its background and colors the first time a wallpaper is set from ii.

Not included, set up by hand: SSH keys, `gh auth login`, API keys (ii stores those in the system keyring).

## Keeping it up to date

```sh
cd ~/dotfiles
./backup.sh            # refresh the snapshot part (the ii fork is already live in the repo)
git status && git diff # review
git add -A && git commit -m "..." && git push
```

- Editing the SDDM theme: edit it under `system/usr/share/sddm/themes/hyprlock-match`, then run
  `./install-sddm-theme.sh`.
- Tracking a new app's config: add its path to `HOME_PATHS` in `backup.sh`.
- The pre-commit hook rejects commits containing things that look like API keys/private keys, or made with a
  non-noreply author email. Generated caches and key files are in `.gitignore`.

## Machine-specific bits

Some of this only makes sense on my hardware and will need adjusting elsewhere: monitor layout (`hypr/monitors.lua`),
the Portuguese (`pt`) keyboard layout (`hypr/custom/`), Razer devices (`openrazer`, `polychromatic`), `OpenRGB`
profiles, GPU tuning (`lact`) and `MangoHud`. The `llama-swap`, `opencode` and `searxng` user services belong to a
separate local-AI project (not in this repo) and simply fail to start without it.

## Credits and license

- [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) (illogical-impulse), which most of
  `home/.config/{quickshell,hypr,matugen}` and several other configs come from. GPL-3.0.
- [Quickshell](https://quickshell.org), [Hyprland](https://hyprland.org), [matugen](https://github.com/InioX/matugen).
- Bundled third-party pieces keep their own licenses: the Material shapes library
  (`quickshell/ii/modules/common/widgets/shapes/LICENSE`), Cava shaders (MIT, SPDX headers in each file),
  Google Sans Flex (SIL OFL, `GoogleSansFlex-LICENSE.txt` next to the font), Colloid Kvantum theme (GPL-3.0).
  Extra license texts used by upstream are in `licenses/`.

Everything else in this repo is released under the GNU General Public License v3.0, see `LICENSE`.
