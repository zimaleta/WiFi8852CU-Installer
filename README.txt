Realtek 8852CU (USB Wi-Fi 6) Portable Installer
-----------------------------------------------
Install:
  sudo ./install_usb_wifi.sh

Uninstall:
  sudo ./uninstall_usb_wifi.sh

Notes:
- Uses bundled source (rtl8852cu-20240510/) if present; else clones upstream.
- Installs via DKMS; writes driver options; disables USB autosuspend.
- If your "Peg-Leg"/"Peg-Leg 1" NM profiles exist, it prefers the USB adapter.
