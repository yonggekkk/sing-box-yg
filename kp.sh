#!/bin/bash
# 定时设置：*/10 * * * * /bin/bash /root/kp.sh 每10分钟运行一次
# 如果你已安装了Serv00本地SSH脚本，不要再运行此脚本部署了，这样会造成进程爆满，必须二选一！
# serv00变量添加规则：
# 如使用保活网页，请不要启用cron，以防止cron与网页保活重复运行造成进程爆满
# RES(必填)：n表示每次不重置部署，y表示每次重置部署。REP(必填)：n表示不重置随机端口(三个端口留空)，y表示重置端口(三个端口留空)。SSH_USER(必填)表示serv00账号名。SSH_PASS(必填)表示serv00密码。REALITY表示reality域名(留空表示serv00官方域名：你serv00账号名.serv00.net)。SUUID表示uuid(留空表示随机uuid)。TCP1_PORT表示vless的tcp端口(留空表示随机tcp端口)。TCP2_PORT表示vmess的tcp端口(留空表示随机tcp端口)。UDP_PORT表示hy2的udp端口(留空表示随机udp端口)。HOST(必填)表示登录serv00服务器域名。ARGO_DOMAIN表示argo固定域名(留空表示临时域名)。ARGO_AUTH表示argo固定域名token(留空表示临时域名)。
# 必填变量：RES、REP、SSH_USER、SSH_PASS、HOST
# 注意[]"",:这些符号不要乱删，按规律对齐
# 每行一个{serv00服务器}，一个服务也可，末尾用,间隔，最后一个服务器末尾无需用,间隔

set -o pipefail

LOCK_FILE="${KP_LOCK_FILE:-/tmp/serv00_kp.lock}"
if command -v flock >/dev/null 2>&1; then
  exec 9>"$LOCK_FILE"
  if ! flock -n 9; then
    echo "⚠️ 已有 kp.sh 实例正在运行，跳过本次执行。"
    exit 0
  fi
fi

REPO_RAW_URL="${REPO_RAW_URL:-https://raw.githubusercontent.com/ArthurSawyer/sing-box-yg/fix/verified-improvements}"
SERV00KEEP_URL="${SERV00KEEP_URL:-${REPO_RAW_URL}/serv00keep.sh}"
SSH_STRICT_HOST_KEY_CHECKING="${SSH_STRICT_HOST_KEY_CHECKING:-accept-new}"
SSH_CONNECT_TIMEOUT="${SSH_CONNECT_TIMEOUT:-15}"

ACCOUNTS="${ACCOUNTS:-'[
{"RES":"n", "REP":"n", "SSH_USER":"你的serv00账号名", "SSH_PASS":"你的serv00账号密码", "REALITY":"你serv00账号名.serv00.net", "SUUID":"自设UUID", "TCP1_PORT":"vless的tcp端口", "TCP2_PORT":"vmess的tcp端口", "UDP_PORT":"hy2的udp端口", "HOST":"s1.serv00.com", "ARGO_DOMAIN":"", "ARGO_AUTH":""}
]'}"

install_missing_deps() {
  local missing=()
  for cmd in sshpass curl jq; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done

  if [ "${#missing[@]}" -eq 0 ]; then
    return 0
  fi

  echo "检测到缺少依赖 (${missing[*]})，正在同步安装……"
  if cat /etc/issue /proc/version /etc/os-release 2>/dev/null | grep -qi "openwrt"; then
    opkg update && opkg install sshpass curl jq
  elif [ -f /etc/debian_version ]; then
    apt-get update && apt-get install -y sshpass curl jq cron
  elif [ -f /etc/redhat-release ]; then
    yum install -y sshpass curl jq
  elif [ -f /etc/fedora-release ]; then
    dnf install -y sshpass curl jq
  elif [ -f /etc/alpine-release ]; then
    apk add --no-cache sshpass curl jq
  else
    echo "❌ 未识别的系统包管理器，请手动安装: ${missing[*]}"
    return 1
  fi

  for cmd in sshpass curl jq; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "❌ 依赖 $cmd 安装失败，无法继续执行。"
      return 1
    fi
  done
}

run_ssh() {
  local ssh_user="$1"
  local ssh_pass="$2"
  local host="$3"
  shift 3
  SSHPASS="$ssh_pass" sshpass -e ssh \
    -o "StrictHostKeyChecking=${SSH_STRICT_HOST_KEY_CHECKING}" \
    -o "ConnectTimeout=${SSH_CONNECT_TIMEOUT}" \
    -o BatchMode=no \
    "${ssh_user}@${host}" "$@"
}

