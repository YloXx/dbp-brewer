#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 20-naming — set the computer name following the company convention:
#   <PREFIX>-<MACTYPE>-<YY><ITER>-<INITIALS>   e.g. GRANTLY-MBP-2501-JD
# Sets ComputerName, LocalHostName and HostName consistently.
# ---------------------------------------------------------------------------

naming_main() {
  local yy; yy="$(date +%y)"
  local name="${COMPANY_PREFIX}-${MAC_TYPE}-${yy}${ITERATION}-${USER_INITIALS}"
  # LocalHostName may only contain letters, digits and hyphens.
  local local_name; local_name="$(printf '%s' "$name" | tr -c '[:alnum:]-' '-')"

  run sudo scutil --set ComputerName "$name"
  run sudo scutil --set LocalHostName "$local_name"
  run sudo scutil --set HostName "$local_name"
  export COMPUTER_NAME="$name"
  log_ok "Computernaam ingesteld: ${name}"
}
