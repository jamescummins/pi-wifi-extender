#!/usr/bin/env python3
"""Pi WiFi Extender - Settings GUI"""

import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk
import subprocess
import os

HOSTAPD_CONF = "/etc/hostapd/hostapd.conf"

class SettingsWindow(Gtk.Window):
    def __init__(self):
        super().__init__(title="WiFi Extender Settings")
        self.set_default_size(350, 250)
        self.set_border_width(15)
        self.set_position(Gtk.WindowPosition.CENTER)

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        self.add(vbox)

        # Title
        title = Gtk.Label()
        title.set_markup("<b>📡 WiFi Extender Settings</b>")
        vbox.pack_start(title, False, False, 5)

        # Form
        grid = Gtk.Grid(column_spacing=10, row_spacing=8)
        vbox.pack_start(grid, False, False, 0)

        # SSID
        grid.attach(Gtk.Label(label="Network Name:", xalign=1), 0, 0, 1, 1)
        self.ssid = Gtk.Entry()
        self.ssid.set_hexpand(True)
        grid.attach(self.ssid, 1, 0, 1, 1)

        # Password
        grid.attach(Gtk.Label(label="Password:", xalign=1), 0, 1, 1, 1)
        pass_box = Gtk.Box(spacing=5)
        self.password = Gtk.Entry()
        self.password.set_visibility(False)
        self.password.set_hexpand(True)
        pass_box.pack_start(self.password, True, True, 0)
        show_btn = Gtk.ToggleButton(label="👁")
        show_btn.connect("toggled", lambda b: self.password.set_visibility(b.get_active()))
        pass_box.pack_start(show_btn, False, False, 0)
        grid.attach(pass_box, 1, 1, 1, 1)

        # Channel
        grid.attach(Gtk.Label(label="Channel:", xalign=1), 0, 2, 1, 1)
        self.channel = Gtk.ComboBoxText()
        for ch in ["1", "6", "11"]:
            self.channel.append_text(ch)
        self.channel.set_active(1)
        grid.attach(self.channel, 1, 2, 1, 1)

        # Country
        grid.attach(Gtk.Label(label="Country:", xalign=1), 0, 3, 1, 1)
        self.country = Gtk.ComboBoxText()
        for c in ["IE", "GB", "US", "DE", "FR"]:
            self.country.append_text(c)
        self.country.set_active(0)
        grid.attach(self.country, 1, 3, 1, 1)

        # Status
        self.status = Gtk.Label()
        self.status.set_margin_top(10)
        vbox.pack_start(self.status, False, False, 0)

        # Buttons
        btn_box = Gtk.Box(spacing=10)
        btn_box.set_margin_top(10)
        vbox.pack_start(btn_box, False, False, 0)

        restart_btn = Gtk.Button(label="🔄 Restart AP")
        restart_btn.connect("clicked", self.on_restart)
        btn_box.pack_start(restart_btn, True, True, 0)

        save_btn = Gtk.Button(label="💾 Save & Reboot")
        save_btn.connect("clicked", self.on_save)
        btn_box.pack_start(save_btn, True, True, 0)

        self.load_config()
        self.update_status()

    def load_config(self):
        """Load current settings from hostapd.conf"""
        if not os.path.exists(HOSTAPD_CONF):
            self.status.set_markup("<span color='red'>Not configured</span>")
            return
        try:
            with open(HOSTAPD_CONF) as f:
                for line in f:
                    if line.startswith("ssid="):
                        self.ssid.set_text(line.strip().split("=", 1)[1])
                    elif line.startswith("wpa_passphrase="):
                        self.password.set_text(line.strip().split("=", 1)[1])
                    elif line.startswith("channel="):
                        ch = line.strip().split("=", 1)[1]
                        for i, t in enumerate(["1", "6", "11"]):
                            if ch == t:
                                self.channel.set_active(i)
                    elif line.startswith("country_code="):
                        cc = line.strip().split("=", 1)[1]
                        for i, t in enumerate(["IE", "GB", "US", "DE", "FR"]):
                            if cc == t:
                                self.country.set_active(i)
        except PermissionError:
            pass

    def update_status(self):
        """Update status display"""
        result = subprocess.run(["systemctl", "is-active", "hostapd"], capture_output=True, text=True)
        if result.stdout.strip() == "active":
            self.status.set_markup("<span color='green'>● Running</span>")
        else:
            self.status.set_markup("<span color='red'>● Stopped</span>")

    def on_restart(self, btn):
        """Restart hostapd service"""
        subprocess.run(["pkexec", "systemctl", "restart", "hostapd"])
        self.update_status()

    def on_save(self, btn):
        """Save config and reboot"""
        ssid = self.ssid.get_text().strip()
        password = self.password.get_text()
        channel = self.channel.get_active_text()
        country = self.country.get_active_text()

        if not ssid:
            self.show_error("Enter a network name")
            return
        if len(password) < 8:
            self.show_error("Password must be at least 8 characters")
            return

        # Write new config
        config = f"""interface=wlan0
bridge=br0
driver=nl80211
ssid={ssid}
hw_mode=g
channel={channel}
country_code={country}
wpa=2
wpa_passphrase={password}
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
wmm_enabled=1
ieee80211n=1
"""
        # Save via pkexec
        try:
            proc = subprocess.Popen(
                ["pkexec", "tee", HOSTAPD_CONF],
                stdin=subprocess.PIPE, stdout=subprocess.DEVNULL
            )
            proc.communicate(config.encode())
            subprocess.run(["pkexec", "chmod", "600", HOSTAPD_CONF])
            subprocess.run(["pkexec", "reboot"])
        except Exception as e:
            self.show_error(str(e))

    def show_error(self, msg):
        dialog = Gtk.MessageDialog(
            transient_for=self, flags=0,
            message_type=Gtk.MessageType.ERROR,
            buttons=Gtk.ButtonsType.OK, text=msg
        )
        dialog.run()
        dialog.destroy()

if __name__ == "__main__":
    win = SettingsWindow()
    win.connect("destroy", Gtk.main_quit)
    win.show_all()
    Gtk.main()
