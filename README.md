### 一、Sing-box-yg精装桶小白专享一键四协议共存脚本（VPS专用）

脚本特色：多功能前台显示、高自由度交互体验，全平台全客户端无脑通吃

支持人气最高的四大协议：Vless-reality-vision、Vmess-ws(tls)/Argo、Hysteria-2、Tuic-v5

支持纯IPV6、纯IPV4、双栈VPS，支持amd与arm架构，支持alpine系统，推荐使用最新的Ubuntu系统

本项目分享订阅节点为本地化生成，不使用节点转换等第三方外链引用，无需担心节点订阅被外链作者查看

小白简单模式：无需域名证书，回车三次就安装完成，复制、扫描你要的节点配置

------------------------------------------------------------------------------------

### 相关说明及注意点请查看[甬哥博客说明与Sing-box视频教程](https://ygkkk.blogspot.com/2023/10/sing-box-yg.html)

### 视频教程：

[Sing-box精装桶小白一键脚本（一）：配置文件通吃SFA/SFI/SFW三平台客户端，Argo隧道、双证书切换、域名分流](https://youtu.be/QwTapeVPeB0)

[Sing-box精装桶小白一键脚本（二）：纯IPV6 VPS搭建，CDN优选IP设置汇总，全平台多种客户端一个脚本全套带走](https://youtu.be/kmTgj1DundU)

[Sing-box精装桶小白一键脚本（三）：自建gitlab私有订阅链接一键同步推送全平台，WARP分流ChatGPT，SFW电脑客户端支持订阅链接](https://youtu.be/by7C2HU6-fU)

[Sing-box精装桶小白一键脚本（四）：vmess协议CDN优选IP多形态设置(详见说明图)](https://youtu.be/Qfm8DbLeb6w)

[Sing-box精装桶小白一键脚本（五）：集成oblivion warp免费vpn功能，本地WARP+赛风VPN切换分流(30个国家IP)](https://youtu.be/5Y6NPsYPws0)

--------------------------------------------------------------
### 交流平台：[甬哥博客地址](https://ygkkk.blogspot.com)、[甬哥YouTube频道](https://www.youtube.com/@ygkkk)、[甬哥TG电报群组](https://t.me/+jZHc6-A-1QQ5ZGVl)、[甬哥TG电报频道](https://t.me/+DkC9ZZUgEFQzMTZl)
--------------------------------------------------------------
### 截止目前，推荐使用sing-box官方V1.10.0系列正式版本
-----------------------------------------------------
### 一键脚本：
```
bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh)
```
或者
```
bash <(wget -qO- https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh)
```
-----------------------------------
### Sing-box-yg脚本界面预览图（注：相关参数随意填写，仅供围观）

![1d5425c093618313888fe41a55f493f](https://github.com/user-attachments/assets/2b4b04a6-2de4-499a-afa1-ed78bccc50a8)

-----------------------------------------------------

### 二、Serv00一键三协议共存脚本（Serv00专用）：

修改自Serv00老王sing-box安装脚本，支持一键三协议：vless-reality、vmess-ws(argo)、hysteria2。

主要增加reality协议默认支持 CF vless/trojan 节点的proxyip以及非标端口的优选反代IP功能

详细设置视频教程，请点击[Serv00最全面的代理脚本](https://youtu.be/2VF9D6z2z7w)

1、Serv00本地专用一键脚本，快捷方式：```bash serv00.sh```
```
bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/serv00.sh)
```
脚本界面预览图：

![1a215abda2dd54d1042e8d3e61979b1](https://github.com/user-attachments/assets/cc28a80b-7cee-41b8-98c1-1d64cb0b1013)

---------------------------------------------------------

2、Serv00多账号自动部署脚本，创建私有库，修改serv00.yml文件的参数，运行github action，自动部署且保活单个或多个Serv00账号的节点

---------------------------------------------------------

3、Serv00多账号自动部署脚本，修改kp.sh文件的参数，可在多个平台上自动远程自动部署且保活单个或多个Serv00账号的节点

VPS、软路由专用，不可用在serv00本地上，默认nano编辑形式，你也可以手动放在其他目录，做好cron定时运行
```
curl -sSL https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/kp.sh -o kp.sh && chmod +x kp.sh && nano kp.sh
```
运行```bash kp.sh```可测试有效性 

-----------------------------------------------------

### 感谢你右上角的star🌟
[![Stargazers over time](https://starchart.cc/yonggekkk/sing-box-yg.svg)](https://starchart.cc/yonggekkk/sing-box-yg)

---------------------------------------
#### 声明：所有代码来源于Github社区与ChatGPT的整合
