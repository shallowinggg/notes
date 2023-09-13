---
layout: default
title: 服务
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

# Unix服务

## System Boot

在具有`BIOS`的系统上，首先，`BIOS`控制计算机，初始化控制器和硬件，检测磁盘，并将所有东西连接在一起。然后，它按启动顺序查找第一个磁盘的主引导记录（`MBR`），并加载存储在那里的代码（第一阶段）。然后，此代码启动第二阶段，并最终执行`bootloader`。

与`BIOS`相比，`UEFI`更复杂，它知道文件系统并可以读取分区表。`UEFI`在系统存储中搜索一个标有特定全局唯一标识符（`GUID`）的分区，该分区标记为`EFI`系统分区（ESP）（`bootloader`、`boot managers`、`UEFI shell`等都位于该分区），然后启动`bootloader`。如果开启了安全启动，启动过程将通过签名验证`EFI`二进制文件的真实性。

在这两种情况下，`bootloader`都会接管启动流程，找到链路上的其他`bootloader`或磁盘上的内核，加载并执行它。然后内核进行初始化，开始搜索并挂载包含根文件系统的分区，最后执行第一个程序——`init`。事实上，“根分区”和`init`通常位于仅存在于`RAM`中的虚拟文件系统中（因此其名称为`initramfs`，以前称为`initrd`，意为`初始化RAM磁盘`）。该文件系统由`bootloader`加载到内存中，通常来自硬盘驱动器上的文件或来自网络。它包含内核加载“真正的”根文件系统所需的最低限度：这可能是硬盘驱动器的驱动程序模块，或者其他系统无法启动的设备，或者更常见的是，用于组装 `RAID` 的初始化脚本和模块阵列、打开加密分区、激活 `LVM` 卷等。一旦挂载根分区，`initramfs`将控制权移交给真正的`init`，然后机器返回到标准启动过程。

### systemd init

真正的`init`目前由`systemd`提供。

```shell
➜  ~ ll /usr/sbin/init
lrwxrwxrwx 1 root root 20 Aug  7  2022 /usr/sbin/init -> /lib/systemd/systemd
```

使用`systemd`运行Linux计算机的引导过程如下所示：

![](https://raw.githubusercontent.com/shallowinggg/notes/main/images/os/debian/system-boot.png)

`systemd`执行多个进程，负责设置系统：键盘、驱动程序、文件系统、网络、服务。它在做到这一点的同时保持对整个系统和组件要求的全局了解。每个组件都由一个`Unit File`（有时更多）描述；通用语法源自广泛使用的`*.ini`语法，其中`key = value`对分布在`[section]`标头之间。`Unit File`存储在`/lib/systemd/system/`和`/etc/systemd/system/`目录下；它们有多种风格，重点关注`services`和`targets`。

`.service`文件描述了由 `systemd` 管理的进程。它包含与旧式初始化脚本大致相同的信息，但以声明性（并且更简洁）的方式表达。 `systemd` 负责处理大量重复性任务（启动和停止进程、检查其状态、日志记录、删除权限等），而服务文件只需要填写进程的具体信息。例如，这是 SSH 的服务文件：

```
[Unit]
Description=OpenBSD Secure Shell server
Documentation=man:sshd(8) man:sshd_config(5)
After=network.target auditd.service
ConditionPathExists=!/etc/ssh/sshd_not_to_be_run

[Service]
EnvironmentFile=-/etc/default/ssh
ExecStartPre=/usr/sbin/sshd -t
ExecStart=/usr/sbin/sshd -D $SSHD_OPTS
ExecReload=/usr/sbin/sshd -t
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
“Restart=on-failure
RestartPreventExitStatus=255
Type=notify
RuntimeDirectory=sshd
RuntimeDirectoryMode=0755

[Install]
WantedBy=multi-user.target
Alias=sshd.service
```

由于`Unit File`是声明性的，而不是脚本或程序，因此它们不能直接运行，只能由 `systemd` 解释；因此，存在多个实用程序允许管理员与 `systemd` 交互并控制系统和每个组件的状态。

- systemctl
  - `systemctl status servicename.service`: 查看服务状态
  - `systemctl start servicename.service`: 手动启动服务
  - `systemctl stop servicename.service`: 手动停止服务
  - `systemctl restart servicename.service`: 重启服务
  - `systemctl enable servicename.service`: 系统启动时自动启动
  - `systemctl is-enabled servicename.service`: 检查服务是否被启用
  - other: `systemctl -h`查看
- journalctl
    - `journalctl -u servicename.service`: 查看服务日志
    - `journalctl -u servicename.service`: 持续展示最新日志，类似`tail -f`

## SSH

