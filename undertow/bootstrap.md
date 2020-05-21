本节分析Undertow的启动过程，由于Undertow使用了`jboss`开源的`xnio`框架作为底层通信库，因此我们首先需要对其有一定了解。

## 启动示例

在`examples`模块下，Undertow的作者编写了很多使用Undertow的示例，我们从最经典的`HelloWorld`示例开始，如下所示：

```java
public class HelloWorldServer {

    public static void main(final String[] args) {
        Undertow server = Undertow.builder()
                .addHttpListener(8080, "localhost")
                .setHandler(new HttpHandler() {
                    @Override
                    public void handleRequest(final HttpServerExchange exchange) throws Exception {
                        exchange.getResponseHeaders().put(Headers.CONTENT_TYPE, "text/plain");
                        exchange.getResponseSender().send("Hello World");
                    }
                }).build();
        server.start();
    }

}
```

使用Undertow最快捷的方式便是通过它的`Builder API`，通过这些API我们可以对`Undertow`的各个方面进行一定的配置。上面的例子中通过`addHttpListener`方法增加了一个监听`localhost:8080`地址的`HTTP`监听器，这个方法可以多次调用，即绑定多个ip地址。接下来调用`setHandler`方法，这个方法的作用是设置一个默认处理器，当请求到来时这个处理器就回对其进行处理。上面的例子中对于任何请求都发送一个`Hello World`响应。最后通过`build()`方法完成最终的构造。

`Builder API`只是对Undertow进行各个功能的配置，还需要调用`server.start()`真正启动服务器。此时，你可以通过命令`curl localhost:8080`向服务器发起一个请求，之后你会收到`Hello World`响应。


## Undertow启动

`Builder API`只是常规的构建器设计模式实现，真正的核心过程为`server.start()`。接下来，让我们一探究竟Undertow是如何启动的。

