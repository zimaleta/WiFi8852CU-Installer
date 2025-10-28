#!/usr/bin/env bash
set -euo pipefail

# Find USB Realtek iface by driver name
USBIF=""
for i in /sys/class/net/wl*; do
  [ -d "$i" ] || continue
  drv="$(basename "$(readlink -f "$i/device/driver" 2>/dev/null || echo "")")"
  if [ "$drv" = "rtl8852cu" ]; then
    USBIF="$(basename "$i")"
    break
  fi
done
[ -z "$USBIF" ] && { echo "No rtl8852cu interface found."; exit 0; }

# Lock to 5 GHz and set metrics/priorities
if command -v nmcli >/dev/null 2>&1; then
  USB_CON="$(nmcli -t -f DEVICE,CONNECTION device status | awk -F: -v D="$USBIF" '$1==D{print $2}')"
  if [ -n "$USB_CON" ] && [ "$USB_CON" != "--" ]; then
    sudo nmcli connection modify "$USB_CON" 802-11-wireless.band a
    CURFREQ="$(iw dev "$USBIF" link 2>/dev/null | awk '/freq:/{print int($2)}')"
    if [ -n "$CURFREQ" ] && [ "$CURFREQ" -ge 5000 ]; then
      CHAN=$(( (CURFREQ - 5000) / 5 ))
      [ "$CHAN" -ge 1 ] && sudo nmcli connection modify "$USB_CON" 802-11-wireless.channel "$CHAN" || true
    fi
    sudo nmcli connection modify "$USB_CON" ipv4.route-metric 50 ipv6.route-metric 50 connection.autoconnect-priority 100
    nmcli connection up "$USB_CON" >/dev/null 2>&1 || true
  fi

  nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device status | awk -F: '$2=="wifi" && $3=="connected"{print $1":"$4}' \
  | while IFS=: read -r DEV CONN; do
      [ "$DEV" = "$USBIF" ] && continue
      [ -n "$CONN" ] && [ "$CONN" != "--" ] || continue
      sudo nmcli connection modify "$CONN" ipv4.route-metric 200 ipv6.route-metric 200 ipv4.never-default yes ipv6.never-default yes connection.autoconnect-priority 0
      nmcli connection up "$CONN" >/dev/null 2>&1 || true
    done
fi

echo "✅ Applied 5 GHz lock and routing preferences to $USBIF."
