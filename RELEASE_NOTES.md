## WiFi8852CU Installer — v1.0.1 (Commercial Trial)

### What's new
- Added commercial README with activation/trial instructions.
- Included license verification workflow (activator + public key).
- DKMS install/uninstall verified on Ubuntu 24.04 (kernel 6.14.0-33).
- Trial: 7 days via `scripts/trial.sh`.
- Paid users: offline license verification via RSA signature.

### Install (paid users)
```bash
sudo ./activator.sh /path/to/license.json /path/to/license.sig
sudo ./install.sh
```

### Install (trial)
```bash
sudo DEBUG=1 bash scripts/trial.sh
sudo ./install.sh
```

### Verify
```bash
make status
lsmod | grep -E '8852cu|rtl8852cu' || echo "not loaded"
nmcli device
```

### Uninstall
```bash
sudo ./uninstall.sh            # keep config
sudo ./uninstall.sh --purge    # also removes autoload/options
```

### Notes
- Module name auto-detected (usually `8852cu`).
- DKMS will auto-rebuild on kernel updates.
- Licensing files live in `/etc/zimaletai` (`license.json`, `license.sig`).

© 2025 ZimaletAI — All rights reserved.