```java
    public synchronized void start() {
        UndertowLogger.ROOT_LOGGER.infof("starting server: %s", Version.getFullVersionString());
        // 获取Xnio实例
        xnio = Xnio.getInstance(Undertow.class.getClassLoader());
        channels = new ArrayList<>();
        try {
            // 通常为true
            if (internalWorker) {
                // 构造xnio worker
                worker = xnio.createWorker(OptionMap.builder()
                        .set(Options.WORKER_IO_THREADS, ioThreads)
                        .set(Options.CONNECTION_HIGH_WATER, 1000000)
                        .set(Options.CONNECTION_LOW_WATER, 1000000)
                        .set(Options.WORKER_TASK_CORE_THREADS, workerThreads)
                        .set(Options.WORKER_TASK_MAX_THREADS, workerThreads)
                        .set(Options.TCP_NODELAY, true)
                        .set(Options.CORK, true)
                        .addAll(workerOptions)
                        .getMap());
            }

            OptionMap socketOptions = OptionMap.builder()
                    .set(Options.WORKER_IO_THREADS, worker.getIoThreadCount())
                    .set(Options.TCP_NODELAY, true)
                    .set(Options.REUSE_ADDRESSES, true)
                    .set(Options.BALANCING_TOKENS, 1)
                    .set(Options.BALANCING_CONNECTIONS, 2)
                    .set(Options.BACKLOG, 1000)
                    .addAll(this.socketOptions)
                    .getMap();

            OptionMap serverOptions = OptionMap.builder()
                    .set(UndertowOptions.NO_REQUEST_TIMEOUT, 60 * 1000)
                    .addAll(this.serverOptions)
                    .getMap();


            // 初始化缓冲池
            ByteBufferPool buffers = this.byteBufferPool;
            if (buffers == null) {
                buffers = new DefaultByteBufferPool(directBuffers, bufferSize, -1, 4);
            }

            listenerInfo = new ArrayList<>();
            for (ListenerConfig listener : listeners) {
                UndertowLogger.ROOT_LOGGER.debugf("Configuring listener with protocol %s for interface %s and port %s", listener.type, listener.host, listener.port);
                final HttpHandler rootHandler = listener.rootHandler != null ? listener.rootHandler : this.rootHandler;
                // 构建socket选项表
                OptionMap socketOptionsWithOverrides = OptionMap.builder().addAll(socketOptions).addAll(listener.overrideSocketOptions).getMap();

                // AJP Listener
                if (listener.type == ListenerType.AJP) {
                    AjpOpenListener openListener = new AjpOpenListener(buffers, serverOptions);
                    openListener.setRootHandler(rootHandler);

                    final ChannelListener<StreamConnection> finalListener;
                    if (listener.useProxyProtocol) {
                        finalListener = new ProxyProtocolOpenListener(openListener, null, buffers, OptionMap.EMPTY);
                    } else {
                        finalListener = openListener;
                    }
                    ChannelListener<AcceptingChannel<StreamConnection>> acceptListener = ChannelListeners.openListenerAdapter(finalListener);
                    AcceptingChannel<? extends StreamConnection> server = worker.createStreamConnectionServer(new InetSocketAddress(Inet4Address.getByName(listener.host), listener.port), acceptListener, socketOptionsWithOverrides);
                    server.resumeAccepts();
                    channels.add(server);
                    listenerInfo.add(new ListenerInfo("ajp", server.getLocalAddress(), openListener, null, server));
                } else {
                    // HTTP Listener

                    OptionMap undertowOptions = OptionMap.builder().set(UndertowOptions.BUFFER_PIPELINED_DATA, true).addAll(serverOptions).getMap();
                    // 默认false，HTTP/2构建在HTTP或HTTPS之上
                    boolean http2 = serverOptions.get(UndertowOptions.ENABLE_HTTP2, false);
                    if (listener.type == ListenerType.HTTP) {
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
                        // 创建服务器
                        AcceptingChannel<? extends StreamConnection> server = worker.createStreamConnectionServer(
                                new InetSocketAddress(Inet4Address.getByName(listener.host), listener.port),
                                acceptListener, socketOptionsWithOverrides);
                        server.resumeAccepts();
                        channels.add(server);
                        listenerInfo.add(new ListenerInfo("http", server.getLocalAddress(), openListener, null, server));
                    } else if (listener.type == ListenerType.HTTPS) {
                        // HTTPS Listener

                        OpenListener openListener;

                        HttpOpenListener httpOpenListener = new HttpOpenListener(buffers, undertowOptions);
                        httpOpenListener.setRootHandler(rootHandler);

                        if (http2) {
                            AlpnOpenListener alpn = new AlpnOpenListener(buffers, undertowOptions, httpOpenListener);
                            Http2OpenListener http2Listener = new Http2OpenListener(buffers, undertowOptions);
                            http2Listener.setRootHandler(rootHandler);
                            alpn.addProtocol(Http2OpenListener.HTTP2, http2Listener, 10);
                            alpn.addProtocol(Http2OpenListener.HTTP2_14, http2Listener, 7);
                            openListener = alpn;
                        } else {
                            openListener = httpOpenListener;
                        }

                        UndertowXnioSsl xnioSsl;
                        if (listener.sslContext != null) {
                            xnioSsl = new UndertowXnioSsl(xnio, OptionMap.create(Options.USE_DIRECT_BUFFERS, true), listener.sslContext);
                        } else {
                            OptionMap.Builder builder = OptionMap.builder()
                                    .addAll(socketOptionsWithOverrides);
                            if (!socketOptionsWithOverrides.contains(Options.SSL_PROTOCOL)) {
                                builder.set(Options.SSL_PROTOCOL, "TLSv1.2");
                            }
                            xnioSsl = new UndertowXnioSsl(xnio, OptionMap.create(Options.USE_DIRECT_BUFFERS, true),
                                    JsseSslUtils.createSSLContext(listener.keyManagers, listener.trustManagers, new SecureRandom(), builder.getMap()));
                        }

                        AcceptingChannel<? extends StreamConnection> sslServer;
                        if (listener.useProxyProtocol) {
                            ChannelListener<AcceptingChannel<StreamConnection>> acceptListener = ChannelListeners.openListenerAdapter(
                                    new ProxyProtocolOpenListener(openListener, xnioSsl, buffers, socketOptionsWithOverrides));
                            sslServer = worker.createStreamConnectionServer(new InetSocketAddress(Inet4Address.getByName(listener.host), listener.port),
                                    (ChannelListener) acceptListener, socketOptionsWithOverrides);
                        } else {
                            ChannelListener<AcceptingChannel<StreamConnection>> acceptListener = ChannelListeners.openListenerAdapter(openListener);
                            sslServer = xnioSsl.createSslConnectionServer(worker, new InetSocketAddress(Inet4Address.getByName(listener.host), listener.port),
                                    (ChannelListener) acceptListener, socketOptionsWithOverrides);
                        }

                        sslServer.resumeAccepts();
                        channels.add(sslServer);
                        listenerInfo.add(new ListenerInfo("https", sslServer.getLocalAddress(), openListener, xnioSsl, sslServer));
                    }
                }

            }

        } catch (Exception e) {
            if(internalWorker && worker != null) {
                worker.shutdownNow();
            }
            throw new RuntimeException(e);
        }
    }
```

