上一节`bootstrap`中分析了`Undertow`的启动过程，接下来让我们看一下它是如何处理`HTTP`连接以及请求的。

在`WrokerThread#run()`方法中，存在下面一段代码：

```java
for (int i = 0; i < keys.length; i++) {
    final SelectionKey key = keys[i];
    if (key == null) break; //end of list
    keys[i] = null;
    final int ops;
    try {
        ops = key.interestOps();
        if (ops != 0) {
            selectorLog.tracef("Selected key %s for %s", key, key.channel());
            final NioHandle handle = (NioHandle) key.attachment();
            if (handle == null) {
                cancelKey(key);
            } else {
                handle.handleReady(key.readyOps());
            }
        }
    } catch (CancelledKeyException ignored) {
        selectorLog.tracef("Skipping selection of cancelled key %s", key);
    } catch (Throwable t) {
        selectorLog.tracef(t, "Unexpected failure of selection of key %s", key);
    }
}
```

当获取到`select()`方法找到的`I/O`事件后，将会获取与`SelectionKey`绑定的`attachment()`，即`NioHandle`，然后调用`NioHanlde#handleReady(int)`方法进行处理。

在创建`QueuedNioTcpServer`时，会构建一个`QueuedNioTcpServerHandle`绑定到`ServerSocketChannel`对应的`SelectionKey`上。因此，客户端发起连接请求时，生成`ACCEPT`事件，并交由`QueuedNioTcpServerHandle`处理。

```java
final class QueuedNioTcpServerHandle extends NioHandle implements ChannelClosed {

    private final QueuedNioTcpServer server;

    QueuedNioTcpServerHandle(final QueuedNioTcpServer server, final WorkerThread workerThread, final SelectionKey key, final int highWater, final int lowWater) {
        super(workerThread, key);
        this.server = server;
    }

    void handleReady(final int ops) {
        server.handleReady();
    }

    // ......
}
```

它直接调用了`QueuedNioTcpServer#handleReady()`方法，因为此`NioHandle`只处理`ACCEPT`事件，所以忽略了`ops`参数。

```java
    void handleReady() {
        final SocketChannel accepted;
        try {
            // 建立连接
            accepted = channel.accept();
            // 如果活跃连接数太多，超过了预定的阈值，那么关闭此连接
            if(suspendedDueToWatermark) {
                IoUtils.safeClose(accepted);
                return;
            }

        } catch (IOException e) {
            tcpServerLog.logf(FQCN, Logger.Level.ERROR, e, "Exception accepting request, closing server channel %s", this);
            IoUtils.safeClose(channel);
            return;
        }
        try {
            boolean ok = false;
            if (accepted != null) try {
                // 获取本地socket地址
                final SocketAddress localAddress = accepted.getLocalAddress();
                int hash;
                // 计算hash值
                if (localAddress instanceof InetSocketAddress) {
                    final InetSocketAddress address = (InetSocketAddress) localAddress;
                    hash = address.getAddress().hashCode() * 23 + address.getPort();
                } else if (localAddress instanceof LocalSocketAddress) {
                    hash = ((LocalSocketAddress) localAddress).getName().hashCode();
                } else {
                    hash = localAddress.hashCode();
                }
                // 获取对等客户端的socket地址
                final SocketAddress remoteAddress = accepted.getRemoteAddress();
                if (remoteAddress instanceof InetSocketAddress) {
                    final InetSocketAddress address = (InetSocketAddress) remoteAddress;
                    hash = (address.getAddress().hashCode() * 23 + address.getPort()) * 23 + hash;
                } else if (remoteAddress instanceof LocalSocketAddress) {
                    hash = ((LocalSocketAddress) remoteAddress).getName().hashCode() * 23 + hash;
                } else {
                    hash = localAddress.hashCode() * 23 + hash;
                }
                // 配置为非阻塞
                accepted.configureBlocking(false);
                // 配置socket
                final Socket socket = accepted.socket();
                socket.setKeepAlive(keepAlive != 0);
                socket.setOOBInline(oobInline != 0);
                socket.setTcpNoDelay(tcpNoDelay != 0);
                final int sendBuffer = this.sendBuffer;
                if (sendBuffer > 0) socket.setSendBufferSize(sendBuffer);
                // 根据hash值选择IO线程使用
                final WorkerThread ioThread = worker.getIoThread(hash);
                ok = true;
                final int number = ioThread.getNumber();
                final BlockingQueue<SocketChannel> queue = acceptQueues.get(number);
                queue.add(accepted);
                // todo: only execute if necessary
                ioThread.execute(acceptTask);
                // 计数并判断是否达到阈值
                openConnections++;
                if(openConnections >= getHighWater(connectionStatus)) {
                    synchronized (QueuedNioTcpServer.this) {
                        suspendedDueToWatermark = true;
                    }
                }
            } finally {
                if (! ok) safeClose(accepted);
            }
        } catch (IOException ignored) {
        }
    }
```

