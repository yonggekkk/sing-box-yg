#!/bin/bash
# 定义颜色
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
export LC_ALL=C
export UUID=${UUID:-''}  
export ARGO_DOMAIN=${ARGO_DOMAIN:-''}   
export ARGO_AUTH=${ARGO_AUTH:-''}     
export vless_port=${vless_port:-''}    
export vmess_port=${vmess_port:-''}  
export hy2_port=${hy2_port:-''}       
export IP=${IP:-''}                  
export reym=${reym:-''}
export reset=${reset:-''}
export resport=${resport:-''}

devil binexec on >/dev/null 2>&1
#USERNAME=$(whoami | tr '[:upper:]' '[:lower:]')
USERNAME=$reym
HOSTNAME=$(hostname)
snb=$(hostname | cut -d. -f1)
nb=$(hostname | cut -d '.' -f 1 | tr -d 's')

bash -c 'ps aux | grep $(whoami) | grep -v "sshd\|bash\|grep" | awk "{print \$2}" | xargs -r kill -9 >/dev/null 2>&1' >/dev/null 2>&1
devil www del ${USERNAME} > /dev/null 2>&1
devil www list | awk 'NR > 1 && NF {print $1}' | xargs -I {} devil www del {} > /dev/null 2>&1
sed -i '/export PATH="\$HOME\/bin:\$PATH"/d' "${HOME}/.bashrc" >/dev/null 2>&1
source "${HOME}/.bashrc" >/dev/null 2>&1
find ~ -type f -exec chmod 644 {} \; 2>/dev/null
find ~ -type d -exec chmod 755 {} \; 2>/dev/null
# find ~ -type f -exec rm -f {} \; 2>/dev/null
# find ~ -type d -empty -exec rmdir {} \; 2>/dev/null
# find ~ -exec rm -rf {} \; 2>/dev/null
echo "重置系统完成"

