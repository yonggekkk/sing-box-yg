#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$repo_root/tests/lib/assert.sh"
fragment=$(mktemp)
call_log=$(mktemp)
hint_log=$(mktemp)
trap 'rm -f "$fragment" "$call_log" "$hint_log"' EXIT

sed -n '/^close(){/,/^inssb(){/p' "$repo_root/sb.sh" | sed '$d' > "$fragment"
red() { :; }
green() { :; }
yellow() { :; }
readp() { printf -v "$2" '%s' "$TEST_ACTION"; }
source "$fragment"
close() { printf 'legacy-close\n' >> "$call_log"; }

TEST_ACTION=''
openyn
assert_not_called "$call_log"

TEST_ACTION='2'
openyn
grep -qx 'legacy-close' "$call_log"

yellow() { printf '%s\n' "$1" >> "$hint_log"; }
port_vl_re=18443
port_vm_ws=18080
port_an=18446
port_hy2=18444
port_tu=18445
firewall_hint
grep -Fx 'TCP：18443 18080 18446' "$hint_log"
grep -Fx 'UDP：18444 18445' "$hint_log"
