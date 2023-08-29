---
layout: default
title: Read/Write
parent: Netty
nav_order: 4
grand_parent: Lib
---

<details open markdown="block">
  <summary>
    Table of contents
  </summary>
  {: .text-delta }
- TOC
{:toc}
</details>

`ServerBootstrap`启动成功后，`ServerChannel`开始监听`accpet`事件，具体处理监听事件的代码在`NioEventLoop`中。

```java
protected void run() {
    for (;;) {
        try {
            try {
                switch (selectStrategy.calculateStrategy(selectNowSupplier, hasTasks())) {
                case SelectStrategy.CONTINUE:
                    continue;

                case SelectStrategy.BUSY_WAIT:
                    // fall-through to SELECT since the busy-wait is not supported with NIO

                case SelectStrategy.SELECT:
                    // 调用Selector#select方法
                    select(wakenUp.getAndSet(false));

                    // 'wakenUp.compareAndSet(false, true)' is always evaluated
                    // before calling 'selector.wakeup()' to reduce the wake-up
                    // overhead. (Selector.wakeup() is an expensive operation.)
                    //
                    // However, there is a race condition in this approach.
                    // The race condition is triggered when 'wakenUp' is set to
                    // true too early.
                    //
                    // 'wakenUp' is set to true too early if:
                    // 1) Selector is waken up between 'wakenUp.set(false)' and
                    //    'selector.select(...)'. (BAD)
                    // 2) Selector is waken up between 'selector.select(...)' and
                    //    'if (wakenUp.get()) { ... }'. (OK)
                    //
                    // In the first case, 'wakenUp' is set to true and the
                    // following 'selector.select(...)' will wake up immediately.
                    // Until 'wakenUp' is set to false again in the next round,
                    // 'wakenUp.compareAndSet(false, true)' will fail, and therefore
                    // any attempt to wake up the Selector will fail, too, causing
                    // the following 'selector.select(...)' call to block
                    // unnecessarily.
                    //
                    // To fix this problem, we wake up the selector again if wakenUp
                    // is true immediately after selector.select(...).
                    // It is inefficient in that it wakes up the selector for both
                    // the first case (BAD - wake-up required) and the second case
                    // (OK - no wake-up required).

                    if (wakenUp.get()) {
                        selector.wakeup();
                    }
                    // fall through
                default:
                }
            } catch (IOException e) {
                // If we receive an IOException here its because the Selector is messed up. Let's rebuild
                // the selector and retry. https://github.com/netty/netty/issues/8566
                rebuildSelector0();
                handleLoopException(e);
                continue;
            }

            // 处理selectionKeys并且执行阻塞队列中的任务
            cancelledKeys = 0;
            needsToSelectAgain = false;
            final int ioRatio = this.ioRatio;
            if (ioRatio == 100) {
                try {
                    processSelectedKeys();
                } finally {
                    // Ensure we always run tasks.
                    runAllTasks();
                }
            } else {
                final long ioStartTime = System.nanoTime();
                try {
                    processSelectedKeys();
                } finally {
                    // Ensure we always run tasks.
                    final long ioTime = System.nanoTime() - ioStartTime;
                    runAllTasks(ioTime * (100 - ioRatio) / ioRatio);
                }
            }
        } catch (Throwable t) {
            handleLoopException(t);
        }
        // Always handle shutdown even if the loop processing threw an exception.
        try {
            if (isShuttingDown()) {
                closeAll();
                if (confirmShutdown()) {
                    return;
                }
            }
        } catch (Throwable t) {
            handleLoopException(t);
        }
    }
}

```

`NioEventLoop`的run方法是一个死循环，根据当前情况选择进行`Selector#select()`操作或者执行任务队列中的任务，Netty提供了一个默认的选取策略：

```java
@Override
public int calculateStrategy(IntSupplier selectSupplier, boolean hasTasks) throws Exception {
    return hasTasks ? selectSupplier.get() : SelectStrategy.SELECT;
}

private final IntSupplier selectNowSupplier = new IntSupplier() {
    @Override
    public int get() throws Exception {
        return selectNow();
    }
};

```

当任务队列中存在任务则根据`Selector#selectNow()`的返回值判定，如果存在任务需要执行，那么将执行任务；否则进行select操作。

