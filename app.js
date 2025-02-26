require('dotenv').config();
const express = require("express");
const { exec } = require('child_process');
const { spawn } = require('child_process');
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
    const changeportCommands = "bash";
    const args = ["webport.sh"];
    
    const child = spawn(changeportCommands, args, { cwd: process.env.HOME });

    let stdoutData = '';
    let stderrData = '';

    // 处理标准输出
    child.stdout.on('data', (data) => {
        stdoutData += data.toString(); // 累加输出
        console.log(data.toString());  // 输出到控制台，或者可以根据需要修改
    });

    // 处理标准错误输出
    child.stderr.on('data', (data) => {
        stderrData += data.toString(); // 累加错误信息
        console.error(data.toString());  // 输出错误
    });

    // 处理结束
    child.on('close', (code) => {
        if (code !== 0) {
            console.error(`子进程退出，错误代码：${code}`);
            return res.status(500).send(`错误：${stderrData || stdoutData}`);
        }

        // 如果有stderr信息
        if (stderrData) {
            return res.status(500).send(`stderr: ${stderrData}`);
        }

        // 返回输出
        res.type('text').send(stdoutData);
    });

    child.on('error', (err) => {
        console.error('子进程启动失败:', err);
        res.status(500).send(`执行错误: ${err.message}`);
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
