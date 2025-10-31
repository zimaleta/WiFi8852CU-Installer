# WiFi8852CU Installer (Commercial, 7-day trial)

One-command DKMS installer for Realtek **RTL8852CU** Wi-Fi on Ubuntu/Debian.

- Signed DKMS module that auto-rebuilds on kernel updates  
- **License required** (7-day trial included)  
- Uninstaller included  

---

## Requirements
To prepare your system:
    sudo apt update
    sudo apt install -y build-essential dkms bc git linux-headers-$(uname -r) openssl

---

## Activation (Paid Users)
Activate your license with:
    sudo ./activator.sh ~/zimaletai-licensing/license.json ~/zimaletai-licensing/license.sig
Expected output:
    [✓] License installed and verified

---

## Trial Users

### Trial behavior & anti-reset
- Trial binds to your machine (machine-id + first MAC).
- When trial expires, a tombstone is written at `/var/lib/zimaletai/wifi8852cu.expired`.
- Uninstalling (even with `--purge`) does **not** remove licensing state.
- Reinstalling will **not** reset trial; please purchase a license.

Start your free 7-day trial:
    sudo DEBUG=1 bash scripts/trial.sh

---

## Install Driver
    sudo ./install.sh

---

## Verify Installation
    make status
    lsmod | grep -E '8852cu|rtl8852cu' || echo "not loaded"
    nmcli device

---

## Uninstall
    sudo ./uninstall.sh            # keep config
    sudo ./uninstall.sh --purge    # also removes autoload/options

---

## Purchase a License
To buy a license, contact sales@zimaletai.com.  
You will receive your signed license.json and license.sig.

---

© 2025 ZimaletAI — All rights reserved.
