---
layout: default
title: netty
parent: interview
# has_children: true
---

<details open markdown="block">
  <summary>
    Table of contents
  </summary>
  {: .text-delta }
- TOC
{:toc}
</details>

# 基础概念

## buffer

引用计数，通过`AtomicIntegerFieldUpdater`进行原子更新。计数器采取偶数计数法，即存储值为真实值的两倍。因为更新计数值时采取先更新再判断是否溢出的方式可以有效提升性能，但是也会因此引发一个bug：
```
1. Object has refCnt==1
2. We have 3 threads playing with this object
3. Thread-1 calls obj.release()
4. Thread-2 calls obj.retain() and sees the oldRef==0 then rolls back the increment (but the rollback is not atomic)
5. Thread-3 calls obj.retain() and sees oldRef==1 (from T-2 increment) therefore thinks the object is not dead
6. Thread-1 will call obj.deallocate()
```

此时Thread-3将使用一个已经销毁的缓冲区，如果Thread-3调用obj.release()，那么就会出现两次销毁的情况。为了解决这个问题，Netty的开发者使用偶数记录引用计数值，奇数作为已销毁的状态，这样可以保留一定的性能提升，同时解决这个bug。

### 直接缓存

使用`java.nio.ByteBuffer`存储，释放缓冲区时通过`Cleaner`进行。在Java6及其之后，使用反射调用；在Java9后，使用jdk Unsafe类提供的方法直接释放。



### 池化缓冲区

jemalloc使用了一个别出心裁的设计：arena。在进行内存分配的时候根据CPU核心数创建一定的arena区，在jemalloc为数量为 4 * cores，每个线程采用轮询的方式占用一个arena区，分配内存时在自己所述的arena中进行分配，这可以在很大程度上减少内存争用。比如一个拥有4个核心的CPU，我们将分配16个arena区，当只有16个线程的时候，它们之间将没有任何竞争。

现在我们将分配空间按大小进行分为三个主要的类别：small，large，huge。

- small的范围为2B ~ 2KB
- large的范围为4KB ~ 1MB
- huge的范围为 2MB ~

对于small类别，进行再一步的细分：

- tiny 2B - 8B
- quantum 16B - 512B
- sub-page 1KB - 4KB

至此，针对不同的需求，将分配不同的内存块。在arena中，以chunk为单位进行管理，对每个chunk的 使用了进行跟踪，分为QINIT, Q0, Q25, Q50, Q75, Q100

- QINIT使用量为 [0 , 25%)
- Q0使用量为 (0, 50%)
- Q25使用量为 [25%, 50%)
- Q50使用量为 [50%, 100%)
- Q75使用量为 [75%, 100%)
- Q100使用量为 [100%, )
当进行分配时，查找顺序为Q50, Q25, Q0, Q75。Q50是一个较为折中的选择，从此处开始查找，可以 让每个chunk的使用量尽可能的高，而不从Q75开始的原因是有一定的可能容量不够导致分配失败，增加了 切换到另一个有更多可用容量的chunk的开销。

为了能够更快的在chunk中定位到可分配的内存区域，在chunk中维护一个二叉平衡树，以页为基本单位 构造，结构为：

层数 大小
1 2MB
2 1MB 1MB
3 512K 512K 512K 512K
...
10 4K 4K 4K ...

当给定一个请求分配的大小时，从树顶部开始遍历即可。


Netty的池化缓冲区就是根据jemalloc来实现的，并且进行了一些微妙的修改：
- 页大小：8K
- 块大小：16M
- arena数量：2 * cores
- 最小分配大小：16B
- 使用ThreadLocalCache，为每个线程维护一块自己的缓冲区


#### 分配tiny缓冲区

size： [16B, 512B)
线程缓存分配32个槽位，分别缓存16B, 32B, 48B, ..., 496B大小的缓冲区。
首次分配某个大小的缓冲区时，无法从缓存中获取。因此需要分配一个新的chunk，并从中分配小缓冲区。

PoolChunk的结构是一个二叉树，将16M大小的块以8K的页为单位，分为2048份，自顶而下容量逐层减半，直到最后一层容量为8K。
```
 depth=0        1 node (chunkSize)
 depth=1        2 nodes (chunkSize/2)
 ..
 ..
 depth=d        2^d nodes (chunkSize/2^d)
 ..
 depth=maxOrder 2^maxOrder nodes (chunkSize/2^{maxOrder} = pageSize)
```
分配小缓冲区直接从最后一层分配即可，同时这一整个节点都用来分配此大小的小缓冲区，并且这个子页会被记录到arena的缓存中，之后可以再分配同样大小的缓冲区时直接走缓存即可，无需再经历复杂的分配过程。

