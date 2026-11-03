#!/usr/bin/env python3
import json
import os
import signal
import subprocess
import sys
import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
from gi.repository import Gtk, Gdk, GLib

PID_FILE = "/tmp/nightlight_slider.pid"
CONFIG_FILE = os.path.expanduser("~/.config/waybar/scripts/nightlight.json")
NIGHTLIGHT_BIN = os.path.expanduser("~/.config/waybar/scripts/nightlight.py")

def check_single_instance():
    if os.path.exists(PID_FILE):
        try:
            with open(PID_FILE, "r") as f:
                pid = int(f.read().strip())
            os.kill(pid, signal.SIGTERM)
            os.remove(PID_FILE)
            sys.exit(0)
        except (ProcessLookupError, ValueError):
            pass
        except Exception:
            pass
    with open(PID_FILE, "w") as f:
        f.write(str(os.getpid()))

def cleanup_pid():
    if os.path.exists(PID_FILE):
        try:
            with open(PID_FILE, "r") as f:
                if f.read().strip() == str(os.getpid()):
                    os.remove(PID_FILE)
        except Exception:
            pass

def load_config():
    if os.path.exists(CONFIG_FILE):
        try:
            with open(CONFIG_FILE, "r") as f:
                return json.load(f)
        except Exception:
            pass
    return {"enabled": False, "temp": 3500}

def is_wlsunset_running():
    res = subprocess.run(["pgrep", "-x", "wlsunset"], stdout=subprocess.DEVNULL)
    return res.returncode == 0

