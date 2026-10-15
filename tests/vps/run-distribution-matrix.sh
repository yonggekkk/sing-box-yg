#!/usr/bin/env bash
set -euo pipefail

images=(ubuntu:24.04 debian:12 rockylinux:9 alpine:3.20)
for image in "${images[@]}"; do
  case "$image" in
    ubuntu:*|debian:*|rockylinux:*|alpine:*) ;;
    *) printf 'unsupported image: %s
' "$image" >&2; exit 2 ;;
  esac
  output=$(docker run --rm "$image" sh -c '
    set -eu
    test -r /etc/os-release
    . /etc/os-release
    case "$ID" in
      ubuntu|debian) command -v apt-get ;;
      rocky) command -v dnf ;;
      alpine) command -v apk ;;
      *) exit 3 ;;
    esac
    printf "id=%s package_manager=ok
" "$ID"
  ')
  printf 'image=%s %s
' "$image" "$output"
done
