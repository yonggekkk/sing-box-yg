#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$repo_root/tests/lib/assert.sh"
fragment=$(mktemp)
log=$(mktemp)
bin=$(mktemp)
trap 'rm -f "$fragment" "$log" "$bin"' EXIT

sed -n '/^checksb(){/,/^stclre(){/p' "$repo_root/sb.sh" | sed '$d' > "$fragment"
red() { :; }
systemctl() { printf '%s\n' "$*" >> "$log"; return 0; }
source "$fragment"
sbfiles=''
snapshot_config() { :; }

printf '#!/usr/bin/env bash\nexit 1\n' > "$bin"
chmod +x "$bin"
SING_BOX_BIN="$bin"
if restartsb; then exit 1; fi
assert_not_called "$log"

printf '#!/usr/bin/env bash\nexit 0\n' > "$bin"
restartsb
grep -Fx 'restart sing-box' "$log"
grep -Fx 'is-active --quiet sing-box' "$log"
