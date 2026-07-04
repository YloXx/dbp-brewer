#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 60-debloat — remove unused pre-installed / leftover software so machines
# stay clean. The removal list is data-driven (config.d/bloat.tsv) and the
# repo's dedicated uninstallers (Zoom, etc.) are invoked when present.
# ---------------------------------------------------------------------------

debloat_main() {
  _remove_listed_apps
  _run_uninstallers
  _brew_cleanup
  log_ok "Debloat voltooid."
}

_remove_listed_apps() {
  local cfg="${GRNTLY_ROOT}/config.d/bloat.tsv"
  [[ -f "$cfg" ]] || return 0
  local path reason
  while IFS=$'\t' read -r path reason; do
    [[ -n "$path" ]] || continue
    if [[ -d "$path" ]]; then
      log_info "Verwijderen: ${path} (${reason})"
      run sudo rm -rf "$path"
    fi
  done < <(awk -F'\t' '/^[[:space:]]*#/{next} NF>=1' "$cfg")
}

_run_uninstallers() {
  local dir="${GRNTLY_ROOT}/uninstallers"
  [[ -d "$dir" ]] || return 0
  # Only run non-interactive uninstallers automatically here; the generic
  # app-uninstall.sh is left for manual use.
  local f
  for f in "$dir"/remove-*.sh; do
    [[ -f "$f" ]] || continue
    log_info "Uninstaller uitvoeren: $(basename "$f")"
    run bash "$f" || log_warn "Uninstaller $(basename "$f") gaf een fout terug."
  done
}

_brew_cleanup() {
  have brew || return 0
  log_info "Homebrew opschonen (oude versies, caches)..."
  run brew cleanup -s 2>/dev/null || true
  run rm -rf "$(brew --cache 2>/dev/null)" 2>/dev/null || true
}
