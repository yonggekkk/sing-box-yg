#!/bin/bash
re="\033[0m"
red="\033[1;91m"
green="\e[1;32m"
yellow="\e[1;33m"
purple="\e[1;35m"
red() { echo -e "\e[1;91m$1\033[0m"; }
green() { echo -e "\e[1;32m$1\033[0m"; }
yellow() { echo -e "\e[1;33m$1\033[0m"; }
purple() { echo -e "\e[1;35m$1\033[0m"; }
reading() { read -p "$(red "$1")" "$2"; }
USERNAME=$(whoami | tr '[:upper:]' '[:lower:]')
HOSTNAME=$(hostname)
snb=$(hostname | awk -F '.' '{print $1}')
devil www add ${USERNAME}.serv00.net php > /dev/null 2>&1
FILE_PATH="${HOME}/domains/${USERNAME}.serv00.net/public_html"
WORKDIR="${HOME}/domains/${USERNAME}.serv00.net/logs"
[ -d "$WORKDIR" ] || (mkdir -p "$WORKDIR" && chmod 777 "$WORKDIR")
curl -sk "http://${snb}.${USERNAME}.serv00.net/up" > /dev/null 2>&1

read_ip() {
cat ip.txt
reading "请输入上面三个IP中的任意一个 (建议默认回车自动选择可用IP): " IP
if [[ -z "$IP" ]]; then
IP=$(grep -m 1 "可用" ip.txt | awk -F ':' '{print $1}')
if [ -z "$IP" ]; then
IP=$(okip)
if [ -z "$IP" ]; then
IP=$(head -n 1 ip.txt | awk -F ':' '{print $1}')
fi
fi
fi
green "你选择的IP为: $IP"
}

read_uuid() {
        reading "请输入统一的uuid密码 (建议回车默认随机): " UUID
        if [[ -z "$UUID" ]]; then
	   UUID=$(uuidgen -r)
        fi
	green "你的uuid为: $UUID"
}

read_reym() {
        yellow "方式一：(推荐)使用CF域名，支持proxyip+非标端口反代ip功能：输入回车"
	yellow "方式二：(推荐)使用Serv00自带域名，不支持proxyip功能：输入s"
        yellow "方式三：支持其他域名，注意要符合reality域名规则：输入域名"
        reading "请输入reality域名 【请选择 回车 或者 s 或者 输入域名】: " reym
        if [[ -z "$reym" ]]; then
           reym=www.speedtest.net
	elif [[ "$reym" == "s" || "$reym" == "S" ]]; then
           reym=$USERNAME.serv00.net
        fi
	green "你的reality域名为: $reym"
}

resallport(){
portlist=$(devil port list | grep -E '^[0-9]+[[:space:]]+[a-zA-Z]+' | sed 's/^[[:space:]]*//')
if [[ -z "$portlist" ]]; then
yellow "无端口"
else
while read -r line; do
port=$(echo "$line" | awk '{print $1}')
port_type=$(echo "$line" | awk '{print $2}')
yellow "删除端口 $port ($port_type)"
devil port del "$port_type" "$port"
done <<< "$portlist"
fi
check_port
}

check_port () {
port_list=$(devil port list)
tcp_ports=$(echo "$port_list" | grep -c "tcp")
udp_ports=$(echo "$port_list" | grep -c "udp")

if [[ $tcp_ports -ne 2 || $udp_ports -ne 1 ]]; then
    red "端口数量不符合要求，正在调整..."

    if [[ $tcp_ports -gt 2 ]]; then
        tcp_to_delete=$((tcp_ports - 2))
        echo "$port_list" | awk '/tcp/ {print $1, $2}' | head -n $tcp_to_delete | while read port type; do
            devil port del $type $port
            green "已删除TCP端口: $port"
        done
    fi

    if [[ $udp_ports -gt 1 ]]; then
        udp_to_delete=$((udp_ports - 1))
        echo "$port_list" | awk '/udp/ {print $1, $2}' | head -n $udp_to_delete | while read port type; do
            devil port del $type $port
            green "已删除UDP端口: $port"
        done
    fi

    if [[ $tcp_ports -lt 2 ]]; then
        tcp_ports_to_add=$((2 - tcp_ports))
        tcp_ports_added=0
        while [[ $tcp_ports_added -lt $tcp_ports_to_add ]]; do
            tcp_port=$(shuf -i 10000-65535 -n 1) 
            result=$(devil port add tcp $tcp_port 2>&1)
            if [[ $result == *"succesfully"* ]]; then
                green "已添加TCP端口: $tcp_port"
                if [[ $tcp_ports_added -eq 0 ]]; then
                    tcp_port1=$tcp_port
                else
                    tcp_port2=$tcp_port
                fi
                tcp_ports_added=$((tcp_ports_added + 1))
            else
                yellow "端口 $tcp_port 不可用，尝试其他端口..."
            fi
        done
    fi

    if [[ $udp_ports -lt 1 ]]; then
        while true; do
            udp_port=$(shuf -i 10000-65535 -n 1) 
            result=$(devil port add udp $udp_port 2>&1)
            if [[ $result == *"succesfully"* ]]; then
                green "已添加UDP端口: $udp_port"
                break
            else
                yellow "端口 $udp_port 不可用，尝试其他端口..."
            fi
        done
    fi
    green "端口已调整完成,将断开ssh连接,请重新连接shh重新执行脚本"
    devil binexec on >/dev/null 2>&1
    kill -9 $(ps -o ppid= -p $$) >/dev/null 2>&1
    sleep 2
else
    tcp_ports=$(echo "$port_list" | awk '/tcp/ {print $1}')
    tcp_port1=$(echo "$tcp_ports" | sed -n '1p')
    tcp_port2=$(echo "$tcp_ports" | sed -n '2p')
    udp_port=$(echo "$port_list" | awk '/udp/ {print $1}')

    purple "当前TCP端口: $tcp_port1 和 $tcp_port2"
    purple "当前UDP端口: $udp_port"
fi
export vless_port=$tcp_port1
export vmess_port=$tcp_port2
export hy2_port=$udp_port
green "你的vless-reality端口: $vless_port"
green "你的vmess-ws端口(设置Argo固定域名端口): $vmess_port"
green "你的hysteria2端口: $hy2_port"
}

install_singbox() {
if [[ -e $WORKDIR/list.txt ]]; then
yellow "已安装sing-box，请先选择2卸载，再执行安装" && exit
fi
sleep 2
        cd $WORKDIR
	echo
	read_ip
 	echo
        read_reym
	echo
	read_uuid
        echo
        check_port
	echo
        sleep 2
        argo_configure
	echo
        download_and_run_singbox
	cd
        fastrun
	green "创建快捷方式：sb"
	echo
	servkeep
        cd $WORKDIR
        echo
        get_links
	cd
}

