#!/bin/bash
export LANG=en_US.UTF-8
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;36m'
bblue='\033[0;34m'
plain='\033[0m'
red(){ echo -e "\033[31m\033[01m$1\033[0m";}
green(){ echo -e "\033[32m\033[01m$1\033[0m";}
yellow(){ echo -e "\033[33m\033[01m$1\033[0m";}
blue(){ echo -e "\033[36m\033[01m$1\033[0m";}
white(){ echo -e "\033[37m\033[01m$1\033[0m";}
readp(){ read -p "$(yellow "$1")" $2;}
[[ $EUID -ne 0 ]] && yellow "请以root模式运行脚本" && exit
#[[ -e /etc/hosts ]] && grep -qE '^ *172.65.251.78 gitlab.com' /etc/hosts || echo -e '\n172.65.251.78 gitlab.com' >> /etc/hosts
if [[ -f /etc/redhat-release ]]; then
release="Centos"
elif cat /etc/issue | grep -q -E -i "alpine"; then
release="alpine"
elif cat /etc/issue | grep -q -E -i "debian"; then
release="Debian"
elif cat /etc/issue | grep -q -E -i "ubuntu"; then
release="Ubuntu"
elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
release="Centos"
elif cat /proc/version | grep -q -E -i "debian"; then
release="Debian"
elif cat /proc/version | grep -q -E -i "ubuntu"; then
release="Ubuntu"
elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
release="Centos"
else 
red "脚本不支持当前的系统，请选择使用Ubuntu,Debian,Centos系统。" && exit
fi
export sbfiles="/etc/s-box/sb10.json /etc/s-box/sb11.json /etc/s-box/sb.json"
export sbnh=$(/etc/s-box/sing-box version 2>/dev/null | awk '/version/{print $NF}' 2>/dev/null | cut -d '.' -f 1,2)
vsid=$(grep -i version_id /etc/os-release | cut -d \" -f2 | cut -d . -f1)
op=$(cat /etc/redhat-release 2>/dev/null || cat /etc/os-release 2>/dev/null | grep -i pretty_name | cut -d \" -f2)
#if [[ $(echo "$op" | grep -i -E "arch|alpine") ]]; then
if [[ $(echo "$op" | grep -i -E "arch") ]]; then
red "脚本不支持当前的 $op 系统，请选择使用Ubuntu,Debian,Centos系统。" && exit
fi
version=$(uname -r | cut -d "-" -f1)
[[ -z $(systemd-detect-virt 2>/dev/null) ]] && vi=$(virt-what 2>/dev/null) || vi=$(systemd-detect-virt 2>/dev/null)
case $(uname -m) in
armv7l) cpu=armv7;;
aarch64) cpu=arm64;;
x86_64) cpu=amd64;;
*) red "目前脚本不支持$(uname -m)架构" && exit;;
esac
if [[ -n $(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk -F ' ' '{print $3}') ]]; then
bbr=`sysctl net.ipv4.tcp_congestion_control | awk -F ' ' '{print $3}'`
elif [[ -n $(ping 10.0.0.2 -c 2 | grep ttl) ]]; then
bbr="Openvz版bbr-plus"
else
bbr="Openvz/Lxc"
fi
hostname=$(hostname)

if [ ! -f sbyg_update ]; then
green "首次安装Sing-box-yg脚本必要的依赖……"
if command -v apk >/dev/null 2>&1; then
apk update
apk add bash libc6-compat jq openssl procps busybox-extras iproute2 iputils coreutils expect git socat iptables grep tar tzdata util-linux
apk add virt-what
else
if [[ $release = Centos && ${vsid} =~ 8 ]]; then
cd /etc/yum.repos.d/ && mkdir backup && mv *repo backup/ 
curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-8.repo
sed -i -e "s|mirrors.cloud.aliyuncs.com|mirrors.aliyun.com|g " /etc/yum.repos.d/CentOS-*
sed -i -e "s|releasever|releasever-stream|g" /etc/yum.repos.d/CentOS-*
yum clean all && yum makecache
cd
fi
if [ -x "$(command -v apt-get)" ]; then
apt update -y
apt install jq cron socat busybox iptables-persistent coreutils util-linux -y
elif [ -x "$(command -v yum)" ]; then
yum update -y && yum install epel-release -y
yum install jq socat busybox coreutils util-linux -y
elif [ -x "$(command -v dnf)" ]; then
dnf update -y
dnf install jq socat busybox coreutils util-linux -y
fi
if [ -x "$(command -v yum)" ] || [ -x "$(command -v dnf)" ]; then
if [ -x "$(command -v yum)" ]; then
yum install -y cronie iptables-services
elif [ -x "$(command -v dnf)" ]; then
dnf install -y cronie iptables-services
fi
systemctl enable iptables >/dev/null 2>&1
systemctl start iptables >/dev/null 2>&1
fi
if [[ -z $vi ]]; then
apt install iputils-ping iproute2 systemctl -y
fi

packages=("curl" "openssl" "iptables" "tar" "expect" "wget" "xxd" "python3" "qrencode" "git")
inspackages=("curl" "openssl" "iptables" "tar" "expect" "wget" "xxd" "python3" "qrencode" "git")
for i in "${!packages[@]}"; do
package="${packages[$i]}"
inspackage="${inspackages[$i]}"
if ! command -v "$package" &> /dev/null; then
if [ -x "$(command -v apt-get)" ]; then
apt-get install -y "$inspackage"
elif [ -x "$(command -v yum)" ]; then
yum install -y "$inspackage"
elif [ -x "$(command -v dnf)" ]; then
dnf install -y "$inspackage"
fi
fi
done
fi
touch sbyg_update
fi

