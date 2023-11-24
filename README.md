
### Sing-box精装桶一键四协议共存脚本
### 支持协议：Vless-reality-vision、Vmess-ws(tls)、Hysteria-2、Tuic-v5
### 支持 纯IPV6 与 ARM架构 的VPS，强烈推荐新手小白使用ubuntu系统
### 特色：多功能前台显示+高自由度交互体验
### 小白模式：回车三次即可快速完成四协议安装，复制、扫描你要的节点配置
--------------------------------------------------------------
### 主要功能及特点：
1：Vmess-ws节点的特殊性：自动衍生出另外独立的Vmess-ws(tls) Argo节点，Argo节点13个端口随便换+CDN优选IP，VPS重启Argo自动重置生成
 
2：双证书切换：reality协议可更换"偷来的证书"，其他协议自签证书与acme域名证书可相互切换，实现各协议独立开启或关闭sni证书验证、TLS

3：IP优先级设置：IPV4优先、IPV6优先、仅IPV4、仅IPV6，四档全局切换(域名分流不受影响)

4：多端口跳跃：Hysteria-2、Tuic-v5可设置多个单端口与多段范围端口随意组合(注意：两个协议不要重复端口)，实现多端口跳跃与多端口复用

5：集成warp-wg出站：默认白送你两个warp的出站IP（wireguad-ipv4与wireguad-ipv6），可用于自定义域名分流（解锁某某某福利哦！）

6：域名分流：最多可组建本地VPS、warp-wg出站、warp-socks5三个通道共六条线路(三组IPV4与IPV6)，支持完整域名方式与geosite方式进行分流

7：双核心切换：Sing-box正式版与测试版可快速切换

8：脚本与内核在线更新提示

9：SSH快捷菜单展示关键节点信息：本地IP显示、IP优选级情况、reality域名、UUID、Argo是否运行及域名、主端口与多端口明细、分流明细

10：实时更新配置显示信息：支持分享链接、二维码、V2RAYN配置、sing-box官方客户端(sfa/sfi/sfw)统一配置文件

11：TG推送配置信息：设置TG的token与用户ID，支持分享链接、clash-meta、sing-box官方客户端(sfa/sfi/sfw)统一配置文件推送到TG机器人上，方便移动端复制粘贴配置

------------------------------------------------------------------------------------

### 相关说明及注意点请查看[甬哥博客说明](https://ygkkk.blogspot.com/2023/10/sing-box-yg.html)

### 一键脚本：
```
bash <(curl -Ls https://gitlab.com/rwkgyg/sing-box-yg/raw/main/sb.sh)
```
或者
```
bash <(wget -qO- https://gitlab.com/rwkgyg/sing-box-yg/raw/main/sb.sh 2> /dev/null)
```

-----------------------------------
### Sing-box-yg脚本主要功能全开后的预览图（注：相关参数随意填写，仅供围观）

![2e3e6e3636ad34aabbe60dd9cf6f57f](https://github.com/yonggekkk/sing-box-yg/assets/121604513/4a06866d-874e-4870-a6e1-2a39e5fee1bb)


---------------------------------------

#### 鸣谢：
#### Sing-box-yg脚本使用[Sing-box官方内核](https://github.com/SagerNet/sing-box)、参考于[Github所有sing-box项目](https://github.com/search?q=SING+BOX&type=repositories)、利用[Chatgpt](https://chat.openai.com/auth/login)整合

-----------------------------------------------------
### 感谢你右上角的star🌟
[![Stargazers over time](https://starchart.cc/yonggekkk/sing-box-yg.svg)](https://starchart.cc/yonggekkk/sing-box-yg)
