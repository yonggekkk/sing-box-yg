#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
fragment="$tmpdir/functions.sh"

sed -n '/^download_to_temp(){/,/^inssb(){/p' "$repo_root/sb.sh" | sed '$d' > "$fragment"
source "$fragment"

SBYG_VERSION_FILE="$tmpdir/version"
printf old > "$SBYG_VERSION_FILE"
download_to_temp() {
  printf '%s\n' '2026.07.12 更新内容：测试' > "$tmpdir/payload"
  printf '%s\n' "$tmpdir/payload"
}
update_sbyg_version
grep -Fx 2026.07.12 "$SBYG_VERSION_FILE"

download_to_temp() { return 1; }
if update_sbyg_version; then exit 1; fi
grep -Fx 2026.07.12 "$SBYG_VERSION_FILE"
