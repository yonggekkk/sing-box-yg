
### 右上角点个star，感谢支持！
### Sing-box精装桶一键四协议共存脚本，又称：小白专属SB小钢炮
### 支持协议：Vless-reality-vision、Vmess-ws(tls)+Argo、Hysteria-2、Tuic-v5
### 支持纯IPV6与ARM架构的VPS
### 小白用户回车三次即可输出配置信息
--------------------------------------------------------------
### 主要功能：
1：支持Argo临时隧道：Vmess-ws(tls)与Argo双节点支持CDN优选IP，Argo失效，并不影响其它四个节点，可重置获取
 
2：双证书切换：自签证书与acme域名证书相互切换，实现各协议独自开启或关闭证书验证、TLS

3：IP优先级设置：IPV4优先、IPV6优先、仅IPV4、仅IPV6，四档全局切换(域名分流不受影响)

4：多端口跳跃：Hysteria-2、Tuic-v5支持多个单端口与多段范围端口随意组合，实现多端口跳跃与多端口复用

5：域名分流：提供本地VPS、warp-wg出站、warp-socks5三个通道共六条线路，支持完整域名方式与geosite方式进行分流

6：双核心切换：Sing-box正式版与测试版可快速切换

7：脚本与内核在线更新提示

8：SSH快捷菜单展示关键节点信息(本地IP显示、IP优选级情况、reality域名、Argo是否运行、各协议主端口与多端口明细、域名分流明细)

9：配置输出：支持分享链接、二维码、V2RAYN配置、sing-box官方客户端(sfa/sfi/sfw)专属统一配置文件

------------------------------------------------------------------------------------

### 后续主要功能更新日志…………

23.11.3功能新增：

1、加入IP优选级设置，支持IPV4优先、IPV6优先、仅IPV4、仅IPV6这四档全局切换

2、加入每天1:00重启一次Sing-box服务（argo临时隧道不受影响），可使用```crontab -e```命令查看自定义修改

更新中。。。。。。。。。。。。

--------------------------------------------------------------------------------------

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

![b3bc74375f887d11e0d1bf10f2c7771](https://github.com/yonggekkk/sing-box-yg/assets/121604513/9ec9d9d4-80c3-488a-ac65-8fd591558770)

---------------------------------------

### 鸣谢：[Sing-box官方](https://github.com/SagerNet/sing-box)、Github所有sing-box项目、Chatgpt