if [[ $vi = openvz ]]; then
TUN=$(cat /dev/net/tun 2>&1)
if [[ ! $TUN =~ 'in bad state' ]] && [[ ! $TUN =~ '处于错误状态' ]] && [[ ! $TUN =~ 'Die Dateizugriffsnummer ist in schlechter Verfassung' ]]; then 
red "检测到未开启TUN，现尝试添加TUN支持" && sleep 4
cd /dev && mkdir net && mknod net/tun c 10 200 && chmod 0666 net/tun
TUN=$(cat /dev/net/tun 2>&1)
if [[ ! $TUN =~ 'in bad state' ]] && [[ ! $TUN =~ '处于错误状态' ]] && [[ ! $TUN =~ 'Die Dateizugriffsnummer ist in schlechter Verfassung' ]]; then 
green "添加TUN支持失败，建议与VPS厂商沟通或后台设置开启" && exit
else
echo '#!/bin/bash' > /root/tun.sh && echo 'cd /dev && mkdir net && mknod net/tun c 10 200 && chmod 0666 net/tun' >> /root/tun.sh && chmod +x /root/tun.sh
grep -qE "^ *@reboot root bash /root/tun.sh >/dev/null 2>&1" /etc/crontab || echo "@reboot root bash /root/tun.sh >/dev/null 2>&1" >> /etc/crontab
green "TUN守护功能已启动"
fi
fi
fi
v4v6(){
v4=$(curl -s4m5 icanhazip.com -k)
v6=$(curl -s6m5 icanhazip.com -k)
v4dq=$(curl -s4m5 -k https://ip.fm | sed -n 's/.*Location: //p' 2>/dev/null)
v6dq=$(curl -s6m5 -k https://ip.fm | sed -n 's/.*Location: //p' 2>/dev/null)
}
warpcheck(){
wgcfv6=$(curl -s6m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
wgcfv4=$(curl -s4m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
}

v6(){
v4orv6(){
if [ -z "$(curl -s4m5 icanhazip.com -k)" ]; then
echo
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
yellow "检测到 纯IPV6 VPS，添加NAT64"
echo -e "nameserver 2a00:1098:2b::1\nnameserver 2a00:1098:2c::1" > /etc/resolv.conf
ipv=prefer_ipv6
else
ipv=prefer_ipv4
fi
if [ -n "$(curl -s6m5 icanhazip.com -k)" ]; then
endip="2606:4700:d0::a29f:c001"
else
endip="162.159.192.1"
fi
}
warpcheck
if [[ ! $wgcfv4 =~ on|plus && ! $wgcfv6 =~ on|plus ]]; then
v4orv6
else
systemctl stop wg-quick@wgcf >/dev/null 2>&1
kill -15 $(pgrep warp-go) >/dev/null 2>&1 && sleep 2
v4orv6
systemctl start wg-quick@wgcf >/dev/null 2>&1
systemctl restart warp-go >/dev/null 2>&1
systemctl enable warp-go >/dev/null 2>&1
systemctl start warp-go >/dev/null 2>&1
fi
}

close(){
systemctl stop firewalld.service >/dev/null 2>&1
systemctl disable firewalld.service >/dev/null 2>&1
setenforce 0 >/dev/null 2>&1
ufw disable >/dev/null 2>&1
iptables -P INPUT ACCEPT >/dev/null 2>&1
iptables -P FORWARD ACCEPT >/dev/null 2>&1
iptables -P OUTPUT ACCEPT >/dev/null 2>&1
iptables -t mangle -F >/dev/null 2>&1
iptables -F >/dev/null 2>&1
iptables -X >/dev/null 2>&1
netfilter-persistent save >/dev/null 2>&1
if [[ -n $(apachectl -v 2>/dev/null) ]]; then
systemctl stop httpd.service >/dev/null 2>&1
systemctl disable httpd.service >/dev/null 2>&1
service apache2 stop >/dev/null 2>&1
systemctl disable apache2 >/dev/null 2>&1
fi
sleep 1
green "执行开放端口，关闭防火墙完毕"
}

openyn(){
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
readp "是否开放端口，关闭防火墙？\n1、是，执行 (回车默认)\n2、否，跳过！自行处理\n请选择【1-2】：" action
if [[ -z $action ]] || [[ "$action" = "1" ]]; then
close
elif [[ "$action" = "2" ]]; then
echo
else
red "输入错误,请重新选择" && openyn
fi
}

inssb(){
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green "使用哪个内核版本？"
yellow "1：使用目前最新正式版内核 (回车默认)"
yellow "2：使用之前1.10.7正式版内核"
readp "请选择【1-2】：" menu
if [ -z "$menu" ] || [ "$menu" = "1" ] ; then
sbcore=$(curl -Ls https://github.com/SagerNet/sing-box/releases/latest | grep -oP 'tag/v\K[0-9.]+' | head -n 1)
else
sbcore='1.10.7'
fi
sbname="sing-box-$sbcore-linux-$cpu"
curl -L -o /etc/s-box/sing-box.tar.gz  -# --retry 2 https://github.com/SagerNet/sing-box/releases/download/v$sbcore/$sbname.tar.gz
if [[ -f '/etc/s-box/sing-box.tar.gz' ]]; then
tar xzf /etc/s-box/sing-box.tar.gz -C /etc/s-box
mv /etc/s-box/$sbname/sing-box /etc/s-box
rm -rf /etc/s-box/{sing-box.tar.gz,$sbname}
if [[ -f '/etc/s-box/sing-box' ]]; then
chown root:root /etc/s-box/sing-box
chmod +x /etc/s-box/sing-box
blue "成功安装 Sing-box 内核版本：$(/etc/s-box/sing-box version | awk '/version/{print $NF}')"
sbnh=$(/etc/s-box/sing-box version 2>/dev/null | awk '/version/{print $NF}' 2>/dev/null | cut -d '.' -f 1,2)
else
red "下载 Sing-box 内核不完整，安装失败，请再运行安装一次" && exit
fi
else
red "下载 Sing-box 内核失败，请再运行安装一次，并检测VPS的网络是否可以访问Github" && exit
fi
}

inscertificate(){
ymzs(){
ym_vl_re=apple.com
echo
blue "Vless-reality的SNI域名默认为 apple.com"
tlsyn=true
ym_vm_ws=$(cat /root/ygkkkca/ca.log 2>/dev/null)
certificatec_vmess_ws='/root/ygkkkca/cert.crt'
certificatep_vmess_ws='/root/ygkkkca/private.key'
certificatec_hy2='/root/ygkkkca/cert.crt'
certificatep_hy2='/root/ygkkkca/private.key'
certificatec_tuic='/root/ygkkkca/cert.crt'
certificatep_tuic='/root/ygkkkca/private.key'
certificatec_an='/root/ygkkkca/cert.crt'
certificatep_an='/root/ygkkkca/private.key'
}

zqzs(){
ym_vl_re=apple.com
echo
blue "Vless-reality的SNI域名默认为 apple.com"
tlsyn=false
ym_vm_ws=www.bing.com
certificatec_vmess_ws='/etc/s-box/cert.pem'
certificatep_vmess_ws='/etc/s-box/private.key'
certificatec_hy2='/etc/s-box/cert.pem'
certificatep_hy2='/etc/s-box/private.key'
certificatec_tuic='/etc/s-box/cert.pem'
certificatep_tuic='/etc/s-box/private.key'
certificatec_an='/etc/s-box/cert.pem'
certificatep_an='/etc/s-box/private.key'
}

red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green "二、生成并设置相关证书"
echo
blue "自动生成bing自签证书中……" && sleep 2
openssl ecparam -genkey -name prime256v1 -out /etc/s-box/private.key
openssl req -new -x509 -days 36500 -key /etc/s-box/private.key -out /etc/s-box/cert.pem -subj "/CN=www.bing.com"
echo
if [[ -f /etc/s-box/cert.pem ]]; then
blue "生成bing自签证书成功"
else
red "生成bing自签证书失败" && exit
fi
echo
if [[ -f /root/ygkkkca/cert.crt && -f /root/ygkkkca/private.key && -s /root/ygkkkca/cert.crt && -s /root/ygkkkca/private.key ]]; then
yellow "经检测，之前已使用Acme-yg脚本申请过Acme域名证书：$(cat /root/ygkkkca/ca.log) "
green "是否使用 $(cat /root/ygkkkca/ca.log) 域名证书？"
yellow "1：否！使用自签的证书 (回车默认)"
yellow "2：是！使用 $(cat /root/ygkkkca/ca.log) 域名证书"
readp "请选择【1-2】：" menu
if [ -z "$menu" ] || [ "$menu" = "1" ] ; then
zqzs
else
ymzs
fi
else
green "如果你有解析完成的域名，是否申请一个Acme域名证书？"
yellow "1：否！继续使用自签的证书 (回车默认)"
yellow "2：是！使用Acme-yg脚本申请Acme证书 (支持常规80端口模式与Dns API模式)"
readp "请选择【1-2】：" menu
if [ -z "$menu" ] || [ "$menu" = "1" ] ; then
zqzs
else
bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/acme-yg/main/acme.sh)
if [[ ! -f /root/ygkkkca/cert.crt && ! -f /root/ygkkkca/private.key && ! -s /root/ygkkkca/cert.crt && ! -s /root/ygkkkca/private.key ]]; then
red "Acme证书申请失败，继续使用自签证书" 
zqzs
else
ymzs
fi
fi
fi
}

chooseport(){
if [[ -z $port ]]; then
port=$(shuf -i 10000-65535 -n 1)
until [[ -z $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") && -z $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]] 
do
[[ -n $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") || -n $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]] && yellow "\n端口被占用，请重新输入端口" && readp "自定义端口:" port
done
else
until [[ -z $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") && -z $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]]
do
[[ -n $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") || -n $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]] && yellow "\n端口被占用，请重新输入端口" && readp "自定义端口:" port
done
fi
blue "确认的端口：$port" && sleep 2
}

vlport(){
readp "\n设置Vless-reality端口 (回车跳过为10000-65535之间的随机端口)：" port
chooseport
port_vl_re=$port
}
vmport(){
readp "\n设置Vmess-ws端口 (回车跳过为10000-65535之间的随机端口)：" port
chooseport
port_vm_ws=$port
}
hy2port(){
readp "\n设置Hysteria2主端口 (回车跳过为10000-65535之间的随机端口)：" port
chooseport
port_hy2=$port
}
tu5port(){
readp "\n设置Tuic5主端口 (回车跳过为10000-65535之间的随机端口)：" port
chooseport
port_tu=$port
}
anport(){
readp "\n设置Anytls主端口，最新内核时可用 (回车跳过为10000-65535之间的随机端口)：" port
chooseport
port_an=$port
}

insport(){
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green "三、设置各个协议端口"
yellow "1：自动生成每个协议的随机端口 (10000-65535范围内)，回车默认。请确保VPS后台已开放所有端口"
yellow "2：自定义每个协议端口。请确保VPS后台已开放指定的端口"
readp "请输入【1-2】：" port
if [ -z "$port" ] || [ "$port" = "1" ] ; then
ports=()
for i in {1..5}; do
while true; do
port=$(shuf -i 10000-65535 -n 1)
if ! [[ " ${ports[@]} " =~ " $port " ]] && \
[[ -z $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]] && \
[[ -z $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]]; then
ports+=($port)
break
fi
done
done
port_vm_ws=${ports[0]}
port_vl_re=${ports[1]}
port_hy2=${ports[2]}
port_tu=${ports[3]}
port_an=${ports[4]}
if [[ $tlsyn == "true" ]]; then
numbers=("2053" "2083" "2087" "2096" "8443")
else
numbers=("8080" "8880" "2052" "2082" "2086" "2095")
fi
port_vm_ws=${numbers[$RANDOM % ${#numbers[@]}]}
until [[ -z $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port_vm_ws") ]]
do
if [[ $tlsyn == "true" ]]; then
numbers=("2053" "2083" "2087" "2096" "8443")
else
numbers=("8080" "8880" "2052" "2082" "2086" "2095")
fi
port_vm_ws=${numbers[$RANDOM % ${#numbers[@]}]}
done
echo
blue "根据Vmess-ws协议是否启用TLS，随机指定支持CDN优选IP的标准端口：$port_vm_ws"
else
vlport && vmport && hy2port && tu5port
if [[ "$sbnh" != "1.10" ]]; then
anport
fi
fi
echo
blue "各协议端口确认如下"
blue "Vless-reality端口：$port_vl_re"
blue "Vmess-ws端口：$port_vm_ws"
blue "Hysteria-2端口：$port_hy2"
blue "Tuic-v5端口：$port_tu"
if [[ "$sbnh" != "1.10" ]]; then
blue "Anytls端口：$port_an"
fi
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green "四、自动生成各个协议统一的uuid (密码)"
uuid=$(/etc/s-box/sing-box generate uuid)
blue "已确认uuid (密码)：${uuid}"
blue "已确认Vmess的path路径：${uuid}-vm"
}

inssbjsonser(){
cat > /etc/s-box/sb10.json <<EOF
{
"log": {
    "disabled": false,
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "vless",
      "sniff": true,
      "sniff_override_destination": true,
      "tag": "vless-sb",
      "listen": "::",
      "listen_port": ${port_vl_re},
      "users": [
        {
          "uuid": "${uuid}",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "${ym_vl_re}",
          "reality": {
          "enabled": true,
          "handshake": {
            "server": "${ym_vl_re}",
            "server_port": 443
          },
          "private_key": "$private_key",
          "short_id": ["$short_id"]
        }
      }
    },
{
        "type": "vmess",
        "sniff": true,
        "sniff_override_destination": true,
        "tag": "vmess-sb",
        "listen": "::",
        "listen_port": ${port_vm_ws},
        "users": [
            {
                "uuid": "${uuid}",
                "alterId": 0
            }
        ],
        "transport": {
            "type": "ws",
            "path": "${uuid}-vm",
            "max_early_data":2048,
            "early_data_header_name": "Sec-WebSocket-Protocol"    
        },
        "tls":{
                "enabled": ${tlsyn},
                "server_name": "${ym_vm_ws}",
                "certificate_path": "$certificatec_vmess_ws",
                "key_path": "$certificatep_vmess_ws"
            }
    }, 
    {
        "type": "hysteria2",
        "sniff": true,
        "sniff_override_destination": true,
        "tag": "hy2-sb",
        "listen": "::",
        "listen_port": ${port_hy2},
        "users": [
            {
                "password": "${uuid}"
            }
        ],
        "ignore_client_bandwidth":false,
        "tls": {
            "enabled": true,
            "alpn": [
                "h3"
            ],
            "certificate_path": "$certificatec_hy2",
            "key_path": "$certificatep_hy2"
        }
    },
        {
            "type":"tuic",
            "sniff": true,
            "sniff_override_destination": true,
            "tag": "tuic5-sb",
            "listen": "::",
            "listen_port": ${port_tu},
            "users": [
                {
                    "uuid": "${uuid}",
                    "password": "${uuid}"
                }
            ],
            "congestion_control": "bbr",
            "tls":{
                "enabled": true,
                "alpn": [
                    "h3"
                ],
                "certificate_path": "$certificatec_tuic",
                "key_path": "$certificatep_tuic"
            }
        }
],
"outbounds": [
{
"type":"direct",
"tag":"direct",
"domain_strategy": "$ipv"
},
{
"type":"direct",
"tag": "vps-outbound-v4", 
"domain_strategy":"prefer_ipv4"
},
{
"type":"direct",
"tag": "vps-outbound-v6",
"domain_strategy":"prefer_ipv6"
},
{
"type": "socks",
"tag": "socks-out",
"server": "127.0.0.1",
"server_port": 40000,
"version": "5"
},
{
"type":"direct",
"tag":"socks-IPv4-out",
"detour":"socks-out",
"domain_strategy":"prefer_ipv4"
},
{
"type":"direct",
"tag":"socks-IPv6-out",
"detour":"socks-out",
"domain_strategy":"prefer_ipv6"
},
{
"type":"direct",
"tag":"warp-IPv4-out",
"detour":"wireguard-out",
"domain_strategy":"prefer_ipv4"
},
{
"type":"direct",
"tag":"warp-IPv6-out",
"detour":"wireguard-out",
"domain_strategy":"prefer_ipv6"
},
{
"type":"wireguard",
"tag":"wireguard-out",
"server":"$endip",
"server_port":2408,
"local_address":[
"172.16.0.2/32",
"${v6}/128"
],
"private_key":"$pvk",
"peer_public_key":"bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
"reserved":$res
},
{
"type": "block",
"tag": "block"
}
],
"route":{
"rules":[
{
"protocol": [
"quic",
"stun"
],
"outbound": "block"
},
{
"outbound":"warp-IPv4-out",
"domain_suffix": [
"yg_kkk"
]
,"geosite": [
"yg_kkk"
]
},
{
"outbound":"warp-IPv6-out",
"domain_suffix": [
"yg_kkk"
]
,"geosite": [
"yg_kkk"
]
},
{
"outbound":"socks-IPv4-out",
"domain_suffix": [
"yg_kkk"
]
,"geosite": [
"yg_kkk"
]
},
{
"outbound":"socks-IPv6-out",
"domain_suffix": [
"yg_kkk"
]
,"geosite": [
"yg_kkk"
]
},
{
"outbound":"vps-outbound-v4",
"domain_suffix": [
"yg_kkk"
]
,"geosite": [
"yg_kkk"
]
},
{
"outbound":"vps-outbound-v6",
"domain_suffix": [
"yg_kkk"
]
,"geosite": [
"yg_kkk"
]
},
{
"outbound": "direct",
"network": "udp,tcp"
}
]
}
}
EOF

cat > /etc/s-box/sb11.json <<EOF
{
"log": {
    "disabled": false,
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "vless",

      
      "tag": "vless-sb",
      "listen": "::",
      "listen_port": ${port_vl_re},
      "users": [
        {
          "uuid": "${uuid}",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "${ym_vl_re}",
          "reality": {
          "enabled": true,
          "handshake": {
            "server": "${ym_vl_re}",
            "server_port": 443
          },
          "private_key": "$private_key",
          "short_id": ["$short_id"]
        }
      }
    },
{
        "type": "vmess",

 
        "tag": "vmess-sb",
        "listen": "::",
        "listen_port": ${port_vm_ws},
        "users": [
            {
                "uuid": "${uuid}",
                "alterId": 0
            }
        ],
        "transport": {
            "type": "ws",
            "path": "${uuid}-vm",
            "max_early_data":2048,
            "early_data_header_name": "Sec-WebSocket-Protocol"    
        },
        "tls":{
                "enabled": ${tlsyn},
                "server_name": "${ym_vm_ws}",
                "certificate_path": "$certificatec_vmess_ws",
                "key_path": "$certificatep_vmess_ws"
            }
    }, 
    {
        "type": "hysteria2",

 
        "tag": "hy2-sb",
        "listen": "::",
        "listen_port": ${port_hy2},
        "users": [
            {
                "password": "${uuid}"
            }
        ],
        "ignore_client_bandwidth":false,
        "tls": {
            "enabled": true,
            "alpn": [
                "h3"
            ],
            "certificate_path": "$certificatec_hy2",
            "key_path": "$certificatep_hy2"
        }
    },
        {
            "type":"tuic",

     
            "tag": "tuic5-sb",
            "listen": "::",
            "listen_port": ${port_tu},
            "users": [
                {
                    "uuid": "${uuid}",
                    "password": "${uuid}"
                }
            ],
            "congestion_control": "bbr",
            "tls":{
                "enabled": true,
                "alpn": [
                    "h3"
                ],
                "certificate_path": "$certificatec_tuic",
                "key_path": "$certificatep_tuic"
            }
        },
        {
            "type":"anytls",
            "tag":"anytls-sb",
            "listen":"::",
            "listen_port":${port_an},
            "users":[
                {
                  "password":"${uuid}"
                }
            ],
            "padding_scheme":[],
            "tls":{
                "enabled": true,
                "certificate_path": "$certificatec_an",
                "key_path": "$certificatep_an"
            }
        }
],
"endpoints":[
{
"type":"wireguard",
"tag":"warp-out",
"address":[
"172.16.0.2/32",
"${v6}/128"
],
"private_key":"$pvk",
"peers": [
{
"address": "$endip",
"port":2408,
"public_key":"bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
"allowed_ips": [
"0.0.0.0/0",
"::/0"
],
"reserved":$res
}
]
}
],









"outbounds": [
{
"type":"direct",
"tag":"direct"
},
{
"type": "socks",
"tag": "socks-out",
"server": "127.0.0.1",
"server_port": 40000,
"version": "5"
}
],
"route":{
"rules":[
{
 "action": "sniff"
},
{
"action": "resolve",
"domain_suffix":[
"yg_kkk"
],
"strategy": "prefer_ipv4"
},
{
"action": "resolve",
"domain_suffix":[
"yg_kkk"
],
"strategy": "prefer_ipv6"
},
{
"domain_suffix":[
"yg_kkk"
],
"outbound":"socks-out"
},
{
"domain_suffix":[
"yg_kkk"
],
"outbound":"warp-out"
},
{
"outbound": "direct",
"network": "udp,tcp"
}
]
}
}
EOF
[[ "$sbnh" == "1.10" ]] && num=10 || num=11
cp /etc/s-box/sb${num}.json /etc/s-box/sb.json
}

sbservice(){
if command -v apk >/dev/null 2>&1; then
echo '#!/sbin/openrc-run
description="sing-box service"
command="/etc/s-box/sing-box"
command_args="run -c /etc/s-box/sb.json"
command_background=true
pidfile="/var/run/sing-box.pid"' > /etc/init.d/sing-box
chmod +x /etc/init.d/sing-box
rc-update add sing-box default
rc-service sing-box start
else
cat > /etc/systemd/system/sing-box.service <<EOF
[Unit]
After=network.target nss-lookup.target
[Service]
User=root
WorkingDirectory=/root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
ExecStart=/etc/s-box/sing-box run -c /etc/s-box/sb.json
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable sing-box >/dev/null 2>&1
systemctl start sing-box
systemctl restart sing-box
fi
}

ipuuid(){
if command -v apk >/dev/null 2>&1; then
status_cmd="rc-service sing-box status"
status_pattern="started"
else
status_cmd="systemctl is-active sing-box"
status_pattern="active"
fi
if [[ -n $($status_cmd 2>/dev/null | grep -w "$status_pattern") && -f '/etc/s-box/sb.json' ]]; then
v4v6
if [[ -n $v4 && -n $v6 ]]; then
green "调整IPv4/IPV6配置输出"
yellow "1：刷新本地IP，使用IPV4配置输出 (回车默认) "
yellow "2：刷新本地IP，使用IPV6配置输出"
readp "请选择【1-2】：" menu
if [ -z "$menu" ] || [ "$menu" = "1" ]; then
server_ip="$v4"
echo "$server_ip" > /etc/s-box/server_ip.log
server_ipcl="$v4"
echo "$server_ipcl" > /etc/s-box/server_ipcl.log
else
server_ip="[$v6]"
echo "$server_ip" > /etc/s-box/server_ip.log
server_ipcl="$v6"
echo "$server_ipcl" > /etc/s-box/server_ipcl.log
fi
else
yellow "VPS并不是双栈VPS，不支持IP配置输出的切换"
serip=$(curl -s4m5 icanhazip.com -k || curl -s6m5 icanhazip.com -k)
if [[ "$serip" =~ : ]]; then
server_ip="[$serip]"
echo "$server_ip" > /etc/s-box/server_ip.log
server_ipcl="$serip"
echo "$server_ipcl" > /etc/s-box/server_ipcl.log
else
server_ip="$serip"
echo "$server_ip" > /etc/s-box/server_ip.log
server_ipcl="$serip"
echo "$server_ipcl" > /etc/s-box/server_ipcl.log
fi
fi
else
red "Sing-box服务未运行" && exit
fi
}

wgcfgo(){
warpcheck
if [[ ! $wgcfv4 =~ on|plus && ! $wgcfv6 =~ on|plus ]]; then
ipuuid
else
systemctl stop wg-quick@wgcf >/dev/null 2>&1
kill -15 $(pgrep warp-go) >/dev/null 2>&1 && sleep 2
ipuuid
systemctl start wg-quick@wgcf >/dev/null 2>&1
systemctl restart warp-go >/dev/null 2>&1
systemctl enable warp-go >/dev/null 2>&1
systemctl start warp-go >/dev/null 2>&1
fi
}

result_vl_vm_hy_tu(){
if [[ -f /root/ygkkkca/cert.crt && -f /root/ygkkkca/private.key && -s /root/ygkkkca/cert.crt && -s /root/ygkkkca/private.key ]]; then
ym=`bash ~/.acme.sh/acme.sh --list | tail -1 | awk '{print $1}'`
echo $ym > /root/ygkkkca/ca.log
fi
rm -rf /etc/s-box/vm_ws_argo.txt /etc/s-box/vm_ws.txt /etc/s-box/vm_ws_tls.txt
server_ip=$(cat /etc/s-box/server_ip.log)
server_ipcl=$(cat /etc/s-box/server_ipcl.log)
uuid=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].users[0].uuid')
vl_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].listen_port')
vl_name=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].tls.server_name')
public_key=$(cat /etc/s-box/public.key)
short_id=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].tls.reality.short_id[0]')
argo=$(cat /etc/s-box/argo.log 2>/dev/null | grep -a trycloudflare.com | awk 'NR==2{print}' | awk -F// '{print $2}' | awk '{print $1}')
ws_path=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].transport.path')
vm_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port')
tls=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.enabled')
vm_name=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.server_name')
if [[ "$tls" = "false" ]]; then
if [[ -f /etc/s-box/cfymjx.txt ]]; then
vm_name=$(cat /etc/s-box/cfymjx.txt 2>/dev/null)
else
vm_name=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.server_name')
fi
vmadd_local=$server_ipcl
vmadd_are_local=$server_ip
else
vmadd_local=$vm_name
vmadd_are_local=$vm_name
fi
if [[ -f /etc/s-box/cfvmadd_local.txt ]]; then
vmadd_local=$(cat /etc/s-box/cfvmadd_local.txt 2>/dev/null)
vmadd_are_local=$(cat /etc/s-box/cfvmadd_local.txt 2>/dev/null)
else
if [[ "$tls" = "false" ]]; then
if [[ -f /etc/s-box/cfymjx.txt ]]; then
vm_name=$(cat /etc/s-box/cfymjx.txt 2>/dev/null)
else
vm_name=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.server_name')
fi
vmadd_local=$server_ipcl
vmadd_are_local=$server_ip
else
vmadd_local=$vm_name
vmadd_are_local=$vm_name
fi
fi
if [[ -f /etc/s-box/cfvmadd_argo.txt ]]; then
vmadd_argo=$(cat /etc/s-box/cfvmadd_argo.txt 2>/dev/null)
else
vmadd_argo=www.visa.com.sg
fi
hy2_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[2].listen_port')
hy2_ports=$(iptables -t nat -nL --line 2>/dev/null | grep -w "$hy2_port" | awk '{print $8}' | sed 's/dpts://; s/dpt://' | tr '\n' ',' | sed 's/,$//')
if [[ -n $hy2_ports ]]; then
hy2ports=$(echo $hy2_ports | sed 's/:/-/g')
hyps=$hy2_port,$hy2ports
else
hyps=
fi
ym=$(cat /root/ygkkkca/ca.log 2>/dev/null)
hy2_sniname=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[2].tls.key_path')
if [[ "$hy2_sniname" = '/etc/s-box/private.key' ]]; then
hy2_name=www.bing.com
sb_hy2_ip=$server_ip
cl_hy2_ip=$server_ipcl
ins_hy2=1
hy2_ins=true
else
hy2_name=$ym
sb_hy2_ip=$ym
cl_hy2_ip=$ym
ins_hy2=0
hy2_ins=false
fi
tu5_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[3].listen_port')
ym=$(cat /root/ygkkkca/ca.log 2>/dev/null)
tu5_sniname=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[3].tls.key_path')
if [[ "$tu5_sniname" = '/etc/s-box/private.key' ]]; then
tu5_name=www.bing.com
sb_tu5_ip=$server_ip
cl_tu5_ip=$server_ipcl
ins=1
tu5_ins=true
else
tu5_name=$ym
sb_tu5_ip=$ym
cl_tu5_ip=$ym
ins=0
tu5_ins=false
fi
an_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[4].listen_port')
ym=$(cat /root/ygkkkca/ca.log 2>/dev/null)
an_sniname=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[4].tls.key_path')
if [[ "$an_sniname" = '/etc/s-box/private.key' ]]; then
an_name=www.bing.com
sb_an_ip=$server_ip
cl_an_ip=$server_ipcl
ins_an=1
an_ins=true
else
an_name=$ym
sb_an_ip=$ym
cl_an_ip=$ym
ins_an=0
an_ins=false
fi
}

resvless(){
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
vl_link="vless://$uuid@$server_ip:$vl_port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$vl_name&fp=chrome&pbk=$public_key&sid=$short_id&type=tcp&headerType=none#vl-reality-$hostname"
echo "$vl_link" > /etc/s-box/vl_reality.txt
red "🚀【 vless-reality-vision 】节点信息如下：" && sleep 2
echo
echo "分享链接【v2ran(切换singbox内核)、nekobox、小火箭shadowrocket】"
echo -e "${yellow}$vl_link${plain}"
echo
echo "二维码【v2ran(切换singbox内核)、nekobox、小火箭shadowrocket】"
qrencode -o - -t ANSIUTF8 "$(cat /etc/s-box/vl_reality.txt)"
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
}

resvmess(){
if [[ "$tls" = "false" ]]; then
if ps -ef 2>/dev/null | grep "[l]ocalhost:$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port')" >/dev/null 2>&1; then
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
red "🚀【 vmess-ws(tls)+Argo 】临时节点信息如下(可选择3-8-3，自定义CDN优选地址)：" && sleep 2
echo
echo "分享链接【v2rayn、v2rayng、nekobox、小火箭shadowrocket】"
echo -e "${yellow}vmess://$(echo '{"add":"'$vmadd_argo'","aid":"0","host":"'$argo'","id":"'$uuid'","net":"ws","path":"'$ws_path'","port":"8443","ps":"'vm-argo-$hostname'","tls":"tls","sni":"'$argo'","fp":"chrome","type":"none","v":"2"}' | base64 -w 0)${plain}"
echo
echo "二维码【v2rayn、v2rayng、nekobox、小火箭shadowrocket】"
echo 'vmess://'$(echo '{"add":"'$vmadd_argo'","aid":"0","host":"'$argo'","id":"'$uuid'","net":"ws","path":"'$ws_path'","port":"8443","ps":"'vm-argo-$hostname'","tls":"tls","sni":"'$argo'","fp":"chrome","type":"none","v":"2"}' | base64 -w 0) > /etc/s-box/vm_ws_argols.txt
qrencode -o - -t ANSIUTF8 "$(cat /etc/s-box/vm_ws_argols.txt)"
fi
if ps -ef 2>/dev/null | grep -q '[c]loudflared.*run'; then
argogd=$(cat /etc/s-box/sbargoym.log 2>/dev/null)
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
red "🚀【 vmess-ws(tls)+Argo 】固定节点信息如下 (可选择3-8-3，自定义CDN优选地址)：" && sleep 2
echo
echo "分享链接【v2rayn、v2rayng、nekobox、小火箭shadowrocket】"
echo -e "${yellow}vmess://$(echo '{"add":"'$vmadd_argo'","aid":"0","host":"'$argogd'","id":"'$uuid'","net":"ws","path":"'$ws_path'","port":"8443","ps":"'vm-argo-$hostname'","tls":"tls","sni":"'$argogd'","fp":"chrome","type":"none","v":"2"}' | base64 -w 0)${plain}"
echo
echo "二维码【v2rayn、v2rayng、nekobox、小火箭shadowrocket】"
echo 'vmess://'$(echo '{"add":"'$vmadd_argo'","aid":"0","host":"'$argogd'","id":"'$uuid'","net":"ws","path":"'$ws_path'","port":"8443","ps":"'vm-argo-$hostname'","tls":"tls","sni":"'$argogd'","fp":"chrome","type":"none","v":"2"}' | base64 -w 0) > /etc/s-box/vm_ws_argogd.txt
qrencode -o - -t ANSIUTF8 "$(cat /etc/s-box/vm_ws_argogd.txt)"
fi
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
red "🚀【 vmess-ws 】节点信息如下 (建议选择3-8-1，设置为CDN优选节点)：" && sleep 2
echo
echo "分享链接【v2rayn、v2rayng、nekobox、小火箭shadowrocket】"
echo -e "${yellow}vmess://$(echo '{"add":"'$vmadd_are_local'","aid":"0","host":"'$vm_name'","id":"'$uuid'","net":"ws","path":"'$ws_path'","port":"'$vm_port'","ps":"'vm-ws-$hostname'","tls":"","type":"none","v":"2"}' | base64 -w 0)${plain}"
echo
echo "二维码【v2rayn、v2rayng、nekobox、小火箭shadowrocket】"
echo 'vmess://'$(echo '{"add":"'$vmadd_are_local'","aid":"0","host":"'$vm_name'","id":"'$uuid'","net":"ws","path":"'$ws_path'","port":"'$vm_port'","ps":"'vm-ws-$hostname'","tls":"","type":"none","v":"2"}' | base64 -w 0) > /etc/s-box/vm_ws.txt
qrencode -o - -t ANSIUTF8 "$(cat /etc/s-box/vm_ws.txt)"
else
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
red "🚀【 vmess-ws-tls 】节点信息如下 (建议选择3-8-1，设置为CDN优选节点)：" && sleep 2
echo
echo "分享链接【v2rayn、v2rayng、nekobox、小火箭shadowrocket】"
echo -e "${yellow}vmess://$(echo '{"add":"'$vmadd_are_local'","aid":"0","host":"'$vm_name'","id":"'$uuid'","net":"ws","path":"'$ws_path'","port":"'$vm_port'","ps":"'vm-ws-tls-$hostname'","tls":"tls","sni":"'$vm_name'","fp":"chrome","type":"none","v":"2"}' | base64 -w 0)${plain}"
echo
echo "二维码【v2rayn、v2rayng、nekobox、小火箭shadowrocket】"
echo 'vmess://'$(echo '{"add":"'$vmadd_are_local'","aid":"0","host":"'$vm_name'","id":"'$uuid'","net":"ws","path":"'$ws_path'","port":"'$vm_port'","ps":"'vm-ws-tls-$hostname'","tls":"tls","sni":"'$vm_name'","fp":"chrome","type":"none","v":"2"}' | base64 -w 0) > /etc/s-box/vm_ws_tls.txt
qrencode -o - -t ANSIUTF8 "$(cat /etc/s-box/vm_ws_tls.txt)"
fi
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
}

reshy2(){
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
hy2_link="hysteria2://$uuid@$sb_hy2_ip:$hy2_port?security=tls&alpn=h3&insecure=$ins_hy2&mport=$hyps&sni=$hy2_name#hy2-$hostname"
#hy2_link="hysteria2://$uuid@$sb_hy2_ip:$hy2_port?security=tls&alpn=h3&insecure=$ins_hy2&sni=$hy2_name#hy2-$hostname"
echo "$hy2_link" > /etc/s-box/hy2.txt
red "🚀【 Hysteria-2 】节点信息如下：" && sleep 2
echo
echo "分享链接【v2rayn、v2rayng、nekobox、小火箭shadowrocket】"
echo -e "${yellow}$hy2_link${plain}"
echo
echo "二维码【v2rayn、v2rayng、nekobox、小火箭shadowrocket】"
qrencode -o - -t ANSIUTF8 "$(cat /etc/s-box/hy2.txt)"
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
}

restu5(){
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
tuic5_link="tuic://$uuid:$uuid@$sb_tu5_ip:$tu5_port?congestion_control=bbr&udp_relay_mode=native&alpn=h3&sni=$tu5_name&allow_insecure=$ins&allowInsecure=$ins#tu5-$hostname"
echo "$tuic5_link" > /etc/s-box/tuic5.txt
red "🚀【 Tuic-v5 】节点信息如下：" && sleep 2
echo
echo "分享链接【v2rayn、nekobox、小火箭shadowrocket】"
echo -e "${yellow}$tuic5_link${plain}"
echo
echo "二维码【v2rayn、nekobox、小火箭shadowrocket】"
qrencode -o - -t ANSIUTF8 "$(cat /etc/s-box/tuic5.txt)"
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
}

resan(){
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
an_link="anytls://$uuid@$sb_an_ip:$an_port?&sni=$an_name&allowInsecure=$ins_an#anytls-$hostname"
echo "$an_link" > /etc/s-box/an.txt
red "🚀【 Anytls】节点信息如下：" && sleep 2
echo
echo "分享链接【v2rayn、小火箭shadowrocket】"
echo -e "${yellow}$an_link${plain}"
echo
echo "二维码【v2rayn、nekobox、小火箭shadowrocket】"
qrencode -o - -t ANSIUTF8 "$(cat /etc/s-box/an.txt)"
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
}

sb_client(){
sbany1(){
  if [[ "$sbnh" != "1.10" ]]; then
    echo "\"anytls-$hostname\","
  fi
}
clany1(){
  if [[ "$sbnh" != "1.10" ]]; then
    echo "- anytls-$hostname"
  fi
}
sbany2(){
  if [[ "$sbnh" != "1.10" ]]; then
    cat <<EOF
         {
            "type": "anytls",
            "tag": "anytls-$hostname",
            "server": "$sb_an_ip",
            "server_port": $an_port,
            "password": "$uuid",
            "idle_session_check_interval": "30s",
            "idle_session_timeout": "30s",
            "min_idle_session": 5,
            "tls": {
                "enabled": true,
                "insecure": $an_ins,
                "server_name": "$an_name"
            }
         },
EOF
  fi
}
clany2(){
  if [[ "$sbnh" != "1.10" ]]; then
    cat <<EOF
- name: anytls-$hostname
  type: anytls
  server: $cl_an_ip
  port: $an_port
  password: $uuid
  client-fingerprint: chrome
  udp: true
  idle-session-check-interval: 30
  idle-session-timeout: 30
  sni: $an_name
  skip-cert-verify: $an_ins
EOF
  fi
}

sball(){
cat <<EOF
{
    "log": {
        "disabled": false,
        "level": "info",
        "timestamp": true
    },
    "experimental": {
        "cache_file": {
            "enabled": true,
            "path": "./cache.db",
            "store_fakeip": true
        },
        "clash_api": {
            "external_controller": "127.0.0.1:9090",
            "external_ui": "ui",
            "default_mode": "Rule"
        }
    },
    "dns": {
        "servers": [
            {
                "tag": "aliDns",
                "type": "https",
                "server": "dns.alidns.com",
                "path": "/dns-query",
                "domain_resolver": "local"
            },
            {
                "tag": "local",
                "type": "udp",
                "server": "223.5.5.5"
            },
            {
                "tag": "proxyDns",
                "type": "https",
                "server": "dns.google",
                "path": "/dns-query",
	            "domain_resolver": "aliDns",
                "detour": "proxy"
            },
           {
        "type": "fakeip",
        "tag": "fakeip",
        "inet4_range": "198.18.0.0/15",
        "inet6_range": "fc00::/18"
      }
        ],
        "rules": [
            {
                "rule_set": "geosite-cn",
                "clash_mode": "Rule",
                "server": "aliDns"
            },
            {
                "clash_mode": "Direct",
                "server": "local"
            },
            {
                "clash_mode": "Global",
                "server": "proxyDns"
            },
            {
        "query_type": [
          "A",
          "AAAA"
        ],
        "server": "fakeip"
      }
        ],
        "final": "proxyDns",
        "strategy": "prefer_ipv4",
        "independent_cache": true
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
            "strict_route": true
        }
    ],
    "route": {
        "rules": [
            {
	           "inbound": "tun-in",
                "action": "sniff"
            },
            {
                "type": "logical",
                "mode": "or",
                "rules": [
                    {
                        "port": 53
                    },
                    {
                        "protocol": "dns"
                    }
                ],
                "action": "hijack-dns"
            },
         {
          "clash_mode": "Global",
          "outbound": "proxy"
         },
        {
        "rule_set": "geosite-cn",
        "clash_mode": "Rule",
        "outbound": "direct"
       },
     {
    "rule_set": "geoip-cn",
    "clash_mode": "Rule",
    "outbound": "direct"
      },
     {
    "ip_is_private": true,
    "clash_mode": "Rule",
    "outbound": "direct"
    },
     {
      "clash_mode": "Direct",
      "outbound": "direct"
     }		
        ],
        "rule_set": [
            {
                "tag": "geosite-cn",
                "type": "remote",
                "format": "binary",
                "url": "https://cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/geolocation-cn.srs",
                "download_detour": "direct"
            },
            {
                "tag": "geoip-cn",
                "type": "remote",
                "format": "binary",
                "url": "https://cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geoip/cn.srs",
                "download_detour": "direct"
            }
        ],
        "final": "proxy",
        "auto_detect_interface": true,
        "default_domain_resolver": {
            "server": "aliDns"
        }
    },
  "outbounds": [
    {
      "type": "vless",
      "tag": "vless-$hostname",
      "server": "$server_ipcl",
      "server_port": $vl_port,
      "uuid": "$uuid",
      "flow": "xtls-rprx-vision",
      "tls": {
        "enabled": true,
        "server_name": "$vl_name",
        "utls": {
          "enabled": true,
          "fingerprint": "chrome"
        },
      "reality": {
          "enabled": true,
          "public_key": "$public_key",
          "short_id": "$short_id"
        }
      }
    },
{
            "server": "$vmadd_local",
            "server_port": $vm_port,
            "tag": "vmess-$hostname",
            "tls": {
                "enabled": $tls,
                "server_name": "$vm_name",
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
                        "$vm_name"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },

    {
        "type": "hysteria2",
        "tag": "hy2-$hostname",
        "server": "$cl_hy2_ip",
        "server_port": $hy2_port,
        "password": "$uuid",
        "tls": {
            "enabled": true,
            "server_name": "$hy2_name",
            "insecure": $hy2_ins,
            "alpn": [
                "h3"
            ]
        }
    },
        {
            "type":"tuic",
            "tag": "tuic5-$hostname",
            "server": "$cl_tu5_ip",
            "server_port": $tu5_port,
            "uuid": "$uuid",
            "password": "$uuid",
            "congestion_control": "bbr",
            "udp_relay_mode": "native",
            "udp_over_stream": false,
            "zero_rtt_handshake": false,
            "heartbeat": "10s",
            "tls":{
                "enabled": true,
                "server_name": "$tu5_name",
                "insecure": $tu5_ins,
                "alpn": [
                    "h3"
                ]
            }
        },
EOF
}

clall(){
cat <<EOF
port: 7890
allow-lan: true
mode: rule
log-level: info
unified-delay: true
dns:
  enable: true 
  listen: "0.0.0.0:1053"
  ipv6: true
  prefer-h3: false
  respect-rules: true
  use-system-hosts: false
  cache-algorithm: "arc"
  enhanced-mode: "fake-ip"
  fake-ip-range: "198.18.0.1/16"
  fake-ip-filter:
    - "+.lan"
    - "+.local"
    - "+.msftconnecttest.com"
    - "+.msftncsi.com"
    - "localhost.ptlogin2.qq.com"
    - "localhost.sec.qq.com"
    - "+.in-addr.arpa"
    - "+.ip6.arpa"
    - "time.*.com"
    - "time.*.gov"
    - "pool.ntp.org"
    - "localhost.work.weixin.qq.com"
  default-nameserver: ["223.5.5.5", "1.2.4.8"]
  nameserver:
    - "https://208.67.222.222/dns-query"
    - "https://1.1.1.1/dns-query"
    - "https://8.8.4.4/dns-query"
  proxy-server-nameserver:
    - "https://223.5.5.5/dns-query"
    - "https://doh.pub/dns-query"
  nameserver-policy:
    "geosite:private,cn":
      - "https://223.5.5.5/dns-query"
      - "https://doh.pub/dns-query"

proxies:
- name: vless-reality-vision-$hostname               
  type: vless
  server: $server_ipcl                           
  port: $vl_port                                
  uuid: $uuid   
  network: tcp
  udp: true
  tls: true
  flow: xtls-rprx-vision
  servername: $vl_name                 
  reality-opts: 
    public-key: $public_key    
    short-id: $short_id                      
  client-fingerprint: chrome                  

- name: vmess-ws-$hostname                         
  type: vmess
  server: $vmadd_local                        
  port: $vm_port                                     
  uuid: $uuid       
  alterId: 0
  cipher: auto
  udp: true
  tls: $tls
  network: ws
  servername: $vm_name                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $vm_name                     

- name: hysteria2-$hostname                            
  type: hysteria2                                      
  server: $cl_hy2_ip                               
  port: $hy2_port                                
  password: $uuid                          
  alpn:
    - h3
  sni: $hy2_name                               
  skip-cert-verify: $hy2_ins
  fast-open: true

- name: tuic5-$hostname                            
  server: $cl_tu5_ip                      
  port: $tu5_port                                    
  type: tuic
  uuid: $uuid       
  password: $uuid   
  alpn: [h3]
  disable-sni: true
  reduce-rtt: true
  udp-relay-mode: native
  congestion-controller: bbr
  sni: $tu5_name                                
  skip-cert-verify: $tu5_ins
EOF
}

tls=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.enabled')
if ps -ef 2>/dev/null | grep -q '[c]loudflared.*run' && ps -ef 2>/dev/null | grep "[l]ocalhost:$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port')" >/dev/null 2>&1 && [ "$tls" = "false" ]; then
cat > /etc/s-box/sbox.json <<EOF
$(sball)
$(sbany2)
{
            "server": "$vmadd_argo",
            "server_port": 8443,
            "tag": "vmess-tls-argo固定-$hostname",
            "tls": {
                "enabled": true,
                "server_name": "$argogd",
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
                        "$argogd"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },
{
            "server": "$vmadd_argo",
            "server_port": 8880,
            "tag": "vmess-argo固定-$hostname",
            "tls": {
                "enabled": false,
                "server_name": "$argogd",
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
                        "$argogd"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },
{
            "server": "$vmadd_argo",
            "server_port": 8443,
            "tag": "vmess-tls-argo临时-$hostname",
            "tls": {
                "enabled": true,
                "server_name": "$argo",
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
                        "$argo"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },
{
            "server": "$vmadd_argo",
            "server_port": 8880,
            "tag": "vmess-argo临时-$hostname",
            "tls": {
                "enabled": false,
                "server_name": "$argo",
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
                        "$argo"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },
        {
            "tag": "proxy",
            "type": "selector",
			"default": "auto",
            "outbounds": [
        "auto",
        "vless-$hostname",
        "vmess-$hostname",
        "hy2-$hostname",
        "tuic5-$hostname",
        $(sbany1)
        "vmess-tls-argo固定-$hostname",
        "vmess-argo固定-$hostname",
        "vmess-tls-argo临时-$hostname",
        "vmess-argo临时-$hostname"
            ]
        },
        {
            "tag": "auto",
            "type": "urltest",
            "outbounds": [
        "vless-$hostname",
        "vmess-$hostname",
        "hy2-$hostname",
        "tuic5-$hostname",
        $(sbany1)
        "vmess-tls-argo固定-$hostname",
        "vmess-argo固定-$hostname",
        "vmess-tls-argo临时-$hostname",
        "vmess-argo临时-$hostname"
            ],
            "url": "http://www.gstatic.com/generate_204",
            "interval": "10m",
            "tolerance": 50
        },
        {
            "type": "direct",
            "tag": "direct"
        }
    ]
}
EOF

cat > /etc/s-box/clmi.yaml <<EOF
$(clall)

$(clany2)

- name: vmess-tls-argo固定-$hostname                         
  type: vmess
  server: $vmadd_argo                        
  port: 8443                                     
  uuid: $uuid       
  alterId: 0
  cipher: auto
  udp: true
  tls: true
  network: ws
  servername: $argogd                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $argogd


- name: vmess-argo固定-$hostname                         
  type: vmess
  server: $vmadd_argo                        
  port: 8880                                     
  uuid: $uuid       
  alterId: 0
  cipher: auto
  udp: true
  tls: false
  network: ws
  servername: $argogd                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $argogd

- name: vmess-tls-argo临时-$hostname                         
  type: vmess
  server: $vmadd_argo                        
  port: 8443                                     
  uuid: $uuid       
  alterId: 0
  cipher: auto
  udp: true
  tls: true
  network: ws
  servername: $argo                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $argo

- name: vmess-argo临时-$hostname                         
  type: vmess
  server: $vmadd_argo                        
  port: 8880                                     
  uuid: $uuid       
  alterId: 0
  cipher: auto
  udp: true
  tls: false
  network: ws
  servername: $argo                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $argo 

proxy-groups:
- name: 负载均衡
  type: load-balance
  url: https://www.gstatic.com/generate_204
  interval: 300
  strategy: round-robin
  proxies:
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
    $(clany1)
    - vmess-tls-argo固定-$hostname
    - vmess-argo固定-$hostname
    - vmess-tls-argo临时-$hostname
    - vmess-argo临时-$hostname

- name: 自动选择
  type: url-test
  url: https://www.gstatic.com/generate_204
  interval: 300
  tolerance: 50
  proxies:
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
    $(clany1)
    - vmess-tls-argo固定-$hostname
    - vmess-argo固定-$hostname
    - vmess-tls-argo临时-$hostname
    - vmess-argo临时-$hostname
    
- name: 🌍选择代理节点
  type: select
  proxies:
    - 负载均衡                                         
    - 自动选择
    - DIRECT
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
    $(clany1)
    - vmess-tls-argo固定-$hostname
    - vmess-argo固定-$hostname
    - vmess-tls-argo临时-$hostname
    - vmess-argo临时-$hostname
rules:
  - GEOIP,LAN,DIRECT
  - GEOIP,CN,DIRECT
  - MATCH,🌍选择代理节点
EOF

elif ! ps -ef 2>/dev/null | grep -q '[c]loudflared.*run' && ps -ef 2>/dev/null | grep "[l]ocalhost:$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port')" >/dev/null 2>&1 && [ "$tls" = "false" ]; then
cat > /etc/s-box/sbox.json <<EOF
$(sball)
$(sbany2)
{
            "server": "$vmadd_argo",
            "server_port": 8443,
            "tag": "vmess-tls-argo临时-$hostname",
            "tls": {
                "enabled": true,
                "server_name": "$argo",
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
                        "$argo"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },
{
            "server": "$vmadd_argo",
            "server_port": 8880,
            "tag": "vmess-argo临时-$hostname",
            "tls": {
                "enabled": false,
                "server_name": "$argo",
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
                        "$argo"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },
        {
            "tag": "proxy",
            "type": "selector",
			"default": "auto",
            "outbounds": [
        "auto",
        "vless-$hostname",
        "vmess-$hostname",
        "hy2-$hostname",
        "tuic5-$hostname",
        $(sbany1)
        "vmess-tls-argo临时-$hostname",
        "vmess-argo临时-$hostname"
            ]
        },
        {
            "tag": "auto",
            "type": "urltest",
            "outbounds": [
        "vless-$hostname",
        "vmess-$hostname",
        "hy2-$hostname",
        "tuic5-$hostname",
        $(sbany1)
        "vmess-tls-argo临时-$hostname",
        "vmess-argo临时-$hostname"
            ],
            "url": "http://www.gstatic.com/generate_204",
            "interval": "10m",
            "tolerance": 50
        },
        {
            "type": "direct",
            "tag": "direct"
        }
    ]
}
EOF

cat > /etc/s-box/clmi.yaml <<EOF
$(clall)








$(clany2)

- name: vmess-tls-argo临时-$hostname                         
  type: vmess
  server: $vmadd_argo                        
  port: 8443                                     
  uuid: $uuid       
  alterId: 0
  cipher: auto
  udp: true
  tls: true
  network: ws
  servername: $argo                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $argo

- name: vmess-argo临时-$hostname                         
  type: vmess
  server: $vmadd_argo                        
  port: 8880                                     
  uuid: $uuid       
  alterId: 0
  cipher: auto
  udp: true
  tls: false
  network: ws
  servername: $argo                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $argo 

proxy-groups:
- name: 负载均衡
  type: load-balance
  url: https://www.gstatic.com/generate_204
  interval: 300
  strategy: round-robin
  proxies:
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
    $(clany1)
    - vmess-tls-argo临时-$hostname
    - vmess-argo临时-$hostname

- name: 自动选择
  type: url-test
  url: https://www.gstatic.com/generate_204
  interval: 300
  tolerance: 50
  proxies:
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
    $(clany1)
    - vmess-tls-argo临时-$hostname
    - vmess-argo临时-$hostname
    
- name: 🌍选择代理节点
  type: select
  proxies:
    - 负载均衡                                         
    - 自动选择
    - DIRECT
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
    $(clany1)
    - vmess-tls-argo临时-$hostname
    - vmess-argo临时-$hostname
rules:
  - GEOIP,LAN,DIRECT
  - GEOIP,CN,DIRECT
  - MATCH,🌍选择代理节点
EOF

elif ps -ef 2>/dev/null | grep -q '[c]loudflared.*run' && ! ps -ef 2>/dev/null | grep "[l]ocalhost:$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port')" >/dev/null 2>&1 && [ "$tls" = "false" ]; then
cat > /etc/s-box/sbox.json <<EOF
$(sball)
$(sbany2)
{
            "server": "$vmadd_argo",
            "server_port": 8443,
            "tag": "vmess-tls-argo固定-$hostname",
            "tls": {
                "enabled": true,
                "server_name": "$argogd",
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
                        "$argogd"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },
{
            "server": "$vmadd_argo",
            "server_port": 8880,
            "tag": "vmess-argo固定-$hostname",
            "tls": {
                "enabled": false,
                "server_name": "$argogd",
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
                        "$argogd"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },
        {
            "tag": "proxy",
            "type": "selector",
			"default": "auto",
            "outbounds": [
        "auto",
        "vless-$hostname",
        "vmess-$hostname",
        "hy2-$hostname",
        "tuic5-$hostname",
        $(sbany1)
        "vmess-tls-argo固定-$hostname",
        "vmess-argo固定-$hostname"
            ]
        },
        {
            "tag": "auto",
            "type": "urltest",
            "outbounds": [
        "vless-$hostname",
        "vmess-$hostname",
        "hy2-$hostname",
        "tuic5-$hostname",
        $(sbany1)
        "vmess-tls-argo固定-$hostname",
        "vmess-argo固定-$hostname"
            ],
            "url": "http://www.gstatic.com/generate_204",
            "interval": "10m",
            "tolerance": 50
        },
        {
            "type": "direct",
            "tag": "direct"
        }
    ]
}
EOF

cat > /etc/s-box/clmi.yaml <<EOF
$(clall)






$(clany2)

- name: vmess-tls-argo固定-$hostname                         
  type: vmess
  server: $vmadd_argo                        
  port: 8443                                     
  uuid: $uuid       
  alterId: 0
  cipher: auto
  udp: true
  tls: true
  network: ws
  servername: $argogd                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $argogd

- name: vmess-argo固定-$hostname                         
  type: vmess
  server: $vmadd_argo                        
  port: 8880                                     
  uuid: $uuid       
  alterId: 0
  cipher: auto
  udp: true
  tls: false
  network: ws
  servername: $argogd                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $argogd

proxy-groups:
- name: 负载均衡
  type: load-balance
  url: https://www.gstatic.com/generate_204
  interval: 300
  strategy: round-robin
  proxies:
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
    $(clany1)
    - vmess-tls-argo固定-$hostname
    - vmess-argo固定-$hostname

- name: 自动选择
  type: url-test
  url: https://www.gstatic.com/generate_204
  interval: 300
  tolerance: 50
  proxies:
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
    $(clany1)
    - vmess-tls-argo固定-$hostname
    - vmess-argo固定-$hostname
    
- name: 🌍选择代理节点
  type: select
  proxies:
    - 负载均衡                                         
    - 自动选择
    - DIRECT
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
    $(clany1)
    - vmess-tls-argo固定-$hostname
    - vmess-argo固定-$hostname
rules:
  - GEOIP,LAN,DIRECT
  - GEOIP,CN,DIRECT
  - MATCH,🌍选择代理节点
EOF

else
cat > /etc/s-box/sbox.json <<EOF
$(sball)
$(sbany2)
        {
            "tag": "proxy",
            "type": "selector",
			"default": "auto",
            "outbounds": [
        "auto",
        "vless-$hostname",
		$(sbany1)
        "vmess-$hostname",
        "hy2-$hostname",
        "tuic5-$hostname"
            ]
        },
        {
            "tag": "auto",
            "type": "urltest",
            "outbounds": [
        "vless-$hostname",
		$(sbany1)
        "vmess-$hostname",
        "hy2-$hostname",
        "tuic5-$hostname"
            ],
            "url": "http://www.gstatic.com/generate_204",
            "interval": "10m",
            "tolerance": 50
        },
        {
            "type": "direct",
            "tag": "direct"
        }
    ]
}
EOF

cat > /etc/s-box/clmi.yaml <<EOF
$(clall)

$(clany2)

proxy-groups:
- name: 负载均衡
  type: load-balance
  url: https://www.gstatic.com/generate_204
  interval: 300
  strategy: round-robin
  proxies:
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
    $(clany1)

- name: 自动选择
  type: url-test
  url: https://www.gstatic.com/generate_204
  interval: 300
  tolerance: 50
  proxies:
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
    $(clany1)
    
- name: 🌍选择代理节点
  type: select
  proxies:
    - 负载均衡                                         
    - 自动选择
    - DIRECT
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
    $(clany1)
rules:
  - GEOIP,LAN,DIRECT
  - GEOIP,CN,DIRECT
  - MATCH,🌍选择代理节点
EOF
fi
}

cfargo_ym(){
tls=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.enabled')
if [[ "$tls" = "false" ]]; then
echo
yellow "1：添加或者删除Argo临时隧道"
yellow "2：添加或者删除Argo固定隧道"
yellow "0：返回上层"
readp "请选择【0-2】：" menu
if [ "$menu" = "1" ]; then
cfargo
elif [ "$menu" = "2" ]; then
cfargoym
else
changeserv
fi
else
yellow "因vmess开启了tls，Argo隧道功能不可用" && sleep 2
fi
}

cloudflaredargo(){
if [ ! -e /etc/s-box/cloudflared ]; then
case $(uname -m) in
aarch64) cpu=arm64;;
x86_64) cpu=amd64;;
esac
curl -L -o /etc/s-box/cloudflared -# --retry 2 https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$cpu
#curl -L -o /etc/s-box/cloudflared -# --retry 2 https://gitlab.com/rwkgyg/sing-box-yg/-/raw/main/$cpu
chmod +x /etc/s-box/cloudflared
fi
}

cfargoym(){
echo
if [[ -f /etc/s-box/sbargotoken.log && -f /etc/s-box/sbargoym.log ]]; then
green "当前Argo固定隧道域名：$(cat /etc/s-box/sbargoym.log 2>/dev/null)"
green "当前Argo固定隧道Token：$(cat /etc/s-box/sbargotoken.log 2>/dev/null)"
fi
echo
green "请进入Cloudflare官网 --- Zero Trust --- 网络 --- 连接器，创建固定隧道"
yellow "1：重置/设置Argo固定隧道域名"
yellow "2：停止Argo固定隧道"
yellow "0：返回上层"
readp "请选择【0-2】：" menu
if [ "$menu" = "1" ]; then
cloudflaredargo
readp "输入Argo固定隧道Token: " argotoken
readp "输入Argo固定隧道域名: " argoym
pid=$(ps -ef 2>/dev/null | awk '/[c]loudflared.*run/ {print $2}')
[ -n "$pid" ] && kill -9 "$pid" >/dev/null 2>&1
echo
if [[ -n "${argotoken}" && -n "${argoym}" ]]; then
if pidof systemd >/dev/null 2>&1; then
cat > /etc/systemd/system/argo.service <<EOF
[Unit]
Description=argo service
After=network.target
[Service]
Type=simple
NoNewPrivileges=yes
TimeoutStartSec=0
ExecStart=/etc/s-box/cloudflared tunnel --no-autoupdate --edge-ip-version auto --protocol http2 run --token "${argotoken}"
Restart=on-failure
RestartSec=5s
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload >/dev/null 2>&1
systemctl enable argo >/dev/null 2>&1
systemctl start argo >/dev/null 2>&1
elif command -v rc-service >/dev/null 2>&1; then
cat > /etc/init.d/argo <<EOF
#!/sbin/openrc-run
description="argo service"
command="/etc/s-box/cloudflared tunnel"
command_args="--no-autoupdate --edge-ip-version auto --protocol http2 run --token ${argotoken}"
pidfile="/run/argo.pid"
command_background="yes"
depend() {
need net
}
EOF
chmod +x /etc/init.d/argo >/dev/null 2>&1
rc-update add argo default >/dev/null 2>&1
rc-service argo start >/dev/null 2>&1
fi
fi
echo ${argoym} > /etc/s-box/sbargoym.log
echo ${argotoken} > /etc/s-box/sbargotoken.log
argo=$(cat /etc/s-box/sbargoym.log 2>/dev/null)
sbshare > /dev/null 2>&1
blue "Argo固定隧道设置完成，固定域名：$argo"
elif [ "$menu" = "2" ]; then
if pidof systemd >/dev/null 2>&1; then
systemctl stop argo >/dev/null 2>&1
systemctl disable argo >/dev/null 2>&1
rm -rf /etc/systemd/system/argo.service
elif command -v rc-service >/dev/null 2>&1; then
rc-service argo stop >/dev/null 2>&1
rc-update del argo default >/dev/null 2>&1
rm -rf /etc/init.d/argo
fi
rm -rf /etc/s-box/vm_ws_argogd.txt
sbshare > /dev/null 2>&1
green "Argo固定隧道已停止"
else
cfargo_ym
fi
}

cfargo(){
echo
yellow "1：重置Argo临时隧道域名"
yellow "2：停止Argo临时隧道"
yellow "0：返回上层"
readp "请选择【0-2】：" menu
if [ "$menu" = "1" ]; then
green "请稍等……"
cloudflaredargo
ps -ef | grep "[l]ocalhost:$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port')" | awk '{print $2}' | xargs kill 2>/dev/null
nohup /etc/s-box/cloudflared tunnel --url http://localhost:$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port') --edge-ip-version auto --no-autoupdate --protocol http2 > /etc/s-box/argo.log 2>&1 &
sleep 20
if [[ -n $(curl -sL https://$(cat /etc/s-box/argo.log 2>/dev/null | grep -a trycloudflare.com | awk 'NR==2{print}' | awk -F// '{print $2}' | awk '{print $1}')/ -I | awk 'NR==1 && /404|400|503/') ]]; then
argo=$(cat /etc/s-box/argo.log 2>/dev/null | grep -a trycloudflare.com | awk 'NR==2{print}' | awk -F// '{print $2}' | awk '{print $1}')
sbshare > /dev/null 2>&1
blue "Argo临时隧道申请成功，域名验证有效：$argo" && sleep 2
if command -v apk >/dev/null 2>&1; then
cat > /etc/local.d/alpineargo.start <<'EOF'
#!/bin/bash
sleep 10
nohup /etc/s-box/cloudflared tunnel --url http://localhost:$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port') --edge-ip-version auto --no-autoupdate --protocol http2 > /etc/s-box/argo.log 2>&1 &
sleep 10
printf "9\n1\n" | bash /usr/bin/sb > /dev/null 2>&1
EOF
chmod +x /etc/local.d/alpineargo.start
rc-update add local default >/dev/null 2>&1
else
crontab -l 2>/dev/null > /tmp/crontab.tmp
sed -i '/url http/d' /tmp/crontab.tmp
echo '@reboot sleep 10 && /bin/bash -c "nohup /etc/s-box/cloudflared tunnel --url http://localhost:$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port') --edge-ip-version auto --no-autoupdate --protocol http2 > /etc/s-box/argo.log 2>&1 & sleep 10 && printf \"9\n1\n\" | bash /usr/bin/sb > /dev/null 2>&1"' >> /tmp/crontab.tmp
crontab /tmp/crontab.tmp >/dev/null 2>&1
rm /tmp/crontab.tmp
fi
else
yellow "Argo临时域名验证暂不可用，请稍后再试"
fi
elif [ "$menu" = "2" ]; then
ps -ef | grep "[l]ocalhost:$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port')" | awk '{print $2}' | xargs kill 2>/dev/null
crontab -l 2>/dev/null > /tmp/crontab.tmp
sed -i '/url http/d' /tmp/crontab.tmp
crontab /tmp/crontab.tmp >/dev/null 2>&1
rm /tmp/crontab.tmp
rm -rf /etc/s-box/vm_ws_argols.txt
rm -rf /etc/local.d/alpineargo.start
sbshare > /dev/null 2>&1
green "Argo临时隧道已停止"
else
cfargo_ym
fi
}

instsllsingbox(){
if [[ -f '/etc/systemd/system/sing-box.service' ]]; then
red "已安装Sing-box服务，无法再次安装" && exit
fi
mkdir -p /etc/s-box
v6
openyn
inssb
inscertificate
insport
sleep 2
echo
blue "Vless-reality相关key与id将自动生成……"
key_pair=$(/etc/s-box/sing-box generate reality-keypair)
private_key=$(echo "$key_pair" | awk '/PrivateKey/ {print $2}' | tr -d '"')
public_key=$(echo "$key_pair" | awk '/PublicKey/ {print $2}' | tr -d '"')
echo "$public_key" > /etc/s-box/public.key
short_id=$(/etc/s-box/sing-box generate rand --hex 4)
wget -q -O /root/geoip.db https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.db
wget -q -O /root/geosite.db https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.db
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green "五、自动生成warp-wireguard出站账户" && sleep 2
warpwg
inssbjsonser
sbservice
sbactive
#curl -sL https://gitlab.com/rwkgyg/sing-box-yg/-/raw/main/version/version | awk -F "更新内容" '{print $1}' | head -n 1 > /etc/s-box/v
curl -sL https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/version | awk -F "更新内容" '{print $1}' | head -n 1 > /etc/s-box/v
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
lnsb && blue "Sing-box-yg脚本安装成功，脚本快捷方式：sb" && cronsb
echo
wgcfgo
sbshare
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
blue "可选择9，刷新并显示所有协议配置及分享链接"
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
}

changeym(){
[ -f /root/ygkkkca/ca.log ] && ymzs="$yellow切换为域名证书：$(cat /root/ygkkkca/ca.log 2>/dev/null)$plain" || ymzs="$yellow未申请域名证书，无法切换$plain"
vl_na="正在使用的域名：$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].tls.server_name')。$yellow更换符合reality要求的域名，不支持证书域名$plain"
tls=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.enabled')
[[ "$tls" = "false" ]] && vm_na="当前已关闭TLS。$ymzs ${yellow}将开启TLS，Argo隧道将不支持开启${plain}" || vm_na="正在使用的域名证书：$(cat /root/ygkkkca/ca.log 2>/dev/null)。$yellow切换为关闭TLS，Argo隧道将可用$plain"
hy2_sniname=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[2].tls.key_path')
[[ "$hy2_sniname" = '/etc/s-box/private.key' ]] && hy2_na="正在使用自签bing证书。$ymzs" || hy2_na="正在使用的域名证书：$(cat /root/ygkkkca/ca.log 2>/dev/null)。$yellow切换为自签bing证书$plain"
tu5_sniname=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[3].tls.key_path')
[[ "$tu5_sniname" = '/etc/s-box/private.key' ]] && tu5_na="正在使用自签bing证书。$ymzs" || tu5_na="正在使用的域名证书：$(cat /root/ygkkkca/ca.log 2>/dev/null)。$yellow切换为自签bing证书$plain"
an_sniname=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[4].tls.key_path')
[[ "$an_sniname" = '/etc/s-box/private.key' ]] && an_na="正在使用自签bing证书。$ymzs" || an_na="正在使用的域名证书：$(cat /root/ygkkkca/ca.log 2>/dev/null)。$yellow切换为自签bing证书$plain"
echo
green "请选择要切换证书模式的协议"
green "1：vless-reality协议，$vl_na"
if [[ -f /root/ygkkkca/ca.log ]]; then
green "2：vmess-ws协议，$vm_na"
green "3：Hysteria2协议，$hy2_na"
green "4：Tuic5协议，$tu5_na"
if [[ "$sbnh" != "1.10" ]]; then
green "5：Anytls协议，$an_na"
fi
else
red "仅支持选项1 (vless-reality)。因未申请域名证书，vmess-ws、Hysteria-2、Tuic-v5、Anytls的证书切换选项暂不予显示"
fi
green "0：返回上层"
readp "请选择：" menu
if [ "$menu" = "1" ]; then
readp "请输入vless-reality域名 (回车使用apple.com)：" menu
ym_vl_re=${menu:-apple.com}
a=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].tls.server_name')
b=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].tls.reality.handshake.server')
c=$(cat /etc/s-box/vl_reality.txt | cut -d'=' -f5 | cut -d'&' -f1)
echo $sbfiles | xargs -n1 sed -i "23s/$a/$ym_vl_re/"
echo $sbfiles | xargs -n1 sed -i "27s/$b/$ym_vl_re/"
restartsb && sbshare > /dev/null 2>&1
blue "Vless-reality域名证书更换完毕"
elif [ "$menu" = "2" ]; then
if [ -f /root/ygkkkca/ca.log ]; then
a=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.enabled')
[ "$a" = "true" ] && a_a=false || a_a=true
b=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.server_name')
[ "$b" = "www.bing.com" ] && b_b=$(cat /root/ygkkkca/ca.log) || b_b=$(cat /root/ygkkkca/ca.log)
c=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.certificate_path')
d=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.key_path')
if [ "$d" = '/etc/s-box/private.key' ]; then
c_c='/root/ygkkkca/cert.crt'
d_d='/root/ygkkkca/private.key'
else
c_c='/etc/s-box/cert.pem'
d_d='/etc/s-box/private.key'
fi
echo $sbfiles | xargs -n1 sed -i "55s#$a#$a_a#"
echo $sbfiles | xargs -n1 sed -i "56s#$b#$b_b#"
echo $sbfiles | xargs -n1 sed -i "57s#$c#$c_c#"
echo $sbfiles | xargs -n1 sed -i "58s#$d#$d_d#"
restartsb && sbshare > /dev/null 2>&1
blue "vmess-ws协议域名证书更换完毕"
echo
tls=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.enabled')
vm_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port')
blue "当前Vmess-ws(tls)的端口：$vm_port"
[[ "$tls" = "false" ]] && blue "切记：可进入主菜单选项4-2，将Vmess-ws端口更改为任意7个80系端口(80、8080、8880、2052、2082、2086、2095)，可实现CDN优选IP" || blue "切记：可进入主菜单选项4-2，将Vmess-ws-tls端口更改为任意6个443系的端口(443、8443、2053、2083、2087、2096)，可实现CDN优选IP"
echo
else
red "当前未申请域名证书，不可切换。主菜单选择12，执行Acme证书申请" && sleep 2 && sb
fi
elif [ "$menu" = "3" ]; then
if [ -f /root/ygkkkca/ca.log ]; then
c=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[2].tls.certificate_path')
d=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[2].tls.key_path')
if [ "$d" = '/etc/s-box/private.key' ]; then
c_c='/root/ygkkkca/cert.crt'
d_d='/root/ygkkkca/private.key'
else
c_c='/etc/s-box/cert.pem'
d_d='/etc/s-box/private.key'
fi
echo $sbfiles | xargs -n1 sed -i "79s#$c#$c_c#"
echo $sbfiles | xargs -n1 sed -i "80s#$d#$d_d#"
restartsb && sbshare > /dev/null 2>&1
blue "Hysteria2协议域名证书更换完毕"
else
red "当前未申请域名证书，不可切换。主菜单选择12，执行Acme证书申请" && sleep 2 && sb
fi
elif [ "$menu" = "4" ]; then
if [ -f /root/ygkkkca/ca.log ]; then
c=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[3].tls.certificate_path')
d=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[3].tls.key_path')
if [ "$d" = '/etc/s-box/private.key' ]; then
c_c='/root/ygkkkca/cert.crt'
d_d='/root/ygkkkca/private.key'
else
c_c='/etc/s-box/cert.pem'
d_d='/etc/s-box/private.key'
fi
echo $sbfiles | xargs -n1 sed -i "102s#$c#$c_c#"
echo $sbfiles | xargs -n1 sed -i "103s#$d#$d_d#"
restartsb && sbshare > /dev/null 2>&1
blue "Tuic5协议域名证书更换完毕"
else
red "当前未申请域名证书，不可切换。主菜单选择12，执行Acme证书申请" && sleep 2 && sb
fi
elif [ "$menu" = "5" ]; then
if [ -f /root/ygkkkca/ca.log ]; then
c=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[4].tls.certificate_path')
d=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[4].tls.key_path')
if [ "$d" = '/etc/s-box/private.key' ]; then
c_c='/root/ygkkkca/cert.crt'
d_d='/root/ygkkkca/private.key'
else
c_c='/etc/s-box/cert.pem'
d_d='/etc/s-box/private.key'
fi
echo $sbfiles | xargs -n1 sed -i "119s#$c#$c_c#"
echo $sbfiles | xargs -n1 sed -i "120s#$d#$d_d#"
restartsb && sbshare > /dev/null 2>&1
blue "Anytls协议域名证书更换完毕"
else
red "当前未申请域名证书，不可切换。主菜单选择12，执行Acme证书申请" && sleep 2 && sb
fi
else
sb
fi
}

allports(){
vl_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].listen_port')
vm_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port')
hy2_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[2].listen_port')
tu5_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[3].listen_port')
an_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[4].listen_port')
hy2_ports=$(iptables -t nat -nL --line 2>/dev/null | grep -w "$hy2_port" | awk '{print $8}' | sed 's/dpts://; s/dpt://' | tr '\n' ',' | sed 's/,$//')
tu5_ports=$(iptables -t nat -nL --line 2>/dev/null | grep -w "$tu5_port" | awk '{print $8}' | sed 's/dpts://; s/dpt://' | tr '\n' ',' | sed 's/,$//')
[[ -n $hy2_ports ]] && hy2zfport="$hy2_ports" || hy2zfport="未添加"
[[ -n $tu5_ports ]] && tu5zfport="$tu5_ports" || tu5zfport="未添加"
}

changeport(){
sbactive
allports
fports(){
readp "\n请输入转发的端口范围 (1000-65535范围内，格式为 小数字:大数字)：" rangeport
if [[ $rangeport =~ ^([1-9][0-9]{3,4}:[1-9][0-9]{3,4})$ ]]; then
b=${rangeport%%:*}
c=${rangeport##*:}
if [[ $b -ge 1000 && $b -le 65535 && $c -ge 1000 && $c -le 65535 && $b -lt $c ]]; then
iptables -t nat -A PREROUTING -p udp --dport $rangeport -j DNAT --to-destination :$port
ip6tables -t nat -A PREROUTING -p udp --dport $rangeport -j DNAT --to-destination :$port
netfilter-persistent save >/dev/null 2>&1
service iptables save >/dev/null 2>&1
blue "已确认转发的端口范围：$rangeport"
else
red "输入的端口范围不在有效范围内" && fports
fi
else
red "输入格式不正确。格式为 小数字:大数字" && fports
fi
echo
}
fport(){
readp "\n请输入一个转发的端口 (1000-65535范围内)：" onlyport
if [[ $onlyport -ge 1000 && $onlyport -le 65535 ]]; then
iptables -t nat -A PREROUTING -p udp --dport $onlyport -j DNAT --to-destination :$port
ip6tables -t nat -A PREROUTING -p udp --dport $onlyport -j DNAT --to-destination :$port
netfilter-persistent save >/dev/null 2>&1
service iptables save >/dev/null 2>&1
blue "已确认转发的端口：$onlyport"
else
blue "输入的端口不在有效范围内" && fport
fi
echo
}

hy2deports(){
allports
hy2_ports=$(echo "$hy2_ports" | sed 's/,/,/g')
IFS=',' read -ra ports <<< "$hy2_ports"
for port in "${ports[@]}"; do
iptables -t nat -D PREROUTING -p udp --dport $port -j DNAT --to-destination :$hy2_port
ip6tables -t nat -D PREROUTING -p udp --dport $port -j DNAT --to-destination :$hy2_port
done
netfilter-persistent save >/dev/null 2>&1
service iptables save >/dev/null 2>&1
}
tu5deports(){
allports
tu5_ports=$(echo "$tu5_ports" | sed 's/,/,/g')
IFS=',' read -ra ports <<< "$tu5_ports"
for port in "${ports[@]}"; do
iptables -t nat -D PREROUTING -p udp --dport $port -j DNAT --to-destination :$tu5_port
ip6tables -t nat -D PREROUTING -p udp --dport $port -j DNAT --to-destination :$tu5_port
done
netfilter-persistent save >/dev/null 2>&1
service iptables save >/dev/null 2>&1
}

allports
green "Vless-reality、Vmess-ws、Anytls仅能更改唯一的端口，vmess-ws注意Argo端口重置"
green "Hysteria2与Tuic5支持更改主端口，也支持增删多个转发端口"
green "Hysteria2支持端口跳跃，且与Tuic5都支持多端口复用"
echo
green "1：Vless-reality协议 ${yellow}端口:$vl_port${plain}"
green "2：Vmess-ws协议 ${yellow}端口:$vm_port${plain}"
green "3：Hysteria2协议 ${yellow}端口:$hy2_port  转发多端口: $hy2zfport${plain}"
green "4：Tuic5协议 ${yellow}端口:$tu5_port  转发多端口: $tu5zfport${plain}"
if [[ "$sbnh" != "1.10" ]]; then
green "5：Anytls协议 ${yellow}端口:$an_port${plain}"
fi
green "0：返回上层"
readp "请选择要变更端口的协议：" menu
if [ "$menu" = "1" ]; then
vlport
echo $sbfiles | xargs -n1 sed -i "14s/$vl_port/$port_vl_re/"
restartsb && sbshare > /dev/null 2>&1
blue "Vless-reality端口更改完成"
echo
elif [ "$menu" = "5" ]; then
anport
echo $sbfiles | xargs -n1 sed -i "110s/$an_port/$port_an/"
restartsb && sbshare > /dev/null 2>&1
blue "Anytls端口更改完成"
echo
elif [ "$menu" = "2" ]; then
vmport
echo $sbfiles | xargs -n1 sed -i "41s/$vm_port/$port_vm_ws/"
restartsb && sbshare > /dev/null 2>&1
blue "Vmess-ws端口更改完成"
tls=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.enabled')
if [[ "$tls" = "false" ]]; then
blue "切记：如果Argo使用中，临时隧道必须重置，固定隧道的CF设置界面端口必须修改为$port_vm_ws"
else
blue "因TLS已开启，当前Argo隧道已不支持开启"
fi
echo
elif [ "$menu" = "3" ]; then
green "1：更换Hysteria2主端口 (原多端口自动重置删除)"
green "2：添加Hysteria2多端口"
green "3：重置删除Hysteria2多端口"
green "0：返回上层"
readp "请选择【0-3】：" menu
if [ "$menu" = "1" ]; then
if [ -n $hy2_ports ]; then
hy2deports
hy2port
echo $sbfiles | xargs -n1 sed -i "67s/$hy2_port/$port_hy2/"
restartsb && sbshare > /dev/null 2>&1
else
hy2port
echo $sbfiles | xargs -n1 sed -i "67s/$hy2_port/$port_hy2/"
restartsb && sbshare > /dev/null 2>&1
fi
blue "Hysteria2端口更改完成"
elif [ "$menu" = "2" ]; then
green "1：添加Hysteria2范围端口"
green "2：添加Hysteria2单端口"
green "0：返回上层"
readp "请选择【0-2】：" menu
port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[2].listen_port')
if [ "$menu" = "1" ]; then
fports && sbshare > /dev/null 2>&1 && changeport
elif [ "$menu" = "2" ]; then
fport && sbshare > /dev/null 2>&1 && changeport
else
changeport
fi
elif [ "$menu" = "3" ]; then
if [ -n $hy2_ports ]; then
hy2deports && sbshare > /dev/null 2>&1 && changeport
else
yellow "Hysteria2未设置多端口" && changeport
fi
else
changeport
fi

elif [ "$menu" = "4" ]; then
green "1：更换Tuic5主端口 (原多端口自动重置删除)"
green "2：添加Tuic5多端口"
green "3：重置删除Tuic5多端口"
green "0：返回上层"
readp "请选择【0-3】：" menu
if [ "$menu" = "1" ]; then
if [ -n $tu5_ports ]; then
tu5deports
tu5port
echo $sbfiles | xargs -n1 sed -i "89s/$tu5_port/$port_tu/"
restartsb && sbshare > /dev/null 2>&1
else
tu5port
echo $sbfiles | xargs -n1 sed -i "89s/$tu5_port/$port_tu/"
restartsb && sbshare > /dev/null 2>&1
fi
blue "Tuic5端口更改完成"
elif [ "$menu" = "2" ]; then
green "1：添加Tuic5范围端口"
green "2：添加Tuic5单端口"
green "0：返回上层"
readp "请选择【0-2】：" menu
port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[3].listen_port')
if [ "$menu" = "1" ]; then
fports && sbshare > /dev/null 2>&1 && changeport
elif [ "$menu" = "2" ]; then
fport && sbshare > /dev/null 2>&1 && changeport
else
changeport
fi
elif [ "$menu" = "3" ]; then
if [ -n $tu5_ports ]; then
tu5deports && sbshare > /dev/null 2>&1 && changeport
else
yellow "Tuic5未设置多端口" && changeport
fi
else
changeport
fi
else
sb
fi
}

changeuuid(){
echo
olduuid=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].users[0].uuid')
oldvmpath=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].transport.path')
green "全协议的uuid (密码)：$olduuid"
green "Vmess的path路径：$oldvmpath"
echo
yellow "1：自定义全协议的uuid (密码)"
yellow "2：自定义Vmess的path路径"
yellow "0：返回上层"
readp "请选择【0-2】：" menu
if [ "$menu" = "1" ]; then
readp "输入uuid，必须是uuid格式，不懂就回车(重置并随机生成uuid)：" menu
if [ -z "$menu" ]; then
uuid=$(/etc/s-box/sing-box generate uuid)
else
uuid=$menu
fi
echo $sbfiles | xargs -n1 sed -i "s/$olduuid/$uuid/g"
restartsb && sbshare > /dev/null 2>&1
blue "已确认uuid (密码)：${uuid}" 
blue "已确认Vmess的path路径：$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].transport.path')"
elif [ "$menu" = "2" ]; then
readp "输入Vmess的path路径，回车表示不变：" menu
if [ -z "$menu" ]; then
echo
else
vmpath=$menu
echo $sbfiles | xargs -n1 sed -i "50s#$oldvmpath#$vmpath#g"
restartsb && sbshare > /dev/null 2>&1
fi
blue "已确认Vmess的path路径：$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].transport.path')"
else
changeserv
fi
}

changeip(){
if [[ "$sbnh" == "1.10" ]]; then
v4v6
chip(){
rpip=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.outbounds[0].domain_strategy')
sed -i "111s/$rpip/$rrpip/g" /etc/s-box/sb10.json
cp /etc/s-box/sb10.json /etc/s-box/sb.json
restartsb
}
readp "1. IPV4优先\n2. IPV6优先\n3. 仅IPV4\n4. 仅IPV6\n请选择：" choose
if [[ $choose == "1" && -n $v4 ]]; then
rrpip="prefer_ipv4" && chip && v4_6="IPV4优先($v4)"
elif [[ $choose == "2" && -n $v6 ]]; then
rrpip="prefer_ipv6" && chip && v4_6="IPV6优先($v6)"
elif [[ $choose == "3" && -n $v4 ]]; then
rrpip="ipv4_only" && chip && v4_6="仅IPV4($v4)"
elif [[ $choose == "4" && -n $v6 ]]; then
rrpip="ipv6_only" && chip && v4_6="仅IPV6($v6)"
else 
red "当前不存在你选择的IPV4/IPV6地址，或者输入错误" && changeip
fi
blue "当前已更换的IP优先级：${v4_6}" && sb
else
red "仅支持1.10.7内核可用" && exit
fi
}

tgsbshow(){
echo
yellow "1：重置/设置Telegram机器人的Token、用户ID"
yellow "0：返回上层"
readp "请选择【0-1】：" menu
if [ "$menu" = "1" ]; then
rm -rf /etc/s-box/sbtg.sh
readp "输入Telegram机器人Token: " token
telegram_token=$token
readp "输入Telegram机器人用户ID: " userid
telegram_id=$userid
echo '#!/bin/bash
export LANG=en_US.UTF-8
sbnh=$(/etc/s-box/sing-box version 2>/dev/null | awk '/version/{print $NF}' 2>/dev/null | cut -d '.' -f 1,2)
total_lines=$(wc -l < /etc/s-box/clmi.yaml)
half=$((total_lines / 2))
head -n $half /etc/s-box/clmi.yaml > /etc/s-box/clash_meta_client1.txt
tail -n +$((half + 1)) /etc/s-box/clmi.yaml > /etc/s-box/clash_meta_client2.txt

total_lines=$(wc -l < /etc/s-box/sbox.json)
quarter=$((total_lines / 4))
head -n $quarter /etc/s-box/sbox.json > /etc/s-box/sing_box_client1.txt
tail -n +$((quarter + 1)) /etc/s-box/sbox.json | head -n $quarter > /etc/s-box/sing_box_client2.txt
tail -n +$((2 * quarter + 1)) /etc/s-box/sbox.json | head -n $quarter > /etc/s-box/sing_box_client3.txt
tail -n +$((3 * quarter + 1)) /etc/s-box/sbox.json > /etc/s-box/sing_box_client4.txt

m1=$(cat /etc/s-box/vl_reality.txt 2>/dev/null)
m2=$(cat /etc/s-box/vm_ws.txt 2>/dev/null)
m3=$(cat /etc/s-box/vm_ws_argols.txt 2>/dev/null)
m3_5=$(cat /etc/s-box/vm_ws_argogd.txt 2>/dev/null)
m4=$(cat /etc/s-box/vm_ws_tls.txt 2>/dev/null)
m5=$(cat /etc/s-box/hy2.txt 2>/dev/null)
m6=$(cat /etc/s-box/tuic5.txt 2>/dev/null)
m7=$(cat /etc/s-box/sing_box_client1.txt 2>/dev/null)
m7_5=$(cat /etc/s-box/sing_box_client2.txt 2>/dev/null)
m7_5_5=$(cat /etc/s-box/sing_box_client3.txt 2>/dev/null)
m7_5_5_5=$(cat /etc/s-box/sing_box_client4.txt 2>/dev/null)
m8=$(cat /etc/s-box/clash_meta_client1.txt 2>/dev/null)
m8_5=$(cat /etc/s-box/clash_meta_client2.txt 2>/dev/null)
m9=$(cat /etc/s-box/sing_box_gitlab.txt 2>/dev/null)
m10=$(cat /etc/s-box/clash_meta_gitlab.txt 2>/dev/null)
m11=$(cat /etc/s-box/jhsub.txt 2>/dev/null)
m12=$(cat /etc/s-box/an.txt 2>/dev/null)
message_text_m1=$(echo "$m1")
message_text_m2=$(echo "$m2")
message_text_m3=$(echo "$m3")
message_text_m3_5=$(echo "$m3_5")
message_text_m4=$(echo "$m4")
message_text_m5=$(echo "$m5")
message_text_m6=$(echo "$m6")
message_text_m7=$(echo "$m7")
message_text_m7_5=$(echo "$m7_5")
message_text_m7_5_5=$(echo "$m7_5_5")
message_text_m7_5_5_5=$(echo "$m7_5_5_5")
message_text_m8=$(echo "$m8")
message_text_m8_5=$(echo "$m8_5")
message_text_m9=$(echo "$m9")
message_text_m10=$(echo "$m10")
message_text_m11=$(echo "$m11")
message_text_m12=$(echo "$m12")
MODE=HTML
URL="https://api.telegram.org/bottelegram_token/sendMessage"
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀【 Vless-reality-vision 分享链接 】：支持v2rayng、nekobox "$'"'"'\n\n'"'"'"${message_text_m1}")
if [[ -f /etc/s-box/vm_ws.txt ]]; then
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀【 Vmess-ws 分享链接 】：支持v2rayng、nekobox "$'"'"'\n\n'"'"'"${message_text_m2}")
fi
if [[ -f /etc/s-box/vm_ws_argols.txt ]]; then
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀【 Vmess-ws(tls)+Argo临时域名分享链接 】：支持v2rayng、nekobox "$'"'"'\n\n'"'"'"${message_text_m3}")
fi
if [[ -f /etc/s-box/vm_ws_argogd.txt ]]; then
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀【 Vmess-ws(tls)+Argo固定域名分享链接 】：支持v2rayng、nekobox "$'"'"'\n\n'"'"'"${message_text_m3_5}")
fi
if [[ -f /etc/s-box/vm_ws_tls.txt ]]; then
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀【 Vmess-ws-tls 分享链接 】：支持v2rayng、nekobox "$'"'"'\n\n'"'"'"${message_text_m4}")
fi
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀【 Hysteria-2 分享链接 】：支持v2rayng、nekobox "$'"'"'\n\n'"'"'"${message_text_m5}")
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀【 Tuic-v5 分享链接 】：支持nekobox "$'"'"'\n\n'"'"'"${message_text_m6}")
if [[ "$sbnh" != "1.10" ]]; then
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀【 Anytls 分享链接 】：仅最新内核可用 "$'"'"'\n\n'"'"'"${message_text_m12}")
fi
if [[ -f /etc/s-box/sing_box_gitlab.txt ]]; then
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀【 Sing-box 订阅链接 】：支持SFA、SFW、SFI "$'"'"'\n\n'"'"'"${message_text_m9}")
else
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀【 Sing-box 配置文件(4段) 】：支持SFA、SFW、SFI "$'"'"'\n\n'"'"'"${message_text_m7}")
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=${message_text_m7_5}")
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=${message_text_m7_5_5}")
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=${message_text_m7_5_5_5}")
fi

if [[ -f /etc/s-box/clash_meta_gitlab.txt ]]; then
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀【 Mihomo 订阅链接 】：支持Mihomo相关客户端 "$'"'"'\n\n'"'"'"${message_text_m10}")
else
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀【 Mihomo 配置文件(2段) 】：支持Mihomo相关客户端 "$'"'"'\n\n'"'"'"${message_text_m8}")
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=${message_text_m8_5}")
fi
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀【 聚合节点 】：支持nekobox "$'"'"'\n\n'"'"'"${message_text_m11}")

if [ $? == 124 ];then
echo TG_api请求超时,请检查网络是否重启完成并是否能够访问TG
fi
resSuccess=$(echo "$res" | jq -r ".ok")
if [[ $resSuccess = "true" ]]; then
echo "TG推送成功";
else
echo "TG推送失败，请检查TG机器人Token和ID";
fi
' > /etc/s-box/sbtg.sh
sed -i "s/telegram_token/$telegram_token/g" /etc/s-box/sbtg.sh
sed -i "s/telegram_id/$telegram_id/g" /etc/s-box/sbtg.sh
green "设置完成！请确保TG机器人已处于激活状态！"
tgnotice
else
changeserv
fi
}

tgnotice(){
if [[ -f /etc/s-box/sbtg.sh ]]; then
green "请稍等5秒，TG机器人准备推送……"
sbshare > /dev/null 2>&1
bash /etc/s-box/sbtg.sh
else
yellow "未设置TG通知功能"
fi
exit
}

changeserv(){
sbactive
echo
green "Sing-box配置变更选择如下:"
readp "1：更换Reality域名伪装地址、切换自签证书与Acme域名证书、开关TLS\n2：更换全协议UUID(密码)、Vmess-Path路径\n3：设置Argo临时隧道、固定隧道\n4：切换IPV4或IPV6的代理优先级 (仅 1.10.7 内核可用)\n5：设置Telegram推送节点通知\n6：更换Warp-wireguard出站账户\n7：设置Gitlab订阅分享链接\n8：设置本地IP订阅分享链接\n9：设置所有Vmess节点的CDN优选地址\n0：返回上层\n请选择【0-9】：" menu
if [ "$menu" = "1" ];then
changeym
elif [ "$menu" = "2" ];then
changeuuid
elif [ "$menu" = "3" ];then
cfargo_ym
elif [ "$menu" = "4" ];then
changeip
elif [ "$menu" = "5" ];then
tgsbshow
elif [ "$menu" = "6" ];then
changewg
elif [ "$menu" = "7" ];then
gitlabsub
elif [ "$menu" = "8" ];then
ipsub
elif [ "$menu" = "9" ];then
vmesscfadd
else 
sb
fi
}

ipsub(){
subtokenipsub(){
echo
readp "输入订阅链接路径密码（回车表示使用当前UUID）：" menu
if [ -z "$menu" ]; then
subtoken="$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].users[0].uuid')"
else
subtoken="$menu"
fi
rm -rf /root/websbox/"$(cat /etc/s-box/subtoken.log 2>/dev/null)"
echo $subtoken > /etc/s-box/subtoken.log
green "订阅链接路径密码：$(cat /etc/s-box/subtoken.log 2>/dev/null)"
}
subportipsub(){
echo
readp "输入未被占用且可用的订阅链接端口（回车表示随机端口）：" menu
if [ -z "$menu" ]; then
subport=$(shuf -i 10000-65535 -n 1)
else
subport="$menu"
fi
echo $subport > /etc/s-box/subport.log
green "订阅链接端口：$(cat /etc/s-box/subport.log 2>/dev/null)"
}
echo
yellow "1：重置安装本地IP订阅链接"
yellow "2：更换订阅链接路径密码"
yellow "3：更换订阅链接端口"
yellow "4：卸载本地IP订阅链接"
yellow "0：返回上层"
readp "请选择【0-4】：" menu
if [ "$menu" = "1" ]; then
subtokenipsub && subportipsub
elif [ "$menu" = "2" ];then
subtokenipsub
elif [ "$menu" = "3" ];then
subportipsub
elif [ "$menu" = "4" ];then
kill -15 $(pgrep -f 'websbox' 2>/dev/null) >/dev/null 2>&1
crontab -l 2>/dev/null > /tmp/crontab.tmp
sed -i '/websbox/d' /tmp/crontab.tmp
crontab /tmp/crontab.tmp >/dev/null 2>&1
rm /tmp/crontab.tmp
rm -rf /root/websbox
rm -rf /etc/local.d/alpinesub.start
green "本地IP订阅链接已卸载完成" && sleep 3 && exit
else
changeserv
fi
echo
green "请稍后…………"
kill -15 $(pgrep -f 'websbox' 2>/dev/null) >/dev/null 2>&1
mkdir -p /root/websbox/"$(cat /etc/s-box/subtoken.log 2>/dev/null)"
ln -sf /etc/s-box/clmi.yaml /root/websbox/"$(cat /etc/s-box/subtoken.log 2>/dev/null)"/clmi.yaml
ln -sf /etc/s-box/sbox.json /root/websbox/"$(cat /etc/s-box/subtoken.log 2>/dev/null)"/sbox.json
ln -sf /etc/s-box/jhsub.txt /root/websbox/"$(cat /etc/s-box/subtoken.log 2>/dev/null)"/jhsub.txt
if command -v apk >/dev/null 2>&1; then
busybox-extras httpd -f -p "$(cat /etc/s-box/subport.log 2>/dev/null)" -h /root/websbox > /dev/null 2>&1 &
else
busybox httpd -f -p "$(cat /etc/s-box/subport.log 2>/dev/null)" -h /root/websbox > /dev/null 2>&1 &
fi
sleep 5
if command -v apk >/dev/null 2>&1; then
cat > /etc/local.d/alpinesub.start <<'EOF'
#!/bin/bash
sleep 10
busybox-extras httpd -f -p $(cat /etc/s-box/subport.log 2>/dev/null) -h /root/websbox > /dev/null 2>&1 &
EOF
chmod +x /etc/local.d/alpinesub.start
rc-update add local default >/dev/null 2>&1
else
crontab -l 2>/dev/null > /tmp/crontab.tmp
sed -i '/websbox/d' /tmp/crontab.tmp
echo '@reboot sleep 10 && /bin/bash -c "busybox httpd -f -p $(cat /etc/s-box/subport.log 2>/dev/null) -h /root/websbox > /dev/null 2>&1 &"' >> /tmp/crontab.tmp
crontab /tmp/crontab.tmp >/dev/null 2>&1
rm /tmp/crontab.tmp
fi
sbshare > /dev/null 2>&1
sleep 1 && green "本地IP订阅链接已更新完成" && sleep 3 && sb
}

vmesscfadd(){
echo
green "推荐使用稳定的世界大厂或组织的官方CDN域名作为CDN优选地址："
blue "www.visa.com.sg"
blue "www.wto.org"
blue "www.web.com"
blue "yg1.ygkkk.dpdns.org (yg1中的1，可换为1-11中任意数字，甬哥维护)"
echo
yellow "1：自定义Vmess-ws(tls)主协议节点的CDN优选地址"
yellow "2：针对选项1，重置客户端host/sni域名(IP解析到CF上的域名)"
yellow "3：自定义Vmess-ws(tls)-Argo节点的CDN优选地址"
yellow "0：返回上层"
readp "请选择【0-3】：" menu
if [ "$menu" = "1" ]; then
echo
green "请确保VPS的IP已解析到Cloudflare的域名上"
if [[ ! -f /etc/s-box/cfymjx.txt ]] 2>/dev/null; then
readp "输入客户端host/sni域名(IP解析到CF上的域名)：" menu
echo "$menu" > /etc/s-box/cfymjx.txt
fi
echo
readp "输入自定义的优选IP/域名：" menu
echo "$menu" > /etc/s-box/cfvmadd_local.txt
green "设置成功，选择主菜单9进行节点配置更新" && sleep 2 && vmesscfadd
elif  [ "$menu" = "2" ]; then
rm -rf /etc/s-box/cfymjx.txt
green "重置成功，可选择1重新设置" && sleep 2 && vmesscfadd
elif  [ "$menu" = "3" ]; then
readp "输入自定义的优选IP/域名：" menu
echo "$menu" > /etc/s-box/cfvmadd_argo.txt
green "设置成功，选择主菜单9进行节点配置更新" && sleep 2 && vmesscfadd
else
changeserv
fi
}

gitlabsub(){
echo
green "请确保Gitlab官网上已建立项目，已开启推送功能，已获取访问令牌"
yellow "1：重置/设置Gitlab订阅链接"
yellow "0：返回上层"
readp "请选择【0-1】：" menu
if [ "$menu" = "1" ]; then
cd /etc/s-box
readp "输入登录邮箱: " email
readp "输入访问令牌: " token
readp "输入用户名: " userid
readp "输入项目名: " project
echo
green "多台VPS共用一个令牌及项目名，可创建多个分支订阅链接"
green "回车跳过表示不新建，仅使用主分支main订阅链接(首台VPS建议回车跳过)"
readp "新建分支名称: " gitlabml
echo
if [[ -z "$gitlabml" ]]; then
gitlab_ml=''
git_sk=main
rm -rf /etc/s-box/gitlab_ml_ml
else
gitlab_ml=":${gitlabml}"
git_sk="${gitlabml}"
echo "${gitlab_ml}" > /etc/s-box/gitlab_ml_ml
fi
echo "$token" > /etc/s-box/gitlabtoken.txt
rm -rf /etc/s-box/.git
git init >/dev/null 2>&1
git add sbox.json clmi.yaml jhsub.txt >/dev/null 2>&1
git config --global user.email "${email}" >/dev/null 2>&1
git config --global user.name "${userid}" >/dev/null 2>&1
git commit -m "commit_add_$(date +"%F %T")" >/dev/null 2>&1
branches=$(git branch)
if [[ $branches == *master* ]]; then
git branch -m master main >/dev/null 2>&1
fi
git remote add origin https://${token}@gitlab.com/${userid}/${project}.git >/dev/null 2>&1
if [[ $(ls -a | grep '^\.git$') ]]; then
cat > /etc/s-box/gitpush.sh <<EOF
#!/usr/bin/expect
spawn bash -c "git push -f origin main${gitlab_ml}"
expect "Password for 'https://$(cat /etc/s-box/gitlabtoken.txt 2>/dev/null)@gitlab.com':"
send "$(cat /etc/s-box/gitlabtoken.txt 2>/dev/null)\r"
interact
EOF
chmod +x gitpush.sh
./gitpush.sh "git push -f origin main${gitlab_ml}" cat /etc/s-box/gitlabtoken.txt >/dev/null 2>&1
echo "https://gitlab.com/api/v4/projects/${userid}%2F${project}/repository/files/sbox.json/raw?ref=${git_sk}&private_token=${token}" > /etc/s-box/sing_box_gitlab.txt
echo "https://gitlab.com/api/v4/projects/${userid}%2F${project}/repository/files/clmi.yaml/raw?ref=${git_sk}&private_token=${token}" > /etc/s-box/clash_meta_gitlab.txt
echo "https://gitlab.com/api/v4/projects/${userid}%2F${project}/repository/files/jhsub.txt/raw?ref=${git_sk}&private_token=${token}" > /etc/s-box/jh_sub_gitlab.txt
clsbshow
else
yellow "设置Gitlab订阅链接失败，请反馈"
fi
cd
else
changeserv
fi
}

gitlabsubgo(){
cd /etc/s-box
if [[ $(ls -a | grep '^\.git$') ]]; then
if [ -f /etc/s-box/gitlab_ml_ml ]; then
gitlab_ml=$(cat /etc/s-box/gitlab_ml_ml)
fi
git rm --cached sbox.json clmi.yaml jhsub.txt >/dev/null 2>&1
git commit -m "commit_rm_$(date +"%F %T")" >/dev/null 2>&1
git add sbox.json clmi.yaml jhsub.txt >/dev/null 2>&1
git commit -m "commit_add_$(date +"%F %T")" >/dev/null 2>&1
chmod +x gitpush.sh
./gitpush.sh "git push -f origin main${gitlab_ml}" cat /etc/s-box/gitlabtoken.txt >/dev/null 2>&1
clsbshow
else
yellow "未设置Gitlab订阅链接"
fi
cd
}

clsbshow(){
green "当前Sing-box节点已更新并推送"
green "Sing-box订阅链接如下："
blue "$(cat /etc/s-box/sing_box_gitlab.txt 2>/dev/null)"
echo
green "Sing-box订阅链接二维码如下："
qrencode -o - -t ANSIUTF8 "$(cat /etc/s-box/sing_box_gitlab.txt 2>/dev/null)"
echo
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
green "当前Mihomo节点配置已更新并推送"
green "Mihomo订阅链接如下："
blue "$(cat /etc/s-box/clash_meta_gitlab.txt 2>/dev/null)"
echo
green "Mihomo订阅链接二维码如下："
qrencode -o - -t ANSIUTF8 "$(cat /etc/s-box/clash_meta_gitlab.txt 2>/dev/null)"
echo
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
green "当前聚合节点配置已更新并推送"
green "订阅链接如下："
blue "$(cat /etc/s-box/jh_sub_gitlab.txt 2>/dev/null)"
echo
yellow "可以在网页上输入订阅链接查看配置内容，如果无配置内容，请自检Gitlab相关设置并重置"
echo
}

warpwg(){
warpcode(){
reg(){
keypair=$(openssl genpkey -algorithm X25519 | openssl pkey -text -noout)
private_key=$(echo "$keypair" | awk '/priv:/{flag=1; next} /pub:/{flag=0} flag' | tr -d '[:space:]' | xxd -r -p | base64)
public_key=$(echo "$keypair" | awk '/pub:/{flag=1} flag' | tr -d '[:space:]' | xxd -r -p | base64)
response=$(curl -sL --tlsv1.3 --connect-timeout 3 --max-time 5 \
-X POST 'https://api.cloudflareclient.com/v0a2158/reg' \
-H 'CF-Client-Version: a-7.21-0721' \
-H 'Content-Type: application/json' \
-d '{
"key": "'"$public_key"'",
"tos": "'"$(date -u +'%Y-%m-%dT%H:%M:%S.000Z')"'"
}')
if [ -z "$response" ]; then
return 1
fi
echo "$response" | python3 -m json.tool 2>/dev/null | sed "/\"account_type\"/i\         \"private_key\": \"$private_key\","
}
reserved(){
reserved_str=$(echo "$warp_info" | grep 'client_id' | cut -d\" -f4)
reserved_hex=$(echo "$reserved_str" | base64 -d | xxd -p)
reserved_dec=$(echo "$reserved_hex" | fold -w2 | while read HEX; do printf '%d ' "0x${HEX}"; done | awk '{print "["$1", "$2", "$3"]"}')
echo -e "{\n    \"reserved_dec\": $reserved_dec,"
echo -e "    \"reserved_hex\": \"0x$reserved_hex\","
echo -e "    \"reserved_str\": \"$reserved_str\"\n}"
}
result() {
echo "$warp_reserved" | grep -P "reserved" | sed "s/ //g" | sed 's/:"/: "/g' | sed 's/:\[/: \[/g' | sed 's/\([0-9]\+\),\([0-9]\+\),\([0-9]\+\)/\1, \2, \3/' | sed 's/^"/    "/g' | sed 's/"$/",/g'
echo "$warp_info" | grep -P "(private_key|public_key|\"v4\": \"172.16.0.2\"|\"v6\": \"2)" | sed "s/ //g" | sed 's/:"/: "/g' | sed 's/^"/    "/g'
echo "}"
}
warp_info=$(reg) 
warp_reserved=$(reserved) 
result
}
output=$(warpcode)
if ! echo "$output" 2>/dev/null | grep -w "private_key" > /dev/null; then
v6=2606:4700:110:860e:738f:b37:f15:d38d
pvk=g9I2sgUH6OCbIBTehkEfVEnuvInHYZvPOFhWchMLSc4=
res=[33,217,129]
else
pvk=$(echo "$output" | sed -n 4p | awk '{print $2}' | tr -d ' "' | sed 's/.$//')
v6=$(echo "$output" | sed -n 7p | awk '{print $2}' | tr -d ' "')
res=$(echo "$output" | sed -n 1p | awk -F":" '{print $NF}' | tr -d ' ' | sed 's/.$//')
fi
blue "Private_key私钥：$pvk"
blue "IPV6地址：$v6"
blue "reserved值：$res"
}

changewg(){
[[ "$sbnh" == "1.10" ]] && num=10 || num=11
if [[ "$sbnh" == "1.10" ]]; then
wgipv6=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.outbounds[] | select(.type == "wireguard") | .local_address[1] | split("/")[0]')
wgprkey=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.outbounds[] | select(.type == "wireguard") | .private_key')
wgres=$(sed -n '165s/.*\[\(.*\)\].*/\1/p' /etc/s-box/sb.json)
wgip=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.outbounds[] | select(.type == "wireguard") | .server')
wgpo=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.outbounds[] | select(.type == "wireguard") | .server_port')
else
wgipv6=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.endpoints[] | .address[1] | split("/")[0]')
wgprkey=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.endpoints[] | .private_key')
wgres=$(sed -n '142s/.*\[\(.*\)\].*/\1/p' /etc/s-box/sb.json)
wgip=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.endpoints[] | .peers[].address')
wgpo=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.endpoints[] | .peers[].port')
fi
echo
green "当前warp-wireguard可更换的参数如下："
green "Private_key私钥：$wgprkey"
green "IPV6地址：$wgipv6"
green "Reserved值：$wgres"
green "对端IP：$wgip:$wgpo"
echo
yellow "1：更换warp-wireguard账户"
yellow "0：返回上层"
readp "请选择【0-1】：" menu
if [ "$menu" = "1" ]; then
green "最新随机生成普通warp-wireguard账户如下"
warpwg
echo
readp "输入自定义Private_key：" menu
sed -i "163s#$wgprkey#$menu#g" /etc/s-box/sb10.json
sed -i "132s#$wgprkey#$menu#g" /etc/s-box/sb11.json
readp "输入自定义IPV6地址：" menu
sed -i "161s/$wgipv6/$menu/g" /etc/s-box/sb10.json
sed -i "130s/$wgipv6/$menu/g" /etc/s-box/sb11.json
readp "输入自定义Reserved值 (格式：数字,数字,数字)，如无值则回车跳过：" menu
if [ -z "$menu" ]; then
menu=0,0,0
fi
sed -i "165s/$wgres/$menu/g" /etc/s-box/sb10.json
sed -i "142s/$wgres/$menu/g" /etc/s-box/sb11.json
rm -rf /etc/s-box/sb.json
cp /etc/s-box/sb${num}.json /etc/s-box/sb.json
restartsb
green "设置结束"
else
changeserv
fi
}

sbymfl(){
sbport=$(cat /etc/s-box/sbwpph.log 2>/dev/null | awk '{print $3}' | awk -F":" '{print $NF}') 
sbport=${sbport:-'40000'}
resv1=$(curl -sm3 --socks5 localhost:$sbport icanhazip.com)
resv2=$(curl -sm3 -x socks5h://localhost:$sbport icanhazip.com)
if [[ -z $resv1 && -z $resv2 ]]; then
warp_s4_ip='Socks5-IPV4未启动，黑名单模式'
warp_s6_ip='Socks5-IPV6未启动，黑名单模式'
else
warp_s4_ip='Socks5-IPV4可用'
warp_s6_ip='Socks5-IPV6自测'
fi
v4v6
if [[ -z $v4 ]]; then
vps_ipv4='无本地IPV4，黑名单模式'      
vps_ipv6="当前IP：$v6"
elif [[ -n $v4 &&  -n $v6 ]]; then
vps_ipv4="当前IP：$v4"    
vps_ipv6="当前IP：$v6"
else
vps_ipv4="当前IP：$v4"    
vps_ipv6='无本地IPV6，黑名单模式'
fi
unset swg4 swd4 swd6 swg6 ssd4 ssg4 ssd6 ssg6 sad4 sag4 sad6 sag6
wd4=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[1].domain_suffix | join(" ")')
wg4=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[1].geosite | join(" ")' 2>/dev/null)
if [[ "$wd4" == "yg_kkk" && ("$wg4" == "yg_kkk" || -z "$wg4") ]]; then
wfl4="${yellow}【warp出站IPV4可用】未分流${plain}"
else
if [[ "$wd4" != "yg_kkk" ]]; then
swd4="$wd4 "
fi
if [[ "$wg4" != "yg_kkk" ]]; then
swg4=$wg4
fi
wfl4="${yellow}【warp出站IPV4可用】已分流：$swd4$swg4${plain} "
fi

wd6=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[2].domain_suffix | join(" ")')
wg6=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[2].geosite | join(" ")' 2>/dev/null)
if [[ "$wd6" == "yg_kkk" && ("$wg6" == "yg_kkk"|| -z "$wg6") ]]; then
wfl6="${yellow}【warp出站IPV6自测】未分流${plain}"
else
if [[ "$wd6" != "yg_kkk" ]]; then
swd6="$wd6 "
fi
if [[ "$wg6" != "yg_kkk" ]]; then
swg6=$wg6
fi
wfl6="${yellow}【warp出站IPV6自测】已分流：$swd6$swg6${plain} "
fi

sd4=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[3].domain_suffix | join(" ")')
sg4=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[3].geosite | join(" ")' 2>/dev/null)
if [[ "$sd4" == "yg_kkk" && ("$sg4" == "yg_kkk" || -z "$sg4") ]]; then
sfl4="${yellow}【$warp_s4_ip】未分流${plain}"
else
if [[ "$sd4" != "yg_kkk" ]]; then
ssd4="$sd4 "
fi
if [[ "$sg4" != "yg_kkk" ]]; then
ssg4=$sg4
fi
sfl4="${yellow}【$warp_s4_ip】已分流：$ssd4$ssg4${plain} "
fi

sd6=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[4].domain_suffix | join(" ")')
sg6=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[4].geosite | join(" ")' 2>/dev/null)
if [[ "$sd6" == "yg_kkk" && ("$sg6" == "yg_kkk" || -z "$sg6") ]]; then
sfl6="${yellow}【$warp_s6_ip】未分流${plain}"
else
if [[ "$sd6" != "yg_kkk" ]]; then
ssd6="$sd6 "
fi
if [[ "$sg6" != "yg_kkk" ]]; then
ssg6=$sg6
fi
sfl6="${yellow}【$warp_s6_ip】已分流：$ssd6$ssg6${plain} "
fi

ad4=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[5].domain_suffix | join(" ")' 2>/dev/null)
ag4=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[5].geosite | join(" ")' 2>/dev/null)
if [[ ("$ad4" == "yg_kkk" || -z "$ad4") && ("$ag4" == "yg_kkk" || -z "$ag4") ]]; then
adfl4="${yellow}【$vps_ipv4】未分流${plain}" 
else
if [[ "$ad4" != "yg_kkk" ]]; then
sad4="$ad4 "
fi
if [[ "$ag4" != "yg_kkk" ]]; then
sag4=$ag4
fi
adfl4="${yellow}【$vps_ipv4】已分流：$sad4$sag4${plain} "
fi

ad6=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[6].domain_suffix | join(" ")' 2>/dev/null)
ag6=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[6].geosite | join(" ")' 2>/dev/null)
if [[ ("$ad6" == "yg_kkk" || -z "$ad6") && ("$ag6" == "yg_kkk" || -z "$ag6") ]]; then
adfl6="${yellow}【$vps_ipv6】未分流${plain}" 
else
if [[ "$ad6" != "yg_kkk" ]]; then
sad6="$ad6 "
fi
if [[ "$ag6" != "yg_kkk" ]]; then
sag6=$ag6
fi
adfl6="${yellow}【$vps_ipv6】已分流：$sad6$sag6${plain} "
fi
}

changefl(){
sbactive
blue "对所有协议进行统一的域名分流"
blue "为确保分流可用，双栈IP（IPV4/IPV6）分流模式为优先模式"
blue "warp-wireguard默认开启 (选项1与2)"
blue "socks5需要在VPS安装warp官方客户端或者WARP-plus-Socks5-赛风VPN (选项3与4)"
blue "VPS本地出站分流(选项5与6)"
echo
[[ "$sbnh" == "1.10" ]] && blue "当前Sing-box内核支持geosite分流方式" || blue "当前Sing-box内核不支持geosite分流方式，仅支持分流2、3、5、6选项"
echo
yellow "注意："
yellow "一、完整域名方式只能填完整域名 (例：谷歌网站填写：www.google.com)"
yellow "二、geosite方式须填写geosite规则名 (例：奈飞填写:netflix ；迪士尼填写:disney ；ChatGPT填写:openai ；全局且绕过中国填写:geolocation-!cn)"
yellow "三、同一个完整域名或者geosite切勿重复分流"
yellow "四、如分流通道中有个别通道无网络，所填分流为黑名单模式，即屏蔽该网站访问"
changef
}

changef(){
[[ "$sbnh" == "1.10" ]] && num=10 || num=11
sbymfl
echo
[[ "$sbnh" != "1.10" ]] && wfl4='暂不支持' sfl6='暂不支持' adfl4='暂不支持' adfl6='暂不支持'
green "1：重置warp-wireguard-ipv4优先分流域名 $wfl4"
green "2：重置warp-wireguard-ipv6优先分流域名 $wfl6"
green "3：重置warp-socks5-ipv4优先分流域名 $sfl4"
green "4：重置warp-socks5-ipv6优先分流域名 $sfl6"
green "5：重置VPS本地ipv4优先分流域名 $adfl4"
green "6：重置VPS本地ipv6优先分流域名 $adfl6"
green "0：返回上层"
echo
readp "请选择：" menu

if [ "$menu" = "1" ]; then
if [[ "$sbnh" == "1.10" ]]; then
readp "1：使用完整域名方式\n2：使用geosite方式\n3：返回上层\n请选择：" menu
if [ "$menu" = "1" ]; then
readp "每个域名之间留空格，回车跳过表示重置清空warp-wireguard-ipv4的完整域名方式的分流通道)：" w4flym
if [ -z "$w4flym" ]; then
w4flym='"yg_kkk"'
else
w4flym="$(echo "$w4flym" | sed 's/ /","/g')"
w4flym="\"$w4flym\""
fi
sed -i "184s/.*/$w4flym/" /etc/s-box/sb.json /etc/s-box/sb10.json
restartsb
changef
elif [ "$menu" = "2" ]; then
readp "每个域名之间留空格，回车跳过表示重置清空warp-wireguard-ipv4的geosite方式的分流通道)：" w4flym
if [ -z "$w4flym" ]; then
w4flym='"yg_kkk"'
else
w4flym="$(echo "$w4flym" | sed 's/ /","/g')"
w4flym="\"$w4flym\""
fi
sed -i "187s/.*/$w4flym/" /etc/s-box/sb.json /etc/s-box/sb10.json
restartsb
changef
else
changef
fi
else
yellow "遗憾！当前暂时只支持warp-wireguard-ipv6，如需要warp-wireguard-ipv4，请切换1.10系列内核" && exit
fi

elif [ "$menu" = "2" ]; then
readp "1：使用完整域名方式\n2：使用geosite方式\n3：返回上层\n请选择：" menu
if [ "$menu" = "1" ]; then
readp "每个域名之间留空格，回车跳过表示重置清空warp-wireguard-ipv6的完整域名方式的分流通道：" w6flym
if [ -z "$w6flym" ]; then
w6flym='"yg_kkk"'
else
w6flym="$(echo "$w6flym" | sed 's/ /","/g')"
w6flym="\"$w6flym\""
fi
sed -i "193s/.*/$w6flym/" /etc/s-box/sb10.json
sed -i "184s/.*/$w6flym/" /etc/s-box/sb11.json
sed -i "196s/.*/$w6flym/" /etc/s-box/sb11.json
cp /etc/s-box/sb${num}.json /etc/s-box/sb.json
restartsb
changef
elif [ "$menu" = "2" ]; then
if [[ "$sbnh" == "1.10" ]]; then
readp "每个域名之间留空格，回车跳过表示重置清空warp-wireguard-ipv6的geosite方式的分流通道：" w6flym
if [ -z "$w6flym" ]; then
w6flym='"yg_kkk"'
else
w6flym="$(echo "$w6flym" | sed 's/ /","/g')"
w6flym="\"$w6flym\""
fi
sed -i "196s/.*/$w6flym/" /etc/s-box/sb.json /etc/s-box/sb10.json
restartsb
changef
else
yellow "遗憾！当前Sing-box内核不支持geosite分流方式。如要支持，请切换1.10系列内核" && exit
fi
else
changef
fi

elif [ "$menu" = "3" ]; then
readp "1：使用完整域名方式\n2：使用geosite方式\n3：返回上层\n请选择：" menu
if [ "$menu" = "1" ]; then
readp "每个域名之间留空格，回车跳过表示重置清空warp-socks5-ipv4的完整域名方式的分流通道：" s4flym
if [ -z "$s4flym" ]; then
s4flym='"yg_kkk"'
else
s4flym="$(echo "$s4flym" | sed 's/ /","/g')"
s4flym="\"$s4flym\""
fi
sed -i "202s/.*/$s4flym/" /etc/s-box/sb10.json
sed -i "177s/.*/$s4flym/" /etc/s-box/sb11.json
sed -i "190s/.*/$s4flym/" /etc/s-box/sb11.json
cp /etc/s-box/sb${num}.json /etc/s-box/sb.json
restartsb
changef
elif [ "$menu" = "2" ]; then
if [[ "$sbnh" == "1.10" ]]; then
readp "每个域名之间留空格，回车跳过表示重置清空warp-socks5-ipv4的geosite方式的分流通道：" s4flym
if [ -z "$s4flym" ]; then
s4flym='"yg_kkk"'
else
s4flym="$(echo "$s4flym" | sed 's/ /","/g')"
s4flym="\"$s4flym\""
fi
sed -i "205s/.*/$s4flym/" /etc/s-box/sb.json /etc/s-box/sb10.json
restartsb
changef
else
yellow "遗憾！当前Sing-box内核不支持geosite分流方式。如要支持，请切换1.10系列内核" && exit
fi
else
changef
fi

elif [ "$menu" = "4" ]; then
if [[ "$sbnh" == "1.10" ]]; then
readp "1：使用完整域名方式\n2：使用geosite方式\n3：返回上层\n请选择：" menu
if [ "$menu" = "1" ]; then
readp "每个域名之间留空格，回车跳过表示重置清空warp-socks5-ipv6的完整域名方式的分流通道：" s6flym
if [ -z "$s6flym" ]; then
s6flym='"yg_kkk"'
else
s6flym="$(echo "$s6flym" | sed 's/ /","/g')"
s6flym="\"$s6flym\""
fi
sed -i "211s/.*/$s6flym/" /etc/s-box/sb.json /etc/s-box/sb10.json
restartsb
changef
elif [ "$menu" = "2" ]; then
readp "每个域名之间留空格，回车跳过表示重置清空warp-socks5-ipv6的geosite方式的分流通道：" s6flym
if [ -z "$s6flym" ]; then
s6flym='"yg_kkk"'
else
s6flym="$(echo "$s6flym" | sed 's/ /","/g')"
s6flym="\"$s6flym\""
fi
sed -i "214s/.*/$s6flym/" /etc/s-box/sb.json /etc/s-box/sb10.json
restartsb
changef
else
changef
fi
else
yellow "遗憾！当前暂时只支持warp-socks5-ipv4，如需要warp-socks5-ipv6，请切换1.10系列内核" && exit
fi

elif [ "$menu" = "5" ]; then
if [[ "$sbnh" == "1.10" ]]; then
readp "1：使用完整域名方式\n2：使用geosite方式\n3：返回上层\n请选择：" menu
if [ "$menu" = "1" ]; then
readp "每个域名之间留空格，回车跳过表示重置清空VPS本地ipv4的完整域名方式的分流通道：" ad4flym
if [ -z "$ad4flym" ]; then
ad4flym='"yg_kkk"'
else
ad4flym="$(echo "$ad4flym" | sed 's/ /","/g')"
ad4flym="\"$ad4flym\""
fi
sed -i "220s/.*/$ad4flym/" /etc/s-box/sb10.json /etc/s-box/sb.json
restartsb
changef
elif [ "$menu" = "2" ]; then
if [[ "$sbnh" == "1.10" ]]; then
readp "每个域名之间留空格，回车跳过表示重置清空VPS本地ipv4的geosite方式的分流通道：" ad4flym
if [ -z "$ad4flym" ]; then
ad4flym='"yg_kkk"'
else
ad4flym="$(echo "$ad4flym" | sed 's/ /","/g')"
ad4flym="\"$ad4flym\""
fi
sed -i "223s/.*/$ad4flym/" /etc/s-box/sb.json /etc/s-box/sb10.json
restartsb
changef
else
yellow "遗憾！当前Sing-box内核不支持geosite分流方式。如要支持，请切换1.10系列内核" && exit
fi
else
changef
fi
else
yellow "遗憾！如需要VPS本地ipv4分流，请切换1.10系列内核" && exit
fi

elif [ "$menu" = "6" ]; then
if [[ "$sbnh" == "1.10" ]]; then
readp "1：使用完整域名方式\n2：使用geosite方式\n3：返回上层\n请选择：" menu
if [ "$menu" = "1" ]; then
readp "每个域名之间留空格，回车跳过表示重置清空VPS本地ipv6的完整域名方式的分流通道：" ad6flym
if [ -z "$ad6flym" ]; then
ad6flym='"yg_kkk"'
else
ad6flym="$(echo "$ad6flym" | sed 's/ /","/g')"
ad6flym="\"$ad6flym\""
fi
sed -i "229s/.*/$ad6flym/" /etc/s-box/sb10.json /etc/s-box/sb.json
restartsb
changef
elif [ "$menu" = "2" ]; then
if [[ "$sbnh" == "1.10" ]]; then
readp "每个域名之间留空格，回车跳过表示重置清空VPS本地ipv6的geosite方式的分流通道：" ad6flym
if [ -z "$ad6flym" ]; then
ad6flym='"yg_kkk"'
else
ad6flym="$(echo "$ad6flym" | sed 's/ /","/g')"
ad6flym="\"$ad6flym\""
fi
sed -i "232s/.*/$ad6flym/" /etc/s-box/sb.json /etc/s-box/sb10.json
restartsb
changef
else
yellow "遗憾！当前Sing-box内核不支持geosite分流方式。如要支持，请切换1.10系列内核" && exit
fi
else
changef
fi
else
yellow "遗憾！如需要VPS本地ipv6分流，请切换1.10系列内核" && exit
fi
else
sb
fi
}

restartsb(){
if command -v apk >/dev/null 2>&1; then
rc-service sing-box restart
else
systemctl enable sing-box
systemctl start sing-box
systemctl restart sing-box
fi
}

stclre(){
if [[ ! -f '/etc/s-box/sb.json' ]]; then
red "未正常安装Sing-box" && exit
fi
readp "1：重启\n2：关闭\n请选择：" menu
if [ "$menu" = "1" ]; then
restartsb
sbactive
green "Sing-box服务已重启\n" && sleep 3 && sb
elif [ "$menu" = "2" ]; then
if command -v apk >/dev/null 2>&1; then
rc-service sing-box stop
else
systemctl stop sing-box
systemctl disable sing-box
fi
green "Sing-box服务已关闭\n" && sleep 3 && sb
else
stclre
fi
}

cronsb(){
uncronsb
crontab -l 2>/dev/null > /tmp/crontab.tmp
echo "0 1 * * * systemctl restart sing-box;rc-service sing-box restart" >> /tmp/crontab.tmp
crontab /tmp/crontab.tmp >/dev/null 2>&1
rm /tmp/crontab.tmp
}
uncronsb(){
crontab -l 2>/dev/null > /tmp/crontab.tmp
sed -i '/sing-box/d' /tmp/crontab.tmp
sed -i '/sbwpph/d' /tmp/crontab.tmp
sed -i '/url http/d' /tmp/crontab.tmp
sed -i '/websbox/d' /tmp/crontab.tmp
crontab /tmp/crontab.tmp >/dev/null 2>&1
rm /tmp/crontab.tmp
}

lnsb(){
rm -rf /usr/bin/sb
curl -L -o /usr/bin/sb -# --retry 2 --insecure https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh
chmod +x /usr/bin/sb
}

upsbyg(){
if [[ ! -f '/usr/bin/sb' ]]; then
red "未正常安装Sing-box-yg" && exit
fi
lnsb
curl -sL https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/version | awk -F "更新内容" '{print $1}' | head -n 1 > /etc/s-box/v
green "Sing-box-yg安装脚本升级成功" && sleep 5 && sb
}

lapre(){
json=$(curl -Ls --max-time 3 https://data.jsdelivr.com/v1/package/gh/SagerNet/sing-box)
if echo "$json"|grep -q '"versions"'; then
latcore=$(echo "$json"|grep -Eo '"[0-9.]+",'|head -n1|tr -d '",')
precore=$(echo "$json"|grep -Eo '"[0-9.]*-[^"]*"'|head -n1|tr -d '",')
else
page=$(curl -Ls --max-time 3 https://github.com/SagerNet/sing-box/releases)
latcore=$(echo "$page"|grep -oE 'tag/v[0-9.]+'|head -n1|cut -d'v' -f2)
precore=$(echo "$page"|grep -oE '/tag/v[0-9.]+-[^"]+'|head -n1|cut -d'v' -f2)
fi
inscore=$(/etc/s-box/sing-box version 2>/dev/null | awk '/version/{print $NF}')
}

upsbcroe(){
sbactive
lapre
[[ $inscore =~ ^[0-9.]+$ ]] && lat="【已安装v$inscore】" || pre="【已安装v$inscore】"
green "1：升级/切换Sing-box最新正式版 v$latcore  ${bblue}${lat}${plain}"
green "2：升级/切换Sing-box最新测试版 v$precore  ${bblue}${pre}${plain}"
green "3：切换Sing-box某个正式版或测试版，需指定版本号 (建议1.10.0以上版本)"
green "0：返回上层"
readp "请选择【0-3】：" menu
if [ "$menu" = "1" ]; then
upcore=$(curl -Ls https://github.com/SagerNet/sing-box/releases/latest | grep -oP 'tag/v\K[0-9.]+' | head -n 1)
elif [ "$menu" = "2" ]; then
upcore=$(curl -Ls https://github.com/SagerNet/sing-box/releases | grep -oP '/tag/v\K[0-9.]+-[^"]+' | head -n 1)
elif [ "$menu" = "3" ]; then
echo
red "注意: 版本号在 https://github.com/SagerNet/sing-box/tags 可查，且有Downloads字样 (必须1.10系或者1.30系以上版本)"
green "正式版版本号格式：数字.数字.数字 (例：1.10.7   注意，1.10系列内核支持geosite分流，1.10以上内核不支持geosite分流"
green "测试版版本号格式：数字.数字.数字-alpha或rc或beta.数字 (例：1.13.0-alpha或rc或beta.1)"
readp "请输入Sing-box版本号：" upcore
else
sb
fi
if [[ -n $upcore ]]; then
green "开始下载并更新Sing-box内核……请稍等"
sbname="sing-box-$upcore-linux-$cpu"
curl -L -o /etc/s-box/sing-box.tar.gz  -# --retry 2 https://github.com/SagerNet/sing-box/releases/download/v$upcore/$sbname.tar.gz
if [[ -f '/etc/s-box/sing-box.tar.gz' ]]; then
tar xzf /etc/s-box/sing-box.tar.gz -C /etc/s-box
mv /etc/s-box/$sbname/sing-box /etc/s-box
rm -rf /etc/s-box/{sing-box.tar.gz,$sbname}
if [[ -f '/etc/s-box/sing-box' ]]; then
chown root:root /etc/s-box/sing-box
chmod +x /etc/s-box/sing-box
sbnh=$(/etc/s-box/sing-box version 2>/dev/null | awk '/version/{print $NF}' 2>/dev/null | cut -d '.' -f 1,2)
[[ "$sbnh" == "1.10" ]] && num=10 || num=11
rm -rf /etc/s-box/sb.json
cp /etc/s-box/sb${num}.json /etc/s-box/sb.json
restartsb && sbshare > /dev/null 2>&1
blue "成功升级/切换 Sing-box 内核版本：$(/etc/s-box/sing-box version | awk '/version/{print $NF}')" && sleep 3 && sb
else
red "下载 Sing-box 内核不完整，安装失败，请重试" && upsbcroe
fi
else
red "下载 Sing-box 内核失败或不存在，请重试" && upsbcroe
fi
else
red "版本号检测出错，请重试" && upsbcroe
fi
}

unins(){
if command -v apk >/dev/null 2>&1; then
for svc in sing-box argo; do
rc-service "$svc" stop >/dev/null 2>&1
rc-update del "$svc" default >/dev/null 2>&1
done
rm -rf /etc/init.d/{sing-box,argo}
else
for svc in sing-box argo; do
systemctl stop "$svc" >/dev/null 2>&1
systemctl disable "$svc" >/dev/null 2>&1
done
rm -rf /etc/systemd/system/{sing-box.service,argo.service}
fi
ps -ef | grep "[l]ocalhost:$(sed 's://.*::g' /etc/s-box/sb.json 2>/dev/null | jq -r '.inbounds[1].listen_port')" | awk '{print $2}' | xargs kill 2>/dev/null
ps -ef | grep '[s]bwpph' | awk '{print $2}' | xargs kill 2>/dev/null
kill -15 $(pgrep -f 'websbox' 2>/dev/null) >/dev/null 2>&1
rm -rf /etc/s-box sbyg_update /usr/bin/sb /root/geoip.db /root/geosite.db /root/warpapi /root/warpip /root/websbox
rm -f /etc/local.d/alpineargo.start /etc/local.d/alpinesub.start /etc/local.d/alpinews5.start
uncronsb
iptables -t nat -F PREROUTING >/dev/null 2>&1
netfilter-persistent save >/dev/null 2>&1
service iptables save >/dev/null 2>&1
green "Sing-box卸载完成！"
blue "欢迎继续使用Sing-box-yg脚本：bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh)"
echo
}

sblog(){
red "退出日志 Ctrl+c"
if command -v apk >/dev/null 2>&1; then
yellow "暂不支持alpine查看日志"
else
#systemctl status sing-box
journalctl -u sing-box.service -o cat -f
fi
}

sbactive(){
if [[ ! -f /etc/s-box/sb.json ]]; then
red "未正常启动Sing-box，请卸载重装或者选择10查看运行日志反馈" && exit
fi
}

sbshare(){
rm -rf /etc/s-box/{jhdy,vl_reality,vm_ws_argols,vm_ws_argogd,vm_ws,vm_ws_tls,hy2,tuic5,an}.txt
result_vl_vm_hy_tu && resvless && resvmess && reshy2 && restu5
if [[ "$sbnh" != "1.10" ]]; then
resan
fi
cat /etc/s-box/vl_reality.txt 2>/dev/null >> /etc/s-box/jhdy.txt
cat /etc/s-box/vm_ws_argols.txt 2>/dev/null >> /etc/s-box/jhdy.txt
cat /etc/s-box/vm_ws_argogd.txt 2>/dev/null >> /etc/s-box/jhdy.txt
cat /etc/s-box/vm_ws.txt 2>/dev/null >> /etc/s-box/jhdy.txt
cat /etc/s-box/vm_ws_tls.txt 2>/dev/null >> /etc/s-box/jhdy.txt
cat /etc/s-box/hy2.txt 2>/dev/null >> /etc/s-box/jhdy.txt
cat /etc/s-box/tuic5.txt 2>/dev/null >> /etc/s-box/jhdy.txt
cat /etc/s-box/an.txt 2>/dev/null >> /etc/s-box/jhdy.txt
v2sub=$(cat /etc/s-box/jhdy.txt 2>/dev/null)
echo "$v2sub" > /etc/s-box/jhsub.txt
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
red "🚀【 聚合节点 】节点信息如下：" && sleep 2
echo
echo "分享链接"
echo -e "${yellow}$v2sub${plain}"
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
sb_client
}

clash_sb_share(){
sbactive
echo
yellow "1：刷新并查看各协议分享链接、二维码、聚合节点"
yellow "2：刷新并查看Mihomo、Sing-box客户端SFA/SFI/SFW三合一配置、Gitlab私有订阅链接"
yellow "3：推送最新节点配置信息(选项1+选项2)到Telegram通知"
yellow "0：返回上层"
readp "请选择【0-3】：" menu
if [ "$menu" = "1" ]; then
sbshare
elif  [ "$menu" = "2" ]; then
green "请稍等……"
sbshare > /dev/null 2>&1
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
red "Gitlab订阅链接如下："
gitlabsubgo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
red "🚀Mihomo配置文件显示如下："
red "文件目录 /etc/s-box/clmi.yaml ，复制自建以yaml文件格式为准" && sleep 2
echo
cat /etc/s-box/clmi.yaml
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
red "🚀SFA/SFI/SFW配置文件显示如下："
red "安卓SFA、苹果SFI，win电脑官方文件包SFW请到甬哥Github项目自行下载，"
red "文件目录 /etc/s-box/sbox.json ，复制自建以json文件格式为准" && sleep 2
echo
cat /etc/s-box/sbox.json
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
elif [ "$menu" = "3" ]; then
tgnotice
else
sb
fi
}

acme(){
#bash <(curl -Ls https://gitlab.com/rwkgyg/acme-script/raw/main/acme.sh)
bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/acme-yg/main/acme.sh)
}
cfwarp(){
#bash <(curl -Ls https://gitlab.com/rwkgyg/CFwarp/raw/main/CFwarp.sh)
bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/warp-yg/main/CFwarp.sh)
}
bbr(){
if [[ $vi =~ lxc|openvz ]]; then
yellow "当前VPS的架构为 $vi，不支持开启原版BBR加速" && sleep 2 && exit 
else
green "点击任意键，即可开启BBR加速，ctrl+c退出"
bash <(curl -Ls https://raw.githubusercontent.com/teddysun/across/master/bbr.sh)
fi
}

showprotocol(){
allports
sbymfl
tls=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.enabled')
if [[ "$tls" = "false" ]]; then
if ps -ef 2>/dev/null | grep -q '[c]loudflared.*run' || ps -ef 2>/dev/null | grep "[l]ocalhost:$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port')" >/dev/null 2>&1; then
vm_zs="TLS关闭"
argoym="已开启"
else
vm_zs="TLS关闭"
argoym="未开启"
fi
else
vm_zs="TLS开启"
argoym="不支持开启"
fi
hy2_sniname=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[2].tls.key_path')
[[ "$hy2_sniname" = '/etc/s-box/private.key' ]] && hy2_zs="自签证书" || hy2_zs="域名证书"
tu5_sniname=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[3].tls.key_path')
[[ "$tu5_sniname" = '/etc/s-box/private.key' ]] && tu5_zs="自签证书" || tu5_zs="域名证书"
an_sniname=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[4].tls.key_path')
[[ "$an_sniname" = '/etc/s-box/private.key' ]] && an_zs="自签证书" || an_zs="域名证书"
echo -e "Sing-box节点关键信息、已分流域名情况如下："
echo -e "🚀【 Vless-reality 】${yellow}端口:$vl_port  Reality域名证书伪装地址：$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].tls.server_name')${plain}"
if [[ "$tls" = "false" ]]; then
echo -e "🚀【   Vmess-ws    】${yellow}端口:$vm_port   证书形式:$vm_zs   Argo状态:$argoym${plain}"
else
echo -e "🚀【 Vmess-ws-tls  】${yellow}端口:$vm_port   证书形式:$vm_zs   Argo状态:$argoym${plain}"
fi
echo -e "🚀【  Hysteria-2   】${yellow}端口:$hy2_port  证书形式:$hy2_zs  转发多端口: $hy2zfport${plain}"
echo -e "🚀【    Tuic-v5    】${yellow}端口:$tu5_port  证书形式:$tu5_zs  转发多端口: $tu5zfport${plain}"
if [[ "$sbnh" != "1.10" ]]; then
echo -e "🚀【    Anytls     】${yellow}端口:$an_port  证书形式:$an_zs${plain}"
fi
if [ -s /etc/s-box/subport.log ]; then
showsubport=$(cat /etc/s-box/subport.log)
if ps -ef 2>/dev/null | grep "$showsubport" | grep -v grep >/dev/null; then
showsubtoken=$(cat /etc/s-box/subtoken.log 2>/dev/null)
subip=$(cat /etc/s-box/server_ip.log 2>/dev/null)
suburl="$subip:$showsubport/$showsubtoken"
echo "Clash/Mihomo本地IP订阅地址：http://$suburl/clmi.yaml"
echo "Sing-box本地IP订阅地址：http://$suburl/sbox.json"
echo "聚合协议本地IP订阅地址：http://$suburl/jhsub.txt"
fi
fi
if [ "$argoym" = "已开启" ]; then
#echo -e "Vmess-UUID：${yellow}$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].users[0].uuid')${plain}"
#echo -e "Vmess-Path：${yellow}$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].transport.path')${plain}"
if ps -ef 2>/dev/null | grep "[l]ocalhost:$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port')" >/dev/null 2>&1; then
echo -e "Argo临时域名：${yellow}$(cat /etc/s-box/argo.log 2>/dev/null | grep -a trycloudflare.com | awk 'NR==2{print}' | awk -F// '{print $2}' | awk '{print $1}')${plain}"
fi
if ps -ef 2>/dev/null | grep -q '[c]loudflared.*run'; then
echo -e "Argo固定域名：${yellow}$(cat /etc/s-box/sbargoym.log 2>/dev/null)${plain}"
fi
fi
echo "------------------------------------------------------------------------------------"
if [[ -n $(ps -e | grep sbwpph) ]]; then
s5port=$(cat /etc/s-box/sbwpph.log 2>/dev/null | awk '{print $3}'| awk -F":" '{print $NF}')
s5gj=$(cat /etc/s-box/sbwpph.log 2>/dev/null | awk '{print $6}')
case "$s5gj" in
AT) showgj="奥地利" ;;
AU) showgj="澳大利亚" ;;
BE) showgj="比利时" ;;
BG) showgj="保加利亚" ;;
CA) showgj="加拿大" ;;
CH) showgj="瑞士" ;;
CZ) showgj="捷克" ;;
DE) showgj="德国" ;;
DK) showgj="丹麦" ;;
EE) showgj="爱沙尼亚" ;;
ES) showgj="西班牙" ;;
FI) showgj="芬兰" ;;
FR) showgj="法国" ;;
GB) showgj="英国" ;;
HR) showgj="克罗地亚" ;;
HU) showgj="匈牙利" ;;
IE) showgj="爱尔兰" ;;
IN) showgj="印度" ;;
IT) showgj="意大利" ;;
JP) showgj="日本" ;;
LT) showgj="立陶宛" ;;
LV) showgj="拉脱维亚" ;;
NL) showgj="荷兰" ;;
NO) showgj="挪威" ;;
PL) showgj="波兰" ;;
PT) showgj="葡萄牙" ;;
RO) showgj="罗马尼亚" ;;
RS) showgj="塞尔维亚" ;;
SE) showgj="瑞典" ;;
SG) showgj="新加坡" ;;
SK) showgj="斯洛伐克" ;;
US) showgj="美国" ;;
esac
grep -q "country" /etc/s-box/sbwpph.log 2>/dev/null && s5ms="多地区Psiphon代理模式 (端口:$s5port  国家:$showgj)" || s5ms="本地Warp代理模式 (端口:$s5port)"
echo -e "WARP-plus-Socks5状态：$yellow已启动 $s5ms$plain"
else
echo -e "WARP-plus-Socks5状态：$yellow未启动$plain"
fi
echo "------------------------------------------------------------------------------------"
ww4="warp-wireguard-ipv4优先分流域名：$wfl4"
ww6="warp-wireguard-ipv6优先分流域名：$wfl6"
ws4="warp-socks5-ipv4优先分流域名：$sfl4"
ws6="warp-socks5-ipv6优先分流域名：$sfl6"
l4="VPS本地ipv4优先分流域名：$adfl4"
l6="VPS本地ipv6优先分流域名：$adfl6"
[[ "$sbnh" == "1.10" ]] && ymflzu=("ww4" "ww6" "ws4" "ws6" "l4" "l6") || ymflzu=("ww6" "ws4" "l4" "l6")
for ymfl in "${ymflzu[@]}"; do
if [[ ${!ymfl} != *"未"* ]]; then
echo -e "${!ymfl}"
fi
done
if [[ $ww4 = *"未"* && $ww6 = *"未"* && $ws4 = *"未"* && $ws6 = *"未"* && $l4 = *"未"* && $l6 = *"未"* ]] ; then
echo -e "未设置域名分流"
fi
}

