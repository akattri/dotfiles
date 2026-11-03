#!/usr/bin/env python3
import subprocess
import sys
import shutil
import os
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
    except subprocess.CalledProcessError as e:
        return e.output or ""
    except Exception:
        return ""

def notify(summary, body="", icon="network-wireless", urgency="normal"):
    subprocess.run(["notify-send", "-u", urgency, "-i", icon, summary, body])

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

def fuzzel_password(prompt):
    fuzzel_cmd = [
        "fuzzel", "--dmenu", "--password",
        "--prompt", f"{prompt} ",
        "--lines", "0",
        "--width", "40"
    ]
    proc = subprocess.Popen(fuzzel_cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
    out, _ = proc.communicate()
    cleanup_tag()
    return out.strip() if proc.returncode == 0 else None

def fuzzel_input(prompt):
    fuzzel_cmd = [
        "fuzzel", "--dmenu",
        "--prompt", f"{prompt} ",
        "--lines", "0",
        "--width", "40"
    ]
    proc = subprocess.Popen(fuzzel_cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
    out, _ = proc.communicate()
    cleanup_tag()
    return out.strip() if proc.returncode == 0 else None

def signal_icon(signal):
    if signal >= 75:
        return "󰤨"
    elif signal >= 50:
        return "󰤥"
    elif signal >= 25:
        return "󰤢"
    return "󰤟"

def get_connection_details(ssid):
    raw = run_cmd(["nmcli", "-t", "-f", "IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,GENERAL.DEVICES", "con", "show", "id", ssid])
    ip_addr = ""
    gateway = ""
    dns = ""
    device = "wlan0"
    for line in raw.split("\n"):
        if line.startswith("IP4.ADDRESS"):
            ip_addr = line.split(":", 1)[1].strip()
        elif line.startswith("IP4.GATEWAY"):
            gateway = line.split(":", 1)[1].strip()
        elif line.startswith("IP4.DNS") and not dns:
            dns = line.split(":", 1)[1].strip()
        elif line.startswith("GENERAL.DEVICES"):
            device = line.split(":", 1)[1].strip()
    return ip_addr, gateway, dns, device

def show_details_dialog(ssid, ip_addr, gateway, dns, device, signal, freq, security):
    details = [
        f"Network (SSID):     {ssid}",
        f"IP Address:         {ip_addr or 'N/A'}",
        f"Gateway / Router:   {gateway or 'N/A'}",
        f"DNS Server:         {dns or 'N/A'}",
        f"Interface:          {device}",
        f"Frequency:          {freq}",
        f"Signal Strength:    {signal}%",
        f"Security:           {security}",
        "───────────────────────────────────────────────",
        "📋  Copy IP Address to Clipboard",
        "󰅚  Disconnect from Network",
        "󰆴  Forget This Network",
        "󰌑  Back to Wi-Fi Menu"
    ]
    ans = fuzzel_menu(f"Details: {ssid}", len(details), details, width=54)
    if not ans or "Back to Wi-Fi Menu" in ans:
        return "menu"
    if "Copy IP Address" in ans and ip_addr:
        clean_ip = ip_addr.split("/")[0]
        subprocess.run(["wl-copy", clean_ip])
        notify("Wi-Fi Details", f"Copied {clean_ip} to clipboard", icon="network-wireless")
        return "menu"
    if "Disconnect from Network" in ans:
        subprocess.run(["nmcli", "connection", "down", "id", ssid])
        notify("Wi-Fi", f"Disconnected from {ssid}", icon="network-wireless-disconnected")
        return None
    if "Forget This Network" in ans:
        subprocess.run(["nmcli", "connection", "delete", "id", ssid])
        notify("Wi-Fi", f"Removed network {ssid}", icon="network-wireless")
        return None
    return "menu"

def main():
    check_toggle("wifi")
    wifi_status = run_cmd(["nmcli", "radio", "wifi"]).strip()
    is_wifi_on = (wifi_status == "enabled")

    if not is_wifi_on:
        menu_items = [
            "── Wi-Fi Disabled ───────────────────────────────",
            "󰤨  Turn ON Wi-Fi",
            "  Open Connection Manager (nmtui)",
            "󰌑  Cancel"
        ]
        choice = fuzzel_menu("Wi-Fi", len(menu_items), menu_items)
        if choice and "Turn ON Wi-Fi" in choice:
            subprocess.run(["nmcli", "radio", "wifi", "on"])
            notify("Wi-Fi", "Wi-Fi turned ON", icon="network-wireless")
        elif choice and "Open Connection Manager" in choice:
            subprocess.Popen(["kitty", "--class", "nmtui", "-e", "nmtui"])
        return

    # Wi-Fi is ON, query networks
    raw_list = run_cmd(["nmcli", "-t", "-f", "active,ssid,bssid,signal,freq,chan,security,bars", "dev", "wifi"])
    networks = {}
    active_ssid = None
    active_details = {}

    for line in raw_list.strip().split("\n"):
        if not line:
            continue
        parts = line.split(":")
        if len(parts) < 8:
            continue
        active, ssid, bssid, signal, freq, chan, security = parts[0], parts[1], parts[2], parts[3], parts[4], parts[5], parts[6]
        if not ssid or ssid == "--":
            continue
        try:
            sig_int = int(signal)
        except ValueError:
            sig_int = 0

        is_active = (active == "yes")
        if is_active:
            active_ssid = ssid
            active_details = {
                "signal": sig_int,
                "freq": freq,
                "chan": chan,
                "security": security if security else "Open"
            }

        # Deduplicate to best signal
        band = "5G" if "58" in freq or "5" in freq[:2] else "2.4G"
        if ssid not in networks or networks[ssid]["signal"] < sig_int:
            networks[ssid] = {
                "active": is_active,
                "signal": sig_int,
                "freq": freq,
                "band": band,
                "security": security if security else "Open"
            }

    # Saved connections
    saved_raw = run_cmd(["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"])
    saved_ssids = set()
    for line in saved_raw.strip().split("\n"):
        if ":802-11-wireless" in line:
            saved_ssids.add(line.split(":")[0])

    menu_items = []

    # Section 1: Active Connection
    menu_items.append("── Active Connection ──────────────────────────")
    if active_ssid:
        ip_addr, gateway, dns, device = get_connection_details(active_ssid)
        clean_ip = ip_addr.split("/")[0] if ip_addr else "No IP"
        sec = active_details.get("security", "WPA2")
        band = "5G" if "58" in active_details.get("freq", "") else "2.4G"
        menu_items.append(f"●  󰤨  {active_ssid}  ({clean_ip} | {band} | {active_details.get('signal', 0)}%)")
        menu_items.append("   󰋽  View Connection Details & IP")
        menu_items.append(f"   󰅚  Disconnect from {active_ssid}")
    else:
        menu_items.append("○  󰤮  Not connected to any network")

    # Section 2: Available Networks
    menu_items.append("── Available Networks ─────────────────────────")
    # Sort: active first, then saved, then highest signal
    sorted_nets = sorted(
        networks.items(),
        key=lambda x: (not x[1]["active"], x[0] not in saved_ssids, -x[1]["signal"])
    )

    for ssid, info in sorted_nets:
        if info["active"]:
            continue  # Already featured in Active Connection
        icon = signal_icon(info["signal"])
        saved_tag = "★ " if ssid in saved_ssids else "  "
        sec_tag = f"[{info['security']}]" if info['security'] != "Open" else "[Open]"
        menu_items.append(f"{saved_tag}{icon}  {ssid:<24} {info['signal']:>3}%  [{info['band']}]  {sec_tag}")

    # Section 3: Tools & Settings
    menu_items.append("── Management & Tools ─────────────────────────")
    menu_items.append("󰑐  Rescan Available Networks")
    menu_items.append("󰤨  Connect to Hidden Wi-Fi...")
    menu_items.append("󰤮  Turn OFF Wi-Fi")
    menu_items.append("  Open Network Manager (nmtui)")
    menu_items.append("󰌑  Close Menu")

    choice = fuzzel_menu("Wi-Fi", len(menu_items), menu_items)
    if not choice or "Close Menu" in choice or choice.startswith("──"):
        return

    # Handle Active Connection items
    if "View Connection Details" in choice or (active_ssid and choice.startswith(f"●  󰤨  {active_ssid}")):
        ip_addr, gateway, dns, device = get_connection_details(active_ssid)
        res = show_details_dialog(
            active_ssid, ip_addr, gateway, dns, device,
            active_details.get("signal", 0),
            active_details.get("freq", ""),
            active_details.get("security", "")
        )
        if res == "menu":
            subprocess.Popen([sys.executable, __file__])
        return

    if "Disconnect from" in choice:
        subprocess.run(["nmcli", "connection", "down", "id", active_ssid])
        notify("Wi-Fi", f"Disconnected from {active_ssid}", icon="network-wireless-disconnected")
        return

    # Handle Management items
    if "Turn OFF Wi-Fi" in choice:
        subprocess.run(["nmcli", "radio", "wifi", "off"])
        notify("Wi-Fi", "Wi-Fi turned OFF", icon="network-wireless-offline")
        return

    if "Rescan Available Networks" in choice:
        notify("Wi-Fi", "Scanning for networks...", icon="network-wireless")
        run_cmd(["nmcli", "device", "wifi", "rescan"])
        time.sleep(1)
        subprocess.Popen([sys.executable, __file__])
        return

    if "Open Network Manager" in choice:
        subprocess.Popen(["kitty", "--class", "nmtui", "-e", "nmtui"])
        return

    if "Connect to Hidden Wi-Fi" in choice:
        hidden_ssid = fuzzel_input("Hidden Network SSID:")
        if not hidden_ssid:
            return
        hidden_pass = fuzzel_password(f"Password for {hidden_ssid} (blank if Open):")
        cmd = ["nmcli", "device", "wifi", "connect", hidden_ssid, "hidden", "yes"]
        if hidden_pass:
            cmd.extend(["password", hidden_pass])
        notify("Wi-Fi", f"Connecting to hidden network {hidden_ssid}...", icon="network-wireless")
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode == 0:
            notify("Wi-Fi", f"Connected to {hidden_ssid}", icon="network-wireless")
        else:
            notify("Wi-Fi Failed", res.stderr.strip() or res.stdout.strip(), icon="network-error", urgency="critical")
        return

    # User selected an available network
    # Match SSID from line
    target_ssid = None
    for ssid in networks.keys():
        if ssid in choice:
            target_ssid = ssid
            break

    if not target_ssid:
        return

    # If saved connection, connect directly
    if target_ssid in saved_ssids:
        notify("Wi-Fi", f"Connecting to {target_ssid}...", icon="network-wireless")
        res = subprocess.run(["nmcli", "connection", "up", "id", target_ssid], capture_output=True, text=True)
        if res.returncode == 0:
            notify("Wi-Fi", f"Connected to {target_ssid}", icon="network-wireless")
        else:
            notify("Wi-Fi Connection Failed", res.stderr.strip() or res.stdout.strip(), icon="network-error", urgency="critical")
        return

    # If open network
    sec = networks[target_ssid]["security"]
    if sec == "Open" or sec == "--":
        notify("Wi-Fi", f"Connecting to {target_ssid}...", icon="network-wireless")
        res = subprocess.run(["nmcli", "device", "wifi", "connect", target_ssid], capture_output=True, text=True)
        if res.returncode == 0:
            notify("Wi-Fi", f"Connected to {target_ssid}", icon="network-wireless")
        else:
            notify("Wi-Fi Connection Failed", res.stderr.strip(), icon="network-error", urgency="critical")
        return

    # Secured network requiring password
    password = fuzzel_password(f"Password for {target_ssid}:")
    if not password:
        return

    notify("Wi-Fi", f"Connecting to {target_ssid}...", icon="network-wireless")
    res = subprocess.run(["nmcli", "device", "wifi", "connect", target_ssid, "password", password], capture_output=True, text=True)
    if res.returncode == 0:
        notify("Wi-Fi", f"Connected to {target_ssid}", icon="network-wireless")
    else:
        notify("Wi-Fi Failed", res.stderr.strip() or "Incorrect password or connection timeout", icon="network-error", urgency="critical")

if __name__ == "__main__":
    main()
