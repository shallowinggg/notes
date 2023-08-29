---
layout: default
title: NameServer
parent: RocketMQ
grand_parent: 消息队列
---

在本节中，我们了解`RocketMQ`的注册中心是如何实现的。

Version: 4.5.2

## 基础概念

RocketMQ的核心架构如下图所示：

![](image/rocketmq_architecture_3.png)

其中的`NameServer`便是本节将会介绍的核心内容。在`RocketMQ`的官方文档中，对`NameServer`作了如下介绍：

> `NameServer`是一个非常简单的Topic路由注册中心，其角色类似`Dubbo`中的`zookeeper`，支持`Broker`的动态注册与发现。主要包括两个功能：`Broker`管理，`NameServer`接受`Broker`集群的注册信息并且保存下来作为路由信息的基本数据。然后提供心跳检测机制，检查`Broker`是否还存活；路由信息管理，每个`NameServer`将保存关于`Broker`集群的整个路由信息和用于客户端查询的队列信息。然后`Producer`和`Conumser`通过`NameServer`就可以知道整个`Broker`集群的路由信息，从而进行消息的投递和消费。`NameServer`通常也是集群的方式部署，各实例间相互不进行信息通讯。`Broker`是向每一台`NameServer`注册自己的路由信息，所以每一个`NameServer`实例上面都保存一份完整的路由信息。当某个`NameServer`因某种原因下线了，`Broker`仍然可以向其它`NameServer`同步其路由信息，`Producer`, `Consumer`仍然可以动态感知`Broker`的路由的信息。

`RocketMQ`是一个支持分布式的消息中间件，为了能够让部署的多个节点保持一致性，存储元数据的注册中心是必不可少的一块内容。事实上，正如文档中介绍的一样，`NameServer`是一个非常简单的注册中心，它并没有达到`Paxos`或者`Raft`协议的高容错性以及一致性，这是目前存在的缺陷。