inssbwpph(){
sbactive
ins(){
if [ ! -e /etc/s-box/sbwpph ]; then
case $(uname -m) in
aarch64) cpu=arm64;;
x86_64) cpu=amd64;;
esac
curl -L -o /etc/s-box/sbwpph -# --retry 2 --insecure https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sbwpph_$cpu
chmod +x /etc/s-box/sbwpph
fi
ps -ef | grep '[s]bwpph' | awk '{print $2}' | xargs kill 2>/dev/null
v4v6
if [[ -n $v4 ]]; then
sw46=4
else
red "IPV4不存在，确保安装过WARP-IPV4模式"
sw46=6
fi
echo
readp "设置WARP-plus-Socks5端口（回车跳过端口默认40000）：" port
if [[ -z $port ]]; then
port=40000
until [[ -z $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") && -z $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]] 
do
[[ -n $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") || -n $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]] && yellow "\n端口被占用，请重新输入端口" && readp "自定义端口:" port
done
else
until [[ -z $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") && -z $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]]
do
[[ -n $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") || -n $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]] && yellow "\n端口被占用，请重新输入端口" && readp "自定义端口:" port
done
fi
s5port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.outbounds[] | select(.type == "socks") | .server_port')
[[ "$sbnh" == "1.10" ]] && num=10 || num=11
sed -i "127s/$s5port/$port/g" /etc/s-box/sb10.json
sed -i "165s/$s5port/$port/g" /etc/s-box/sb11.json
cp /etc/s-box/sb${num}.json /etc/s-box/sb.json
restartsb
}
unins(){
ps -ef | grep '[s]bwpph' | awk '{print $2}' | xargs kill 2>/dev/null
rm -rf /etc/s-box/sbwpph.log
crontab -l 2>/dev/null > /tmp/crontab.tmp
sed -i '/sbwpph/d' /tmp/crontab.tmp
crontab /tmp/crontab.tmp >/dev/null 2>&1
rm /tmp/crontab.tmp
rm -rf /etc/local.d/alpinews5.start
}
aplws5(){
if command -v apk >/dev/null 2>&1; then
cat > /etc/local.d/alpinews5.start <<'EOF'
#!/bin/bash
sleep 10
nohup $(cat /etc/s-box/sbwpph.log 2>/dev/null)
EOF
chmod +x /etc/local.d/alpinews5.start
rc-update add local default >/dev/null 2>&1
else
crontab -l 2>/dev/null > /tmp/crontab.tmp
sed -i '/sbwpph/d' /tmp/crontab.tmp
echo '@reboot sleep 10 && /bin/bash -c "nohup $(cat /etc/s-box/sbwpph.log 2>/dev/null) &"' >> /tmp/crontab.tmp
crontab /tmp/crontab.tmp >/dev/null 2>&1
rm /tmp/crontab.tmp
fi
}
echo
yellow "1：重置启用WARP-plus-Socks5本地Warp代理模式"
yellow "2：重置启用WARP-plus-Socks5多地区Psiphon代理模式"
yellow "3：停止WARP-plus-Socks5代理模式"
yellow "0：返回上层"
readp "请选择【0-3】：" menu
if [ "$menu" = "1" ]; then
ins
nohup /etc/s-box/sbwpph -b 127.0.0.1:$port --gool -$sw46 --endpoint 162.159.192.1:2408 >/dev/null 2>&1 &
green "申请IP中……请稍等……" && sleep 20
resv1=$(curl -sm3 --socks5 localhost:$port icanhazip.com)
resv2=$(curl -sm3 -x socks5h://localhost:$port icanhazip.com)
if [[ -z $resv1 && -z $resv2 ]]; then
red "WARP-plus-Socks5的IP获取失败" && unins && exit
else
echo "/etc/s-box/sbwpph -b 127.0.0.1:$port --gool -$sw46 --endpoint 162.159.192.1:2408 >/dev/null 2>&1" > /etc/s-box/sbwpph.log
aplws5
green "WARP-plus-Socks5的IP获取成功，可进行Socks5代理分流"
fi
elif [ "$menu" = "2" ]; then
ins
echo '
奥地利（AT）
澳大利亚（AU）
比利时（BE）
保加利亚（BG）
加拿大（CA）
瑞士（CH）
捷克 (CZ)
德国（DE）
丹麦（DK）
爱沙尼亚（EE）
西班牙（ES）
芬兰（FI）
法国（FR）
英国（GB）
克罗地亚（HR）
匈牙利 (HU)
爱尔兰（IE）
印度（IN）
意大利 (IT)
日本（JP）
立陶宛（LT）
拉脱维亚（LV）
荷兰（NL）
挪威 (NO)
波兰（PL）
葡萄牙（PT）
罗马尼亚 (RO)
塞尔维亚（RS）
瑞典（SE）
新加坡 (SG)
斯洛伐克（SK）
美国（US）
'
readp "可选择国家地区（输入末尾两个大写字母，如美国，则输入US）：" guojia
nohup /etc/s-box/sbwpph -b 127.0.0.1:$port --cfon --country $guojia -$sw46 --endpoint 162.159.192.1:2408 >/dev/null 2>&1 &
green "申请IP中……请稍等……" && sleep 20
resv1=$(curl -sm3 --socks5 localhost:$port icanhazip.com)
resv2=$(curl -sm3 -x socks5h://localhost:$port icanhazip.com)
if [[ -z $resv1 && -z $resv2 ]]; then
red "WARP-plus-Socks5的IP获取失败，尝试换个国家地区吧" && unins && exit
else
echo "/etc/s-box/sbwpph -b 127.0.0.1:$port --cfon --country $guojia -$sw46 --endpoint 162.159.192.1:2408 >/dev/null 2>&1" > /etc/s-box/sbwpph.log
aplws5
green "WARP-plus-Socks5的IP获取成功，可进行Socks5代理分流"
fi
elif [ "$menu" = "3" ]; then
unins && green "已停止WARP-plus-Socks5代理功能"
else
sb
fi
}

sbsm(){
echo
green "关注甬哥YouTube频道：https://youtube.com/@ygkkk?sub_confirmation=1 了解最新代理协议与翻墙动态"
echo
blue "sing-box-yg脚本视频教程：https://www.youtube.com/playlist?list=PLMgly2AulGG_Affv6skQXWnVqw7XWiPwJ"
echo
blue "sing-box-yg脚本博客说明：http://ygkkk.blogspot.com/2023/10/sing-box-yg.html"
echo
blue "sing-box-yg脚本项目地址：https://github.com/yonggekkk/sing-box-yg"
echo
blue "推荐甬哥新品：ArgoSBX一键无交互小钢炮脚本"
blue "ArgoSBX项目地址：https://github.com/yonggekkk/argosbx"
echo
}

clear
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" 
echo -e "${bblue} ░██     ░██      ░██ ██ ██         ░█${plain}█   ░██     ░██   ░██     ░█${red}█   ░██${plain}  "
echo -e "${bblue}  ░██   ░██      ░██    ░░██${plain}        ░██  ░██      ░██  ░██${red}      ░██  ░██${plain}   "
echo -e "${bblue}   ░██ ░██      ░██ ${plain}                ░██ ██        ░██ █${red}█        ░██ ██  ${plain}   "
echo -e "${bblue}     ░██        ░${plain}██    ░██ ██       ░██ ██        ░█${red}█ ██        ░██ ██  ${plain}  "
echo -e "${bblue}     ░██ ${plain}        ░██    ░░██        ░██ ░██       ░${red}██ ░██       ░██ ░██ ${plain}  "
echo -e "${bblue}     ░█${plain}█          ░██ ██ ██         ░██  ░░${red}██     ░██  ░░██     ░██  ░░██ ${plain}  "
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" 
white "甬哥Github项目  ：github.com/yonggekkk"
white "甬哥Blogger博客 ：ygkkk.blogspot.com"
white "甬哥YouTube频道 ：www.youtube.com/@ygkkk"
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" 
white "Vless-reality-vision、Vmess-ws(tls)+Argo、Hy2、Tuic、Anytls 五协议共存脚本"
white "脚本快捷方式：sb"
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green " 1. 一键安装 Sing-box" 
green " 2. 删除卸载 Sing-box"
white "----------------------------------------------------------------------------------"
green " 3. 变更配置 【双证书TLS/UUID路径/Argo/IP优先/TG通知/Warp/订阅/CDN优选】" 
green " 4. 更改主端口/添加多端口跳跃复用" 
green " 5. 三通道域名分流"
green " 6. 关闭/重启 Sing-box"   
green " 7. 更新 Sing-box-yg 脚本"
green " 8. 更新/切换/指定 Sing-box 内核版本"
white "----------------------------------------------------------------------------------"
green " 9. 刷新并查看节点 【Mihomo/SFA+SFI+SFW三合一配置/订阅链接/推送TG通知】"
green "10. 查看 Sing-box 运行日志"
green "11. 一键原版BBR+FQ加速"
green "12. 管理 Acme 申请域名证书"
green "13. 管理 Warp 查看Netflix/ChatGPT解锁情况"
green "14. 添加 WARP-plus-Socks5 代理模式 【本地Warp/多地区Psiphon-VPN】"
green "15. 刷新本地IP、调整IPV4/IPV6配置输出"
white "----------------------------------------------------------------------------------"
green "16. Sing-box-yg脚本使用说明书"
white "----------------------------------------------------------------------------------"
green " 0. 退出脚本"
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
insV=$(cat /etc/s-box/v 2>/dev/null)
latestV=$(curl -sL https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/version | awk -F "更新内容" '{print $1}' | head -n 1)
if [ -f /etc/s-box/v ]; then
if [ "$insV" = "$latestV" ]; then
echo -e "当前 Sing-box-yg 脚本最新版：${bblue}${insV}${plain} (已安装)"
else
echo -e "当前 Sing-box-yg 脚本版本号：${bblue}${insV}${plain}"
echo -e "检测到最新 Sing-box-yg 脚本版本号：${yellow}${latestV}${plain} (可选择7进行更新)"
echo -e "${yellow}$(curl -sL https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/version)${plain}"
fi
else
echo -e "当前 Sing-box-yg 脚本版本号：${bblue}${latestV}${plain}"
yellow "未安装 Sing-box-yg 脚本！请先选择 1 安装"
fi

lapre
if [ -f '/etc/s-box/sb.json' ]; then
if [[ $inscore =~ ^[0-9.]+$ ]]; then
if [ "${inscore}" = "${latcore}" ]; then
echo
echo -e "当前 Sing-box 最新正式版内核：${bblue}${inscore}${plain} (已安装)"
echo
echo -e "当前 Sing-box 最新测试版内核：${bblue}${precore}${plain} (可切换)"
else
echo
echo -e "当前 Sing-box 已安装正式版内核：${bblue}${inscore}${plain}"
echo -e "检测到最新 Sing-box 正式版内核：${yellow}${latcore}${plain} (可选择8进行更新)"
echo
echo -e "当前 Sing-box 最新测试版内核：${bblue}${precore}${plain} (可切换)"
fi
else
if [ "${inscore}" = "${precore}" ]; then
echo
echo -e "当前 Sing-box 最新测试版内核：${bblue}${inscore}${plain} (已安装)"
echo
echo -e "当前 Sing-box 最新正式版内核：${bblue}${latcore}${plain} (可切换)"
else
echo
echo -e "当前 Sing-box 已安装测试版内核：${bblue}${inscore}${plain}"
echo -e "检测到最新 Sing-box 测试版内核：${yellow}${precore}${plain} (可选择8进行更新)"
echo
echo -e "当前 Sing-box 最新正式版内核：${bblue}${latcore}${plain} (可切换)"
fi
fi
else
echo
echo -e "当前 Sing-box 最新正式版内核：${bblue}${latcore}${plain}"
echo -e "当前 Sing-box 最新测试版内核：${bblue}${precore}${plain}"
fi
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo -e "VPS状态如下："
echo -e "系统:$blue$op$plain  \c";echo -e "内核:$blue$version$plain  \c";echo -e "处理器:$blue$cpu$plain  \c";echo -e "虚拟化:$blue$vi$plain  \c";echo -e "BBR算法:$blue$bbr$plain"
v4v6
if [[ "$v6" == "2a09"* ]]; then
w6="【WARP】"
fi
if [[ "$v4" == "104.28"* ]]; then
w4="【WARP】"
fi
[[ -z $v4 ]] && showv4='IPV4地址丢失，请切换至IPV6或者重装Sing-box' || showv4=$v4$w4
[[ -z $v6 ]] && showv6='IPV6地址丢失，请切换至IPV4或者重装Sing-box' || showv6=$v6$w6
if [[ -z $v4 ]]; then
vps_ipv4='无IPV4'      
vps_ipv6="$v6"
location="$v6dq"
elif [[ -n $v4 &&  -n $v6 ]]; then
vps_ipv4="$v4"    
vps_ipv6="$v6"
location="$v4dq"
else
vps_ipv4="$v4"    
vps_ipv6='无IPV6'
location="$v4dq"
fi
echo -e "本地IPV4地址：$blue$vps_ipv4$w4$plain   本地IPV6地址：$blue$vps_ipv6$w6$plain"
echo -e "服务器地区：$blue$location$plain"
if [[ "$sbnh" == "1.10" ]]; then
rpip=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.outbounds[0].domain_strategy') 2>/dev/null
if [[ $rpip = 'prefer_ipv6' ]]; then
v4_6="IPV6优先出站($showv6)"
elif [[ $rpip = 'prefer_ipv4' ]]; then
v4_6="IPV4优先出站($showv4)"
elif [[ $rpip = 'ipv4_only' ]]; then
v4_6="仅IPV4出站($showv4)"
elif [[ $rpip = 'ipv6_only' ]]; then
v4_6="仅IPV6出站($showv6)"
fi
echo -e "代理IP优先级：$blue$v4_6$plain"
fi
if command -v apk >/dev/null 2>&1; then
status_cmd="rc-service sing-box status"
status_pattern="started"
else
status_cmd="systemctl is-active sing-box"
status_pattern="active"
fi
if [[ -n $($status_cmd 2>/dev/null | grep -w "$status_pattern") && -f '/etc/s-box/sb.json' ]]; then
echo -e "Sing-box状态：$blue运行中$plain"
elif [[ -z $($status_cmd 2>/dev/null | grep -w "$status_pattern") && -f '/etc/s-box/sb.json' ]]; then
echo -e "Sing-box状态：$yellow未启动，选择10查看日志并反馈，建议切换正式版内核或卸载重装脚本$plain"
else
echo -e "Sing-box状态：$red未安装$plain"
fi
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
if [ -f '/etc/s-box/sb.json' ]; then
showprotocol
fi
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
readp "请输入数字【0-16】:" Input
case "$Input" in  
 1 ) instsllsingbox;;
 2 ) unins;;
 3 ) changeserv;;
 4 ) changeport;;
 5 ) changefl;;
 6 ) stclre;;
 7 ) upsbyg;; 
 8 ) upsbcroe;;
 9 ) clash_sb_share;;
10 ) sblog;;
11 ) bbr;;
12 ) acme;;
13 ) cfwarp;;
14 ) inssbwpph;;
15 ) wgcfgo && sbshare;;
16 ) sbsm;;
 * ) exit 
esac