uninstall_singbox() {
  reading "\n确定要卸载吗？【y/n】: " choice
    case "$choice" in
       [Yy])
	  bash -c 'ps aux | grep $(whoami) | grep -v "sshd\|bash\|grep" | awk "{print \$2}" | xargs -r kill -9 >/dev/null 2>&1' >/dev/null 2>&1
          rm -rf domains bin serv00keep.sh
          sed -i '/export PATH="\$HOME\/bin:\$PATH"/d' "${HOME}/.bashrc" >/dev/null 2>&1
          source "${HOME}/.bashrc" >/dev/null 2>&1
	  #crontab -l | grep -v "serv00keep" >rmcron
          #crontab rmcron >/dev/null 2>&1
          #rm rmcron
          clear
          green "已完全卸载"
          ;;
        [Nn]) exit 0 ;;
    	*) red "无效的选择，请输入y或n" && menu ;;
    esac
}

kill_all_tasks() {
reading "\n清理所有进程并清空所有安装内容，将退出ssh连接，确定继续清理吗？【y/n】: " choice
  case "$choice" in
    [Yy]) 
    bash -c 'ps aux | grep $(whoami) | grep -v "sshd\|bash\|grep" | awk "{print \$2}" | xargs -r kill -9 >/dev/null 2>&1' >/dev/null 2>&1
    devil www del ${snb}.${USERNAME}.serv00.net > /dev/null 2>&1
    devil www del ${USERNAME}.serv00.net > /dev/null 2>&1
    sed -i '/export PATH="\$HOME\/bin:\$PATH"/d' "${HOME}/.bashrc" >/dev/null 2>&1
    source "${HOME}/.bashrc" >/dev/null 2>&1 
    #crontab -l | grep -v "serv00keep" >rmcron
    #crontab rmcron >/dev/null 2>&1
    #rm rmcron
    find ~ -type f -exec chmod 644 {} \; 2>/dev/null
    find ~ -type d -exec chmod 755 {} \; 2>/dev/null
    find ~ -type f -exec rm -f {} \; 2>/dev/null
    find ~ -type d -empty -exec rmdir {} \; 2>/dev/null
    find ~ -exec rm -rf {} \; 2>/dev/null
    killall -9 -u $(whoami)
    ;;
    *) menu ;;
  esac
}

