#!/bin/sh
# Life (liferust) installer.
#
#   curl -fsSL https://creepydutchboy.github.io/life-install/install.sh | sh
#   wget -qO-  https://creepydutchboy.github.io/life-install/install.sh | sh
#
# Everything goes into ~/liferust (app, icon, launcher, uninstaller; settings in
# ~/liferust/cfg). Outside it, only symlinks are created: the `liferust` command in
# ~/.local/bin and a desktop entry + icon so GNOME / KDE / others show the app.
# Remove with: ~/liferust/uninstall.sh
set -eu

BASE_URL="${LIFERUST_URL:-https://creepydutchboy.github.io/life-install}"
DEST="$HOME/liferust"
BIN_DIR="$HOME/.local/bin"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
APPS="$DATA/applications"
ICONS="$DATA/icons/hicolor/256x256/apps"

say() { printf '\033[1;33m::\033[0m %s\n' "$*"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }
fetch() {
    if command -v curl >/dev/null 2>&1; then curl -fsSL -o "$2" "$1"
    elif command -v wget >/dev/null 2>&1; then wget -qO "$2" "$1"
    else die "curl or wget is required"; fi
}
# refuse to replace something at $1 unless it's missing or our own symlink to $2
claim() {
    if [ -e "$1" ] || [ -L "$1" ]; then
        [ -L "$1" ] && [ "$(readlink "$1")" = "$2" ] && return 0
        die "$1 already exists and wasn't created by this installer — move it away and re-run"
    fi
}

[ -n "${HOME:-}" ] && [ "$HOME" != "/" ] || die "HOME is not set"
[ "$(uname -s)" = "Linux" ] || die "this installer is for Linux"
[ "$(uname -m)" = "x86_64" ] || die "only x86_64 builds are available (this is $(uname -m))"
command -v sha256sum >/dev/null 2>&1 || die "sha256sum is required"

claim "$BIN_DIR/liferust" "$DEST/liferust"
claim "$APPS/liferust.desktop" "$DEST/liferust.desktop"
claim "$ICONS/liferust.png" "$DEST/liferust.png"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT INT TERM
say "downloading Life from $BASE_URL"
fetch "$BASE_URL/Life-x86_64.AppImage" "$TMP/Life.AppImage"
fetch "$BASE_URL/Life-x86_64.AppImage.sha256" "$TMP/sum"
fetch "$BASE_URL/liferust.png" "$TMP/liferust.png"
fetch "$BASE_URL/uninstall.sh" "$TMP/uninstall.sh"
VERSION=$(fetch "$BASE_URL/version.txt" "$TMP/version" 2>/dev/null && cat "$TMP/version" || echo unknown)

say "verifying checksum"
want=$(cut -d' ' -f1 "$TMP/sum")
got=$(sha256sum "$TMP/Life.AppImage" | cut -d' ' -f1)
[ -n "$want" ] && [ "$want" = "$got" ] || die "checksum mismatch — download corrupted or tampered with"

mkdir -p "$DEST" "$BIN_DIR" "$APPS" "$ICONS"
chmod 755 "$TMP/Life.AppImage"
install -m 755 "$TMP/Life.AppImage" "$DEST/Life.AppImage"
install -m 644 "$TMP/liferust.png" "$DEST/liferust.png"
install -m 755 "$TMP/uninstall.sh" "$DEST/uninstall.sh"
printf 'version %s\ninstalled %s from %s\n' "$VERSION" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$BASE_URL" > "$DEST/.liferust-install"

# unpack once so launching needs no FUSE and starts fast (the .AppImage stays as the
# portable single-file copy)
say "unpacking"
( cd "$TMP" && ./Life.AppImage --appimage-extract >/dev/null 2>&1 ) || {
    chmod +x "$TMP/Life.AppImage"
    ( cd "$TMP" && ./Life.AppImage --appimage-extract >/dev/null ) || die "couldn't unpack the AppImage"
}
[ -x "$TMP/squashfs-root/AppRun" ] || die "unpacked app is incomplete"
rm -rf "$DEST/app.new"
mv "$TMP/squashfs-root" "$DEST/app.new"
: > "$DEST/app.new/.liferust-app"
if [ -d "$DEST/app" ] && [ -f "$DEST/app/.liferust-app" ]; then rm -rf "$DEST/app"; fi
mv "$DEST/app.new" "$DEST/app"

cat > "$DEST/liferust" <<LAUNCHER
#!/bin/sh
# liferust launcher (created by the Life installer)
exec "$DEST/app/AppRun" "\$@"
LAUNCHER
chmod 755 "$DEST/liferust"

cat > "$DEST/liferust.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Life
GenericName=Cellular automaton bench
Comment=Conway's Game of Life with multiplayer and LuaJIT mods
Exec=$DEST/liferust %U
Icon=liferust
Terminal=false
Categories=Game;Simulation;Education;
Keywords=conway;life;cellular;automaton;simulation;
StartupWMClass=liferust
DESKTOP

ln -sfn "$DEST/liferust" "$BIN_DIR/liferust"
ln -sfn "$DEST/liferust.desktop" "$APPS/liferust.desktop"
ln -sfn "$DEST/liferust.png" "$ICONS/liferust.png"
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database -q "$APPS" 2>/dev/null || true
command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -q -t "$DATA/icons/hicolor" 2>/dev/null || true

say "installed Life $VERSION into $DEST"
case ":$PATH:" in
    *":$BIN_DIR:"*) say "run it with: liferust  (or from your app menu)" ;;
    *) say "run it with: $BIN_DIR/liferust  — add ~/.local/bin to your PATH for plain 'liferust'" ;;
esac
say "remove it with: $DEST/uninstall.sh"
