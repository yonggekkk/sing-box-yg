require('dotenv').config();
const express = require("express");
const { exec } = require('child_process');
const app = express();
app.use(express.json());
app.get("/up", function (req, res) {
    const commandToRun = "cd ~ && bash serv00keep.sh";
    exec(commandToRun, function (err, stdout, stderr) {
        if (err) {
            console.log("命令执行错误: " + err);
            res.status(500).send("服务器错误");
            return;
        }
        if (stderr) {
            console.log("命令执行标准错误输出: " + stderr);
        }
        console.log("命令执行成功:\n" + stdout);
    });

    res.type("html").send("<pre>Serv00网页保活启动：Serv00！一柱擎天！UP！UP！UP！</pre>");
});
app.use((req, res, next) => {
    if (req.path === '/up') {
        return next();
    }
    res.status(404).send('把浏览器地址改为：http://name.name.serv00.net/up 这样才能启动Serv00网页保活');
});

app.listen(3000, () => {
    console.log("服务器已启动，监听端口 3000");
});
