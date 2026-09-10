#!/usr/bin/env bash
set -Eeuo pipefail

astra_project="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ "$(uname -s)" != Linux ]]; then
  echo 'Use scripts/install.ps1 on Windows 11 Pro. Only Ubuntu LTS-based Linux is supported here.' >&2
  exit 1
fi

command -v python3 >/dev/null 2>&1 || { echo 'Install python3 before running Astra setup.' >&2; exit 1; }
python3 - <<'PY'
import pathlib, re, sys
values = {}
for line in pathlib.Path('/etc/os-release').read_text().splitlines():
    match = re.match(r'^([A-Z][A-Z0-9_]*)=(.*)$', line)
    if match:
        values[match[1]] = match[2].strip().strip('\"\'')
ubuntu = values.get('ID') == 'ubuntu'
derived = 'ubuntu' in values.get('ID_LIKE', '').split()
codename = values.get('UBUNTU_CODENAME') or (values.get('VERSION_CODENAME') if ubuntu else None)
versions = {'jammy': '22.04', 'noble': '24.04', 'resolute': '26.04'}
if not (ubuntu or derived) or codename not in versions or (ubuntu and values.get('VERSION_ID', versions[codename]) != versions[codename]):
    sys.exit('Astra requires Ubuntu 22.04/24.04/26.04 LTS or a derivative declaring that Ubuntu base.')
PY

# The Windows launcher stages a checked-out project on the Linux filesystem.
# All paths are positional arguments; no user path becomes executable shell text.
if [[ "${1:-}" == --copy-to ]]; then
  [[ $# -ge 2 && "$2" = /* ]] || { echo '--copy-to requires an absolute Linux path.' >&2; exit 1; }
  astra_target="$(realpath -m -- "$2")"
  case "$astra_target/" in "$astra_project/"*) echo 'Copy destination cannot be inside the source checkout.' >&2; exit 1;; esac
  [[ ! -e "$astra_target" ]] || { echo "Destination already exists: $astra_target" >&2; exit 1; }
  shift 2
  mkdir -p -- "$(dirname -- "$astra_target")"
  mkdir -- "$astra_target"
  tar -C "$astra_project" --exclude=.git --exclude=node_modules --exclude=.env --exclude='.env.*' \
    --exclude=.test-output --exclude=.test-state --exclude=coverage --exclude=dist --exclude=backups \
    --exclude=runtime --exclude=runtime-packages --exclude=verification.json --exclude=verification.log \
    --exclude=tool-catalog.json --exclude=settings.json --exclude=backends.json \
    --exclude=browser-output --exclude=browser-profiles --exclude=app-homes -cf - . | tar -C "$astra_target" -xf -
  exec bash "$astra_target/scripts/install.sh" "$@"
fi

# Keep an existing modern Node runtime; otherwise install a verified official
# Node 22 build privately. No shell profile edits or global Node replacement.
if ! command -v node >/dev/null 2>&1 || ! node -e 'process.exit(Number(process.versions.node.split(".")[0]) >= 22 ? 0 : 1)'; then
  astra_node_root="${XDG_DATA_HOME:-${HOME}/.local/share}/astra-mcp/node"
  if [[ -x "$astra_node_root/bin/node" ]] && "$astra_node_root/bin/node" -e 'process.exit(Number(process.versions.node.split(".")[0]) >= 22 ? 0 : 1)'; then
    export PATH="$astra_node_root/bin:$PATH"
  else
    for astra_option in "$@"; do
      if [[ "$astra_option" == --check || "$astra_option" == --print-entry ]]; then
        echo 'Node.js 22+ is missing. Run bash scripts/install.sh to install a private runtime.' >&2
        exit 1
      fi
    done
    for astra_command in curl tar xz sha256sum; do
      command -v "$astra_command" >/dev/null 2>&1 || { echo "Missing $astra_command. Install curl xz-utils before retrying." >&2; exit 1; }
    done
    case "$(uname -m)" in
      x86_64) astra_arch=x64 ;;
      aarch64|arm64) astra_arch=arm64 ;;
      *) echo 'Astra requires x86-64 or ARM64.' >&2; exit 1 ;;
    esac
    astra_download="$(mktemp -d)"
    trap 'rm -rf -- "$astra_download"' EXIT
    curl --fail --show-error --silent --location --proto '=https' --tlsv1.2 'https://nodejs.org/dist/latest-v22.x/SHASUMS256.txt' -o "$astra_download/SHASUMS256.txt"
    astra_line="$(awk -v arch="$astra_arch" '$2 ~ ("^node-v22\\.[0-9]+\\.[0-9]+-linux-" arch "\\.tar\\.xz$") { print; count++ } END { if (count != 1) exit 1 }' "$astra_download/SHASUMS256.txt")"
    astra_archive="${astra_line##* }"
    astra_version="${astra_archive#node-}"
    astra_version="${astra_version%-linux-*}"
    curl --fail --show-error --silent --location --proto '=https' --tlsv1.2 "https://nodejs.org/dist/$astra_version/$astra_archive" -o "$astra_download/$astra_archive"
    (cd -- "$astra_download" && printf '%s\n' "$astra_line" | sha256sum --check --status)
    mkdir -p -- "$astra_node_root"
    tar -xJf "$astra_download/$astra_archive" --strip-components=1 -C "$astra_node_root"
    export PATH="$astra_node_root/bin:$PATH"
    rm -rf -- "$astra_download"
    trap - EXIT
  fi
fi
exec node "$astra_project/scripts/install.mjs" "$@"