# Generating argo Config
argo_configure() {
  while true; do
    yellow "方式一：(推荐)无需域名的Argo临时隧道：输入回车"
    yellow "方式二：需要域名的Argo固定隧道(需要CF设置提取Token)：输入g"
    echo -e "${red}注意：${purple}Argo固定隧道使用Token时，需要在cloudflare后台设置隧道端口，该端口必须与vmess-ws的tcp端口 $vmess_port 一致)${re}"
    reading "【请选择 g 或者 回车】: " argo_choice
    if [[ "$argo_choice" != "g" && "$argo_choice" != "G" && -n "$argo_choice" ]]; then
        red "无效的选择，请输入 g 或回车"
        continue
    fi
    if [[ "$argo_choice" == "g" || "$argo_choice" == "G" ]]; then
        reading "请输入argo固定隧道域名: " ARGO_DOMAIN
        green "你的argo固定隧道域名为: $ARGO_DOMAIN"
        reading "请输入argo固定隧道密钥（当你粘贴Token时，必须以ey开头）: " ARGO_AUTH
        green "你的argo固定隧道密钥为: $ARGO_AUTH"
    else
        green "使用Argo临时隧道"
    fi
    break
done

  if [[ $ARGO_AUTH =~ TunnelSecret ]]; then
    echo $ARGO_AUTH > tunnel.json
    cat > tunnel.yml << EOF
tunnel: $(cut -d\" -f12 <<< "$ARGO_AUTH")
credentials-file: tunnel.json
protocol: http2

ingress:
  - hostname: $ARGO_DOMAIN
    service: http://localhost:$vmess_port
    originRequest:
      noTLSVerify: true
  - service: http_status:404
EOF
  fi
}

# Download Dependency Files
download_and_run_singbox() {
  ARCH=$(uname -m) && DOWNLOAD_DIR="." && mkdir -p "$DOWNLOAD_DIR" && FILE_INFO=()
  if [ "$ARCH" == "arm" ] || [ "$ARCH" == "arm64" ] || [ "$ARCH" == "aarch64" ]; then
      FILE_INFO=("https://github.com/eooce/test/releases/download/arm64/sb web" "https://github.com/eooce/test/releases/download/arm64/bot13 bot")
  elif [ "$ARCH" == "amd64" ] || [ "$ARCH" == "x86_64" ] || [ "$ARCH" == "x86" ]; then
      FILE_INFO=("https://github.com/yonggekkk/Cloudflare_vless_trojan/releases/download/serv00/sb web" "https://github.com/yonggekkk/Cloudflare_vless_trojan/releases/download/serv00/server bot")
  else
      echo "Unsupported architecture: $ARCH"
      exit 1
  fi
declare -A FILE_MAP
generate_random_name() {
    local chars=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890
    local name=""
    for i in {1..6}; do
        name="$name${chars:RANDOM%${#chars}:1}"
    done
    echo "$name"
}

download_with_fallback() {
    local URL=$1
    local NEW_FILENAME=$2

    curl -L -sS --max-time 2 -o "$NEW_FILENAME" "$URL" &
    CURL_PID=$!
    CURL_START_SIZE=$(stat -c%s "$NEW_FILENAME" 2>/dev/null || echo 0)
    
    sleep 1
    CURL_CURRENT_SIZE=$(stat -c%s "$NEW_FILENAME" 2>/dev/null || echo 0)
    
    if [ "$CURL_CURRENT_SIZE" -le "$CURL_START_SIZE" ]; then
        kill $CURL_PID 2>/dev/null
        wait $CURL_PID 2>/dev/null
        wget -q -O "$NEW_FILENAME" "$URL"
        echo -e "\e[1;32mDownloading $NEW_FILENAME by wget\e[0m"
    else
        wait $CURL_PID
        echo -e "\e[1;32mDownloading $NEW_FILENAME by curl\e[0m"
    fi
}

for entry in "${FILE_INFO[@]}"; do
    URL=$(echo "$entry" | cut -d ' ' -f 1)
    RANDOM_NAME=$(generate_random_name)
    NEW_FILENAME="$DOWNLOAD_DIR/$RANDOM_NAME"
    
    if [ -e "$NEW_FILENAME" ]; then
        echo -e "\e[1;32m$NEW_FILENAME already exists, Skipping download\e[0m"
    else
        download_with_fallback "$URL" "$NEW_FILENAME"
    fi
    
    chmod +x "$NEW_FILENAME"
    FILE_MAP[$(echo "$entry" | cut -d ' ' -f 2)]="$NEW_FILENAME"
done
wait

output=$(./"$(basename ${FILE_MAP[web]})" generate reality-keypair)
private_key=$(echo "${output}" | awk '/PrivateKey:/ {print $2}')
public_key=$(echo "${output}" | awk '/PublicKey:/ {print $2}')
echo "${private_key}" > private_key.txt
echo "${public_key}" > public_key.txt

openssl ecparam -genkey -name prime256v1 -out "private.key"
openssl req -new -x509 -days 3650 -key "private.key" -out "cert.pem" -subj "/CN=$USERNAME.serv00.net"

nb=$(hostname | cut -d '.' -f 1 | tr -d 's')
if [[ "$nb" =~ (14|15|16) ]]; then
ytb='"jnn-pa.googleapis.com",'
fi
hy1p=$(sed -n '1p' hy2ip.txt)
hy2p=$(sed -n '2p' hy2ip.txt)
hy3p=$(sed -n '3p' hy2ip.txt)
  cat > config.json << EOF
{
  "log": {
    "disabled": true,
    "level": "info",
    "timestamp": true
  },
    "inbounds": [
    {
       "tag": "hysteria-in",
       "type": "hysteria2",
       "listen": "$hy1p",
       "listen_port": $hy2_port,
       "users": [
         {
             "password": "$UUID"
         }
     ],
     "masquerade": "https://www.bing.com",
     "ignore_client_bandwidth":false,
     "tls": {
         "enabled": true,
         "alpn": [
             "h3"
         ],
         "certificate_path": "cert.pem",
         "key_path": "private.key"
        }
    },
        {
       "tag": "hysteria-in",
       "type": "hysteria2",
       "listen": "$hy2p",
       "listen_port": $hy2_port,
       "users": [
         {
             "password": "$UUID"
         }
     ],
     "masquerade": "https://www.bing.com",
     "ignore_client_bandwidth":false,
     "tls": {
         "enabled": true,
         "alpn": [
             "h3"
         ],
         "certificate_path": "cert.pem",
         "key_path": "private.key"
        }
    },
        {
       "tag": "hysteria-in",
       "type": "hysteria2",
       "listen": "$hy3p",
       "listen_port": $hy2_port,
       "users": [
         {
             "password": "$UUID"
         }
     ],
     "masquerade": "https://www.bing.com",
     "ignore_client_bandwidth":false,
     "tls": {
         "enabled": true,
         "alpn": [
             "h3"
         ],
         "certificate_path": "cert.pem",
         "key_path": "private.key"
        }
    },
    {
        "tag": "vless-reality-vesion",
        "type": "vless",
        "listen": "::",
        "listen_port": $vless_port,
        "users": [
            {
              "uuid": "$UUID",
              "flow": "xtls-rprx-vision"
            }
        ],
        "tls": {
            "enabled": true,
            "server_name": "$reym",
            "reality": {
                "enabled": true,
                "handshake": {
                    "server": "$reym",
                    "server_port": 443
                },
                "private_key": "$private_key",
                "short_id": [
                  ""
                ]
            }
        }
    },
{
      "tag": "vmess-ws-in",
      "type": "vmess",
      "listen": "::",
      "listen_port": $vmess_port,
      "users": [
      {
        "uuid": "$UUID"
      }
    ],
    "transport": {
      "type": "ws",
      "path": "$UUID-vm",
      "early_data_header_name": "Sec-WebSocket-Protocol"
      }
    }
 ],
    "outbounds": [
     {
        "type": "wireguard",
        "tag": "wg",
        "server": "162.159.192.200",
        "server_port": 4500,
        "local_address": [
                "172.16.0.2/32",
                "2606:4700:110:8f77:1ca9:f086:846c:5f9e/128"
        ],
        "private_key": "wIxszdR2nMdA7a2Ul3XQcniSfSZqdqjPb6w6opvf5AU=",
        "peer_public_key": "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
        "reserved": [
            126,
            246,
            173
        ]
    },
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "block",
      "tag": "block"
    }
  ],
   "route": {
       "rule_set": [
      {
        "tag": "geosite-google-gemini",
        "type": "remote",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-google-gemini.srs",
        "download_detour": "direct"
      }
    ],
    "rules": [
    {
     "domain": [
     $ytb
     "oh.my.god"
      ],
     "outbound": "wg"
     },
     {
     "rule_set":"geosite-google-gemini",
     "outbound": "wg"
    }
    ],
    "final": "direct"
    }  
}
EOF

if [ -e "$(basename "${FILE_MAP[web]}")" ]; then
   echo "$(basename "${FILE_MAP[web]}")" > sb.txt
   sbb=$(cat sb.txt)
    nohup ./"$sbb" run -c config.json >/dev/null 2>&1 &
    sleep 5
if pgrep -x "$sbb" > /dev/null; then
    green "$sbb 主进程已启动"
else
for ((i=1; i<=5; i++)); do
    red "$sbb 主进程未启动, 重启中... (尝试次数: $i)"
    pkill -x "$sbb"
    nohup ./"$sbb" run -c config.json >/dev/null 2>&1 &
    sleep 5
    if pgrep -x "$sbb" > /dev/null; then
        purple "$sbb 主进程已成功重启"
        break
    fi
    if [[ $i -eq 5 ]]; then
        red "$sbb 主进程重启失败"
    fi
done
fi
fi
if [ -e "$(basename "${FILE_MAP[bot]}")" ]; then
   echo "$(basename "${FILE_MAP[bot]}")" > ag.txt
   agg=$(cat ag.txt)
    rm -rf boot.log
    if [[ $ARGO_AUTH =~ ^[A-Z0-9a-z=]{120,250}$ ]]; then
      #args="tunnel --edge-ip-version auto --no-autoupdate --protocol http2 run --token ${ARGO_AUTH}"
      args="tunnel --no-autoupdate run --token ${ARGO_AUTH}"
    elif [[ $ARGO_AUTH =~ TunnelSecret ]]; then
      args="tunnel --edge-ip-version auto --config tunnel.yml run"
    else
     #args="tunnel --edge-ip-version auto --no-autoupdate --protocol http2 --logfile boot.log --loglevel info --url http://localhost:$vmess_port"
     args="tunnel --url http://localhost:$vmess_port --no-autoupdate --logfile boot.log --loglevel info"
    fi    
    nohup ./"$agg" $args >/dev/null 2>&1 &
    sleep 10
if pgrep -x "$agg" > /dev/null; then
    green "$agg Argo进程已启动"
else
for ((i=1; i<=5; i++)); do
    red "$agg Argo进程未启动, 重启中...(尝试次数: $i)"
    pkill -x "$agg"
    nohup ./"$agg" "${args}" >/dev/null 2>&1 &
    sleep 5
    if pgrep -x "$agg" > /dev/null; then
        purple "$agg Argo进程已成功重启"
        break
    fi
    if [[ $i -eq 5 ]]; then
        red "$agg Argo进程重启失败，Argo节点暂不可用(保活过程中会自动恢复)，其他节点依旧可用"
    fi
done
fi
fi
sleep 2
if ! pgrep -x "$(cat sb.txt)" > /dev/null; then
red "主进程未启动，根据以下情况一一排查"
yellow "1、网页端权限是否开启"
yellow "2、选择7重置端口，自动生成随机可用端口（重要）"
yellow "3、选择8重置"
yellow "4、当前Serv00服务器炸了？等会再试"
red "5、以上都试了，哥直接躺平，交给进程保活，过会再来看"
sleep 6
fi
}

