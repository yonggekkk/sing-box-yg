
### Sing-box-yg精装桶小白专享一键四协议共存脚本
### 脚本特色：多功能前台显示、高自由度交互体验，全平台全客户端无脑通吃
### 支持人气最高的四大协议：Vless-reality-vision、Vmess-ws(tls)/Argo、Hysteria-2、Tuic-v5
### 支持纯IPV6、纯IPV4、双栈VPS，支持amd与arm架构，推荐新手小白使用ubuntu系统
### 小白简单模式：无需域名证书，回车三次就安装完成，复制、扫描你要的节点配置
--------------------------------------------------------------
### 主要功能及特点：
1：Vmess-ws(tls)节点的特殊性 (详见第二期视频教程的独家彩蛋图)：TLS与非TLS下自动随机生成优选端口，非TLS自动衍生出独立的Vmess-ws(tls) Argo节点
 
2：双证书切换：reality协议可更换"偷来的证书"，其他协议自签证书与acme域名证书可相互切换，实现各协议独立开启或关闭sni证书验证、TLS

3：IP优先级设置：IPV4优先、IPV6优先、仅IPV4、仅IPV6，四档全局切换 (域名分流不受影响)

4：多端口跳跃：Hysteria-2、Tuic-v5可设置多个单端口与多段范围端口随意组合 (注意：两个协议不要重复端口)，实现多端口跳跃与多端口复用

5：warp-wg出站：默认白送你两个warp的出站IP (wireguad-ipv4与wireguad-ipv6)，可设置分流，解锁某些东西哦！

6：warp账户变更【🌟将与第三期视频同步更新上线】：从别处提取的三大参数，可对warp-wg出站的warp账户类型进行变更 (warp teams团队账户、warp+账户、warp普通账户)

7：warp-wg对端IP优选【🌟将与第三期视频同步更新上线】：优化warp-wg出站分流速度，支持一键回车自动优选即可

8：域名分流：最多可组建本地VPS、warp-wg出站、warp-socks5三个通道共六条线路 (三组IPV4与IPV6)，支持完整域名方式与geosite方式进行分流

9：核心切换、指定【已上线，🌟相关细节操作将在第三期视频说明】：Sing-box正式版与测试版可快速切换，且支持手动指定任意正式版与测试版各自的历史版本，重新输出Sing-box官方客户端配置会自动匹配对应服务端版本

10：脚本与内核在线更新提示

11：SSH快捷菜单展示关键节点信息：本地IP显示、IP优选级情况、reality域名、UUID、Argo是否运行及域名、主端口与多端口明细、分流明细

12：实时更新配置显示信息：全协议分享链接、二维码、v2rayn配置、clash-meta、sing-box官方客户端(sfa/sfi/sfw)统一配置文件

13：TG推送配置信息：设置TG的token与用户ID，支持全协议分享链接、clash-meta、sing-box官方客户端(sfa/sfi/sfw)统一配置文件推送到TG机器人上，方便移动端复制粘贴配置

14：Gitlab私有订阅推送更新【🌟将与第三期视频同步更新上线】：自动生成Gitlab私有订阅链接，每次安装、变更配置都会自动刷新Gitlab私有订阅里的配置，告别Gitlab手动修改

15：Sing-box的电脑端网页版客户端可直接下载SFW.zip压缩包【已上线，🌟相关细节操作将在第三期视频说明】，支持在线更新明文订阅链接与本地配置信息直接读取

更新中。。。。。。。。。。

------------------------------------------------------------------------------------

### 相关说明及注意点请查看[甬哥博客说明与Sing-box视频教程](https://ygkkk.blogspot.com/2023/10/sing-box-yg.html)
--------------------------------------------------------------
### 截止目前，推荐使用V1.8.0系列正式版本

--------------------------------------------------------------

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

-----------------------------------------------------
### 感谢你右上角的star🌟
[![Stargazers over time](https://starchart.cc/yonggekkk/sing-box-yg.svg)](https://starchart.cc/yonggekkk/sing-box-yg)

---------------------------------------
#### 声明：

#### 该项目使用base64加密，可自行解密，介意者请勿使用，[加密原因在此](https://ygkkk.blogspot.com/2022/06/github.html)

#### 所有代码来源于Github社区与ChatGPT的整合；如您需要开源代码，请提Issues留下您的联系邮箱