`QueuedNioTcpServer#handleReady()`方法共做了如下几步处理：

1. 建立连接
2. 通过连接的本地地址和远程地址计算hash值
3. 通过hash值选择IO线程绑定
4. 处理`ACCEPT`任务

前三个步骤都比较简单，不过通过ip地址进行hash可能会导致IO线程负载不均衡，当大量客户端从同一个局域网NAT出口连接时，这一点会被特别放大。而`Netty`默认采用了`round-robin`策略，同时也向用户提供了自定义策略的灵活性。

当`SocketChannel`绑定到IO线程后，同时会向IO线程增加一个任务：

```java
    ioThread.execute(acceptTask);

    private final Runnable acceptTask = new Runnable() {
        public void run() {
            // 获取当前线程以及与其绑定的SocketChannel队列
            final WorkerThread current = WorkerThread.getCurrent();
            assert current != null;
            final BlockingQueue<SocketChannel> queue = acceptQueues.get(current.getNumber());
            // 使用acceptListener处理ACCEPT事件
            ChannelListeners.invokeChannelListener(QueuedNioTcpServer.this, getAcceptListener());
            // 如果处理完成后有新的连接到来，那么继续处理
            if (! queue.isEmpty() && !suspendedDueToWatermark) {
                current.execute(this);
            }
        }
    };

    public static <T extends Channel> boolean invokeChannelListener(T channel, ChannelListener<? super T> channelListener) {
        if (channelListener != null) try {
            listenerMsg.tracef("Invoking listener %s on channel %s", channelListener, channel);
            channelListener.handleEvent(channel);
        } catch (Throwable t) {
            listenerMsg.listenerException(t);
            return false;
        }
        return true;
    }
```

而`acceptListener`是在`Undertow`启动时设置的，如下：

```java
    // 构造监听器，处理到来的请求
    HttpOpenListener openListener = new HttpOpenListener(buffers, undertowOptions);
    HttpHandler handler = rootHandler;
                        if (http2) {
        // 如果启用了http2，那么需要处理http升级
        handler = new Http2UpgradeHandler(handler);
    }
                        openListener.setRootHandler(handler);
    final ChannelListener<StreamConnection> finalListener;
    // 处理代理
                        if (listener.useProxyProtocol) {
        finalListener = new ProxyProtocolOpenListener(openListener, null, buffers, OptionMap.EMPTY);
    } else {
        finalListener = openListener;
    }
    ChannelListener<AcceptingChannel<StreamConnection>> acceptListener = ChannelListeners.openListenerAdapter(finalListener);


    public static <C extends ConnectedChannel> ChannelListener<AcceptingChannel<C>> openListenerAdapter(final ChannelListener<? super C> openListener) {
        if (openListener == null) {
            throw msg.nullParameter("openListener");
        }
        return new ChannelListener<AcceptingChannel<C>>() {
            public void handleEvent(final AcceptingChannel<C> channel) {
                try {
                    final C accepted = channel.accept();
                    if (accepted != null) {
                        invokeChannelListener(accepted, openListener);
                    }
                } catch (IOException e) {
                    listenerMsg.acceptFailed(channel, e);
                }
            }

            public String toString() {
                return "Accepting listener for " + openListener;
            }
        };
    }
```

`acceptListener`会先调用`QueuedNioTcpServer#accept()`方法，获取到连接后再调用`HttpOpenListener`监听器。

```java
    public NioSocketStreamConnection accept() throws IOException {
        final WorkerThread current = WorkerThread.getCurrent();
        if (current == null) {
            return null;
        }
        final BlockingQueue<SocketChannel> socketChannels = acceptQueues.get(current.getNumber());
        final SocketChannel accepted;
        boolean ok = false;
        try {
            // 从SocketChannel队列中取出连接
            accepted = socketChannels.poll();
            if (accepted != null) try {
                // 将SocketChannel注册到自己的Selector上，之后由自己处理它的一切读写事件
                final SelectionKey selectionKey = current.registerChannel(accepted);
                // 封装为xnio内部的连接
                final NioSocketStreamConnection newConnection = new NioSocketStreamConnection(current, selectionKey, handle);
                // 设置socket配置
                newConnection.setOption(Options.READ_TIMEOUT, Integer.valueOf(readTimeout));
                newConnection.setOption(Options.WRITE_TIMEOUT, Integer.valueOf(writeTimeout));
                ok = true;
                return newConnection;
            } finally {
                if (! ok) safeClose(accepted);
            }
        } catch (IOException e) {
            return null;
        } finally {
            if (! ok) {
                handle.freeConnection();
            }
        }
        // by contract, only a resume will do
        return null;
    }
```

