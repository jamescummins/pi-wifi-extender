#!/bin/bash
# Pi WiFi Extender - Setup Script
# Usage: sudo ./setup.sh "MySSID" "MyPassword" [channel] [country] [band]
#        sudo ./setup.sh --revert

set -e

BACKUP_DIR="/var/lib/wifi-extender-backup"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Check root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Run as root: sudo $0 \"SSID\" \"Password\"${NC}"
    exit 1
fi

# Handle --revert flag
if [[ "$1" == "--revert" ]]; then
    if [[ ! -d "$BACKUP_DIR" ]]; then
        echo -e "${RED}No backup found to restore${NC}"
        exit 1
    fi
    
    echo "Reverting to backup..."
    
    systemctl stop hostapd 2>/dev/null || true
    systemctl disable hostapd 2>/dev/null || true
    
    # Restore files
    [[ -f "$BACKUP_DIR/dhcpcd.conf" ]] && cp "$BACKUP_DIR/dhcpcd.conf" /etc/dhcpcd.conf
    [[ -f "$BACKUP_DIR/hostapd.conf" ]] && cp "$BACKUP_DIR/hostapd.conf" /etc/hostapd/ || rm -f /etc/hostapd/hostapd.conf
    [[ -f "$BACKUP_DIR/hostapd-default" ]] && cp "$BACKUP_DIR/hostapd-default" /etc/default/hostapd
    rm -f /etc/network/interfaces.d/br0
    
    # NetworkManager cleanup
    if systemctl is-active --quiet NetworkManager; then
        rm -f /etc/NetworkManager/conf.d/10-hostapd.conf
        nmcli connection delete bridge-slave-eth0 2>/dev/null || true
        nmcli connection delete bridge-br0 2>/dev/null || true
        systemctl reload NetworkManager
    fi
    
    # Remove bridge
    ip link set br0 down 2>/dev/null || true
    ip link delete br0 type bridge 2>/dev/null || true
    
    echo -e "${GREEN}✓ Reverted to backup${NC}"
    echo "Reboot to complete: sudo reboot"
    exit 0
fi

WIFI_SSID="${1:-PiExtender}"
WIFI_PASSWORD="$2"
WIFI_CHANNEL="${3:-6}"
COUNTRY_CODE="${4:-IE}"
WIFI_BAND="${5:-g}"  # g = 2.4GHz, a = 5GHz

# Validate band and adjust settings
if [[ "$WIFI_BAND" == "a" ]]; then
    HW_MODE="a"
    # Validate 5GHz channel
    if [[ ! "$WIFI_CHANNEL" =~ ^(36|40|44|48|149|153|157|161|165)$ ]]; then
        WIFI_CHANNEL=36
    fi
else
    HW_MODE="g"
    # Validate 2.4GHz channel
    if [[ "$WIFI_CHANNEL" -lt 1 || "$WIFI_CHANNEL" -gt 13 ]] 2>/dev/null; then
        WIFI_CHANNEL=6
    fi
fi

# Detect WiFi interface
WIFI_IFACE=$(iw dev 2>/dev/null | awk '$1=="Interface"{print $2; exit}')
WIFI_IFACE=${WIFI_IFACE:-wlan0}

