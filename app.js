require('dotenv').config();
const express = require("express");
const { exec } = require('child_process');
const app = express();
app.use(express.json());
const commandToRun = "cd ~ && bash serv00keep.sh";
function runCustomCommand() {
    exec(commandToRun, (err, stdout, stderr) => {
        if (err) console.error("执行错误:", err);
        else console.log("执行成功:", stdout);
    });
}
app.get("/up", (req, res) => {
    runCustomCommand();
    res.type("html").send("<pre>Serv00-name服务器网页保活启动：Serv00-name！UP！UP！UP！</pre>");
});
app.get("/re", (req, res) => {
    const additionalCommands = `
        USERNAME=$(whoami | tr '[:upper:]' '[:lower:]')
        FULL_PATH="/home/\${USERNAME}/domains/\${USERNAME}.serv00.net/logs"
        cd "\$FULL_PATH"
        pkill -f 'run -c con' || echo "无进程可终止，准备执行重启……"
        sbb="\$(cat sb.txt 2>/dev/null)"
        nohup ./"\$sbb" run -c config.json >/dev/null 2>&1 &
        sleep 2
        (cd ~ && bash serv00keep.sh >/dev/null 2>&1) &  
        echo 'Serv00主程序重启成功，请检测三个主节点是否可用，如不可用，可再次刷新重启网页或者重置端口并卸载重装脚本'
    `;
    exec(additionalCommands, (err, stdout, stderr) => {
        console.log('stdout:', stdout);
        console.error('stderr:', stderr);
        if (err) {
            return res.status(500).send(`错误：${stderr || stdout}`);
        }
        res.type('text').send(stdout);
    });
}); 

