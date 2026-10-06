#!/usr/bin/env bash

get_pictures_dir() {
    if command -v xdg-user-dir &> /dev/null; then
        xdg-user-dir PICTURES
        return
    fi

    local config_file="${XDG_CONFIG_HOME:-$HOME/.config}/user-dirs.dirs"
    if [ -f "$config_file" ]; then
        local pictures_path
        pictures_path=$(source "$config_file" >/dev/null 2>&1; echo "$XDG_PICTURES_DIR")
        echo "${pictures_path/#\$HOME/$HOME}"
        return
    fi

    echo "$HOME/Pictures"
}

QUICKSHELL_CONFIG_NAME="ii"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
PICTURES_DIR=$(get_pictures_dir)
CONFIG_DIR="$XDG_CONFIG_HOME/quickshell/$QUICKSHELL_CONFIG_NAME"
CACHE_DIR="$XDG_CACHE_HOME/quickshell"
STATE_DIR="$XDG_STATE_HOME/quickshell"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$PICTURES_DIR/Wallpapers/Static"

# categories=100 -> general only, purity=100 -> sfw only
# q= is the search query; override with WALLHAVEN_QUERY
query="${WALLHAVEN_QUERY:-dark}"
response=$(curl -s "https://wallhaven.cc/api/v1/search?q=$(jq -rn --arg q "$query" '$q|@uri')&categories=100&purity=100&resolutions=2560x1440,3840x2160&sorting=random")
count=$(echo "$response" | jq '.data | length' -r)
if [[ -z "$count" || "$count" -eq 0 ]]; then
    notify-send "Wallhaven" "No results, try again" -a "Wallpaper switcher"
    exit 1
fi
randomIndex=$((RANDOM % count))
link=$(echo "$response" | jq ".data[$randomIndex].path" -r)
ext=$(echo "$link" | awk -F. '{print $NF}')
illogicalImpulseConfigPath="$HOME/.config/illogical-impulse/config.json"
downloadPath="$PICTURES_DIR/Wallpapers/Static/random_wallpaper.$ext"
currentWallpaperPath=$(jq -r '.background.wallpaperPath' "$illogicalImpulseConfigPath")
if [ "$downloadPath" == "$currentWallpaperPath" ]; then
    downloadPath="$PICTURES_DIR/Wallpapers/Static/random_wallpaper-1.$ext"
fi
pending=$(mktemp "$PICTURES_DIR/Wallpapers/Static/.download-XXXXXX") || exit 1
trap 'rm -f -- "$pending"' EXIT
curl -fLsS "$link" -o "$pending" || exit 1
resolution=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$pending")
case "$resolution" in
    2560x1440|3840x2160) ;;
    *) notify-send "Wallpaper switcher" "Skipped wallpaper: only 1440p and 4K are allowed"; exit 1 ;;
esac
mv -- "$pending" "$downloadPath" || exit 1
"$SCRIPT_DIR/../switchwall.sh" --image "$downloadPath"
