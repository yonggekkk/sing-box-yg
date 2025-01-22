#!/bin/bash
# 定时设置：*/10 * * * * /bin/bash /root/kp.sh 每10分钟运行一次
# serv00变量添加规则：
# RES(必填)：n表示每次不重置部署，y表示每次重置部署。SSH_USER(必填)表示用户名。SSH_PASS(必填)表示密码。REALITY表示reality域名(留空表示serv00官方域名：你用户名.serv00.net)。SUUID表示uuid(留空表示随机uuid)。TCP1_PORT表示vless的tcp端口(留空表示随机tcp端口)。TCP2_PORT表示vmess的tcp端口(留空表示随机tcp端口)。UDP_PORT表示hy2的udp端口(留空表示随机udp端口)。HOST(必填)表示登录服务器域名。ARGO_DOMAIN表示argo固定域名(留空表示临时域名)。ARGO_AUTH表示argo固定域名token(留空表示临时域名)。
# 必填变量：RES、SSH_USER、SSH_PASS、HOST
# 每行一个{serv00服务器}，单个服务也可，末尾用,间隔，最后一个服务器末尾无需用,间隔
ACCOUNTS='[
  {"RES":"n", "SSH_USER":"第二个账号ygkkk1", "SSH_PASS":"ygkkk123", "REALITY":"www.wto.org", "SUUID":"a0ae1415-3390-4f92-ab83-d942db07ae94", "TCP1_PORT":"15661", "TCP2_PORT":"15662", "UDP_PORT":"15663", "HOST":"s1.serv00.com", "ARGO_DOMAIN":"", "ARGO_AUTH":""},
  {"RES":"y", "SSH_USER":"第三个账号ygkkk2", "SSH_PASS":"ygkkk456", "REALITY":"time.is", "SUUID":"2f68aba2-b460-43ca-b9c3-1ac843bd2c70", "TCP1_PORT":"55254", "TCP2_PORT":"55255", "UDP_PORT":"55256", "HOST":"s16.serv00.com", "ARGO_DOMAIN":"abcd.ygkkk.eu.org", "ARGO_AUTH":"eyJhIjoiOTM3YzFjYWI88552NTFiYTM4ZTY0ZDQzMWRhOTgyNzkiLCJ0IjoiYjI1MDc5MDktMWQzMS00MWNmLWI1N2QtYTkxNGIxOTAzOTExIiwicyI6Ik9XTmxNR1F6WkRRdE56a3dNaTAwWlRaakxXRmlNelF0TkRBd1pUQTRNVEJqTUdVeCJ9"}
]'
run_remote_command() {
  local RES=$1
  local SSH_USER=$2
  local SSH_PASS=$3
  local REALITY=$4
  local SUUID=$5
  local TCP1_PORT=$6
  local TCP2_PORT=$7
  local UDP_PORT=$8
  local HOST=$9
  local ARGO_DOMAIN=${10}
  local ARGO_AUTH=${11}
  if [ -z "${ARGO_DOMAIN}" ]; then
    echo "Argo域名为空，申请Argo临时域名"
  else
    echo "Argo已设置固定域名：${ARGO_DOMAIN}"
  fi
  remote_command="export reym=$REALITY UUID=$SUUID vless_port=$TCP1_PORT vmess_port=$TCP2_PORT hy2_port=$UDP_PORT reset=$RES ARGO_DOMAIN=${ARGO_DOMAIN} ARGO_AUTH=${ARGO_AUTH} && bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/serv00keep.sh)"
  echo "Executing remote command on $HOST as $SSH_USER with command: $remote_command"
  sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no "$SSH_USER@$HOST" "$remote_command"
}
if  cat /etc/issue /proc/version /etc/os-release 2>/dev/null | grep -q -E -i "openwrt"; then
opkg update
opkg install sshpass curl jq
else
    if [ -f /etc/debian_version ]; then
        package_manager="apt-get install -y"
        apt-get update >/dev/null 2>&1
    elif [ -f /etc/redhat-release ]; then
        package_manager="yum install -y"
    elif [ -f /etc/fedora-release ]; then
        package_manager="dnf install -y"
    elif [ -f /etc/alpine-release ]; then
        package_manager="apk add"
    fi
    $package_manager sshpass curl jq cron >/dev/null 2>&1 &