get_argodomain() {
  if [[ -n $ARGO_AUTH ]]; then
    echo "$ARGO_DOMAIN" > gdym.log
    echo "$ARGO_DOMAIN"
  else
    local retry=0
    local max_retries=6
    local argodomain=""
    while [[ $retry -lt $max_retries ]]; do
    ((retry++)) 
    argodomain=$(cat boot.log 2>/dev/null | grep -a trycloudflare.com | awk 'NR==2{print}' | awk -F// '{print $2}' | awk '{print $1}')
      if [[ -n $argodomain ]]; then
        break
      fi
      sleep 2
    done  
    if [ -z ${argodomain} ]; then
    argodomain="Argo临时域名暂时获取失败，Argo节点暂不可用(保活过程中会自动恢复)，其他节点依旧可用"
    fi
    echo "$argodomain"
  fi
}

get_links(){
argodomain=$(get_argodomain)
echo -e "\e[1;32mArgo域名：\e[1;35m${argodomain}\e[0m\n"
ISP=$(curl -sL --max-time 5 https://speed.cloudflare.com/meta | awk -F\" '{print $26}' | sed -e 's/ /_/g' || echo "0")
get_name() { if [ "$HOSTNAME" = "s1.ct8.pl" ]; then SERVER="CT8"; else SERVER=$(echo "$HOSTNAME" | cut -d '.' -f 1); fi; echo "$SERVER"; }
NAME="$ISP-$(get_name)"
rm -rf jh.txt
vl_link="vless://$UUID@$IP:$vless_port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$reym&fp=chrome&pbk=$public_key&type=tcp&headerType=none#$NAME-reality"
echo "$vl_link" >> jh.txt
vmws_link="vmess://$(echo "{ \"v\": \"2\", \"ps\": \"$NAME-vmess-ws\", \"add\": \"$IP\", \"port\": \"$vmess_port\", \"id\": \"$UUID\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"\", \"path\": \"/$UUID-vm?ed=2048\", \"tls\": \"\", \"sni\": \"\", \"alpn\": \"\", \"fp\": \"\"}" | base64 -w0)"
echo "$vmws_link" >> jh.txt
vmatls_link="vmess://$(echo "{ \"v\": \"2\", \"ps\": \"$NAME-vmess-ws-tls-argo\", \"add\": \"icook.hk\", \"port\": \"8443\", \"id\": \"$UUID\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$argodomain\", \"path\": \"/$UUID-vm?ed=2048\", \"tls\": \"tls\", \"sni\": \"$argodomain\", \"alpn\": \"\", \"fp\": \"\"}" | base64 -w0)"
echo "$vmatls_link" >> jh.txt
vma_link="vmess://$(echo "{ \"v\": \"2\", \"ps\": \"$NAME-vmess-ws-argo\", \"add\": \"icook.hk\", \"port\": \"8880\", \"id\": \"$UUID\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$argodomain\", \"path\": \"/$UUID-vm?ed=2048\", \"tls\": \"\"}" | base64 -w0)"
echo "$vma_link" >> jh.txt
hy2_link="hysteria2://$UUID@$IP:$hy2_port?sni=www.bing.com&alpn=h3&insecure=1#$NAME-hy2"
echo "$hy2_link" >> jh.txt
url=$(cat jh.txt 2>/dev/null)
baseurl=$(echo -e "$url" | base64 -w 0)

cat > sing_box.json <<EOF
{
  "log": {
    "disabled": false,
    "level": "info",
    "timestamp": true
  },
  "experimental": {
    "clash_api": {
      "external_controller": "127.0.0.1:9090",
      "external_ui": "ui",
      "external_ui_download_url": "",
      "external_ui_download_detour": "",
      "secret": "",
      "default_mode": "Rule"
       },
      "cache_file": {
            "enabled": true,
            "path": "cache.db",
            "store_fakeip": true
        }
    },
    "dns": {
        "servers": [
            {
                "tag": "proxydns",
                "address": "tls://8.8.8.8/dns-query",
                "detour": "select"
            },
            {
                "tag": "localdns",
                "address": "h3://223.5.5.5/dns-query",
                "detour": "direct"
            },
            {
                "tag": "dns_fakeip",
                "address": "fakeip"
            }
        ],
        "rules": [
            {
                "outbound": "any",
                "server": "localdns",
                "disable_cache": true
            },
            {
                "clash_mode": "Global",
                "server": "proxydns"
            },
            {
                "clash_mode": "Direct",
                "server": "localdns"
            },
            {
                "rule_set": "geosite-cn",
                "server": "localdns"
            },
            {
                 "rule_set": "geosite-geolocation-!cn",
                 "server": "proxydns"
            },
             {
                "rule_set": "geosite-geolocation-!cn",         
                "query_type": [
                    "A",
                    "AAAA"
                ],
                "server": "dns_fakeip"
            }
          ],
           "fakeip": {
           "enabled": true,
           "inet4_range": "198.18.0.0/15",
           "inet6_range": "fc00::/18"
         },
          "independent_cache": true,
          "final": "proxydns"
        },
      "inbounds": [
    {
      "type": "tun",
           "tag": "tun-in",
	  "address": [
      "172.19.0.1/30",
	  "fd00::1/126"
      ],
      "auto_route": true,
      "strict_route": true,
      "sniff": true,
      "sniff_override_destination": true,
      "domain_strategy": "prefer_ipv4"
    }
  ],
  "outbounds": [
    {
      "tag": "select",
      "type": "selector",
      "default": "auto",
      "outbounds": [
        "auto",
        "vless-$NAME",
        "vmess-$NAME",
        "hy2-$NAME",
"vmess-tls-argo-$NAME",
"vmess-argo-$NAME"
      ]
    },
    {
      "type": "vless",
      "tag": "vless-$NAME",
      "server": "$IP",
      "server_port": $vless_port,
      "uuid": "$UUID",
      "packet_encoding": "xudp",
      "flow": "xtls-rprx-vision",
      "tls": {
        "enabled": true,
        "server_name": "$reym",
        "utls": {
          "enabled": true,
          "fingerprint": "chrome"
        },
      "reality": {
          "enabled": true,
          "public_key": "$public_key",
          "short_id": ""
        }
      }
    },
{
            "server": "$IP",
            "server_port": $vmess_port,
            "tag": "vmess-$NAME",
            "tls": {
                "enabled": false,
                "server_name": "www.bing.com",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "www.bing.com"
                    ]
                },
                "path": "/$UUID-vm",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$UUID"
        },

    {
        "type": "hysteria2",
        "tag": "hy2-$NAME",
        "server": "$IP",
        "server_port": $hy2_port,
        "password": "$UUID",
        "tls": {
            "enabled": true,
            "server_name": "www.bing.com",
            "insecure": true,
            "alpn": [
                "h3"
            ]
        }
    },
{
            "server": "icook.hk",
            "server_port": 8443,
            "tag": "vmess-tls-argo-$NAME",
            "tls": {
                "enabled": true,
                "server_name": "$argodomain",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$argodomain"
                    ]
                },
                "path": "/$UUID-vm",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$UUID"
        },
{
            "server": "icook.hk",
            "server_port": 8880,
            "tag": "vmess-argo-$NAME",
            "tls": {
                "enabled": false,
                "server_name": "$argodomain",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$argodomain"
                    ]
                },
                "path": "/$UUID-vm",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$UUID"
        },
    {
      "tag": "direct",
      "type": "direct"
    },
    {
      "tag": "auto",
      "type": "urltest",
      "outbounds": [
        "vless-$NAME",
        "vmess-$NAME",
        "hy2-$NAME",
"vmess-tls-argo-$NAME",
"vmess-argo-$NAME"
      ],
      "url": "https://www.gstatic.com/generate_204",
      "interval": "1m",
      "tolerance": 50,
      "interrupt_exist_connections": false
    }
  ],
  "route": {
      "rule_set": [
            {
                "tag": "geosite-geolocation-!cn",
                "type": "remote",
                "format": "binary",
                "url": "https://cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/geolocation-!cn.srs",
                "download_detour": "select",
                "update_interval": "1d"
            },
            {
                "tag": "geosite-cn",
                "type": "remote",
                "format": "binary",
                "url": "https://cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/geolocation-cn.srs",
                "download_detour": "select",
                "update_interval": "1d"
            },
            {
                "tag": "geoip-cn",
                "type": "remote",
                "format": "binary",
                "url": "https://cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geoip/cn.srs",
                "download_detour": "select",
                "update_interval": "1d"
            }
        ],
    "auto_detect_interface": true,
    "final": "select",
    "rules": [
      {
      "inbound": "tun-in",
      "action": "sniff"
      },
      {
      "protocol": "dns",
      "action": "hijack-dns"
      },
      {
      "port": 443,
      "network": "udp",
      "action": "reject"
      },
      {
        "clash_mode": "Direct",
        "outbound": "direct"
      },
      {
        "clash_mode": "Global",
        "outbound": "select"
      },
      {
        "rule_set": "geoip-cn",
        "outbound": "direct"
      },
      {
        "rule_set": "geosite-cn",
        "outbound": "direct"
      },
      {
      "ip_is_private": true,
      "outbound": "direct"
      },
      {
        "rule_set": "geosite-geolocation-!cn",
        "outbound": "select"
      }
    ]
  },
    "ntp": {
    "enabled": true,
    "server": "time.apple.com",
    "server_port": 123,
    "interval": "30m",
    "detour": "direct"
  }
}
EOF