#### 分配small缓冲区

size: [512B, 4KB]
线程缓存分配4个槽位，分别缓存512B, 1KB, 2KB, 4KB大小的缓冲区。

#### 分配normal缓冲区

与前两个一样，只是一次将会占用一个节点以上，因此也不存在一个节点多次使用的情况。

#### huge缓冲区

直接分配一块非池化的chunk使用。

#### 销毁

对于前三种缓冲区，会优先将其加入到线程缓存中以便下次使用。

#### 回收

当分配次数达到一定限度后，将会触发回收空闲缓存的操作。

关于PoolThreadCache的回收操作，涉及到了一个优化操作。设想如果应用持续的分配内存，那么这个回收操作将可以良好的运行，但是如果应用很长时间不再分配内存，那么回收操作将永远不会被触发，这将浪费许多内存空间。因此，Netty提供了一个新的选项，如果设置了io.netty.allocation.cacheTrimIntervalMillis，那么Netty将会开启一个线程用以定时回收空闲内存。


### FastThreadLocal

使用数组代替map以获取轻微的性能提升。初始化时建立一个大小为32的数组，可存储31个元素。并且通过填充缓冲行避免伪共享问题。

## concurrency

传统的线程池由于大量的上下文切换，导致了巨大的开销，并且还会导致其他的线程问题。

Netty线程模型的卓越性能取决于对于当前执行的Thread的身份的确定，也就是说，确定它是否是分配给当前Channel以及它的EventLoop的那一个线程(EventLoop将负责处理一个Channel的整个生命周期内的所有事件)。

EventLoopGroup负责为每个新创建的Channel分配一个EventLoop。在当前实现中，使用顺序循环（round-robin）的方式进行分配以获取一个均衡的分布，并且相同的EventLoop可能会被分配给多个Channel。

一旦一个Channel 被分配给一个EventLoop，它将在它的整个生命周期中都使用这个 EventLoop（以及相关联的Thread）。请牢记这一点，因为它可以使你从担忧你的Channel- Handler 实现中的线程安全和同步问题中解脱出来。

另外，需要注意的是，EventLoop 的分配方式对ThreadLocal 的使用的影响。因为一个 EventLoop 通常会被用于支撑多个Channel，所以对于所有相关联的Channel 来说， ThreadLocal 都将是一样的。这使得它对于实现状态追踪等功能来说是个糟糕的选择。然而， 在一些无状态的上下文中，它仍然可以被用于在多个Channel 之间共享一些重度的或者代价昂 贵的对象，甚至是事件。

## bootstrap

![init](/images/netty/init.png)

![register](/images/netty/register.png)

![bind](/images/netty/bind.png)

## event

### accept

Netty使用`NioEventLoop`处理NIO事件，包括`ACCEPT`, `CONNECT`, `READ`, `WRITE`。在它的`run()`方法中，集中处理`Selector#select()`，就绪事件以及任务。其中，任务的优先级最高，每一次循环中，如果存在任务，那么将只调用一次`selectNow()`方法查询就绪事件，之后处理就绪事件以及任务。如果不存在任务，那么获取最近一次定时任务的剩余到来时间timeout，调用`select(timeout)`等待时间到来。

其中，可能会出现jdk select空轮询bug，即每次`select`调用都返回0，一直循环，导致CPU空转。当空轮询达到预设次数时，即判定为出现此bug，将重建一个新的`Selector`，并将旧`Selector`绑定的`Channel`转移到新的`Selector`上。

当`ServerBootstrap`启动完成后，将等待连接到来。连接到来后，`ACCEPT`事件将就绪，Netty检测到后触发`read`操作，接受到来的请求并连接，生成一个`SocketChannel`，然后封装并通过`ServerBootStrapAcceptor`注册到子线程池中进行处理。

### read

Netty为每一个`Channel`维护了一个缓冲区分配处理器，默认初始缓冲区容量为65536。然后分配一个临时缓冲区用于接收此次来到的数据，并记录实际接收到的消息大小。分配处理器维护了一张缓冲区大小表，如果实际消息大小大于当前缓冲区容量，那么下次读取数据前将会分配一个更大容量的临时缓冲区；如果实际消息大小小于当前缓冲区容量，并不会立刻缩小缓冲区容量，如果下次读取依然小于当前容量，下一次读取数据前才会分配一个更小容量的临时缓冲区。当然，默认只有当前缓冲区读满了，才会进行下一次读取。同时，每接收一次消息后，将会调用`ChannelPipeline#fireChannelRead`方法，通知pipeline上的`ChannelHandler`读取消息。如果没有读取到数据，那么释放临时缓冲区，并结束读取。

