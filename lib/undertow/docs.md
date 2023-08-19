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

### Maven

Undertow是使用`Maven`构建的，并已同步到`Maven Central`。Undertow提供了三个独立的`artifacts`：

- **Core**
Undertow核心代码，为非阻塞处理器和Web socket提供支持

- **Servlet**
支持Servlet 4.0

- **Websockets JSR**
支持`Websockets(JSR-356)`的Java API标准


为了能在你的`Maven`项目中使用Undertow，你需要在`pom.xml`中加入以下部分，并将`undertow.version`属性设置为你要使用的Undertow版本。其中`undertow-core`是必需的`artifact`，如果你不使用`Servlet`或`JSR-356`，那么不需要引入另外两个`artifact`。

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

### 直接下载

你也可以直接从`Maven`仓库下载Undertow。

Undertow依赖`XNIO`和`JBoss Logging`，它们也需要一起下载。

### 自己构建

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

`HTTP`，`HTTPS`和`AJP`监听器的代码如下所示：

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

处理器们一般通过在构造时显式指定下一个处理器的方式链接在一起，其中并没有流水线的概念，这意味着处理器可以根据当前请求选择下一个处理器调用。一个典型的处理器可能看起来像这样：

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

监听器代表Undertow应用程序的入口点。所有传入的请求都将通过监听器来进行，并且监听器负责将请求转换为`HttpServerExchange`类的实例，然后将结果转换为可以发送回客户端的响应。

Undertow提供了3种内置的监听器类型，即`HTTP/1.1`，`AJP`和`HTTP/2`。通过使用`HTTP`监听器以及启用`SSL`的连接可以提供`HTTPS`。

Undertow还支持代理协议的version 1，你可以通过监听器的构建器将`useProxyProtocol`属性设置为`true`与上面三种监听器类型组合。

### Options

你可以通过`org.xnio.Option`类来配置Undertow监听器。XNIO的通用选项例如控制连接和worker级别行为在`org.xnio.Options`类中列出，而Underwow的特定选项例如控制连接器级别行为则在`io.undertow.UndertowOptions`中列出。

### XNIO workers

所有监听器都将绑定到某个`XNIO Worker`实例上。通常，只有一个工作器（`XNIO Worker`）实例在监听器之间共享，但是也可以为每个监听器创建一个新的工作器。

工作器实例管理监听器的IO线程以及默认的阻塞任务线程池。有几个主要的`XNIO Wroker`选项会影响监听器的行为。这些选项要么通过Undertow构建器指定为worker选项，要么在`XNIO Worker`创建时指定（如果要手动引导服务器）。这些选项全部位于`org.xnio.Options`类上。

#### WORKER_IO_THREADS

要创建的IO线程数。IO线程执行非阻塞任务，并且永远不会执行阻塞操作，因为它们负责多个连接，因此如果进行阻塞操作那么其他连接实质上将挂起。每个CPU核心两个IO线程是一个合理的默认设置。

#### WORKER_TASK_CORE_THREADS

工作器阻塞任务线程池的线程数。当执行诸如`Servlet`请求之类的阻塞操作时，将使用该线程池中的线程。通常，很难为此设置一个合理的默认值，因为它取决于服务器的工作负载。通常，它应该在合理范围内较高，每个CPU核心大约10个。

### Buffer Pool

所有监听器都有一个缓冲池，用于分配池化的`NIO ByteBuffer`实例。这些缓冲区用于IO操作，缓冲区大小对应用程序性能有很大影响。对于服务器，理想大小通常为16k，因为这通常是可以通过`write()`操作写出的最大数据量（取决于操作系统的网络设置）。较小的系统可能希望使用较小的缓冲区来节省内存。

在某些情况下例如阻塞IO，缓冲区大小将决定是使用分块编码发送响应还是通过固定的内容长度发送响应。如果响应大小完全适合缓冲区并且`flush()`方法未被调用，那么内容长度会被自动设置。

### Common Listener Options

除了工作器选项之外，监听器还采用其他一些选项来控制服务器的行为。这些选项都是`io.undertow.UndertowOptions`类的一部分，其中一些仅对特定协议有意义。你可以使用`Undertow.Builder.setServerOption`来设置以下选项：

#### MAX_HEADER_SIZE

HTTP头部块的最大大小，以字节为单位。如果客户端发送更多数据作为请求头的一部分，那么连接将关闭。默认为50k。

