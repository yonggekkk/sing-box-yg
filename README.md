### 一、Sing-box-yg精装桶一键四协议共存脚本（VPS专用）
### 二、Serv00/Hostuno-sb-yg多平台一键三协议共存脚本（Serv00/Hostuno专用）

### 注：本项目分享订阅节点都为本地化生成，不使用节点转换、订阅器等第三方外链引用，无需担心节点订阅被外链作者查看

### 交流平台：[甬哥博客地址](https://ygkkk.blogspot.com)、[甬哥YouTube频道](https://www.youtube.com/@ygkkk)、[甬哥TG电报群组](https://t.me/+jZHc6-A-1QQ5ZGVl)、[甬哥TG电报频道](https://t.me/+DkC9ZZUgEFQzMTZl)
--------------------------------------------------------------

### 一、Sing-box-yg精装桶小白专享一键四协议共存脚本（VPS专用）

* 支持人气最高的四大协议：Vless-reality-vision、Vmess-ws(tls)/Argo、Hysteria-2、Tuic-v5

* 支持纯IPV6、纯IPV4、双栈VPS，支持amd与arm架构，支持alpine系统，推荐使用最新的Ubuntu系统

* 小白简单模式：无需域名证书，回车三次就安装完成，复制、扫描你要的节点配置

#### 相关说明及注意点请查看[甬哥博客说明与Sing-box视频教程](https://ygkkk.blogspot.com/2023/10/sing-box-yg.html)

#### 视频教程：

[Sing-box精装桶小白一键脚本（一）：配置文件通吃SFA/SFI/SFW三平台客户端，Argo隧道、双证书切换、域名分流](https://youtu.be/QwTapeVPeB0)

[Sing-box精装桶小白一键脚本（二）：纯IPV6 VPS搭建，CDN优选IP设置汇总，全平台多种客户端一个脚本全套带走](https://youtu.be/kmTgj1DundU)

[Sing-box精装桶小白一键脚本（三）：自建gitlab私有订阅链接一键同步推送全平台，WARP分流ChatGPT，SFW电脑客户端支持订阅链接](https://youtu.be/by7C2HU6-fU)

[Sing-box精装桶小白一键脚本（四）：vmess协议CDN优选IP多形态设置(详见说明图)](https://youtu.be/Qfm8DbLeb6w)

[Sing-box精装桶小白一键脚本（五）：集成oblivion warp免费vpn功能，本地WARP+赛风VPN切换分流(30个国家IP)](https://youtu.be/5Y6NPsYPws0)

### VPS专用一键脚本如下：快捷方式：```sb```
### (注意：serv00不可用，请继续往下翻)
```
bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh)
```
或者
```
bash <(wget -qO- https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh)
```

### Sing-box-yg脚本界面预览图（注：相关参数随意填写，仅供围观）

![1d5425c093618313888fe41a55f493f](https://github.com/user-attachments/assets/2b4b04a6-2de4-499a-afa1-ed78bccc50a8)

-----------------------------------------------------

### 二、Serv00/Hostuno一键三协议共存脚本（Serv00/Hostuno专用）：

* 切勿与其他Serv00脚本混用！！！

* 修改自Serv00老王sing-box安装脚本，支持一键三协议：vless-reality、vmess-ws(argo)、hysteria2

* 主要增加reality协议默认支持 CF vless/trojan 节点的proxyip以及非标端口的优选反代IP功能

* 支持多功能网页：1、保活 2、重启 3、重置端口 4、查看订阅节点

* 网页保活与网页重启可在github或workers设置定时运行任务，可参考视频教程三

#### 相关说明及注意点请查看[甬哥博客说明与Serv00视频教程](https://ygkkk.blogspot.com/2025/01/serv00.html)

#### 视频教程：

[Serv00免费代理脚本最终教程（一）：独家支持三个IP自定义安装，支持Proxyip+反代IP、支持Argo临时/固定隧道+CDN回源；支持五个节点的Sing-box与Clash订阅配置输出](https://youtu.be/2VF9D6z2z7w)

[Serv00免费代理脚本最终教程（二）：Serv00不必再登录SSH了，部署保活融为一体，独家支持Github、VPS、软路由多平台多账户通用部署，四大方案总有一款适合你](https://youtu.be/rYeX1iU_iZ0)

[Serv00免费代理脚本最终教程（三）：多功能网页生成【保活+重启+重置端口+查看订阅节点】、随意重置端口功能；Github+Workers自动执行保活功能任你选！](https://youtu.be/9uCfFNnjNc0)



### 方案一、Serv00/Hostuno-sb-yg一键脚本 【本地SSH专用，同服务器与方案二、方案三都不通用】

### 快捷方式：```sb```

```
bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/serv00.sh)
```

#### Serv00/Hostuno-sb-yg脚本界面预览图，仅限方案一的SSH端安装脚本（注：仅供围观）
![0904b4205bf0a45b43ea502c28caea7](https://github.com/user-attachments/assets/e3a56a18-91e1-4da4-afa4-39e6144a0d00)

![a39f5972b1f33b71138fd9b45af6e53](https://github.com/user-attachments/assets/a2e069ea-80cb-4953-b034-3cb518444eb7)


### 方案二、Serv00多账号自动部署脚本：serv00.yml（github专用，不支持Hostuno，同服务器与方案三通用）

* 创建私有库，修改serv00.yml文件的参数，运行github action，自动远程部署且保活单个或多个Serv00账号的节点，做好cron定时或者使用网页保活


### 方案三、Serv00多账号自动部署脚本：kp.sh（VPS、软路由专用，不支持Hostuno，同服务器与方案二通用）

* 修改kp.sh文件的参数，可在多个平台上自动远程部署且保活单个或多个Serv00账号的节点，不可用在serv00本地上，默认nano编辑形式

* 也可以手动放在其他目录，做好cron定时或者使用网页保活

```
curl -sSL https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/kp.sh -o kp.sh && chmod +x kp.sh && nano kp.sh
```

### 注意：方案二serv00.yml与方案三kp.sh在启用cron时，都为"强制保活脚本"，就算Serv00清空你服务器上所有文件(到目前为止从没发生过)，只要让你连接成功，就会自动安装脚本保活，保持不死状态


-----------------------------------------------------

### 感谢你右上角的star🌟
[![Stargazers over time](https://starchart.cc/yonggekkk/sing-box-yg.svg)](https://starchart.cc/yonggekkk/sing-box-yg)

---------------------------------------
#### 声明：所有代码来源于Github社区与ChatGPT的整合，[老王eooce](https://github.com/eooce/Sing-box/blob/test/sb_00.sh)、[frankiejun](https://github.com/frankiejun/serv00-play/blob/main/start.sh)
