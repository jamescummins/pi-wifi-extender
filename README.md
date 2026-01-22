# Pi WiFi Extender

Turn your Raspberry Pi into a WiFi access point via ethernet.

```
[Router] ──ethernet──▶ [Pi] )))WiFi))) [Devices]
```

## Features

- **Bridged mode** - devices get IPs from your main router
- **Simple setup** - one command
- **Pi Imager support** - auto-configure on first boot
- **GUI settings** - change SSID/password anytime

## Quick Setup

```bash
sudo ./setup.sh "MyNetwork" "MyPassword123"
sudo reboot
```

With options:
```bash
sudo ./setup.sh "MyNetwork" "MyPassword123" 6 IE
#                SSID        Password      Channel Country
```

## For Pi Imager (Auto-setup on first boot)

After flashing SD card:
```bash
./install-to-sdcard.sh /media/user/bootfs "MyNetwork" "MyPassword123"
```
Eject, insert in Pi, power on. Done!

## Other Commands

```bash
./status.sh              # Check status
./settings-gui.py        # GUI to change settings
sudo ./uninstall.sh      # Remove and restore normal WiFi
```

## Defaults

- Country: IE (Ireland)
- Channel: 6
- Mode: Bridged (devices get IPs from your router)