上面的启动过程相当冗长，因为它综合了默认的启动过程以及使用用户自定义的配置后启动过程。当然这两个过程几乎一样，因此此处只分析默认的启动过程。

启动过程共分为下面几步：

1. 创建`XnioWorker`。
2. 初始化缓冲池。
3. 构造服务器。

### 创建`XnioWorker`

由于Undertow的底层通信框架为`xnio`，因此需要使用它提供的API来进行服务器的构造。关于`xnio`的文档资料比较少，它没有`Netty`社区那么活跃，但是它相对`Netty`来说更加轻量级，同时Undertow本身也是`jboss`的产物，因此使用了自家的`xnio`以及`jboss logging`。

`xnio`的使用示例可以参考[此处](https://github.com/ecki/xnio-samples/blob/master/src/main/java/org/xnio/samples/SimpleEchoServer.java)，大体过程如下所示：

```java
public final class SimpleEchoServer {

    public static void main(String[] args) throws Exception {

        // First define the listener that actually is run on each connection.
        final ChannelListener<ConnectedStreamChannel> readListener = new ChannelListener<ConnectedStreamChannel>() {
            public void handleEvent(ConnectedStreamChannel channel) {
                // read and handle request
            }
        };

        // Create an accept listener.
        final ChannelListener<AcceptingChannel<ConnectedStreamChannel>> acceptListener = new ChannelListener<AcceptingChannel<ConnectedStreamChannel>>() {
            public void handleEvent(
                    final AcceptingChannel<ConnectedStreamChannel> channel) {
                // accept request
        };

        final XnioWorker worker = Xnio.getInstance().createWorker(
                OptionMap.EMPTY);
        // Create the server.
        AcceptingChannel<? extends ConnectedStreamChannel> server = worker
                .createStreamServer(new InetSocketAddress(12345),
                        acceptListener, OptionMap.EMPTY);
        // lets start accepting connections
        server.resumeAccepts();

        System.out.println("Listening on " + server.getLocalAddress());
    }
```

Undertow中创建`XnioWorker`的过程也和上面的过程一样。

```java
xnio = Xnio.getInstance(Undertow.class.getClassLoader());
        channels = new ArrayList<>();
        try {
            // 通常为true
            if (internalWorker) {
                // 构造xnio worker
                worker = xnio.createWorker(OptionMap.builder()
                        // 配置io线程数量，max{cpu cores, 2}
                        .set(Options.WORKER_IO_THREADS, ioThreads)
                        // 活跃连接数高水位
                        .set(Options.CONNECTION_HIGH_WATER, 1000000)
                        // 活跃连接数低水位
                        .set(Options.CONNECTION_LOW_WATER, 1000000)
                        // 核心工作线程数量，默认 ioThreads * 8
                        .set(Options.WORKER_TASK_CORE_THREADS, workerThreads)
                        // 最大工作线程数量
                        .set(Options.WORKER_TASK_MAX_THREADS, workerThreads)
                        .set(Options.TCP_NODELAY, true)
                        .set(Options.CORK, true)
                        .addAll(workerOptions)
                        .getMap());
            }
```

其中`internalWorker`通常情况下都为`true`，除非你使用`Builder`提供了一个自定义的`XnioWorker`。但是更多情况下，我们只需要对其进行一定的配置即可，因此你可以通过调用`Builder#setWorkerOption`方法来完成这个目的，而无需手动创建一个`XnioWorker`。你可以在`org.xnio.Options`类中查看具体可用的配置项。

### 初始化缓冲池

`xnio`并没有像`Netty`那样重新设计了一套缓冲区的API，而是依然使用jdk自带的nio缓冲区，因此Undertow也不能从中获取到一些编码的好处。由于jdk并没有提供缓冲池相关的工具类，在此处Undertow实现了一个非常简易的池化缓冲区，以便重复利用开辟出来的缓冲区。

除此以外，大多情况下直接缓冲区是最常用的，由于直接缓冲区并不由java堆管理，因此需要提供一个资源泄漏检测器，以防编码错误带来的内存泄漏问题。

另外，`xnio`内部开启了很多线程运行，因此提供一个`ThreadLocal`来存储一些缓冲区，可以让性能得到进一步提高。

```java
    // 初始化缓冲池
    ByteBufferPool buffers = this.byteBufferPool;
    if (buffers == null) {
        buffers = new DefaultByteBufferPool(directBuffers, bufferSize, -1, 4);
    }
```

与`XnioWorker`一样，你也可以自定义一个缓冲池并通过`Builder API`传入。缓冲区大小对应用程序性能有很大影响。对于服务器，理想大小通常为16k，因为这通常是可以通过`write()`操作写出的最大数据量（取决于操作系统的网络设置）。较小的系统可能希望使用较小的缓冲区来节省内存。

```java
        private Builder() {
            ioThreads = Math.max(Runtime.getRuntime().availableProcessors(), 2);
            workerThreads = ioThreads * 8;
            long maxMemory = Runtime.getRuntime().maxMemory();
            //smaller than 64mb of ram we use 512b buffers
            if (maxMemory < 64 * 1024 * 1024) {
                //use 512b buffers
                directBuffers = false;
                bufferSize = 512;
            } else if (maxMemory < 128 * 1024 * 1024) {
                //use 1k buffers
                directBuffers = true;
                bufferSize = 1024;
            } else {
                //use 16k buffers for best performance
                //as 16k is generally the max amount of data that can be sent in a single write() call
                directBuffers = true;
                bufferSize = 1024 * 16 - 20; //the 20 is to allow some space for protocol headers, see UNDERTOW-1209
            }
        }
```

在`Builder`的构造方法中，会根据机器的硬件条件选择合适的默认缓冲区大小。


### 构造服务器

```java
    UndertowLogger.ROOT_LOGGER.debugf("Configuring listener with protocol %s for interface %s and port %s", listener.type, listener.host, listener.port);
    final HttpHandler rootHandler = listener.rootHandler != null ? listener.rootHandler : this.rootHandler;
    // 构建socket选项表
    OptionMap socketOptionsWithOverrides = OptionMap.builder().addAll(socketOptions).addAll(listener.overrideSocketOptions).getMap();

    // AJP Listener
    if (listener.type == ListenerType.AJP) {
        AjpOpenListener openListener = new AjpOpenListener(buffers, serverOptions);
        openListener.setRootHandler(rootHandler);

        final ChannelListener<StreamConnection> finalListener;
        if (listener.useProxyProtocol) {
            finalListener = new ProxyProtocolOpenListener(openListener, null, buffers, OptionMap.EMPTY);
        } else {
            finalListener = openListener;
        }
        ChannelListener<AcceptingChannel<StreamConnection>> acceptListener = ChannelListeners.openListenerAdapter(finalListener);
        AcceptingChannel<? extends StreamConnection> server = worker.createStreamConnectionServer(new InetSocketAddress(Inet4Address.getByName(listener.host), listener.port), acceptListener, socketOptionsWithOverrides);
        server.resumeAccepts();
        channels.add(server);
        listenerInfo.add(new ListenerInfo("ajp", server.getLocalAddress(), openListener, null, server));
    } else {
        // HTTP Listener

        OptionMap undertowOptions = OptionMap.builder().set(UndertowOptions.BUFFER_PIPELINED_DATA, true).addAll(serverOptions).getMap();
        // 默认false，HTTP/2构建在HTTP或HTTPS之上
        boolean http2 = serverOptions.get(UndertowOptions.ENABLE_HTTP2, false);
        if (listener.type == ListenerType.HTTP) {
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
            // 创建服务器
            AcceptingChannel<? extends StreamConnection> server = worker.createStreamConnectionServer(
                new InetSocketAddress(Inet4Address.getByName(listener.host), listener.port),
                acceptListener, socketOptionsWithOverrides);
            server.resumeAccepts();
            channels.add(server);
            listenerInfo.add(new ListenerInfo("http", server.getLocalAddress(), openListener, null, server));
        } else if (listener.type == ListenerType.HTTPS) {
            // HTTPS Listener

            OpenListener openListener;

            HttpOpenListener httpOpenListener = new HttpOpenListener(buffers, undertowOptions);
            httpOpenListener.setRootHandler(rootHandler);

            if (http2) {
                AlpnOpenListener alpn = new AlpnOpenListener(buffers, undertowOptions, httpOpenListener);
                Http2OpenListener http2Listener = new Http2OpenListener(buffers, undertowOptions);
                http2Listener.setRootHandler(rootHandler);
                alpn.addProtocol(Http2OpenListener.HTTP2, http2Listener, 10);
                alpn.addProtocol(Http2OpenListener.HTTP2_14, http2Listener, 7);
                openListener = alpn;
            } else {
                openListener = httpOpenListener;
            }

            UndertowXnioSsl xnioSsl;
            if (listener.sslContext != null) {
                xnioSsl = new UndertowXnioSsl(xnio, OptionMap.create(Options.USE_DIRECT_BUFFERS, true), listener.sslContext);
            } else {
                OptionMap.Builder builder = OptionMap.builder()
                    .addAll(socketOptionsWithOverrides);
                if (!socketOptionsWithOverrides.contains(Options.SSL_PROTOCOL)) {
                builder.set(Options.SSL_PROTOCOL, "TLSv1.2");
                }
                xnioSsl = new UndertowXnioSsl(xnio, OptionMap.create(Options.USE_DIRECT_BUFFERS, true),
                    JsseSslUtils.createSSLContext(listener.keyManagers, listener.trustManagers, new SecureRandom(), builder.getMap()));
            }

            AcceptingChannel<? extends StreamConnection> sslServer;
            if (listener.useProxyProtocol) {
                ChannelListener<AcceptingChannel<StreamConnection>> acceptListener = ChannelListeners.openListenerAdapter(
                    new ProxyProtocolOpenListener(openListener, xnioSsl, buffers, socketOptionsWithOverrides));
                sslServer = worker.createStreamConnectionServer(new InetSocketAddress(Inet4Address.getByName(listener.host), listener.port),
                    (ChannelListener) acceptListener, socketOptionsWithOverrides);
            } else {
                ChannelListener<AcceptingChannel<StreamConnection>> acceptListener = ChannelListeners.openListenerAdapter(openListener);
                sslServer = xnioSsl.createSslConnectionServer(worker, new InetSocketAddress(Inet4Address.getByName(listener.host), listener.port),
                    (ChannelListener) acceptListener, socketOptionsWithOverrides);
            }

            sslServer.resumeAccepts();
            channels.add(sslServer);
            listenerInfo.add(new ListenerInfo("https", sslServer.getLocalAddress(), openListener, xnioSsl, sslServer));
        }
    }
```

Undertow支持`AJP`， `HTTP`， `HTTPS`以及`HTTP2`四种协议。