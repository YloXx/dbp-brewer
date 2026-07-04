#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 30-homebrew — install and configure Homebrew.
#
# Notes vs. the old script:
#  * Homebrew is left owned by the installing user (its default). We do NOT
#    chmod -R 775 /opt/homebrew (that weakens security and breaks brew's own
#    permission model).
#  * brew shellenv is written to the profile via ensure_line (idempotent).
#  * Analytics are disabled.
# ---------------------------------------------------------------------------

BREW_PREFIX="/opt/homebrew"

_brew_bin() {
  if [[ -x "${BREW_PREFIX}/bin/brew" ]]; then
    echo "${BREW_PREFIX}/bin/brew"
  elif have brew; then
    command -v brew
  else
    echo ""
  fi
}

homebrew_main() {
  if have brew; then
    log_info "Homebrew is al geïnstalleerd."
  else
    log_info "Homebrew installeren..."
    if [[ "$DRY_RUN" == "1" ]]; then
      log_info "[dry-run] curl Homebrew install script | bash"
    else
      NONINTERACTIVE=1 /bin/bash -c \
        "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
        || die "Homebrew-installatie is mislukt."
    fi
  fi

  local brew; brew="$(_brew_bin)"
  [[ -n "$brew" || "$DRY_RUN" == "1" ]] || die "brew niet gevonden na installatie."

  # Make brew available now and in future shells (idempotent).
  if [[ -n "$brew" ]]; then
    eval "$("$brew" shellenv)"
  fi
  local shellenv_line="eval \"\$(${BREW_PREFIX}/bin/brew shellenv)\""
  ensure_line "${HOME}/.bash_profile" "$shellenv_line"
  ensure_line "${HOME}/.zprofile"     "$shellenv_line"

  run "$brew" analytics off
  run "$brew" update
  log_ok "Homebrew is klaar."
}

# homebrew_rollback — remove a Homebrew installed by this toolkit.
homebrew_rollback() {
  if [[ -d "$BREW_PREFIX" ]]; then
    if ask_yes_no "Homebrew (${BREW_PREFIX}) volledig verwijderen?"; then
      run sudo rm -rf "$BREW_PREFIX"
      log_ok "Homebrew verwijderd."
    fi
  fi
}
