require("dotenv").config();
const auth = require("basic-auth");
const crypto = require("crypto");
const express = require("express");
const { spawn, exec } = require("child_process");

const app = express();
app.use(express.json());

const SERV00_NAME = process.env.SERV00_NAME || "__SERV00_NAME__";
const AUTH_KEY = process.env.KEY || process.env.UUID || "__UUID__";
const SITE_DOMAIN = process.env.SITE_DOMAIN || "__SITE_DOMAIN__";
const PORT = Number(process.env.PORT) || 3000;
const KEEPALIVE_INTERVAL_MS = (2 * 60 + 15) * 60 * 1000;
const IS_PASSENGER =
    typeof PhusionPassenger !== "undefined" ||
    Boolean(
        process.env.PASSENGER_APP_ENV ||
            process.env.IN_PASSENGER ||
            process.env.PASSENGER_BASE_URI
    );

const commandToRun = "cd ~ && bash serv00keep.sh";
const changeportCommands = "cd ~ && bash webport.sh";

let isRunningKeepalive = false;
let isRunningPortReset = false;

function safeEqual(a, b) {
    if (typeof a !== "string" || typeof b !== "string") {
        return false;
    }
    const bufA = Buffer.from(a, "utf8");
    const bufB = Buffer.from(b, "utf8");
    if (bufA.length !== bufB.length) {
        return false;
    }
    return crypto.timingSafeEqual(bufA, bufB);
}

function isConfiguredKey() {
    return Boolean(AUTH_KEY && AUTH_KEY !== "__UUID__");
}

function escapeHtml(value) {
    return String(value)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#39;");
}

function sanitizeProcessOutput(text) {
    return String(text)
        .replace(/(--token(?:=|\s+))(\S+)/gi, "$1[REDACTED]")
        .replace(/((?:ARGO_AUTH|SSH_PASS|PASSWORD|TOKEN)=)(\S+)/gi, "$1[REDACTED]");
}

function extractRequestToken(req) {
    if (typeof req.query.key === "string" && req.query.key) {
        return req.query.key;
    }
    if (typeof req.query.token === "string" && req.query.token) {
        return req.query.token;
    }
    const headerToken = req.get("x-auth-token") || req.get("x-api-key");
    if (headerToken) {
        return headerToken.trim();
    }
    const authHeader = req.get("authorization") || "";
    if (/^Bearer\s+/i.test(authHeader)) {
        return authHeader.replace(/^Bearer\s+/i, "").trim();
    }
    return null;
}

function requireAuth(req, res, next) {
    if (!isConfiguredKey()) {
        return res.status(503).type("text").send("Service auth key is not configured.");
    }

    const token = extractRequestToken(req);
    if (token && safeEqual(token, AUTH_KEY)) {
        return next();
    }

    const credentials = auth(req);
    if (credentials) {
        const expectedUser = process.env.BASIC_USER;
        const expectedPass = process.env.BASIC_PASS || AUTH_KEY;
        const userOk = expectedUser ? safeEqual(credentials.name, expectedUser) : true;
        if (userOk && safeEqual(credentials.pass, expectedPass)) {
            return next();
        }
    }

    res.set("WWW-Authenticate", 'Basic realm="Serv00 Control"');
    return res.status(401).type("text").send("Unauthorized");
}

function runCustomCommand() {
    if (isRunningKeepalive) {
        console.log("serv00keep.sh 已在运行中，跳过重复启动");
        return;
    }
    isRunningKeepalive = true;
    exec(commandToRun, { maxBuffer: 1024 * 1024 * 10 }, (err, stdout, stderr) => {
        isRunningKeepalive = false;
        if (err) {
            console.error("执行错误:", err.message);
            if (stderr) console.error("stderr:", stderr);
        } else {
            console.log("执行成功:", stdout);
        }
    });
}

function runportCommand() {
    if (isRunningPortReset) {
        console.log("webport.sh 已在运行中，跳过重复执行");
        return false;
    }
    isRunningPortReset = true;
    exec(changeportCommands, { maxBuffer: 1024 * 1024 * 10 }, (err, stdout, stderr) => {
        isRunningPortReset = false;
        if (stdout) console.log("stdout:", stdout);
        if (stderr) console.error("stderr:", stderr);
        if (err) {
            console.error("Execution error:", err.message);
        }
    });
    return true;
}

app.get("/up", requireAuth, (req, res) => {
    runCustomCommand();
    const safeName = escapeHtml(SERV00_NAME);
    res.type("html").send(`<pre>Serv00-${safeName}服务器网页保活启动：Serv00-${safeName}！UP！UP！UP！</pre>`);
});

