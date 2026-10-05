#!/usr/bin/env bash

assert_eq() {
  [ "$1" = "$2" ] || { printf 'expected=%s actual=%s\n' "$1" "$2" >&2; return 1; }
}

assert_not_called() {
  [ ! -s "$1" ]
}
