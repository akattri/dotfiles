#!/usr/bin/env python3
import subprocess
import sys
import os
import re
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

def notify(summary, body="", icon="bluetooth-active"):
    subprocess.run(["notify-send", "-i", icon, summary, body])

def fuzzel_menu(prompt, lines, options, width=52):
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

def get_device_info(mac):
    info = run_cmd(["bluetoothctl", "info", mac])
    connected = "Connected: yes" in info
    paired = "Paired: yes" in info
    trusted = "Trusted: yes" in info
    name = mac

    for line in info.split("\n"):
        line = line.strip()
        if line.startswith("Name: ") or line.startswith("Alias: "):
            name = line.split(":", 1)[1].strip()
            break

    # Battery
    battery = None
    m_bat = re.search(r"Battery Percentage:.*?\(([0-9]+)\)", info)
    if m_bat:
        battery = f"{m_bat.group(1)}%"
    else:
        m_bat2 = re.search(r"Battery:\s*([0-9]+)%", info)
        if m_bat2:
            battery = f"{m_bat2.group(1)}%"

    # Icon detection
    info_low = info.lower()
    if "icon: audio-headset" in info_low or "headphone" in info_low or "wh-" in name.lower():
        icon = "󰋋"
    elif "icon: audio-speaker" in info_low or "speaker" in info_low:
        icon = "󰓃"
    elif "icon: input-mouse" in info_low or "mouse" in info_low:
        icon = "󰍽"
    elif "icon: input-keyboard" in info_low or "keyboard" in info_low:
        icon = "󰌌"
    elif "phone" in info_low or "mobile" in info_low:
        icon = "󰄡"
    elif "computer" in info_low:
        icon = "󰌢"
    else:
        icon = "󰂯"

    return {
        "mac": mac,
        "name": name,
        "connected": connected,
        "paired": paired,
        "trusted": trusted,
        "battery": battery,
        "icon": icon,
        "raw_info": info
    }

def device_action_menu(dev):
    actions = []
    actions.append(f"Device: {dev['name']} ({dev['mac']})")
    actions.append("───────────────────────────────────────────────")
    if dev["connected"]:
        actions.append(f"󰅚  Disconnect from {dev['name']}")
    else:
        actions.append(f"󰂱  Connect to {dev['name']}")

    if not dev["paired"]:
        actions.append(f"󰂯  Pair with {dev['name']}")

    trust_action = "Untrust Device" if dev["trusted"] else "Trust Device"
    actions.append(f"󰄬  {trust_action}")
    actions.append(f"󰆴  Remove / Unpair {dev['name']}")
    actions.append("󰋽  Show Diagnostics & Details")
    actions.append("󰌑  Back to Bluetooth Menu")

    choice = fuzzel_menu(f"Manage: {dev['name']}", len(actions), actions, width=54)
    if not choice or "Back to Bluetooth Menu" in choice:
        return "menu"

    mac = dev["mac"]
    if "Disconnect from" in choice:
        notify("Bluetooth", f"Disconnecting {dev['name']}...")
        subprocess.run(["bluetoothctl", "disconnect", mac])
        return None
    elif "Connect to" in choice:
        notify("Bluetooth", f"Connecting to {dev['name']}...")
        subprocess.run(["bluetoothctl", "trust", mac])
        res = subprocess.run(["bluetoothctl", "connect", mac], capture_output=True, text=True)
        if "Successful" in res.stdout or "Connection successful" in res.stdout:
            notify("Bluetooth", f"Connected to {dev['name']}")
        else:
            notify("Bluetooth", f"Failed: {res.stdout.strip() or res.stderr.strip()}", icon="bluetooth-disabled")
        return None
    elif "Pair with" in choice:
        notify("Bluetooth", f"Pairing with {dev['name']}...")
        subprocess.run(["bluetoothctl", "pair", mac])
        subprocess.run(["bluetoothctl", "trust", mac])
        subprocess.run(["bluetoothctl", "connect", mac])
        return None
    elif "Trust Device" in choice:
        subprocess.run(["bluetoothctl", "trust", mac])
        notify("Bluetooth", f"Trusted {dev['name']}")
        return "menu"
    elif "Untrust Device" in choice:
        subprocess.run(["bluetoothctl", "untrust", mac])
        notify("Bluetooth", f"Untrusted {dev['name']}")
        return "menu"
    elif "Remove / Unpair" in choice:
        subprocess.run(["bluetoothctl", "remove", mac])
        notify("Bluetooth", f"Removed {dev['name']}")
        return None
    elif "Show Diagnostics" in choice:
        lines = [line.strip() for line in dev["raw_info"].split("\n") if line.strip()]
        lines.append("───────────────────────────────────────────────")
        lines.append("󰌑  Back")
        fuzzel_menu(f"Info: {dev['name']}", len(lines), lines, width=54)
        return "menu"

    return "menu"

