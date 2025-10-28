#!/usr/bin/env bash
set -euo pipefail
shopt -s nocasematch

echo "=== Realtek 8852CU (USB Wi-Fi 6) — Portable Installer ==="

# --- Settings you can tweak ---
VENDOR_ID="0bda"
PRODUCT_ID="c832"
MODPROBE_CONF="/etc/modprobe.d/8852cu.conf"
UDEV_RULE="/etc/udev/rules.d/99-usb-8852cu-powersave.rules"
BLACKLIST_BU="/etc/modprobe.d/blacklist-rtl8852bu.conf"
COUNTRY_CODE="US"
# ------------------------------

KREL="$(uname -r)"
HDR="linux-headers-$KREL"

echo "[1/7] Installing build deps (dkms, headers, toolchain)..."
sudo apt-get update -y
sudo apt-get install -y dkms build-essential "$HDR" git

echo "[2/7] Getting driver source..."
HERE="$(cd "$(dirname "$0")"; pwd)"
WORK="$HERE/rtl8852cu-20240510"
if [ ! -d "$WORK" ]; then
  echo "  No bundled source found; cloning morrownr/rtl8852cu-20240510..."
  git clone https://github.com/morrownr/rtl8852cu-20240510.git "$WORK"
fi

echo "[3/7] Blacklisting wrong BU driver (safe to repeat)..."
echo "blacklist 8852bu" | sudo tee "$BLACKLIST_BU" >/dev/null || true
sudo modprobe -r 8852bu 2>/dev/null || true

echo "[4/7] Building & installing 8852cu via DKMS..."
cd "$WORK"
printf "n\nn\n" | sudo ./install-driver.sh

echo "[5/7] Applying driver options..."
sudo tee "$MODPROBE_CONF" >/dev/null <<OPT
options 8852cu rtw_power_mgnt=0 rtw_enusbss=0 rtw_switch_usb_mode=1 rtw_led_ctrl=1 rtw_country_code=$COUNTRY_CODE
OPT

echo "[6/7] Disabling USB autosuspend for this adapter..."
sudo tee "$UDEV_RULE" >/dev/null <<RULE
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="$VENDOR_ID", ATTR{idProduct}=="$PRODUCT_ID", \
  TEST=="power/control", ATTR{power/control}="on"
RULE
sudo udevadm control --reload
sudo udevadm trigger -v -a idVendor=$VENDOR_ID -a idProduct=$PRODUCT_ID

echo "[7/7] Loading module, verifying alias, and nudging NetworkManager..."
sudo depmod -a
sudo modprobe -r 8852cu 2>/dev/null || true
sudo modprobe 8852cu

if modinfo 8852cu | grep -qi "alias:.*$VENDOR_ID.*$PRODUCT_ID"; then
  echo "  OK: module exports alias for ${VENDOR_ID}:${PRODUCT_ID}"
else
  echo "  !! Warning: module alias for ${VENDOR_ID}:${PRODUCT_ID} not found"
fi

# Set reg domain (best-effort)
sudo iw reg set "$COUNTRY_CODE" 2>/dev/null || true

# Prefer USB interface if your known connections exist (best-effort)
if command -v nmcli >/dev/null 2>&1; then
  nmcli -t -f NAME con show | grep -qx "Peg-Leg 1" && \
    sudo nmcli con modify "Peg-Leg 1" ipv4.route-metric 50 ipv6.route-metric 50 connection.autoconnect-priority 100 || true
  nmcli -t -f NAME con show | grep -qx "Peg-Leg" && \
    sudo nmcli con modify "Peg-Leg" ipv4.route-metric 200 ipv6.route-metric 200 connection.autoconnect-priority 0 ipv4.never-default yes ipv6.never-default yes || true
  sudo systemctl reload NetworkManager || sudo systemctl restart NetworkManager || true
fi

echo
echo "✅ Install complete."
echo "• 8852cu (DKMS) installed and loaded"
echo "• Options in: $MODPROBE_CONF"
echo "• Udev rule : $UDEV_RULE"
echo "Tip: Unplug/replug the Realtek dongle if it isn't seen immediately."
sudo udevadm trigger -v -a idVendor=$VENDOR_ID -a idProduct=$PRODUCT_ID

echo "[7/7] Loading module, verifying alias, and nudging NetworkManager..."
sudo depmod -a
sudo modprobe -r 8852cu 2>/dev/null || true
sudo modprobe 8852cu

if modinfo 8852cu | grep -qi "alias:.*$VENDOR_ID.*$PRODUCT_ID"; then
  echo "  OK: module exports alias for ${VENDOR_ID}:${PRODUCT_ID}"
else
  echo "  !! Warning: module alias for ${VENDOR_ID}:${PRODUCT_ID} not found"
fi

# Set regulatory domain (best-effort)
sudo iw reg set "$COUNTRY_CODE" 2>/dev/null || true

