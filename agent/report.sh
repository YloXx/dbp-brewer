#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# agent/report.sh — collect inventory + Homebrew update status and POST it to
# the central Google Apps Script Web App, keyed on serial number + user.
#
# The request is signed with HMAC-SHA256 over the raw JSON body using a shared
# secret, so the Web App can reject forged/unauthenticated reports.
#
# Configuration is read from /etc/grntly/agent.conf (root-only, mode 600):
#   GRNTLY_ENDPOINT="https://script.google.com/macros/s/XXXX/exec"
#   GRNTLY_SHARED_SECRET="....long random...."
#
# Run manually to test, or via the com.grntly.report LaunchDaemon.
# ---------------------------------------------------------------------------
set -euo pipefail

CONF="${GRNTLY_AGENT_CONF:-/etc/grntly/agent.conf}"
[[ -f "$CONF" ]] || { echo "[report] Config ontbreekt: $CONF" >&2; exit 1; }
# shellcheck disable=SC1090
source "$CONF"
: "${GRNTLY_ENDPOINT:?GRNTLY_ENDPOINT niet gezet in $CONF}"
: "${GRNTLY_SHARED_SECRET:?GRNTLY_SHARED_SECRET niet gezet in $CONF}"

# --- Collect facts ----------------------------------------------------------
serial="$(ioreg -l 2>/dev/null | awk -F'"' '/IOPlatformSerialNumber/{print $4; exit}')"
hostname="$(scutil --get ComputerName 2>/dev/null || hostname)"
# The user actually logged in at the console (not root running the daemon).
console_user="$(stat -f%Su /dev/console 2>/dev/null || echo unknown)"
os_version="$(sw_vers -productVersion 2>/dev/null || echo '?')"
os_build="$(sw_vers -buildVersion 2>/dev/null || echo '?')"
model="$(sysctl -n hw.model 2>/dev/null || echo '?')"
uptime_str="$(uptime | sed 's/^ *//')"
free_gb="$(df -g / 2>/dev/null | awk 'NR==2{print $4}')"

filevault="unknown"
if fdesetup status 2>/dev/null | grep -q "FileVault is On"; then filevault="on"; else filevault="off"; fi

firewall="unknown"
fw="/usr/libexec/ApplicationFirewall/socketfilterfw"
if [[ -x "$fw" ]]; then
  "$fw" --getglobalstate 2>/dev/null | grep -qi enabled && firewall="on" || firewall="off"
fi

gatekeeper="unknown"
spctl --status 2>/dev/null | grep -qi enabled && gatekeeper="on" || gatekeeper="off"

# Homebrew outdated status (as the console user, since brew is user-owned).
outdated_count=0
outdated_list=""
if [[ "$console_user" != "unknown" && "$console_user" != "root" ]]; then
  outdated_list="$(sudo -u "$console_user" /opt/homebrew/bin/brew outdated --quiet 2>/dev/null || true)"
  [[ -n "$outdated_list" ]] && outdated_count="$(printf '%s\n' "$outdated_list" | grep -c . || true)"
fi
# Compact the list to a comma-separated string for the sheet.
outdated_csv="$(printf '%s' "$outdated_list" | tr '\n' ',' | sed 's/,$//')"

timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

# --- Build JSON (escape helper) --------------------------------------------
# Pure-sed JSON string escaper (no python3 dependency, safe for a root daemon).
# Escapes backslash, double-quote, tab, CR and newline, then wraps in quotes.
json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"      # backslash first
  s="${s//\"/\\\"}"      # double quote
  s="${s//$'\t'/\\t}"    # tab
  s="${s//$'\r'/}"       # strip CR
  s="${s//$'\n'/\\n}"    # newline
  printf '"%s"' "$s"
}

payload=$(cat <<JSON
{
  "serial": $(json_escape "$serial"),
  "hostname": $(json_escape "$hostname"),
  "user": $(json_escape "$console_user"),
  "model": $(json_escape "$model"),
  "os_version": $(json_escape "$os_version"),
  "os_build": $(json_escape "$os_build"),
  "filevault": $(json_escape "$filevault"),
  "firewall": $(json_escape "$firewall"),
  "gatekeeper": $(json_escape "$gatekeeper"),
  "free_gb": $(json_escape "$free_gb"),
  "uptime": $(json_escape "$uptime_str"),
  "brew_outdated_count": $outdated_count,
  "brew_outdated": $(json_escape "$outdated_csv"),
  "reported_at": $(json_escape "$timestamp")
}
JSON
)

# --- Sign and send ----------------------------------------------------------
# HMAC-SHA256 as lowercase hex. Using openssl's text output (last field) avoids
# a dependency on xxd. Matches Apps Script's computeHmacSha256Signature.
signature="$(printf '%s' "$payload" \
  | openssl dgst -sha256 -hmac "$GRNTLY_SHARED_SECRET" \
  | awk '{print $NF}')"

# Apps Script Web Apps cannot read custom request headers, so the signature is
# passed as a query parameter (it still authenticates the JSON body).
sep="?"; [[ "$GRNTLY_ENDPOINT" == *"?"* ]] && sep="&"
http_code="$(curl -fsSL -o /tmp/grntly-report-resp.txt -w '%{http_code}' \
  --max-time 30 \
  -H "Content-Type: application/json" \
  -X POST --data "$payload" \
  "${GRNTLY_ENDPOINT}${sep}sig=sha256%3D${signature}" 2>/dev/null || echo "000")"

if [[ "$http_code" == "200" ]]; then
  echo "[report] OK — ${serial} / ${console_user} (${outdated_count} outdated)"
else
  echo "[report] FAILED — HTTP ${http_code}" >&2
  cat /tmp/grntly-report-resp.txt >&2 2>/dev/null || true
  exit 1
fi
