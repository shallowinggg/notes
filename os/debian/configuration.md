---
layout: default
title: 配置
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

# 基础配置

## Locale

`locale`命令列出了各种区域参数（日期格式、数字格式等）的当前配置摘要，以一组标准环境变量的形式呈现，专门用于动态修改这些设置。虽然这些参数中的每一个都可以独立于其他参数指定，但我们通常使用`locale`，它是这些参数的一组连贯的值，对应于最广泛意义上的区域。`locale`通常以`language-code_COUNTRY-CODE`的形式表示，有时用后缀来指定要使用的字符集和编码。这可以考虑具有共同语言的不同区域之间的惯用或排版差异。

```sh
➜  ~ locale
LANG=
LANGUAGE=
LC_CTYPE="POSIX"
LC_NUMERIC="POSIX"
LC_TIME="POSIX"
LC_COLLATE="POSIX"
LC_MONETARY="POSIX"
LC_MESSAGES="POSIX"
LC_PAPER="POSIX"
LC_NAME="POSIX"
LC_ADDRESS="POSIX"
LC_TELEPHONE="POSIX"
LC_MEASUREMENT="POSIX"
LC_IDENTIFICATION="POSIX"
LC_ALL=
```

### 设置默认语言

`locales`包在安装时会先要求你从受支持的语言中选择一组`locale`，可以通过执行`dpkg-reconfigure locales`命令修改。

系统已启用的`locale`列表存储在`/etc/locale.gen`文件中。你可以手动编辑此文件，但在进行任何修改后需要运行`locale-gen`命令，它将为新增的`locales`生成所需的文件，并删除任何过时的文件。

```sh
➜  ~ head -10 /etc/locale.gen
en_US.UTF-8 UTF-8
# C.UTF-8 UTF-8
# aa_DJ ISO-8859-1
# aa_DJ.UTF-8 UTF-8
# aa_ER UTF-8
# aa_ER@saaho UTF-8
# aa_ET UTF-8
# af_ZA ISO-8859-1
# af_ZA.UTF-8 UTF-8
# agr_PE UTF-8
```

然后，它会让你从之前选择的一组`locale`中选择一个作为系统默认的`locale`，`/etc/default/locale`文件会存储此选项。它被所有用户会话接收，因为`PAM`将在`LANG`环境变量中注入其内容。

```sh
➜  ~ cat /etc/default/locale
LANG=en_US.UTF-8
```

### 设置键盘

`dpkg-reconfigure keyboard-configuration`命令可以用来重新设置键盘布局。

### 迁移至UTF-8

#### 文件名

`convmv`工具可以将文件名从一种编码重命名为另一种编码。这个工具使用起来很简单，但是建议通过两步完成以避免产生意料之外的情况。如下所示：

```sh
$ ls travail/
Ic?nes  ?l?ments graphiques  Textes

# step1
$ convmv -r -f iso-8859-15 -t utf-8 travail/
Starting a dry run without changes...
mv "travail/�l�ments graphiques"        "travail/Éléments graphiques"
mv "travail/Ic�nes"     "travail/Icônes"
No changes to your files done. Use --notest to finally rename the files.

# step2
$ convmv -r --notest -f iso-8859-15 -t utf-8 travail/
mv "travail/�l�ments graphiques"        "travail/Éléments graphiques"
mv "travail/Ic�nes"     "travail/Icônes"
Ready!
$ ls travail/
Éléments graphiques  Icônes  Textes”
```

#### 文件内容

对于简单的文件，可以使用`recode`命令，它将自动重新编码。

`iconv`支持更多的编码集，但是它没有`recode`灵活。

## 网络

网络配置存储于`/etc/network/interfaces`文件中，如果需要有多个不同的配置，最佳实践是将配置分散于`/etc/network/interfaces.d/`目录下。

```sh
~ sudo cat /etc/network/interfaces
# Location: /etc/network/interfaces

# Drop-in configs
source interfaces.d/*

# Ethernet
allow-hotplug eth0
iface eth0 inet dhcp
address 192.168.0.100
netmask 255.255.255.0
gateway 192.168.0.1
#dns-nameservers 9.9.9.9 149.112.112.112

# WiFi
#allow-hotplug wlan0
iface wlan0 inet dhcp
address 192.168.0.100
netmask 255.255.255.0
gateway 192.168.0.1
#dns-nameservers 9.9.9.9 149.112.112.112
wireless-power off
wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf
```

### Ethernet

如果计算机拥有以太网卡，那么必须用下面两种方式来配置与之关联的ip地址。

#### DHCP

最简单的方法是使用`DHCP`进行动态配置，它需要在本地网络上安装`DHCP`服务器。它可以指示主机名，对应于以下示例中的主机名设置。然后，`DHCP`服务器发送相应网络的配置设置。

```
# DHCP配置样例
auto enp0s31f6
iface enp0s31f6 inet dhcp
  hostname arrakis
```

