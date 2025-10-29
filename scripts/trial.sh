#!/usr/bin/env bash
set -euo pipefail
# Optional debug: sudo DEBUG=1 ./scripts/trial.sh
if [[ "${DEBUG:-0}" == "1" ]]; then
  set -x
  trap 'echo "[debug] failed at line $LINENO" >&2' ERR
fi

# ---- Trial settings ----
TRIAL_DAYS=7
TRIAL_DIR="/etc/zimaletai"
TRIAL_FILE="${TRIAL_DIR}/wifi8852cu.trial"   # root-owned, not user-writable

trial_status() {
  local now ts elapsed days_left
  now=$(date +%s)

  if [[ ! -f "$TRIAL_FILE" ]]; then
    echo "[i] First run detected. Starting your 7-day evaluation."
    return 0
  fi

  ts=$(awk -F= '/^install_ts=/{print $2}' "$TRIAL_FILE" 2>/dev/null || echo "")
  [[ -n "$ts" ]] || { echo "[!] Trial metadata unreadable. Please purchase a license at https://zimaletai.com"; return 1; }

  elapsed=$(( (now - ts) / 86400 ))
  if (( elapsed < 0 )); then
    echo "[!] System clock anomaly detected. Trial status unknown. Please purchase a license at https://zimaletai.com"
    return 1
  fi

  if (( elapsed >= TRIAL_DAYS )); then
    echo "⚠️  Trial expired. Visit https://zimaletai.com to purchase a license."
    return 1
  fi

  days_left=$(( TRIAL_DAYS - elapsed ))
  echo "[i] Trial: $days_left day(s) remaining."
  return 0
}

trial_check_or_exit() {
  if [[ $EUID -ne 0 ]]; then
    echo "Please run with sudo."
    exit 1
  fi

  mkdir -p "$TRIAL_DIR"
  chmod 755 "$TRIAL_DIR"

  if [[ ! -f "$TRIAL_FILE" ]]; then
    echo "install_ts=$(date +%s)" > "$TRIAL_FILE"
    chmod 644 "$TRIAL_FILE"
    echo "[i] Trial started. You have $TRIAL_DAYS days left."
    return 0
  fi

  if ! trial_status; then
    exit 1
  fi
}

# Example usage
trial_check_or_exit
echo "[i] Continuing installation..."
