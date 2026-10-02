#!/usr/bin/env bash
# Exercise failure recovery and cache reuse without network access.
set -euo pipefail
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT
installer="$(cd "$(dirname "$0")/.." && pwd)/build/scripts/install_copilot.sh"
cat > "$root/curl" <<'SH'
#!/usr/bin/env bash
set -eu
[[ ${COPILOT_TEST_FAIL:-} != download ]] || exit 22
while [[ $1 != --output ]]; do shift; done
printf archive > "$2"
SH
cat > "$root/unzip" <<'SH'
#!/usr/bin/env bash
set -eu
[[ ${COPILOT_TEST_FAIL:-} != extract ]] || exit 9
mkdir -p "$4"
printf '#!/bin/sh\nexit %s\n' "${COPILOT_TEST_BINARY_EXIT:-0}" > "$4/copilot-language-server"
SH
chmod +x "$root/curl" "$root/unzip"
export COPILOT_CURL="$root/curl" COPILOT_UNZIP="$root/unzip"
destination="$root/cache with spaces/1.503.0/copilot-language-server"
for failure in download extract; do
  if COPILOT_TEST_FAIL=$failure bash "$installer" 1.503.0 "$destination"; then
    echo "Installer ignored $failure failure" >&2; exit 1
  fi
  test ! -e "$destination"
done
if COPILOT_TEST_BINARY_EXIT=1 bash "$installer" 1.503.0 "$destination"; then
  echo 'Installer accepted an unusable server' >&2; exit 1
fi
test ! -e "$destination"
bash "$installer" 1.503.0 "$destination"
test -x "$destination"
# No network call on a second sync, even if downloading would now fail.
COPILOT_TEST_FAIL=download bash "$installer" 1.503.0 "$destination"
test -z "$(find "$root" -name '.download.*' -print)"
echo 'COPILOT INSTALLER OK: failures, retry, atomic publication and cache reuse'
