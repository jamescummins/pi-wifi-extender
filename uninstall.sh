#!/bin/bash
# Pi WiFi Extender - Uninstall
set -e

if [[ $EUID -ne 0 ]]; then
    echo "Run as root: sudo $0"
    exit 1
fi

echo "Removing WiFi Extender..."

# Detect WiFi interface (don't assume wlan0)
WIFI_IFACE=$(iw dev 2>/dev/null | awk '$1=="Interface"{print $2; exit}')
WIFI_IFACE=${WIFI_IFACE:-wlan0}

systemctl stop hostapd 2>/dev/null || true
systemctl disable hostapd 2>/dev/null || true
rm -f /etc/hostapd/hostapd.conf
rm -f /etc/default/hostapd
rm -f /etc/network/interfaces.d/br0

# Detect and clean up based on network manager
if systemctl is-active --quiet NetworkManager; then
    # NetworkManager cleanup (Bookworm+)
    rm -f /etc/NetworkManager/conf.d/10-hostapd.conf
    nmcli connection delete "bridge-slave-eth0" 2>/dev/null || true
    nmcli connection delete "bridge-slave-${WIFI_IFACE}" 2>/dev/null || true
    nmcli connection delete "bridge-br0" 2>/dev/null || true
    nmcli connection delete "br0" 2>/dev/null || true
    systemctl reload NetworkManager 2>/dev/null || true
else
    # Legacy dhcpcd cleanup
    if [[ -f /etc/dhcpcd.conf.backup ]]; then
        mv /etc/dhcpcd.conf.backup /etc/dhcpcd.conf
    else
        sed -i '/# Pi WiFi Extender/,/interface br0/d' /etc/dhcpcd.conf
        sed -i "/denyinterfaces ${WIFI_IFACE} eth0/d" /etc/dhcpcd.conf
        sed -i '/denyinterfaces wlan0 eth0/d' /etc/dhcpcd.conf
    fi
fi

# Clean up bridge interface
if ip link show br0 &>/dev/null; then
    ip link set br0 down 2>/dev/null || true
    ip link delete br0 type bridge 2>/dev/null || brctl delbr br0 2>/dev/null || true
fi

# Re-enable WiFi interface for normal use
ip link set "${WIFI_IFACE}" up 2>/dev/null || true

echo "✓ Uninstalled (interface: ${WIFI_IFACE}). Reboot to restore normal WiFi: sudo reboot"
