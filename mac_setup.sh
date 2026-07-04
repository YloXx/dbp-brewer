#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Grntly Mac Setup — compatibiliteits-shim.
#
# De setup is opgesplitst in een modulaire, geharde installer (install.sh +
# lib/ + modules/). Dit bestand blijft bestaan zodat de gedocumenteerde
# curl-oneliner blijft werken; het roept simpelweg install.sh aan.
#
# Let op: bij uitvoeren via `curl | bash` staat de repo niet lokaal. Kloon dan
# eerst de repo en draai ./install.sh, of gebruik de git-gepinde installer.
# ---------------------------------------------------------------------------
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"

if [[ -n "$HERE" && -f "${HERE}/install.sh" ]]; then
  exec "${HERE}/install.sh" "$@"
fi

cat >&2 <<'MSG'
[grntly-brewer] De modulaire installer (install.sh) is niet lokaal gevonden.
Kloon de repo en draai de installer:

    git clone https://github.com/grntly/grntly_brewer.git
    cd grntly_brewer
    ./install.sh

MSG
exit 1
