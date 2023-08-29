---
layout: default
title: redis-sentinel
parent: database
grand_parent: interview
---

<details open markdown="block">
  <summary>
    Table of contents
  </summary>
  {: .text-delta }
- TOC
{:toc}
</details>

原文链接：https://pdai.tech/md/db/nosql-redis/db-redis-x-sentinel.html

# Redis Sentinel

下图是一个典型的哨兵集群监控的逻辑图：
![](https://pdai.tech/images/db/redis/db-redis-sen-1.png)

哨兵实现了什么功能呢？下面是Redis官方文档的描述：
- 监控（Monitoring）：哨兵会不断地检查主节点和从节点是否运作正常。
- - 自动故障转移（Automatic failover）：当主节点不能正常工作时，哨兵会开始自动故障转移操作，它会将失效主节点的其中一个从节点升级为新的主节点，并让其他从节点改为复制新的主节点。- 配置提供者（Configuration provider）：客户端在初始化时，通过连接哨兵来获得当前Redis服务的主节点地址。
- 通知（Notification）：哨兵可以将故障转移的结果发送给客户端。其中，监控和自动故障转移功能，使得哨兵可以及时发现主节点故障并完成转移；而配置提供者和通知功能，则需要在与客户端的交互中才能体现。

## 哨兵集群的组建

在主从集群中，主库上有一个名为__sentinel__:hello的频道，不同哨兵就是通过它来相互发现，实现互相通信的。在下图中，哨兵 1 把自己的 IP（172.16.19.3）和端口（26579）发布到__sentinel__:hello频道上，哨兵 2 和 3 订阅了该频道。那么此时，哨兵 2 和 3 就可以从这个频道直接获取哨兵 1 的 IP 地址和端口号。然后，哨兵 2、3 可以和哨兵 1 建立网络连接。

![](https://pdai.tech/images/db/redis/db-redis-sen-6.jpg)

通过这个方式，哨兵 2 和 3 也可以建立网络连接，这样一来，哨兵集群就形成了。它们相互间可以通过网络连接进行通信，比如说对主库有没有下线这件事儿进行判断和协商。


## 哨兵监控Redis

这是由哨兵向主库发送 INFO 命令来完成的。就像下图所示，哨兵 2 给主库发送 INFO 命令，主库接受到这个命令后，就会把从库列表返回给哨兵。接着，哨兵就可以根据从库列表中的连接信息，和每个从库建立连接，并在这个连接上持续地对从库进行监控。哨兵 1 和 3 可以通过相同的方法和从库建立连接。

![](https://pdai.tech/images/db/redis/db-redis-sen-7.jpg)

## 主库下线的判定

首先要理解两个概念：主观下线和客观下线

- 主观下线：任何一个哨兵都是可以监控探测，并作出Redis节点下线的判断；
- 客观下线：有哨兵集群共同决定Redis节点是否下线；

当某个哨兵（如下图中的哨兵2）判断主库“主观下线”后，就会给其他哨兵发送 is-master-down-by-addr 命令。接着，其他哨兵会根据自己和主库的连接情况，做出 Y 或 N 的响应，Y 相当于赞成票，N 相当于反对票。

![](https://pdai.tech/images/db/redis/db-redis-sen-2.jpg)

如果赞成票数（这里是2）是大于等于哨兵配置文件中的 quorum 配置项（比如这里如果是quorum=2）, 则可以判定主库客观下线了。

## 哨兵集群的选举

### 为什么必然会出现选举/共识机制？
为了避免哨兵的单点情况发生，所以需要一个哨兵的分布式集群。作为分布式集群，必然涉及共识问题（即选举问题）；同时故障的转移和通知都只需要一个主的哨兵节点就可以了。

### 哨兵的选举机制是什么样的？

哨兵的选举机制其实很简单，就是一个Raft选举算法： 选举的票数大于等于num(sentinels)/2+1时，将成为领导者，如果没有超过，继续选举。

任何一个想成为 Leader 的哨兵，要满足两个条件：
- 第一，拿到半数以上的赞成票；
- 第二，拿到的票数同时还需要大于等于哨兵配置文件中的 quorum 值。

以 3 个哨兵为例，假设此时的 quorum 设置为 2，那么，任何一个想成为 Leader 的哨兵只要拿到 2 张赞成票，就可以了。

## 新主库的选出

- 过滤掉不健康的（下线或断线），没有回复过哨兵ping响应的从节点
- 选择salve-priority从节点优先级最高（redis.conf）的
- 选择复制偏移量最大，只复制最完整的从节点

## 故障转移

假设根据我们一开始的图：（我们假设：判断主库客观下线了，同时选出sentinel 3是哨兵leader）

![](https://pdai.tech/images/db/redis/db-redis-sen-1.png)

故障转移流程如下：

![](https://pdai.tech/images/db/redis/db-redis-sen-4.png)

- 将slave-1脱离原从节点（PS: 5.0 中应该是replicaof no one)，升级主节点
- 将从节点slave-2指向新的主节点
- 通知客户端主节点已更换
- 将原主节点（oldMaster）变成从节点，指向新的主节点

转移之后

![](https://pdai.tech/images/db/redis/db-redis-sen-5.png)