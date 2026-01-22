#!/bin/bash
# Pi WiFi Extender - Setup Script
# Usage: sudo ./setup.sh "MySSID" "MyPassword" [channel] [country]

set -e

WIFI_SSID="${1:-PiExtender}"
WIFI_PASSWORD="$2"
WIFI_CHANNEL="${3:-6}"
COUNTRY_CODE="${4:-IE}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Check root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Run as root: sudo $0 \"SSID\" \"Password\"${NC}"
    exit 1
fi

# Check password
if [[ -z "$WIFI_PASSWORD" ]] || [[ ${#WIFI_PASSWORD} -lt 8 ]]; then
    echo "Usage: sudo $0 \"SSID\" \"Password\" [channel] [country]"
    echo "  Password must be at least 8 characters"
    echo "  Channel: 1, 6, 11 (default: 6)"
    echo "  Country: IE, GB, US, DE (default: IE)"
    exit 1
fi

echo -e "${GREEN}Setting up WiFi Extender...${NC}"

# Install packages
apt-get update -qq
apt-get install -y -qq hostapd bridge-utils

# Stop hostapd
systemctl stop hostapd 2>/dev/null || true
rfkill unblock wlan 2>/dev/null || true

# Configure hostapd
cat > /etc/hostapd/hostapd.conf << EOF
interface=wlan0
bridge=br0
driver=nl80211
ssid=${WIFI_SSID}
hw_mode=g
channel=${WIFI_CHANNEL}
country_code=${COUNTRY_CODE}
wpa=2
wpa_passphrase=${WIFI_PASSWORD}
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
wmm_enabled=1
ieee80211n=1
EOF
chmod 600 /etc/hostapd/hostapd.conf

# Set daemon config
sed -i 's|^#\?DAEMON_CONF=.*|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd 2>/dev/null || \
  echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' >> /etc/default/hostapd

# Backup and configure dhcpcd
[[ ! -f /etc/dhcpcd.conf.backup ]] && cp /etc/dhcpcd.conf /etc/dhcpcd.conf.backup
if ! grep -q "denyinterfaces wlan0 eth0" /etc/dhcpcd.conf; then
    echo -e "\n# Pi WiFi Extender\ndenyinterfaces wlan0 eth0\ninterface br0" >> /etc/dhcpcd.conf
fi

# Configure bridge
cat > /etc/network/interfaces.d/br0 << EOF
auto br0
iface br0 inet dhcp
    bridge_ports eth0
    bridge_stp off
    bridge_fd 0
EOF

# Enable hostapd
systemctl unmask hostapd
systemctl enable hostapd

echo ""
echo -e "${GREEN}✓ Setup complete!${NC}"
echo "  SSID: $WIFI_SSID | Channel: $WIFI_CHANNEL | Country: $COUNTRY_CODE"
echo ""
echo "Reboot to activate: sudo reboot"