# Prefer USB interface if your known connections exist (best-effort)
if command -v nmcli >/dev/null 2>&1; then
  nmcli -t -f NAME con show | grep -qx "Peg-Leg 1" && \
    sudo nmcli con modify "Peg-Leg 1" ipv4.route-metric 50 ipv6.route-metric 50 connection.autoconnect-priority 100 || true
  nmcli -t -f NAME con show | grep -qx "Peg-Leg" && \
    sudo nmcli con modify "Peg-Leg" ipv4.route-metric 200 ipv6.route-metric 200 connection.autoconnect-priority 0 ipv4.never-default yes ipv6.never-default yes || true
  sudo systemctl reload NetworkManager || sudo systemctl restart NetworkManager || true
fi

echo
echo "✅ Install complete."
echo "• 8852cu (DKMS) installed and loaded"
echo "• Options in: $MODPROBE_CONF"
echo "• Udev rule : $UDEV_RULE"
echo "Tip: Unplug/replug the Realtek dongle if it isn't seen immediately."

echo "[8/8] Optimizing Wi-Fi: 5 GHz band + priority routes..."

# Find the USB Realtek interface handled by rtl8852cu
USBIF=""
for i in /sys/class/net/wl*; do
  [ -d "$i" ] || continue
  drv="$(basename "$(readlink -f "$i/device/driver" 2>/dev/null || echo "")")"
  if [ "$drv" = "rtl8852cu" ]; then
    USBIF="$(basename "$i")"
    break
  fi
done

# Reassert driver options (no power save)
sudo tee /etc/modprobe.d/8852cu.conf >/dev/null <<OPT
options 8852cu rtw_power_mgnt=0 rtw_enusbss=0 rtw_switch_usb_mode=1 rtw_led_ctrl=1 rtw_country_code=$COUNTRY_CODE
OPT
sudo modprobe -r 8852cu 2>/dev/null || true
sudo modprobe 8852cu 2>/dev/null || true

# If NetworkManager is available, prefer the USB and lock to 5 GHz
if command -v nmcli >/dev/null 2>&1 && [ -n "$USBIF" ]; then
  # Get the active connection name on the USB interface (if any)
  USB_CON="$(nmcli -t -f DEVICE,CONNECTION device status | awk -F: -v D="$USBIF" '$1==D{print $2}')"

  # If not connected yet, try bringing up any saved connection on that iface
  if [ -z "$USB_CON" ] || [ "$USB_CON" = "--" ]; then
    # Try to pick a saved connection name that matches a visible 5 GHz AP
    SSID_5G="$(nmcli -t -f SSID,FREQ dev wifi | awk -F: '$2>=5000 && $1!=""{print $1; exit}')"
    if [ -n "$SSID_5G" ]; then
      nmcli dev wifi connect "$SSID_5G" ifname "$USBIF" 2>/dev/null || true
      USB_CON="$(nmcli -t -f DEVICE,CONNECTION device status | awk -F: -v D="$USBIF" '$1==D{print $2}')"
    fi
  fi

  # Lock the USB connection profile to 5 GHz and give it priority + low metrics
  if [ -n "$USB_CON" ] && [ "$USB_CON" != "--" ]; then
    sudo nmcli connection modify "$USB_CON" 802-11-wireless.band a
    # If currently on 5 GHz, capture its channel and pin it
    CURFREQ="$(iw dev "$USBIF" link 2>/dev/null | awk '/freq:/{print int($2)}')"
    if [ -n "$CURFREQ" ] && [ "$CURFREQ" -ge 5000 ]; then
      # crude freq->chan map for 5 GHz (works for common UNII bands)
      CHAN=$(( (CURFREQ - 5000) / 5 ))
      [ "$CHAN" -ge 1 ] && sudo nmcli connection modify "$USB_CON" 802-11-wireless.channel "$CHAN" || true
    fi
    sudo nmcli connection modify "$USB_CON" ipv4.route-metric 50 ipv6.route-metric 50 connection.autoconnect-priority 100
    nmcli connection up "$USB_CON" >/dev/null 2>&1 || true
  fi

  # De-prioritize other Wi-Fi connections on non-Realtek interfaces
  nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device status | awk -F: '$2=="wifi" && $3=="connected"{print $1":"$4}' \
  | while IFS=: read -r DEV CONN; do
      [ "$DEV" = "$USBIF" ] && continue
      [ -n "$CONN" ] && [ "$CONN" != "--" ] || continue
      sudo nmcli connection modify "$CONN" ipv4.route-metric 200 ipv6.route-metric 200 ipv4.never-default yes ipv6.never-default yes connection.autoconnect-priority 0
      nmcli connection up "$CONN" >/dev/null 2>&1 || true
    done
fi

echo "   Wi-Fi optimization done."
