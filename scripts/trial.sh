#!/usr/bin/env bash
set -euo pipefail

TRIAL_DAYS=7
STATE_DIR="/etc/zimaletai"
TRIAL_FILE="${STATE_DIR}/wifi8852cu.trial"
LIC_DATA="${STATE_DIR}/license.json"
LIC_SIG="${STATE_DIR}/license.sig"
PUBKEY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/licensing/license_public.pem"

log() { echo -e "$*"; }

ensure_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "Please run with sudo." >&2
    exit 1
  fi
}

has_valid_license() {
  [[ -f "$LIC_DATA" && -f "$LIC_SIG" && -f "$PUBKEY" ]] || return 1
  if openssl dgst -sha256 -verify "$PUBKEY" -signature "$LIC_SIG" "$LIC_DATA" >/dev/null 2>&1; then
    # Optional: honor "expires" (unix epoch) if present
    local exp now
    exp=$(awk -F\" '/"expires":/ {print $4}' "$LIC_DATA" 2>/dev/null || echo "")
    now=$(date +%s)
    if [[ -n "$exp" && "$exp" =~ ^[0-9]+$ ]]; then
      (( now <= exp )) || { log "[!] License expired."; return 1; }
    fi
    return 0
  fi
  return 1
}

trial_status() {
  local now ts elapsed left
  now=$(date +%s)

  if has_valid_license; then
    log "[i] License: valid."
    return 0
  fi

  mkdir -p "$STATE_DIR"; chmod 755 "$STATE_DIR"

  if [[ ! -f "$TRIAL_FILE" ]]; then
    echo "install_ts=$(date +%s)" > "$TRIAL_FILE"
    chmod 644 "$TRIAL_FILE"
    log "[i] Trial started. You have ${TRIAL_DAYS} days left."
    return 0
  fi

  ts=$(awk -F= '/^install_ts=/{print $2}' "$TRIAL_FILE" 2>/dev/null || echo "")
  [[ -n "$ts" ]] || { log "[!] Trial metadata unreadable. Please purchase a license at https://zimaletai.com"; return 1; }

  elapsed=$(( (now - ts) / 86400 ))
  if (( elapsed < 0 )); then
    log "[!] System clock anomaly. Please purchase a license at https://zimaletai.com"
    return 1
  fi

  if (( elapsed >= TRIAL_DAYS )); then
    log "⚠️  Trial expired. Visit https://zimaletai.com to purchase a license."
    return 1
  fi

  left=$(( TRIAL_DAYS - elapsed ))
  log "[i] Trial: ${left} day(s) remaining."
  return 0
}

main() {
  ensure_root
  if trial_status; then
    log "[i] Continuing installation..."
    exit 0
  else
    exit 1
  fi
}

if [[ "${DEBUG:-0}" == "1" ]]; then
  set -x
  trap 'echo "[debug] failed at line $LINENO" >&2' ERR
fi

main "$@"