app.get("/re", requireAuth, (req, res) => {
    const additionalCommands = `
        USERNAME=$(whoami | tr '[:upper:]' '[:lower:]')
        FULL_PATH="\${HOME}/domains/\${USERNAME}.serv00.net/logs"
        cd "\$FULL_PATH" || exit 1
        pkill -f '[r]un -c con' || echo "无进程可终止，准备执行重启……"
        sbb="\$(cat sb.txt 2>/dev/null)"
        if [ -n "\$sbb" ] && [ -x "./\$sbb" ]; then
            nohup "./\$sbb" run -c config.json >/dev/null 2>&1 &
        fi
        sleep 2
        (cd ~ && bash serv00keep.sh >/dev/null 2>&1) &
        echo '主程序重启成功，请检测三个主节点是否可用，如不可用，可再次刷新重启网页或者重置端口'
    `;
    exec(additionalCommands, { maxBuffer: 1024 * 1024 * 10 }, (err, stdout, stderr) => {
        if (stdout) console.log("stdout:", stdout);
        if (stderr) console.error("stderr:", stderr);
        if (err) {
            return res.status(500).type("text").send(`错误：${stderr || stdout || err.message}`);
        }
        return res.type("text").send(stdout);
    });
});

app.get("/rp", requireAuth, (req, res) => {
    const started = runportCommand();
    const statusNote = started
        ? "重置三个节点端口任务已启动！"
        : "重置三个节点端口任务正在执行中，请勿重复提交！";
    res.type("html").send(
        `<pre>${statusNote}请立即关闭本网页并稍等20秒，将主页后缀改为  /list/你的uuid  可查看更新端口后的节点及订阅信息</pre>`
    );
});

app.get("/list/:key", (req, res) => {
    if (!isConfiguredKey()) {
        return res.status(503).type("text").send("Service auth key is not configured.");
    }
    if (!safeEqual(req.params.key, AUTH_KEY)) {
        return res.status(401).type("text").send("Unauthorized");
    }

    const listCommands = `
        USERNAME=$(whoami | tr '[:upper:]' '[:lower:]')
        FULL_PATH="\${HOME}/domains/\${USERNAME}.serv00.net/logs/list.txt"
        cat "\$FULL_PATH"
    `;
    exec(listCommands, (err, stdout, stderr) => {
        if (err) {
            console.error(`路径验证失败: ${stderr || err.message}`);
            return res.status(404).type("text").send(stderr || "Not found");
        }
        return res.type("text").send(stdout);
    });
});

app.get("/jc", requireAuth, (req, res) => {
    const ps = spawn("ps", ["aux"]);
    const stdoutChunks = [];
    const stderrChunks = [];

    ps.stdout.on("data", (data) => stdoutChunks.push(data));
    ps.stderr.on("data", (data) => stderrChunks.push(data));
    ps.on("error", (err) => {
        if (!res.headersSent) {
            res.status(500).type("text").send(`ps aux 启动失败: ${err.message}`);
        }
    });
    ps.on("close", (code) => {
        const stdout = sanitizeProcessOutput(Buffer.concat(stdoutChunks).toString("utf8"));
        const stderr = sanitizeProcessOutput(Buffer.concat(stderrChunks).toString("utf8"));
        if (code !== 0) {
            return res
                .status(500)
                .type("text")
                .send(`ps aux 进程退出，错误码: ${code}${stderr ? `\n${stderr}` : ""}`);
        }
        return res.type("text").send(stderr ? `${stdout}\nError: ${stderr}` : stdout);
    });
});

app.use((req, res) => {
    res.status(404).type("text").send(
        `请在地址 http://${SITE_DOMAIN} 后附带授权参数（?key=你的uuid 或 Basic Auth）访问受保护路径：/up、/re、/rp、/jc，或访问 /list/你的uuid`
    );
});

let keepaliveTimer = null;
if (!IS_PASSENGER && process.env.DISABLE_KEEPALIVE_INTERVAL !== "1") {
    keepaliveTimer = setInterval(runCustomCommand, KEEPALIVE_INTERVAL_MS);
    if (typeof keepaliveTimer.unref === "function") {
        keepaliveTimer.unref();
    }
}

const server = app.listen(PORT, () => {
    console.log(`服务器运行在端口 ${PORT}`);
    if (!IS_PASSENGER) {
        runCustomCommand();
    }
});

function shutdown() {
    if (keepaliveTimer) {
        clearInterval(keepaliveTimer);
        keepaliveTimer = null;
    }
    server.close(() => process.exit(0));
}

process.on("SIGTERM", shutdown);
process.on("SIGINT", shutdown);