`accept()`方法主要是将`SocketChannel`注册到`WorkerThread`自己的`Selector`上，之后所有的读写事件都将由自己处理，这是`Reactor`模型的经典实现。然后将其封装为`xnio`框架的`NioSocketStreamConnection`，在框架内部进行读写的一些预处理，以屏蔽无需开发者重视的细节，并通过提供处理器的方式，使得开发者可以专注业务处理。

`NioSocketStreamConnection`的构造过程如下所示，它会构造一个`NioSocketConduit`并作为`SelectionKey#attachment()`，在`NioSocketConduit`内部会屏蔽一些通信细节处理，类似`Netty`中的`DefaultChannelPipeline#HeadContext`。

```java
    NioSocketStreamConnection(final WorkerThread workerThread, final SelectionKey key, final ChannelClosed closedHandle) {
        super(workerThread);
        conduit = new NioSocketConduit(workerThread, key, this);
        key.attach(conduit);
        this.closedHandle = closedHandle;
        setSinkConduit(conduit);
        setSourceConduit(conduit);
    }
```

`SocketChannel`封装完成后，将其交由`HttpOpenListener`处理，如下所示：

```java
    @Override
    public void handleEvent(StreamConnection channel) {
        handleEvent(channel, null);
    }

    @Override
    public void handleEvent(final StreamConnection channel, PooledByteBuffer buffer) {
        if (UndertowLogger.REQUEST_LOGGER.isTraceEnabled()) {
            UndertowLogger.REQUEST_LOGGER.tracef("Opened connection with %s", channel.getPeerAddress());
        }

        //set read and write timeouts
        try {
            Integer readTimeout = channel.getOption(Options.READ_TIMEOUT);
            Integer idle = undertowOptions.get(UndertowOptions.IDLE_TIMEOUT);
            if (idle != null) {
                IdleTimeoutConduit conduit = new IdleTimeoutConduit(channel);
                channel.getSourceChannel().setConduit(conduit);
                channel.getSinkChannel().setConduit(conduit);
            }
            if (readTimeout != null && readTimeout > 0) {
                channel.getSourceChannel().setConduit(new ReadTimeoutStreamSourceConduit(channel.getSourceChannel().getConduit(), channel, this));
            }
            Integer writeTimeout = channel.getOption(Options.WRITE_TIMEOUT);
            if (writeTimeout != null && writeTimeout > 0) {
                channel.getSinkChannel().setConduit(new WriteTimeoutStreamSinkConduit(channel.getSinkChannel().getConduit(), channel, this));
            }
        } catch (IOException e) {
            IoUtils.safeClose(channel);
            UndertowLogger.REQUEST_IO_LOGGER.ioException(e);
        } catch (Throwable t) {
            IoUtils.safeClose(channel);
            UndertowLogger.REQUEST_IO_LOGGER.handleUnexpectedFailure(t);
        }
        if (statisticsEnabled) {
            channel.getSinkChannel().setConduit(new BytesSentStreamSinkConduit(channel.getSinkChannel().getConduit(), connectorStatistics.sentAccumulator()));
            channel.getSourceChannel().setConduit(new BytesReceivedStreamSourceConduit(channel.getSourceChannel().getConduit(), connectorStatistics.receivedAccumulator()));
        }

        HttpServerConnection connection = new HttpServerConnection(channel, bufferPool, rootHandler, undertowOptions, bufferSize, statisticsEnabled ? connectorStatistics : null);
        HttpReadListener readListener = new HttpReadListener(connection, parser, statisticsEnabled ? connectorStatistics : null);


        if (buffer != null) {
            if (buffer.getBuffer().hasRemaining()) {
                connection.setExtraBytes(buffer);
            } else {
                buffer.close();
            }
        }
        if (connectorStatistics != null && statisticsEnabled) {
            connectorStatistics.incrementConnectionCount();
        }

        connections.add(connection);
        connection.addCloseListener(new ServerConnection.CloseListener() {
            @Override
            public void closed(ServerConnection c) {
                connections.remove(connection);
            }
        });
        connection.setReadListener(readListener);
        readListener.newRequest();
        channel.getSourceChannel().setReadListener(readListener);
        readListener.handleEvent(channel.getSourceChannel());
    }
```

上面的代码虽然较长，但是做的事却很简单。

1. 设置读写超时以及空闲处理
2. 启动数据统计
3. 构造`HttpServerConnection`以及读监听器`HttpReadListener`
4. 注册`HttpReadListener`


// HttpServerConnection 和 HttpReadListener的用处