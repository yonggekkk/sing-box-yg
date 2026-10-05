#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
fragment="$tmpdir/functions.sh"

sed -n '/^download_to_temp(){/,/^inssb(){/p' "$repo_root/sb.sh" | sed '$d' > "$fragment"
source "$fragment"

first="$tmpdir/first.json"
second="$tmpdir/second.json"
printf '%s\n' '{"inbounds":[{"tag":"vmess-sb","listen_port":10001,"users":[{"uuid":"old"}],"transport":{"path":"/old"},"tls":{"enabled":true,"server_name":"old.example","certificate_path":"/old/cert","key_path":"/old/key"}},{"tag":"vless-sb","listen_port":10002,"users":[{"uuid":"old"}],"tls":{"server_name":"old.example","reality":{"handshake":{"server":"old.example"}}}},{"tag":"hy2-sb","listen_port":10003,"users":[{"password":"old"}],"tls":{"certificate_path":"/old/cert","key_path":"/old/key"}}]}' > "$first"
printf '%s\n' '{"inbounds":[{"tag":"tuic5-sb","listen_port":10004,"users":[{"uuid":"old"}],"tls":{"certificate_path":"/old/cert","key_path":"/old/key"}},{"tag":"vless-sb","listen_port":10005,"users":[{"uuid":"old"}],"tls":{"server_name":"old.example","reality":{"handshake":{"server":"old.example"}}}},{"tag":"anytls-sb","listen_port":10006,"users":[{"password":"old"}],"tls":{"certificate_path":"/old/cert","key_path":"/old/key"}}]}' > "$second"
chmod 640 "$first"
sbfiles="$first $second"

update_inbound_port vless-sb 18443
test "$(jq -r '.inbounds[] | select(.tag == "vless-sb") | .listen_port' "$first")" = 18443
test "$(jq -r '.inbounds[] | select(.tag == "vless-sb") | .listen_port' "$second")" = 18443
case $(uname -s) in
  MINGW*|MSYS*) ;;
  *) test "$(stat -c %a "$first")" = 640 ;;
esac

update_vless_reality_server_name safe.example
test "$(jq -r '.inbounds[] | select(.tag == "vless-sb") | .tls.server_name' "$first")" = safe.example
test "$(jq -r '.inbounds[] | select(.tag == "vless-sb") | .tls.reality.handshake.server' "$second")" = safe.example

update_inbound_tls vmess-sb false vm.example /new/cert /new/key
test "$(jq -r '.inbounds[] | select(.tag == "vmess-sb") | .tls.enabled' "$first")" = false
test "$(jq -r '.inbounds[] | select(.tag == "vmess-sb") | .tls.server_name' "$first")" = vm.example
test "$(jq -r '.inbounds[] | select(.tag == "vmess-sb") | .tls.certificate_path' "$first")" = /new/cert

update_inbound_tls hy2-sb '' '' /hy2/cert /hy2/key
test "$(jq -r '.inbounds[] | select(.tag == "hy2-sb") | .tls.key_path' "$first")" = /hy2/key
update_vmess_path '/safe/#path?x=1'
test "$(jq -r '.inbounds[] | select(.tag == "vmess-sb") | .transport.path' "$first")" = '/safe/#path?x=1'
update_inbound_credentials new-credential
test "$(jq -r '.inbounds[] | select(.tag == "hy2-sb") | .users[0].password' "$first")" = new-credential
test "$(jq -r '.inbounds[] | select(.tag == "tuic5-sb") | .users[0].uuid' "$second")" = new-credential

before=$(sha256sum "$first" "$second")
if update_inbound_port missing-tag 18444; then exit 1; fi
if update_inbound_port vless-sb invalid-port; then exit 1; fi
after=$(sha256sum "$first" "$second")
test "$before" = "$after"