def main():
    check_toggle("bluetooth")
    show = run_cmd(["bluetoothctl", "show"])
    is_powered = "Powered: yes" in show
    is_discoverable = "Discoverable: yes" in show
    is_pairable = "Pairable: yes" in show

    # Controller alias
    adapter_name = "Bluetooth Controller"
    m_name = re.search(r"Alias:\s*(.+)", show)
    if m_name:
        adapter_name = m_name.group(1).strip()

    if not is_powered:
        menu_items = [
            "── Bluetooth Disabled ───────────────────────────",
            "󰂯  Turn ON Bluetooth",
            "  Open Bluetooth Manager (bluetoothctl)",
            "󰌑  Cancel"
        ]
        choice = fuzzel_menu("Bluetooth", len(menu_items), menu_items)
        if choice and "Turn ON Bluetooth" in choice:
            subprocess.run(["bluetoothctl", "power", "on"])
            notify("Bluetooth", "Bluetooth turned ON")
        elif choice and "Open Bluetooth Manager" in choice:
            subprocess.Popen(["kitty", "--class", "bluetoothctl", "-e", "bluetoothctl"])
        return

    # Bluetooth is ON - query devices
    devices_raw = run_cmd(["bluetoothctl", "devices"]).strip().split("\n")
    dev_list = []
    for line in devices_raw:
        if not line.startswith("Device "):
            continue
        parts = line.split(" ", 2)
        if len(parts) >= 2:
            mac = parts[1]
            dev_list.append(get_device_info(mac))

    connected_devs = [d for d in dev_list if d["connected"]]
    paired_devs = [d for d in dev_list if d["paired"] and not d["connected"]]
    other_devs = [d for d in dev_list if not d["paired"] and not d["connected"]]

    menu_items = []

    # Section 1: Connected Devices
    menu_items.append("── Connected Devices ──────────────────────────")
    if connected_devs:
        for d in connected_devs:
            bat_tag = f"  󰂎 {d['battery']}" if d['battery'] else ""
            menu_items.append(f"●  {d['icon']}  {d['name']:<24}{bat_tag}  [Connected]")
    else:
        menu_items.append("○  󰂲  No devices currently connected")

    # Section 2: Paired / Known Devices
    if paired_devs:
        menu_items.append("── Paired Devices ─────────────────────────────")
        for d in paired_devs:
            trust_badge = " [Trusted]" if d["trusted"] else ""
            menu_items.append(f"   {d['icon']}  {d['name']:<24}{trust_badge}")

    # Section 3: Available / Other Devices
    if other_devs:
        menu_items.append("── Nearby Devices ─────────────────────────────")
        for d in other_devs:
            menu_items.append(f"   {d['icon']}  {d['name']:<24} ({d['mac']})")

    # Section 4: Controller Tools
    menu_items.append("── Controls & Tools ───────────────────────────")
    menu_items.append("󰑐  Scan for Nearby Devices (5 seconds)")
    disc_status = "ON" if is_discoverable else "OFF"
    menu_items.append(f"󰈈  Toggle Discoverable Mode (Currently: {disc_status})")
    pair_status = "ON" if is_pairable else "OFF"
    menu_items.append(f"󰄬  Toggle Pairable Mode (Currently: {pair_status})")
    menu_items.append("󰂲  Turn OFF Bluetooth")
    menu_items.append("  Open Bluetooth Manager (bluetoothctl)")
    menu_items.append("󰌑  Close Menu")

    choice = fuzzel_menu("Bluetooth", len(menu_items), menu_items)
    if not choice or "Close Menu" in choice or choice.startswith("──") or choice.startswith("○  󰂲  No devices"):
        return

    # Handle Tools
    if "Scan for Nearby Devices" in choice:
        notify("Bluetooth", "Scanning for nearby devices (5 seconds)...")
        subprocess.run("bluetoothctl --timeout 5 scan on", shell=True)
        time.sleep(0.5)
        subprocess.Popen([sys.executable, __file__])
        return

    if "Toggle Discoverable Mode" in choice:
        new_state = "off" if is_discoverable else "on"
        subprocess.run(["bluetoothctl", "discoverable", new_state])
        notify("Bluetooth", f"Discoverable mode: {new_state.upper()}")
        subprocess.Popen([sys.executable, __file__])
        return

    if "Toggle Pairable Mode" in choice:
        new_state = "off" if is_pairable else "on"
        subprocess.run(["bluetoothctl", "pairable", new_state])
        notify("Bluetooth", f"Pairable mode: {new_state.upper()}")
        subprocess.Popen([sys.executable, __file__])
        return

    if "Turn OFF Bluetooth" in choice:
        subprocess.run(["bluetoothctl", "power", "off"])
        notify("Bluetooth", "Bluetooth turned OFF", icon="bluetooth-disabled")
        return

    if "Open Bluetooth Manager" in choice:
        subprocess.Popen(["kitty", "--class", "bluetoothctl", "-e", "bluetoothctl"])
        return

    # Handle device selection
    chosen_dev = None
    for d in dev_list:
        if d["name"] in choice or d["mac"] in choice:
            chosen_dev = d
            break

    if not chosen_dev:
        return

    res = device_action_menu(chosen_dev)
    if res == "menu":
        subprocess.Popen([sys.executable, __file__])

if __name__ == "__main__":
    main()