run_remote_command() {
  local RES="$1"
  local REP="$2"
  local SSH_USER="$3"
  local SSH_PASS="$4"
  local REALITY="$5"
  local SUUID="$6"
  local TCP1_PORT="$7"
  local TCP2_PORT="$8"
  local UDP_PORT="$9"
  local HOST="${10}"
  local ARGO_DOMAIN="${11}"
  local ARGO_AUTH="${12}"

  if [ -z "${ARGO_DOMAIN}" ]; then
    echo "Argo域名为空，申请Argo临时域名" >&2
  else
    echo "Argo已设置固定域名：${ARGO_DOMAIN}" >&2
  fi

  local remote_command
  remote_command=$(printf 'export reym=%q UUID=%q vless_port=%q vmess_port=%q hy2_port=%q reset=%q resport=%q ARGO_DOMAIN=%q ARGO_AUTH=%q REPO_RAW_URL=%q && bash <(curl -fsSL %q)' \
    "$REALITY" "$SUUID" "$TCP1_PORT" "$TCP2_PORT" "$UDP_PORT" "$RES" "$REP" "$ARGO_DOMAIN" "$ARGO_AUTH" "$REPO_RAW_URL" "$SERV00KEEP_URL")

  echo "Executing remote deployment on $HOST as $SSH_USER (sensitive variables redacted)" >&2
  run_ssh "$SSH_USER" "$SSH_PASS" "$HOST" "$remote_command"
}

install_missing_deps || exit 1

echo "*****************************************************"
echo "自动远程部署Serv00三合一协议脚本【VPS+软路由】"
echo "版本：V25.3.26"
echo "*****************************************************"

if ! echo "${ACCOUNTS}" | jq -e 'type == "array"' >/dev/null 2>&1; then
  echo "❌ ACCOUNTS 格式无效，必须是 JSON 数组。"
  exit 1
fi

count=0
while IFS= read -r account; do
  [ -z "$account" ] && continue
  count=$((count + 1))

  RES=$(echo "$account" | jq -r '.RES // ""')
  REP=$(echo "$account" | jq -r '.REP // ""')
  SSH_USER=$(echo "$account" | jq -r '.SSH_USER // ""')
  SSH_PASS=$(echo "$account" | jq -r '.SSH_PASS // ""')
  REALITY=$(echo "$account" | jq -r '.REALITY // ""')
  SUUID=$(echo "$account" | jq -r '.SUUID // ""')
  TCP1_PORT=$(echo "$account" | jq -r '.TCP1_PORT // ""')
  TCP2_PORT=$(echo "$account" | jq -r '.TCP2_PORT // ""')
  UDP_PORT=$(echo "$account" | jq -r '.UDP_PORT // ""')
  HOST=$(echo "$account" | jq -r '.HOST // ""')
  ARGO_DOMAIN=$(echo "$account" | jq -r '.ARGO_DOMAIN // ""')
  ARGO_AUTH=$(echo "$account" | jq -r '.ARGO_AUTH // ""')

  if [ -z "$SSH_USER" ] || [ -z "$SSH_PASS" ] || [ -z "$HOST" ]; then
    echo "⚠️ 第【$count】台服务器配置缺少 SSH_USER/SSH_PASS/HOST，跳过。"
    continue
  fi

  if run_ssh "$SSH_USER" "$SSH_PASS" "$HOST" -n -q exit; then
    echo "🎉恭喜！✅第【$count】台服务器连接成功！🚀服务器地址：$HOST ，账户名：$SSH_USER"

    if [ -z "${ARGO_DOMAIN}" ]; then
      if [ -n "${TCP2_PORT}" ]; then
        argo_check=$(printf "ps aux | grep -F %q | grep -v grep > /dev/null" "localhost:${TCP2_PORT}")
      else
        argo_check="ps aux | grep -E 'tunnel.*--url http://localhost:' | grep -v grep > /dev/null"
      fi
    else
      argo_check="ps aux | grep -E 'tunnel.*run.*--token' | grep -v grep > /dev/null"
    fi
    check_process="ps aux | grep '[r]un -c config\.json' > /dev/null && ${argo_check}"

    if ! run_ssh "$SSH_USER" "$SSH_PASS" "$HOST" -n "$check_process" || [[ "$RES" =~ ^[Yy]$ ]]; then
      echo "⚠️检测到主进程或者argo进程未启动，或者执行重置"
      echo "⚠️现在开始修复或重置部署……请稍等"
      if output=$(run_remote_command "$RES" "$REP" "$SSH_USER" "$SSH_PASS" "$REALITY" "$SUUID" "$TCP1_PORT" "$TCP2_PORT" "$UDP_PORT" "$HOST" "$ARGO_DOMAIN" "$ARGO_AUTH"); then
        echo "✅ 远程命令执行完成"
      else
        echo "❌ 远程命令执行失败"
      fi
      if [ -n "$output" ]; then
        if [ -n "$ARGO_AUTH" ]; then
          printf '%s\n' "${output//"$ARGO_AUTH"/[REDACTED]}"
        else
          printf '%s\n' "$output"
        fi
      fi
    else
      echo "🎉恭喜！✅检测到所有进程正常运行中"
      SSH_USER_LOWER=$(printf '%s' "$SSH_USER" | tr '[:upper:]' '[:lower:]')
      list_cmd=$(printf 'echo "配置显示如下：" && cat domains/%q.serv00.net/logs/list.txt && echo "===================================================="' "$SSH_USER_LOWER")
      run_ssh "$SSH_USER" "$SSH_PASS" "$HOST" -n "$list_cmd"
    fi
  else
    echo "===================================================="
    echo "💥杯具！❌第【$count】台服务器连接失败！🚀服务器地址：$HOST ，账户名：$SSH_USER"
    echo "⚠️可能账号名、密码、服务器名称输入错误，或者当前服务器在维护中"
    echo "===================================================="
  fi
done < <(echo "${ACCOUNTS}" | jq -c '.[]')
