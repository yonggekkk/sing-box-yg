require('dotenv').config();
const express = require("express");
const { exec } = require('child_process');
const app = express();
app.use(express.json());
const commandToRun = "cd ~ && bash serv00keep.sh";
function runCustomCommand() {
    exec(commandToRun, function (err, stdout, stderr) {
        if (err) {
            console.log("命令执行错误: " + err);
            return;
        }
        if (stderr) {
            console.log("命令执行标准错误输出: " + stderr);
        }
        console.log("命令执行成功:\n" + stdout);
    });
}
setInterval(runCustomCommand, 3 * 60 * 1000); // 3 分钟 = 3 * 60 * 1000 毫秒
app.get("/up", function (req, res) {
    runCustomCommand();
    res.type("html").send("<pre>Serv00网页保活启动：Serv00！UP！UP！UP！</pre>");
});
app.use((req, res, next) => {
    if (req.path === '/up') {
        return next();
    }
    res.status(404).send('把浏览器地址改为：http://name.name.serv00.net/up 这样才能启动Serv00网页保活');
});
app.listen(3000, () => {
    console.log("服务器已启动，监听端口 3000");
    runCustomCommand();
});
