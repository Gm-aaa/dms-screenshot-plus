#!/usr/bin/env bash
# Install dms-screenshot-plus by symlinking it onto your PATH.
#
#   ./install.sh            # symlink into ~/.local/bin (default)
#   PREFIX=~/bin ./install.sh
#   ./install.sh uninstall  # remove the symlink
#
# A symlink (not a copy) is used so `git pull` updates the installed command.
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$SRC_DIR/bin/dms-screenshot-plus"
PREFIX="${PREFIX:-$HOME/.local/bin}"
TARGET="$PREFIX/dms-screenshot-plus"

case "${1:-install}" in
    uninstall|remove)
        if [[ -L "$TARGET" ]]; then rm -v "$TARGET"; else echo "Not a symlink, leaving alone: $TARGET"; fi
        exit 0 ;;
esac

chmod +x "$BIN"
mkdir -p "$PREFIX"
ln -sfn "$BIN" "$TARGET"
echo "Linked: $TARGET -> $BIN"

case ":$PATH:" in
    *":$PREFIX:"*) ;;
    *) echo "WARNING: $PREFIX is not on your PATH. Add it to use the bare command name." ;;
esac

cat <<'EOF'

Done. Bind a key the easy way: run `dms-screenshot-plus`, then
Settings -> Keybinding — it writes a Mod+F1 bind into your compositor's
config (with a .bak backup) or copies the snippet.

Prefer to do it by hand?

  niri (~/.config/niri/.../binds.kdl):
    Mod+F1 hotkey-overlay-title="截图菜单 Screenshot menu" { spawn "dms-screenshot-plus"; }

  Hyprland (hyprland.conf):
    bind = SUPER, F1, exec, dms-screenshot-plus

Check your setup any time with:  dms-screenshot-plus doctor
Optional: copy config.example to ~/.config/dms-screenshot-plus/config to tweak defaults.
EOF
