#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
fragment="$tmpdir/functions.sh"
sed -n '/^download_to_temp(){/,/^inssb(){/p' "$repo_root/sb.sh" | sed '$d' > "$fragment"
source "$fragment"

destination="$tmpdir/current"
printf old > "$destination"
curl() { return 1; }
if download_to_temp https://example.invalid "$destination"; then exit 1; fi
grep -Fx old "$destination"

source_file="$tmpdir/source"
: > "$source_file"
if atomic_install "$source_file" "$destination"; then exit 1; fi
grep -Fx old "$destination"

printf new > "$source_file"
atomic_install "$source_file" "$destination" 700
grep -Fx new "$destination"
case $(uname -s) in
  MINGW*|MSYS*) ;;
  *) test "$(stat -c %a "$destination")" = 700 ;;
esac
