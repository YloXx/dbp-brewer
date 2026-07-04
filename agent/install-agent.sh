#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# agent/install-agent.sh — install the reporting + managed-upgrade agent and
# their LaunchDaemons on a Mac. Run once per machine (or from install.sh).
#
# Usage:
#   sudo ./install-agent.sh <ENDPOINT_URL> <SHARED_SECRET>
# ---------------------------------------------------------------------------
set -euo pipefail

[[ "$(id -u)" -eq 0 ]] || { echo "Draai dit script met sudo." >&2; exit 1; }
[[ $# -eq 2 ]] || { echo "Usage: sudo $0 <ENDPOINT_URL> <SHARED_SECRET>" >&2; exit 1; }

ENDPOINT="$1"
SECRET="$2"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="/usr/local/grntly"
CONF_DIR="/etc/grntly"

# --- Config (root-only) -----------------------------------------------------
mkdir -p "$CONF_DIR"
umask 077
cat >"${CONF_DIR}/agent.conf" <<CONF
GRNTLY_ENDPOINT="${ENDPOINT}"
GRNTLY_SHARED_SECRET="${SECRET}"
CONF
chmod 600 "${CONF_DIR}/agent.conf"
chown root:wheel "${CONF_DIR}/agent.conf"

# --- Agent scripts ----------------------------------------------------------
mkdir -p "$DEST"
install -m 0755 -o root -g wheel "${HERE}/report.sh"          "${DEST}/report.sh"
install -m 0755 -o root -g wheel "${HERE}/managed-upgrade.sh" "${DEST}/managed-upgrade.sh"

# --- LaunchDaemons ----------------------------------------------------------
for plist in com.grntly.report com.grntly.upgrade; do
  install -m 0644 -o root -g wheel "${HERE}/${plist}.plist" "/Library/LaunchDaemons/${plist}.plist"
  launchctl bootout system "/Library/LaunchDaemons/${plist}.plist" 2>/dev/null || true
  launchctl bootstrap system "/Library/LaunchDaemons/${plist}.plist"
done

echo "[agent] Geïnstalleerd. Eerste report draait direct; daarna elke 4 uur."
echo "[agent] Test handmatig: sudo ${DEST}/report.sh"
