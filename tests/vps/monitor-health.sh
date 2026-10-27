#!/usr/bin/env bash
set -euo pipefail

log=${SING_BOX_YG_HEALTH_LOG:-/var/log/sing-box-yg-health.log}
state=${SING_BOX_YG_HEALTH_STATE:-/var/lib/sing-box-yg/health-monitor-start}
install -d -m 755 "$(dirname "$state")"
if [ ! -s "$state" ]; then date +%s > "$state"; fi
since="@$(cat "$state")"
service=$(systemctl is-active sing-box 2>/dev/null || true)
if /etc/s-box/sing-box check -c /etc/s-box/sb.json >/dev/null 2>&1; then config=ok; else config=failed; fi
disk=$(df -P /etc/s-box | awk 'NR==2 {print $5}')
errors=$(journalctl -u sing-box --since "$since" --priority=err --no-pager --quiet 2>/dev/null | grep -c . || true)
printf '%s service=%s config=%s disk=%s errors=%s
' "$(date --iso-8601=seconds)" "$service" "$config" "$disk" "$errors" >> "$log"
test "$service" = active
test "$config" = ok
