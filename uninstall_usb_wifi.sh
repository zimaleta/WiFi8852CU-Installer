#!/usr/bin/env bash
set -euo pipefail
echo "=== Realtek 8852CU — Uninstaller ==="

if dkms status | grep -qi 'rtl8852cu'; then
  VER="$(dkms status | awk -F, '/rtl8852cu/{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit}')"
  [ -n "${VER:-}" ] && sudo dkms remove -m rtl8852cu -v "$VER" --all || true
fi

sudo find /lib/modules/$(uname -r) -name '8852cu.ko*' -exec rm -f {} + 2>/dev/null || true
sudo depmod -a

sudo rm -f /etc/modprobe.d/8852cu.conf 2>/dev/null || true
sudo rm -f /etc/udev/rules.d/99-usb-8852cu-powersave.rules 2>/dev/null || true
sudo rm -f /etc/modprobe.d/blacklist-rtl8852bu.conf 2>/dev/null || true
sudo udevadm control --reload || true

sudo systemctl reload NetworkManager || sudo systemctl restart NetworkManager || true
sudo modprobe -r 8852cu 2>/dev/null || true

echo "✅ Uninstall complete."
