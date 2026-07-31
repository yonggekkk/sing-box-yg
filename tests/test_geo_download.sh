#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
fragment="$tmpdir/functions.sh"
log="$tmpdir/downloads.log"

sed -n '/^download_to_temp(){/,/^inssb(){/p' "$repo_root/sb.sh" | sed '$d' > "$fragment"
source "$fragment"

download_to_temp() {
  printf '%s\n' "$1" >> "$log"
  printf '%s' "${1##*/}" > "$tmpdir/payload"
  printf '%s\n' "$tmpdir/payload"
}

GEO_DATABASE_DIR="$tmpdir/databases"
mkdir -p "$GEO_DATABASE_DIR"
install_geo_databases
grep -Fx 'https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.db' "$log"
grep -Fx 'https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.db' "$log"
grep -Fx geoip.db "$GEO_DATABASE_DIR/geoip.db"
grep -Fx geosite.db "$GEO_DATABASE_DIR/geosite.db"
case $(uname -s) in
  MINGW*|MSYS*) ;;
  *) test "$(stat -c %a "$GEO_DATABASE_DIR/geoip.db")" = 644 ;;
esac
