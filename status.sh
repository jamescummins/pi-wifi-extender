#!/bin/bash
# Pi WiFi Extender - Status

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "📡 WiFi Extender Status"
echo "─────────────────────────"

# Services
if systemctl is-active --quiet hostapd; then
    echo -e "hostapd: ${GREEN}● running${NC}"
else
    echo -e "hostapd: ${RED}● stopped${NC}"
fi

if ip link show br0 &>/dev/null; then
    echo -e "bridge:  ${GREEN}● active${NC}"
else
    echo -e "bridge:  ${RED}● inactive${NC}"
fi

# Config
if [[ -f /etc/hostapd/hostapd.conf ]]; then
    ssid=$(grep ^ssid= /etc/hostapd/hostapd.conf | cut -d= -f2)
    channel=$(grep ^channel= /etc/hostapd/hostapd.conf | cut -d= -f2)
    echo "─────────────────────────"
    echo "SSID:    $ssid"
    echo "Channel: $channel"
fi

# Clients
if systemctl is-active --quiet hostapd; then
    clients=$(iw dev wlan0 station dump 2>/dev/null | grep -c "Station" || echo 0)
    echo "Clients: $clients"
fi