> 默认情况下，内核将`eth0`（用于有线以太网）或`wlan0`（用于WiFi）等通用名称归入网络接口。这些名称中的数字是一个简单的增量计数器，表示检测到它们的顺序。对于现代硬件，该顺序（至少在理论上）可能会随着每次重启而改变，因此默认名称不可靠。
>
> 幸运的是，`systemd`和`udev`能够在网络接口出现时立即重命名。默认名称策略由`/lib/systemd/network/99-default.link`定义。在实践中，这些名称通常基于设备的物理位置（根据连接位置猜测），你将看到有线以太网以`en`开头的名称和WiFi以`wl`开头的名称。在上面的示例中，名称（`enp0s31f6`）的其余部分以缩写形式表示PCI（p）总线号（0）、插槽号（s31）、function number（f6）。因此，这个名字变得可以预测。

#### static

`static`配置必须以固定的方式指示网络设置。这至少包括IP地址和子网掩码；网络和广播地址有时也会列出。连接到外部的路由器将被指定为网关。

```
# static配置样例
auto enp0s31f6
iface enp0s31f6 inet static
  address 192.168.0.3/24
  broadcast 192.168.0.255
  network 192.168.0.0
  gateway 192.168.0.1
```

### Wireless

TODO!!!

## Hostname

每台机器都由主（或“规范”）名称标识，存储在`/etc/hostname`文件中，并通过`hostname`命令通过初始化脚本与Linux内核通信。当前值在虚拟文件系统中可用，你可以使用`cat /proc/sys/kernel/hostname`命令获取它。

```sh
~ hostname
r6s-2
~ sudo cat /etc/hostname
r6s-2
~ susudo cat /proc/sys/kernel/hostname
r6s-2
```

> `/proc/`和`/sys/`文件树由“虚拟”文件系统生成。这是从内核中恢复信息（通过列出虚拟文件）并将其传达给内核（通过写入虚拟文件）的实用方法。
>
> `/sys/`旨在提供对内部内核对象的访问，特别是那些代表系统中各种设备的内核对象。因此，内核可以共享各种信息：每个设备的状态（例如是否处于节能模式），是否是可移动设备等。请注意，`/sys/`自内核2.6版本以来才存在。`/proc/`描述了内核的当前状态：此目录中的文件包含有关系统及其硬件上运行的进程的信息。

### 名称解析

Linux中的名称解析机制是模块化的，可以使用`/etc/nsswitch.conf`文件中声明的各种信息源，涉及主机名解析的条目是`hosts`。默认情况下，它包含`files dns`，这意味着系统首先查询`/etc/hosts`文件，然后是`DNS服务器`。`NIS/NIS+`或`LDAP服务器`是其他可能的来源。

```
➜  ~ sudo cat /etc/nsswitch.conf
# /etc/nsswitch.conf
#
# Example configuration of GNU Name Service Switch functionality.
# If you have the `glibc-doc-reference' and `info' packages installed, try:
# `info libc "Name Service Switch"' for information about this file.

passwd:         files
group:          files
shadow:         files
gshadow:        files

hosts:          files dns
networks:       files

protocols:      db files
services:       db files
ethers:         db files
rpc:            db files

