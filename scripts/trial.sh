#!/usr/bin/env bash
set -euo pipefail

TRIAL_DAYS=7
STATE_DIR="/etc/zimaletai"
VAR_DIR="/var/lib/zimaletai"
TRIAL_FILE="${STATE_DIR}/wifi8852cu.trial"
EXPIRED_FILE="${VAR_DIR}/wifi8852cu.expired"
LIC_DATA="${STATE_DIR}/license.json"
LIC_SIG="${STATE_DIR}/license.sig"
PUBKEY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/licensing/license_public.pem"

log(){ echo -e "$*"; }

ensure_root(){
  if [[ $EUID -ne 0 ]]; then
    echo "Please run with sudo." >&2; exit 1
  }
}

machine_fingerprint(){
  local mid mac
  mid="$(cat /etc/machine-id 2>/dev/null || echo unknown)"
  mac="$(ip link 2>/dev/null | awk '/link\/ether/{print $2; exit}' | tr -d '\n')"
  printf '%s' "${mid}-${mac}" | sha256sum | awk '{print $1}'
}

has_valid_license(){
  [[ -f "$LIC_DATA" && -f "$LIC_SIG" && -f "$PUBKEY" ]] || return 1
  if openssl dgst -sha256 -verify "$PUBKEY" -signature "$LIC_SIG" "$LIC_DATA" >/dev/null 2>&1; then
    local exp now
    exp=$(awk -F\" '/"expires":/ {print $4}' "$LIC_DATA" 2>/dev/null || echo "")
    now=$(date +%s)
    if [[ -n "$exp" && "$exp" =~ ^[0-9]+$ && $now -gt $exp ]]; then
      log "[!] License expired."; return 1
    fi
    return 0
  fi
  return 1
}

write_tombstone(){
  mkdir -p "$VAR_DIR"; chmod 755 "$VAR_DIR"
  echo "expired=$(date +%s)" > "$EXPIRED_FILE"
  chmod 444 "$EXPIRED_FILE" || true
  command -v chattr >/dev/null 2>&1 && chattr +i "$EXPIRED_FILE" 2>/dev/null || true
}

trial_status(){
  local now ts left fp stored_fp
  now=$(date +%s)
  fp="$(machine_fingerprint)"

  if has_valid_license; then
    log "[i] License: valid."
    return 0
  fi

  if [[ -f "$EXPIRED_FILE" ]]; then
    log "[!] Trial previously expired on this machine. Please purchase a license."
    return 2
  fi

  mkdir -p "$STATE_DIR" "$VAR_DIR"; chmod 755 "$STATE_DIR" "$VAR_DIR"

  if [[ ! -f "$TRIAL_FILE" ]]; then
    {
      echo "install_ts=$(date +%s)"
      echo "fp=${fp}"
    } > "$TRIAL_FILE"
    chmod 444 "$TRIAL_FILE" || true
    command -v chattr >/dev/null 2>&1 && chattr +i "$TRIAL_FILE" 2>/dev/null || true
    log "[i] Trial started. You have ${TRIAL_DAYS} days left."
    return 0
  fi

  stored_fp="$(awk -F= '/^fp=/{print $2}' "$TRIAL_FILE" 2>/dev/null || echo "")"
  if [[ -n "$stored_fp" && "$stored_fp" != "$fp" ]]; then
    log "[!] Trial file mismatch (different machine). Please purchase a license."
    return 2
  fi

  ts="$(awk -F= '/^install_ts=/{print $2}' "$TRIAL_FILE" 2>/dev/null || echo 0)"
  if [[ ! "$ts" =~ ^[0-9]+$ ]]; then
    log "[!] Corrupted trial file. Please purchase a license."
    return 2
  fi

  left=$(( TRIAL_DAYS*86400 - ($(date +%s) - ts) ))
  if (( left <= 0 )); then
    log "[!] Trial expired. Please purchase a license."
    write_tombstone
    return 2
  fi

  log "[i] Trial: $(( (left+86399)/86400 )) day(s) remaining."
  return 0
}

ensure_root
trial_status
