#!/bin/bash
# Install WiFi Extender to SD card boot partition (for Pi Imager users)
# Usage: ./install-to-sdcard.sh /path/to/bootfs "SSID" "Password"

set -e

BOOT_PATH="$1"
WIFI_SSID="${2:-PiExtender}"
WIFI_PASSWORD="$3"
WIFI_CHANNEL="${4:-6}"
COUNTRY_CODE="${5:-IE}"

# Find boot partition if not specified
if [[ -z "$BOOT_PATH" ]]; then
    for p in /media/*/bootfs /media/*/boot /Volumes/bootfs /Volumes/boot /mnt/boot; do
        [[ -f "$p/cmdline.txt" ]] && BOOT_PATH="$p" && break
    done
fi

if [[ ! -f "$BOOT_PATH/cmdline.txt" ]]; then
    echo "Usage: $0 /path/to/bootfs \"SSID\" \"Password\" [channel] [country]"
    echo "Example: $0 /media/user/bootfs \"MyNetwork\" \"MyPassword123\""
    exit 1
fi

if [[ -z "$WIFI_PASSWORD" ]] || [[ ${#WIFI_PASSWORD} -lt 8 ]]; then
    echo "Error: Password required (min 8 characters)"
    exit 1
fi

echo "Installing to: $BOOT_PATH"
echo "SSID: $WIFI_SSID | Channel: $WIFI_CHANNEL | Country: $COUNTRY_CODE"

# Create firstrun script
cat > "$BOOT_PATH/firstrun.sh" << EOF
#!/bin/bash
rm -f /boot/firstrun.sh /boot/firmware/firstrun.sh
sed -i 's| systemd.run.*||g' /boot/cmdline.txt /boot/firmware/cmdline.txt 2>/dev/null
apt-get update -qq && apt-get install -y -qq hostapd bridge-utils
systemctl stop hostapd 2>/dev/null; rfkill unblock wlan 2>/dev/null
cat > /etc/hostapd/hostapd.conf << CONF
interface=wlan0
bridge=br0
driver=nl80211
ssid=$WIFI_SSID
hw_mode=g
channel=$WIFI_CHANNEL
country_code=$COUNTRY_CODE
wpa=2
wpa_passphrase=$WIFI_PASSWORD
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
wmm_enabled=1
ieee80211n=1
CONF
chmod 600 /etc/hostapd/hostapd.conf
sed -i 's|^#\\?DAEMON_CONF=.*|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd
echo -e "\\n# Pi WiFi Extender\\ndenyinterfaces wlan0 eth0\\ninterface br0" >> /etc/dhcpcd.conf
cat > /etc/network/interfaces.d/br0 << BR
auto br0
iface br0 inet dhcp
    bridge_ports eth0
    bridge_stp off
    bridge_fd 0
BR
systemctl unmask hostapd && systemctl enable hostapd
reboot
EOF

chmod +x "$BOOT_PATH/firstrun.sh"

# Add to cmdline.txt
if ! grep -q "systemd.run=" "$BOOT_PATH/cmdline.txt"; then
    sed -i 's/$/ systemd.run=\/boot\/firstrun.sh systemd.run_success_action=reboot systemd.unit=kernel-command-line.target/' "$BOOT_PATH/cmdline.txt"
fi

echo "✓ Done! Eject SD card, insert in Pi, and power on."
