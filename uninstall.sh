#!/bin/sh
# Life (liferust) removal — only removes what the installer created.
#
#   ~/liferust/uninstall.sh            remove the app, keep ~/liferust/cfg (settings, saves)
#   ~/liferust/uninstall.sh --purge    remove settings too
#   add -y to skip the confirmation
#
# Symlinks outside ~/liferust are only removed if they still point into it; nothing is
# deleted recursively except ~/liferust/cfg with --purge.
set -eu

DEST="$HOME/liferust"
BIN_DIR="$HOME/.local/bin"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
PURGE=0
YES=0
for a in "$@"; do
    case "$a" in
        --purge) PURGE=1 ;;
        -y|--yes) YES=1 ;;
        -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
        *) printf 'unknown option: %s\n' "$a" >&2; exit 2 ;;
    esac
done

say() { printf '\033[1;33m::\033[0m %s\n' "$*"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

[ -n "${HOME:-}" ] && [ "$HOME" != "/" ] || die "HOME is not set"
[ -f "$DEST/.liferust-install" ] || die "no Life installation found in $DEST"

if [ "$YES" -ne 1 ]; then
    what="the Life app"
    [ "$PURGE" -eq 1 ] && what="the Life app AND your settings/saves"
    printf 'Remove %s from %s? [y/N] ' "$what" "$DEST"
    # works when piped through `curl | sh` too
    read -r answer < /dev/tty || answer=""
    case "$answer" in y|Y|yes|YES) ;; *) say "nothing removed"; exit 0 ;; esac
fi

# a symlink is ours only if it points at the file we installed
unlink_ours() {
    if [ -L "$1" ] && [ "$(readlink "$1")" = "$2" ]; then
        rm -f "$1" && say "removed $1"
    fi
}
unlink_ours "$BIN_DIR/liferust" "$DEST/liferust"
unlink_ours "$DATA/applications/liferust.desktop" "$DEST/liferust.desktop"
unlink_ours "$DATA/icons/hicolor/256x256/apps/liferust.png" "$DEST/liferust.png"

# the unpacked app dir is removed only if it carries the installer's marker
if [ -d "$DEST/app" ] && [ -f "$DEST/app/.liferust-app" ]; then
    rm -rf "$DEST/app" && say "removed $DEST/app"
fi
for f in Life.AppImage liferust liferust.png liferust.desktop uninstall.sh .liferust-install; do
    [ -e "$DEST/$f" ] || [ -L "$DEST/$f" ] && rm -f "$DEST/$f"
done
if [ "$PURGE" -eq 1 ] && [ -d "$DEST/cfg" ]; then
    rm -rf "$DEST/cfg" && say "removed settings ($DEST/cfg)"
fi
if rmdir "$DEST" 2>/dev/null; then
    say "removed $DEST"
else
    say "kept $DEST — it still holds your settings/saves (cfg/); use --purge to remove them"
fi
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database -q "$DATA/applications" 2>/dev/null || true
command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -q -t "$DATA/icons/hicolor" 2>/dev/null || true
say "Life has been uninstalled"