`select(boolean)`方法将任务队列以及`Selector#select()`操作结合在一起，防止`select()`操作阻塞过久影响任务队列中的任务执行。同时，此方法还解决了jdk `select()`方法的bug，这个bug会在linux机器上出现空轮询，导致cpu占用100%。具体查看[此处](https://www.cnblogs.com/qiumingcheng/p/9481528.html)。

```java
private void select(boolean oldWakenUp) throws IOException {
    Selector selector = this.selector;
    try {
        int selectCnt = 0;
        long currentTimeNanos = System.nanoTime();
        long selectDeadLineNanos = currentTimeNanos + delayNanos(currentTimeNanos);

        long normalizedDeadlineNanos = selectDeadLineNanos - initialNanoTime();
        if (nextWakeupTime != normalizedDeadlineNanos) {
            nextWakeupTime = normalizedDeadlineNanos;
        }

        for (;;) {
            long timeoutMillis = (selectDeadLineNanos - currentTimeNanos + 500000L) / 1000000L;
            // 当下一个定时任务马上就要执行时，则跳出循环
            if (timeoutMillis <= 0) {
                if (selectCnt == 0) {
                    selector.selectNow();
                    selectCnt = 1;
                }
                break;
            }

            // If a task was submitted when wakenUp value was true, the task didn't get a chance to call
            // Selector#wakeup. So we need to check task queue again before executing select operation.
            // If we don't, the task might be pended until select operation was timed out.
            // It might be pended until idle timeout if IdleStateHandler existed in pipeline.
            if (hasTasks() && wakenUp.compareAndSet(false, true)) {
                selector.selectNow();
                selectCnt = 1;
                break;
            }

            // 执行select操作
            int selectedKeys = selector.select(timeoutMillis);
            selectCnt ++;

            if (selectedKeys != 0 || oldWakenUp || wakenUp.get() || hasTasks() || hasScheduledTasks()) {
                // - Selected something,
                // - waken up by user, or
                // - the task queue has a pending task.
                // - a scheduled task is ready for processing
                break;
            }
            if (Thread.interrupted()) {
                // Thread was interrupted so reset selected keys and break so we not run into a busy loop.
                // As this is most likely a bug in the handler of the user or it's client library we will
                // also log it.
                //
                // See https://github.com/netty/netty/issues/2426
                if (logger.isDebugEnabled()) {
                    logger.debug("Selector.select() returned prematurely because " +
                            "Thread.currentThread().interrupt() was called. Use " +
                            "NioEventLoop.shutdownGracefully() to shutdown the NioEventLoop.");
                }
                selectCnt = 1;
                break;
            }

            long time = System.nanoTime();
            // 如果下一个定时任务的执行时间还未到，则继续循环进行下一次select
            if (time - TimeUnit.MILLISECONDS.toNanos(timeoutMillis) >= currentTimeNanos) {
                // timeoutMillis elapsed without anything selected.
                selectCnt = 1;
            } else if (SELECTOR_AUTO_REBUILD_THRESHOLD > 0 &&
                    selectCnt >= SELECTOR_AUTO_REBUILD_THRESHOLD) {
                // 解决jdk seletor空轮询bug
                // The code exists in an extra method to ensure the method is not too big to inline as this
                // branch is not very likely to get hit very frequently.
                selector = selectRebuildSelector(selectCnt);
                selectCnt = 1;
                break;
            }

            currentTimeNanos = time;
        }

        if (selectCnt > MIN_PREMATURE_SELECTOR_RETURNS) {
            if (logger.isDebugEnabled()) {
                logger.debug("Selector.select() returned prematurely {} times in a row for Selector {}.",
                        selectCnt - 1, selector);
            }
        }
    } catch (CancelledKeyException e) {
        if (logger.isDebugEnabled()) {
            logger.debug(CancelledKeyException.class.getSimpleName() + " raised by a Selector {} - JDK bug?",
                    selector, e);
        }
        // Harmless exception - log anyway
    }
}

private Selector selectRebuildSelector(int selectCnt) throws IOException {
    // The selector returned prematurely many times in a row.
    // Rebuild the selector to work around the problem.
    logger.warn(
            "Selector.select() returned prematurely {} times in a row; rebuilding Selector {}.",
            selectCnt, selector);

    rebuildSelector();
    Selector selector = this.selector;

    // Select again to populate selectedKeys.
    selector.selectNow();
    return selector;
}

public void rebuildSelector() {
    if (!inEventLoop()) {
        execute(new Runnable() {
            @Override
            public void run() {
                rebuildSelector0();
            }
        });
        return;
    }
    rebuildSelector0();
}

private void rebuildSelector0() {
    final Selector oldSelector = selector;
    final SelectorTuple newSelectorTuple;

    if (oldSelector == null) {
        return;
    }

    try {
        // 开启一个新的selector
        newSelectorTuple = openSelector();
    } catch (Exception e) {
        logger.warn("Failed to create a new Selector.", e);
        return;
    }

    // Register all channels to the new Selector.
    int nChannels = 0;
    // 对于所有旧的channel，将它们注册到新的selector上，并将旧的selectionKey取消
    for (SelectionKey key: oldSelector.keys()) {
        Object a = key.attachment();
        try {
            if (!key.isValid() || key.channel().keyFor(newSelectorTuple.unwrappedSelector) != null) {
                continue;
            }

            int interestOps = key.interestOps();
            key.cancel();
            SelectionKey newKey = key.channel().register(newSelectorTuple.unwrappedSelector, interestOps, a);
            if (a instanceof AbstractNioChannel) {
                // Update SelectionKey
                ((AbstractNioChannel) a).selectionKey = newKey;
            }
            nChannels ++;
        } catch (Exception e) {
            logger.warn("Failed to re-register a Channel to the new Selector.", e);
            if (a instanceof AbstractNioChannel) {
                AbstractNioChannel ch = (AbstractNioChannel) a;
                ch.unsafe().close(ch.unsafe().voidPromise());
            } else {
                @SuppressWarnings("unchecked")
                NioTask<SelectableChannel> task = (NioTask<SelectableChannel>) a;
                invokeChannelUnregistered(task, key, e);
            }
        }
    }

    selector = newSelectorTuple.selector;
    unwrappedSelector = newSelectorTuple.unwrappedSelector;

    try {
        // time to close the old selector as everything else is registered to the new one
        oldSelector.close();
    } catch (Throwable t) {
        if (logger.isWarnEnabled()) {
            logger.warn("Failed to close the old Selector.", t);
        }
    }

    if (logger.isInfoEnabled()) {
        logger.info("Migrated " + nChannels + " channel(s) to the new Selector.");
    }
}

```

当`select()`操作执行完后，需要对获取到的`SelectionKey`进行处理。Netty对JDK提供的Selector进行了一定优化，并提供`processSelectedKeysOptimized()`方法进行更快的处理，此处只讨论`SelectionKey`的正常处理方法。

```java
private void processSelectedKeys() {
    if (selectedKeys != null) {
        processSelectedKeysOptimized();
    } else {
        processSelectedKeysPlain(selector.selectedKeys());
    }
}

private void processSelectedKeysPlain(Set<SelectionKey> selectedKeys) {
    // check if the set is empty and if so just return to not create garbage by
    // creating a new Iterator every time even if there is nothing to process.
    // See https://github.com/netty/netty/issues/597
    if (selectedKeys.isEmpty()) {
        return;
    }

    Iterator<SelectionKey> i = selectedKeys.iterator();
    for (;;) {
        final SelectionKey k = i.next();
        // ServerChannel注册到selector上时将自己作为attachment
        final Object a = k.attachment();
        i.remove();

        if (a instanceof AbstractNioChannel) {
            // 真正的处理方法
            processSelectedKey(k, (AbstractNioChannel) a);
        } else {
            @SuppressWarnings("unchecked")
            NioTask<SelectableChannel> task = (NioTask<SelectableChannel>) a;
            processSelectedKey(k, task);
        }

        if (!i.hasNext()) {
            break;
        }

        if (needsToSelectAgain) {
            selectAgain();
            selectedKeys = selector.selectedKeys();

            // Create the iterator again to avoid ConcurrentModificationException
            if (selectedKeys.isEmpty()) {
                break;
            } else {
                i = selectedKeys.iterator();
            }
        }
    }
}

private void processSelectedKey(SelectionKey k, AbstractNioChannel ch) {
    final AbstractNioChannel.NioUnsafe unsafe = ch.unsafe();
    // 如果key不合法，那么将此channel关闭
    if (!k.isValid()) {
        final EventLoop eventLoop;
        try {
            eventLoop = ch.eventLoop();
        } catch (Throwable ignored) {
            // If the channel implementation throws an exception because there is no event loop, we ignore this
            // because we are only trying to determine if ch is registered to this event loop and thus has authority
            // to close ch.
            return;
        }
        // Only close ch if ch is still registered to this EventLoop. ch could have deregistered from the event loop
        // and thus the SelectionKey could be cancelled as part of the deregistration process, but the channel is
        // still healthy and should not be closed.
        // See https://github.com/netty/netty/issues/5125
        if (eventLoop != this || eventLoop == null) {
            return;
        }
        // close the channel if the key is not valid anymore
        unsafe.close(unsafe.voidPromise());
        return;
    }

    try {
        int readyOps = k.readyOps();
        // We first need to call finishConnect() before try to trigger a read(...) or write(...) as otherwise
        // the NIO JDK channel implementation may throw a NotYetConnectedException.
        if ((readyOps & SelectionKey.OP_CONNECT) != 0) {
            // remove OP_CONNECT as otherwise Selector.select(..) will always return without blocking
            // See https://github.com/netty/netty/issues/924
            int ops = k.interestOps();
            ops &= ~SelectionKey.OP_CONNECT;
            k.interestOps(ops);

            unsafe.finishConnect();
        }

        // Process OP_WRITE first as we may be able to write some queued buffers and so free memory.
        if ((readyOps & SelectionKey.OP_WRITE) != 0) {
            // Call forceFlush which will also take care of clear the OP_WRITE once there is nothing left to write
            ch.unsafe().forceFlush();
        }

        // Also check for readOps of 0 to workaround possible JDK bug which may otherwise lead
        // to a spin loop
        if ((readyOps & (SelectionKey.OP_READ | SelectionKey.OP_ACCEPT)) != 0 || readyOps == 0) {
            unsafe.read();
        }
    } catch (CancelledKeyException ignored) {
        unsafe.close(unsafe.voidPromise());
    }
}

```

## accept

此方法中涵盖了`CONNECT`, `WRITE`, `READ`, `ACCEPT`四种事件，在此处我们只关心`ServerChannel`的`accept`事件。

```java
# AbstractNioMessageChannel.java --------------------
@Override
public void read() {
    assert eventLoop().inEventLoop();
    final ChannelConfig config = config();
    final ChannelPipeline pipeline = pipeline();
    final RecvByteBufAllocator.Handle allocHandle = unsafe().recvBufAllocHandle();
    allocHandle.reset(config);

    boolean closed = false;
    Throwable exception = null;
    try {
        try {
            do {
                // 处理收到的信息，对于ServerChannel则是一个Channel
                int localRead = doReadMessages(readBuf);
                if (localRead == 0) {
                    break;
                }
                if (localRead < 0) {
                    closed = true;
                    break;
                }

                allocHandle.incMessagesRead(localRead);
            } while (allocHandle.continueReading());
        } catch (Throwable t) {
            exception = t;
        }

        int size = readBuf.size();
        for (int i = 0; i < size; i ++) {
            readPending = false;
            // 通知pipeline上的CHC执行channelRead()方法
            pipeline.fireChannelRead(readBuf.get(i));
        }
        readBuf.clear();
        allocHandle.readComplete();
        pipeline.fireChannelReadComplete();

        if (exception != null) {
            closed = closeOnReadError(exception);

            pipeline.fireExceptionCaught(exception);
        }

        if (closed) {
            inputShutdown = true;
            if (isOpen()) {
                close(voidPromise());
            }
        }
    } finally {
        // Check if there is a readPending which was not processed yet.
        // This could be for two reasons:
        // * The user called Channel.read() or ChannelHandlerContext.read() in channelRead(...) method
        // * The user called Channel.read() or ChannelHandlerContext.read() in channelReadComplete(...) method
        //
        // See https://github.com/netty/netty/issues/2254
        if (!readPending && !config.isAutoRead()) {
            removeReadOp();
        }
    }
}


@Override
protected int doReadMessages(List<Object> buf) throws Exception {
    SocketChannel ch = SocketUtils.accept(javaChannel());

    try {
        if (ch != null) {
            buf.add(new NioSocketChannel(this, ch));
            return 1;
        }
    } catch (Throwable t) {
        logger.warn("Failed to create a new channel from an accepted socket.", t);

        try {
            ch.close();
        } catch (Throwable t2) {
            logger.warn("Failed to close a socket.", t2);
        }
    }

    return 0;
}

public static SocketChannel accept(final ServerSocketChannel serverSocketChannel) throws IOException {
    try {
        return AccessController.doPrivileged(new PrivilegedExceptionAction<SocketChannel>() {
            @Override
            public SocketChannel run() throws IOException {
                return serverSocketChannel.accept();
            }
        });
    } catch (PrivilegedActionException e) {
        throw (IOException) e.getCause();
    }
}

```

我们先不关心`allocHandle`的存在，它对accept事件用处不大。在`doReadMessages`方法中，调用了`ServerSocketChannel#accept()`方法，与远程主机建立了连接，并返回一个`SocketChannel`，然后将其封装为Netty自己的`NioSocketChannel`，其`interestOps`为`READ`。获取到所有的`SocketChannel`后，通知pipeline上的CHC调用`channelRead`方法，此方法属于`ChannelInboundHandler`。之前执行`bind()`方法时我们发现pipeline上共有三个ChannelHandler，并且它们都是`ChannelInboundHandler`的子类，其中构造`ServerChannel`后再没有出现的`ServerBootstrapAcceptor`在此处成为了关键角色。

```java
@Override
@SuppressWarnings("unchecked")
public void channelRead(ChannelHandlerContext ctx, Object msg) {
    final Channel child = (Channel) msg;

    child.pipeline().addLast(childHandler);

    setChannelOptions(child, childOptions, logger);
    setAttributes(child, childAttrs);

    try {
        childGroup.register(child).addListener(new ChannelFutureListener() {
            @Override
            public void operationComplete(ChannelFuture future) throws Exception {
                if (!future.isSuccess()) {
                    forceClose(child, future.cause());
                }
            }
        });
    } catch (Throwable t) {
        forceClose(child, t);
    }
}

```
`ServerBootstrapAcceptor`对接收到的`SocketChannel`进行处理，增加`childHandler`，设置属性，最后将其注册到`childGroup`中。此处展现了NIO的经典线程模型，`bossGroup`只用来接受连接请求，真正的读写通信都在`childGroup`中执行。

`ServerBootstrap`存在一个方法`childHandler(ChannelHandler childHandler)`，可以用来设置`childHandler`。

## read

此时，客户端已经和服务端建立了完整的联系，当客户端向服务端发送消息时，将触发相应`SocketChannel`的`READ`事件。回到之前的`processSelectedKey`方法，此时我们关注`READ`事件，不过处理逻辑不再处于`NioServerSocketChannel`的父类`AbstractNioMessageChannel`，而是`NioSocketChannel`的父类`AbstractNioByteChannel`。

```java
@Override
public final void read() {
    final ChannelConfig config = config();
    if (shouldBreakReadReady(config)) {
        clearReadPending();
        return;
    }
    final ChannelPipeline pipeline = pipeline();
    // 默认为pool direct，android平台为unpool direct
    final ByteBufAllocator allocator = config.getAllocator();
    // 默认为AdaptiveRecvByteBufAllocator#newHandle()
    final RecvByteBufAllocator.Handle allocHandle = recvBufAllocHandle();
    allocHandle.reset(config);

    ByteBuf byteBuf = null;
    boolean close = false;
    try {
        do {
            // 分配一个临时缓冲区，用以接受数据
            byteBuf = allocHandle.allocate(allocator);
            // 读取Channel中的数据
            allocHandle.lastBytesRead(doReadBytes(byteBuf));
            // 如果没有读到数据，结束读取
            if (allocHandle.lastBytesRead() <= 0) {
                // nothing was read. release the buffer.
                byteBuf.release();
                byteBuf = null;
                close = allocHandle.lastBytesRead() < 0;
                if (close) {
                    // There is nothing left to read as we received an EOF.
                    readPending = false;
                }
                break;
            }

            allocHandle.incMessagesRead(1);
            readPending = false;
            // 通知pipeline上的CHC调用channelRead方法
            pipeline.fireChannelRead(byteBuf);
            byteBuf = null;
        } while (allocHandle.continueReading());

        allocHandle.readComplete();
        // 通过pipeline上的CHC调用channelReadComplete方法
        pipeline.fireChannelReadComplete();

        if (close) {
            closeOnRead(pipeline);
        }
    } catch (Throwable t) {
        handleReadException(pipeline, byteBuf, t, close, allocHandle);
    } finally {
        // Check if there is a readPending which was not processed yet.
        // This could be for two reasons:
        // * The user called Channel.read() or ChannelHandlerContext.read() in channelRead(...) method
        // * The user called Channel.read() or ChannelHandlerContext.read() in channelReadComplete(...) method
        //
        // See https://github.com/netty/netty/issues/2254
        if (!readPending && !config.isAutoRead()) {
            removeReadOp();
        }
    }
}

@Override
public Handle newHandle() {
    // 64， 1024， 65536
    return new HandleImpl(minIndex, maxIndex, initial);
}

HandleImpl(int minIndex, int maxIndex, int initial) {
    this.minIndex = minIndex;
    this.maxIndex = maxIndex;

    index = getSizeTableIndex(initial);
    nextReceiveBufferSize = SIZE_TABLE[index];
}

@Override
public int guess() {
    return nextReceiveBufferSize;
}

@Override
public ByteBuf allocate(ByteBufAllocator alloc) {
    return alloc.ioBuffer(guess());
}


@Override
protected int doReadBytes(ByteBuf byteBuf) throws Exception {
    final RecvByteBufAllocator.Handle allocHandle = unsafe().recvBufAllocHandle();
    allocHandle.attemptedBytesRead(byteBuf.writableBytes());
    return byteBuf.writeBytes(javaChannel(), allocHandle.attemptedBytesRead());
}

```

默认情况下猜测第一次到来的消息大小为65536字节，分配完缓冲区后，从`SocketChannel`中尝试读取缓冲区最大可写字节的数据，然后调用pipeline上各个`ChannelHandler`的`channelRead`方法，此时就会触发用户提供的`ChannelHandler`进行相应的处理。当`Channel`中的所有数据都读取完后，调用pipeline上各个`ChannelHandler`的`channelReadComplete`方法；同时也会调用`allocHandle.readComplete()`方法，记录此次读取的字节数，用于决定下一次读取数据时分配缓冲区的猜测大小，`allocHandle`的核心功能便在于此。


## write

写操作一般调用`ChannelHandlerContext#write(Object)`执行，当然也可以调用`writeAndFlush(Object)`方法。

```java
@Override
public ChannelFuture write(Object msg) {
    return write(msg, newPromise());
}

@Override
public ChannelFuture write(final Object msg, final ChannelPromise promise) {
    write(msg, false, promise);

    return promise;
}

private void write(Object msg, boolean flush, ChannelPromise promise) {
    ObjectUtil.checkNotNull(msg, "msg");
    try {
        if (isNotValidPromise(promise, true)) {
            ReferenceCountUtil.release(msg);
            // cancelled
            return;
        }
    } catch (RuntimeException e) {
        ReferenceCountUtil.release(msg);
        throw e;
    }

    // 查找合适的ChannelHandler
    final AbstractChannelHandlerContext next = findContextOutbound(flush ?
            (MASK_WRITE | MASK_FLUSH) : MASK_WRITE);
    // 记录ResourceTracker debug信息
    final Object m = pipeline.touch(msg, next);
    EventExecutor executor = next.executor();
    if (executor.inEventLoop()) {
        if (flush) {
            next.invokeWriteAndFlush(m, promise);
        } else {
            next.invokeWrite(m, promise);
        }
    } else {
        final AbstractWriteTask task;
        if (flush) {
            task = WriteAndFlushTask.newInstance(next, m, promise);
        }  else {
            task = WriteTask.newInstance(next, m, promise);
        }
        if (!safeExecute(executor, task, promise, m)) {
            // We failed to submit the AbstractWriteTask. We need to cancel it so we decrement the pending bytes
            // and put it back in the Recycler for re-use later.
            //
            // See https://github.com/netty/netty/issues/8343.
            task.cancel();
        }
    }
}

private void invokeWrite(Object msg, ChannelPromise promise) {
    if (invokeHandler()) {
        invokeWrite0(msg, promise);
    } else {
        write(msg, promise);
    }
}

private void invokeWrite0(Object msg, ChannelPromise promise) {
    try {
        ((ChannelOutboundHandler) handler()).write(this, msg, promise);
    } catch (Throwable t) {
        notifyOutboundHandlerException(t, promise);
    }
}
```

写操作最终通过pipeline头部的`HeadContext`执行，但是当使用nio时这个`ChannelHandler`只接受`ByteBuf`和`FileRegion`这两种类型的数据，所以如果写入的对象不是这两种类型，那么需要一个编码器将此对象转换为`ByteBuf`。

```java
@Override
public void write(ChannelHandlerContext ctx, Object msg, ChannelPromise promise) {
    unsafe.write(msg, promise);
}

@Override
public final void write(Object msg, ChannelPromise promise) {
    assertEventLoop();

    ChannelOutboundBuffer outboundBuffer = this.outboundBuffer;
    if (outboundBuffer == null) {
        // If the outboundBuffer is null we know the channel was closed and so
        // need to fail the future right away. If it is not null the handling of the rest
        // will be done in flush0()
        // See https://github.com/netty/netty/issues/2362
        safeSetFailure(promise, newClosedChannelException(initialCloseCause));
        // release message now to prevent resource-leak
        ReferenceCountUtil.release(msg);
        return;
    }

    int size;
    try {
        // NioSocketChannel只支持ByteBuf和FileRegion
        msg = filterOutboundMessage(msg);
        // 推算此次传输的字节数
        size = pipeline.estimatorHandle().size(msg);
        if (size < 0) {
            size = 0;
        }
    } catch (Throwable t) {
        safeSetFailure(promise, t);
        ReferenceCountUtil.release(msg);
        return;
    }

    // 加入到缓冲区等待发送
    outboundBuffer.addMessage(msg, size, promise);
}


# AbstractNioByteChannel.java --------------------------

@Override
protected final Object filterOutboundMessage(Object msg) {
    if (msg instanceof ByteBuf) {
        ByteBuf buf = (ByteBuf) msg;
        if (buf.isDirect()) {
            return msg;
        }

        return newDirectBuffer(buf);
    }

    if (msg instanceof FileRegion) {
        return msg;
    }

    throw new UnsupportedOperationException(
            "unsupported message type: " + StringUtil.simpleClassName(msg) + EXPECTED_TYPES);
}

@Override
public int size(Object msg) {
    if (msg instanceof ByteBuf) {
        return ((ByteBuf) msg).readableBytes();
    }
    if (msg instanceof ByteBufHolder) {
        return ((ByteBufHolder) msg).content().readableBytes();
    }
    if (msg instanceof FileRegion) {
        return 0;
    }
    return unknownSize;
}

```

`outboundBuffer`是`unsafe`初始化时构造的：
```java
private volatile ChannelOutboundBuffer outboundBuffer = new ChannelOutboundBuffer(AbstractChannel.this);
```

它是Netty内建的缓冲区，用于储存`AbstractChannel`的写请求，存储结构为链表形式：

```
Entry(flushedEntry) --> ... Entry(unflushedEntry) --> ... Entry(tailEntry)
```

- `flushedEntry`为已经被刷新的数据条目，处于链表头部；
- `unflushedEntry`为第一个未被刷新的数据条目；
- `tailEntry`是一个标志条目，用于表示缓冲区末尾。

```java
public void addMessage(Object msg, int size, ChannelPromise promise) {
    // 构造一个新的条目保存信息
    Entry entry = Entry.newInstance(msg, size, total(msg), promise);
    // 加入到链表中
    if (tailEntry == null) {
        flushedEntry = null;
    } else {
        Entry tail = tailEntry;
        tail.next = entry;
    }
    tailEntry = entry;
    if (unflushedEntry == null) {
        unflushedEntry = entry;
    }

    // increment pending bytes after adding message to the unflushed arrays.
    // See https://github.com/netty/netty/issues/1619
    // 记录条目占用的字节数，用于流量控制
    incrementPendingOutboundBytes(entry.pendingSize, false);
}

private static long total(Object msg) {
    if (msg instanceof ByteBuf) {
        return ((ByteBuf) msg).readableBytes();
    }
    if (msg instanceof FileRegion) {
        return ((FileRegion) msg).count();
    }
    if (msg instanceof ByteBufHolder) {
        return ((ByteBufHolder) msg).content().readableBytes();
    }
    return -1;
}
```

将消息增加到缓冲区一共分为三步：
1. 构造一个`Entry`用于保存消息，注意`Entry`是可以复用的；
2. 将`Entry`加入到链表中；
3. 记录新增的字节数，进行流量控制

```java
static Entry newInstance(Object msg, int size, long total, ChannelPromise promise) {
    Entry entry = RECYCLER.get();
    entry.msg = msg;
    // 设置消息大小
    entry.pendingSize = size + CHANNEL_OUTBOUND_BUFFER_ENTRY_OVERHEAD;
    entry.total = total;
    entry.promise = promise;
    return entry;
}

public final T get() {
    // 默认为4K
    if (maxCapacityPerThread == 0) {
        return newObject((Handle<T>) NOOP_HANDLE);
    }
    // 使用栈复用对象
    Stack<T> stack = threadLocal.get();
    DefaultHandle<T> handle = stack.pop();
    if (handle == null) {
        handle = stack.newHandle();
        handle.value = newObject(handle);
    }
    return (T) handle.value;
}

private static final Recycler<Entry> RECYCLER = new Recycler<Entry>() {
    @Override
    protected Entry newObject(Handle<Entry> handle) {
        return new Entry(handle);
    }
};

private Entry(Handle<Entry> handle) {
    this.handle = handle;
}

```

此处`Recycler`是一个经典的对象池，同时每个线程都维护其对应的对象池，减少了并发争用。

```java
private void incrementPendingOutboundBytes(long size, boolean invokeLater) {
    if (size == 0) {
        return;
    }

    // 原子更新缓冲区大小
    long newWriteBufferSize = TOTAL_PENDING_SIZE_UPDATER.addAndGet(this, size);
    // 当缓冲区大小超过阈值，禁止写入
    if (newWriteBufferSize > channel.config().getWriteBufferHighWaterMark()) {
        setUnwritable(invokeLater);
    }
}

private void setUnwritable(boolean invokeLater) {
    for (;;) {
        // 设置unwritable标识位为1
        final int oldValue = unwritable;
        final int newValue = oldValue | 1;
        if (UNWRITABLE_UPDATER.compareAndSet(this, oldValue, newValue)) {
            if (oldValue == 0 && newValue != 0) {
                fireChannelWritabilityChanged(invokeLater);
            }
            break;
        }
    }
}

private void fireChannelWritabilityChanged(boolean invokeLater) {
    final ChannelPipeline pipeline = channel.pipeline();
    if (invokeLater) {
        Runnable task = fireChannelWritabilityChangedTask;
        if (task == null) {
            fireChannelWritabilityChangedTask = task = new Runnable() {
                @Override
                public void run() {
                    pipeline.fireChannelWritabilityChanged();
                }
            };
        }
        channel.eventLoop().execute(task);
    } else {
        pipeline.fireChannelWritabilityChanged();
    }
}
```

当缓冲区超过64KB（默认值）时，将会设置`unwritable`为1，并通知pipeline上的`ChannelInboundHandler`调用其`channelWritabilityChanged`方法。用户自定义的`ChannelHandler`可以实现此方法进行限流。

调用`write`方法只会将消息置于缓冲区，还需要调用`flush`方法将缓冲区的数据刷新到`Channel`中。

```java
@Override
public ChannelHandlerContext flush() {
    final AbstractChannelHandlerContext next = findContextOutbound(MASK_FLUSH);
    EventExecutor executor = next.executor();
    if (executor.inEventLoop()) {
        next.invokeFlush();
    } else {
        Tasks tasks = next.invokeTasks;
        if (tasks == null) {
            next.invokeTasks = tasks = new Tasks(next);
        }
        safeExecute(executor, tasks.invokeFlushTask, channel().voidPromise(), null);
    }

    return this;
}

private void invokeFlush() {
    if (invokeHandler()) {
        invokeFlush0();
    } else {
        flush();
    }
}

private void invokeFlush0() {
    try {
        ((ChannelOutboundHandler) handler()).flush(this);
    } catch (Throwable t) {
        notifyHandlerException(t);
    }
}

@Override
public void flush(ChannelHandlerContext ctx) {
    unsafe.flush();
}

@Override
public final void flush() {
    assertEventLoop();

    ChannelOutboundBuffer outboundBuffer = this.outboundBuffer;
    if (outboundBuffer == null) {
        return;
    }

    outboundBuffer.addFlush();
    flush0();
}

```

刷新操作共两步，先将`flushedEntry`指向等待刷新的条目，再执行刷新操作。

```java
public void addFlush() {
    // There is no need to process all entries if there was already a flush before and no new messages
    // where added in the meantime.
    //
    // See https://github.com/netty/netty/issues/2577
    Entry entry = unflushedEntry;
    if (entry != null) {
        if (flushedEntry == null) {
            // there is no flushedEntry yet, so start with the entry
            flushedEntry = entry;
        }
        do {
            flushed ++;
            // 如果写请求被取消，那么不发送此条消息
            if (!entry.promise.setUncancellable()) {
                // Was cancelled so make sure we free up memory and notify about the freed bytes
                int pending = entry.cancel();
                decrementPendingOutboundBytes(pending, false, true);
            }
            entry = entry.next;
        } while (entry != null);

        // All flushed so reset unflushedEntry
        unflushedEntry = null;
    }
}

```

`flush0()`方法较为复杂，首先对刷新操作进行控制，如果已经有刷新操作在进行，那么此次刷新取消。由于Netty的线程模型为一个线程对应多个`Channel`，所以某一个`Channel`内的多个刷新操作只会由一个线程执行，`inFlush0`不需要进行并发控制。如果`Channel`处于未激活状态（比如尚未连接），那么需要拒绝此次刷新操作。最后，执行真正的刷新操作。

```java
protected void flush0() {
    if (inFlush0) {
        // Avoid re-entrance
        return;
    }

    final ChannelOutboundBuffer outboundBuffer = this.outboundBuffer;
    if (outboundBuffer == null || outboundBuffer.isEmpty()) {
        return;
    }

    inFlush0 = true;

    // Mark all pending write requests as failure if the channel is inactive.
    if (!isActive()) {
        try {
            if (isOpen()) {
                outboundBuffer.failFlushed(new NotYetConnectedException(), true);
            } else {
                // Do not trigger channelWritabilityChanged because the channel is closed already.
                outboundBuffer.failFlushed(newClosedChannelException(initialCloseCause), false);
            }
        } finally {
            inFlush0 = false;
        }
        return;
    }

    try {
        doWrite(outboundBuffer);
    } catch (Throwable t) {
        if (t instanceof IOException && config().isAutoClose()) {
            /**
             * Just call {@link #close(ChannelPromise, Throwable, boolean)} here which will take care of
             * failing all flushed messages and also ensure the actual close of the underlying transport
             * will happen before the promises are notified.
             *
             * This is needed as otherwise {@link #isActive()} , {@link #isOpen()} and {@link #isWritable()}
             * may still return {@code true} even if the channel should be closed as result of the exception.
             */
            initialCloseCause = t;
            close(voidPromise(), t, newClosedChannelException(t), false);
        } else {
            try {
                shutdownOutput(voidPromise(), t);
            } catch (Throwable t2) {
                initialCloseCause = t;
                close(voidPromise(), t2, newClosedChannelException(t), false);
            }
        }
    } finally {
        inFlush0 = false;
    }
}
```

NIO针对写操作提供了gather方法，可以一次性写入多个`ByteBuffer`，此处就利用了这一特性。首先尝试从`ChannelOutboundBuffer`缓冲区中获取`ByteBuffer`数组，默认最多获取1024个，最大字节数为Integer.MAX_VALUE，第二个属性可以通过`ChannelOption#SO_SNDBUF`进行设置。然后根据获取到的数组的长度，执行不同的写策略。

```java
protected void doWrite(ChannelOutboundBuffer in) throws Exception {
    SocketChannel ch = javaChannel();
    // 16
    int writeSpinCount = config().getWriteSpinCount();
    do {
        if (in.isEmpty()) {
            // All written so clear OP_WRITE
            clearOpWrite();
            // Directly return here so incompleteWrite(...) is not called.
            return;
        }

        // Ensure the pending writes are made of ByteBufs only.
        // 默认值为Integer.MAX_VALUE，可以通过ChannelOption#SO_SNDBUF指定
        int maxBytesPerGatheringWrite = ((NioSocketChannelConfig) config).getMaxBytesPerGatheringWrite();
        // 导出最多1024个ByteBuffer，最大总字节数不超过maxBytesPerGatheringWrite，以便使用gather写数据
        ByteBuffer[] nioBuffers = in.nioBuffers(1024, maxBytesPerGatheringWrite);
        int nioBufferCnt = in.nioBufferCount();

        // Always us nioBuffers() to workaround data-corruption.
        // See https://github.com/netty/netty/issues/2761
        switch (nioBufferCnt) {
            case 0:
                // We have something else beside ByteBuffers to write so fallback to normal writes.
                // 写入FileRegion类型的消息
                writeSpinCount -= doWrite0(in);
                break;
            case 1: {
                // Only one ByteBuf so use non-gathering write
                // Zero length buffers are not added to nioBuffers by ChannelOutboundBuffer, so there is no need
                // to check if the total size of all the buffers is non-zero.
                ByteBuffer buffer = nioBuffers[0];
                int attemptedBytes = buffer.remaining();
                final int localWrittenBytes = ch.write(buffer);
                // 如果Channel没有写入缓冲区的数据，那么设置interestOp为WRITE，之后继续尝试
                if (localWrittenBytes <= 0) {
                    incompleteWrite(true);
                    return;
                }
                // 调整maxBytesPerGatheringWrite
                adjustMaxBytesPerGatheringWrite(attemptedBytes, localWrittenBytes, maxBytesPerGatheringWrite);
                in.removeBytes(localWrittenBytes);
                --writeSpinCount;
                break;
            }
            default: {
                // Zero length buffers are not added to nioBuffers by ChannelOutboundBuffer, so there is no need
                // to check if the total size of all the buffers is non-zero.
                // We limit the max amount to int above so cast is safe
                long attemptedBytes = in.nioBufferSize();
                final long localWrittenBytes = ch.write(nioBuffers, 0, nioBufferCnt);
                if (localWrittenBytes <= 0) {
                    incompleteWrite(true);
                    return;
                }
                // Casting to int is safe because we limit the total amount of data in the nioBuffers to int above.
                adjustMaxBytesPerGatheringWrite((int) attemptedBytes, (int) localWrittenBytes,
                        maxBytesPerGatheringWrite);
                in.removeBytes(localWrittenBytes);
                --writeSpinCount;
                break;
            }
        }
    } while (writeSpinCount > 0);

    // writeSpinCount < 0 一般为case 0时，FileRegion的数据写入Channel失败，需要设置WRITE再次写入
    incompleteWrite(writeSpinCount < 0);
}

```

从`ChannelOutboundBuffer`获取`ByteBuffer[]`时要求对应的`Entry`必须是`ByteBuf`类型，并且要求是连续的。如果多个类型为`ByteBuf`的`Entry`之中有一个类型为`FileRegion`的`Entry`，那么此方法只会返回前半部分的`Entry`构造出的`ByteBuffer[]`。因此，缓冲列表并不会一次就全部写完，而需要多次写入，默认最大次数为16，可以通过`ChannelOption#WRITE_SPIN_COUNT`设置。

注意：对于`buf.nioBufferCount()`方法，常规的`ByteBuf`都只会返回1，而`CompositeByteBuf`则会根据其组合的`ByteBuf`返回对应的数量。

```java
public ByteBuffer[] nioBuffers(int maxCount, long maxBytes) {
    assert maxCount > 0;
    assert maxBytes > 0;
    long nioBufferSize = 0;
    int nioBufferCount = 0;
    final InternalThreadLocalMap threadLocalMap = InternalThreadLocalMap.get();
    ByteBuffer[] nioBuffers = NIO_BUFFERS.get(threadLocalMap);
    Entry entry = flushedEntry;
    while (isFlushedEntry(entry) && entry.msg instanceof ByteBuf) {
        if (!entry.cancelled) {
            ByteBuf buf = (ByteBuf) entry.msg;
            final int readerIndex = buf.readerIndex();
            final int readableBytes = buf.writerIndex() - readerIndex;

            if (readableBytes > 0) {
                if (maxBytes - readableBytes < nioBufferSize && nioBufferCount != 0) {
                    // If the nioBufferSize + readableBytes will overflow maxBytes, and there is at least one entry
                    // we stop populate the ByteBuffer array. This is done for 2 reasons:
                    // 1. bsd/osx don't allow to write more bytes then Integer.MAX_VALUE with one writev(...) call
                    // and so will return 'EINVAL', which will raise an IOException. On Linux it may work depending
                    // on the architecture and kernel but to be safe we also enforce the limit here.
                    // 2. There is no sense in putting more data in the array than is likely to be accepted by the
                    // OS.
                    //
                    // See also:
                    // - https://www.freebsd.org/cgi/man.cgi?query=write&sektion=2
                    // - http://linux.die.net/man/2/writev
                    break;
                }
                nioBufferSize += readableBytes;
                int count = entry.count;
                if (count == -1) {
                    //noinspection ConstantValueVariableUse
                    entry.count = count = buf.nioBufferCount();
                }
                int neededSpace = min(maxCount, nioBufferCount + count);
                if (neededSpace > nioBuffers.length) {
                    nioBuffers = expandNioBufferArray(nioBuffers, neededSpace, nioBufferCount);
                    NIO_BUFFERS.set(threadLocalMap, nioBuffers);
                }
                if (count == 1) {
                    ByteBuffer nioBuf = entry.buf;
                    if (nioBuf == null) {
                        // cache ByteBuffer as it may need to create a new ByteBuffer instance if its a
                        // derived buffer
                        entry.buf = nioBuf = buf.internalNioBuffer(readerIndex, readableBytes);
                    }
                    nioBuffers[nioBufferCount++] = nioBuf;
                } else {
                    // The code exists in an extra method to ensure the method is not too big to inline as this
                    // branch is not very likely to get hit very frequently.
                    nioBufferCount = nioBuffers(entry, buf, nioBuffers, nioBufferCount, maxCount);
                }
                if (nioBufferCount == maxCount) {
                    break;
                }
            }
        }
        entry = entry.next;
    }
    this.nioBufferCount = nioBufferCount;
    this.nioBufferSize = nioBufferSize;

    return nioBuffers;
}

```

调用完`nioBuffers(int maxCount, long maxBytes)`方法后，可以调用`nioBufferCount`方法获取数组的大小，调用`nioBufferSize`方法获取`ByteBuffer`数组的总字节大小。

当`nioBufferCount`方法返回0时，一般表示下一个待刷新的`Entry`为`FileRegion`类型或者当前没有待刷新的`Entry`或者由于`writeSpinCount`和`maxBytesPerGatheringWrite`的限制导致无法返回一个可用的`ByteBuffer[]`，所以需要针对其进行特殊处理。

```java
protected final int doWrite0(ChannelOutboundBuffer in) throws Exception {
    Object msg = in.current();
    if (msg == null) {
        // Directly return here so incompleteWrite(...) is not called.
        return 0;
    }
    return doWriteInternal(in, in.current());
}

private int doWriteInternal(ChannelOutboundBuffer in, Object msg) throws Exception {
    if (msg instanceof ByteBuf) {
        ByteBuf buf = (ByteBuf) msg;
        if (!buf.isReadable()) {
            in.remove();
            return 0;
        }

        final int localFlushedAmount = doWriteBytes(buf);
        if (localFlushedAmount > 0) {
            in.progress(localFlushedAmount);
            if (!buf.isReadable()) {
                in.remove();
            }
            return 1;
        }
    } else if (msg instanceof FileRegion) {
        FileRegion region = (FileRegion) msg;
        if (region.transferred() >= region.count()) {
            in.remove();
            return 0;
        }

        long localFlushedAmount = doWriteFileRegion(region);
        if (localFlushedAmount > 0) {
            in.progress(localFlushedAmount);
            if (region.transferred() >= region.count()) {
                in.remove();
            }
            return 1;
        }
    } else {
        // Should not reach here.
        throw new Error();
    }
    // Integer.MAX_VALUE
    return WRITE_STATUS_SNDBUF_FULL;
}

```

当`nioBufferCount`方法返回1时，直接获取数组第一个元素，并将其写入到`Channel`中。否则，就使用gather模式写入`ByteBuffer[]`。如果写入的字节数`<=` 0，那么需要设置interestOp为`WRITE`，以便之后完成此次写入。

```java
protected final void incompleteWrite(boolean setOpWrite) {
    // Did not write completely.
    if (setOpWrite) {
        setOpWrite();
    } else {
        // It is possible that we have set the write OP, woken up by NIO because the socket is writable, and then
        // use our write quantum. In this case we no longer want to set the write OP because the socket is still
        // writable (as far as we know). We will find out next time we attempt to write if the socket is writable
        // and set the write OP if necessary.
        clearOpWrite();

        // Schedule flush again later so other tasks can be picked up in the meantime
        eventLoop().execute(flushTask);
    }
}

protected final void setOpWrite() {
    final SelectionKey key = selectionKey();
    // Check first if the key is still valid as it may be canceled as part of the deregistration
    // from the EventLoop
    // See https://github.com/netty/netty/issues/2104
    if (!key.isValid()) {
        return;
    }
    final int interestOps = key.interestOps();
    if ((interestOps & SelectionKey.OP_WRITE) == 0) {
        key.interestOps(interestOps | SelectionKey.OP_WRITE);
    }
}

```

除此以外，还需要调整`maxBytesPerGatheringWrite`的值。起初是跟踪`SO_SNDBUF`属性以获取其值，但是某些操作系统可能会动态修改`SO_SNDBUF`，因此需要对`maxBytesPerGatheringWrite`进行适当的调整来适配操作系统的特性。

```java
private void adjustMaxBytesPerGatheringWrite(int attempted, int written, int oldMaxBytesPerGatheringWrite) {
    // By default we track the SO_SNDBUF when ever it is explicitly set. However some OSes may dynamically change
    // SO_SNDBUF (and other characteristics that determine how much data can be written at once) so we should try
    // make a best effort to adjust as OS behavior changes.
    if (attempted == written) {
        if (attempted << 1 > oldMaxBytesPerGatheringWrite) {
            ((NioSocketChannelConfig) config).setMaxBytesPerGatheringWrite(attempted << 1);
        }
    } else if (attempted > MAX_BYTES_PER_GATHERING_WRITE_ATTEMPTED_LOW_THRESHOLD && written < attempted >>> 1) {
        ((NioSocketChannelConfig) config).setMaxBytesPerGatheringWrite(attempted >>> 1);
    }
}

```

调整完`maxBytesPerGatheringWrite`的值后，需要将已写入到`Channel`的`Entry`移除。

```java
public void removeBytes(long writtenBytes) {
    for (;;) {
        // 获取flushedEntry中的第一个条目消息
        Object msg = current();
        if (!(msg instanceof ByteBuf)) {
            assert writtenBytes == 0;
            break;
        }

        final ByteBuf buf = (ByteBuf) msg;
        final int readerIndex = buf.readerIndex();
        final int readableBytes = buf.writerIndex() - readerIndex;

        if (readableBytes <= writtenBytes) {
            if (writtenBytes != 0) {
                progress(readableBytes);
                writtenBytes -= readableBytes;
            }
            // 将此Entry从链表中移除并回收
            remove();
        } else { // readableBytes > writtenBytes
            if (writtenBytes != 0) {
                buf.readerIndex(readerIndex + (int) writtenBytes);
                progress(writtenBytes);
            }
            break;
        }
    }
    // 清除上次nioBuffers(int maxCount, long maxBytes)调用保存的临时值
    clearNioBuffers();
}

// Clear all ByteBuffer from the array so these can be GC'ed.
// See https://github.com/netty/netty/issues/3837
private void clearNioBuffers() {
    int count = nioBufferCount;
    if (count > 0) {
        nioBufferCount = 0;
        Arrays.fill(NIO_BUFFERS.get(), 0, count, null);
    }
}

```

至此，刷新操作已经完成。现在让我们看下`NioEventLoop`对于`WRITE`的处理，以彻底完善`flush()`操作的逻辑。

```java
if ((readyOps & SelectionKey.OP_WRITE) != 0) {
    // Call forceFlush which will also take care of clear the OP_WRITE once there is nothing left to write
    ch.unsafe().forceFlush();
}

@Override
public final void forceFlush() {
    // directly call super.flush0() to force a flush now
    super.flush0();
}

protected void flush0() {
    if (inFlush0) {
        // Avoid re-entrance
        return;
    }

    final ChannelOutboundBuffer outboundBuffer = this.outboundBuffer;
    if (outboundBuffer == null || outboundBuffer.isEmpty()) {
        return;
    }

    // other operations
	......
}
```

此方法很简单，只是再次调用`flush0()`方法继续尝试上次未写入成功的`Entry`。


## conntect

最后，则是NIO四种事件之一的`CONNECT`。当`Bootstrap`开始连接服务器时，连接操作是异步操作，并不一定会立刻成功，因此如果没有立刻连接，需要注册`CONNECT`事件等待连接成功。当eventloop检测到此事件时，需要等待其连接成功，方可执行读写操作。

在进行读写操作前，需要保证连接已经建立，否则将会抛出`IOException`，因此此事件需要第一个检测，以保证连接建立成功。

```java
if ((readyOps & SelectionKey.OP_CONNECT) != 0) {
    // remove OP_CONNECT as otherwise Selector.select(..) will always return without blocking
    // See https://github.com/netty/netty/issues/924
    int ops = k.interestOps();
    ops &= ~SelectionKey.OP_CONNECT;
    k.interestOps(ops);

    // 等待SocketChannel连接完成
    unsafe.finishConnect();
}

public final void finishConnect() {
    // Note this method is invoked by the event loop only if the connection attempt was
    // neither cancelled nor timed out.

    assert eventLoop().inEventLoop();

    try {
        boolean wasActive = isActive();
        doFinishConnect();
        fulfillConnectPromise(connectPromise, wasActive);
    } catch (Throwable t) {
        fulfillConnectPromise(connectPromise, annotateConnectException(t, requestedRemoteAddress));
    } finally {
        // Check for null as the connectTimeoutFuture is only created if a connectTimeoutMillis > 0 is used
        // See https://github.com/netty/netty/issues/1770
        if (connectTimeoutFuture != null) {
            connectTimeoutFuture.cancel(false);
        }
        connectPromise = null;
    }
}

protected void doFinishConnect() throws Exception {
    if (!javaChannel().finishConnect()) {
        throw new Error();
    }
}

```