# Pi WiFi Extender

Turn your Raspberry Pi into a WiFi access point via ethernet.

```
[Router] ──ethernet──▶ [Pi] )))WiFi))) [Devices]
```

## Quick Start

```bash
# Install GUI
./install-gui.sh

# Launch GUI
./wifi-extender-gui.py
```

Or via command line:
```bash
sudo ./setup.sh "MyNetwork" "MyPassword123"
sudo reboot
```

## GUI Features

- Configure SSID, password, channel, country
- Choose 2.4GHz or 5GHz band
- Apply settings with one click
- Revert to previous configuration
- Check for updates from GitHub

## Compatibility

| OS | Status |
|----|--------|
| Raspberry Pi OS Bookworm (2023+) | ✅ NetworkManager |
| Raspberry Pi OS Bullseye | ✅ dhcpcd |
| Raspberry Pi 4/5 | ✅ Tested |

## Commands

| Command | Description |
|---------|-------------|
| `./wifi-extender-gui.py` | Launch GUI |
| `./status.sh` | Check status |
| `sudo ./setup.sh --revert` | Restore previous config |
| `sudo ./uninstall.sh` | Remove completely |

## Pi Imager (Headless Setup)

After flashing your SD card:
```bash
./install-to-sdcard.sh /media/user/bootfs "MyNetwork" "MyPassword123"
```

## License

MIT
