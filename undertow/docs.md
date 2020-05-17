目录

* [1. 简介](#简介)
    * [1.1 介绍Undertow](#介绍Undertow)
    * [1.2 获取Undertow](#获取Undertow)
Undertow Core
Bootstrapping Undertow
Architecture Overview
Listeners
Built in Handlers
Undertow Handler Authors Guide
Undertow Request Lifecycle
Error Handling
Security
Predicates Attributes and Handlers
Built in Handlers
Access Log Handler
Access Control Handler
Allowed Methods
Blocking Handler
Buffer Request Handler
Byte Range Handler
Canonical Path Handler
Clear Handler
Compress Handler
Disable Cache Handler
Disallowed Methods Handler
Done Handler
Request Dumping Handler
Eager Form Parsing Handler
Error File Handler
Forwarded Handler
Header Handler
Http Continue Accepting Handler
IP Access Control Handler
JVM Route Handler
Learning Push Handler
Mark Secure Handler
Path Separator Handler
Proxy Peer Address Handler
Redirect Handler
Request Limiting Handler
Resolve Local Name Handler
Resolve Peer Name Handler
Resource Handler
Response Code Handler
Response Rate Limiting Handler
Restart Handler
Reverse Proxy Handler
Rewrite Handler
Set Attribute Handler
Secure Cookie Handler
SameSite Cookie Handler
SSL Headers Handler
Store Response Header
Stuck Thread Detection Handler
Trace Handler
Uncompress Handler
URL Decoding Handler
Reverse Proxy
Websockets
Undertow Servlet
Creating a Servlet Deployment
Servlet Extensions
Using non-blocking handlers with servlet
Servlet Security
Advanced Servlet Use Cases
JSP
Undertow.js
Undertow.js
FAQ
Undertow FAQ

[TOC]


# 简介

## 介绍Undertow

Undertow是一个Web服务器，被设计同时用于阻塞和非阻塞任务。它的一些主要功能如下：

- 高性能
- 可嵌入
- Servlet 4.0
- Web Sockets
- 反向代理

你可以通过两种主要的方法使用Undertow，第一种是直接将其嵌入你的代码中，第二种是将其作为 [Wildfly Application Server](http://wildfly.org/)的一部分。该指南主要侧重于嵌入式API，如果你使用Wildfly，仍然会有许多相关内容，只是相关功能通常是通过XML配置而不是编程配置暴露。

该文档分为两部分，第一部分关注`Undertow`的代码，第二部分关注`Servlet`。

## 获取Undertow

有几种获取Undertow的方法。

### Wildfly

从8.0版本开始，`Undertow`已经成为了`Wildfly`的Web服务器组件。如果你使用的是Wildfly，那么你已经有了Undertow。

### `Maven`

Undertow是使用``Maven``构建的，并已同步到``Maven` Central`。Undertow提供了三个独立的artifacts：

- **Core**
Undertow核心代码，为非阻塞处理器和Web socket提供支持

- **Servlet**
支持Servlet 4.0

- **Websockets JSR**
支持`Websockets(JSR-356)`的Java API标准

In order to use Undertow in your maven projects just include the following section in your pom.xml, and set the undertow.version property to whatever version of Undertow you wish to use. Only the core artifact is required, if you are not using Servlet or JSR-356 then those artifacts are not required.

为了能在你的`Maven`项目中使用Undertow，需要在`pom.xml`中加入以下部分，并将`undertow.version`属性设置为你要使用的Undertow版本。其中`undertow-core`是必需的artifact，如果你不使用`Servlet`或`JSR-356`，则不需要另外两个artifact。

```xml
<dependency>
        <groupId>io.undertow</groupId>
        <artifactId>undertow-core</artifactId>
        <version>${undertow.version}</version>
</dependency>
<dependency>
        <groupId>io.undertow</groupId>
        <artifactId>undertow-servlet</artifactId>
        <version>${undertow.version}</version>
</dependency>
<dependency>
        <groupId>io.undertow</groupId>
        <artifactId>undertow-websockets-jsr</artifactId>
        <version>${undertow.version}</version>
</dependency>
```

### Direct Download
你也可以直接从`Maven`仓库下载Undertow。

Undertow依赖`XNIO`和`JBoss Logging`，它们也需要一起下载。

### Build it yourself

为了获得最新的代码，你可以自己构建Undertow。

#### 先决条件

- JDK8或更高版本
- Maven 3.1
- git

构建Undertow很轻松，只需执行以下步骤：

#### 配置Maven

请按照[此处](https://developer.jboss.org/wiki/MavenGettingStarted-Users)的说明将`Maven`配置为使用`JBoss Maven`仓库。

#### 克隆git仓库

```
git clone https://github.com/undertow-io/undertow.git
```

#### 构建Undertow

```
cd undertow && mvn install
```

构建过程应当运行所有测试并全部通过。

> 警告：如果你尝试使用`-Dmaven.test.skip=true`进行初始构建，那么构建过程会失败，因为核心的测试jar包将不会被构建，但是`Servlet`模块对此jar包具有测试范围的依赖关系。因此要么使用`-DskipTests`，要么第一次构建时便运行测试。

# Undertow核心

## 启动Undertow

有两种方法可以启动Undertow。首先也是最简单的方法是使用`io.undertow.Undertow`构建器API；第二个方法是直接使用`XNIO`和`Undertow`监听器类组装服务器。第二种方法需要更多代码，但具有更大的灵活性。可以预料的是，对于大多数用例而言，构建器API已经足够使用。

有一件事对于理解Undertow很重要，那就是实际上并没有Undertow容器这个概念。Undertow应用程序是由多个处理器类组装而成的，并且由嵌入式应用程序来管理所有这些处理器的生命周期。这是一个故意的设计决策，目的是让嵌入式应用程序获得尽可能多的控制权。通常，只有当你的处理器拥有需要在服务器停止时清理的资源时，这才是一个问题。

### 构建器API

构建器API可以通过`io.undertow.Undertow`类来访问。我们将从一个简单的例子开始：

```java
import io.undertow.Undertow;
import io.undertow.server.HttpHandler;
import io.undertow.server.HttpServerExchange;
import io.undertow.util.Headers;

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

上面的示例启动了一个简单的服务器，对于所有的请求它都返回`"Hello World"`。服务器将监听`localhost`上的`8080`端口，直到`server.stop()`方法被调用为止。当请求到达时，它们将由处理器链中的第一个（也是唯一一个）处理器处理，在此处，这个处理器仅设置一个标头并写入一些内容（查看[处理器指南](https://undertow.io/undertow-docs/undertow-docs-2.1.0/undertow-handler-guide.html)以获取更多信息）。

构建器将尝试为所有与性能相关的参数（例如线程数和缓冲区大小）选择合理的默认值，但是你也可以通过构建器的API来覆盖所有的默认值。这些参数及其用处在[监听器指南](https://undertow.io/undertow-docs/undertow-docs-2.1.0/listeners.html)中有详细介绍，此处不再赘述。

### 手动组装服务器

如果你不想使用构建器API，那么需要遵循一些步骤来创建服务器：

1. 创建一个`XNIO Worker`。它管理服务器的IO和工作线程。

2. 创建一个`XNIO SSL`实例（可选，仅在使用`HTTPS`时才需要）

3. 创建一个Undertow监听器类的实例

4. 使用`XNIO`打开服务器套接字并设置其accept监听器

HTTP，HTTPS和AJP监听器的代码如下所示：

```java
Xnio xnio = Xnio.getInstance();

XnioWorker worker = xnio.createWorker(OptionMap.builder()
        .set(Options.WORKER_IO_THREADS, ioThreads)
        .set(Options.WORKER_TASK_CORE_THREADS, workerThreads)
        .set(Options.WORKER_TASK_MAX_THREADS, workerThreads)
        .set(Options.TCP_NODELAY, true)
        .getMap());

OptionMap socketOptions = OptionMap.builder()
        .set(Options.WORKER_IO_THREADS, ioThreads)
        .set(Options.TCP_NODELAY, true)
        .set(Options.REUSE_ADDRESSES, true)
        .getMap();

Pool<ByteBuffer> buffers = new ByteBufferSlicePool(BufferAllocator.DIRECT_BYTE_BUFFER_ALLOCATOR,bufferSize, bufferSize * buffersPerRegion);


if (listener.type == ListenerType.AJP) {
    AjpOpenListener openListener = new AjpOpenListener(buffers, serverOptions, bufferSize);
    openListener.setRootHandler(rootHandler);
    ChannelListener<AcceptingChannel<StreamConnection>> acceptListener = ChannelListeners.openListenerAdapter(openListener);
    AcceptingChannel<? extends StreamConnection> server = worker.createStreamConnectionServer(new InetSocketAddress(Inet4Address.getByName(listener.host), listener.port), acceptListener, socketOptions);
    server.resumeAccepts();
} else if (listener.type == ListenerType.HTTP) {
    HttpOpenListener openListener = new HttpOpenListener(buffers, OptionMap.builder().set(UndertowOptions.BUFFER_PIPELINED_DATA, true).addAll(serverOptions).getMap(), bufferSize);
    openListener.setRootHandler(rootHandler);
    ChannelListener<AcceptingChannel<StreamConnection>> acceptListener = ChannelListeners.openListenerAdapter(openListener);
    AcceptingChannel<? extends StreamConnection> server = worker.createStreamConnectionServer(new InetSocketAddress(Inet4Address.getByName(listener.host), listener.port), acceptListener, socketOptions);
    server.resumeAccepts();
} else if (listener.type == ListenerType.HTTPS){
    HttpOpenListener openListener = new HttpOpenListener(buffers, OptionMap.builder().set(UndertowOptions.BUFFER_PIPELINED_DATA, true).addAll(serverOptions).getMap(), bufferSize);
    openListener.setRootHandler(rootHandler);
    ChannelListener<AcceptingChannel<StreamConnection>> acceptListener = ChannelListeners.openListenerAdapter(openListener);
    XnioSsl xnioSsl;
    if(listener.sslContext != null) {
        xnioSsl = new JsseXnioSsl(xnio, OptionMap.create(Options.USE_DIRECT_BUFFERS, true), listener.sslContext);
    } else {
        xnioSsl = xnio.getSslProvider(listener.keyManagers, listener.trustManagers, OptionMap.create(Options.USE_DIRECT_BUFFERS, true));
    }
    AcceptingChannel <SslConnection> sslServer = xnioSsl.createSslConnectionServer(worker, new InetSocketAddress(Inet4Address.getByName(listener.host), listener.port), (ChannelListener) acceptListener, socketOptions);
    sslServer.resumeAccepts();
}
```

如你所见，它比使用构建器要多写很多代码，但是它确实提供了构建器不具备的一些灵活性：

- 完全控制所有参数

- 能够为每个监听器使用不同的缓冲池和工作器

- `XnioWorker`实例可以在不同的服务器实例之间共享

- 缓冲池可以在不同的服务器实例之间共享

- 可以给监听器不同的根处理器

在大多数情况下，这种级别的控制不是必需的，因此你只需要简单使用构建器API即可。

## 架构概览

Undertow独特之处在于它没有全局容器的概念，而是由嵌入式应用程序组装Undertow服务器。这使得Undertow变得非常灵活，同时嵌入式应用程序可以只选择需要的组件，并且以任何有意义的方式组装它们。

Undertow服务器通常由三部分组成：一个（或多个）`XNIO worker`实例，一个或多个连接器（ `connector` ）以及用于处理传入请求的处理器链。

### XNIO

Undertow基于`XNIO`。`XNIO`项目在`Java NIO`之上提供了一个薄的（ `thin` ）抽象层。特别是它提供了以下内容：

### Management of IO and Worker threads

`XNIO worker`既管理了IO线程，也管理了一个用于阻塞任务的线程池。通常，非阻塞处理器将在IO线程内运行，而诸如`Servlet`调用之类的阻塞任务将分派到工作线程池中。

IO线程循环运行。这个循环执行三件事：

- 运行已安排要由IO线程执行的所有任务

- 运行所有可运行的定时任务

- 调用`Selector.select()`，然后为`selected keys`调用回调

### Channel API

`XNIO`提供了一个`Channel`抽象，它基于基础传输抽象而出。`Channel`的事件将由`ChannelListener`API处理，而不必直接与`NIO interestOps`打交道。在创建时，`Channel`会被分配一个IO线程。这个线程用于执行通道相关的所有`ChannelListener`。

### Listeners

Undertow中的监听器概念是Undertow的一部分，它处理传入的连接以及底层的wire协议。默认情况下，Undertow附带5个不同的监听器：

- HTTP/1.1

- HTTPS

- AJP

- HTTP/2

这些监听器通常会使用异步IO在IO线程中完成所有IO。当一个请求被完整解析后，他们将创建一个填充了请求数据的`HttpServerExchange`对象，然后将其交给处理器链。

连接器（`Connector`）则被绑定到一个`XNIO worker`上。如果设置了多个连接器来调用同一处理器链，那么它们可能共享一个`XNIO worker`，它们也可能具有单独的`XNIO worker`，这取决于它们的配置方式。

通常对于你的应用程序而言，所使用的连接器类型无关紧要，但并非每个连接器都支持所有功能。例如，`AJP`不支持`HTTP`升级。

有关监听器的更多信息，请参阅[监听器指南](https://undertow.io/undertow-docs/undertow-docs-2.1.0/listeners.html)。

### Handlers

Undertow主要的功能都是由`io.undertow.server.HttpHandler`实例提供的，这些处理器可以链接在一起以形成一个完整的服务器。

`HttpHandler`接口非常简单：

```java
public interface HttpHandler {

    void handleRequest(HttpServerExchange exchange) throws Exception;
}
```

处理器们一般通过在构造时显式指定下一个处理器的方式链接在一起，其中并没有流水线的概念，这意味着处理器可以根据当前请求选择下一个处理器调用。一个典型的处理程序可能看起来像这样：

```java
public class SetHeaderHandler implements HttpHandler {

    private final HttpString header;
    private final String value;
    private final HttpHandler next;

    public SetHeaderHandler(final HttpHandler next, final String header, final String value) {
        this.next = next;
        this.value = value;
        this.header = new HttpString(header);
    }

    @Override
    public void handleRequest(final HttpServerExchange exchange) throws Exception {
        exchange.getResponseHeaders().put(header, value);
        next.handleRequest(exchange);
    }
}
```

> 注：其中并没有流水线的概念的意思是并不是每个处理器都必须要处理请求，如上面的例子，它可以直接调用它的下一个或者下下个处理器（注意NPE）来处理请求。如果你使用过Netty，相信对这个概念也比较熟悉。

## Listeners

Listeners represent the entry point of an Undertow application. All incoming requests will come through a listener, and a listener is responsible for translating a request into an instance of the HttpServerExchange object, and then turning the result into a response that can be sent back to the client.

Undertow provides 3 built in listener types, HTTP/1.1, AJP and HTTP/2. HTTPS is provided by using the HTTP listener with an SSL enabled connection.

Undertow also supports version 1 of the proxy protocol, which can be combined with any of the above listener types by setting useProxyProtocol to true on the listener builder.

Options
Undertow listeners can be configured through the use of the org.xnio.Option class. In general options for XNIO that control connection and worker level behaviour are listed in org.xnio.Options. Undertow specific options that control connector level behaviour are listed in io.undertow.UndertowOptions.

XNIO workers
All listeners are tied to an XNIO Worker instance. Usually there will only be a single worker instance that is shared between listeners, however it is possible to create a new worker for each listener.

The worker instance manages the listeners IO threads, and also the default blocking task thread pool. There are several main XNIO worker options that affect listener behaviour. These option can either be specified on the Undertow builder as worker options, or at worker creating time if you are bootstrapping a server manually. These options all reside on the org.xnio.Options class.

WORKER_IO_THREADS
The number of IO threads to create. IO threads perform non blocking tasks, and should never perform blocking operations because they are responsible for multiple connections, so while the operation is blocking other connections will essentially hang. Two IO threads per CPU core is a reasonable default.

WORKER_TASK_CORE_THREADS
The number of threads in the workers blocking task thread pool. When performing blocking operations such as Servlet requests threads from this pool will be used. In general it is hard to give a reasonable default for this, as it depends on the server workload. Generally this should be reasonably high, around 10 per CPU core.

Buffer Pool
All listeners have a buffer pool, which is used to allocate pooled NIO ByteBuffer instances. These buffers are used for IO operations, and the buffer size has a big impact on application performance. For servers the ideal size is generally 16k, as this is usually the maximum amount of data that can be written out via a write() operation (depending on the network setting of the operating system). Smaller systems may want to use smaller buffers to save memory.

In some situations with blocking IO the buffer size will determine if a response is sent using chunked encoding or has a fixed content length. If a response fits completely in the buffer and flush() is not called then a content length can be set automatically.

Common Listener Options
In addition to the worker options the listeners take some other options that control server behaviour. These are all part of the io.undertow.UndertowOptions class. Some of of these only make sense for specific protocols. You can set options with the Undertow.Builder.setServerOption:

MAX_HEADER_SIZE
The maximum size of a HTTP header block, in bytes. If a client sends more data that this as part of the request header then the connection will be closed. Defaults to 50k.

MAX_ENTITY_SIZE
The default maximum size of a request entity. If entity body is larger than this limit then a java.io.IOException will be thrown at some point when reading the request (on the first read for fixed length requests, when too much data has been read for chunked requests). This value is only the default size, it is possible for a handler to override this for an individual request by calling io.undertow.server.HttpServerExchange.setMaxEntitySize(long size). Defaults to unlimited.

MULTIPART_MAX_ENTITY_SIZE
The default max entity size when using the Multipart parser. This will generally be larger than MAX_ENTITY_SIZE. Having a separate setting for this allows for large files to be uploaded, while limiting the size of other requests.

MAX_PARAMETERS
The maximum number of query parameters that are permitted in a request. If a client sends more than this number the connection will be closed. This limit is necessary to protect against hash based denial of service attacks. Defaults to 1000.

MAX_HEADERS
The maximum number of headers that are permitted in a request. If a client sends more than this number the connection will be closed. This limit is necessary to protect against hash based denial of service attacks. Defaults to 200.

MAX_COOKIES
The maximum number of cookies that are permitted in a request. If a client sends more than this number the connection will be closed. This limit is necessary to protect against hash based denial of service attacks. Defaults to 200.

URL_CHARSET
The charset to use to decode the URL and query parameters. Defaults to UTF-8.

DECODE_URL
Determines if the listener will decode the URL and query parameters, or simply pass it through to the handler chain as is. If this is set url encoded characters will be decoded to the charset specified in URL_CHARSET. Defaults to true.

ALLOW_ENCODED_SLASH
If a request comes in with encoded / characters (i.e. %2F), will these be decoded. This can cause security problems (link:http://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2007-0450) if a front end proxy does not perform the same decoding, and as a result this is disabled by default.

ALLOW_EQUALS_IN_COOKIE_VALUE
If this is true then Undertow will allow non-escaped equals characters in unquoted cookie values. Unquoted cookie values may not contain equals characters. If present the value ends before the equals sign. The remainder of the cookie value will be dropped. Defaults to false.

ALWAYS_SET_DATE
If the server should add a HTTP Date header to all response entities which do not already have one. The server sets the header right before writing the response, if none was set by a handler before. Unlike the DateHandler it will not overwrite the header. The current date string is cached, and is updated every second. Defaults to true.

ALWAYS_SET_KEEP_ALIVE
If a HTTP Connection: keep-alive header should always be set, even for HTTP/1.1 requests that are persistent by default. Even though the spec does not require this header to always be sent it seems safer to always send it. If you are writing some kind of super high performance application and are worried about the extra data being sent over the wire this option allows you to turn it off. Defaults to true.

MAX_BUFFERED_REQUEST_SIZE
The maximum size of a request that can be saved in bytes. Requests are buffered in a few situations, the main ones being SSL renegotiation and saving post data when using FORM based auth. Defaults to 16,384 bytes.

RECORD_REQUEST_START_TIME
If the server should record the start time of a HTTP request. This is necessary if you wish to log or otherwise use the total request time, however has a slight performance impact, as it means that System.nanoTime() must be called for each request. Defaults to false.

IDLE_TIMEOUT
The amount of time a connection can be idle for before it is timed out. An idle connection is a connection that has had no data transfer in the idle timeout period. Note that this is a fairly coarse grained approach, and small values will cause problems for requests with a long processing time.

REQUEST_PARSE_TIMEOUT
How long a request can spend in the parsing phase before it is timed out. This timer is started when the first bytes of a request are read, and finishes once all the headers have been parsed.

NO_REQUEST_TIMEOUT
The amount of time a connection can sit idle without processing a request, before it is closed by the server.

ENABLE_CONNECTOR_STATISTICS
If this is true then the connector will record statistics such as requests processed and bytes sent/received. This has a performance impact, although it should not be noticeable in most cases.

ALPN
io.undertow.server.protocol.http.AlpnOpenListener

The HTTP/2 connector requires the use of ALPN when running over SSL.

As of Java 9 the JDK supports ALPN natively, however on previous JDKs different approaches need to be used.

If you are using OpenJDK/Oracle JDK then Undertow contains a workaround that should allow ALPN to work out of the box.

Alternatively you can use the Wildfly OpenSSL project to provide ALPN, which should also perform better than the JDK SSL implementation.

Another option is to use Jetty ALPN, however it is not recommended as it is no longer tested as part of the Undertow test suite. For more information see the Jetty ALPN documentation.

HTTP Listener
io.undertow.server.protocol.http.HttpOpenListener

The HTTP listener is the most commonly used listener type, and deals with HTTP/1.0 and HTTP/1.1. It only takes one additional option.

ENABLE_HTTP2
If this is true then the connection can be processed as a HTTP/2 prior knowledge connection. If a HTTP/2 client connects directly to the listener with a HTTP/2 connection preface then the HTTP/2 protocol will be used instead of HTTP/1.1.

AJP Listener
io.undertow.server.protocol.ajp.AjpOpenListener

The AJP listener allows the use of the AJP protocol, as used by the Apache modules mod_jk and mod_proxy_ajp. It is a binary protocol that is slightly more efficient protocol than HTTP, as some common strings are replaced by integers. If the front end load balancer supports it then it is recommended to use HTTP2 instead, as it is both a standard protocol and more efficient.

This listener has one specific option:

MAX_AJP_PACKET_SIZE
Controls the maximum size of an AJP packet. This setting must match on both the load balancer and backend server.

HTTP2 Listener
HTTP/2 support is implemented on top of HTTP/1.1 (it is not possible to have a HTTP/2 server that does not also support HTTP/1). There are three different ways a HTTP/2 connection can be established:

ALPN
This is the most common way (and the only way many browsers currently support). It requires HTTPS, and uses the application layer protocol negotiation SSL extension to negotiate that connection will use HTTP/2.

Prior Knowledge
This involves the client simply sending a HTTP/2 connection preface and assuming the server will support it. This is not generally used on the open internet, but it’s useful for things like load balancers when you know the backend server will support HTTP/2.

HTTP Upgrade
This involves the client sending an Upgrade: h2c header in the initial request. If this upgrade is accepted then the server will initiate a HTTP/2 connection, and send back the response to the initial request using HTTP/2.

Depending on the way HTTP/2 is being used the setup for the listeners is slightly different.

If you are using the Undertow builder all that is required is to call setServerOption(ENABLE_HTTP2, true), and HTTP/2 support will be automatically added for all HTTP and HTTPS listeners.

If JDK8 is in use then Undertow will use a reflection based implementation of ALPN that should work with OpenJDK/Oracle JDK. If JDK9+ is in use then Undertow will use the ALPN implementation provided by the JDK.

The following options are supported:

HTTP2_SETTINGS_HEADER_TABLE_SIZE
The size of the header table that is used for compression. Increasing this will use more memory per connection, but potentially decrease the amount of data that is sent over the wire. Defaults to 4096.

HTTP2_SETTINGS_ENABLE_PUSH
If server push is enabled for this connection.

HTTP2_SETTINGS_MAX_CONCURRENT_STREAMS
The maximum number of streams a client is allowed to have open at any one time.

HTTP2_SETTINGS_INITIAL_WINDOW_SIZE
The initial flow control window size.

HTTP2_SETTINGS_MAX_FRAME_SIZE
The maximum frame size.

HTTP2_SETTINGS_MAX_HEADER_LIST_SIZE
The maximum size of the headers that this server is prepared to accept.

Built in Handlers
Undertow contains a number of build in handlers that provide common functionality. Most of these handlers can be created using static methods on the io.undertow.Handlers utility class.

The most common of these handlers are detailed below.

Path
The path matching handler allows you to delegate to a handler based on the path of the request. It can match on either an exact path or a path prefix, and will update the exchanges relative path based on the selected path. Paths are first checked against an exact match, and then via longest prefix match.

Virtual Host
This handler delegates to a handler based on the contents of the Host: header, which allows you to select a different chain to handle different hosts.

Path Template
Similar to the path handler, however the path template handler allows you to use URI template expressions in the path, for example /rest/{name}. The value of the relevant path template items are stored as an attachment on the exchange, under the io.undertow.util.PathTemplateMatch#ATTACHMENT_KEY attachment key.

Resource
The resource handler is used to serve static resources such as files. This handler takes a ResourceManager instance, that is basically a file system abstraction. Undertow provides file system and class path based resource mangers, as well as a caching resource manager that wraps an existing resource manager to provide in memory caching support.

Predicate
The predicate handler picks between two possible handlers based on the value of a predicate that is resolved against the exchange. For more information see the predicates guide.

HTTP Continue
There are multiple handlers that deal with requests that expect a HTTP 100 Continue response. The HTTP Continue Read Handler will automatically send a continue response for requests that require it the first time a handler attempts to read the request body. The HTTP Continue Accepting handler will immediately either send a 100 or a 417 response depending on the value of a predicate. If no predicate is supplied it all immediately accept all requests. If a 417 response code is send the next handler is not invoked and the request will be changed to be non persistent.

Websocket
Handler that handles incoming web socket connections. See the websockets guide for details.

Redirect
A handler that redirects to a specified location.

Trace
A handler that handles HTTP TRACE requests, as specified by the HTTP RFC.

Header
A handler that sets a response header.

IP Access Control
A handler that allows or disallows a request based on the IP address of the remote peer.

ACL
A handler that allows or disallows a request based on an access control list. Any attribute of the exchange can be used as the basis of this comparison.

URL Decoding
A handler that decodes the URL and query parameters into a specified charset. It may be that different resources may require a different charset for the URL. In this case it is possible to set the Undertow listener to not decode the URL, and instead multiple instances of this handler at an appropriate point in the handler chain. For example this could allow you to have different virtual hosts use different URL encodings.

Set Attribute
Sets an arbitrary attribute on the exchange. Both the attribute and the value are specified as exchange attributes, so this handler can essentially be used to modify any part of the exchange. For more information see the section on exchange attributes.

Rewrite
Handler that provides URL rewrite support.

Graceful Shutdown
Returns a handler that can be used to make sure all running requests are finished before the server shuts down. This handler tracks running requests, and will reject new ones once shutdown has started.

Proxy Peer Address
This handler can be used by servers that are behind a reverse proxy. It will modify the exchanges peer address and protocol to match that of the X-Forwarded-* headers that are sent by the reverse proxy. This means downstream handlers will see that actual clients peer address, rather than that of the proxy.

Request Limiting Handler
Handler that limits the number of concurrent requests. If the number exceeds the limit requests are queued. If the queue fills up then requests are rejected.

Undertow Handler Authors Guide
This guide provides an overview of how to write native handlers for Undertow. It does not cover every API method on the HttpServerExchange object, as many of them are self explanatory or covered by the javadoc. Instead this guide focuses on the concepts you will need to write an Undertow handler.

Lets start with a simple example:

import io.undertow.Undertow;
import io.undertow.server.HttpHandler;
import io.undertow.server.HttpServerExchange;
import io.undertow.util.Headers;

public class HelloWorldServer {

    public static void main(final String[] args) {
        Undertow server = Undertow.builder()                                                    //Undertow builder
                .addHttpListener(8080, "localhost")                                             //Listener binding
                .setHandler(new HttpHandler() {                                                 //Default Handler
                    @Override
                    public void handleRequest(final HttpServerExchange exchange) throws Exception {
                        exchange.getResponseHeaders().put(Headers.CONTENT_TYPE, "text/plain");  //Response Headers
                        exchange.getResponseSender().send("Hello World");                       //Response Sender
                    }
                }).build();
        server.start();
    }

}
For the most part this is all fairly self explanatory:

The Undertow Builder
This API enables you to quickly configure and launch an Undertow server. It is intended for use in embedded and testing environments. At this stage the API is still subject to change.

Listener Binding
The next line tells the Undertow server to bind to localhost on port 8080.

Default Handler
This is the handler that will be matched if a URL does not match any of the paths that are registered with Undertow. In this case we do not have any other handlers registered, so this handler is always invoked.

Response Headers
This sets the content type header, which is fairly self explanatory. One thing to note is that Undertow does not use String as the key for the header map, but rather a case insensitive string io.undertow.util.HttpString. The io.undertow.util.Headers class contains predefined constants for all common headers.

Response Sender
The Undertow sender API is just one way of sending a response. The sender will be covered in more detail later, but in this case as no completion callback has been specified the sender knows that the provided string is the complete response, and as such will set a content length header for us and close the response when done.

From now on our code examples will focus on the handlers themselves, and not on the code to setup a server.

Request Lifecycle
(This is also covered in the Request Lifecycle document.)

When a client connects to the server Undertow creates a io.undertow.server.HttpServerConnection. When the client sends a request it is parsed by the Undertow parser, and then the resulting io.undertow.server.HttpServerExchange is passed to the root handler. When the root handler finishes one of 4 things can happen:

The exchange can be already completed
An exchange is considered complete if both request and response channels have been fully read/written. For requests with no content (such as GET and HEAD) the request side is automatically considered fully read. The read side is considered complete when a handler has written out the full response and closed and fully flushed the response channel. If an exchange is already complete then no action is taken, as the exchange is finished.

The root handler returns normally without completing the exchange
In this case the exchange will be completed by calling HttpServerExchange.endExchange(). The semantics of endExchange() are discussed later.

The root handler returns with an Exception
In this case a response code of 500 will be set, and the exchange will be ended using HttpServerExchange.endExchange().

The root handler can return after HttpServerExchange.dispatch() has been called, or after async IO has been started
In this case the dispatched task will be submitted to the dispatch executor, or if async IO has been started on either the request or response channels then this will be started. In this case the exchange will not be finished, it is up to your async task to finish the exchange when it is done processing.

By far the most common use of HttpServerExchange.dispatch() is to move execution from an IO thread where blocking is not allowed into a worker thread, which does allow for blocking operations. This pattern generally looks like:

Dispatching to a worker thread
public void handleRequest(final HttpServerExchange exchange) throws Exception {
    if (exchange.isInIoThread()) {
      exchange.dispatch(this);
      return;
    }
    //handler code
}
Because exchange is not actually dispatched until the call stack returns you can be sure that more that one thread is never active in an exchange at once. The exchange is not thread safe, however it can be passed between multiple threads as long as both threads do not attempt to modify it at once, and there is a happens before action (such as a thread pool dispatch) in between the first and second thread access.

Ending the exchange
As mentioned above, and exchange is considered done once both the request and response channels have been closed and flushed.

There are two ways to end an exchange, either by fully reading the request channel, and calling shutdownWrites() on the response channel and then flushing it, or by calling HttpServerExchange.endExchange(). When endExchange() is called Undertow will check if and content has been generated yet, if it has then it will simply drain the request channel, and close and flush the response channel. If not and there are any default response listeners registered on the exchange then Undertow will give each of them a chance to generate a default response. This mechanism is how default error pages are generated.

The Undertow Buffer Pool
As Undertow is based on NIO it uses java.nio.ByteBuffer whenever buffering is needed. These buffers are pooled, and should not be allocated on demand as this will severely impact performance. The buffer pool can be obtained by calling HttpServerConnection.getBufferPool().

Pooled buffers must be freed after use, as they will not be cleaned up by the garbage collector. The size of the buffers in the pool is configured when the server is created. Empirical testing has shown that if direct buffers are being used 16kb buffers are optimal if maximum performance is required (as this corresponds to the default socket buffer size on Linux).

Non-blocking IO
By default Undertow uses non-blocking XNIO channels, and requests initially start off in an XNIO IO thread. These channels can be used directly to send and receive data. These channels are quite low level however, so to that end, Undertow provides some abstractions to make using them a little bit easier.

The easiest way to send a response using non-blocking IO is to use the sender API as shown above. It contains several versions of the send() method for both byte and String data. Some versions of the method take a callback that is invoked when the send is complete, other versions do not take a callback and instead end the exchange when the send is complete.

Note that the sender API does not support queuing, you may not call send() again until after the callback has been notified.

When using versions of the send() method that do not take a callback the Content-Length header will be automatically set, otherwise you must set this yourself to avoid using chunked encoding.

The sender API also supports blocking IO, if the exchange has been put into blocking mode by invoking HttpServerExchange.startBlocking() then the Sender will send its data using the exchanges output stream.

Blocking IO
Undertow provides full support for blocking IO. It is not advisable to use blocking IO in an XNIO worker thread, so you will need to make sure that the request has been dispatched to a worker thread pool before attempting to read or write.

The code to dispatch to a worker thread can be found above.

To begin blocking IO call HttpServerExchange.startBlocking(). There are two versions of this method, the one which does not take any parameters which will use Undertow’s default stream implementations, and HttpServerExchange.startBlocking(BlockingHttpServerExchange blockingExchange) which allows you to customize the streams that are in use. For example the servlet implementation uses the second method to replace Undertow’s default streams with Servlet(Input/Output)Stream implementations.

Once the exchange has been put into blocking mode you can now call HttpServerExchange.getInputStream() and HttpServerExchange.getOutputStream(), and write data to them as normal. You can also still use the sender API described above, however in this case the sender implementation will use blocking IO.

By default Undertow uses buffering streams, using buffers taken from the buffer pool. If a response is small enough to fit in the buffer then a Content-Length header will automatically be set.

Headers
Request and response headers are accessible through the HttpServerExchange.getRequestHeaders() and HttpServerExchange.getResponseHeaders() methods. These methods return a HeaderMap, an optimised map implementation.

Headers are written out with the HTTP response header when the first data is written to the underlying channel (this may not be the same time as the first time data is written if buffering is used).

If you wish to force the headers to be written you can call the flush() method on either the response channel or stream.

HTTP Upgrade
In order to perform a HTTP upgrade you can call HttpServerExchange.upgradeChannel(ExchangeCompletionListener upgradeCompleteListener), the response code will be set to 101, and once the exchange is complete your listener will be notified. Your handler is responsible for setting any appropriate headers that the upgrade client will be expecting.

Undertow Request Lifecycle
This document covers the lifecycle of a web request from the point of view of the Undertow server.

When a connection is established XNIO invokes the io.undertow.server.HttpOpenListener, this listener creates a new io.undertow.server.HttpServerConnection to hold state associated with this connection, and then invokes io.undertow.server.HttpReadListener.

The HTTP read listener is responsible for parsing the incoming request, and creating a new io.undertow.server.HttpServerExchange to store the request state. The exchange object contains both the request and response state.

At this point the request and response channel wrappers are setup, that are responsible for decoding and encoding the request and response data.

The root handler is then executed via io.undertow.server.Connectors#executeRootHandler. Handlers are chained together, and each handler can modify the exchange, send a response, or delegate to a different handler. At this point there are a few different things that can happen:

The exchange can be finished. This happens when both the request and response channels are closed. If a content length is set then the channel will automatically close once all the data has been written. This can also be forced by calling HttpServerExchange.endExchange(), and if no data has been written yet any default response listeners that have been registered with the exchange will be given the opportunity to generate a default response, such as an error page. Once the current exchange is finished the exchange completion listeners will be run. The last completion listener will generally start processing the next request on the connection, and will have been setup by the read listener.

The exchange can be dispatched by calling one of the HttpServerExchange.dispatch methods. This is similar to the servlet startAsync() method. Once the call stack returns then the dispatch task (if any) will be run in the provided executor (if no executor is provided it will be ran by the XNIO worker). The most common use of a dispatch is to move from executing in an IO thread (where blocking operations are not allowed), to a worker thread that can block. This pattern looks like:

public void handleRequest(final HttpServerExchange exchange) throws Exception {
    if (exchange.isInIoThread()) {
      exchange.dispatch(this);
      return;
    }
    //handler code
}
Reads/Writes can be resumed on a request or response channel. Internally this is treated like a dispatch, and once the call stack returns the relevant channel will be notified about IO events. The reason why the operation does not take effect until the call stack returns is to make sure that we never have multiple threads acting in the same exchange.

The call stack can return without the exchange being dispatched. If this happens HttpServerExchange.endExchange() will be called, and the request will be finished.

An exception can be thrown. If this propagates all the way up the call stack the exchange will be ended with a 500 response code.

Error Handling
Error handling is accomplished through the use of default response listeners. These are listeners that can generate a response if the exchange is ended without a response being sent.

This is completely different to Servlet error handling. Servlet error handling is implemented as part of Undertow Servlet, and follows the standard Servlet rules.
In general there are two types of errors that we need to worry about, handlers that throw exceptions or handlers that set an error response code and then call HttpServerExchange.endExchange().

Exceptions
The easiest way to handle exceptions is to catch them in an outer handler. For example:

public class ErrorHandler implements HttpHandler {

    @Override
    public void handleRequest(final HttpServerExchange exchange) throws Exception {
        try {
            next.handleRequest(exchange);
        } catch (Exception e) {
            if(exchange.isResponseChannelAvailable()) {
                //handle error
            }
        }
    }
}
The allows your application to handle exceptions in whatever manner you see fit.

If the exception propagates out of the handler chain a 500 response code will be set and the exchange can be ended.

Default Response Listeners
Default response listener allow you to generate a default page if the exchange is ended without a response body. These handlers should test for an error response code, and then generate an appropriate error page.

Note that these handlers will be run for all requests that terminate with no content, but generating default content for successful requests will likely cause problems.

Default response listeners can be registered via the HttpServerExchange#addDefaultResponseListener(DefaultResponseListener) method. They will be called in the reverse order that they are registered, so the last handler registered is the first to be called.

The following example shows a handler that will generate a simple next based error page for 500 errors:

public class SimpleErrorPageHandler implements HttpHandler {

    private final HttpHandler next;

    public SimpleErrorPageHandler(final HttpHandler next) {
        this.next = next;
    }

    @Override
    public void handleRequest(final HttpServerExchange exchange) throws Exception {
        exchange.addDefaultResponseListener(new DefaultResponseListener() {
            @Override
            public boolean handleDefaultResponse(final HttpServerExchange exchange) {
                if (!exchange.isResponseChannelAvailable()) {
                    return false;
                }
                Set<Integer> codes = responseCodes;
                if (exchange.getResponseCode() == 500) {
                    final String errorPage = "<html><head><title>Error</title></head><body>Internal Error</body></html>";
                    exchange.getResponseHeaders().put(Headers.CONTENT_LENGTH, "" + errorPage.length());
                    exchange.getResponseHeaders().put(Headers.CONTENT_TYPE, "text/html");
                    Sender sender = exchange.getResponseSender();
                    sender.send(errorPage);
                    return true;
                }
                return false;
            }
        });
        next.handleRequest(exchange);
    }
}
Security
Undertow has a flexible security architecture that provides several built in authentication mechanisms, as well as providing an API to allow you to provide custom mechanisms. Mechanisms can be combined (as much as the relevant specifications allow). This document covers the details of the core Undertow security API. For details on how these are used in servlet deployments see Servlet Security.

The SecurityContext
The core of Undertow’s security architecture is the SecurityContext. It is accessible via the HttpServerExchange.getSecurityContext() method. The security context is responsible for maintaining all security related state for the request, including configured authentication mechanisms and the current authenticated user.

Security Handlers
Security within Undertow is implemented as a set of asynchronous handlers and a set of authentication mechanisms co-ordinated by these handlers.

Early in the call chain is a handler called SecurityInitialHandler, this is where the security processing beings, this handler ensures that an empty SecurityContext is set on the current HttpServerExchange

Allow authentication to occur in the call as early as possible.

Allows for use of the mechanisms in numerous scenarios and not just for servlets.

The SecurityContext is responsible for both holding the state related to the currently authenticated user and also for holding the configured mechanisms for authentication (AuthenticationMechanism) and providing methods to work with both of these. As this SecurityContext is replacable a general configuration can be applied to a complete server with custom configuration replacing it later in the call.

After the SecurityContext has been established subsequent handlers can then add authentication mechanisms to the context, to simplify this Undertow contains a handler called AuthenticationMechanismsHandler this handler can be created with a set of AuthenticationMechanism mechanisms and will set them all on the established SecurityContext. Alternatively custom handlers could be used to add mechanisms one at a time bases on alternative requirements.

The next handler in the authentication process is the AuthenticationConstraintHandler, this handler is responsible for checking the current request and identifying if authentication should be marked as being required for the current request. This handler can take a Predicate that makes a decision about if the request requires authentication.

The final handler in this chain is the AuthenticationCallHandler, this handler is responsible for ensuring the SecurityContext is called to actually perform the authentication process, depending on any identified constraint this will either mandate authentication or only perform authentication if appropriate for the configured mechanisms.

There is no requirement for these handlers to be executed consecutively, the only requirement is that first the SecurityContext is established, then the authentications and constrain check can be performed in any order and finally the AuthenticationCallHandler must be used before any processing of a potentially protected resource is called.

An Example Security Chain
Figure 1. An Example Security Chain
Security mechanisms that are to be used must implement the following interface: -

public interface AuthenticationMechanism {

    AuthenticationMechanismOutcome authenticate(final HttpServerExchange exchange, final SecurityContext securityContext);

    ChallengeResult sendChallenge(final HttpServerExchange exchange, final SecurityContext securityContext);
}
The AuthenticationMechanismOutcome is used by the mechanism to indicate the status of the attempted authentication.

The three options are:

AUTHENTICATED - The authentication was successful. No further methods will be tried and no challenge will be sent.

NOT_ATTEMPTED - There was not enough information available to attempt an authentication. The next mechanism will be tried. If this was the last mechanism and authentication is required then a challenge will be sent by calling the sendChallenge method on all the mechanisms in order. If authentication is not required then the request will proceed with no authenticated principal.

NOT_AUTHENTICATED - The authentication failed, usually this is due to invalid credentials. The authentication process will not proceed further, and a new challenge will be sent to the client.

Regardless of if authentication has been flagged as being required when the request reaches the AuthenticationCallHandler the SecurityContext is called to commence the process. The reason this happens regardless of if authentication is flagged as required is for a few reasons:

The client may have sent additional authentication tokens and have expectations the response will take these into account.

We may be able to verify the remote user without any additional rount trips, especially where authentication has already occurred.

The authentication mechanism may need to pass intermediate updates to the client so we need to ensure any inbound tokens are valid.

When authentication runs the authenticate method on each configured AuthenticationMechanism is called in turn, this continues until one of the following occurs:

A mechanism successfully authenticates the request and returns AUTHENTICATED.

A mechanism attempts but does not complete authentication and returns NOT_AUTHENTICATED.

The list of mechanisms is exhausted.

At this point if the response was AUTHENTICATED then the request will be allowed through and passed onto the next handler.

If the request is NOT_AUTHENTICATED then either authentication failed or a mechanism requires an additional round trip with the client, either way the sendChallenge method of each defined AuthenticationMethod is called in turn and the response sent back to the client. All mechanisms are called as even if one mechanism is mid-authentication the client can still decide to abandon that mechanism and switch to an alternative mechanism so all challenges need to be re-sent.

If the list of mechanisms was exhausted then the previously set authentication constraint needs to be checked, if authentication was not required then the request can proceed to the next handler in the chain and that will be then of authentication for this request (unless a later handler mandates authentication and requests authentication is re-attempted). If however authentication was required then as with a NOT_AUTHENTICATED response each mechanism has sendChallenge called in turn to generate an authentication challenge to send to the client.

Predicates Attributes and Handlers
Introduction
Predicates and Exchange attributes are an abstraction that allow handlers to read, write and make decisions based on certain attributes of a request without hard coding this into the handler. These form the basis of Undertow’s text based handler configuration format. Some examples are shown below:

Use the reverse proxy to send all requests to /reports to a different backend server:

path-prefix('/reports') -> reverse-proxy({'http://reports1.mydomain.com','http://reports2.mydomain.com'})
Redirect all requests from /a to /b. The first example only redirects if there is an exact match, the later examples match all paths that start with /a:

path('/a') -> redirect('/b')
path-prefix('/a') -> redirect('/b${remaining}')
regex('/a(.*)') -> set(attribute='%{o,Location}', value='/b${1}') -> response-code(302)
Exchange Attributes
An exchange attribute represents the value of part of the exchange. For example the path attribute represents the request path, the method attribute represents the HTTP. Even though these attributes can be retrieved and modified directly this requires a handler to hard code the attribute that they wish to use. For example Undertow provides a handler that checks an attribute against an access control list. There are lots of different attributes we may wish to check against the ACL (e.g. username, User-Agent header, request path).

Predicates
A predicate is a function that takes a value (in this case the HttpServerExchange) and returns a true or false value. This allows actions to be taken based on the return value of the predicate. In general any handler that needs to make a boolean decision based on the exchange should use a predicate to allow for maximum flexibility.

The provided predicate handler can be used to make a decision between which handler to invoke based on the value of a predicate.

Programmatic Representation of Exchange Attributes
An exchange attribute is represented by the io.undertow.attribute.ExchangeAttribute interface:

/**
 * Representation of a string attribute from a HTTP server exchange.
 */
public interface ExchangeAttribute {

    /**
     * Resolve the attribute from the HTTP server exchange. This may return null if the attribute is not present.
     * @param exchange The exchange
     * @return The attribute
     */
    String readAttribute(final HttpServerExchange exchange);

    /**
     * Sets a new value for the attribute. Not all attributes are writable.
     * @param exchange The exchange
     * @param newValue The new value for the attribute
     */
    void writeAttribute(final HttpServerExchange exchange, final String newValue) throws ReadOnlyAttributeException;
}
Undertow provides implementation of a lot of attributes out of the box, most of which can be accessed using the io.undertow.attribute.ExchangeAttributes utility class. Some of the attributes that are provided include request and response headers, cookies, path, query parameters, the current user and more.

Programmatic Representation of Predicates
Predicates are represented by the io.undertow.predicate.Predicate interface:

/**
 * A predicate.
 *
 * This is mainly uses by handlers as a way to decide if a request should have certain
 * processing applied, based on the given conditions.
 */
public interface Predicate {

    /**
     * Attachment key that can be used to store additional predicate context that allows the predicates to store
     * additional information. For example a predicate that matches on a regular expression can place additional
     * information about match groups into the predicate context.
     *
     * Predicates must not rely on this attachment being present, it will only be present if the predicate is being
     * used in a situation where this information may be required by later handlers.
     *
     */
    AttachmentKey<Map<String, Object>> PREDICATE_CONTEXT = AttachmentKey.create(Map.class);

    boolean resolve(final HttpServerExchange value);

}
Undertow provides built in predicates that can be created using the io.undertow.predicate.Predicates utility class. This includes basic boolean logic predicates (and, or and not), as well as other useful predicates such as path matching (including prefix and suffix based matches), regular expression matching, contains and exists. Many of these predicates operate on exchange attributes, so they can be used to match arbitrary parts of the exchange. The following example demonstrates a predicate that matches any exchange that has no Content-Type header where the method is POST:

Predicate predicate = Predicates.and(
        Predicates.not(Predicates.exists(ExchangeAttributes.requestHeader(Headers.CONTENT_TYPE))),
        Predicates.equals("POST", ExchangeAttributes.requestMethod()));
Textual Representation
Undertows predicate language is still considered tech preview. Its syntax will likely change in a future version as the language is expanded.
All these attributes and predicates are all well and good, but unless there is a way for the end user to configure them without resorting to programmatic means they are not super useful. Fortunately Undertow provides a way to do just that.

Exchange Attributes
Exchange attributes may have up to two textual representations, a long one and a short one. The long version takes the form %{attribute}, while the short version is a percent sign followed by a single character. A list of the built in attributes provided by Undertow is below:

Attribute	Short Form	Long Form
Remote IP address

%a

%{REMOTE_IP}

Local IP address

%A

%{LOCAL_IP}

Bytes sent, excluding HTTP headers, or - if no bytes were sent

%b

Bytes sent, excluding HTTP headers

%B

%{BYTES_SENT}

Remote host name

%h

%{REMOTE_HOST}

Request protocol

%H

%{PROTOCOL}

Remote logical username from identd (always returns -)

%l

Request method

%m

%{METHOD}

Local port

%p

%{LOCAL_PORT}

Query string (prepended with a ? if it exists, otherwise an empty string)

%q

%{QUERY_STRING}

First line of the request

%r

%{REQUEST_LINE}

HTTP status code of the response

%s

%{RESPONSE_CODE}

Date and time, in Common Log Format format

%t

%{DATE_TIME}

Remote user that was authenticated

%u

%{REMOTE_USER}

Requested URL path

%U

%{REQUEST_URL}

Request relative path

%R

%{RELATIVE_PATH}

Local server name

%v

%{LOCAL_SERVER_NAME}

Time taken to process the request, in millis

%D

%{RESPONSE_TIME}

Time taken to process the request, in seconds

%T

Time taken to process the request, in micros

%{RESPONSE_TIME_MICROS}

Time taken to process the request, in nanos

%{RESPONSE_TIME_NANOS}

Current request thread name

%I

%{THREAD_NAME}

SSL cypher

%{SSL_CIPHER}

SSL client certificate

%{SSL_CLIENT_CERT}

SSL session id

%{SSL_SESSION_ID}

Cookie value

%{c,cookie_name}

Query parameter

%{q,query_param_name}

Request header

%{i,request_header_name}

Response header

%{o,response_header_name}

Value from the predicate context

${name}

Any tokens that do not follow one of the above patterns are assumed to be literals. For example assuming a user name of Stuart and a request method of GET the attribute text Hello %u the request method is %m will give the value Hello Stuart the request method is GET.

These attributes are used anywhere that text based configuration is required, e.g. specifying the log pattern in the access log.

Some handlers may actually modify these attributes. In order for this to work the attribute must not be read only, and must consist of only a single token from the above table.

Textual Representation of Predicates
Sometimes it is also useful to have a textual representation of a predicate. For examples when configuring a handler in Wildfly we may want it only to run if a certain condition is met, and when doing rewrite handling we generally do not want to re-write all requests, only a subset of them.

To this end Undertow provides a way to specify a textual representation of a predicate. In its simplest form, a predicate is represented as predicate-name[name1=value1,name2=value2].

For example, the following predicates all match POST requests:

method(POST)
method(value=POST)
equals({%{METHOD}, POST})
equals(%m, "POST")
regex(pattern="POST", value="%m", full-match=true)
Lets examine these a bit more closely. The first one method(POST) uses the built in method predicate that matches based on the method. As this predicate takes only a single parameter (that is the default parameter) it is not necessary to explicitly specify the parameter name. Also note that POST is not quoted, quoting is only necessary if the token contains spaces, commas or square braces.

The second example method(value=POST) is the same as the first, except that the parameter name is explicitly specified.

The third and fourth examples demonstrates the equals predicate. This predicate actually takes one parameter that is an array, and will return true if all items in the array are equal. Arrays are generally enclosed in curly braces, however in this case where there is a single parameter that is the default parameter the braces can be omitted.

The final examples shows the use of the regex predicate. This takes 3 parameters, the pattern to match, the value to match against and full-match, which determines if the pattern must match the whole value or simply part of it.

Some predicates may also capture additional information about the match and store it in the predicate context. For example the regex predicate will store the match under the key 0, and any match groups under the key 1, 2 etc.

These contextual values can then be retrieved by later predicates of handlers using the syntax ${0}, ${1} etc.

Predicates can be combined using the boolean operators and, or and not. Some examples are shown below:

not method(POST)
method(POST) and path-prefix("/uploads")
path-template(value="/user/{username}/*") and equals(%u, ${username})
regex(pattern="/user/(.*?)./.*", value=%U, full-match=true) and equals(%u, ${1})
The first predicate will match everything except post requests. The second will match all post requests to /uploads. The third predicate will match all requests to URL’s of the form /user/{username}/* where the username is equal to the username of the currently logged in user. In this case the username part of the URL is captured, and the equals handler can retrieve it using the ${username} syntax shown above. The fourth example is the same as the third, however it uses a regex with a match group rather than a path template.

The complete list of built in predicates is shown below:

Name	Parameters	Default Parameter	Additional context
auth-required

contains

search: String[] (required), value: attribute (required)

directory

value: attribute

value

Only usable within the scope of Servlet deployment

dispatcher

value: String (required)

value

Only usable within the scope of Servlet deployment

equals

value: attribute[] (required)

value

exists

value: attribute (required)

value

file

value: attribute

value

Only usable within the scope of Servlet deployment

max-content-size

value: Long (required)

value

method

value: String[] (required)

value

min-content-size

value: Long (required)

value

path

path: String[] (required)

path

path-prefix

path: String[] (required)

path

Unmatched under ${remaining}

path-suffix

path: String[] (required)

path

path-template

match: attribute, value: String (required)

value

Path template elements under the name

regex

case-sensitive: Boolean, full-match: Boolean, pattern: String (required), value: attribute

pattern

Match groups under number

secure

Textual Representation of Handlers
Handlers are represented in a similar way to predicates. Handlers and predicates are combined into the Undertow predicate language.

The general form of this language is predicate -> handler. If the predicate evaluates to true the handler is executes. If there is only a handler present then the handler is always executed. Handlers are executed in order and separated by line breaks or semi colons. Curly braces can be used to create a sub grouping, with all handlers (and possibly predicates) in the sub grouping being executed. The else keyword can be used to execute a different handler or sub grouping if the predicate evaluates to false. Sub grouping can contain other predicates and sub groupings.

The restart handler is a special handler that will restart execution at the beginning of the predicated handler list. The done handler will skip any remaining rules.

Some examples are below:

path(/skipallrules) and true -> done
method(GET) -> set(attribute='%{o,type}', value=get)
regex('(.*).css') -> { rewrite('${1}.xcss'); set(attribute='%{o,chained}', value=true) }
regex('(.*).redirect$') -> redirect('${1}.redirected')
set(attribute='%{o,someHeader}', value=always)
path-template('/foo/{bar}/{f}') -> set[attribute='%{o,template}', value='${bar}')
path-template('/bar->foo') -> {
    redirect(/);
} else {
    path(/some-other-path) -> header(header=my-header,value=my-value)
}
regex('(.*).css') -> set(attribute='%{o,css}', value='true') else set(attribute='%{o,css}', value='false');
path(/restart) -> {
    rewrite(/foo/a/b);
    restart;
}
Built in Handlers
Access Log Handler
Name:

access-log

Class:

io.undertow.server.handlers.accesslog.AccessLogHandler

Parameters:

format: String (required)

Default Parameter

format

A handler that will log access attempts to JBoss Logging. The output can be configured via the format parameter which takes exchange attributes.

Access Control Handler
Name:

access-control

Class:

io.undertow.server.handlers.AccessControlListHandler

Parameters:

acl: String[] (required), default-allow: boolean, attribute: ExchangeAttribute (required)

Default Parameter

This handler is used to specify access control lists. These lists consist of an array of strings, which follow the format {pattern} allow|deny, where {pattern} is a regular expression. These rules are applied against the specified exchange attribute until a match is found. If the result in deny then the request is rejected with a 403 response, otherwise the next handler is invoked.

If no match is found the default behaviour is to deny.

Allowed Methods
Name:

allowed-methods

Class:

io.undertow.server.handlers.AllowedMethodsHandler

Parameters:

methods: String[] (required)

Default Parameter

methods

This handler takes a list of allowed methods. If an incoming request’s method is in the specific method list then the request is allowed, otherwise it is rejected with a 405 response (method not allowed).

Blocking Handler
Name:

blocking

Class:

io.undertow.server.handlers.BlockingHandler

Parameters:

Default Parameter

This handler will mark the request as blocking and dispatch it to the XNIO worker thread.

Buffer Request Handler
Name:

buffer-request

Class:

io.undertow.server.handlers.RequestBufferingHandler

Parameters:

buffers: int (required)

Default Parameter

buffers

This handler will pause request processing while it attempts to read the request body. It uses Undertow buffers to store the request body, so the amount of data that can be buffered is determined by the buffer size multiplied by the buffers parameter.

Once either all data is read or the configured maximum amount of data has been read then the next handler will be invoked.

This can be very useful when use a blocking processing model, as the request will be read using non-blocking IO, and as the request will not be dispatched to the thread pool until the data has been read.

Byte Range Handler
Name:

byte-range

Class:

io.undertow.server.handlers.ByteRangeHandler

Parameters:

send-accept-ranges: boolean

Default Parameter

send-accept-ranges

A handler that adds generic support for range requests. This handler will work with any request, however in general it is less efficient than supporting range requests directly, as the full response will be generated and then pieces that are not requested will be discarded. Nonetheless for dynamic content this is often the only way to fully support ranges.

If the handler that generated the response already handled the range request then this handler will have no effect.

By default the Accept-Range header will not be appended to responses, unless the send-accept-ranges parameter is true.

Canonical Path Handler
Name:

canonical-path

Class:

io.undertow.server.handlers.CanonicalPathHandler

Parameters:

Default Parameter

Handler that turns a path into a canonical path by resolving ../ and ./ segments. If these segments result in a path that would be outside the root then these segments are simply discarded.

This can help prevent directory traversal attacks, as later handlers will only every see a path that is not attempting to escape the server root.

Clear Handler
Name:

clear

Class:

io.undertow.server.handlers.SetAttributeHandler

Parameters:

attribute: ExchangeAttribute (required)

Default Parameter

attribute

A special form of the set-attribute handler that sets an attribute to null.

Compress Handler
Name:

compress

Class:

io.undertow.server.handlers.encoding.EncodingHandler

Parameters:

Default Parameter

A handler that adds support for deflate and gzip compression.

Disable Cache Handler
Name:

disable-cache

Class:

io.undertow.server.handlers.DisableCacheHandler

Parameters:

Default Parameter

A handler that will set headers to disable the browser cache. The headers that are set are:

Cache-Control: no-cache, no-store, must-revalidate

Pragma: no-cache

Expires: 0

Disallowed Methods Handler
Name:

disallowed-methods

Class:

io.undertow.server.handlers.DisallowedMethodsHandler

Parameters:

methods: String[] (required)

Default Parameter

methods

This handler takes a list of disallowed methods. If an incoming request’s method is in the specific method list then the request is rejected with a 405 response (method not allowed), otherwise it is allowed.

Done Handler
Name:

done

Class:

N/A

Parameters:

Default Parameter

This is a pseudo handler that will finish execution of the current predicated handlers, and invoke whatever handler is configured after the current predicated handlers block.

Request Dumping Handler
Name:

dump-request

Class:

io.undertow.server.handlers.RequestDumpingHandler

Parameters:

Default Parameter

A handler that will dump all relevant details from a request to the log. As this is quite expensive a predicate should generally be used to control which requests are dumped.

Eager Form Parsing Handler
Name:

eager-form-parser

Class:

io.undertow.server.handlers.form.EagerFormParsingHandler

Parameters:

Default Parameter

Handler that eagerly parses form data. The request chain will pause while the data is being read, and then continue when the form data is fully passed.

This is not strictly compatible with servlet, as it removes the option for the user to parse the request themselves. It also removes the option to control the charset that the request will be decoded to.
Error File Handler
Name:

error-file

Class:

io.undertow.server.handlers.error.FileErrorPageHandler

Parameters:

file: String (required), response-codes: int[] (required)

Default Parameter

A handler that will respond with a file based error page if the request has finished with one of the specified error codes and no response body has been generated.

Forwarded Handler
Name:

forwarded

Class:

io.undertow.server.handlers.ForwardedHandler

Parameters:

Default Parameter

This handler implements rfc7239 and handles the Forwarded header. It does this by updating the exchange so its peer and local addresses reflect the values in the header.

This should only be installed behind a reverse proxy that has been configured to send the Forwarded header, otherwise a remote user can spoof their address by sending a header with bogus values.

In general either this handler or proxy-peer-address handler should be used, they should not both be installed at once.

Header Handler
Name:

header

Class:

io.undertow.server.handlers.SetHeaderHandler

Parameters:

header: String (required), value: ExchangeAttribute (required)

Default Parameter

The handler sets a response header with the given name and value.

Http Continue Accepting Handler
Name:

http-continue-accept

Class:

io.undertow.server.handlers.HttpContinueAcceptingHandler

Parameters:

Default Parameter

A handler that will respond to requests that expect a 100-continue response.

IP Access Control Handler
Name:

ip-access-control

Class:

io.undertow.server.handlers.IPAddressAccessControlHandler

Parameters:

acl: String[] (required), default-allow: boolean, failure-status: int

Default Parameter

acl

A handler that provided IP based access control. The ACL list is of the form {pattern} allow|deny, where {pattern} can be one of the following (both IPv4 and IPv6 are accepted):

An exact IP address (e.g. 192.168.0.1)

An Wildcard IP address (e.g. 192.168.0.*)

A Wildcard in slash notation: (e.g. 192.168.0.0/24)

By default anything that is not matched will be denied.

The failure-status param allows you to set the response code to be set on failure, 403 will be sent by default.

JVM Route Handler
Name:

jvm-route

Class:

io.undertow.server.JvmRouteHandler

Parameters:

session-cookie-name: String, value: String (required)

Default Parameter

value

A handler that appends a specified JVM route to session cookie values. This can enable sticky sessions for load balancers that support it.

Learning Push Handler
Name:

learning-push

Class:

io.undertow.server.handlers.LearningPushHandler

Parameters:

max-age: int, max-entries: int

Default Parameter

Mark Secure Handler
Name:

mark-secure

Class:

io.undertow.servlet.handlers.MarkSecureHandler

Parameters:

Default Parameter

A handler that will mark a request as secure. This means that javax.servlet.ServletRequest#isSecure() will return true, and the security layer will consider the request as being sent over a confidential channel.

Path Separator Handler
Name:

path-separator

Class:

io.undertow.server.handlers.PathSeparatorHandler

Parameters:

Default Parameter

A handler that only takes effect on windows systems (or other systems that do not use / as the path separator character). Any instances of the path seperator character in the URL are replaced with a /.

Proxy Peer Address Handler
Name:

proxy-peer-address

Class:

io.undertow.server.handlers.ProxyPeerAddressHandler

Parameters:

Default Parameter

A handler that handles X-Forwarded-* headers by updating the values on the current exchange to match what was sent in the header.

This should only be installed behind a reverse proxy that has been configured to send the X-Forwarded-* header, otherwise a remote user can spoof their address by sending a header with bogus values.

The headers that are read are:

X-Forwarded-For

X-Forwarded-Proto

X-Forwarded-Host

X-Forwarded-Port

In general either this handler or forwarded handler should be used, they should not both be installed at once.

Redirect Handler
Name:

redirect

Class:

io.undertow.server.handlers.RedirectHandler

Parameters:

value: ExchangeAttribute (required)

Default Parameter

value

A handler that will redirect to the location specified by value.

Request Limiting Handler
Name:

request-limit

Class:

io.undertow.server.handlers.RequestLimitingHandler

Parameters:

requests: int (required)

Default Parameter

requests

A handler that will limit the number of concurrent requests to the limit specified, requests that exceed the limit will be queued.

Resolve Local Name Handler
Name:

resolve-local-name

Class:

io.undertow.server.handlers.LocalNameResolvingHandler

Parameters:

Default Parameter

A handler that will resolve the exchange destination address, if it is not already resolved.

Resolve Peer Name Handler
Name:

resolve-peer-name

Class:

io.undertow.server.handlers.PeerNameResolvingHandler

Parameters:

Default Parameter

A handler that will resolve the exchange source address, if it is not already resolved.

Resource Handler
Name:

resource

Class:

io.undertow.server.handlers.resource.ResourceHandler

Parameters:

allow-listing: boolean, location: String (required)

Default Parameter

location

A handler that will serve files from the local file system at the specified location.

Response Code Handler
Name:

response-code

Class:

io.undertow.server.handlers.ResponseCodeHandler

Parameters:

value: int (required)

Default Parameter

value

A handler that sets the specified status code and then ends the exchange.

Response Rate Limiting Handler
Name:

response-rate-limit

Class:

io.undertow.server.handlers.ResponseRateLimitingHandler

Parameters:

bytes: int (required), time: long (required)

Default Parameter

A handler that limits the speed of responses. This speed is set in terms of bytes per time block.

The time block is specified in MS, so if you wanted a limit of 1kb per second you would set bytes to 1024 and time to 1000.

Restart Handler
Name:

restart

Class:

N\A

Parameters:

Default Parameter

A pseudo handler that restarts execution of the current predicated handler block. Care must be taken to avoid infinite loops, usually by making sure that the exchange has been modified in such a way that it will not end up on the restart handler before calling restart.

Reverse Proxy Handler
Name:

reverse-proxy

Class:

io.undertow.server.handlers.proxy.ProxyHandler

Parameters:

hosts: String[] (required), rewrite-host-header: Boolean

Default Parameter

hosts

A handler that will proxy requests to the specified hosts, using round-robin based load balancing.

Rewrite Handler
Name:

rewrite

Class:

io.undertow.server.handlers.SetAttributeHandler

Parameters:

value: ExchangeAttribute (required)

Default Parameter

value

A handler that rewrites the current path.

Set Attribute Handler
Name:

set

Class:

io.undertow.server.handlers.SetAttributeHandler

Parameters:

attribute: ExchangeAttribute (required), value: ExchangeAttribute (required)

Default Parameter

A handler that can be used to set any writable attribute on the exchange.

Secure Cookie Handler
Name:

secure-cookie

Class:

io.undertow.server.handlers.SecureCookieHandler

Parameters:

Default Parameter

A handler that will mark any cookies that are set over a secure channel as being secure cookies.

SameSite Cookie Handler
Name:

samesite-cookie

Class:

io.undertow.server.handlers.SameSiteCookieHandler

Parameters:

mode: String (required), cookie-pattern: String, case-sensitive: Boolean, enable-client-checker (Boolean), add-secure-for-none (Boolean)

Default Parameter

mode

A handler that will add the SameSite attribute to all cookies that match a pattern. If the pattern is omitted, it will add the attribute to all cookies. The value of the added attribute is specified by the mode parameter.

If mode is None and add-secure-for-none is true or unspecificed, a Secure attribute is also added to the cookie.

By default, this handler checks if the client supports SameSite=None when mode is None (see https://www.chromium.org/updates/same-site/incompatible-clients). If the client is not compatible, the attribute is not added. This check can be disabled by setting the enable-client-checker parameter to false.

SSL Headers Handler
Name:

ssl-headers

Class:

io.undertow.server.handlers.SSLHeaderHandler

Parameters:

Default Parameter

A handler that will set SSL information on the connection based on headers received from the load balancer.

This is for situations where SSL is terminated at the load balancer, however SSL information is still required on the back end.

The headers that are read are:

SSL_CLIENT_CERT

SSL_CIPHER

SSL_SESSION_ID

SSL_CIPHER_USEKEYSIZE

This handler should only be used if the front end load balancer is configured to either set or clear these headers, otherwise remote users can trick the server into thinking that SSL is in use over a plaintext connection.

Store Response Header
Name:

store-response

Class:

io.undertow.server.handlers.StoredResponseHandler

Parameters:

Default Parameter

A handler that reads the full response and stores it in an attachment on the exchange. Generally used in combination with the request dumping handler to dump the response body.

Stuck Thread Detection Handler
Name:

stuck-thread-detector

Class:

io.undertow.server.handlers.StuckThreadDetectionHandler

Parameters:

threshhold: int

Default Parameter

threshhold

A handler that will print a log message if a request takes longer than the specified number of seconds to complete.

Trace Handler
Name:

trace

Class:

io.undertow.server.handlers.HttpTraceHandler

Parameters:

Default Parameter

A handler that responds to HTTP TRACE requests.

Uncompress Handler
Name:

uncompress

Class:

io.undertow.server.handlers.encoding.RequestEncodingHandler

Parameters:

Default Parameter

A handler that can decompress a content-encoded request. Note that such requests are not part of the HTTP standard, and as such represent a non-compatible extension. This will generally used for RPC protocols to enabled compressed invocations.

URL Decoding Handler
Name:

url-decoding

Class:

io.undertow.server.handlers.URLDecodingHandler

Parameters:

charset: String (required)

Default Parameter

charset

A handler that will decode the request path (including query parameters) into the specified charset. To use this handler request decoding must be disabled on the listener.

Reverse Proxy
Undertow’s reverse proxy is implemented as a handler, and as such it can be used like any other handler.

An instance of the handler can be created using the io.undertow.Handlers#proxyHandler method. It takes two parameters, a ProxyClient instance and the next handler to invoke if the client does not know how to proxy a request (often just a handler that returns a 404). It is also possible to specify the maximum request time, after which time a request will be terminated.

Undertow provides two instances of ProxyClient (there is a third one under development that has mod_cluster support). Note that all proxy clients use the Undertow HTTP client API. At the moment this provides support for HTTP and AJP backends.

The provided proxy clients are:

io.undertow.server.handlers.proxy.SimpleProxyClientProvider
A proxy client that just forwards to another server. It takes the servers URI as a constructor parameter, and then will forward all requests to the target server. Connections are maintained on a one to one basis, a connection to the front end server results in a new connection to the back end server.

io.undertow.server.handlers.proxy.LoadBalancingProxyClient
A load balancing proxy client that forwards requests to servers in a round robin fashion, unless sticky sessions have been enabled in which case requests with a session cookie will always be forwarded to the same server.

Target servers can be added to the client using the addHost method, which takes the server URI to connect to and an optional node ID to use for sticky sessions.

The load balancing proxy maintain a pool of connections to each backend server. The number of connections in the pool is determined by the parameter connectionsPerThread, which specifies the maximum number of connections per IO thread (so to get the total number of connections multiply this by the number of IO threads). The reason why this pool is maintain by thread is to make sure that both the frontend and backend connections use the same thread, so the proxy client does not have to deal with threading issues.

In general the client connects to servers one after the other in a round robin fashion, skipping any servers that are either full (i.e. all connections in the pool are in use) or in a problem state (which happens if a connection attempt fails). Servers that are in the problem state will be queried every so often (controlled by problemServerRetry) to see if they have recovered.

HTTP Upgrade (including websockets) is fully supported for HTTP based backends. When a HTTP upgrade occurs the connection is taken out of the pool and takes on a one to one relationship with the front end connection. Upgraded connections to not count towards the backend connection limit.

Websockets
Undertow provides support for Websockets out of the box. Undertow core provides a XNIO based API, which uses the Xnio Channel interface to provide access to the web socket at a low level.

Most users will want a higher level interface than this, and to that end Undertow also provides a JSR-356 implementation. This implementation is part of a separate jar, to use it you must make sure that you have the undertow-servlet and undertow-websocket-jsr artifacts on your class path. Servlet support is required because the JSR-356 API is based on the Servlet API.

For maven users the following snippet should be added to your pom.xml:

<dependency>
  <groupId>io.undertow</groupId>
  <artifactId>undertow-servlet</artifactId>
  <version>${version.io.undertow}</version>
</dependency>

<dependency>
  <groupId>io.undertow</groupId>
  <artifactId>undertow-websockets-jsr</artifactId>
  <version>${version.io.undertow}</version>
</dependency>
Undertow Servlet
Creating a Servlet Deployment
A simple example of how to create a Servlet deployment is the servlet example from the Undertow examples:

DeploymentInfo servletBuilder = Servlets.deployment()
        .setClassLoader(ServletServer.class.getClassLoader())
        .setContextPath("/myapp")
        .setDeploymentName("test.war")
        .addServlets(
                Servlets.servlet("MessageServlet", MessageServlet.class)
                        .addInitParam("message", "Hello World")
                        .addMapping("/*"),
                Servlets.servlet("MyServlet", MessageServlet.class)
                        .addInitParam("message", "MyServlet")
                        .addMapping("/myservlet"));

DeploymentManager manager = Servlets.defaultContainer().addDeployment(servletBuilder);
manager.deploy();
PathHandler path = Handlers.path(Handlers.redirect("/myapp"))
        .addPrefixPath("/myapp", manager.start());

Undertow server = Undertow.builder()
        .addHttpListener(8080, "localhost")
        .setHandler(path)
        .build();
server.start();
The basic process is to create a DeploymentInfo structure (this can be done use the io.undertow.servlets.Servlets utility method), add any Servlets and other information to this structure, and then deploy it to a Servlet container.

After this is deployed you can call the start() method on the DeploymentManager which returns a HttpHandler than can then be installed in an Undertow server handler chain.

The DeploymentInfo structure has a lot of data, and most of it directly corresponds to data in web.xml so it will not be covered in this guide, instead this will focus on the elements that are Undertow specific.

Handler Chain Wrappers
Handler chain wrappers allow you to insert additional HttpHandlers into the Servlet chain, there are three methods that allow you to do this:

addInitialHandlerChainWrapper()
This allows you to add a handler that is run before all other Servlet handlers. If this handler does not delegate to the next handler in the chain it can effectively bypass the Servlet deployment.

addOuterHandlerChainWrapper()
This handler is run after the servlet request context has been setup, but before any other handlers.

addInnerHandlerChainWrapper()
This handler is run after the security handlers, just before the request is dispatched to deployment code.

Thread Setup Actions
Thread setup actions can be added using the addThreadSetupAction() method, these actions will be run before a request is dispatched to a thread, so any thread local data can be setup.

The Resource Manager
The ResourceManager is used by the default servlet to serve all static resources. By modifying the resource manager in use it is possible to pick where static resource are served from.

Authentication Mechanisms
The authentication mechanism to use is determined by the LoginConfig object. This maintains a list of mechanism names and the mechanisms will be tried in order.

In addition to the built in mechanisms it is possible to add custom authentication mechanisms using the addFirstAuthenticationMechanism() addLastAuthenticationMechanism() and addAuthenticationMechanism() methods.

The first and last versions of this method will both add a mechanism and add it to the LoginConfig object, while the addAuthenticationMechanism() simply registers a factory for the given mechanism name. If you are trying to create a general purpose authentication mechanism via a Servlet extension this is the method you should use, as it means you can install your extension into a server for all deployments, and it will only be active for deployments where the user has specifically selected your mechanism name in web.xml.

Servlet Extensions
Servlet extensions allow you to hook into the Servlet deployment process, and modify aspect of a Servlet deployment. In some ways they are similar to ServletContainerInitializer or ServletContextListener, however they provides much more flexibility over what can be modified.

In order to create a ServletExtension it is necessary to implement io.undertow.servlet.ServletExtension, and then add the name of your implementation class to META-INF/services/io.undertow.servlet.ServletExtension. When Undertow is deploying a Servlet deployment it will load all such services from the deployments class loader, and then invoke their handleDeployment method.

This method is passed an Undertow DeploymentInfo structure, which contains a complete and mutable description of the deployment, by modifying this structure it is possible to change any aspect of the deployment.

The DeploymentInfo structure is the same structure that is used by the embedded API, so in effect a ServletExtension has the same amount of flexibility that you have when using Undertow in embedded mode.

There are many possible use cases for this, a common one would be to add additional authentication mechanisms to a deployment, or to use native Undertow handlers as part of a Servlet deployment.

Examples
The deployment guide contains examples of how to use the DeploymentInfo API.

Using non-blocking handlers with Servlet deployments

Using non-blocking handlers with servlet
When using servlet deployments in Undertow it is possible to mix and match servlets and Undertow native handlers.

This is achieved via the io.undertow.servlet.ServletExtension interface. This interface allows you to customise a servlet deployment before it is deployed, including wrapping the servlet handler chain with your own handlers.

Lets get started. First we need a ServletExtension implementation:

package io.undertow.example.nonblocking;

import io.undertow.Handlers;
import io.undertow.server.HandlerWrapper;
import io.undertow.server.HttpHandler;
import io.undertow.server.handlers.PathHandler;
import io.undertow.servlet.ServletExtension;
import io.undertow.servlet.api.DeploymentInfo;

import javax.servlet.ServletContext;

public class NonBlockingHandlerExtension implements ServletExtension {
    @Override
    public void handleDeployment(final DeploymentInfo deploymentInfo, final ServletContext servletContext) {
        deploymentInfo.addInitialHandlerChainWrapper(new HandlerWrapper() {
            @Override
            public HttpHandler wrap(final HttpHandler handler) {
                return Handlers.path()
                        .addPrefixPath("/", handler)
                        .addPrefixPath("/hello", new HelloWorldHandler());
            }
        });
    }
}
Now we need a handler:

public class HelloWorldHandler implements HttpHandler {
    @Override
    public void handleRequest(final HttpServerExchange exchange) throws Exception {
        exchange.getResponseHeaders().put(Headers.CONTENT_TYPE, "text/plain");
        exchange.getResponseSender().send("Hello World");
    }
}
We now need to register this extension. This uses to standard java service loader mechanism, so we need to create a WEB-INF/classes/META-INF/services/io.undertow.servlet.ServletExtension file that contains the name of our extension class.

Now when you deploy your war to Wildfly you should be able to navigate to /mywar/hello and your custom handler will be invoked.

Lets see exactly what is going on here. When the deployment is about to deploy the handleDeployment method is invoked. This method is passed the io.undertow.servlet.api.DeploymentInfo structure, that contains a complete description of the deployment. One of the things that this contains is a list of handler chain wrappers. These wrappers allow you to add additional handlers before the servlet handler.

In our wrapper we create an io.undertow.server.handlers.PathHandler, which is a handler provided by undertow that maps handlers to paths. We register two different handlers into the path handler, our custom handler under /hello, and the servlet handler under /. These paths are relative to the root of the servlet context (technically they are relative to the last resolved path, so if you chain two path handlers together the second paths will be resolved relative to the first one).

In our handler we simply set a Content-Type header and then send a "Hello World" response via async IO.

A slightly more complex example
Say we are serving up an application, and we decide that we would like to serve all our .js and .css files using an async handler, as we want to avoid the overhead of a servlet request.

To do this we are going to create a handler that checks the extension on the incoming request, and if it is .js or .css then it will serve the file directly, bypassing servlet all together.

This will bypass all servlet handlers, including security handlers, so security rules will not be applied for these handlers.
public class NonBlockingHandlerExtension implements ServletExtension {
    @Override
    public void handleDeployment(final DeploymentInfo deploymentInfo, final ServletContext servletContext) {
        deploymentInfo.addInitialHandlerChainWrapper(new HandlerWrapper() {
            @Override
            public HttpHandler wrap(final HttpHandler handler) {

                final ResourceHandler resourceHandler = new ResourceHandler()
                        .setResourceManager(deploymentInfo.getResourceManager());

                PredicateHandler predicateHandler = new PredicateHandler(Predicates.suffixs(".css", ".js"), resourceHandler, handler);

                return predicateHandler;
            }
        });
    }
}
Lets go through this line by line:

final ResourceHandler resourceHandler = new ResourceHandler()
    .setResourceManager(deploymentInfo.getResourceManager());
A resource handler is a handler provided by Undertow that serves resources from a resource manager. This is basically just an abstraction that allows us to re-use the file serving code no matter where a file in coming from. For example undertow provides several default resource manager implementations:

io.undertow.server.handlers.resource.FileResourceManager
A resource manager that serves files from the file system

io.undertow.server.handlers.resource.ClassPathResourceManager
A resource manager that serves files from the class path

io.undertow.server.handlers.resource.CachingResourceManager
A resource manger that wraps another resource manger, and provides caching.

You do not need to worry about what type of resource manager is in use here, all you need to know is that this is the resource manager that is being used by the default servlet, so serving files from this resource manager will mirror the behaviour of the default servlet.

We now need to wire up our resource handler so it is only used for .js and .css. We could simply write a handler that checks the file extension and delegates accordingly, however Undertow already provides us with one:

PredicateHandler predicateHandler = new PredicateHandler(Predicates.suffixs(".css", ".js"), resourceHandler, handler);
A PredicateHandler chooses between two different handlers based on the result of a predicate that is applied to the exchange. In this case we are using a suffix predicate, that will return true if the request ends with .js or .css.

When this predicate returns true our resource handler will be invoked, otherwise the request will be delegated to the servlet container as normal.

Servlet Security
As well as support for the standard servlet spec required authentication mechanisms, Undertow also allows you to create your own mechanisms, and provides an easy way to make the accessible to an end user.

Securing a Servlet Deployment
Undertow provides full support for all security constructs specified in the Servlet specification. These are configured via the DeploymentInfo structure, and in general closely mirror the corresponding structures as defined by annotations or web.xml. These structures are not detailed fully here, but are covered by the relevant javadoc.

If you are using Wildfly then then it is possible to configure multiple mechanisms using web.xml, by listing the mechanism names separated by commas. It is also possible to set mechanism properties using a query string like syntax.

For example:

<auth-method>BASIC?silent=true,FORM</auth-method>
The mechanisms will be tried in the order that they are listed. In the example silent basic auth will be tried first, which is basic auth that only takes effect if an Authorization header is present. If no such header is present then form auth will be used instead. This will allow programmatic clients to use basic auth, while users connecting via a browser can use form based auth.

The built it list of mechanisms and the properties they take are as follows:

Mechanism Name	Options	Notes	
BASIC

silent (true/false), charset, user-agent-charsets

silent mode means that a challenge will only be issued if an Authorization header with invalid credentials is present. If this header is not present this auth method will never be used. charset specifies the default charset to use for decoding usernames and passwords. user-agent-charsets is a comma seperated list of the form pattern,charset,pattern,charset,... that allows you to change the charset used for decoding based on the browser user agent string. If the regex matches the requests user agent then the specified charset will be used instead.

FORM

CLIENT-CERT

DIGEST

EXTERNAL

Used when authentication is being done by a front end such as httpd

Selecting an Authentication Mechanism
The authentication mechanism is specified via the io.undertow.servlet.api.LoginConfig object that can be added using the method DeploymentInfo.setLoginConfig(LoginConfig config). This object contains an ordered list of mechanism names. The Servlet specification only allows you to specify a single mechanism name, while Undertow allows as many as you want (if you are using Wildfly you can make use of this by using a comma separated list of names in web.xml, and pass properties using a query string like syntax, for example BASIC?silent=true,FORM).

The mechanisms are standard Undertow AuthenticationMechanism implementations, and it should be noted that not all mechanisms are compatible. For example trying to combine FORM and BASIC does not work, just because they both require a different response code. Combining FORM and silent BASIC will work just fine however (silent basic auth means that if the user agent provides an Authorization: header then BASIC auth will be used, however if this header is not present then no action will be taken. This allows scripts to use basic auth, while browsers can use form).

When adding the mechanism name to the LoginConfig structure it is also possible to specify a property map. Custom authentication mechanisms may use these properties however they wish. The only built in mechanism that makes use of this mechanism is basic auth, which if passed Collections.singletonMap("silent", "true") will enable silent mode as described above.

The built in mechanisms are FORM, DIGEST, CLIENT_CERT and BASIC.

Adding a Custom Authentication Mechanism
Custom authentication mechanisms are added using the Undertow ServletExtension mechanism. This provides a way to hook into the Undertow deployment process, and add any additional mechanisms.

These extensions are discovered via the standard META-INF/services discovery mechanism, so if you have a jar that provides a custom authentication mechanism all that should be required is to add this jar to your deployment and then specify the mechanism name in web.xml.

For more info see the Servlet extensions guide.

Advanced Servlet Use Cases
As well as allowing you to add all the standard Servlet constructs that you would expect (such as Servlets, Filters etc), Undertow also allows you to customise your deployment in a number of ways. This section details these additional options.

This section does not cover all the different options available in the DeploymentInfo structure. For a complete reference please refer to the javadoc.
Inserting Custom Handlers into the Servlet Handler Chain
It is possible to insert customer handlers into various parts of the servlet handler chain. This is done by adding a io.undertow.server.HandlerWrapper to the DeploymentInfo structure. This will be called at deployment time and allows you to wrap the existing handler.

There are three possible places where a handler can be inserted:

Before the Servlet Chain
This happens before any Servlet handlers are invoked, and handlers inserted here have the option of completely bypassing Servlet altogether. Some possible use cases include serving static files directly without any Servlet overhead, or performing some kind of request re-writing before Servlet is invoked. To add a wrapper here use DeploymentInfo.addInitialHandlerChainWrapper(HandlerWrapper wrapper).

After the Servlet Initial Handler
This happens after the initial Servlet handler is invoked. The request has been dispatched to a worker thread, request and response objects have been created, the target servlet has been resolved and all relevant info has been attached to the exchange as part of the ServletRequestContext. No security handlers have been invoked at this stage. To add a wrapper here use DeploymentInfo.addOuterHandlerChainWrapper(HandlerWrapper wrapper).

After the Security Initial Handlers
This happens after the Security handlers have been invoked, before the request is dispatched to the first Filter or Servlet.

To add a wrapper here use DeploymentInfo.addInnerHandlerChainWrapper(HandlerWrapper wrapper).

Thread Setup Actions
Thread setup actions allow you to perform tasks before and after control is dispatched to user code. The most common use for this is to set up thread local contexts. For example a server might want to setup the appropriate JNDI contexts before control is passed to user code, so make sure the code has access to the correct java:comp context.

Thread setup actions can be added using DeploymentInfo.addThreadSetupAction(ThreadSetupAction action).

Ignore Flush
In Servlet code it is common to see code that looks like this:

public class SomeServlet extends HttpServlet {

    @Override
    protected void doGet(final HttpServletRequest req, final HttpServletResponse resp) throws ServletException, IOException {
            OutputStream stream = resp.getOutputStream();

            //do stuff

            stream.flush();
            stream.close();
        }
    }
}
While this seems reasonable at first glace it is actually terrible from a performance point of view. The flush() call before the close() call forces content to be written to the client, which will generally force chunked encoding. The following close() call then writes out the chunk terminator, resulting in another write to the socket. This means that a response that could otherwise have been written out using a single write call using a fixed content length now takes two and uses chunked encoding.

To work around this poor practice Undertow provides an option to ignore flushes on the ServletOutputStream. This can be activated by calling DeploymentInfo.setIgnoreFlush(true). Even though flush() will no longer flush to the client when this is enabled Undertow will still treat the response as committed and not allow modification of the headers.

JSP
JSP can be used in Undertow through the use of the Jastow project, which is a fork of Apache Jasper for use in Undertow (note that fork is used very loosely here, it is basically just Jasper with its Tomcat dependencies removed).

Jasper provides all its functionality though a Servlet, as a result can be added to a standard Undertow servlet deployment by adding the JSP servlet to the *.jsp mapping.

There are also some additional context parameters that JSP requires, and Jastow provides a helper class to set these up.

An example of how to set up a JSP deployment is shown below:

final PathHandler servletPath = new PathHandler();
final ServletContainer container = ServletContainer.Factory.newInstance();

DeploymentInfo builder = new DeploymentInfo()
        .setClassLoader(SimpleJspTestCase.class.getClassLoader())
        .setContextPath("/servletContext")
        .setClassIntrospecter(TestClassIntrospector.INSTANCE)
        .setDeploymentName("servletContext.war")
        .setResourceManager(new TestResourceLoader(SimpleJspTestCase.class))
        .addServlet(JspServletBuilder.createServlet("Default Jsp Servlet", "*.jsp"));
JspServletBuilder.setupDeployment(builder, new HashMap<String, JspPropertyGroup>(), new HashMap<String, TagLibraryInfo>(), new MyInstanceManager());

DeploymentManager manager = container.addDeployment(builder);
manager.deploy();
servletPath.addPrefixPath(builder.getContextPath(), manager.start());
Note that JSP tags are created using an instance of the Jasper InstanceManager interface. If you do not require injection into tags then this interface can simply create a new instance using reflection.

Undertow.js
Undertow.js
Undertow.js is a standalone project that makes it easy to write server side Javascript with Undertow. It supports the following:

Java EE integration, including dependency injection

REST

Templates

Declarative security

Filters

Websockets

Hot reload

JDBC

The functionality is intended to be used as part of a Servlet deployment. It is designed to make it easy to mix Javascript and Java EE backend functionality, allowing you to quickly create a front end in Javascript while still using Java EE for all the heavy lifting.

An overview of the functionality can be found at http://wildfly.org/news/2015/08/10/Javascript-Support-In-Wildfly/. Some simple examples can be found at https://github.com/stuartwdouglas/undertow.js-examples.

Getting Started
First you need to include the latest Undertow.js in your application. If you are using Wildfly 10 this is not necessary, as Wildfly 10 provides this functionality out of the box. If you are using maven you can include the following in your pom.xml :

<dependency>
        <groupId>io.undertow.js</groupId>
        <artifactId>undertow-js</artifactId>
        <version>1.0.0.Alpha3</version>
</dependency>
Otherwise you can download the jars from link:http://mvnrepository.com/artifact/io.undertow.js/undertow-js .

Once you have Undertow.js you need to tell it where to find your javascript files. To do this we create a file WEB-INF/undertow-scripts.conf. In this file you list your server side JavaScript files, one per line. These files will be executed in the order specified.

Note that even though the server JavaScript files are located in the web context, the JavaScript integration will not allow them to be served. If a user requests a server side JS file a 404 will be returned instead.

We can now create a simple endpoint. Create a javascript file, add it to undertow-scripts.conf and add the following contents:

$undertow
    .onGet("/hello",
        {headers: {"content-type": "text/plain"}},
        [function ($exchange) {
            return "Hello World";
        }])
Accessing the /hello path inside your deployment should now return a Hello World response. Note that this path is relative to the context root, so if your deployment is example.war and your server is running on port 8080 the handler will be installed at http://localhost:8080/example/hello.

Basic concepts
The $undertow global provides the main functionality of an Undertow.js application. When your scripts are executed they invoke methods on this object to register HTTP and Websocket handlers. Incoming requests for the application will be checked against these handlers, and if they match the relevant javascript will be run to handle the request. If there is no matches the request is forwarded to the Servlet container as normal.

If a file is modified and hot deployment is enabled the Nashorn engine is discarded, a new engine is created and all scripts are executed again to re-set up the handlers.

HTTP Endpoints
To register a handler for a HTTP endpoint you can use one of the following methods

onGet

onPost

onPut

onDelete

onRequest

onRequest takes the method name as a first parameter, otherwise its usage is the same as the others. These methods can accept a variable number of parameters.

Note that all methods on $undertow are fluent, they return the same object so they can be chained together.

There are a number of different forms that can be used to invoke these methods, they are all covered below.

$undertow.onGet("/path", function($exchange) {...})
$undertow.onRequest("GET", "/path", function($exchange) {...})

$undertow.onGet("/path", [function($exchange) {...}])
$undertow.onRequest("GET", "/path", [function($exchange) {...}])
This is the simplest usage, which consists of a path and a handler function to register under this path. Both the usages shown above are identical. Future examples will not show the onRequest version, as with the exception of the method name it is identical.

$undertow.onGet("/path", ['cdi:myBean', function($exchange, myBean) {...}])
The example above shows the use of dependency injection. If a list is passed as the last argument instead of a function then it is assumed to be a dependency injection list. It should consist of dependency names, followed by the handler function as the last element in the list. When the handler is invoked these items will be resolved, and passed into the method as parameters. The process is covered in more detail later.

$undertow.onGet("/path/{name}", function($exchange) {...})
This example shoes the use a of path template instead of a hard coded path. The path parameter name can be accessed using the syntax $exchange.params('name').

$undertow.onGet("/path", {headers={'Content-Type': 'text/plain'}}, function($exchange) {...})
This usage includes an extra parameter, the metadata map. The usage of this is covered in more detail in the relevant sections, however the allowed values in this map are as follows:

template
A template that should be applied using the data that is returned from the handler function.

template_type
The template engine that should be used to render the template.

headers
A map of response headers to add to the response.

predicate
An Undertow predicate string that determines if this handler should actually be executed.

roles_allowed
A list of roles that are allowed to access this handler. This uses the security configuration of the servlet deployment.

It is possible to set default values for all of these values using the $undertow.setDefault() method. For example to set a content type header for all handlers you would do $undertow.setDefault('headers', {'Content-Type': application/json}). These defaults only take effect if the corresponding metadata item is not set on the handler.

Handler functions can return a value. How this value is interpreted depends on the handler and what is returned. If the template parameter is specified in the metadata map then this return value is used as the data object for the template. Otherwise if the return value is a string it is sent to the client as the entity body, otherwise the return value will be converted into JSON using JSON.stringify() and the resulting JSON sent to the client.

The exchange object
The first parameter of any handler is the exchange object. This object is a wrapper around the Undertow HttpServerExchange, that makes it easier to use if from within Javascript. If you want to access the actual underlying object for whatever reason you can do so with the $underlying property (this applies to all wrapper objects used by Undertow.js, if the wrapper does not meet your needs you can get the underlying java object and invoke it directly).

The exchange object provides the following methods:

$exchange.requestHeaders('User-Agent');             //gets the user agent request header
$exchange.requestHeaders('User-Agent', 'foo 1.0');  //sets the user agent request header
$exchange.requestHeaders();                         //get the request headers map

$exchange.responseHeaders('Content-Length');        //gets the content-length response header
$exchange.responseHeaders('Content-Length', '100'); //sets the content length response header
$exchange.responseHeaders();                        //gets the response header map

$exchange.send("data");                             //sends the given string as the response body, and ends the exchange when done
$exchange.send(404, "not found");                   //sets the given response code, and sends the response body, ending the exchange when done

$exchange.redirect("http://www.example.org/index.php"); //redirects to the given location

$exchange.status();                                 //returns the current status code
$exchange.status(404);                              //sets the current status code

$exchange.endExchange();                            //ends the current exchange

$exchange.param("name");                            //gets the first query or path parameter with the specified name

$exchange.params("names");                          //gets a list of the query or path parameters with the specified name

$exchange.session();                                //returns the servlet HTTPSession object
$exchange.request();                                //returns the servlet request object
$exchange.response();                               //returns the servlet response object
Injection
As shown above Undertow.js supports injection into handler functions. To perform an injection pass the name of the injection in a list with the handler function, as shown below:

$undertow.onGet("/path", ['$entity:json', function($exchange, entity) {...}])
The injection mechanism is pluggable, and in general injections follow the form type:name. The following injection types are supported out of the box:

$entity
This allows you to inject the request body. It supports the types string, json and form. $entity:string will inject the entity as a string, $entity:json will parse the entity as JSON and deliver it as a JavaScript object, and $entity:form will inject form encoded (or multipart) data.

jndi
This will inject whatever object is at the specified JNDI location. For example jndi:java:jboss/datasources/ExampleDS will inject the Wildfly default datasource (actually it will inject a javascript wrapper of the datasource, more on that later).

cdi
This will inject a @Named CDI bean with the given name.

It is possible to create aliases for commonly used injections. You can do this by calling the $undertow.alias() function, for example:

$undertow.alias("ds", "jndi:java:jboss/datasources/ExampleDS");
Note that aliases can not have a type specifier.

Note that this injection support is pluggable, and can be extended by implementing io.undertow.js.InjectionProvider, and adding the implementing class to META-INF/services/io.undertow.js.InjectionProvider.

Wrapper Objects and JDBC
When injecting JDBC data sources Undertow does not inject the actual datasource, but a JavaScript wrapper object. To get the underlying data source you can refer to the wrappers $underlying property.

The wrapper object has the following methods:

ds.query("UPDATE ...");             //executes a query, and returns the number of rows affected
ds.select("SELECT * from ...");     //executes a select query, and returns an array of maps as the result
ds.selectOne("SELECT * from ...");  //executes a select query, and a single map as the result
Note that this wrapper mechanism is pluggable, and can be extended by adding a function to the $undertow.injection_wrappers array. This function takes the original object and returns the wrapped result.

Wrappers (Filters)
It is possible to register wrappers, which act similarly to a Servlet Filter. These can intercept requests before they reach a handler, allowing you to apply cross cutting logic such as transactions or logging. Note that these wrappers only apply to javascript handlers, if a request is not targeted at a handler they will not be invoked.

To register a wrapper you call the $undertow.wrapper() function as follows:

$undertow.wrapper("path-suffix['.html']", ["cdi:myBean",function($exchange, $next, myBean) {
        //do stuff
        $next();
    }])
The first optional parameter is an Undertow predicate string, that controls when the wrapper will be invoked (in this case for all .html files). The next argument is an injection list. This works in a similar way to handlers, however this function takes two parameters in addition to any injected one. The $next parameter is a function that should be invoked to invoke the next wrapper or handler in the chain.

Templates
It is possible to use template engines to do server side rendering. This mechanism is pluggable, out of the box the mustache and freemarker template engines are supported, with mustache being the default. This is controlled by the template_type entry in the metadata map, and the default can be changed by calling $undertow.setDefault('template_type', 'freemarker');.

To use a template all that is requires is to specify the template name in the metadata map when registering a handler, and then return the data object that you wish to use to render the template:

$undertow.onGet("/template", {template: test.html}, function($exchange) {
    return {message: "Hello World"};
}
After the handler function has been installed, the template is rendered with the provided data and sent to the client.

The template mechanism is pluggable, new engines can be added by implementing io.undertow.js.templates.TemplateProvider and adding the implementation class to META-INF/services/io.undertow.js.templates.TemplateProvider.

Security
It is possible to use declarative security by specifying the allowed roles in the metadata map as an array under roles_allowed. The security settings of the Servlet application are used to authenticate the user and perform the check

The special role ** refers to any authenticated user.

An example is shown below:

$undertow.onGet("/path", {roles_allowed: ['admin', 'user']}, function($exchange) { });
WebSockets
To register a WebSocket endpoint you can invoke the $undertow.websocket() method as follows:

$undertow.websocket("/path", function(connection) { });
This connection object is a wrapper around an Undertow WebSocketConnection. It supports the following methods and properties:

con.send(data);                     //sends a websocket message
con.onText = function(data){};      //set the onText handler function
con.onBinary = function(data){};    //sets the onBinary handler function
con.onClose = function(message){};  //sets the close message handler function
con.onError = function(error){};    //sets the error handing function
The behaviour of the send() function varies depending on the argument. If a string is passed in the string is sent as a text message. If an ArrayBuffer is passed in the data will be sent as a binary message. Otherwise the object will be converted into JSON and the result sent to the client as a text message.

The onText callback will deliver its message as a string, and the onBinary method will deliver it as a Javascript ArrayBuffer. If these callbacks return a value it will be sent to the client using send() (so the same conversion rules apply).

It is currently not possible to inject into Websocket Endpoint methods. This will be fixed shortly.
Some notes on thread safety
Note that you should never store global or shared state in Javascript objects, as Nashhorn does not support this sort of multi threaded access. If you need to share data between threads you should use a properly synchronised Java object (such as an EJB singleton) and inject this object into your handler.

FAQ
Undertow FAQ
Here is a list of frequently asked questions.

Why does the world need another web server?
Before we created Undertow we needed multiple web server technologies to meet our needs. Undertow was designed to be flexible and efficient enough to meet every use case we had and every use case we could think of. Undertow is embeddable and easy to use, but is also well suited for application servers. It has great performance, but also rich enterprise Java capabilities. It has efficient non-blocking reactive APIs, but also more familiar traditional blocking APIs. It has new innovative APIs, but also standard APIs. It can run large dynamic applications, but is also lightweight enough to replace a native web server.

What JDK does Undertow require?
Undertow 1.4 and earlier require Java 7 or later.

Undertow 2.0 and later require Java 8 or later.

Why am I only seeing one request being processed at a time?
Some browsers share connections between tabs, so even if you have opened another tab the second tab will not load until the first tab has completed.

When will Undertow be included in JBoss EAP?
Undertow is currently planned for EAP7, which will be based on a future WildFly release. It can be used today on its own or within WindFly 8.

What license is Undertow under?
Undertow is licensed under the Apache License, Version 2.0.

How do I build Undertow?
git clone git://github.com/undertow-io/undertow.git

cd undertow

mvn install

How do I get started?
A good starting point is taking a look at our examples.

Where can I get help?
A number of the developers and users hang out on IRC at #undertow on irc.freenode.org. We also have a mailing list you can subscribe to. Finally, if you are using Undertow in WildFly you can use the general WildFly project forum as well.

Why isn’t Undertow based on Mina, Netty, RNIO, Grizzly, or <insert network framework>?
In order to best achieve its goals, Undertow requires very close integration with the underlying I/O infrastructure in the Java platform. The simplicity offered by any abstraction comes from hiding the underlying mechanisms behind it. However, the dilemma is that building an extremely efficient and flexible web server requires customization and control of these mechanisms. Undertow attempts to strike the right balance by reusing a minimalistic I/O library, XNIO, that was created for WildFly’s remote invocation layer.

XNIO allows us to eliminate some boiler plate, and also allows for direct I/O integration with the operating system, but it does not go further than that. In addition, XNIO offers very strong backwards compatibility which is important since this is also a concern for the Undertow project. Of course, other projects may have different needs, and thus might make different choices.

Last updated 2019-06-24 15:11:30 BRT