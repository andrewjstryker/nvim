#!/usr/bin/env bash
# Provision the standalone server outside the plugin checkout. Publish only a
# complete, runnable download; a failed sync leaves the previous file intact.
set -euo pipefail
version=${1:?server version required}
destination=${2:?server destination required}
: "${COPILOT_CURL:?curl path required}" "${COPILOT_UNZIP:?unzip path required}"

if [[ -s "$destination" && -x "$destination" ]]; then
  printf 'Copilot server %s already provisioned.\n' "$version"
  exit 0
fi

case "$(uname -s)/$(uname -m)" in
  Linux/x86_64) platform=linux-x64 ;;
  Linux/aarch64|Linux/arm64) platform=linux-arm64 ;;
  Darwin/x86_64) platform=darwin-x64 ;;
  Darwin/arm64) platform=darwin-arm64 ;;
  *) printf 'Unsupported Copilot binary platform: %s/%s\n' "$(uname -s)" "$(uname -m)" >&2; exit 1 ;;
esac

mkdir -p "$(dirname "$destination")"
temporary=$(mktemp -d "$(dirname "$destination")/.download.XXXXXX")
trap 'rm -rf "$temporary"' EXIT
archive="copilot-language-server-${platform}-${version}.zip"
url="https://github.com/github/copilot-language-server-release/releases/download/${version}/${archive}"
printf 'Provisioning Copilot server %s (%s)...\n' "$version" "$platform"
"$COPILOT_CURL" --fail --location --show-error --silent --retry 3 \
  --connect-timeout 30 --max-time 300 --output "$temporary/server.zip" "$url"
"$COPILOT_UNZIP" -q "$temporary/server.zip" -d "$temporary/extracted"
binary="$temporary/extracted/copilot-language-server"
test -s "$binary"
chmod +x "$binary"
# Detect incompatible hosts and malformed artifacts during sync, not startup.
"$binary" --version
mv "$binary" "$destination"
