#!/usr/bin/env python3
import subprocess
import os
import shutil
import sys
import time

TAG_FILE = "/tmp/fuzzel_current_menu"

def check_toggle(menu_name):
    if subprocess.run(["pgrep", "-x", "fuzzel"], stdout=subprocess.DEVNULL).returncode == 0:
        if os.path.exists(TAG_FILE):
            try:
                with open(TAG_FILE, "r") as f:
                    curr = f.read().strip()
                if curr == menu_name:
                    subprocess.run(["pkill", "-x", "fuzzel"])
                    os.remove(TAG_FILE)
                    sys.exit(0)
            except Exception:
                pass
        subprocess.run(["pkill", "-x", "fuzzel"])
        time.sleep(0.05)
    with open(TAG_FILE, "w") as f:
        f.write(menu_name)

def cleanup_tag():
    if os.path.exists(TAG_FILE):
        try:
            os.remove(TAG_FILE)
        except Exception:
            pass

def run_cmd(cmd):
    try:
        return subprocess.check_output(cmd, stderr=subprocess.PIPE, text=True)
    except Exception:
        return ""

def notify(summary, body="", icon="battery-good"):
    subprocess.run(["notify-send", "-i", icon, summary, body])

def fuzzel_menu(prompt, lines, options, width=54):
    fuzzel_cmd = [
        "fuzzel", "--dmenu",
        "--prompt", f"{prompt} ",
        "--lines", str(min(max(lines, 3), 16)),
        "--width", str(width)
    ]
    proc = subprocess.Popen(fuzzel_cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
    out, _ = proc.communicate(input="\n".join(options))
    cleanup_tag()
    return out.strip() if proc.returncode == 0 else None

def get_battery_info():
    out = run_cmd(["upower", "-i", "/org/freedesktop/UPower/devices/battery_BAT1"])
    data = {}
    for line in out.split("\n"):
        line = line.strip()
        if ":" in line:
            k, v = line.split(":", 1)
            data[k.strip()] = v.strip()

    state = data.get("state", "Discharging").capitalize()
    percentage = data.get("percentage", "100%")
    time_to_empty = data.get("time to empty", "")
    time_to_full = data.get("time to full", "")
    time_str = f"{time_to_empty} remaining" if time_to_empty else (f"{time_to_full} until full" if time_to_full else "")
    capacity = data.get("capacity", "")
    energy_full = data.get("energy-full", "")
    energy_design = data.get("energy-full-design", "")
    energy_rate = data.get("energy-rate", "")
    voltage = data.get("voltage", "")

    # Pick dynamic battery icon
    try:
        pct_num = int(percentage.replace("%", "").strip())
    except Exception:
        pct_num = 100

    if "charging" in state.lower():
        icon = "󰂄"
    elif pct_num >= 90:
        icon = "󰁹"
    elif pct_num >= 70:
        icon = "󰂀"
    elif pct_num >= 50:
        icon = "󰁾"
    elif pct_num >= 30:
        icon = "󰁼"
    elif pct_num >= 15:
        icon = "󰁻"
    else:
        icon = "󰁺"

    return {
        "state": state,
        "percentage": percentage,
        "time_str": time_str,
        "capacity": capacity,
        "energy_full": energy_full,
        "energy_design": energy_design,
        "energy_rate": energy_rate,
        "voltage": voltage,
        "icon": icon,
        "raw": out
    }

def get_power_profile():
    curr = run_cmd(["powerprofilesctl", "get"]).strip().lower()
    if not curr:
        curr = run_cmd(["tlpctl", "get"]).strip().lower()
    return curr or "balanced"

def set_power_profile(profile):
    if shutil.which("powerprofilesctl"):
        subprocess.run(["powerprofilesctl", "set", profile])
    if shutil.which("tlpctl"):
        subprocess.run(["tlpctl", "set", profile])

def show_battery_details(info):
    lines = [
        "Battery Hardware & Health Diagnostics",
        "───────────────────────────────────────────────"
    ]
    for line in info["raw"].split("\n"):
        line = line.strip()
        if line and not line.startswith("History"):
            lines.append(f"  {line}")
    lines.append("───────────────────────────────────────────────")
    lines.append("󰌑  Back to Power Menu")
    fuzzel_menu("Diagnostics", len(lines), lines, width=54)

def main():
    check_toggle("battery")
    info = get_battery_info()
    curr_profile = get_power_profile()

    menu_items = []

    # Section 1: Real-Time Battery Status & Health
    menu_items.append("── Battery Status ─────────────────────────────")
    status_suffix = f" — {info['time_str']}" if info['time_str'] else ""
    menu_items.append(f"●  {info['icon']}  {info['percentage']} ({info['state']}){status_suffix}")

    health_pct = f"{float(info['capacity'].replace('%','')):.1f}%" if info['capacity'] else "N/A"
    wh_info = f" ({info['energy_full']} / {info['energy_design']})" if info['energy_full'] and info['energy_design'] else ""
    menu_items.append(f"   󰂑  Battery Health: {health_pct}{wh_info}")

    if info['energy_rate']:
        volt_info = f" @ {info['voltage']}" if info['voltage'] else ""
        menu_items.append(f"   󱐋  Current Power Draw: {info['energy_rate']}{volt_info}")

    # Section 2: Power Management Profiles
    menu_items.append("── Power Management Profiles ──────────────────")
    perf_active = "●" if curr_profile == "performance" else "○"
    bal_active = "●" if curr_profile == "balanced" else "○"
    save_active = "●" if curr_profile in ("power-saver", "powersave") else "○"

    menu_items.append(f"{perf_active}  󰓅  Performance Profile    (Maximum Speed & Clocks)")
    menu_items.append(f"{bal_active}  󰾅  Balanced Profile       (Standard Adaptive Balance)")
    menu_items.append(f"{save_active}  󰾆  Power Saver Profile    (Reduced Power Draw)")

    # Section 3: Power Diagnostics & Tools
    menu_items.append("── Battery Diagnostics & Tools ───────────────")
    menu_items.append("󰌨  Launch Powertop (Power Monitor & Tunables)")
    menu_items.append("󰍛  Launch System Activity Monitor (htop)")
    menu_items.append("󱩎  View Detailed Hardware & Health Diagnostics")
    menu_items.append("󰌑  Close Menu")

    choice = fuzzel_menu("Battery & Profiles", len(menu_items), menu_items)
    if not choice or "Close Menu" in choice or choice.startswith("──"):
        return

    # Profile switches
    if "Performance Profile" in choice:
        set_power_profile("performance")
        notify("Power Profile", "Switched to Performance mode", icon="power-profile-performance")
        subprocess.Popen([sys.executable, __file__])
        return
    elif "Balanced Profile" in choice:
        set_power_profile("balanced")
        notify("Power Profile", "Switched to Balanced mode", icon="power-profile-balanced")
        subprocess.Popen([sys.executable, __file__])
        return
    elif "Power Saver Profile" in choice:
        set_power_profile("power-saver")
        notify("Power Profile", "Switched to Power Saver mode", icon="power-profile-power-saver")
        subprocess.Popen([sys.executable, __file__])
        return

    # Tools
    elif "Powertop" in choice:
        subprocess.Popen(["kitty", "--class", "powertop", "-e", "sudo", "powertop"])
    elif "Activity Monitor" in choice:
        subprocess.Popen(["kitty", "--class", "htop", "-e", "htop"])
    elif "Detailed Hardware & Health Diagnostics" in choice or "Battery Health:" in choice:
        show_battery_details(info)
        subprocess.Popen([sys.executable, __file__])

if __name__ == "__main__":
    main()
