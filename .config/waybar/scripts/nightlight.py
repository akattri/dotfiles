#!/usr/bin/env python3
import json
import os
import subprocess
import sys

CONFIG_FILE = os.path.expanduser("~/.config/waybar/scripts/nightlight.json")
DEFAULT_CONFIG = {"enabled": False, "temp": 3500}

def load_config():
    if os.path.exists(CONFIG_FILE):
        try:
            with open(CONFIG_FILE, "r") as f:
                return json.load(f)
        except Exception:
            pass
    return DEFAULT_CONFIG.copy()

def save_config(cfg):
    os.makedirs(os.path.dirname(CONFIG_FILE), exist_ok=True)
    with open(CONFIG_FILE, "w") as f:
        json.dump(cfg, f)

def is_running():
    res = subprocess.run(["pgrep", "-x", "wlsunset"], stdout=subprocess.DEVNULL)
    return res.returncode == 0

def start_wlsunset(temp):
    subprocess.run(["pkill", "-x", "wlsunset"], stderr=subprocess.DEVNULL)
    subprocess.Popen(
        ["wlsunset", "-S", "00:00", "-s", "00:00", "-t", str(temp)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True
    )

def stop_wlsunset():
    subprocess.run(["pkill", "-x", "wlsunset"], stderr=subprocess.DEVNULL)

def signal_waybar():
    subprocess.run(["pkill", "-RTMIN+11", "waybar"], stderr=subprocess.DEVNULL)

def status():
    cfg = load_config()
    active = is_running()
    temp = cfg.get("temp", 3500)
    
    # Warmth label
    if not active:
        tooltip = "Night Light: Off\n\nClick: Adjust Warmth\nRight-click: Turn On"
        state = "off"
    else:
        tooltip = f"Night Light: Active ({temp}K)\n\nClick: Adjust Warmth\nRight-click: Turn Off\nScroll: Adjust Warmth"
        state = "on"

    output = {
        "text": "",
        "alt": state,
        "class": state,
        "tooltip": tooltip
    }
    print(json.dumps(output))

def toggle():
    cfg = load_config()
    temp = cfg.get("temp", 3500)
    if is_running():
        stop_wlsunset()
        cfg["enabled"] = False
        save_config(cfg)
    else:
        start_wlsunset(temp)
        cfg["enabled"] = True
        save_config(cfg)
    signal_waybar()

def adjust(delta):
    cfg = load_config()
    temp = cfg.get("temp", 3500)
    temp = max(2000, min(6500, temp + delta))
    cfg["temp"] = temp
    cfg["enabled"] = True
    save_config(cfg)
    start_wlsunset(temp)
    signal_waybar()

def set_temp(val):
    cfg = load_config()
    val = max(2000, min(6500, int(val)))
    cfg["temp"] = val
    cfg["enabled"] = True
    save_config(cfg)
    start_wlsunset(val)
    signal_waybar()

def main():
    if len(sys.argv) < 2:
        status()
        return

    action = sys.argv[1]
    if action == "status":
        status()
    elif action == "toggle":
        toggle()
    elif action == "warmer":
        # Warmer = lower Kelvin
        adjust(-250)
    elif action == "cooler":
        # Cooler = higher Kelvin
        adjust(250)
    elif action == "set" and len(sys.argv) > 2:
        set_temp(sys.argv[2])
    elif action == "stop":
        cfg = load_config()
        cfg["enabled"] = False
        save_config(cfg)
        stop_wlsunset()
        signal_waybar()

if __name__ == "__main__":
    main()
