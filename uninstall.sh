#!/usr/bin/env bash
set -euo pipefail

# --- Elevate if needed (keeps DEBUG env)
if [[ $EUID -ne 0 ]]; then
  exec sudo --preserve-env=DEBUG "$0" "$@"
fi

# --- Defaults (can be overridden by flags or env)
PKG_NAME="${PKG_NAME:-rtl8852cu}"
PKG_VER_DEFAULT="1.19.2.1"
KEEP_SRC=0
PURGE_CFG=0
DRY_RUN=0

# --- Parse flags
#   --version X   : force a specific DKMS version to remove
#   --keep-src    : keep /usr/src tree
#   --purge       : also remove /etc/modules-load.d/8852cu.conf and /etc/modprobe.d/8852cu.conf
#   --dry-run     : show actions only
PKG_VER="$PKG_VER_DEFAULT"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) shift; PKG_VER="${1:-$PKG_VER_DEFAULT}";;
    --keep-src) KEEP_SRC=1;;
    --purge) PURGE_CFG=1;;
    --dry-run) DRY_RUN=1;;
    *) echo "[!] Unknown flag: $1"; exit 2;;
  esac
  shift || true
done

say() { echo -e "$*"; }
do_or_echo() { if (( DRY_RUN )); then say "[dry-run] $*"; else eval "$@"; fi; }

say "[i] Uninstaller starting (package=${PKG_NAME}, requested_version=${PKG_VER}, keep_src=${KEEP_SRC}, purge=${PURGE_CFG}, dry_run=${DRY_RUN})"

# --- Find installed DKMS versions for this package
INSTALLED_VERSIONS=()
while IFS= read -r line; do
  ver=$(awk -F'[ /,]' '{print $2}' <<<"$line")
  [[ -n "$ver" ]] && INSTALLED_VERSIONS+=("$ver")
done < <(dkms status | grep -E "^${PKG_NAME}/" || true)

if (( ${#INSTALLED_VERSIONS[@]} == 0 )); then
  say "[i] No DKMS entries found for ${PKG_NAME}. Nothing to remove."
  TARGET_VER="$PKG_VER"
else
  TARGET_VER="$PKG_VER"
  if ! printf '%s\n' "${INSTALLED_VERSIONS[@]}" | grep -qx "$PKG_VER"; then
    TARGET_VER="${INSTALLED_VERSIONS[0]}"
    say "[i] Requested version not found. Will remove first detected: ${TARGET_VER}"
  else
    say "[i] Will remove DKMS version: ${TARGET_VER}"
  fi

  say "[i] Removing DKMS module ${PKG_NAME}/${TARGET_VER} ..."
  do_or_echo dkms remove -m "$PKG_NAME" -v "$TARGET_VER" --all || true
fi

# --- Detect actual module filename to unload (8852cu vs rtl8852cu)
MODULE_PATH="$(find "/lib/modules/$(uname -r)/updates/dkms" -maxdepth 1 -type f -name '*.ko*' | head -n1 || true)"
MODULE_NAME=""
if [[ -n "${MODULE_PATH:-}" ]]; then
  MODULE_NAME="$(modinfo -F name "$MODULE_PATH" 2>/dev/null || true)"
  if [[ -z "${MODULE_NAME:-}" ]]; then
    MODULE_NAME="$(basename "$MODULE_PATH")"
    MODULE_NAME="${MODULE_NAME%.ko}"
    MODULE_NAME="${MODULE_NAME%.ko.zst}"
  fi
fi

# Fallback to known names if needed
if [[ -z "${MODULE_NAME:-}" ]]; then
  for cand in 8852cu rtl8852cu; do
    if modinfo "$cand" >/dev/null 2>&1; then MODULE_NAME="$cand"; break; fi
  done
fi

if [[ -n "${MODULE_NAME:-}" ]]; then
  say "[i] Unloading kernel module: ${MODULE_NAME}"
  do_or_echo modprobe -r "$MODULE_NAME" || true
else
  say "[i] No module file found to unload (may already be removed)."
fi

# --- Remove /usr/src tree (de-duped)
SRC_DST_DIR="/usr/src/${PKG_NAME}-${PKG_VER}"
if (( KEEP_SRC )); then
  say "[i] Keeping source tree: ${SRC_DST_DIR}"
else
  ALT_SRC="/usr/src/${PKG_NAME}-${TARGET_VER:-$PKG_VER}"

  if [[ -d "$SRC_DST_DIR" ]]; then
    say "[i] Removing source tree: $SRC_DST_DIR"
    do_or_echo rm -rf "$SRC_DST_DIR"
  fi

  if [[ "$ALT_SRC" != "$SRC_DST_DIR" && -d "$ALT_SRC" ]]; then
    say "[i] Removing source tree: $ALT_SRC"
    do_or_echo rm -rf "$ALT_SRC"
  fi
fi

# --- Optional: purge autoload & module options
if (( PURGE_CFG )); then
  say "[i] Purging config: /etc/modules-load.d/8852cu.conf (autoload)"
  do_or_echo rm -f /etc/modules-load.d/8852cu.conf
  say "[i] Purging config: /etc/modprobe.d/8852cu.conf (driver options)"
  do_or_echo rm -f /etc/modprobe.d/8852cu.conf
fi

say "[i] Running depmod"
do_or_echo depmod -a || true

say "[✓] Uninstall complete."
say "[i] Tip: use --dry-run to preview, --keep-src to preserve /usr/src, and --purge to remove config files."