#### MAX_ENTITY_SIZE

请求实体的默认最大大小。如果实体的主体（`body`）大小大于此限制，那么在读取请求时（对于固定长度请求第一次读取，对于分块请求读取的数据太多）将在某个点抛出`java.io.IOException`异常 。该值仅是默认大小，处理器可以调用`io.undertow.server.HttpServerExchange.setMaxEntitySize(long size)`方法为某个请求覆盖此值。默认值为无限制。

#### MULTIPART_MAX_ENTITY_SIZE

使用`Multipart`解析器时的默认最大实体大小。通常大于`MAX_ENTITY_SIZE`。为了能够上传大文件对此有一个单独的设置，同时可以限制其他类型请求的大小。

#### MAX_PARAMETERS

一个请求中允许的最大查询参数数量。如果客户端发送的参数数量超过此限制，那么连接将关闭。这个限制是必需的，它可以防止基于散列的拒绝服务攻击。默认值为1000。

#### MAX_HEADERS

一个请求中允许的最大标头（`header`）数。如果客户端发送的数量超过此限制，那么连接将关闭。这个限制是必需的，它可以防止基于散列的拒绝服务攻击。默认为200。

#### MAX_COOKIES

一个请求中允许Cookie的最大数量。如果客户端发送的数量超过此限制，那么连接将关闭。这个限制是必需的，它可以防止基于散列的拒绝服务攻击。默认为200。

#### URL_CHARSET

用于解码URL和查询参数的字符集。默认为UTF-8。

#### DECODE_URL

决定监听器是否解码URL和查询参数，还是直接将其传递给处理器链。如果这个选项设置为`true`，那么监听器会将url编码的字符解码为`URL_CHARSET`中指定的字符集。默认为true。

#### ALLOW_ENCODED_SLASH

