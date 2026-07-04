#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 40-apps — install the app profile for the selected USER_TYPE, plus the
# company wallpaper and a cleaned-up Dock. App lists are data-driven from
# config.d/apps.tsv (no hardcoded case blocks).
# ---------------------------------------------------------------------------

# _brew_install_if_missing formula|cask NAME
_install_pkg() {
  local kind="$1" name="$2"
  case "$kind" in
    formula)
      if brew list --versions "$name" &>/dev/null; then
        log_info "$name is al geïnstalleerd."
      else
        run brew install "$name"
      fi ;;
    cask)
      if brew list --cask --versions "$name" &>/dev/null; then
        log_info "$name (cask) is al geïnstalleerd."
      else
        run brew install --cask "$name"
      fi ;;
  esac
}

_install_profile() {
  local role="$1" cfg="${GRNTLY_ROOT}/config.d/apps.tsv"
  # Read rows matching the role: field2=kind, field3=name.
  while IFS=$'\t' read -r r kind name; do
    [[ "$r" == "$role" ]] || continue
    [[ -n "$name" ]] || continue
    _install_pkg "$kind" "$name"
  done < <(awk -F'\t' '/^[[:space:]]*#/{next} NF>=3' "$cfg")
}

_set_wallpaper() {
  [[ -n "${WALLPAPER_URL:-}" ]] || return 0
  local dest="/Library/Desktop Pictures/company-wallpaper.jpg"
  log_info "Wallpaper downloaden..."
  if [[ "$DRY_RUN" == "1" ]]; then
    log_info "[dry-run] wallpaper -> $dest"
    return 0
  fi
  run sudo mkdir -p "/Library/Desktop Pictures"
  if curl -fsSL --max-time 30 "$WALLPAPER_URL" -o /tmp/company-wallpaper.jpg; then
    sudo cp /tmp/company-wallpaper.jpg "$dest"
    rm -f /tmp/company-wallpaper.jpg
    osascript -e "tell application \"System Events\" to set picture of every desktop to POSIX file \"$dest\"" 2>/dev/null || true
    log_ok "Wallpaper geïnstalleerd."
  else
    log_warn "Wallpaper downloaden mislukt voor ${COMPANY_NAME}."
  fi
}

_reset_dock() {
  have dockutil || _install_pkg formula dockutil
  if have dockutil; then
    log_info "Dock opschonen..."
    run dockutil --remove all --no-restart 2>/dev/null || true
  fi
}

apps_main() {
  have brew || { log_warn "Homebrew ontbreekt; app-installatie overgeslagen."; return 0; }

  log_info "App-profiel installeren voor: ${USER_TYPE}"
  _install_profile "$USER_TYPE"

  _set_wallpaper
  _reset_dock

  # A sensible default Dock for everyone; the developer module adds dev tools.
  if have dockutil; then
    run dockutil --add "/Applications/Google Chrome.app" --no-restart 2>/dev/null || true
    run dockutil --add "/Applications/Slack.app" --no-restart 2>/dev/null || true
    run dockutil --add "/System/Applications/Mail.app" --no-restart 2>/dev/null || true
    run dockutil --add "/System/Applications/Notes.app" --no-restart 2>/dev/null || true
    run killall Dock 2>/dev/null || true
  fi

  log_ok "Apps geïnstalleerd voor ${USER_TYPE}."
}
