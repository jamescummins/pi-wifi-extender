#!/bin/bash
# Install GUI dependencies and desktop shortcut
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing WiFi Extender GUI..."

# Install dependencies
sudo apt-get update
sudo apt-get install -y python3-gi python3-gi-cairo gir1.2-gtk-3.0 polkitd pkexec

# Make GUI executable
chmod +x "$SCRIPT_DIR/wifi-extender-gui.py"

# Install desktop shortcut
mkdir -p ~/.local/share/applications
sed "s|/home/pi/workspace/pi-wifi-extender|$SCRIPT_DIR|g" \
    "$SCRIPT_DIR/wifi-extender.desktop" > ~/.local/share/applications/wifi-extender.desktop

# Update desktop database
update-desktop-database ~/.local/share/applications 2>/dev/null || true

echo ""
echo "✓ GUI installed!"
echo ""
echo "Launch from:"
echo "  • Applications menu → Settings → WiFi Extender"
echo "  • Or run: $SCRIPT_DIR/wifi-extender-gui.py"