在2020年4月30日，`RocketMQ`社区开始提出使用`Raft`协议解决此问题的pr，在之后的版本中这个问题即将被修复。具体请查看[RIP-18 Metadata management architecture upgrade](https://docs.google.com/document/d/1hQxlbtlMDwNxyVDGsIIUpDNWwfS6hP0PGKY9-A2KUOA/edit#heading=h.nwczedg8v2na)了解更多信息。

虽然目前注册中心还存在一定的缺陷，但我们仍然可以了解学习弱化版本的注册中心是如何实现的，同时注册中心也是`RocketMQ`架构中核心的组成部分，对其有一定了解后才可以更好的理解其他内容。

在`RocketMQ`官网的[Quick Start](https://rocketmq.apache.org/docs/quick-start/)中也展示了使用`RocketMQ`首先需要启动`NameServer`，如下所示：

Start Name Server
```
> nohup sh bin/mqnamesrv &
> tail -f ~/logs/rocketmqlogs/namesrv.log
The Name Server boot success...
```
## 源码实现

`mqnamesrv.sh`文件中大部分的命令都是设置在设置环境，其中核心语句如下：

```
sh ${ROCKETMQ_HOME}/bin/runserver.sh org.apache.rocketmq.namesrv.NamesrvStartup $@
```

它继续执行`runserver.sh`文件，并将`org.apache.rocketmq.namesrv.NamesrvStartup`作为参数传入。在`runserver.sh`文件中，主要进行JVM以及gc日志的配置工作。核心语句如下：

```
$JAVA ${JAVA_OPT} $@
```

在这句命令中，涉及到了`org.apache.rocketmq.namesrv.NamesrvStartup`类的启动。这个类在`rocketmq-namesrv`模块中，其中`main`方法如下所示：

```java
public static void main(String[] args) {
    main0(args);
}

public static NamesrvController main0(String[] args) {
    try {
        NamesrvController controller = createNamesrvController(args);
        start(controller);
        String tip = "The Name Server boot success. serializeType=" + RemotingCommand.getSerializeTypeConfigInThisServer();
        log.info(tip);
        System.out.printf("%s%n", tip);
        return controller;
    } catch (Throwable e) {
        e.printStackTrace();
        System.exit(-1);
    }

    return null;
}

```

它的主要功能是进行了`NamesrvController`的创建以及启动。

### 创建NamesrvController

```java
public static NamesrvController createNamesrvController(String[] args) throws IOException, JoranException {
    // 设置系统属性版本号
    System.setProperty(RemotingCommand.REMOTING_VERSION_KEY, Integer.toString(MQVersion.CURRENT_VERSION));
    //PackageConflictDetect.detectFastjson();

    Options options = ServerUtil.buildCommandlineOptions(new Options());
    // 构建mynamesrv命令行，并解析入参
    commandLine = ServerUtil.parseCmdLine("mqnamesrv", args, buildCommandlineOptions(options), new PosixParser());
    if (null == commandLine) {
        System.exit(-1);
        return null;
    }

    // 构造默认配置类
    final NamesrvConfig namesrvConfig = new NamesrvConfig();
    final NettyServerConfig nettyServerConfig = new NettyServerConfig();
    // 设置name server服务端的监听端口为9876
    nettyServerConfig.setListenPort(9876);

    // 解析入参
    if (commandLine.hasOption('c')) {
        String file = commandLine.getOptionValue('c');
        if (file != null) {
            InputStream in = new BufferedInputStream(new FileInputStream(file));
            properties = new Properties();
            properties.load(in);
            MixAll.properties2Object(properties, namesrvConfig);
            MixAll.properties2Object(properties, nettyServerConfig);

            namesrvConfig.setConfigStorePath(file);

            System.out.printf("load config properties file OK, %s%n", file);
            in.close();
        }
    }

    if (commandLine.hasOption('p')) {
        InternalLogger console = InternalLoggerFactory.getLogger(LoggerName.NAMESRV_CONSOLE_NAME);
        MixAll.printObjectProperties(console, namesrvConfig);
        MixAll.printObjectProperties(console, nettyServerConfig);
        System.exit(0);
    }

    MixAll.properties2Object(ServerUtil.commandLine2Properties(commandLine), namesrvConfig);

    // 检查rocketmq home是否配置，默认会在mqnamesrv文件中配置环境变量ROCKETMQ_HOME
    if (null == namesrvConfig.getRocketmqHome()) {
        System.out.printf("Please set the %s variable in your environment to match the location of the RocketMQ installation%n", MixAll.ROCKETMQ_HOME_ENV);
        System.exit(-2);
    }

    // 配置日志信息，默认读取$ROCKETMQ_HOME/conf/logback_namesrv.xml
    LoggerContext lc = (LoggerContext) LoggerFactory.getILoggerFactory();
    JoranConfigurator configurator = new JoranConfigurator();
    configurator.setContext(lc);
    lc.reset();
    configurator.doConfigure(namesrvConfig.getRocketmqHome() + "/conf/logback_namesrv.xml");

    log = InternalLoggerFactory.getLogger(LoggerName.NAMESRV_LOGGER_NAME);

    MixAll.printObjectProperties(log, namesrvConfig);
    MixAll.printObjectProperties(log, nettyServerConfig);

    // 根据配置信息创建NamesrvController
    final NamesrvController controller = new NamesrvController(namesrvConfig, nettyServerConfig);

    // remember all configs to prevent discard
    controller.getConfiguration().registerConfig(properties);

    return controller;
}

```

创建`NamesrvController`共分为下面几步：

1. 设置系统版本号
2. 解析命令行传入的参数，如果传入了`-h`参数，那么将打印帮助信息并退出
3. 构造默认配置信息
4. 如果用户通过`-c`参数提供了自定义配置信息，那么将解析并覆盖默认配置
5. 如果用户传入了`-p`参数，那么将打印全部配置信息并退出
6. 读取`conf`目录下的日志配置，并配置日志框架
7. 构造`NamesrvController`实例并返回

其中大部分的步骤都相对比较简单，下面挑选其中几个讲解。

#### mqnamesrv命令

`RocketMQ`使用apache的`cli`工具包解析`mqnamesrv`命令行信息，`mqnamesrv`的参数项及对应功能如下所示：

```
usage: mqnamesrv [-c <arg>] [-h] [-n <arg>] [-p]
 -c,--configFile <arg>    Name server config properties file
 -h,--help                Print help
 -n,--namesrvAddr <arg>   Name server address list, eg: 192.168.0.1:9876;192.168.0.2:9876
 -p,--printConfigItem     Print all config item
```

> 其中`-n`参数并没有进行处理，这可能是代码演化时出现的bug。

#### 自定义配置

你可以通过`-c`参数提供一个properties文件，自定义namesrv以及服务端的相关配置项。这些自定义的配置项将会覆盖与之对应的默认配置。

`namesrv`相关配置如下：

- `rocketmqHome`： RocketMQ根目录，默认会通过系统属性`rocketmq.home.dir`或者环境变量`ROCKETMQ_HOME`读取。
- `kvConfigPath`： 部分元数据存盘路径，默认存储在`/${user.home}/namesrv/kvConfig.json`文件中
- `configStorePath`： 存储自定义配置文件路径，默认为`/${user.home}/namesrv/namesrv.properties`。当使用`-c`参数时，替换为用户自定义配置文件的路径。
- `productEnvName`： 默认为`center`
- `clusterTest`： 默认为`false`
- `orderMessageEnable`： 是否启动有序消息，默认为`false`

除了注册中心自己的私有配置以外，你还可以配置通信模块中的服务端。关于这一块的内容，在上一节`transport`中已经进行了介绍，具体可查看`org.apache.rocketmq.remoting.netty.NettyServerConfig`类获取具体的可配置项。

自定义配置覆盖默认配置的方法是`MixAll#properties2Object(final Properties, final Object)`，主要通过反射获取Object的setter方法实现。

#### 构造NamesrvController实例

在获取到最终的配置信息后，将会使用它们来构造`NamesrvController`实例，`NamesrvController`类的构造方法如下所示：

```java
public NamesrvController(NamesrvConfig namesrvConfig, NettyServerConfig nettyServerConfig) {
    this.namesrvConfig = namesrvConfig;
    this.nettyServerConfig = nettyServerConfig;
    // 构造配置管理器
    this.kvConfigManager = new KVConfigManager(this);
    // 构造路由信息管理器
    this.routeInfoManager = new RouteInfoManager();
    // 构造事件监听器，管理与broker之间的网络连接
    this.brokerHousekeepingService = new BrokerHousekeepingService(this);
    this.configuration = new Configuration(
        log,
        this.namesrvConfig, this.nettyServerConfig
    );
    this.configuration.setStorePathFromConfig(this.namesrvConfig, "configStorePath");
}

```

注册中心拥有的所有功能都被`NamesrvController`集中管理，在其构造方法中构造了一些管理器用以启用这些功能。

`BrokerHousekeepingService`则实现了netty的事件接口`ChannelEventListener`，当底层通信所用的`Channel`出现故障或者其他情况将会触发事件，修改路由信息管理器中的数据表。

### 启动NamesrvController

之前的过程只是对`NamesrvController`进行了初步的构造，还需要启动它以提供所有的服务。

```java
public static NamesrvController start(final NamesrvController controller) throws Exception {

    if (null == controller) {
        throw new IllegalArgumentException("NamesrvController is null");
    }

    // 初始化NamesrvController
    boolean initResult = controller.initialize();
    if (!initResult) {
        controller.shutdown();
        System.exit(-3);
    }

    // 增加钩子，优雅关闭
    Runtime.getRuntime().addShutdownHook(new ShutdownHookThread(log, new Callable<Void>() {
        @Override
        public Void call() throws Exception {
            controller.shutdown();
            return null;
        }
    }));

    // 启动NamesrvController
    controller.start();

    return controller;
}

```

启动`NamesrvController`共分为三步：

1. 初始化`NamesrvController`
2. 注册销毁钩子
3. 启动`NamesrvController`

#### 初始化`NamesrvController`

`NamesrvController`作为注册中心，最常用的功能便是与客户端之间建立网络连接，然后通过交换数据包完成预定的功能。因此，在启动服务端之前，需要先进行一些初始化过程，当初始化完成后，才可以真正启动对外提供服务。初始化方法如下所示：

```java
public boolean initialize() {

    // 加载配置管理器
    this.kvConfigManager.load();

    // 构造服务端
    this.remotingServer = new NettyRemotingServer(this.nettyServerConfig, this.brokerHousekeepingService);

    // 8  业务线程池，负责执行业务逻辑
    this.remotingExecutor =
        Executors.newFixedThreadPool(nettyServerConfig.getServerWorkerThreads(), new ThreadFactoryImpl("RemotingExecutorThread_"));

    // 注册请求处理器
    this.registerProcessor();

    // 检查broker心跳，超过10s未发送心跳包则判定失联，remove
    this.scheduledExecutorService.scheduleAtFixedRate(new Runnable() {

        @Override
        public void run() {
            NamesrvController.this.routeInfoManager.scanNotActiveBroker();
        }
    }, 5, 10, TimeUnit.SECONDS);

    this.scheduledExecutorService.scheduleAtFixedRate(new Runnable() {

        @Override
        public void run() {
            NamesrvController.this.kvConfigManager.printAllPeriodically();
        }
    }, 1, 10, TimeUnit.MINUTES);

    if (TlsSystemConfig.tlsMode != TlsMode.DISABLED) {
        // Register a listener to reload SslContext
        try {
            fileWatchService = new FileWatchService(
                new String[] {
                    TlsSystemConfig.tlsServerCertPath,
                    TlsSystemConfig.tlsServerKeyPath,
                    TlsSystemConfig.tlsServerTrustCertPath
                },
                new FileWatchService.Listener() {
                    boolean certChanged, keyChanged = false;
                    @Override
                    public void onChanged(String path) {
                        if (path.equals(TlsSystemConfig.tlsServerTrustCertPath)) {
                            log.info("The trust certificate changed, reload the ssl context");
                            reloadServerSslContext();
                        }
                        if (path.equals(TlsSystemConfig.tlsServerCertPath)) {
                            certChanged = true;
                        }
                        if (path.equals(TlsSystemConfig.tlsServerKeyPath)) {
                            keyChanged = true;
                        }
                        if (certChanged && keyChanged) {
                            log.info("The certificate and private key changed, reload the ssl context");
                            certChanged = keyChanged = false;
                            reloadServerSslContext();
                        }
                    }
                    private void reloadServerSslContext() {
                        ((NettyRemotingServer) remotingServer).loadSslContext();
                    }
                });
        } catch (Exception e) {
            log.warn("FileWatchService created error, can't load the certificate dynamically");
        }
    }

    return true;
}

```

在上面的初始化方法中，进行了许多初始化过程，如下：

1. 初始化配置管理器。配置管理器用于存储一些公用的键值对配置，考虑到容错，这些配置会进行存盘以防机器宕机，丢失所有信息。因此，在启动之前，需要先读取之前存盘的数据。当然，如果是第一次启动，那么将不存在存储文件，这一步将会跳过。
2. 构造Netty服务端和业务线程池，并注册请求处理器。这方面的内容在上一节网络通信中已经详细介绍过。
3. 启动定时任务，检测与`broker`之间的连接以及打印配置管理器中存储的配置项。
4. 注册文件监听器。当启用SSL加密时，将监听相关的配置文件，如果他们发生了变化，那么将重建SSL处理器。


初始化配置管理器的代码如下所示，它将读取存储配置的文件，并置于配置管理器中。默认文件路径为`/${user.home}/namesrv/kvConfig.json`。

```java
public void load() {
    String content = null;
    try {
        // /${user.home}/namesrv/kvConfig.json
        // 首次启动时不存在此文件，返回null
        content = MixAll.file2String(this.namesrvController.getNamesrvConfig().getKvConfigPath());
    } catch (IOException e) {
        log.warn("Load KV config table exception", e);
    }
    if (content != null) {
        KVConfigSerializeWrapper kvConfigSerializeWrapper =
            KVConfigSerializeWrapper.fromJson(content, KVConfigSerializeWrapper.class);
        if (null != kvConfigSerializeWrapper) {
            this.configTable.putAll(kvConfigSerializeWrapper.getConfigTable());
            log.info("load KV config table OK");
        }
    }
}

```

#### 启动`NamesrvController`

完成`NamesrvController`的初始化工作后，即各个子功能已经预热完毕，便可以正式启动注册中心的通信服务端，接受来自客户端的连接。启动`NamesrvController`的源码如下：

```java
    public void start() throws Exception {
        // 启动远程服务
        this.remotingServer.start();

        // 启动文件监视器，当文件发生变化时，重新加载
        if (this.fileWatchService != null) {
            this.fileWatchService.start();
        }
    }
```

### `NamesrvController`核心功能

在`NamesrvController`的构造过程中，同时还构造了`KVConfigManager`, `RouteInfoManager`, `RemotingServer`, `BrokerHousekeepingService`, `FileWatchService`这几个类的实例。其中`KVConfigManager`, `RemotingServer`以及`FileWatchService`之前已经进行了介绍，接下来分析一下`RouteInfoManager`和`BrokerHousekeepingService`的功能，以及服务端的`NettyRequestProcessor`。

#### RouteInfoManager

路由信息管理器`RouteInfoManager`主要负责管理`broker`的元数据，例如启用的`topic`信息，与`topic`关联的队列信息，`broker`的路由信息，集群信息等。

```java
// 主题对应的队列信息
private final HashMap<String/* topic */, List<QueueData>> topicQueueTable;

// 所有broker的信息，包括所属集群，名称以及它的地址，包括主从broker
private final HashMap<String/* brokerName */, BrokerData> brokerAddrTable;

// 集群及其下属的broker
private final HashMap<String/* clusterName */, Set<String/* brokerName */>> clusterAddrTable;

// 当前存活的broker信息
private final HashMap<String/* brokerAddr */, BrokerLiveInfo> brokerLiveTable;

//
private final HashMap<String/* brokerAddr */, List<String>/* Filter Server */> filterServerTable;
```

关于`broker`, `topic`的基本概念如下：

> RocketMQ主要由 Producer、Broker、Consumer 三部分组成，其中Producer 负责生产消息，Consumer 负责消费消息，Broker 负责存储消息。Broker 在实际部署过程中对应一台服务器，每个 Broker 可以存储多个Topic的消息，每个Topic的消息也可以分片存储于不同的 Broker。

> `Topic`表示一类消息的集合，每个主题包含若干条消息，每条消息只能属于一个主题，是RocketMQ进行消息订阅的基本单位。

> `Broker`是消息中转角色，负责存储消息、转发消息。代理服务器在RocketMQ系统中负责接收从生产者发送来的消息并存储、同时为消费者的拉取请求作准备。代理服务器也存储消息相关的元数据，包括消费者组、消费进度偏移和主题和队列消息等。

在此处只是对`RouteInfoManager`的功能进行一个简单的介绍，显得比较空泛。在后面分析`Broker`的源码时，`RouteInfoManager`的功能将会变得容易理解。因此，如果现在对它的功能感到困惑并不是问题，留下一个印象即可。

#### BrokerHousekeepingService

`BrokerHousekeepingService`实现了`ChannelEventListener`接口，主要是对客户端的连接，断开等事件进行监听，并作相应的处理，关于`ChannelEventListener`接口的详细介绍，请查看上一节内容。

`BrokerHousekeepingService`的实现相当简单，当客户端连接空闲，断开以及异常时，对`RouteInfoManager`进行相应的处理。之前介绍过`RouteInfoManager`会存储`broker`相关的元信息，事实上`namesrv`对应的客户端只有`broker`，因此当某个`broker`与当前注册中心的网络连接出现变化时，需要对`RouteInfoManager`进行修正（存在异常断开连接的情况，所以需要一个被动的触发器来处理这种情况）。

```java
    @Override
    public void onChannelConnect(String remoteAddr, Channel channel) {
    }

    @Override
    public void onChannelClose(String remoteAddr, Channel channel) {
        this.namesrvController.getRouteInfoManager().onChannelDestroy(remoteAddr, channel);
    }

    @Override
    public void onChannelException(String remoteAddr, Channel channel) {
        this.namesrvController.getRouteInfoManager().onChannelDestroy(remoteAddr, channel);
    }

    @Override
    public void onChannelIdle(String remoteAddr, Channel channel) {
        this.namesrvController.getRouteInfoManager().onChannelDestroy(remoteAddr, channel);
    }
```

#### NettyRequestProcessor

在上一节`transport`中对`NettyRequestProcessor`进行了详细的介绍，在此处`RocketMQ`向我们展示了具体的实践。

在`NamesrvController`的初始化过程中，对`NettyRequestProcessor`进行了注册，如下所示：

```java
    private void registerProcessor() {
        // 默认为false
        if (namesrvConfig.isClusterTest()) {
            this.remotingServer.registerDefaultProcessor(new ClusterTestRequestProcessor(this, namesrvConfig.getProductEnvName()),
                this.remotingExecutor);
        } else {
            // 构造默认的请求处理器，负责执行remote request/response操作
            this.remotingServer.registerDefaultProcessor(new DefaultRequestProcessor(this), this.remotingExecutor);
        }
    }
```

此处将`DefaultRequestProcessor`作为默认处理器注册，所以客户端的请求都通过它进行处理。

它的核心方法`processRequest`的片段如下所示：

```java

        switch (request.getCode()) {
            case RequestCode.PUT_KV_CONFIG:
                return this.putKVConfig(ctx, request);
            case RequestCode.GET_KV_CONFIG:
                return this.getKVConfig(ctx, request);
            case RequestCode.DELETE_KV_CONFIG:
                return this.deleteKVConfig(ctx, request);
            case RequestCode.QUERY_DATA_VERSION:
                return queryBrokerTopicConfig(ctx, request);
            case RequestCode.REGISTER_BROKER:
                ......
```

使用`switch`语句根据请求码分别进行相应的处理，当设计的请求场景较少时，非常适合这种处理方式。当请求的场景的过多时，则需要对其进行分类，使用多个`NettyRequestProcessor`分别处理每一类的请求，以使得代码有良好的可维护性。

在`processRequest`方法的请求处理中，将会和`KVConfigManager`，`RouteInfoManager`进行交互，以完成注册中心提供的功能。

除了`DefaultRequestProcessor`以外，如果你启用了集群测试，那么将使用`ClusterTestRequestProcessor`来替代它。`ClusterTestRequestProcessor`继承自`DefaultRequestProcessor`，只对查询`Topic`元信息的处理作了一些改动。

```java
// DefaultRequestProcessor.java
    public RemotingCommand getRouteInfoByTopic(ChannelHandlerContext ctx,
        RemotingCommand request) throws RemotingCommandException {
        final RemotingCommand response = RemotingCommand.createResponseCommand(null);
        final GetRouteInfoRequestHeader requestHeader =
            (GetRouteInfoRequestHeader) request.decodeCommandCustomHeader(GetRouteInfoRequestHeader.class);

        // 获取queue data，broker data，filter server
        TopicRouteData topicRouteData = this.namesrvController.getRouteInfoManager().pickupTopicRouteData(requestHeader.getTopic());

        // 设置order
        if (topicRouteData != null) {
            if (this.namesrvController.getNamesrvConfig().isOrderMessageEnable()) {
                String orderTopicConf =
                    this.namesrvController.getKvConfigManager().getKVConfig(NamesrvUtil.NAMESPACE_ORDER_TOPIC_CONFIG,
                        requestHeader.getTopic());
                topicRouteData.setOrderTopicConf(orderTopicConf);
            }

            byte[] content = topicRouteData.encode();
            response.setBody(content);
            response.setCode(ResponseCode.SUCCESS);
            response.setRemark(null);
            return response;
        }

        response.setCode(ResponseCode.TOPIC_NOT_EXIST);
        response.setRemark("No topic route info in name server for the topic: " + requestHeader.getTopic()
            + FAQUrl.suggestTodo(FAQUrl.APPLY_TOPIC_URL));
        return response;
    }

// ClusterTestRequestProcessor.java
    @Override
    public RemotingCommand getRouteInfoByTopic(ChannelHandlerContext ctx,
        RemotingCommand request) throws RemotingCommandException {
        final RemotingCommand response = RemotingCommand.createResponseCommand(null);
        final GetRouteInfoRequestHeader requestHeader =
            (GetRouteInfoRequestHeader) request.decodeCommandCustomHeader(GetRouteInfoRequestHeader.class);

        TopicRouteData topicRouteData = this.namesrvController.getRouteInfoManager().pickupTopicRouteData(requestHeader.getTopic());
        if (topicRouteData != null) {
            String orderTopicConf =
                this.namesrvController.getKvConfigManager().getKVConfig(NamesrvUtil.NAMESPACE_ORDER_TOPIC_CONFIG,
                    requestHeader.getTopic());
            topicRouteData.setOrderTopicConf(orderTopicConf);
        } else {
            // 当前注册中心不存在，查询其他注册中心
            try {
                topicRouteData = adminExt.examineTopicRouteInfo(requestHeader.getTopic());
            } catch (Exception e) {
                log.info("get route info by topic from product environment failed. envName={},", productEnvName);
            }
        }

        if (topicRouteData != null) {
            byte[] content = topicRouteData.encode();
            response.setBody(content);
            response.setCode(ResponseCode.SUCCESS);
            response.setRemark(null);
            return response;
        }

        response.setCode(ResponseCode.TOPIC_NOT_EXIST);
        response.setRemark("No topic route info in name server for the topic: " + requestHeader.getTopic()
            + FAQUrl.suggestTodo(FAQUrl.APPLY_TOPIC_URL));
        return response;
    }
```

在`ClusterTestRequestProcessor`中，如果当前注册中心没有存储查询的`Topic`信息，那么它将尝试向其他注册中心查询，最后返回结果。

## 总结

在本节中，对注册中心进行了一个简单的介绍以及分析。`broker`, `producer`以及`consumer`都会与注册中心存在直接或者间接的通信，因此，在之后的章节中将对注册中心的功能有一个完整的理解以及概括。