# Check password
if [[ -z "$WIFI_PASSWORD" ]] || [[ ${#WIFI_PASSWORD} -lt 8 ]]; then
    echo "Usage: sudo $0 \"SSID\" \"Password\" [channel] [country] [band]"
    echo "       sudo $0 --revert"
    echo ""
    echo "  Password must be at least 8 characters"
    echo "  Channel: 1-13 for 2.4GHz, 36/40/44/48/149/153/157/161 for 5GHz"
    echo "  Country: IE, GB, US, DE (default: IE)"
    echo "  Band: g (2.4GHz) or a (5GHz) (default: g)"
    exit 1
fi

echo -e "${GREEN}Setting up WiFi Extender...${NC}"
echo "  SSID: $WIFI_SSID"
echo "  Channel: $WIFI_CHANNEL"
echo "  Band: $([ "$HW_MODE" = "a" ] && echo "5GHz" || echo "2.4GHz")"
echo "  Country: $COUNTRY_CODE"
echo "  Interface: $WIFI_IFACE"

# Create backup (only on first run)
if [[ ! -d "$BACKUP_DIR" ]]; then
    echo "Creating backup..."
    mkdir -p "$BACKUP_DIR"
    cp /etc/dhcpcd.conf "$BACKUP_DIR/" 2>/dev/null || true
    cp /etc/hostapd/hostapd.conf "$BACKUP_DIR/" 2>/dev/null || true
    cp /etc/default/hostapd "$BACKUP_DIR/hostapd-default" 2>/dev/null || true
    echo "Backup saved to $BACKUP_DIR"
fi

# Detect network manager
USE_NETWORKMANAGER=false
if systemctl is-active --quiet NetworkManager; then
    USE_NETWORKMANAGER=true
    echo "Detected: NetworkManager (Bookworm+)"
else
    echo "Detected: dhcpcd (Legacy)"
fi

# Install packages
apt-get update -qq
apt-get install -y -qq hostapd bridge-utils

# Stop hostapd and unblock wifi
systemctl stop hostapd 2>/dev/null || true
rfkill unblock wlan 2>/dev/null || true

# Configure hostapd
cat > /etc/hostapd/hostapd.conf << EOF
interface=$WIFI_IFACE
bridge=br0
driver=nl80211
ssid=${WIFI_SSID}
hw_mode=${HW_MODE}
channel=${WIFI_CHANNEL}
country_code=${COUNTRY_CODE}
wpa=2
wpa_passphrase=${WIFI_PASSWORD}
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
wmm_enabled=1
ieee80211n=1
EOF

# Add 802.11ac for 5GHz
if [[ "$HW_MODE" == "a" ]]; then
    echo "ieee80211ac=1" >> /etc/hostapd/hostapd.conf
fi

chmod 600 /etc/hostapd/hostapd.conf

# Configure based on network manager
if $USE_NETWORKMANAGER; then
    # NetworkManager configuration (Bookworm+)
    
    # Create bridge connection
    nmcli connection delete br0 2>/dev/null || true
    nmcli connection delete bridge-br0 2>/dev/null || true
    nmcli connection delete bridge-slave-eth0 2>/dev/null || true
    
    nmcli connection add type bridge ifname br0 con-name bridge-br0 \
        ipv4.method auto ipv6.method auto
    nmcli connection add type bridge-slave ifname eth0 master br0 \
        con-name bridge-slave-eth0
    
    # Prevent NetworkManager from managing WiFi interface (hostapd will)
    mkdir -p /etc/NetworkManager/conf.d
    cat > /etc/NetworkManager/conf.d/10-hostapd.conf << EOF
[keyfile]
unmanaged-devices=interface-name:$WIFI_IFACE
EOF
    
    # Reload NetworkManager
    systemctl reload NetworkManager
    
    # Bring up bridge
    nmcli connection up bridge-br0 2>/dev/null || true
else
    # Legacy dhcpcd configuration (Bullseye and older)
    sed -i 's|^#\?DAEMON_CONF=.*|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd 2>/dev/null || \
      echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' >> /etc/default/hostapd
    
    # Backup and configure dhcpcd
    [[ ! -f /etc/dhcpcd.conf.backup ]] && cp /etc/dhcpcd.conf /etc/dhcpcd.conf.backup
    if ! grep -q "denyinterfaces $WIFI_IFACE eth0" /etc/dhcpcd.conf; then
        echo -e "\n# Pi WiFi Extender\ndenyinterfaces $WIFI_IFACE eth0\ninterface br0" >> /etc/dhcpcd.conf
    fi
    
    # Configure bridge via interfaces
    cat > /etc/network/interfaces.d/br0 << EOF
auto br0
iface br0 inet dhcp
    bridge_ports eth0
    bridge_stp off
    bridge_fd 0
EOF
fi

# Enable hostapd
systemctl unmask hostapd
systemctl enable hostapd

echo ""
echo -e "${GREEN}✓ Setup complete!${NC}"
echo "  SSID: $WIFI_SSID | Channel: $WIFI_CHANNEL | Country: $COUNTRY_CODE"
echo ""
echo "Reboot to activate: sudo reboot"
echo "To revert changes:  sudo ./setup.sh --revert"