cat > clash_meta.yaml <<EOF
port: 7890
allow-lan: true
mode: rule
log-level: info
unified-delay: true
global-client-fingerprint: chrome
dns:
  enable: true
  listen: :53
  ipv6: true
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  default-nameserver: 
    - 223.5.5.5
    - 8.8.8.8
  nameserver:
    - https://dns.alidns.com/dns-query
    - https://doh.pub/dns-query
  fallback:
    - https://1.0.0.1/dns-query
    - tls://dns.google
  fallback-filter:
    geoip: true
    geoip-code: CN
    ipcidr:
      - 240.0.0.0/4

proxies:
- name: vless-reality-vision-$NAME               
  type: vless
  server: $IP                           
  port: $vless_port                                
  uuid: $UUID   
  network: tcp
  udp: true
  tls: true
  flow: xtls-rprx-vision
  servername: $reym                 
  reality-opts: 
    public-key: $public_key                      
  client-fingerprint: chrome                  

- name: vmess-ws-$NAME                         
  type: vmess
  server: $IP                       
  port: $vmess_port                                     
  uuid: $UUID       
  alterId: 0
  cipher: auto
  udp: true
  tls: false
  network: ws
  servername: www.bing.com                    
  ws-opts:
    path: "/$UUID-vm"                             
    headers:
      Host: www.bing.com                     

- name: hysteria2-$NAME                            
  type: hysteria2                                      
  server: $IP                               
  port: $hy2_port                                
  password: $UUID                          
  alpn:
    - h3
  sni: www.bing.com                               
  skip-cert-verify: true
  fast-open: true

- name: vmess-tls-argo-$NAME                         
  type: vmess
  server: icook.hk                        
  port: 8443                                     
  uuid: $UUID       
  alterId: 0
  cipher: auto
  udp: true
  tls: true
  network: ws
  servername: $argodomain                    
  ws-opts:
    path: "/$UUID-vm"                             
    headers:
      Host: $argodomain