app.get("/rp", (req, res) => {
    const changeportCommands = `
USERNAME=$(whoami | tr '[:upper:]' '[:lower:]')
WORKDIR="/home/\${USERNAME}/domains/\${USERNAME}.serv00.net/logs"
portlist="\$(devil port list | grep -E '^[0-9]+[[:space:]]+[a-zA-Z]+' | sed 's/^[[:space:]]*//')"
if [[ -z "\$portlist" ]]; then
echo "无端口"
else
while read -r line; do
port=\$(echo "\$line" | awk '{print $1}')
port_type=\$(echo "\$line" | awk '{print $2}')
echo "删除端口 \$port (\$port_type)"
devil port del "\$port_type" "\$port"
done <<< "\$portlist"
fi
port_list=\$(devil port list)
tcp_ports=\$(echo "\$port_list" | grep -c "tcp")
udp_ports=\$(echo "\$port_list" | grep -c "udp")
if [[ \$tcp_ports -ne 2 || \$udp_ports -ne 1 ]]; then
    echo "端口数量不符合要求，正在调整..."
    if [[ \$tcp_ports -gt 2 ]]; then
        tcp_to_delete=\$((tcp_ports - 2))
        echo "\$port_list" | awk '/tcp/ {print $1, $2}' | head -n \$tcp_to_delete | while read port type; do
            devil port del \$type \$port
            echo "已删除TCP端口: \$port"
        done
    fi
    if [[ \$udp_ports -gt 1 ]]; then
        udp_to_delete=\$((udp_ports - 1))
        echo "\$port_list" | awk '/udp/ {print $1, $2}' | head -n \$udp_to_delete | while read port type; do
            devil port del \$type \$port
            echo "已删除UDP端口: \$port"
        done
    fi
    if [[ \$tcp_ports -lt 2 ]]; then
        tcp_ports_to_add=\$((2 - tcp_ports))
        tcp_ports_added=0
        while [[ \$tcp_ports_added -lt \$tcp_ports_to_add ]]; do
            tcp_port=\$(shuf -i 10000-65535 -n 1)
            result=\$(devil port add tcp \$tcp_port 2>&1)
            if [[ \$result == *"succesfully"* ]]; then
                echo "已添加TCP端口: \$tcp_port"
                if [[ \$tcp_ports_added -eq 0 ]]; then
                    tcp_port1=\$tcp_port
                else
                    tcp_port2=\$tcp_port
                fi
                tcp_ports_added=\$((tcp_ports_added + 1))
            else
                echo "端口 \$tcp_port 不可用，尝试其他端口..."
            fi
        done
    fi
    if [[ \$udp_ports -lt 1 ]]; then
        while true; do
            udp_port=\$(shuf -i 10000-65535 -n 1)
            result=\$(devil port add udp \$udp_port 2>&1)
            if [[ \$result == *"succesfully"* ]]; then
                echo "已添加UDP端口: \$udp_port"
                break
            else
                echo "端口 \$udp_port 不可用，尝试其他端口..."
            fi
        done
    fi
    sleep 3
else
    tcp_ports=\$(echo "\$port_list" | awk '/tcp/ {print $1}')
    tcp_port1=\$(echo "\$tcp_ports" | sed -n '1p')
    tcp_port2=\$(echo "\$tcp_ports" | sed -n '2p')
    udp_port=\$(echo "\$port_list" | awk '/udp/ {print $1}')
    echo "当前TCP端口: \$tcp_port1 和 \$tcp_port2"
    echo "当前UDP端口: \$udp_port"
fi
export vless_port=\$tcp_port1
export vmess_port=\$tcp_port2
export hy2_port=\$udp_port
echo "你的vless-reality端口: \$vless_port"
echo "你的vmess-ws端口(设置Argo固定域名端口): \$vmess_port"
echo "你的hysteria2端口: \$hy2_port"
if [[ -e \$WORKDIR/config.json ]]; then
hyp=\$(jq -r '.inbounds[0].listen_port' \$WORKDIR/config.json 2>/dev/null)
vlp=\$(jq -r '.inbounds[3].listen_port' \$WORKDIR/config.json 2>/dev/null)
vmp=\$(jq -r '.inbounds[4].listen_port' \$WORKDIR/config.json 2>/dev/null)
echo "检测到Serv00-sb-yg脚本已安装，执行端口替换，请稍等……"
sed -i '' "12s/\$hyp/\$hy2_port/g" \$WORKDIR/config.json
sed -i '' "33s/\$hyp/\$hy2_port/g" \$WORKDIR/config.json
sed -i '' "54s/\$hyp/\$hy2_port/g" \$WORKDIR/config.json
sed -i '' "75s/\$vlp/\$vless_port/g" \$WORKDIR/config.json
sed -i '' "102s/\$vmp/\$vmess_port/g" \$WORKDIR/config.json
sed -i '' -e "17s|\$vlp|'\$vless_port'|" serv00keep.sh
sed -i '' -e "18s|\$vmp|'\$vmess_port'|" serv00keep.sh
sed -i '' -e "19s|\$hyp|'\$hy2_port'|" serv00keep.sh
bash -c 'ps aux | grep \$(whoami) | grep -v "sshd\|bash\|grep" | awk "{print \$2}" | xargs -r kill -9 >/dev/null 2>&1' >/dev/null 2>&1
(cd ~ && bash serv00keep.sh >/dev/null 2>&1) &
sleep 5
echo "端口替换完成！"
ps aux | grep '[r]un -c con' > /dev/null && echo "主进程启动成功，单节点用户修改下客户端三协议端口，订阅链接用户更新下订阅即可" || echo "Sing-box主进程启动失败，再次重置端口或者多刷几次保活网页，可能会自动恢复"
if [ -f "$WORKDIR/boot.log" ]; then
ps aux | grep '[t]unnel --u' > /dev/null && echo "Argo临时隧道启动成功，单节点用户在客户端host/sni更换临时域名，订阅链接用户更新下订阅即可" || echo "Argo临时隧道启动失败，再次重置端口或者多刷几次保活网页，可能会自动恢复"
else
ps aux | grep '[t]unnel --n' > /dev/null && echo "Argo固定隧道启动成功" || echo "Argo固定隧道启动失败，请先在CF更改隧道端口：\$vmess_port，多刷几次保活网页可能会自动恢复"
fi
fi
    `;
    exec(changeportCommands, (err, stdout, stderr) => {
        console.log('stdout:', stdout);
        console.error('stderr:', stderr);
        if (err) {
            return res.status(500).send(`错误：${stderr || stdout}`);
        }
        res.type('text').send(stdout);
    });
});

app.get("/list/key", (req, res) => {
    const listCommands = `
        USERNAME=$(whoami | tr '[:upper:]' '[:lower:]')
        FULL_PATH="/home/\${USERNAME}/domains/\${USERNAME}.serv00.net/logs/list.txt"
        cat "\$FULL_PATH"
    `;
    exec(listCommands, (err, stdout, stderr) => {
        if (err) {
            console.error(`路径验证失败: ${stderr}`);
            return res.status(404).send(stderr);
        }
        res.type('text').send(stdout);
    });
});
app.use((req, res) => {
    res.status(404).send('请在浏览器地址：http://where.name.serv00.net 后面加三种路径功能：/up是保活，/re是重启，/rp是重置节点端口，/list/你的uuid 是节点及订阅信息');
});
setInterval(runCustomCommand, 3 * 60 * 1000);
app.listen(3000, () => {
    console.log("服务器运行在端口 3000");
    runCustomCommand();
});