class NightLightWindow(Gtk.Window):
    def __init__(self):
        super().__init__(title="Night Light")
        self.set_default_size(380, 220)
        self.set_position(Gtk.WindowPosition.CENTER)
        self.set_resizable(False)

        self.cfg = load_config()
        self.is_active = is_wlsunset_running()
        self.update_timer = None

        self.apply_styles()
        self.build_ui()

        self.connect("destroy", self.on_close)
        self.connect("key-press-event", self.on_key_press)
        self.connect("focus-out-event", self.on_focus_out)

    def apply_styles(self):
        css_provider = Gtk.CssProvider()
        css = b"""
        window {
            background-color: #1e1e1e;
            border: 1px solid rgba(255, 255, 255, 0.15);
            border-radius: 16px;
        }
        .main-box {
            padding: 20px;
        }
        label {
            color: #ffffff;
            font-family: "Adwaita Sans", "Inter", sans-serif;
        }
        .title-label {
            font-size: 18px;
            font-weight: 800;
        }
        .sub-label {
            font-size: 13px;
            color: rgba(255, 255, 255, 0.6);
        }
        .warmth-label {
            font-size: 14px;
            font-weight: 700;
            color: #f8e45c;
            margin-top: 6px;
        }
        scale trough {
            background-color: rgba(255, 255, 255, 0.12);
            min-height: 10px;
            border-radius: 5px;
        }
        scale highlight {
            background: linear-gradient(to right, #62a0ea, #f8e45c, #ff7800);
            border-radius: 5px;
            min-height: 10px;
        }
        scale slider {
            min-width: 20px;
            min-height: 20px;
            border-radius: 10px;
            background-color: #ffffff;
            box-shadow: 0 2px 4px rgba(0, 0, 0, 0.4);
        }
        button.preset-btn {
            background-color: rgba(255, 255, 255, 0.08);
            border-radius: 8px;
            padding: 6px 10px;
            font-size: 12px;
            font-weight: 700;
            color: #ffffff;
            border: 1px solid rgba(255, 255, 255, 0.08);
        }
        button.preset-btn:hover {
            background-color: rgba(255, 255, 255, 0.2);
            border-color: rgba(255, 255, 255, 0.25);
        }
        """
        css_provider.load_from_data(css)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

    def kelvin_to_warmth_pct(self, kelvin):
        pct = (6500 - kelvin) / 4500.0 * 100.0
        return max(0, min(100, round(pct)))

    def warmth_pct_to_kelvin(self, pct):
        kelvin = 6500 - (pct / 100.0) * 4500.0
        return max(2000, min(6500, round(kelvin / 50) * 50))

    def build_ui(self):
        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
        main_box.get_style_context().add_class("main-box")
        self.add(main_box)

        # Header Row
        header_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        
        icon_lbl = Gtk.Label(label="🌙")
        icon_lbl.get_style_context().add_class("title-label")
        header_box.pack_start(icon_lbl, False, False, 0)

        title_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        t_lbl = Gtk.Label(label="Night Light", xalign=0)
        t_lbl.get_style_context().add_class("title-label")
        sub_lbl = Gtk.Label(label="Screen Warmth & Eye Comfort", xalign=0)
        sub_lbl.get_style_context().add_class("sub-label")
        title_vbox.pack_start(t_lbl, False, False, 0)
        title_vbox.pack_start(sub_lbl, False, False, 0)
        header_box.pack_start(title_vbox, True, True, 0)

        # Toggle Switch
        self.switch = Gtk.Switch()
        self.switch.set_active(self.is_active)
        self.switch.set_valign(Gtk.Align.CENTER)
        self.switch.connect("state-set", self.on_switch_toggled)
        header_box.pack_end(self.switch, False, False, 0)

        main_box.pack_start(header_box, False, False, 0)

        # Warmth status label
        curr_temp = self.cfg.get("temp", 3500)
        curr_pct = self.kelvin_to_warmth_pct(curr_temp)
        self.warmth_lbl = Gtk.Label(xalign=0)
        self.warmth_lbl.get_style_context().add_class("warmth-label")
        self.update_warmth_text(curr_pct, curr_temp)
        main_box.pack_start(self.warmth_lbl, False, False, 0)

        # Warmth Slider
        self.scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 1)
        self.scale.set_value(curr_pct)
        self.scale.set_draw_value(False)
        self.scale.connect("value-changed", self.on_slider_changed)
        main_box.pack_start(self.scale, False, False, 0)

        # Scale tick labels
        ticks_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        cool_lbl = Gtk.Label(label="Cool (6500K)", xalign=0)
        cool_lbl.get_style_context().add_class("sub-label")
        warm_lbl = Gtk.Label(label="Warm (2000K)", xalign=1)
        warm_lbl.get_style_context().add_class("sub-label")
        ticks_box.pack_start(cool_lbl, True, True, 0)
        ticks_box.pack_end(warm_lbl, True, True, 0)
        main_box.pack_start(ticks_box, False, False, 0)

        # Presets Row
        presets_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        presets_box.set_homogeneous(True)

        presets = [
            ("Neutral", 6500),
            ("Mild (4500K)", 4500),
            ("Warm (3500K)", 3500),
            ("Deep (2500K)", 2500)
        ]
        for name, k in presets:
            btn = Gtk.Button(label=name)
            btn.get_style_context().add_class("preset-btn")
            btn.connect("clicked", self.on_preset_clicked, k)
            presets_box.pack_start(btn, True, True, 0)

        main_box.pack_start(presets_box, False, False, 0)

    def update_warmth_text(self, pct, kelvin):
        if not self.switch.get_active():
            self.warmth_lbl.set_text("Status: Disabled (Click switch or drag slider to enable)")
        else:
            if pct == 0:
                desc = "Neutral / Off"
            elif pct < 35:
                desc = "Mild Comfort"
            elif pct < 70:
                desc = "Warm"
            else:
                desc = "Very Warm / Night"
            self.warmth_lbl.set_text(f"Warmth: {pct}%  •  {kelvin} K  ({desc})")

    def on_switch_toggled(self, switch, state):
        pct = round(self.scale.get_value())
        kelvin = self.warmth_pct_to_kelvin(pct)
        self.update_warmth_text(pct, kelvin)
        if state:
            subprocess.run([NIGHTLIGHT_BIN, "set", str(kelvin)])
        else:
            subprocess.run([NIGHTLIGHT_BIN, "stop"])
        return False

    def on_slider_changed(self, scale):
        pct = round(scale.get_value())
        kelvin = self.warmth_pct_to_kelvin(pct)
        
        # If switch is off, automatically enable it
        if not self.switch.get_active():
            self.switch.set_active(True)

        self.update_warmth_text(pct, kelvin)

        # Debounce updating wlsunset
        if self.update_timer:
            GLib.source_remove(self.update_timer)
        self.update_timer = GLib.timeout_add(40, self.apply_temperature, kelvin)

    def apply_temperature(self, kelvin):
        subprocess.run([NIGHTLIGHT_BIN, "set", str(kelvin)])
        self.update_timer = None
        return False

    def on_preset_clicked(self, btn, kelvin):
        pct = self.kelvin_to_warmth_pct(kelvin)
        self.scale.set_value(pct)
        if kelvin == 6500:
            self.switch.set_active(False)
            subprocess.run([NIGHTLIGHT_BIN, "stop"])
        else:
            self.switch.set_active(True)
            subprocess.run([NIGHTLIGHT_BIN, "set", str(kelvin)])

    def on_key_press(self, widget, event):
        if event.keyval in (Gdk.KEY_Escape, Gdk.KEY_q):
            self.close()
            return True
        return False

    def on_focus_out(self, widget, event):
        # Auto-close on click outside / focus loss
        self.close()
        return False

    def on_close(self, widget):
        cleanup_pid()
        Gtk.main_quit()

def main():
    check_single_instance()
    win = NightLightWindow()
    win.show_all()
    Gtk.main()

if __name__ == "__main__":
    main()