- name: vmess-argo-$NAME                         
  type: vmess
  server: icook.hk                        
  port: 8880                                     
  uuid: $UUID       
  alterId: 0
  cipher: auto
  udp: true
  tls: false
  network: ws
  servername: $argodomain                   
  ws-opts:
    path: "/$UUID-vm"                             
    headers:
      Host: $argodomain 

proxy-groups:
- name: Balance
  type: load-balance
  url: https://www.gstatic.com/generate_204
  interval: 300
  strategy: round-robin
  proxies:
    - vless-reality-vision-$NAME                              
    - vmess-ws-$NAME
    - hysteria2-$NAME
    - vmess-tls-argo-$NAME
    - vmess-argo-$NAME

- name: Auto
  type: url-test
  url: https://www.gstatic.com/generate_204
  interval: 300
  tolerance: 50
  proxies:
    - vless-reality-vision-$NAME                              
    - vmess-ws-$NAME
    - hysteria2-$NAME
    - vmess-tls-argo-$NAME
    - vmess-argo-$NAME
    
- name: Select
  type: select
  proxies:
    - Balance                                         
    - Auto
    - DIRECT
    - vless-reality-vision-$NAME                              
    - vmess-ws-$NAME
    - hysteria2-$NAME
    - vmess-tls-argo-$NAME
    - vmess-argo-$NAME
rules:
  - GEOIP,LAN,DIRECT
  - GEOIP,CN,DIRECT
  - MATCH,Select
  
EOF

sleep 2
[ -d "$FILE_PATH" ] || mkdir -p "$FILE_PATH"
echo "$baseurl" > ${FILE_PATH}/${UUID}_v2sub.txt
cat clash_meta.yaml > ${FILE_PATH}/${UUID}_clashmeta.txt
cat sing_box.json > ${FILE_PATH}/${UUID}_singbox.txt
V2rayN_LINK="https://${USERNAME}.serv00.net/${UUID}_v2sub.txt"
Clashmeta_LINK="https://${USERNAME}.serv00.net/${UUID}_clashmeta.txt"
Singbox_LINK="https://${USERNAME}.serv00.net/${UUID}_singbox.txt"
allip=$(cat hy2ip.txt)
cat > list.txt <<EOF
=================================================================================================

当前客户端正在使用的IP：$IP
如默认节点IP被墙，可在客户端地址更换以下其他IP
$allip
-------------------------------------------------------------------------------------------------

一、Vless-reality分享链接如下：
$vl_link

注意：如果之前输入的reality域名为CF域名，将激活以下功能：
可应用在 https://github.com/yonggekkk/Cloudflare_vless_trojan 项目中创建CF vless/trojan 节点
1、Proxyip(带端口)信息如下：
方式一全局应用：设置变量名：proxyip    设置变量值：$IP:$vless_port  
方式二单节点应用：path路径改为：/pyip=$IP:$vless_port
CF节点的TLS可开可关
CF节点落地到CF网站的地区为：$IP所在地区

2、非标端口反代IP信息如下：
客户端优选IP地址为：$IP，端口：$vless_port
CF节点的TLS必须开启
CF节点落地到非CF网站的地区为：$IP所在地区

注：如果Serv00的IP被墙，proxyip依旧有效，但用于客户端地址与端口的非标端口反代IP将不可用
注：可能有大佬会扫Serv00的反代IP作为其共享IP库或者出售，请慎重将reality域名设置为CF域名
-------------------------------------------------------------------------------------------------


二、Vmess-ws分享链接三形态如下：

1、Vmess-ws主节点分享链接如下：
(该节点默认不支持CDN，如果设置为CDN回源(需域名)：客户端地址可自行修改优选IP/域名，7个80系端口随便换，被墙依旧能用！)
$vmws_link

Argo域名：${argodomain}
如果上面Argo临时域名未生成，以下 2 与 3 的Argo节点将不可用 (打开Argo固定/临时域名网页，显示HTTP ERROR 404说明正常可用)

2、Vmess-ws-tls_Argo分享链接如下： 
(该节点为CDN优选IP节点，客户端地址可自行修改优选IP/域名，6个443系端口随便换，被墙依旧能用！)
$vmatls_link

3、Vmess-ws_Argo分享链接如下：
(该节点为CDN优选IP节点，客户端地址可自行修改优选IP/域名，7个80系端口随便换，被墙依旧能用！)
$vma_link
-------------------------------------------------------------------------------------------------


三、HY2分享链接如下：
$hy2_link
-------------------------------------------------------------------------------------------------


四、以上五个节点的聚合通用订阅分享链接如下：
$V2rayN_LINK

以上五个节点聚合通用分享码：
$baseurl
-------------------------------------------------------------------------------------------------


五、查看Sing-box与Clash-meta的订阅配置文件，请进入主菜单选择4

Clash-meta订阅分享链接：
$Clashmeta_LINK

Sing-box订阅分享链接：
$Singbox_LINK
-------------------------------------------------------------------------------------------------

=================================================================================================

EOF
cat list.txt
sleep 2
rm -rf sb.log core tunnel.yml tunnel.json fake_useragent_0.2.0.json
}

showlist(){
if [[ -e $WORKDIR/list.txt ]]; then
green "查看节点及proxyip/非标端口反代ip信息"
cat $WORKDIR/list.txt
else
red "未安装脚本，请选择1进行安装" && exit
fi
}

showsbclash(){
if [[ -e $WORKDIR/sing_box.json ]]; then
green "Sing_box配置文件如下，可上传到订阅类客户端上使用："
yellow "其中Argo节点为CDN优选IP节点，server地址可自行修改优选IP/域名，被墙依旧能用！"
sleep 2
cat $WORKDIR/sing_box.json 
echo
echo
green "Clash_meta配置文件如下，可上传到订阅类客户端上使用："
yellow "其中Argo节点为CDN优选IP节点，server地址可自行修改优选IP/域名，被墙依旧能用！"
sleep 2
cat $WORKDIR/clash_meta.yaml
echo
else
red "未安装脚本，请选择1进行安装" && exit
fi
}

