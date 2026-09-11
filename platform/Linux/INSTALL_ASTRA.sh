#!/usr/bin/env bash
set -uo pipefail

# Works both at a release archive's root and in platform/Linux in a checkout.
astra_here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
astra_root="$astra_here"
[[ -f "$astra_root/scripts/install.sh" ]] || astra_root="$(cd -- "$astra_here/../.." && pwd)"

astra_finish() {
  local astra_exit="$1"
  if (( astra_exit )); then
    echo "Astra setup failed (exit $astra_exit). Read the error above and START_HERE.md before retrying." >&2
  else
    echo 'Setup finished. Restart LM Studio and enable mcp/astra for a compatible model.'
  fi
  if [[ -t 0 && "${ASTRA_NO_PAUSE:-0}" != 1 ]]; then
    read -r -p 'Press Enter to close this installer...' || true
  fi
  exit "$astra_exit"
}

if [[ "$(uname -s)" != Linux || "$EUID" == 0 ]]; then
  echo 'Run this launcher on Ubuntu LTS-based Linux as your ordinary user, not root.' >&2
  astra_finish 1
fi
if [[ ! -f "$astra_root/scripts/install.sh" || ! -f "$astra_root/package-lock.json" ]]; then
  echo 'Extract the complete Astra release before running this launcher.' >&2
  astra_finish 1
fi
for astra_command in python3 curl tar xz sha256sum; do
  if ! command -v "$astra_command" >/dev/null 2>&1; then
    echo "Missing prerequisite: $astra_command. Install python3 curl xz-utils before retrying." >&2
    astra_finish 1
  fi
done

if [[ "${1:-}" == --no-gui ]]; then
  shift
elif [[ $# == 0 && "${ASTRA_NO_GUI:-0}" != 1 && -n "${DISPLAY:-}" ]] && python3 "$astra_root/scripts/setup-gui.py" --check >/dev/null 2>&1; then
  exec python3 "$astra_root/scripts/setup-gui.py"
fi

astra_target="$HOME/.local/share/astra-mcp/sources/release-$(date -u +%Y%m%d-%H%M%S)-$$"
echo "Installing a fresh Astra source copy in $astra_target"
bash "$astra_root/scripts/install.sh" --copy-to "$astra_target" --system-deps --replace-legacy "$@"
astra_finish "$?"
