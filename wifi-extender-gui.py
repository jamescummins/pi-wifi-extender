#!/usr/bin/env python3
"""
Pi WiFi Extender - Desktop GUI
A simple GTK-based GUI for managing the WiFi Extender
"""

import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, GLib, Gdk
import subprocess
import os
import threading
import json
import signal

CONFIG_FILE = "/var/lib/wifi-extender-backup/gui-config.json"
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

# CSS for styling
CSS = b"""
#log-view {
    font-family: monospace;
    font-size: 9pt;
}
"""

class WiFiExtenderGUI(Gtk.Window):
    def __init__(self):
        Gtk.Window.__init__(self, title="Pi WiFi Extender")
        self.set_border_width(15)
        self.set_default_size(500, 450)
        self.set_position(Gtk.WindowPosition.CENTER)
        self.running = True  # Track if app is running
        
        # Load saved config
        self.config = self.load_config()
        
        # Main container
        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=15)
        self.add(main_box)
        
        # Header
        header = Gtk.Label()
        header.set_markup("<big><b>📶 Pi WiFi Extender</b></big>")
        main_box.pack_start(header, False, False, 0)
        
        # Status frame
        status_frame = Gtk.Frame(label="Status")
        main_box.pack_start(status_frame, False, False, 0)
        
        self.status_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        self.status_box.set_border_width(10)
        status_frame.add(self.status_box)
        
        self.status_label = Gtk.Label(label="Checking status...")
        self.status_label.set_xalign(0)
        self.status_box.pack_start(self.status_label, False, False, 0)
        
        # Settings frame
        settings_frame = Gtk.Frame(label="Settings")
        main_box.pack_start(settings_frame, True, True, 0)
        
        settings_grid = Gtk.Grid()
        settings_grid.set_border_width(10)
        settings_grid.set_row_spacing(10)
        settings_grid.set_column_spacing(10)
        settings_frame.add(settings_grid)
        
        # SSID
        ssid_label = Gtk.Label(label="Network Name (SSID):")
        ssid_label.set_xalign(0)
        settings_grid.attach(ssid_label, 0, 0, 1, 1)
        
        self.ssid_entry = Gtk.Entry()
        self.ssid_entry.set_text(self.config.get("ssid", "PiExtender"))
        self.ssid_entry.set_hexpand(True)
        settings_grid.attach(self.ssid_entry, 1, 0, 1, 1)
        
        # Password
        pass_label = Gtk.Label(label="Password:")
        pass_label.set_xalign(0)
        settings_grid.attach(pass_label, 0, 1, 1, 1)
        
        self.pass_entry = Gtk.Entry()
        self.pass_entry.set_text(self.config.get("password", ""))
        self.pass_entry.set_visibility(False)
        self.pass_entry.set_hexpand(True)
        settings_grid.attach(self.pass_entry, 1, 1, 1, 1)
        
        self.show_pass = Gtk.CheckButton(label="Show password")
        self.show_pass.connect("toggled", self.on_show_pass_toggled)
        settings_grid.attach(self.show_pass, 1, 2, 1, 1)
        
        # Channel
        channel_label = Gtk.Label(label="WiFi Channel:")
        channel_label.set_xalign(0)
        settings_grid.attach(channel_label, 0, 3, 1, 1)
        
        self.channel_combo = Gtk.ComboBoxText()
        for ch in range(1, 14):
            self.channel_combo.append_text(str(ch))
        self.channel_combo.set_active(self.config.get("channel", 6) - 1)
        settings_grid.attach(self.channel_combo, 1, 3, 1, 1)
        
        # Country
        country_label = Gtk.Label(label="Country:")
        country_label.set_xalign(0)
        settings_grid.attach(country_label, 0, 4, 1, 1)
        
        self.country_combo = Gtk.ComboBoxText()
        countries = [
            ("IE", "Ireland"),
            ("GB", "United Kingdom"),
            ("US", "United States"),
            ("DE", "Germany"),
            ("FR", "France"),
            ("ES", "Spain"),
            ("IT", "Italy"),
            ("NL", "Netherlands"),
            ("BE", "Belgium"),
            ("AT", "Austria"),
            ("CH", "Switzerland"),
            ("AU", "Australia"),
            ("CA", "Canada"),
        ]
        self.country_codes = [c[0] for c in countries]
        for code, name in countries:
            self.country_combo.append_text(f"{code} - {name}")
        # Set default to IE or saved config
        saved_country = self.config.get("country", "IE")
        try:
            self.country_combo.set_active(self.country_codes.index(saved_country))
        except ValueError:
            self.country_combo.set_active(0)  # Default to IE
        settings_grid.attach(self.country_combo, 1, 4, 1, 1)
        
        # Band selection (for Pi 4 5GHz support)
        band_label = Gtk.Label(label="WiFi Band:")
        band_label.set_xalign(0)
        settings_grid.attach(band_label, 0, 5, 1, 1)
        
        self.band_combo = Gtk.ComboBoxText()
        self.band_combo.append_text("2.4 GHz (better range)")
        self.band_combo.append_text("5 GHz (faster speed)")
        self.band_combo.set_active(0 if self.config.get("band", "g") == "g" else 1)
        self.band_combo.connect("changed", self.on_band_changed)
        settings_grid.attach(self.band_combo, 1, 5, 1, 1)
        
        # Button box
        button_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        button_box.set_homogeneous(True)
        main_box.pack_start(button_box, False, False, 0)
        
        # Apply button
        self.apply_btn = Gtk.Button(label="✓ Apply Settings")
        self.apply_btn.get_style_context().add_class("suggested-action")
        self.apply_btn.connect("clicked", self.on_apply_clicked)
        button_box.pack_start(self.apply_btn, True, True, 0)
        
        # Revert button
        self.revert_btn = Gtk.Button(label="↩ Revert")
        self.revert_btn.connect("clicked", self.on_revert_clicked)
        button_box.pack_start(self.revert_btn, True, True, 0)
        
        # Uninstall button
        self.uninstall_btn = Gtk.Button(label="🗑 Uninstall")
        self.uninstall_btn.get_style_context().add_class("destructive-action")
        self.uninstall_btn.connect("clicked", self.on_uninstall_clicked)
        button_box.pack_start(self.uninstall_btn, True, True, 0)
        
        # Update section
        update_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        main_box.pack_start(update_box, False, False, 0)
        
        self.update_btn = Gtk.Button(label="⬇ Check for Updates")
        self.update_btn.connect("clicked", self.on_update_clicked)
        update_box.pack_start(self.update_btn, True, True, 0)
        
        # Progress bar (hidden by default)
        self.progress = Gtk.ProgressBar()
        self.progress.set_no_show_all(True)
        main_box.pack_start(self.progress, False, False, 0)
        
        # Log output
        log_frame = Gtk.Frame(label="Log")
        main_box.pack_start(log_frame, True, True, 0)
        
        scroll = Gtk.ScrolledWindow()
        scroll.set_min_content_height(100)
        log_frame.add(scroll)
        
        self.log_view = Gtk.TextView()
        self.log_view.set_editable(False)
        self.log_view.set_wrap_mode(Gtk.WrapMode.WORD)
        self.log_view.set_name("log-view")
        scroll.add(self.log_view)
        
        self.log_buffer = self.log_view.get_buffer()
        
        # Initial status check
        GLib.timeout_add(500, self.refresh_status)
    
    def load_config(self):
        """Load saved configuration"""
        try:
            if os.path.exists(CONFIG_FILE):
                with open(CONFIG_FILE, 'r') as f:
                    return json.load(f)
        except:
            pass
        return {}
    
    def save_config(self):
        """Save current configuration"""
        config = {
            "ssid": self.ssid_entry.get_text(),
            "password": self.pass_entry.get_text(),
            "channel": int(self.channel_combo.get_active_text() or "6"),
            "country": self.country_codes[self.country_combo.get_active()],
            "band": "g" if self.band_combo.get_active() == 0 else "a"
        }
        try:
            os.makedirs(os.path.dirname(CONFIG_FILE), exist_ok=True)
            with open(CONFIG_FILE, 'w') as f:
                json.dump(config, f)
        except PermissionError:
            pass  # Will be saved when running as root
        return config
    
    def log(self, message):
        """Add message to log"""
        GLib.idle_add(self._log_append, message)
    
    def _log_append(self, message):
        end_iter = self.log_buffer.get_end_iter()
        self.log_buffer.insert(end_iter, message + "\n")
        # Auto-scroll
        self.log_view.scroll_to_iter(self.log_buffer.get_end_iter(), 0, False, 0, 0)
    
    def on_show_pass_toggled(self, button):
        self.pass_entry.set_visibility(button.get_active())
    
    def on_band_changed(self, combo):
        """Update channel options based on band"""
        self.channel_combo.remove_all()
        if combo.get_active() == 0:  # 2.4 GHz
            for ch in range(1, 14):
                self.channel_combo.append_text(str(ch))
            self.channel_combo.set_active(5)  # Channel 6
        else:  # 5 GHz
            for ch in [36, 40, 44, 48, 149, 153, 157, 161]:
                self.channel_combo.append_text(str(ch))
            self.channel_combo.set_active(0)  # Channel 36
    
    def refresh_status(self):
        """Check current status"""
        threading.Thread(target=self._check_status, daemon=True).start()
        return False  # Don't repeat
    
    def _check_status(self):
        try:
            # Check if hostapd is running
            result = subprocess.run(
                ["systemctl", "is-active", "hostapd"],
                capture_output=True, text=True, timeout=5
            )
            hostapd_active = result.stdout.strip() == "active"
            
            # Get current SSID if active
            current_ssid = ""
            if hostapd_active:
                try:
                    if os.path.exists("/etc/hostapd/hostapd.conf"):
                        with open("/etc/hostapd/hostapd.conf", 'r') as f:
                            for line in f:
                                if line.startswith("ssid="):
                                    current_ssid = line.split("=", 1)[1].strip()
                                    break
                except PermissionError:
                    current_ssid = "(permission denied)"
            
            # Get connected clients
            clients = 0
            if hostapd_active:
                try:
                    result = subprocess.run(
                        ["iw", "dev", "wlan0", "station", "dump"],
                        capture_output=True, text=True, timeout=5
                    )
                    clients = result.stdout.count("Station")
                except:
                    pass
            
            # Update UI
            if hostapd_active:
                status = f"🟢 <b>Active</b> - Broadcasting: {current_ssid}\n"
                status += f"📱 Connected clients: {clients}"
            else:
                status = "🔴 <b>Not running</b>"
            
            GLib.idle_add(self._update_status, status)
            
        except Exception as e:
            GLib.idle_add(self._update_status, f"⚠ Error: {e}")
    
    def _update_status(self, status):
        self.status_label.set_markup(status)
    
    def run_command(self, cmd, success_msg, requires_reboot=False):
        """Run command in background thread"""
        self.set_buttons_sensitive(False)
        self.progress.show()
        self.progress.pulse()
        
        def pulse():
            if not self.running:
                return False
            if self.progress.get_visible():
                self.progress.pulse()
                return True
            return False
        
        GLib.timeout_add(100, pulse)
        
        def run():
            try:
                self.log(f"Running: {' '.join(cmd)}")
                result = subprocess.run(
                    cmd,
                    capture_output=True, text=True
                )
                
                if result.returncode == 0:
                    self.log(result.stdout if result.stdout else success_msg)
                    if requires_reboot:
                        GLib.idle_add(self.show_reboot_dialog)
                else:
                    self.log(f"Error: {result.stderr}")
                
            except Exception as e:
                self.log(f"Exception: {e}")
            finally:
                GLib.idle_add(self.command_finished)
        
        threading.Thread(target=run, daemon=True).start()
    
    def command_finished(self):
        self.progress.hide()
        self.set_buttons_sensitive(True)
        self.refresh_status()
    
    def set_buttons_sensitive(self, sensitive):
        self.apply_btn.set_sensitive(sensitive)
        self.revert_btn.set_sensitive(sensitive)
        self.uninstall_btn.set_sensitive(sensitive)
        self.update_btn.set_sensitive(sensitive)
    
    def show_reboot_dialog(self):
        dialog = Gtk.MessageDialog(
            parent=self,
            flags=0,
            message_type=Gtk.MessageType.QUESTION,
            buttons=Gtk.ButtonsType.YES_NO,
            text="Reboot Required"
        )
        dialog.format_secondary_text("Changes require a reboot. Reboot now?")
        response = dialog.run()
        dialog.destroy()
        
        if response == Gtk.ResponseType.YES:
            subprocess.run(["sudo", "reboot"])
    
    def on_apply_clicked(self, button):
        ssid = self.ssid_entry.get_text().strip()
        password = self.pass_entry.get_text()
        channel = self.channel_combo.get_active_text()
        country = self.country_codes[self.country_combo.get_active()]
        band = "g" if self.band_combo.get_active() == 0 else "a"
        
        # Validation
        if len(ssid) < 1 or len(ssid) > 32:
            self.log("Error: SSID must be 1-32 characters")
            return
        
        if len(password) < 8:
            self.log("Error: Password must be at least 8 characters")
            return
        
        self.save_config()
        
        setup_script = os.path.join(SCRIPT_DIR, "setup.sh")
        cmd = ["pkexec", setup_script, ssid, password, channel, country, band]
        self.run_command(cmd, "Setup complete!", requires_reboot=True)
    
    def on_revert_clicked(self, button):
        dialog = Gtk.MessageDialog(
            parent=self,
            flags=0,
            message_type=Gtk.MessageType.WARNING,
            buttons=Gtk.ButtonsType.OK_CANCEL,
            text="Revert Configuration?"
        )
        dialog.format_secondary_text("This will restore the previous network configuration.")
        response = dialog.run()
        dialog.destroy()
        
        if response == Gtk.ResponseType.OK:
            setup_script = os.path.join(SCRIPT_DIR, "setup.sh")
            cmd = ["pkexec", setup_script, "--revert"]
            self.run_command(cmd, "Reverted successfully!", requires_reboot=True)
    
    def on_uninstall_clicked(self, button):
        dialog = Gtk.MessageDialog(
            parent=self,
            flags=0,
            message_type=Gtk.MessageType.WARNING,
            buttons=Gtk.ButtonsType.OK_CANCEL,
            text="Uninstall WiFi Extender?"
        )
        dialog.format_secondary_text("This will remove the WiFi Extender and restore normal WiFi.")
        response = dialog.run()
        dialog.destroy()
        
        if response == Gtk.ResponseType.OK:
            uninstall_script = os.path.join(SCRIPT_DIR, "uninstall.sh")
            cmd = ["pkexec", uninstall_script]
            self.run_command(cmd, "Uninstalled successfully!", requires_reboot=True)
    
    def on_update_clicked(self, button):
        self.log("Checking for updates...")
        self.set_buttons_sensitive(False)
        
        def check_update():
            try:
                # Fetch latest from git
                result = subprocess.run(
                    ["git", "-C", SCRIPT_DIR, "fetch", "origin"],
                    capture_output=True, text=True
                )
                
                # Check if behind
                result = subprocess.run(
                    ["git", "-C", SCRIPT_DIR, "status", "-uno"],
                    capture_output=True, text=True
                )
                
                if "behind" in result.stdout:
                    GLib.idle_add(self.show_update_available)
                else:
                    self.log("✓ Already up to date!")
                    GLib.idle_add(self.command_finished)
                    
            except Exception as e:
                self.log(f"Update check failed: {e}")
                GLib.idle_add(self.command_finished)
        
        threading.Thread(target=check_update, daemon=True).start()
    
    def show_update_available(self):
        dialog = Gtk.MessageDialog(
            parent=self,
            flags=0,
            message_type=Gtk.MessageType.INFO,
            buttons=Gtk.ButtonsType.YES_NO,
            text="Update Available"
        )
        dialog.format_secondary_text("A new version is available. Download and install?")
        response = dialog.run()
        dialog.destroy()
        
        if response == Gtk.ResponseType.YES:
            self.log("Downloading update...")
            cmd = ["git", "-C", SCRIPT_DIR, "pull", "origin", "main"]
            
            def pull():
                try:
                    result = subprocess.run(cmd, capture_output=True, text=True)
                    if result.returncode == 0:
                        self.log("✓ Updated successfully! Restart the app to use new version.")
                    else:
                        self.log(f"Update failed: {result.stderr}")
                except Exception as e:
                    self.log(f"Update failed: {e}")
                finally:
                    GLib.idle_add(self.command_finished)
            
            threading.Thread(target=pull, daemon=True).start()
        else:
            self.command_finished()


def on_destroy(win):
    """Clean shutdown"""
    win.running = False
    Gtk.main_quit()


def main():
    # Handle Ctrl+C gracefully
    signal.signal(signal.SIGINT, signal.SIG_DFL)
    
    # Check for display
    if not os.environ.get('DISPLAY'):
        print("Error: No display found. Run from desktop or use: DISPLAY=:0 ./wifi-extender-gui.py")
        return 1
    
    # Load CSS
    css_provider = Gtk.CssProvider()
    css_provider.load_from_data(CSS)
    Gtk.StyleContext.add_provider_for_screen(
        Gdk.Screen.get_default(),
        css_provider,
        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
    )
    
    win = WiFiExtenderGUI()
    win.connect("destroy", on_destroy)
    win.show_all()
    win.progress.hide()
    Gtk.main()
    return 0


if __name__ == "__main__":
    exit(main())