servkeep() {
#green "开始安装Cron进程保活"
curl -sSL https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/serv00keep.sh -o serv00keep.sh && chmod +x serv00keep.sh
sed -i '' -e "14s|''|'$UUID'|" serv00keep.sh
sed -i '' -e "17s|''|'$vless_port'|" serv00keep.sh
sed -i '' -e "18s|''|'$vmess_port'|" serv00keep.sh
sed -i '' -e "19s|''|'$hy2_port'|" serv00keep.sh
sed -i '' -e "20s|''|'$IP'|" serv00keep.sh
sed -i '' -e "21s|''|'$reym'|" serv00keep.sh
if [ ! -f "$WORKDIR/boot.log" ]; then
sed -i '' -e "15s|''|'${ARGO_DOMAIN}'|" serv00keep.sh
sed -i '' -e "16s|''|'${ARGO_AUTH}'|" serv00keep.sh
fi
#if ! crontab -l 2>/dev/null | grep -q 'serv00keep'; then
#if [ -f "$WORKDIR/boot.log" ] || grep -q "trycloudflare.com" "$WORKDIR/boot.log" 2>/dev/null; then
#check_process="! ps aux | grep '[c]onfig' > /dev/null || ! ps aux | grep [l]ocalhost > /dev/null"
#else
#check_process="! ps aux | grep '[c]onfig' > /dev/null || ! ps aux | grep [t]oken > /dev/null"
#fi
#(crontab -l 2>/dev/null; echo "*/10 * * * * if $check_process; then /bin/bash serv00keep.sh; fi") | crontab -
#fi
#green "安装完毕，默认每10分钟执行一次，运行 crontab -e 可自行修改保活执行间隔" && sleep 2
#echo
green "开始安装多功能主页，请稍等……"
keep_path="$HOME/domains/${snb}.${USERNAME}.serv00.net/public_nodejs"
[ -d "$keep_path" ] || mkdir -p "$keep_path"
curl -sL https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/app.js -o "$keep_path"/app.js
sed -i '' "15s/name/$snb/g" "$keep_path"/app.js
sed -i '' "38s/key/$UUID/g" "$keep_path"/app.js
sed -i '' "53s/name/$USERNAME/g" "$keep_path"/app.js
sed -i '' "53s/where/$snb/g" "$keep_path"/app.js
devil www del ${snb}.${USERNAME}.serv00.net > /dev/null 2>&1
devil www add ${USERNAME}.serv00.net php > /dev/null 2>&1
devil www add ${snb}.${USERNAME}.serv00.net nodejs /usr/local/bin/node18 > /dev/null 2>&1
ln -fs /usr/local/bin/node18 ~/bin/node > /dev/null 2>&1
ln -fs /usr/local/bin/npm18 ~/bin/npm > /dev/null 2>&1
mkdir -p ~/.npm-global
npm config set prefix '~/.npm-global'
echo 'export PATH=~/.npm-global/bin:~/bin:$PATH' >> $HOME/.bash_profile && source $HOME/.bash_profile
rm -rf $HOME/.npmrc > /dev/null 2>&1
cd "$keep_path"
npm install basic-auth express dotenv axios --silent > /dev/null 2>&1
rm $HOME/domains/${snb}.${USERNAME}.serv00.net/public_nodejs/public/index.html > /dev/null 2>&1
devil www restart ${snb}.${USERNAME}.serv00.net
curl -sk "http://${snb}.${USERNAME}.serv00.net/up" > /dev/null 2>&1
green "安装完毕，多功能主页地址：http://${snb}.${USERNAME}.serv00.net" && sleep 2
}

okip(){
    IP_LIST=($(devil vhost list | awk '/^[0-9]+/ {print $1}'))
    API_URL="https://status.eooce.com/api"
    IP=""
    THIRD_IP=${IP_LIST[2]}
    RESPONSE=$(curl -s --max-time 2 "${API_URL}/${THIRD_IP}")
    if [[ $(echo "$RESPONSE" | jq -r '.status') == "Available" ]]; then
        IP=$THIRD_IP
    else
        FIRST_IP=${IP_LIST[0]}
        RESPONSE=$(curl -s --max-time 2 "${API_URL}/${FIRST_IP}")
        
        if [[ $(echo "$RESPONSE" | jq -r '.status') == "Available" ]]; then
            IP=$FIRST_IP
        else
            IP=${IP_LIST[1]}
        fi
    fi
    echo "$IP"
    }

fastrun(){
if [[ -e $WORKDIR/config.json ]]; then
  COMMAND="sb"
  SCRIPT_PATH="$HOME/bin/$COMMAND"
  mkdir -p "$HOME/bin"
  curl -Ls https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/serv00.sh > "$SCRIPT_PATH"
  chmod +x "$SCRIPT_PATH"
  if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
      echo "export PATH=\"\$HOME/bin:\$PATH\"" >> "$HOME/.bashrc"
      source "$HOME/.bashrc"
  fi
  curl -sL https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sversion | awk -F "更新内容" '{print $1}' | head -n 1 > $WORKDIR/v
  else
  red "未安装脚本，请选择1进行安装" && exit
  fi
}

resservsb(){
if [[ -e $WORKDIR/config.json ]]; then
cd $WORKDIR
ps aux | grep '[r]un -c con' | awk '{print $2}' | xargs -r kill -9 > /dev/null 2>&1
sbb=$(cat sb.txt)
nohup ./"$sbb" run -c config.json >/dev/null 2>&1 &
sleep 3
if pgrep -x "$sbb" > /dev/null; then
green "$sbb 主进程重启成功"
else
red "$sbb 主进程重启失败"
fi
cd
else
red "未安装脚本，请选择1进行安装" && exit
fi
}