netgroup:       nis
```

> 注意，专门用于查询DNS（特别是主机）的命令不使用标准名称解析机制（NSS）。因此，他们没有考虑`/etc/nsswitch.conf`，因此也没有考虑`/etc/hosts`。

#### 配置DNS服务器

要使用的DNS服务器在`/etc/resolv.conf`中指示，每行一个，名称服务器关键字在IP地址之前，如下所示：

```
nameserver 212.27.32.176
nameserver 212.27.32.177
nameserver 8.8.8.8
```

注意，当网络由`NetworkManager`管理或通过`DHCP`配置时，或者当`resolvconf`被安装或启用`systemd-resolved`时，`/etc/resolv.conf`文件可能会被自动处理（并覆盖）。

#### 配置`/etc/hosts`

如果本地网络上没有名称服务器，可以在`/etc/hosts`文件中建立一个小表映射IP地址和机器主机名，这通常保留给本地网络。此文件的语法非常简单：每行指示一个特定的IP地址，然后是任何关联名称的列表（第一个是“完全限定的”，这意味着它包括域名）。

```
127.0.0.1     localhost
192.168.0.1   arrakis.falcot.com arrakis
```

即使在网络中断或DNS服务器无法访问时，此文件也可用，但只有在网络上的所有机器上复制时才真正有用。任何细微的更改要求更新所有机器上的文件，这就是为什么`/etc/hosts`通常只包含最重要的条目。

对于未连接到互联网的小型网络来说，此文件就足够了，但对于5台或更多机器，建议安装适当的DNS服务器。

## 用户与组

用户列表通常存储在`/etc/passwd`文件中，而`/etc/shadow`文件存储哈希后的密码。两者都是文本文件，格式相对简单，可以使用文本编辑器读取和修改。每个用户都列在一行上，字段用冒号（`:`）分隔。

### /etc/passwd


```
➜  ~ sudo cat /etc/passwd
root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin
dietpi:x:1000:1000::/home/dietpi:/usr/bin/zsh
```

`/etc/passwd`文件包含如下字段：

- login, 例如rhertzog, root
- password: 单向加密后的密码，通过DES, MD5, SHA-256或SHA-512算法实现。特殊值`x`表示加密后的密码存储在`/etc/shadow`文件中
- uid: 确定每一个用户的唯一数字
- gid: 确实用户main group的唯一数字（debian默认会为每个用户创建一个特定的组）
- GECOS: 包含用户全名的数据字段
- login directory: 存储用户个人文件的目录（环境变量`$HOME`通过指向此目录）
- program to execute upon login: 通常是命令行解释器(shell)，给予用户自由控制。如果你指定此字段值为`/bin/false`，这个用户将无法登录

### /etc/shadow

`/etc/shadow`文件包含如下字段

- login
- encrypted password
- several fields managing password expiration

可以使用此文件过期密码，或设置时间，直到密码过期后帐户被禁用。

### 修改账户或密码

下面的命令可以用来修改用户数据库(`/etc/passwd`, `/etc/shadow`)中的特定字段：

- `passwd`: 允许普通用户修改自己的密码，它会更新`/etc/shadow`文件
- `chpasswd`: 允许管理员批量修改一组用户的密码
- `chfn`: 修改全名，它会更新`GECOS`字段，只有root用户可以使用
- `chsh`: 允许用户修改他们的`login shell`，但是只能从`/etc/shells`中选择，root用户可以自由选择shell，不受此限制
- `chage`: 允许管理修改密码过期设置
  - `chage -l user`可以查看当前设置
  - `chage -e user`可以强制过期指定用户的密码，此用户下次登录时需要重新设置密码
- `usermod`: 可以修改上述所有

### 禁用账户

你可能会发现自己需要“禁用帐户”（锁定用户），作为纪律措施，用于调查目的，或者仅仅是在用户长期或最终缺席的情况。禁用帐户意味着用户无法登录或访问机器。该帐户在机器上保持完好无损，不会删除任何文件或数据，只是无法访问。可以通过使用命令`passwd -l user`（lock）来禁用账户，使用-u选项（解锁）重新启用帐户。然而，这只会阻止用户基于密码的登录。用户可能仍然能够使用SSH密钥（如果已配置）访问系统。为了防止这种可能性，你必须使用`chage -E 1user`或`usermod -e 1user`来使帐户过期。要（暂时）禁用所有用户帐户，只需创建文件`/etc/nologin`。

不仅可以通过上述方法锁定用户帐户，还可以通过更改其默认`login shell`（`chsh -s shell user`）来禁用用户帐户。如果`login shell`更改为`/usr/sbin/nologin`，用户会收到一条礼貌的消息，通知无法登录，而`/bin/false`只是在返回false时退出。注意，没有选项可以恢复上一个`shell`，在更改设置之前，你必须获取并保留该信息。这些`shell`通常用于不需要任何登录可用性的系统用户（例如`daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin`）。

> 除了使用文件管理用户与组外，还可以使用其他类型的数据库，例如`LDAP`或`db`来管理，通过使用适当的NSS（Name Service Switch）模块。使用的模块列在`/etc/nsswitch.conf`文件中配置，包括`passwd`、`shadow`和`group`条目。

### /etc/group

`/etc/group`文件存在组信息，它包含如下字段：

- group name
- password (optional): 这仅用于在用户不是普通成员时加入组
- gid: 唯一的组识别号
- list of members: 组成员用户姓名列表，以逗号分隔

下面的命令可以用于修改组：
- `addgroup`: 新增组
- `delgroup`: 删除组
- `groupmod`: 修改用户信息，例如`gid`
- `gpasswd group`: 修改组密码
- `gpasswd -r group`: 删除组密码

> `getent`命令可以通过标准方式获取数据库中的条目，例如
> ```
> ➜  ~ getent passwd daemon
> daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
> ```

### 创建账户

可以使用`adduser`命令创建一个新账户，它通过一系列的询问来完成。`/etc/adduser.conf`文件存储了`adduser`命令的设置。

`adduser user group`可以将用户增加到其他组中。

## 时区

可以使用`dpkg-reconfigure tzdata`命令修改时区，通过交互式方式完成。它的配置存储在`/etc/timezone`文件中。

```shell
➜  ~ cat /etc/timezone
Asia/Shanghai
```

如果只需要临时修改时区，可以使用环境变量`TZ`：

```shell
$ date
Thu Sep  2 22:29:48 CEST 2021
$ TZ="Pacific/Honolulu" date
Thu 02 Sep 2021 10:31:01 AM HST
```

## 日志归档

`logrotate`可以旋转归档日志，通过`/etc/logrotate.conf`和`/etc/logrotate.d/`中的配置文件完成。

## 开放管理员权限

`sudo`允许某些用户以特殊权限执行某些命令。在最常见的用例中，`sudo`允许受信任的用户以`root`身份执行任何命令，用户只需执行`sudo`命令并使用其个人密码进行身份验证。

安装后，`sudo`软件包为`sudo` Unix组的成员提供完整的`root`权限。要委派其他权限，可以使用`visudo`命令，该命令会修改`/etc/sudoers`配置文件。添加带有`user ALL=（ALL）ALL`的行允许相关用户以`root`身份执行任何命令。更复杂的配置只允许向特定用户授权特定命令。

