#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 70-profiles — deploy an optimal macOS defaults set (.macos) and a managed
# .bashrc for all human users. Idempotent: re-running does not duplicate lines.
#
# The .bashrc is deployed from profiles/bashrc.template. A .bash_profile that
# sources .bashrc is ensured, and a ~/Development directory is created (via a
# real directory, NOT a `cd` in the profile as the old script did).
# ---------------------------------------------------------------------------

profiles_main() {
  _apply_macos_defaults
  _deploy_dotfiles_all_users
  log_ok "Profielen uitgerold."
}

# --- macOS defaults ---------------------------------------------------------
_apply_macos_defaults() {
  log_info "macOS-defaults toepassen..."
  # Finder: show path bar, status bar, extensions, POSIX path in title
  run defaults write com.apple.finder ShowPathbar -bool true
  run defaults write com.apple.finder ShowStatusBar -bool true
  run defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
  run defaults write NSGlobalDomain AppleShowAllExtensions -bool true
  run defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
  # Screenshots to ~/Screenshots as PNG
  run mkdir -p "$HOME/Screenshots"
  run defaults write com.apple.screencapture location -string "$HOME/Screenshots"
  run defaults write com.apple.screencapture type -string "png"
  # Dock: autohide, no recents, faster
  run defaults write com.apple.dock autohide -bool true
  run defaults write com.apple.dock show-recents -bool false
  # Avoid creating .DS_Store on network/USB volumes
  run defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
  run defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true
  # Expand save/print dialogs by default
  run defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
  run defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true

  run killall Finder 2>/dev/null || true
  run killall Dock   2>/dev/null || true
}

# --- Dotfiles ---------------------------------------------------------------
# List human users (UID >= 501) with a real home directory.
_human_users() {
  dscl . -list /Users UniqueID 2>/dev/null | awk '$2 >= 501 {print $1}'
}

_deploy_dotfiles_one() {
  local user="$1" home
  home="$(dscl . -read "/Users/$user" NFSHomeDirectory 2>/dev/null | awk '{print $2}')"
  [[ -d "$home" ]] || { log_warn "Home van $user niet gevonden; overslaan."; return 0; }

  local tmpl="${GRNTLY_ROOT}/profiles/bashrc.template"
  log_info "Dotfiles uitrollen voor ${user} (${home})"

  if [[ "$DRY_RUN" == "1" ]]; then
    log_info "[dry-run] deploy .bashrc/.bash_profile + ~/Development voor ${user}"
    return 0
  fi

  backup_once "${home}/.bashrc"
  sudo cp "$tmpl" "${home}/.bashrc"
  # .bash_profile should source .bashrc (login shells)
  printf '%s\n' '[[ -f ~/.bashrc ]] && source ~/.bashrc' | sudo tee "${home}/.bash_profile" >/dev/null
  sudo mkdir -p "${home}/Development"
  sudo chown "$user" "${home}/.bashrc" "${home}/.bash_profile" "${home}/Development"
}

_deploy_dotfiles_all_users() {
  local u
  while read -r u; do
    [[ -n "$u" ]] && _deploy_dotfiles_one "$u"
  done < <(_human_users)
}
