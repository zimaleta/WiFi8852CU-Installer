# WiFi8852CU Installer
One-command installer for Realtek **RTL8852CU** Wi-Fi on Ubuntu/Debian via DKMS.

## Features
- DKMS install (rebuilds automatically on kernel updates)
- Includes vendor source pinned to a known-good snapshot
- Uninstall script to cleanly remove the module

## Requirements
- Ubuntu/Debian-based system with build tools
- Internet connection for apt packages

## Quick Start
```bash
sudo apt update
sudo apt install -y build-essential dkms bc git linux-headers-$(uname -r)

# run whichever installer exists in this repo:
if [[ -x ./install.sh ]]; then
  sudo ./install.sh
elif [[ -f ./install-driver.sh ]]; then
  sudo bash ./install-driver.sh
else
  echo "No installer script found (install.sh or install-driver.sh)."
fi


if [[ -x ./uninstall.sh ]]; then
  sudo ./uninstall.sh
elif [[ -f ./remove-driver.sh ]]; then
  sudo bash ./remove-driver.sh
else
  echo "No uninstall script found (uninstall.sh or remove-driver.sh)."
fi