fi
echo "*****************************************************"
echo "*****************************************************"
echo "甬哥Github项目  ：github.com/yonggekkk"
echo "甬哥Blogger博客 ：ygkkk.blogspot.com"
echo "甬哥YouTube频道 ：www.youtube.com/@ygkkk"
echo "自动远程部署Serv00三合一协议脚本【VPS+软路由】"
echo "版本：V25.1.22"
echo "*****************************************************"
echo "*****************************************************"
              count=0  
           for account in $(echo "${ACCOUNTS}" | jq -c '.[]'); do
              count=$((count+1))
              RES=$(echo $account | jq -r '.RES')
              SSH_USER=$(echo $account | jq -r '.SSH_USER')
              SSH_PASS=$(echo $account | jq -r '.SSH_PASS')
              REALITY=$(echo $account | jq -r '.REALITY')
              SUUID=$(echo $account | jq -r '.SUUID')
              TCP1_PORT=$(echo $account | jq -r '.TCP1_PORT')
              TCP2_PORT=$(echo $account | jq -r '.TCP2_PORT')
              UDP_PORT=$(echo $account | jq -r '.UDP_PORT')
              HOST=$(echo $account | jq -r '.HOST')
              ARGO_DOMAIN=$(echo $account | jq -r '.ARGO_DOMAIN')
              ARGO_AUTH=$(echo $account | jq -r '.ARGO_AUTH') 
          if sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no "$SSH_USER@$HOST" -q exit; then
            echo "🎉恭喜！✅第【$count】台服务器连接成功！🚀服务器地址：$HOST ，账户名：$SSH_USER"   
          if [ -z "${ARGO_DOMAIN}" ]; then
           check_process="ps aux | grep '[c]onfig' > /dev/null && ps aux | grep [l]ocalhost:$TCP2_PORT > /dev/null"
            else
           check_process="ps aux | grep '[c]onfig' > /dev/null && ps aux | grep '[t]oken $ARGO_AUTH' > /dev/null"
           fi
          if ! sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no "$SSH_USER@$HOST" "$check_process" || [[ "$RES" =~ ^[Yy]$ ]]; then
            echo "⚠️检测到主进程或者argo进程未启动，或者执行重置"
             echo "⚠️现在开始修复或重置部署……请稍等"
             output=$(run_remote_command "$RES" "$SSH_USER" "$SSH_PASS" "${REALITY}" "$SUUID" "$TCP1_PORT" "$TCP2_PORT" "$UDP_PORT" "$HOST" "${ARGO_DOMAIN}" "${ARGO_AUTH}")
            echo "远程命令执行结果：$output"
          else
            echo "🎉恭喜！✅检测到所有进程正常运行中 "
            echo "配置显示如下："
          sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no "$SSH_USER@$HOST" \
             "cat domains/\$(whoami).serv00.net/logs/list.txt; \
              echo '===================================================='; \
              echo 'Clash-meta订阅配置文件:'; \
              cat domains/\$(whoami).serv00.net/logs/clash_meta.yaml; \
              echo '===================================================='; \
              echo 'Sing-box订阅配置文件:'; \
              cat domains/\$(whoami).serv00.net/logs/sing_box.json; \
              echo '===================================================='" 
            fi
           else
            echo "===================================================="
            echo "💥杯具！❌第【$count】台服务器连接失败！🚀服务器地址：$HOST ，账户名：$SSH_USER"
            echo "⚠️可能账号名、密码、服务器名称输入错误，或者当前服务器在维护中"  
            echo "===================================================="
           fi
            done
