
### 右上角点个star，感谢支持！
### Sing-box精装桶一键四协议共存脚本
### 支持协议：Vless-reality-vision、Vmess-ws(tls)+Argo、Hysteria-2、Tuic-v5
### 支持纯IPV6与ARM架构的VPS
### 小白用户回车三次即可输出配置信息
--------------------------------------------------------------
### 主要功能：
1、支持Argo临时隧道：Vmess-ws(tls)与Argo双节点支持CDN优选IP
 
2、双证书切换：自签证书与域名证书相互切换，现实各自协议证书验证、TLS的开启或者关闭

3、加入IP优选级设置：支持IPV4优先、IPV6优先、仅IPV4、仅IPV6这四档全局切换

4、多端口跳跃：Hysteria-2、Tuic-v5都支持转发多端口(支持多个单端口与范围端口)，实现多端口跳跃与多端口复用

5、域名分流：提供本地VPS、warp-wg出站、warp-socks5这三个通道六条线路，支持完整域名方式与geosite方式进行分流

6、双核心切换：Sing-box正式版与测试版可快速切换

7、脚本与内核在线更新提示，SSH控制台展示关键节点参数

8、输出配置多样，你懂的

------------------------------------------------------------------------------------

### 后续主要功能更新日志…………

23.11.3功能新增：

1、加入IP优选级设置，支持IPV4优先、IPV6优先、仅IPV4、仅IPV6这四档全局切换

2、加入每天1:00重启一次Sing-box服务，可使用```crontab -e```命令查看修改

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
