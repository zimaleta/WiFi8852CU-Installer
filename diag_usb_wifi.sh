#!/usr/bin/env bash
set -euo pipefail
echo "=== Realtek 8852CU Diagnostic ==="

echo
echo "[1/4] Module & alias check:"
modinfo 8852cu | grep -E "version:|alias:.*(8852|c832)" || echo "  (no module info)"

echo
echo "[2/4] Active interfaces:"
nmcli -f DEVICE,TYPE,STATE,CONNECTION device status 2>/dev/null || ip link show

echo
echo "[3/4] Default routes:"
ip route show default || echo "  (no default route)"

echo
echo "[4/4] Recent kernel messages:"
sudo dmesg -T | grep -E "8852cu|rtl8852cu|c832" | tail -n 20 || echo "  (no recent driver logs)"

echo
echo "✅ Diagnostic complete."