如果一个请求带有编码的`/`字符（例如`％2F`），这些字符将被解码。如果前端代理未执行相同的解码，则可能会导致[安全问题](http://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2007-0450)，因此默认情况下禁用此功能。

#### ALLOW_EQUALS_IN_COOKIE_VALUE

如果为`true`，那么Undertow将允许在未加引号的cookie值中包含未转义的`=`字符。未加引号的cookie值事实上不能包含`=`字符，如果存在`=`字符，那么cookie值将在`=`之前结束，cookie值的剩余部分将被丢弃。默认为false。

#### ALWAYS_SET_DATE

服务器是否应将`HTTP Date`标头添加到所有没有此标头的HTTP回复中。如果处理器之前未设置此标头，那么服务器将在写入回复之前立即设置标头。不同于`DateHandler`，它不会覆盖标头。当前日期字符串将被缓存，并每秒更新一次。默认为true。

#### ALWAYS_SET_KEEP_ALIVE

`HTTP Connection: keep-alive`标头是否应该始终设置，即使对于默认情况下已经持久化的`HTTP/1.1`请求。虽然规范没有要求始终发送此标头，但始终发送它似乎更安全。如果你正在编写某种超高性能应用程序，并且担心会发送额外数据，那么可以将关闭此选项。默认为`true`。

#### MAX_BUFFERED_REQUEST_SIZE

可以保存的最大请求大小（以字节为单位）。在某些情况下会缓冲请求，最常见的情况为SSL重新协商并且使用基于`FORM`的身份验证时保存`post`数据。默认为16,384字节。

#### RECORD_REQUEST_START_TIME

服务器是否应记录HTTP请求的开始时间。如果你希望记录或以其他方式使用总请求时间，那么这是必需的，但是这会对性能产生一点影响，因为这意味着每个请求都需要调用`System.nanoTime()`方法。默认为`false`。

#### IDLE_TIMEOUT

连接超时之前可以空闲的时间。空闲连接是指在空闲超时期间内没有数据传输的连接。请注意，这是一个粗粒度的方法，如果设置了较小的值，那么可能会导致处理时间较长的请求出现问题。

#### REQUEST_PARSE_TIMEOUT

在超时之前，请求可以在解析阶段花费多长时间。当读取请求的第一个字节时，此计时器启动，并在解析完所有标头后结束。

#### NO_REQUEST_TIMEOUT

在服务器关闭连接之前，连接可以闲置而不处理请求的时间。

#### ENABLE_CONNECTOR_STATISTICS

如果为`true`，那么连接器将记录统计信息，例如已处理的请求以及已发送/已接收的字节。这会影响性能，虽然在大多数情况下不会引起注意。

### ALPN

```java
io.undertow.server.protocol.http.AlpnOpenListener
```

通过SSL运行时，`HTTP/2`连接器要求使用`ALPN`。

从Java 9开始，JDK内部支持`ALPN`，但是在之前版本的JDK上，需要使用其他方法。

如果你使用的是`OpenJDK / Oracle JDK`，那么Undertow提供了一种开箱即用`ALPN`的方法。

或者，你可以使用`Wildfly OpenSSL`项目来提供`ALPN`，其性能也比`JDK SSL`实现更好。

另一个选择是使用`Jetty ALPN`，但是并不推荐这个方法，因为它不再作为Undertow测试套件的一部分进行测试。有关更多信息，请参阅[Jetty ALPN文档](http://www.eclipse.org/jetty/documentation/current/alpn-chapter.html)。

### HTTP Listener

```java
io.undertow.server.protocol.http.HttpOpenListener
```

HTTP监听器是最常用的监听器类型，可以处理`HTTP/1.0`和`HTTP/1.1`。它仅需要一个附加选项：

#### ENABLE_HTTP2

如果为`true`，则可以将该连接作为`HTTP/2` prior knowledge连接进行处理。如果`HTTP/2`客户端使用`HTTP/2`连接前言直接连接到监听器，那么将使用`HTTP/2`协议代替`HTTP/1.1`。

### AJP Listener

```java
io.undertow.server.protocol.ajp.AjpOpenListener
```

`AJP`监听器允许使用`AJP`协议，如Apache的`mod_jk`和`mod_proxy_ajp`模块所使用的那样。它是一种二进制协议，比HTTP协议更有效，因为某些通用字符串已被整数替换。如果前端负载均衡器支持`HTTP2`，则建议改用`HTTP2`，因为它既是标准协议，同时效率更高。

该监听器有一个特定选项：

#### MAX_AJP_PACKET_SIZE

控制`AJP`数据包的最大大小。此设置在负载均衡器和后端服务器上必须匹配。

### HTTP2 Listener

`HTTP/2`支持是在`HTTP/1.1`之上实现的（不可能有不支持`HTTP/1`的`HTTP/2`服务器）。可以通过三种不同方式建立`HTTP/2`连接：

#### ALPN

这是最常见的方式（也是许多浏览器当前支持的唯一方式）。它需要`HTTPS`，并使用应用层协议`negotiation SSL extension`来协商将使用`HTTP/2`的连接。

#### Prior Knowledge

客户端仅发送`HTTP/2`连接前言并假定服务器支持它。在开放的Internet上通常不使用此功能，但是当你知道后端服务器支持`HTTP/2`时，它对于负载均衡器之类的功能很有用。

#### HTTP

客户端在初始请求中发送`Upgrade: h2c`标头。如果服务器接受升级，那么将启动`HTTP/2`连接，并使用`HTTP/2`将响应发送回初始请求。

根据使用`HTTP/2`的方式，监听器的设置略有不同。

如果你使用的是Undertow构建器，则只需调用`setServerOption(ENABLE_HTTP2, true)`方法，此时会自动为所有`HTTP`和`HTTPS`监听器添加`HTTP/2`支持。

如果你正在使用JDK8，那么Undertow将使用`ALPN`基于反射的实现，这个实现应与`OpenJDK / Oracle JDK`一起使用。如果你正在使用`JDK9+`，那么Undertow将使用JDK提供的`ALPN`实现。

查看[HTTP2简介](https://developers.google.com/web/fundamentals/performance/http2?hl=zh-cn)以获取HTTP2的基础知识。

支持以下选项：

#### HTTP2_SETTINGS_HEADER_TABLE_SIZE

用于首部压缩的标头表（`header table`）大小。增大此值将为每个连接使用更多的内存，但可能会减少通过有线网络发送的数据量。默认为4096。

#### HTTP2_SETTINGS_ENABLE_PUSH

是否为此连接启用服务器推送。

#### HTTP2_SETTINGS_MAX_CONCURRENT_STREAMS

允许客户端在任何一次打开流的最大数量。

#### HTTP2_SETTINGS_INITIAL_WINDOW_SIZE

初始流量控制窗口的大小。

#### HTTP2_SETTINGS_MAX_FRAME_SIZE

最大帧大小。

#### HTTP2_SETTINGS_MAX_HEADER_LIST_SIZE

服务器准备接受的标头的最大大小。

## Built in Handlers

Undertow包含许多提供通用功能的内置处理器。这些处理器中的大多数都可以使用`io.undertow.Handlers`工具类上的静态方法来创建。

> 下面的内容是对Undertow内建的处理器进行一些介绍，如果对它们的具体实现较为感兴趣，请查阅位于`io.undertow.server.handlers`包下的相关源码。

最常见的处理器的详细信息如下：

### Path

路径匹配处理器允许你根据请求路径将请求委托给其他处理器。它可以在精确路径上匹配，也可以在路径前缀上匹配，并将根据所选路径更新`HttpServerExchange`的相对路径。首先会根据完全匹配检查路径，如果匹配失败，则通过最长前缀匹配进行检查。

### Virtual Host

虚拟主机处理器会根据`Host:`标头的内容将请求委派给其他处理器，从而使你可以选择其他处理器链来处理不同的主机。

### Path Template

与路径处理器类似，但是路径模板处理器允许你在路径中使用URI模板表达式，例如`/rest/{name}`。相关路径模板项的值将作为附件存储在`HttpServerExchange`上的`io.undertow.util.PathTemplateMatch#ATTACHMENT_KEY` attachment key下。

### Resource

资源处理器用于提供静态资源，例如文件。该处理器采用一个`ResourceManager`实例，这个实例基本上是一个文件系统抽象。Undertow提供了基于文件系统和类路径的资源管理器，以及一个缓存资源管理器，缓存资源管理器包装了一个现有的资源管理器以提供内存缓存支持。

### Predicate

谓词（`Predicate`）处理器根据针对`HttpServerExchange`解析的谓词值在两个可能的处理器之间进行选择。有关更多信息，请参见[谓词指南](https://undertow.io/undertow-docs/undertow-docs-2.1.0/predicates-attributes-handlers.html)。

### HTTP Continue

有多个处理器可以处理期望`HTTP 100 Continue`响应的请求。HTTP继续读取（`HTTP Continue Read`）处理器将在处理器首次尝试读取请求正文时自动向需要的请求发送继续响应。HTTP继续接受处理器将立即根据谓词的值发送100或417响应。如果没有提供谓词，那么立即接受所有请求。如果发送了417响应代码，则不会调用下一个处理器，并且该请求将变为非持久性。

### Websocket

处理传入的`WebSocket`连接的处理器。有关详细信息，请参见[websockets指南](https://undertow.io/undertow-docs/undertow-docs-2.1.0/websockets.html)。

### Redirect

重定向到指定位置的处理器。

### Trace

处理`HTTP TRACE`请求的处理器，由`HTTP RFC`指定。

### Header

设置响应头的处理器。

### IP Access Control

根据远程对等方的IP地址允许或拒绝请求的处理器。

### ACL

根据访问控制列表允许或拒绝请求的处理器。`HttpServerExchange`的任何属性都可以用作此比较的基础。

### URL Decoding

将URL和查询参数解码为指定字符集的处理器。不同的URL资源可能需要不同的字符集，在这种情况下，可以将Undertow监听器设置为不解码URL，而是在处理器链中的某个适当位置使用此处理器的多个实例进行解码。例如，这可以允许你让不同的虚拟主机使用不同的URL编码。

### Set Attribute

设置`HttpServerExchange`上的任意属性。属性和值都被指定为`HttpServerExchange`属性，因此该处理器实际上可以用于修改`HttpServerExchange`的任何部分。有关更多信息，请参见[exchange attributes](https://undertow.io/undertow-docs/undertow-docs-2.1.0/predicates-attributes-handlers.html)。

### Rewrite

提供URL重写支持的处理器。

### Graceful Shutdown

返回一个处理器，这个处理器可用于确保在关闭服务器之前完成所有正在运行的请求。它会跟踪运行中的请求，一旦服务器开始关闭，它将拒绝新的请求。

### Proxy Peer Address

此处理器可以被反向代理后面的服务器使用。它将修改`HttpServerExchange`的对等地址和协议，以匹配反向代理发送的`X-Forwarded-*`标头。这意味着下游处理器将看到实际客户端的对等地址，而不是代理的地址。

### Request Limiting Handler

限制并发请求数的处理器。如果请求数量超出限制，那么会将请求排队。如果队列已满，则拒绝请求。

## Undertow Handler Authors Guide

本指南概述了如何为Undertow编写本地处理器。它并没有涵盖`HttpServerExchange`对象上的所有API方法，因为其中许多方法都是自解释性的，或者由Javadoc解析。相反，本指南重点介绍编写Undertow处理器所需的概念。

让我们从一个简单的例子开始：

```java
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
```

在大多数情况下，上面的代码是自解释的，因此很容易理解：

#### The Undertow Builder

使用`Buidler` API，你可以快速配置和启动Undertow服务器，它旨在用于嵌入式和测试环境。`Builder`类的API可能会在未来继续演进更改。

#### Listener Binding

下一行告诉Undertow服务器在端口`8080`上绑定到`localhost`。

#### Default Handler

如果`URL`与在Undertow中注册的任何路径都不匹配，那么将使用这个默认处理器。在上面的例子中，我们没有注册任何其他处理器，因此始终会调用此处理器。

#### Response Headers

设置`Content-Type`标头，这很容易理解。要注意的一件事是，Undertow并不使用`String`作为标头表的键，而是一个不区分大小写的字符串`io.undertow.util.HttpString`。`io.undertow.util.Headers`类中预定义了所有常用的标头。

#### Response Sender

Undertow `Sender API`只是发送响应的一种方式。稍后将详细介绍`Sender`，在上面的例子中，由于未指定完成回调，所以`Sender`知道提供的字符串是完整的响应，因此将为我们设置内容长度标头并在完成后关闭响应。

从现在开始，我们的代码示例将专注于处理器本身，而不是用于设置服务器的代码。

### Request Lifecycle

（这也包含在[“请求生命周期”](https://undertow.io/undertow-docs/undertow-docs-2.1.0/undertow-request-lifecycle.html)文档中。）

当客户端连接到服务器时，Undertow创建一个`io.undertow.server.HttpServerConnection`。客户端发送请求时，它由Undertow解析器解析，然后将结果`io.undertow.server.HttpServerExchange`传递到根处理器。当根处理器完成时，可能会发生以下四种情况之一：

#### The exchange can be already completed

如果请求和响应通道均已完全读取/写入，则认为交换（`HttpServerExchange`）已完成。对于没有内容的请求（例如`GET`和`HEAD`），请求侧将自动视为已完全读取。当处理器已写出完整的响应并关闭以及完全刷新响应通道时，则认为响应侧已完成。如果交换已经完成，那么之后将不会采取任何措施，因为交换已经结束。

#### The root handler returns normally without completing the exchange

在这种情况下，可以通过`HttpServerExchange.endExchange()`方法完成`exchange`。`endExchange()`的语义将在后面讨论。

#### The root handler returns with an Exception

在这种情况下，将设置响应码`500`，并调用`HttpServerExchange.endExchange()`方法结束`exchange`。

#### The root handler can return after HttpServerExchange.dispatch() has been called, or after async IO has been started

在这种情况下，被分派的任务将被提交到分派执行器中执行，或者如果已在请求或响应通道上启动了异步IO，则将启动该任务。此时`exchange`将不会处于完成状态，而是当异步任务完成后判断是否完成。

到目前为止，`HttpServerExchange.dispatch()`最常见的用法是将任务执行从一个不允许阻塞的IO线程转移到一个允许阻塞操作的工作线程中。通常如下所示：

*Dispatching to a worker thread*
```java
public void handleRequest(final HttpServerExchange exchange) throws Exception {
    if (exchange.isInIoThread()) {
      exchange.dispatch(this);
      return;
    }
    //handler code
}
```

因为直到调用堆栈返回才真正调度`HttpServerExchange`，所以你可以确定永远不会在一个`HttpServerExchange`上有多个线程处于活动状态。`HttpServerExchange`不是线程安全的，但是可以在多个线程之间传递，只要两个线程不要立即尝试对其进行修改，并且在第一个和第二个线程访问操作之间存在一个`happens before`操作（例如线程池分派）。

> 原文：Because exchange is not actually dispatched until the call stack returns you can be sure that more that one thread is never active in an exchange at once. The exchange is not thread safe, however it can be passed between multiple threads as long as both threads do not attempt to modify it at once, and there is a happens before action (such as a thread pool dispatch) in between the first and second thread access.

### Ending the exchange

如上所述，一旦请求和响应通道都被关闭和刷新，`exchange`就被认为已经完成。

有两种方法可以结束一个`exchange`，第一种方法是完全读取请求通道，然后在响应通道上调用`shutdownWrites()`并刷新通道，第二种方法则是调用`HttpServerExchange.endExchange()`。当`endExchange()`调用时，Undertow将检查是否已生成响应内容，如果已生成，则将仅清空请求通道，并关闭以及刷新响应通道。如果没有，并且有任何默认响应监听器注册到了`exchange`上，那么Undertow将为每个监听器提供一个生成默认响应的机会。这个机制一般是用来生成默认错误页面的。

### The Undertow Buffer Pool

由于Undertow基于`NIO`，因此在需要缓冲时会使用`java.nio.ByteBuffer`。这些缓冲区是池化的，不应按需分配，因为这会严重影响性能。可以调用`HttpServerConnection.getBufferPool()`方法获取缓冲池。

池化缓冲池使用后必须释放，因为它们不会被垃圾收集器清除。在创建服务器时会配置缓冲池中缓冲区的大小。经验测试表明，如果使用直接缓冲区，在需要最大性能的情况下使用16kb大小的缓冲区是最佳的（因为这对应`Linux`上的默认套接字缓冲区大小）。

### Non-blocking IO

默认情况下，Undertow使用非阻塞`XNIO`通道，并且请求最初在`XNIO IO`线程中启动。这些通道可以直接用于发送和接收数据。这些通道的级别很低，因此，Undertow提供了一些抽象方法，使得它们更加容易使用。

使用非阻塞IO发送响应的最简单方法是使用上个例子中展示的`Sender` API。它包含`send()`方法的多个重载版本，用于发送`byte`和`String`数据。该方法的某些版本可以接受回调，在发送完成时调用，而其他不接受回调的版本在发送完成后结束`exchange`。

请注意，`Sender` API不支持排队，直到回调被通知之后，你才可以再次调用`send()`方法。

使用不接受回调的`send()`方法版本时，将自动设置`Content-Length`标头，否则，你必须自己进行设置以避免使用分块编码。

`Sender` API还支持阻塞IO，如果调用了`HttpServerExchange.startBlocking()`方法将`exchange`置为阻塞模式，那么`Sender`将使用`exchange`输出流发送其数据。

### Blocking IO

Undertow为阻塞IO提供了全面的支持。我们不建议在`XNIO`工作线程中使用阻塞IO，因此在尝试读取或写入之前，你需要确保已将请求分派到一个工作线程池中。

在之前（`Dispatching to a worker thread`）已经介绍过如何将请求分派给工作线程。

要使用阻塞IO，你需要调用`HttpServerExchange.startBlocking()`方法。此方法有两种版本，一种不接受任何参数，它将使用Undertow的默认流实现，而另一个版本`HttpServerExchange.startBlocking(BlockingHttpServerExchange blockingExchange)`允许你自定义要使用的流。例如，`Servlet`实现采取第二种方法，使用`Servlet(Input/Output）Stream`实现替换Undertow的默认流。

将`exchange`置为阻塞模式后，你可以调用`HttpServerExchange.getInputStream()`和`HttpServerExchange.getOutputStream()`两个方法，并像往常一样读取或写入数据。此时你仍然可以使用之前介绍过的`Sender` API，但是在这种情况下将使用阻塞IO。

默认情况下，Undertow使用缓冲流，并使用从缓冲池中提取的缓冲区。如果响应内容足够小，即缓冲区能够容纳，那么将自动设置`Content-Length`标头。

### Headers

可以通过`HttpServerExchange.getRequestHeaders()`和`HttpServerExchange.getResponseHeaders()`方法访问请求头和响应头。这两个方法将返回一个`HeaderMap`类实例，它是优化过的`Map`实现。

当第一个数据写入底层通道时，标头将会随着HTTP响应写入（如果使用缓冲，则此时间可能与第一次写入数据的时间不同）。

如果希望强制写入标头，则可以在响应通道或流上调用`flush()`方法。

### HTTP Upgrade

为了进行HTTP升级，你可以调用`HttpServerExchange.upgradeChannel(ExchangeCompletionListener upgradeCompleteListener)`方法，响应代码将设置为101，一旦`exchange`完成，监听器就会收到通知。你的处理器负责设置升级客户端期望的任何适当的标头。

## Undertow Request Lifecycle

本文档将从Undertow服务器的角度介绍Web请求的生命周期。

建立连接后，`XNIO`将调用`io.undertow.server.HttpOpenListener`，此监听器会创建一个`io.undertow.server.HttpServerConnection`实例以存储与此连接关联的状态，然后调用`io.undertow.server.HttpReadListener`。

`HttpReadListener`负责解析传入的请求，并创建一个`io.undertow.server.HttpServerExchange`实例来存储请求状态。`HttpServerExchange`对象会同时包含请求和响应状态。

此时将构造请求和响应通道包装器，它们负责对请求和响应数据进行解码和编码。

然后根处理器将会通过`io.undertow.server.Connectors#executeRootHandler`执行。处理器链接在一起，每个处理器都可以修改`exchange`，发送响应或委托其他处理器处理。此时，可能会发生一些不同的事情：

- `exchange`完成。当请求和响应通道都关闭时，会发生这种情况。如果设置了内容长度，一旦写入了所有数据，通道将自动关闭。也可以调用`HttpServerExchange.endExchange()`方法来强制执行此操作，如果尚未写入任何数据，将会给所有注册到此`exchange`之上的默认响应监听器一个机会生成默认响应，例如错误页面。一旦`exchange`完成，就会运行`exchange completion`监听器。最后一个`completion`监听器完成后通常将开始处理网络连接上的下一个请求，并且将由读取监听器进行设置。

- 可以调用`HttpServerExchange.dispatch`方法的任意一个版本来分派`exchange`。它和`servlet startAsync()`方法相似。调用堆栈返回后，分派任务（如果有）将在给定的执行线程中运行（如果未提供执行线程，那么XNIO工作程序将运行该任务）。分派的最常见用途是将操作从IO线程（不允许执行阻塞操作）中转移到可以阻塞的工作线程。这个模式如下所示：

```java
public void handleRequest(final HttpServerExchange exchange) throws Exception {
    if (exchange.isInIoThread()) {
      exchange.dispatch(this);
      return;
    }
    //handler code
}
```

- 读/写可以在请求或响应通道上恢复。在内部，这被视为分派，一旦调用堆栈返回，相关通道将收到有关IO事件的通知。该操作要等到调用堆栈返回后才能生效，这是为了确保永远不会有多个线程在同一个`exchange`中操作。

- 调用堆栈可以返回而无需分派`exchange`。如果发生这种情况`HttpServerExchange.endExchange()`方法将会被调用，并且这个请求将完成。

- 引发一个异常。如果异常一直传播到调用堆栈的上方，那么`exchange`将以响应代码`500`结束。

## Error Handling

错误处理是通过默认响应监听器完成的。如果在不发送响应的情况下`exchange`完成，那么默认响应监听器会生成一个响应。

这与`Servlet`错误处理完全不同。`Servlet`错误处理被实现为`Undertow Servlet`的一部分，并遵循标准`Servlet`规则。
通常，我们需要担心两种类型的错误：引发异常的处理器或者设置了一个错误的响应代码后调用`HttpServerExchange.endExchange()`的处理器。

### Exceptions

处理异常的最简单方法是在外部处理器中捕获异常。例如：

```java
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
```

这允许你的应用程序以你认为合适的方式处理异常。

如果异常传播到处理器链之外，那么将设置响应码`500`，并且结束`exchange`。

### Default Response Listeners

如果在没有响应体的情况下`exchange`结束，那么默认响应监听器允许你生成一个默认页面。默认响应处理器应测试错误响应码，然后生成适当的错误页面。

请注意，所有没有任何响应内容就终止的请求都会被默认响应处理器处理，但是为成功的请求生成一份默认的错误内容可能会导致问题。

可以通过`HttpServerExchange#addDefaultResponseListener(DefaultResponseListener)`方法注册默认响应监听器。它们将按照注册时的相反顺序被调用，因此最后注册的处理器是第一个被调用的处理器。

下面的示例展示了一个处理器，它将针对响应码`500`生成一个简单的错误页面：

```java
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
```

## Security
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

## Predicates Attributes and Handlers

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

```
method(POST)
method(value=POST)
equals(%m, "POST")
regex(pattern="POST", value="%m", full-match=true)
```

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