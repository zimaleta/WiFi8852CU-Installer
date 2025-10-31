## WiFi8852CU Installer — v1.0.2

### Security & Licensing
- Trial hardened with machine fingerprint + immutable trial file.
- Expiry writes a tombstone at /var/lib/zimaletai/wifi8852cu.expired.
- Uninstall preserves licensing state (trial, tombstone, and license files).

### UX
- Uninstall auto-detects the actual module name (e.g., 8852cu) for unload messages.
- README clarifies trial behavior and anti-reset design.

### Install (paid users)
    sudo ./activator.sh /path/to/license.json /path/to/license.sig
    sudo ./install.sh

### Trial
    sudo DEBUG=1 bash scripts/trial.sh

### Verify
    make status
    lsmod | grep -E '8852cu|rtl8852cu' || echo "not loaded"
    nmcli device

### Uninstall
    sudo ./uninstall.sh            # keep config
    sudo ./uninstall.sh --purge    # removes autoload/options (keeps licensing state)

© 2025 ZimaletAI — All rights reserved.
