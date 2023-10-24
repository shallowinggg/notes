---
layout: default
title: 网络
parent: Debian
grand_parent: 操作系统
---

<details open markdown="block">
  <summary>
    Table of contents
  </summary>
  {: .text-delta }
- TOC
{:toc}
</details>

# 网络

## 证书

- [什么是 TLS（传输层安全性）？](https://www.cloudflare-cn.com/learning/ssl/transport-layer-security-tls/)
- [TLS 握手期间会发生什么？| SSL 握手](https://www.cloudflare-cn.com/learning/ssl/what-happens-in-a-tls-handshake/)
- [什么是 SSL 证书？](https://www.cloudflare-cn.com/learning/ssl/what-is-an-ssl-certificate/)
- [公钥加密如何运作？](https://www.cloudflare-cn.com/learning/ssl/how-does-public-key-encryption-work/)

### 创建免费证书

使用`certbot`可以创建自信任证书。

[Let's Encrypt](https://letsencrypt.org/)倡议是一项共同努力，旨在创建一个免费、自动化和开放的证书颁发机构（CA），为公众利益而运行。

### 公钥

#### easy-rsa

`easy-rsa`软件包提供了作为`X.509`认证基础设施的工具，使用`openssl`命令作为一组脚本实现。

#### GnuTLS

`GnuTLS`也可用于生成CA，并处理围绕TLS、DTLS和SSL协议的其他技术。

软件包`gnutls-bin`包含命令行实用程序。安装`gnutls-doc`软件包也很有用，其中包括广泛的文档。

## VPN

虚拟专用网络（简称`VPN`）是一种利用隧道通过互联网连接两个不同本地网络的方式；为了保密，隧道通常经过加密。`VPN`通常用于将远程机器集成到公司的本地网络中。

有几个工具提供了此功能。`OpenVPN`是一个高效的解决方案，易于部署和维护，基于`SSL/TLS`。另一种方式是使用`IPsec`加密两台机器之间的IP流量；这种加密是透明的，这意味着在这些主机上运行的应用程序不需要修改以考虑`VPN`。除了更传统的功能外，`SSH`也可用于提供`VPN`。

### OpenVPN

TODO!!!

### SSH

TODO!!!

## 网络诊断工具

### netstat

`netstat`命令在`net-tools`包中，它显示机器网络活动的即时摘要。当在没有参数的情况下调用时，此命令会列出所有打开的连接，此列表可能非常详细，因为它包括许多`Unix-domain socket`（被守护进程广泛使用），这些套接字根本不涉及网络（例如，dbus通信、X11流量以及虚拟文件系统和桌面之间的通信）。

`netstat`的选项可以其行为，最常用的选项包括：
- `-t`: 过滤结果以仅包括`TCP`连接
- `-u`: 过滤结果以仅包括`UDP`连接；与`-t`并不相互排斥，使用任意一个都可以停止显示`Unix-domain socket`
- `-a`: 列出监听套接字（等待传入连接）
- `-n`: 以数字方式显示结果：IP地址（无DNS解析）、端口号（无`/etc/services`中定义的别名）和用户ID（无登录名）
- `-p`: 列出所涉及的进程；此选项仅在`netstat`作为`root`运行时有用，因为普通用户只会看到自己的进程
- `-c`: 不断刷新连接列表

常用的组合为`netstat -tupan`

### nmap

`nmap`在某种程度上是 `netstat` 的远程替代。它可以扫描一个或多个远程服务器的一组众所周知端口，并列出发现应用程序应答传入连接的端口。此外，`nmap`能够识别其中一些应用程序，有时甚至是它们的版本号。由于它远程运行，因此无法提供有关进程或用户的信息；然而，它可以同时对多个目标进行操作。

典型的`nmap`调用仅使用`-A`选项（以便`nmap`尝试识别它找到的服务器软件的版本），以及要扫描的机器的一个或多个IP地址或DNS名称。同样，还有许多选项可以精细控制`nmap`的行为，参考`nmap`手册。

### sniffer

有时，我们需要逐包查看线路上实际传输的内容。这些情况需要“帧分析器”，更广泛地称为嗅探器。这样的工具会观察到达给定网络接口的所有数据包，并以用户友好的方式显示它们。

该领域中最受尊敬的工具是`tcpdump`，它可作为多种平台上的标准工具。它允许捕获多种网络流量，但这种流量的表示仍然相当模糊。

更新的（也更现代的）工具`wireshark`，已经成为网络流量分析的新参考，因为它有许多解码模块，可以对捕获的数据包进行简化分析。数据包以图形方式显示，并具有基于协议层的组织。这允许用户可视化数据包中涉及的所有协议。例如，给定一个包含 `HTTP` 请求的数据包，`wireshark` 会分别显示有关物理层、以太网层、IP 数据包信息、TCP 连接参数以及最终 `HTTP` 请求本身的信息。

> 当无法运行图形界面，或者出于某种原因不希望这样做时，可以使用`wireshark`的纯文本版本`tshark`。大多数捕获和解码功能仍然可用，但缺乏图形界面必然会限制与程序的交互（捕获数据包后对其进行过滤、跟踪给定的 TCP 连接等）。如果打算进行进一步的操作并且需要图形界面，则可以将数据包保存到文件中，然后可以将该文件加载到另一台计算机上运行的图形`wireshark` 中。


### iperf3

可以使用`iperf3`进行网络速度测试。

分别在两台服务器上安装`iperf3`工具：
```sh
sudo apt-get install iperf3
```

然后在一台服务器上启动`iperf3 server`，另一个服务器连接此`server`进行测试：
```sh
# server
iperf3 -s
# Server listening on 5201

# client
iperf3 -c 192.168.x.x 5201
```

`iperf3`工具会输出测试结果，例如：
```
iperf3 -c 192.168.31.209 5201
Connecting to host 192.168.31.209, port 5201
[  5] local 192.168.31.150 port 47402 connected to 192.168.31.209 port 5201
[ ID] Interval           Transfer     Bitrate         Retr  Cwnd
[  5]   0.00-1.00   sec   114 MBytes   957 Mbits/sec    9   1022 KBytes
[  5]   1.00-2.00   sec   112 MBytes   944 Mbits/sec    0   1022 KBytes
[  5]   2.00-3.00   sec   112 MBytes   944 Mbits/sec    0   1022 KBytes
[  5]   3.00-4.00   sec   112 MBytes   944 Mbits/sec    0   1022 KBytes
[  5]   4.00-5.00   sec   112 MBytes   943 Mbits/sec    0   1022 KBytes
[  5]   5.00-6.00   sec   111 MBytes   934 Mbits/sec    0   1022 KBytes
[  5]   6.00-7.00   sec   112 MBytes   944 Mbits/sec    0   1022 KBytes
[  5]   7.00-8.00   sec   112 MBytes   944 Mbits/sec    0   1022 KBytes
[  5]   8.00-9.00   sec   112 MBytes   944 Mbits/sec    0   1022 KBytes
[  5]   9.00-10.00  sec   112 MBytes   942 Mbits/sec    0   1022 KBytes
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-10.00  sec  1.10 GBytes   944 Mbits/sec    9             sender
[  5]   0.00-10.04  sec  1.10 GBytes   937 Mbits/sec                  receiver

iperf Done.
```
