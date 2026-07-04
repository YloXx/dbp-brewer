#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# agent/managed-upgrade.sh — scheduled Homebrew maintenance so the update
# status reported to the sheet actually moves. Runs as the console user
# (brew is user-owned). Intended to be driven by com.grntly.upgrade LaunchDaemon.
# ---------------------------------------------------------------------------
set -euo pipefail

LOG="/var/log/grntly-upgrade.log"
console_user="$(stat -f%Su /dev/console 2>/dev/null || echo root)"
BREW="/opt/homebrew/bin/brew"

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG"; }

[[ -x "$BREW" ]] || { log "brew niet gevonden op $BREW"; exit 1; }
[[ "$console_user" != "root" ]] || { log "Geen console-gebruiker; upgrade overgeslagen."; exit 0; }

run_as_user() { sudo -u "$console_user" "$BREW" "$@"; }

log "Start managed upgrade (gebruiker: $console_user)"
run_as_user update             >>"$LOG" 2>&1 || log "brew update gaf een fout"
run_as_user upgrade            >>"$LOG" 2>&1 || log "brew upgrade gaf een fout"
run_as_user upgrade --cask     >>"$LOG" 2>&1 || log "brew upgrade --cask gaf een fout"
run_as_user cleanup -s         >>"$LOG" 2>&1 || true
log "Managed upgrade voltooid"

# Trigger a fresh inventory report right after upgrading, if the agent exists.
if [[ -x /usr/local/grntly/report.sh ]]; then
  /usr/local/grntly/report.sh >>"$LOG" 2>&1 || true
fi
