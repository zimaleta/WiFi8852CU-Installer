#!/usr/bin/env bash
set -euo pipefail

# --- Elevate to root if not already (keeps DEBUG/BATCH envs if you set them)
if [[ $EUID -ne 0 ]]; then
  exec sudo --preserve-env=DEBUG,BATCH "$0" "$@"
fi

# --- Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Enforce trial/licensing (runs once, exits non-zero if expired)
bash "$SCRIPT_DIR/scripts/trial.sh" || exit 1

# --- Package config (adjust version if your vendor tree differs)
PKG_NAME="rtl8852cu"
PKG_VER="1.19.2.1"
SRC_VENDOR_DIR="$SCRIPT_DIR/vendor/${PKG_NAME}-${PKG_VER}"
SRC_DST_DIR="/usr/src/${PKG_NAME}-${PKG_VER}"

echo "[i] Starting ${PKG_NAME} DKMS install..."

# 1) Dependencies
echo "[i] Installing build dependencies..."
apt-get update -y
apt-get install -y build-essential dkms "linux-headers-$(uname -r)" git

# 2) Stage source into /usr/src
if [[ ! -d "$SRC_VENDOR_DIR" ]]; then
  echo "[!] Missing vendor source at: $SRC_VENDOR_DIR"
  echo "    Place the driver source here with dkms files (dkms.conf, Makefile, src/ ...)."
  echo "    Expected path: vendor/${PKG_NAME}-${PKG_VER}/"
  exit 1
fi

echo "[i] Copying source to $SRC_DST_DIR ..."
rm -rf "$SRC_DST_DIR"
mkdir -p "$SRC_DST_DIR"
cp -a "$SRC_VENDOR_DIR"/. "$SRC_DST_DIR"/
chown -R root:root "$SRC_DST_DIR"

# 3) DKMS add/build/install (clean if pre-existing)
echo "[i] Registering with DKMS..."
if dkms status | grep -q "^${PKG_NAME}/${PKG_VER}"; then
  echo "[i] DKMS entry exists, removing to ensure a clean build..."
  dkms remove -m "$PKG_NAME" -v "$PKG_VER" --all || true
fi

dkms add -m "$PKG_NAME" -v "$PKG_VER"
dkms build -m "$PKG_NAME" -v "$PKG_VER"
dkms install -m "$PKG_NAME" -v "$PKG_VER" --force

# 4) Load module (ignore errors if not yet needed)
echo "[i] Loading kernel module..."

# --- Auto-detect built module name ---
MODULE_PATH="$(find "/lib/modules/$(uname -r)/updates/dkms" -maxdepth 1 -type f -name '*.ko*' | head -n1 || true)"
if [[ -z "${MODULE_PATH:-}" ]]; then
  echo "[!] No built .ko found under /lib/modules/$(uname -r)/updates/dkms"
  echo "    Something went wrong with DKMS install; check the dkms build log."
  exit 1
fi

MODULE_NAME="$(modinfo -F name "$MODULE_PATH" 2>/dev/null || true)"
if [[ -z "${MODULE_NAME:-}" ]]; then
  MODULE_NAME="$(basename "$MODULE_PATH")"
  MODULE_NAME="${MODULE_NAME%.ko}"
  MODULE_NAME="${MODULE_NAME%.ko.zst}"
fi

echo "[i] Detected module name: $MODULE_NAME"

# --- Load it safely ---
modprobe -r "$MODULE_NAME" || true
depmod -a || true
modprobe "$MODULE_NAME" || { echo "[!] modprobe failed; last dmesg:"; dmesg | tail -n 60; exit 1; }

echo "[i] DKMS install complete for ${PKG_NAME} ${PKG_VER}."
echo "[i] This module will auto-rebuild on future kernel updates."

