#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="/etc/zimaletai"
LIC_DATA="${STATE_DIR}/license.json"
LIC_SIG="${STATE_DIR}/license.sig"
PUBKEY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/licensing/license_public.pem"

err() { echo "[!] $*" >&2; }
die() { err "$@"; exit 1; }
say() { echo -e "$*"; }

if [[ $EUID -ne 0 ]]; then
  exec sudo --preserve-env=DEBUG "$0" "$@"
fi

if [[ $# -ne 2 ]]; then
  die "Usage: $0 <license.json> <license.sig>"
fi

SRC_JSON="$1"
SRC_SIG="$2"

[[ -f "$SRC_JSON" ]] || die "license.json not found: $SRC_JSON"
[[ -f "$SRC_SIG"  ]] || die "license.sig not found: $SRC_SIG"
[[ -f "$PUBKEY"   ]] || die "Public key missing: $PUBKEY"

# verify before installing
if ! openssl dgst -sha256 -verify "$PUBKEY" -signature "$SRC_SIG" "$SRC_JSON" >/dev/null 2>&1; then
  die "Signature verification failed. Please re-download your license files."
fi

mkdir -p "$STATE_DIR"; chmod 755 "$STATE_DIR"
install -m 0644 "$SRC_JSON" "$LIC_DATA"
install -m 0644 "$SRC_SIG"  "$LIC_SIG"

say "[✓] License installed and verified."