缓冲区大小表如下：
```16, 32, 48, ..., 512, 1024, 2048, 4096, ...```

全部消息读取完成后，将调用`ChannelPipeline#fireChannelReadComplete`方法。

### write

调用`CHC#write()`方法写入数据，数据格式必须为`ByteBuf`或者`FileRegion`，可以通过编码器将数据转变为此种格式。每一个`Channel`都维护了一个缓冲区，数据将会暂存在缓冲区，而非每调用一次都写入一次，通过这种方法减少系统调用。缓冲区的结构为链表，如下所示：

```
Entry(flushedEntry) --> ... Entry(unflushedEntry) --> ... Entry(tailEntry)
```

写入时构造一个容器存储数据以及其他信息，并加入到缓冲区尾部。同时会记录缓冲区大小，如果超过阈值，将会调用`fireChannelWritabilityChanged()`通知`ChannelInboundHandler`调用`channelWritabilityChanged`进行限流，默认阈值为64KB，使用`WRITE_BUFFER_HIGH_WATER_MARK`可以设置其值。实现者可以调用`Channel#isWritable()`检查是否可以再写入。

如果需要真正将数据写入`Channel`中，那么需要调用`flush()`或者`writeAndFlush()`方法。它会将`flushedEntry`置为`unflushedEntry`，将`unflushedEntry`置空，因此从`flushedEntry`开始的节点全是未刷新的。之后从这些节点中获取`ByteBuffer[]`，最大数量为1024，最大值为`Integer#MAX_VALUE`，第二个值为可以通过`ChannelOption#SO_SNDBUF`设置，通过获取数组，可以利用gather特性一次写入多个缓冲区。不过，为了利用此特性，要求容器中存储的消息格式为`ByteBuf`，因此获取`ByteBuffer[]`时要求有一段连续的`ByteBuf`格式消息。如果消息格式为`FileRegion`，那么对其进行单独写入。因此，写入缓冲的消息时并不是一次就能全部写完，Netty设置了一个阈值16，即一共尝试从缓冲中写入16次，除非缓冲列表中多于16个不连续`FileRegion`格式消息，其他情况都能将缓冲列表的数据全部写完，这个值可以通过`ChannelOption#WRITE_SPIN_COUNT`设置。

当然，将数据写入`Channel`中时也会出现意外，比如无法将缓冲区中的数据全部写入，因此如果出现这种情况，将会在下一次循环中继续写入。如果一个字节都未写入，那么将结束写入，并设置`Channel`的`interestOp`为`WRITE`，eventloop下一次`select`检测到此事件时，将会再次执行刷新操作。

已经写入的数据需要从缓冲列表中删除，如果容器中全部数据都写入了，那么将移除这个容器并回收，否则设置其`readIndex`，下次从此位置继续写入。

### connect

当`Bootstrap`开始连接服务器时，连接操作是异步操作，并不一定会立刻成功，因此如果没有立刻连接，需要注册`CONNECT`事件等待连接成功。当eventloop检测到此事件时，需要等待其连接成功，方可执行读写操作。

![read-write](/images/netty/rw.png)

## decode

继承`ByteToMessageDecoder`基类，缓存到来的消息，并执行子类的`decode(...)`方法进行解码，如果解析成功则加入到输出列表（粘包，可能一次解码出多条消息）并向之后的`ChannelHandler`推送，否则等待下一次数据到来（半包）（不改变`readerIndex`）。

## encode

继承`MessageToByteEncoder`基类，根据子类泛型类型进行匹配。如果类型符合，那么分配一个大小为256字节的缓冲区，并调用子类实现的`encode(...)`方法进行编码。

# 常见面试题

 [https://www.cnblogs.com/xiaoyangjia/p/11526197.html](https://www.cnblogs.com/xiaoyangjia/p/11526197.html)

[https://www.jianshu.com/p/544c4ea707d7?tdsourcetag=s_pcqq_aiomsg](https://www.jianshu.com/p/544c4ea707d7?tdsourcetag=s_pcqq_aiomsg)