menu() {
   clear
   echo "============================================================"
   green "甬哥Github项目  ：github.com/yonggekkk"
   green "甬哥Blogger博客 ：ygkkk.blogspot.com"
   green "甬哥YouTube频道 ：www.youtube.com/@ygkkk"
   green "Serv00-sb-yg三协议共存：vless-reality、Vmess-ws(Argo)、Hy2"
   green "脚本快捷方式：sb"
   echo   "============================================================"
   green  "1. 一键安装 Serv00-sb-yg"
   echo   "------------------------------------------------------------"
   red    "2. 卸载删除 Serv00-sb-yg"
   echo   "------------------------------------------------------------"
   green  "3. 重启主进程"
   echo   "------------------------------------------------------------"
   green  "4. 更新脚本"
   echo   "------------------------------------------------------------"
   green  "5. 查看各节点分享/sing-box与clash订阅链接/CF节点proxyip"
   echo   "------------------------------------------------------------"
   green  "6. 查看sing-box与clash配置文件"
   echo   "------------------------------------------------------------"
   yellow "7. 删除所有端口并随机生成新端口"
   echo   "------------------------------------------------------------"
   yellow "8. 重置并清理所有服务进程(系统初始化)"
   echo   "------------------------------------------------------------"
   red    "0. 退出脚本"
   echo   "============================================================"
nb=$(echo "$HOSTNAME" | cut -d '.' -f 1 | tr -d 's')
ym=("$HOSTNAME" "cache$nb.serv00.com" "web$nb.serv00.com")
rm -rf $WORKDIR/ip.txt $WORKDIR/hy2ip.txt
dig @8.8.8.8 +time=5 +short "web$nb.serv00.com" >> $WORKDIR/hy2ip.txt
dig @8.8.8.8 +time=5 +short "$HOSTNAME" >> $WORKDIR/hy2ip.txt
dig @8.8.8.8 +time=5 +short "cache$nb.serv00.com" >> $WORKDIR/hy2ip.txt
for host in "${ym[@]}"; do
response=$(curl -sL --connect-timeout 5 --max-time 7 "https://ss.serv0.us.kg/api/getip?host=$host")
if [[ "$response" =~ ^$|unknown|not|error ]]; then
dig @8.8.8.8 +time=5 +short $host >> $WORKDIR/ip.txt
sleep 1 
else
echo "$response" | while IFS='|' read -r ip status; do
if [[ $status == "Accessible" ]]; then
echo "$ip: 可用"  >> $WORKDIR/ip.txt
else
echo "$ip: 被墙 (Argo与CDN回源节点、proxyip依旧有效)"  >> $WORKDIR/ip.txt
fi	
done
fi
done
curl --max-time 5 -sL ip.sb >/dev/null 2>&1 && state="正常可用" || state="可能宕机了，慢慢等官方修复吧"
green "Serv00服务器名称及状态：${snb} ${state}"
echo
green "当前可选择的IP如下："
cat $WORKDIR/ip.txt
if [[ -e $WORKDIR/config.json ]]; then
echo "如默认节点IP被墙，可在客户端地址更换以上任意一个显示可用的IP"
fi
echo
portlist=$(devil port list | grep -E '^[0-9]+[[:space:]]+[a-zA-Z]+' | sed 's/^[[:space:]]*//')
if [[ -n $portlist ]]; then
green "已设置的端口如下："
echo -e "$portlist"
else
yellow "未设置端口！请先选择 7 随机生成端口，再选择 1 安装脚本"
fi
echo
insV=$(cat $WORKDIR/v 2>/dev/null)
latestV=$(curl -sL https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sversion | awk -F "更新内容" '{print $1}' | head -n 1)
if [ -f $WORKDIR/v ]; then
if [ "$insV" = "$latestV" ]; then
echo -e "当前 Serv00-sb-yg 脚本最新版：${purple}${insV}${re} (已安装)"
else
echo -e "当前 Serv00-sb-yg 脚本版本号：${purple}${insV}${re}"
echo -e "检测到最新 Serv00-sb-yg 脚本版本号：${yellow}${latestV}${re} (可选择4进行更新)"
echo -e "${yellow}$(curl -sL https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sversion)${re}"
fi
echo -e "========================================================="
ps aux | grep '[r]un -c con' > /dev/null && green "主进程运行正常" || yellow "主进程启动失败，请检测节点是否可用"
echo
if [ -f "$WORKDIR/boot.log" ] && grep -q "trycloudflare.com" "$WORKDIR/boot.log" 2>/dev/null && ps aux | grep '[t]unnel --u' > /dev/null; then
argosl=$(cat "$WORKDIR/boot.log" 2>/dev/null | grep -a trycloudflare.com | awk 'NR==2{print}' | awk -F// '{print $2}' | awk '{print $1}')
checkhttp=$(curl -o /dev/null -s -w "%{http_code}\n" "https://$argosl")
[ "$checkhttp" -eq 404 ] && check="域名有效" || check="域名可能无效"
green "Argo临时域名：$argosl  $check"
fi
if [ -f "$WORKDIR/boot.log" ] && ! ps aux | grep '[t]unnel --u' > /dev/null; then
yellow "Argo临时域名暂时不存在，保活过程中会自动恢复"
fi
if ps aux | grep '[t]unnel --n' > /dev/null; then
argogd=$(cat $WORKDIR/gdym.log 2>/dev/null)
checkhttp=$(curl --max-time 2 -o /dev/null -s -w "%{http_code}\n" "https://$argogd")
[ "$checkhttp" -eq 404 ] && check="域名有效" || check="域名可能失效"
green "Argo固定域名：$argogd $check"
fi
if [ ! -f "$WORKDIR/boot.log" ] && ! ps aux | grep '[t]unnel --n' > /dev/null; then
yellow "Argo固定域名：$(cat $WORKDIR/gdym.log 2>/dev/null)，启动失败，请检查相关参数是否输入有误"
fi
echo
green "多功能主页如下，支持网页保活、网页重启、网页节点查询"
purple "http://${snb}.${USERNAME}.serv00.net"
#if ! crontab -l 2>/dev/null | grep -q 'serv00keep'; then
#if [ -f "$WORKDIR/boot.log" ] || grep -q "trycloudflare.com" "$WORKDIR/boot.log" 2>/dev/null; then
#check_process="! ps aux | grep '[c]onfig' > /dev/null || ! ps aux | grep [l]ocalhost > /dev/null"
#else
#check_process="! ps aux | grep '[c]onfig' > /dev/null || ! ps aux | grep [t]oken > /dev/null"
#fi
#(crontab -l 2>/dev/null; echo "*/2 * * * * if $check_process; then /bin/bash serv00keep.sh; fi") | crontab -
#purple "发现Serv00开大招了，Cron保活被重置清空了"
#purple "目前Cron保活已修复成功。打开 http://${USERNAME}.${USERNAME}.serv00.net/up 也可实时保活"
#purple "主进程与Argo进程启动中…………1分钟后可再次进入脚本查看"
#else
#green "Cron保活运行正常。打开 http://${USERNAME}.${USERNAME}.serv00.net/up 也可实时保活"
#fi
else
echo -e "当前 Serv00-sb-yg 脚本版本号：${purple}${latestV}${re}"
yellow "未安装 Serv00-sb-yg 脚本！请选择 1 安装"
fi
#curl -sSL https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/serv00.sh -o serv00.sh && chmod +x serv00.sh
   echo -e "========================================================="
   reading "请输入选择【0-8】: " choice
   echo
    case "${choice}" in
        1) install_singbox ;;
        2) uninstall_singbox ;; 
	3) resservsb ;;
	4) fastrun && green "脚本已更新成功" && sleep 2 && sb ;; 
        5) showlist ;;
	6) showsbclash ;;
        7) resallport ;;
        8) kill_all_tasks ;;
	0) exit 0 ;;
        *) red "无效的选项，请输入 0 到 8" ;;
    esac
}
menu
