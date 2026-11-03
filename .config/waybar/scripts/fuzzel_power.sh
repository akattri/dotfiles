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

def fuzzel_menu(prompt, lines, options, width=38):
    fuzzel_cmd = [
        "fuzzel", "--dmenu",
        "--prompt", f"{prompt} ",
        "--lines", str(min(max(lines, 3), 12)),
        "--width", str(width)
    ]
    proc = subprocess.Popen(fuzzel_cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
    out, _ = proc.communicate(input="\n".join(options))
    cleanup_tag()
    return out.strip() if proc.returncode == 0 else None

def lock_screen():
    if shutil.which("veila"):
        subprocess.run(["systemctl", "--user", "start", "veilad.service"])
        subprocess.Popen(["veila", "lock"])
    else:
        swaylock_bin = shutil.which("swaylock") or "/home/user/.local/bin/swaylock"
        if os.path.exists(swaylock_bin):
            subprocess.Popen([swaylock_bin])
        else:
            subprocess.run(["loginctl", "lock-session"])

def logout():
    # Attempt clean Niri quit first, then fallback to loginctl terminate-user
    if shutil.which("niri"):
        res = subprocess.run(["niri", "msg", "action", "quit", "--skip-confirmation"])
        if res.returncode == 0:
            return
    subprocess.run(["loginctl", "terminate-user", os.environ.get("USER", "user")])

def main():
    check_toggle("power")

    menu_items = [
        "󰌾  Lock Screen",
        "󰗽  Log Out (Exit Session)",
        "󰒲  Suspend / Sleep",
        "󰤄  Hibernate",
        "󰑓  Restart System",
        "  Shut Down System",
        "󰌑  Cancel"
    ]

    choice = fuzzel_menu("Power & Session", len(menu_items), menu_items)
    if not choice or "Cancel" in choice:
        return

    if "Lock Screen" in choice:
        lock_screen()
    elif "Log Out" in choice:
        logout()
    elif "Suspend" in choice:
        subprocess.run(["systemctl", "suspend"])
    elif "Hibernate" in choice:
        subprocess.run(["systemctl", "hibernate"])
    elif "Restart" in choice:
        subprocess.run(["systemctl", "reboot"])
    elif "Shut Down" in choice:
        subprocess.run(["systemctl", "poweroff"])

if __name__ == "__main__":
    main()
