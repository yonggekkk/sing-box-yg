# Sing-box-yg（精简优化版）

## 一、VPS 五协议共存脚本（`sb.sh`）

- 支持协议：`VLESS-REALITY-Vision`、`VMess-WS(TLS)/Argo`、`Hysteria2`、`TUIC-v5`、`AnyTLS`
- 支持架构与系统：AMD64 / ARM64；纯 IPv4、纯 IPv6、双栈 VPS；Ubuntu / Debian / CentOS / Alpine（推荐使用最新 Ubuntu）
- 支持本地化生成订阅配置（`Mihomo/Clash`、`Sing-box`、`聚合节点`），无第三方外链转换
- 快捷命令：`sb`

### 安装与快捷命令

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ArthurSawyer/sing-box-yg/fix/verified-improvements/sb.sh)
```

- 本地 IP 订阅：`printf '3\n8\n1\n订阅密码\n订阅端口' | sb`
- Argo 临时隧道：`printf '3\n3\n1\n1' | sb`
- Argo 固定隧道：`printf '3\n3\n2\n1\n固定密钥\n固定域名' | sb`
- 域名分流：`printf '5\n2\n1\n后缀域名1 后缀域名2' | sb`

---

## 二、Serv00 / Hostuno 三协议共存脚本（`serv00.sh`）

> ⚠️ 免费 Serv00 账号运行代理脚本存在封号风险，付费版 Hostuno 不受影响；切勿与其他 Serv00 脚本混用。

- 支持协议：`VLESS-REALITY`、`VMess-WS(Argo)`、`Hysteria2`
- 支持 Argo 临时/固定隧道切换、ProxyIP/反代 IP 配置、多平台保活（`serv00keep.sh`、`kp.sh`、`workers_keep.js`、`.github/workflows/`）及 Web 管理面板（`app.js`）

### 安装命令

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ArthurSawyer/sing-box-yg/fix/verified-improvements/serv00.sh)
```
