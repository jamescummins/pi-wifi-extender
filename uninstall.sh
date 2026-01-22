#!/bin/bash
# Pi WiFi Extender - Uninstall
set -e

if [[ $EUID -ne 0 ]]; then
    echo "Run as root: sudo $0"
    exit 1
fi

echo "Removing WiFi Extender..."

systemctl stop hostapd 2>/dev/null || true
systemctl disable hostapd 2>/dev/null || true
rm -f /etc/hostapd/hostapd.conf
rm -f /etc/network/interfaces.d/br0

if [[ -f /etc/dhcpcd.conf.backup ]]; then
    mv /etc/dhcpcd.conf.backup /etc/dhcpcd.conf
else
    sed -i '/# Pi WiFi Extender/,/interface br0/d' /etc/dhcpcd.conf
    sed -i '/denyinterfaces wlan0 eth0/d' /etc/dhcpcd.conf
fi

ip link set br0 down 2>/dev/null || true
brctl delbr br0 2>/dev/null || true

echo "✓ Uninstalled. Reboot to restore normal WiFi: sudo reboot"
