#!/usr/bin/env bash
set -euo pipefail

# This intentionally exercises the recovery path on a disposable VPS.  It
# writes an invalid temporary configuration, verifies that restartsb restores
# the last known-good copy, then leaves the running service untouched.
if [ "${1:-}" != "--live" ]; then
  printf 'Refusing to run on a live host. Re-run with --live on a dedicated test VPS.
' >&2
  exit 2
fi
if [ "$(id -u)" -ne 0 ]; then
  printf 'This integration test must run as root.
' >&2
  exit 2
fi

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
config=/etc/s-box/sb.json
binary=/etc/s-box/sing-box
test -x "$binary"
test -f "$config"

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT
fragment="$workdir/recovery-functions.sh"
sed -n '/^checksb(){/,/^stclre(){/p' "$repo_root/sb.sh" | sed '$d' > "$fragment"

# The extracted functions use the script's coloured output helper.  Keep test
# output readable without sourcing the interactive menu itself.
red() { printf '%s
' "$*" >&2; }
source "$fragment"

SING_BOX_BIN="$binary"
sbfiles="$config"
config_state_dir=/etc/s-box/.last-known-good
before=$(sha256sum "$config" | awk '{print $1}')

"$binary" check -c "$config"
systemctl is-active --quiet sing-box
snapshot_config
printf '{invalid
' > "$config"
if restartsb; then
  printf 'restartsb unexpectedly accepted an invalid configuration.
' >&2
  exit 1
fi

after=$(sha256sum "$config" | awk '{print $1}')
test "$before" = "$after"
"$binary" check -c "$config"
systemctl is-active --quiet sing-box
printf 'host integration: recovery and service checks passed
'
