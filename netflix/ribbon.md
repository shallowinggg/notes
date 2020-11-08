# config

`ribbon`配置文件的属性格式如下：

```
<clientName>.<nameSpace>.<propertyName>=<value>
```

当加载配置文件时，会将`ribbon`视作默认的`namespace`，当然也可以通过编码手动指定`namespace`。另外，如果属性名称不指定`clientName`，那么这个属性将作为所有客户端的全局配置，例如`ribbon.MaxHttpConnectionsPerHost=10`。

`config`包的核心组成结构如下：

![](imageibbon-config.png)

## IClientConfigKey

`IClientConfigKey`接口是对配置key的抽象，它提供了配置属性的类型以及默认值的访问操作。相比传统的常量表示或者枚举表示，此接口提供了更加强大的能力以及便捷性。

```java
public interface IClientConfigKey<T> {

    @SuppressWarnings("rawtypes")
	final class Keys extends CommonClientConfigKey {
        private Keys(String configKey) {
            super(configKey);
        }
    }
    
	/**
	 * @return string representation of the key used for hash purpose.
	 */
	String key();
	
	/**
     * @return Data type for the key. For example, Integer.class.
	 */
	Class<T> type();

	default T defaultValue() { return null; }

	default IClientConfigKey<T> format(Object ... args) {
		return create(String.format(key(), args), type(), defaultValue());
	}

	default IClientConfigKey<T> create(String key, Class<T> type, T defaultValue) {
		return new IClientConfigKey<T>() {

			@Override
			public int hashCode() {
				return key().hashCode();
			}

			@Override
			public boolean equals(Object obj) {
				if (obj instanceof IClientConfigKey) {
					return key().equals(((IClientConfigKey)obj).key());
				}
				return false;
			}

			@Override
			public String toString() {
				return key();
			}

			@Override
			public String key() {
				return key;
			}

			@Override
			public Class<T> type() {
				return type;
			}

			@Override
			public T defaultValue() { return defaultValue; }
		};
	}
}
```

`CommonClientConfigKey`类则是对`IClientConfigKey`接口的实现，它是一个抽象类，通过创建它的匿名子类即可自动解析配置属性的类型。

## IClientConfig

`IClientConfig`接口提供了配置属性的访问API，如下所示：

```java
public interface IClientConfig {
	
	String getClientName();
		
	String getNameSpace();

	void setNameSpace(String nameSpace);

	/**
	 * Load the properties for a given client and/or load balancer. 
	 * @param clientName
	 */
	void loadProperties(String clientName);
	
	/**
	 * load default values for this configuration
	 */
	void loadDefaultValues();

	Map<String, Object> getProperties();

    /**
     * Iterate all properties and report the final value.  Can be null if a default value is not specified.
     * @param consumer
     */
    default void forEach(BiConsumer<IClientConfigKey<?>, Object> consumer) {
        throw new UnsupportedOperationException();
    }
    
    /**
     * Returns a typed property. If the property of IClientConfigKey is not set, it returns null.
     */
    <T> T get(IClientConfigKey<T> key);

    /**
     * Returns a typed property. If the property of IClientConfigKey is not set, it returns the default value, which
     * could be null.
     */
    default <T> T getOrDefault(IClientConfigKey<T> key) {
        return get(key, key.defaultValue());
    }

    /**
     * Return a typed property if and only if it was explicitly set, skipping configuration loading.
     * @param key
     * @param <T>
     * @return
     */
    default <T> Optional<T> getIfSet(IClientConfigKey<T> key) {
        return Optional.ofNullable(get(key));
    }

    /**
     * @return Return a global dynamic property not scoped to the specific client.  The property will be looked up as is using the
     * key without any client name or namespace prefix
     */
    <T> Property<T> getGlobalProperty(IClientConfigKey<T> key);

    /**
     * @return Return a dynamic property scoped to the client name or namespace.
     */
    <T> Property<T> getDynamicProperty(IClientConfigKey<T> key);

    /**
     * @return Return a dynamically updated property that is a mapping of all properties prefixed by the key name to an
     * object with static method valueOf(Map{@literal <}String, String{@literal >})
     */
    default <T> Property<T> getPrefixMappedProperty(IClientConfigKey<T> key) {
        throw new UnsupportedOperationException();
    }

    /**
     * Returns a typed property. If the property of IClientConfigKey is not set, 
     * it returns the default value passed in as the parameter.
     */
    <T> T get(IClientConfigKey<T> key, T defaultValue);

    /**
     * Set the typed property with the given value. 
     */
    <T> IClientConfig set(IClientConfigKey<T> key, T value);

    // ... other methods
}

```

它的抽象实现类`ReloadableClientConfig`提供了配置动态更新的能力，因为它使用了`Archaius`作为底层的数据源。`ReloadableClientConfig`类维护了两张映射表，一个存储动态属性，另一个存储编码设置的默认值。

```java
    // Map of raw property names (without namespace or client name) to values. All values are non-null and properly
    // typed to match the key type
    private final Map<IClientConfigKey<?>, Optional<?>> internalProperties = new ConcurrentHashMap<>();

    private final Map<IClientConfigKey<?>, ReloadableProperty<?>> dynamicProperties = new ConcurrentHashMap<>();

    // List of actions to perform when configuration changes.  This includes both updating the Property instances
    // as well as external consumers.
    private final Map<IClientConfigKey<?>, Runnable> changeActions = new ConcurrentHashMap<>();
```

下面的代码片段展示了如何使用`IClientConfig`加载特定`<clientName>.<nameSpace>`的配置：

```java
    public static DefaultClientConfigImpl getClientConfigWithDefaultValues(String clientName, String nameSpace) {
        DefaultClientConfigImpl config = new DefaultClientConfigImpl(nameSpace);
        config.loadProperties(clientName);
        return config;
    }
```

当调用`loadProperties(String)`方法时，`ReloadableClientConfig`会通过`PropertyResolver`接口读取给定的配置key，如果配置源中不存在此属性，那么将使用默认值。获取到配置的值后，会将其存储到`internalProperties`表中，并注册一个处理器。当数据源中此配置的值发生变化时，将会通知处理器执行以更新`internalProperties`表中存储的值。

```java
    @Override
    public void loadProperties(String clientName) {
        LOG.info("[{}] loading config", clientName);
        this.clientName = clientName;
        this.isDynamic = true;
        loadDefaultValues();
        resolver.onChange(this::reload);

        internalProperties.forEach((key, value) -> LOG.info("[{}] {}={}", clientName, key, value.orElse(null)));
    }

    public void loadDefaultValues() {
        setDefault(CommonClientConfigKey.MaxHttpConnectionsPerHost, getDefaultMaxHttpConnectionsPerHost());
        setDefault(CommonClientConfigKey.MaxTotalHttpConnections, getDefaultMaxTotalHttpConnections());
        // ...
    }

    protected final <T> void setDefault(IClientConfigKey<T> key, T value) {
        Preconditions.checkArgument(key != null, "key cannot be null");

        value = resolveFromPropertyResolver(key).orElse(value);
        internalProperties.put(key, Optional.ofNullable(value));
        if (isDynamic) {
            autoRefreshFromPropertyResolver(key);
        }
        cachedToString = null;
    }

    private final PropertyResolver resolver;

    /**
     * Resolve a property's final value from the property value.
     * - client scope
     * - default scope
     */
    private <T> Optional<T> resolveFromPropertyResolver(IClientConfigKey<T> key) {
        Optional<T> value;
        if (!StringUtils.isEmpty(clientName)) {
            value = resolver.get(clientName + "." + getNameSpace() + "." + key.key(), key.type());
            if (value.isPresent()) {
                return value;
            }
        }

        return resolver.get(getNameSpace() + "." + key.key(), key.type());
    }

    /**
     * Register an action that will refresh the cached value for key. Uses the current value as a reference and will
     * update from the dynamic property source to either delete or set a new value.
     *
     * @param key - Property key without client name or namespace
     */
    private <T> void autoRefreshFromPropertyResolver(final IClientConfigKey<T> key) {
        changeActions.computeIfAbsent(key, ignore -> {
            final Supplier<Optional<T>> valueSupplier = () -> resolveFromPropertyResolver(key);
            final Optional<T> current = valueSupplier.get();
            if (current.isPresent()) {
                internalProperties.put(key, current);
            }

            final AtomicReference<Optional<T>> previous = new AtomicReference<>(current);
            return () -> {
                final Optional<T> next = valueSupplier.get();
                if (!next.equals(previous.get())) {
                    LOG.info("[{}] new value for {}: {} -> {}", clientName, key.key(), previous.get(), next);
                    previous.set(next); 
                    internalProperties.put(key, next);
                }
            };
        });
    }
```

除此以外，`IClientConfig`还提供了`<T> Property<T> getDynamicProperty(IClientConfigKey<T> key)`方法用于获取动态属性，如下所示：

```java
    private static IClientConfigKey<Double> MAX_LOAD_PER_SERVER = new CommonClientConfigKey<Double>("zoneAffinity.maxLoadPerServer", 0.6d) {};

    private boolean zoneAffinity;
    private Property<Double> activeReqeustsPerServerThreshold;

    public void initWithNiwsConfig(IClientConfig niwsClientConfig) {
        zoneAffinity = niwsClientConfig.getOrDefault(CommonClientConfigKey.EnableZoneAffinity);
        activeReqeustsPerServerThreshold = niwsClientConfig.getDynamicProperty(MAX_LOAD_PER_SERVER);
    }

    private boolean shouldEnableZoneAffinity() {    
        double loadPerServer = ...;
        if (zoneAffinity && loadPerServer >= activeReqeustsPerServerThreshold.getOrDefault()) {
            // do something
        }
    }
```

其中`activeReqeustsPerServerThreshold`保存了对`internalProperties`表中对应条目的引用，因此调用它的`getOrDefault()`方法与调用`niwsClientConfig.getOrDefault(MAX_LOAD_PER_SERVER)`方法拥有同样的效果，相对而言更加清晰简洁一些。创建动态属性的过程如下：

```java
    @Override
    public final <T> Property<T> getDynamicProperty(IClientConfigKey<T> key) {
        LOG.debug("[{}] get dynamic property key={} ns={}", clientName, key.key(), getNameSpace());

        get(key);

        return getOrCreateProperty(
                key,
                () -> (Optional<T>)internalProperties.getOrDefault(key, Optional.empty()),
                key::defaultValue);
    }

    private synchronized <T> Property<T> getOrCreateProperty(final IClientConfigKey<T> key, final Supplier<Optional<T>> valueSupplier, final Supplier<T> defaultSupplier) {
        Preconditions.checkNotNull(valueSupplier, "defaultValueSupplier cannot be null");

        return (Property<T>)dynamicProperties.computeIfAbsent(key, ignore -> new ReloadableProperty<T>() {
                private volatile Optional<T> current = Optional.empty();
                private final List<Consumer<T>> consumers = new CopyOnWriteArrayList<>();

                {
                    reload();
                }

                @Override
                public void onChange(Consumer<T> consumer) {
                    consumers.add(consumer);
                }

                @Override
                public Optional<T> get() {
                    return current;
                }

                @Override
                public T getOrDefault() {
                    return current.orElse(defaultSupplier.get());
                }

                @Override
                public void reload() {
                    refreshCounter.incrementAndGet();

                    Optional<T> next = valueSupplier.get();
                    if (!next.equals(current)) {
                        current = next;
                        consumers.forEach(consumer -> consumer.accept(next.orElseGet(defaultSupplier)));
                    }
                }

                @Override
                public String toString() {
                    return String.valueOf(get());
                }
            });
    }
```

## PropertyResolver

`PropertyResolver`接口用于将`IClientConfig`和底层数据源之间进行解耦，当底层数据源的实现发生变化时，将不会对`IClientConfig`产生任何影响。目前`ribbon`的底层数据源使用`Archaius`实现，`ArchaiusPropertyResolver`类负责从`archaius`读取属性，并提供动态更新的能力。

```java
public interface PropertyResolver {
    /**
     * @return Get the value of a property or Optional.empty() if not set
     */
    <T> Optional<T> get(String key, Class<T> type);

    /**
     * Iterate through all properties with the specified prefix
     */
    void forEach(String prefix, BiConsumer<String, String> consumer);

    /**
     * Provide action to invoke when config changes
     * @param action
     */
    void onChange(Runnable action);
}
```

```java
    private final CopyOnWriteArrayList<Runnable> actions = new CopyOnWriteArrayList<>();

    private ArchaiusPropertyResolver() {
        this.config = ConfigurationManager.getConfigInstance();

        ConfigurationManager.getConfigInstance().addConfigurationListener(new ConfigurationListener() {
            @Override
            public void configurationChanged(ConfigurationEvent event) {
                if (!event.isBeforeUpdate()) {
                    actions.forEach(ArchaiusPropertyResolver::invokeAction);
                }
            }
        });
    }

    private static void invokeAction(Runnable action) {
        try {
            action.run();
        } catch (Exception e) {
            LOG.info("Failed to invoke action", e);
        }
    }

    @Override
    public void onChange(Runnable action) {
        actions.add(action);
    }

```

注意，当调用`ReloadableClientConfig#loadProperties(String)`方法时，会注册一个`reload`操作到`PropertyResolver`上，当底层数据源中的配置发生更改时，将会通知`ReloadableClientConfig`进行配置值的更新。

```java
# ReloadableClientConfig.java

    @Override
    public void loadProperties(String clientName) {
        LOG.info("[{}] loading config", clientName);
        this.clientName = clientName;
        this.isDynamic = true;
        loadDefaultValues();
        resolver.onChange(this::reload);

        internalProperties.forEach((key, value) -> LOG.info("[{}] {}={}", clientName, key, value.orElse(null)));
    }
```

# loadbalance

负载均衡器的核心功能是根据预定义的规则从一组服务实例中选取最合适的，因为首先需要对服务实例进行抽象，如下所示：

```java
/**
 * Class that represents a typical Server (or an addressable Node) i.e. a
 * Host:port identifier
 * 
 * @author stonse
 * 
 */
public class Server {

    /**
     * Additional meta information of a server, which contains
     * information of the targeting application, as well as server identification
     * specific for a deployment environment, for example, AWS.
     */
    public interface MetaInfo {
        /**
         * @return the name of application that runs on this server, null if not available
         */
        String getAppName();

        /**
         * @return the group of the server, for example, auto scaling group ID in AWS.
         * Null if not available
         */
        String getServerGroup();

        /**
         * @return A virtual address used by the server to register with discovery service.
         * Null if not available
         */
        String getServiceIdForDiscovery();

        /**
         * @return ID of the server
         */
        String getInstanceId();
    }

    public static final String UNKNOWN_ZONE = "UNKNOWN";
    private String host;
    private int port = 80;
    private String scheme;
    private volatile String id;
    private volatile boolean isAliveFlag;
    private String zone = UNKNOWN_ZONE;
    private volatile boolean readyToServe = true;

    // ...

}
```

其中`MetaInfo`接口是在加入云服务特性时引入的，提供了一些必要的元数据。

确定了服务实例的结构后，便可以在其基础上建立服务实例列表，由负载均衡器在此列表中进行选择。

![](imageibbon-serverlist.png)

```java
public interface ServerList<T extends Server> {

    public List<T> getInitialListOfServers();
    
    /**
     * Return updated list of servers. This is called say every 30 secs
     * (configurable) by the Loadbalancer's Ping cycle
     * 
     */
    public List<T> getUpdatedListOfServers();   

}

public interface ServerListFilter<T extends Server> {

    public List<T> getFilteredListOfServers(List<T> servers);

}

```

`ServerList`接口提供了访问服务实例列表的方法，`ServerListFilter`接口则提供了对服务实例列表进行过滤的能力。通过过滤，可以减少负载均衡器选择的范围。`ServerListUpdater`接口提供了动态更新服务实例列表的方法。当然，后两者的能力是可选的。


## ServerList

`ServerList`接口的默认实现类为`ConfigurationBasedServerList`，它从配置文件中读取服务实例列表，格式为`<clientName>.<nameSpace>.listOfServers=<comma delimited hostname:port strings>`。当然，这个类提供的能力有限，我们可以自己实现一个子类与服务注册框架进行整合，以提供动态发现服务实例列表的能力。


`ConfigurationBasedServerList`的实现如下所示：

```java
/**
 * The class includes an API to create a filter to be use by load balancer
 * to filter the servers returned from {@link #getUpdatedListOfServers()} or {@link #getInitialListOfServers()}.
 *
 */
public abstract class AbstractServerList<T extends Server> implements ServerList<T>, IClientConfigAware {   
     
    
    /**
     * Get a ServerListFilter instance. It uses {@link ClientFactory#instantiateInstanceWithClientConfig(String, IClientConfig)}
     * which in turn uses reflection to initialize the filter instance. 
     * The filter class name is determined by the value of {@link CommonClientConfigKey#NIWSServerListFilterClassName}
     * in the {@link IClientConfig}. The default implementation is {@link ZoneAffinityServerListFilter}.
     */
    public AbstractServerListFilter<T> getFilterImpl(IClientConfig niwsClientConfig) throws ClientException {
        String niwsServerListFilterClassName = null;
        try {
            niwsServerListFilterClassName = niwsClientConfig.get(
                            CommonClientConfigKey.NIWSServerListFilterClassName,
                            ZoneAffinityServerListFilter.class.getName());

            AbstractServerListFilter<T> abstractNIWSServerListFilter = 
                    (AbstractServerListFilter<T>) ClientFactory.instantiateInstanceWithClientConfig(niwsServerListFilterClassName, niwsClientConfig);
            return abstractNIWSServerListFilter;
        } catch (Throwable e) {
            throw new ClientException(
                    ClientException.ErrorType.CONFIGURATION,
                    "Unable to get an instance of CommonClientConfigKey.NIWSServerListFilterClassName. Configured class:"
                            + niwsServerListFilterClassName, e);
        }
    }
}

/**
 * Utility class that can load the List of Servers from a Configuration (i.e
 * properties available via Archaius). The property name be defined in this format:
 * 
 * <pre>{@code
<clientName>.<nameSpace>.listOfServers=<comma delimited hostname:port strings>
}</pre>
 * 
 * @author awang
 * 
 */
public class ConfigurationBasedServerList extends AbstractServerList<Server>  {

	private IClientConfig clientConfig;
		
	@Override
	public List<Server> getInitialListOfServers() {
	    return getUpdatedListOfServers();
	}

	@Override
	public List<Server> getUpdatedListOfServers() {
        String listOfServers = clientConfig.get(CommonClientConfigKey.ListOfServers);
        return derive(listOfServers);
	}

	@Override
	public void initWithNiwsConfig(IClientConfig clientConfig) {
	    this.clientConfig = clientConfig;
	}
	
	protected List<Server> derive(String value) {
	    List<Server> list = Lists.newArrayList();
		if (!Strings.isNullOrEmpty(value)) {
			for (String s: value.split(",")) {
				list.add(new Server(s.trim()));
			}
		}
        return list;
	}

	@Override
	public String toString() {
		return "ConfigurationBasedServerList:" + getUpdatedListOfServers();
	}
}

```

`AbstractServerList`抽象基类提供了一个获取默认过滤器的方法，过滤器的类名可以通过`<clientName>.<nameSpace>.NIWSServerListFilterClassName`配置属性指定，如果未指定那么默认使用`ZoneAffinityServerListFilter`过滤器类。

## filter

`ServerListFilter`接口提供了对服务实例列表进行过滤的能力。通过过滤，可以减少负载均衡器选择的范围。`ribbon`默认提供了`ZoneAffinityServerListFilter`和`ServerListSubsetFilter`两个过滤类，其中`ServerListSubsetFilter`继承自`ZoneAffinityServerListFilter`。

### ZoneAffinityServerListFilter

`ZoneAffinityServerListFilter`基于`zone`偏爱性进行过滤，当`<clientName>.<nameSpace>.EnableZoneAffinity`或者`<clientName>.<nameSpace>.EnableZoneExclusivity`配置项被设置为`true`，此过滤器将会被启用，默认情况下这个过滤器是关闭的。

`zone`偏爱性是指如果给定的服务实例所在`zone`与配置指定的`zone`一致，那么它会被保留下来。指定`zone`的配置项为`<clientName>.<nameSpace>.@zone`。

```java
public class ZoneAffinityPredicate extends AbstractServerPredicate {

    private final String zone;

    public ZoneAffinityPredicate(String zone) {
        this.zone = zone;
    }

    @Override
    public boolean apply(PredicateKey input) {
        Server s = input.getServer();
        String az = s.getZone();
        if (az != null && zone != null && az.toLowerCase().equals(zone.toLowerCase())) {
            return true;
        } else {
            return false;
        }
    }
}
```

经过`ZoneAffinityPredicate`过滤后，还需要检查这个`zone`的健康状态，如果不满足条件那么仍然返回全部服务实例列表，如下所示：

```java
    @Override
    public List<T> getFilteredListOfServers(List<T> servers) {
        if (zone != null && (zoneAffinity || zoneExclusive) && servers !=null && servers.size() > 0){
            List<T> filteredServers = Lists.newArrayList(Iterables.filter(
                    servers, this.zoneAffinityPredicate.getServerOnlyPredicate()));
            if (shouldEnableZoneAffinity(filteredServers)) {
                return filteredServers;
            } else if (zoneAffinity) {
                overrideCounter.increment();
            }
        }
        return servers;
    }


    private boolean shouldEnableZoneAffinity(List<T> filtered) {    
        if (!zoneAffinity && !zoneExclusive) {
            return false;
        }
        if (zoneExclusive) {
            return true;
        }
        LoadBalancerStats stats = getLoadBalancerStats();
        if (stats == null) {
            return zoneAffinity;
        } else {
            logger.debug("Determining if zone affinity should be enabled with given server list: {}", filtered);
            ZoneSnapshot snapshot = stats.getZoneSnapshot(filtered);
            double loadPerServer = snapshot.getLoadPerServer();
            int instanceCount = snapshot.getInstanceCount();            
            int circuitBreakerTrippedCount = snapshot.getCircuitTrippedCount();
            // 以下条件满足任何一个，则zone不健康
            // 1. zone中被断路的实例超过80%，通过<clientName>.<nameSpace>.zoneAffinity.maxBlackOutServesrPercentage设置
            // 2. zone中的实例平均活跃请求数超过0.6，通过<clientName>.<nameSpace>.zoneAffinity.maxLoadPerServer设置
            // 3. zone中可用实例数小于2，通过<clientName>.<nameSpace>.zoneAffinity.minAvailableServers设置
            if (((double) circuitBreakerTrippedCount) / instanceCount >= blackOutServerPercentageThreshold.getOrDefault()
                    || loadPerServer >= activeReqeustsPerServerThreshold.getOrDefault()
                    || (instanceCount - circuitBreakerTrippedCount) < availableServersThreshold.getOrDefault()) {
                logger.debug("zoneAffinity is overriden. blackOutServerPercentage: {}, activeReqeustsPerServer: {}, availableServers: {}",
                        (double) circuitBreakerTrippedCount / instanceCount, loadPerServer, instanceCount - circuitBreakerTrippedCount);
                return false;
            } else {
                return true;
            }
            
        }
    }

```

### ServerListSubsetFilter

当服务实例的数量过多时（例如几百个），使用它们中的每一个是不可能的，同时保持对它们每一个的连接是没有必要的。因此，负载均衡器可以只从其中一部分子集中进行选择。

`ServerListSubsetFilter`将会持有一个稳定的子集使用，当其中某个服务实例不健康时将会排除它，并从服务实例中选择其他的进行补充。

不健康的定义如下：

1. 并发连接数超过`<clientName>.<nameSpace>.ServerListSubsetFilter.eliminationConnectionThresold`限制，默认0
2. 错误数量超过`<clientName>.<nameSpace>.ServerListSubsetFilter.eliminationFailureThresold`，默认0
3. 如果上面排除的实例数量低于`<clientName>.<nameSpace>.ServerListSubsetFilter.forceEliminatePercent`要求的比例，默认10%，或者剩余服务实例数量高于`<clientName>.<nameSpace>.ServerListSubsetFilter.size`限制，默认20，那么剩余的服务实例将会被排序，并移除健康状况最差的几个实例，以满足预设的阈值。

如果实例数量低于预设阈值，那么将从父类过滤后的服务实例列表中随机选择增加到当前列表中。

```java
    /**
     * Given all the servers, keep only a stable subset of servers to use. This method
     * keeps the current list of subset in use and keep returning the same list, with exceptions
     * to relatively unhealthy servers, which are defined as the following:
     * <p>
     * <ul>
     * <li>Servers with their concurrent connection count exceeding the client configuration for 
     *  {@code <clientName>.<nameSpace>.ServerListSubsetFilter.eliminationConnectionThresold} (default is 0)
     * <li>Servers with their failure count exceeding the client configuration for 
     *  {@code <clientName>.<nameSpace>.ServerListSubsetFilter.eliminationFailureThresold}  (default is 0)
     *  <li>If the servers evicted above is less than the forced eviction percentage as defined by client configuration
     *   {@code <clientName>.<nameSpace>.ServerListSubsetFilter.forceEliminatePercent} (default is 10%, or 0.1), the
     *   remaining servers will be sorted by their health status and servers will worst health status will be
     *   forced evicted.
     * </ul>
     * <p>
     * After the elimination, new servers will be randomly chosen from all servers pool to keep the
     * number of the subset unchanged. 
     * 
     */
    @Override
    public List<T> getFilteredListOfServers(List<T> servers) {
        List<T> zoneAffinityFiltered = super.getFilteredListOfServers(servers);
        Set<T> candidates = Sets.newHashSet(zoneAffinityFiltered);
        Set<T> newSubSet = Sets.newHashSet(currentSubset);
        LoadBalancerStats lbStats = getLoadBalancerStats();
        // 从当前子集中排除不属于父类过滤出的以及连接数和错误数超过阈值的
        for (T server: currentSubset) {
            // this server is either down or out of service
            if (!candidates.contains(server)) {
                newSubSet.remove(server);
            } else {
                ServerStats stats = lbStats.getSingleServerStat(server);
                // remove the servers that do not meet health criteria
                if (stats.getActiveRequestsCount() > eliminationConnectionCountThreshold.getOrDefault()
                        || stats.getFailureCount() > eliminationFailureCountThreshold.getOrDefault()) {
                    newSubSet.remove(server);
                    // also remove from the general pool to avoid selecting them again
                    candidates.remove(server);
                }
            }
        }
        // 20
        int targetedListSize = sizeProp.getOrDefault();
        int numEliminated = currentSubset.size() - newSubSet.size();
        int minElimination = (int) (targetedListSize * eliminationPercent.getOrDefault());
        int numToForceEliminate = 0;
        if (targetedListSize < newSubSet.size()) {
            // size is shrinking
            numToForceEliminate = newSubSet.size() - targetedListSize;
        } else if (minElimination > numEliminated) {
            numToForceEliminate = minElimination - numEliminated; 
        }
        
        if (numToForceEliminate > newSubSet.size()) {
            numToForceEliminate = newSubSet.size();
        }

        if (numToForceEliminate > 0) {
            List<T> sortedSubSet = Lists.newArrayList(newSubSet);           
            sortedSubSet.sort(this);
            List<T> forceEliminated = sortedSubSet.subList(0, numToForceEliminate);
            newSubSet.removeAll(forceEliminated);
            candidates.removeAll(forceEliminated);
        }
        
        // after forced elimination or elimination of unhealthy instances,
        // the size of the set may be less than the targeted size,
        // then we just randomly add servers from the big pool
        if (newSubSet.size() < targetedListSize) {
            int numToChoose = targetedListSize - newSubSet.size();
            candidates.removeAll(newSubSet);
            if (numToChoose > candidates.size()) {
                // Not enough healthy instances to choose, fallback to use the
                // total server pool
                candidates = Sets.newHashSet(zoneAffinityFiltered);
                candidates.removeAll(newSubSet);
            }
            List<T> chosen = randomChoose(Lists.newArrayList(candidates), numToChoose);
            newSubSet.addAll(chosen);
        }
        currentSubset = newSubSet;       
        return Lists.newArrayList(newSubSet);            
    }

```

## rule

拥有服务实例列表后，负载均衡器需要合适的策略以决定选择哪一个服务实例。除此以外，负载均衡器还需要能够确定服务实例是否健康，否则将会产生无效请求。

`ribbon`提供了丰富的负载均衡策略，如下所示：

![](imageibbon-rule.png)

`IRule`接口定义如下：

```java
/**
 * Interface that defines a "Rule" for a LoadBalancer. A Rule can be thought of
 * as a Strategy for loadbalacing. Well known loadbalancing strategies include
 * Round Robin, Response Time based etc.
 * 
 * @author stonse
 * 
 */
public interface IRule {
    /*
     * choose one alive server from lb.allServers or
     * lb.upServers according to key
     * 
     * @return choosen Server object. NULL is returned if none
     *  server is available 
     */

    public Server choose(Object key);
    
    public void setLoadBalancer(ILoadBalancer lb);
    
    public ILoadBalancer getLoadBalancer();    
}

```

### WeightedResponseTimeRule

`WeightedResponseTimeRule`是根据请求的平均响应时间作为权重选择的负载均衡策略，这个策略的想法来自于JCS。

假设我们有四个`endpoints`：A(wt=10), B(wt=30), C(wt=40), D(wt=20)。使用随机数API从1到10+30+40+20之间产生一个随机数，基于给定的权重，我们有如下间隔：

- 1-----10 (A's weight)
- 11----40 (A's weight + B's weight)
- 41----80 (A's weight + B's weight + C's weight)
- 81----100 (A's weight + B's weight + C's weight + C's weight)

当生成的随机数处于某个间隔中时，将选择对应的服务实例。

构造`WeightedResponseTimeRule`时，将会调用其`initialize(ILoadBalancer)`方法进行初始化，并通过`ServerWeight#maintainWeights`方法确定服务实例的权重，同时增加一个定时任务重新计算权重。

```java
    void initialize(ILoadBalancer lb) {        
        if (serverWeightTimer != null) {
            serverWeightTimer.cancel();
        }
        serverWeightTimer = new Timer("NFLoadBalancer-serverWeightTimer-" + name, true);
        serverWeightTimer.schedule(new DynamicServerWeightTask(), 0,
                serverWeightTaskTimerInterval);
        // do a initial run
        ServerWeight sw = new ServerWeight();
        sw.maintainWeights();

        Runtime.getRuntime().addShutdownHook(new Thread(new Runnable() {
            public void run() {
                logger.info("Stopping NFLoadBalancer-serverWeightTimer-" + name);
                serverWeightTimer.cancel();
            }
        }));
    }

    class ServerWeight {

        public void maintainWeights() {
            ILoadBalancer lb = getLoadBalancer();
            if (lb == null) {
                return;
            }
            
            if (!serverWeightAssignmentInProgress.compareAndSet(false,  true))  {
                return; 
            }
            
            try {
                logger.info("Weight adjusting job started");
                AbstractLoadBalancer nlb = (AbstractLoadBalancer) lb;
                LoadBalancerStats stats = nlb.getLoadBalancerStats();
                if (stats == null) {
                    // no statistics, nothing to do
                    return;
                }
                double totalResponseTime = 0;
                // find maximal 95% response time
                for (Server server : nlb.getAllServers()) {
                    // this will automatically load the stats if not in cache
                    ServerStats ss = stats.getSingleServerStat(server);
                    totalResponseTime += ss.getResponseTimeAvg();
                }
                // weight for each server is (sum of responseTime of all servers - responseTime)
                // so that the longer the response time, the less the weight and the less likely to be chosen
                Double weightSoFar = 0.0;
                
                // create new list and hot swap the reference
                List<Double> finalWeights = new ArrayList<Double>();
                for (Server server : nlb.getAllServers()) {
                    ServerStats ss = stats.getSingleServerStat(server);
                    double weight = totalResponseTime - ss.getResponseTimeAvg();
                    weightSoFar += weight;
                    finalWeights.add(weightSoFar);   
                }
                setWeights(finalWeights);
            } catch (Exception e) {
                logger.error("Error calculating server weights", e);
            } finally {
                serverWeightAssignmentInProgress.set(false);
            }

        }
    }
```

服务实例的平均响应时间越短，其权重越大。初始选择时，由于没有足够的数据，因此会先使用其父类的轮询策略，等到所有服务实例的数据收集完毕后，才使用响应时间权重策略。

```java
    public Server choose(ILoadBalancer lb, Object key) {
        if (lb == null) {
            return null;
        }
        Server server = null;

        while (server == null) {
            // get hold of the current reference in case it is changed from the other thread
            List<Double> currentWeights = accumulatedWeights;
            if (Thread.interrupted()) {
                return null;
            }
            List<Server> allList = lb.getAllServers();

            int serverCount = allList.size();

            if (serverCount == 0) {
                return null;
            }

            int serverIndex = 0;

            // last one in the list is the sum of all weights
            double maxTotalWeight = currentWeights.size() == 0 ? 0 : currentWeights.get(currentWeights.size() - 1); 
            // No server has been hit yet and total weight is not initialized
            // fallback to use round robin
            if (maxTotalWeight < 0.001d || serverCount != currentWeights.size()) {
                server =  super.choose(getLoadBalancer(), key);
                if(server == null) {
                    return server;
                }
            } else {
                // generate a random weight between 0 (inclusive) to maxTotalWeight (exclusive)
                double randomWeight = random.nextDouble() * maxTotalWeight;
                // pick the server index based on the randomIndex
                int n = 0;
                for (Double d : currentWeights) {
                    if (d >= randomWeight) {
                        serverIndex = n;
                        break;
                    } else {
                        n++;
                    }
                }

                server = allList.get(serverIndex);
            }

            if (server == null) {
                /* Transient. */
                Thread.yield();
                continue;
            }

            if (server.isAlive()) {
                return (server);
            }

            // Next.
            server = null;
        }
        return server;
    }
```

### BestAvailableRule

`BestAvailableRule`策略会跳过被断路器阻塞的服务实例，然后在剩余服务实例中挑选一个当前并发请求数最少的服务实例。

这个策略应该与`ServerListSubsetFilter`过滤器一起工作，因为此过滤器会提供一个服务实例列表的子集，此时这个策略只会在小范围内的列表中选择，因此虽然需要进行全量扫描，性能上并不会受到影响。

```java
    @Override
    public Server choose(Object key) {
        if (loadBalancerStats == null) {
            return super.choose(key);
        }
        List<Server> serverList = getLoadBalancer().getAllServers();
        int minimalConcurrentConnections = Integer.MAX_VALUE;
        long currentTime = System.currentTimeMillis();
        Server chosen = null;
        for (Server server: serverList) {
            ServerStats serverStats = loadBalancerStats.getSingleServerStat(server);
            if (!serverStats.isCircuitBreakerTripped(currentTime)) {
                int concurrentConnections = serverStats.getActiveRequestsCount(currentTime);
                if (concurrentConnections < minimalConcurrentConnections) {
                    minimalConcurrentConnections = concurrentConnections;
                    chosen = server;
                }
            }
        }
        if (chosen == null) {
            return super.choose(key);
        } else {
            return chosen;
        }
    }

```

内置的断路器规则基于连接失败的次数，当超过给定阈值时，会根据错误次数通过二进制后退算法设置一个断路时间。

```java
    public boolean isCircuitBreakerTripped(long currentTime) {
        long circuitBreakerTimeout = getCircuitBreakerTimeout();
        if (circuitBreakerTimeout <= 0) {
            return false;
        }
        return circuitBreakerTimeout > currentTime;
    }

    // 获取断路结束时间，未被断路返回0
    private long getCircuitBreakerTimeout() {
        long blackOutPeriod = getCircuitBreakerBlackoutPeriod();
        if (blackOutPeriod <= 0) {
            return 0;
        }
        return lastConnectionFailedTimestamp + blackOutPeriod;
    }
    
    // 获取断路时间
    private long getCircuitBreakerBlackoutPeriod() {
        int failureCount = successiveConnectionFailureCount.get();
        int threshold = connectionFailureThreshold.get();
        if (failureCount < threshold) {
            return 0;
        }
        int diff = Math.min(failureCount - threshold, 16);
        int blackOutSeconds = (1 << diff) * circuitTrippedTimeoutFactor.get();
        if (blackOutSeconds > maxCircuitTrippedTimeout.get()) {
            blackOutSeconds = maxCircuitTrippedTimeout.get();
        }
        return blackOutSeconds * 1000L;
    }
```

### AvailabilityFilteringRule

`AvailabilityFilteringRule`策略与`BestAvailableRule`相似，唯一一个轻微的不同之处是它不选择并发请求数最少的实例，只要当前服务实例没有被断路器断路并且并发请求数低于给定的阈值（默认为`Integer.MAX_VALUE`）即可被选中。这个阈值可以通过`<clientName>.<nameSpace>.ActiveConnectionsLimit`配置属性设置。

```java
    /**
     * This method is overridden to provide a more efficient implementation which does not iterate through
     * all servers. This is under the assumption that in most cases, there are more available instances 
     * than not. 
     */
    @Override
    public Server choose(Object key) {
        int count = 0;
        Server server = roundRobinRule.choose(key);
        while (count++ <= 10) {
            if (server != null && predicate.apply(new PredicateKey(server))) {
                return server;
            }
            server = roundRobinRule.choose(key);
        }
        return super.choose(key);
    }

    @Override
    public boolean apply(@Nullable PredicateKey input) {
        LoadBalancerStats stats = getLBStats();
        if (stats == null) {
            return true;
        }
        return !shouldSkipServer(stats.getSingleServerStat(input.getServer()));
    }
    
    private boolean shouldSkipServer(ServerStats stats) {
        if ((circuitBreakerFiltering.getOrDefault() && stats.isCircuitBreakerTripped())
                || stats.getActiveRequestsCount() >= getActiveConnectionsLimit()) {
            return true;
        }
        return false;
    }

```

### ZoneAvoidanceRule

`ZoneAvoidanceRule`策略以`zone`为基本单位（每个服务实例都会处于某个`zone`内）进行选择。测量`zone`状况的核心指标是服务实例平均活跃请求数，它由`zone`中有所有可用的服务实例（即排除被断路器断路的服务实例）的活跃请求数除以可用服务实例数量得到。当某个`zone`中存在超时连接时这个指标非常有效。

`ZoneAvoidanceRule`将会检查所有可用的`zone`，当某个`zone`的平均获取请求数超过阈值时，它将会被抛弃。如果存在多个超过阈值的`zone`，将随机抛弃其中某个`zone`。然后，`ZoneAvoidanceRule`判断给定的服务实例列表是否处于剩余的`zone`中，并使用轮询策略选择最终的服务实例。

```java
public ZoneAvoidanceRule() {
        ZoneAvoidancePredicate zonePredicate = new ZoneAvoidancePredicate(this);
        AvailabilityPredicate availabilityPredicate = new AvailabilityPredicate(this);
        compositePredicate = createCompositePredicate(zonePredicate, availabilityPredicate);
    }
    
    private CompositePredicate createCompositePredicate(ZoneAvoidancePredicate p1, AvailabilityPredicate p2) {
        return CompositePredicate.withPredicates(p1, p2)
                             .addFallbackPredicate(p2)
                             .addFallbackPredicate(AbstractServerPredicate.alwaysTrue())
                             .build();
    }

```

`ZoneAvoidanceRule`由`ZoneAvoidancePredicate`和`AvailabilityPredicate`共同过滤，并增加`AvailabilityPredicate`和`AbstractServerPredicate.alwaysTrue()`作为回调。

`ZoneAvoidancePredicate`的实现如下所示：

```java
ZoneAvoidancePredicate.java

    /**
     * zone平均连接数阈值
     */
    private static final IClientConfigKey<Double> TRIGGERING_LOAD_PER_SERVER_THRESHOLD = new CommonClientConfigKey<Double>(
            "ZoneAwareNIWSDiscoveryLoadBalancer.%s.triggeringLoadPerServerThreshold", 0.2d) {};

    /**
     * 断路实例占比阈值
     */
    private static final IClientConfigKey<Double> AVOID_ZONE_WITH_BLACKOUT_PERCENTAGE = new CommonClientConfigKey<Double>(
            "ZoneAwareNIWSDiscoveryLoadBalancer.%s.avoidZoneWithBlackoutPercetage", 0.99999d) {};


    @Override
    public boolean apply(@Nullable PredicateKey input) {
        if (!enabled.getOrDefault()) {
            return true;
        }
        String serverZone = input.getServer().getZone();
        if (serverZone == null) {
            // there is no zone information from the server, we do not want to filter
            // out this server
            return true;
        }
        LoadBalancerStats lbStats = getLBStats();
        if (lbStats == null) {
            // no stats available, do not filter
            return true;
        }
        if (lbStats.getAvailableZones().size() <= 1) {
            // only one zone is available, do not filter
            return true;
        }
        Map<String, ZoneSnapshot> zoneSnapshot = ZoneAvoidanceRule.createSnapshot(lbStats);
        if (!zoneSnapshot.keySet().contains(serverZone)) {
            // The server zone is unknown to the load balancer, do not filter it out 
            return true;
        }
        logger.debug("Zone snapshots: {}", zoneSnapshot);
        Set<String> availableZones = ZoneAvoidanceRule.getAvailableZones(zoneSnapshot, triggeringLoad.getOrDefault(), triggeringBlackoutPercentage.getOrDefault());
        logger.debug("Available zones: {}", availableZones);
        if (availableZones != null) {
            return availableZones.contains(input.getServer().getZone());
        } else {
            return false;
        }
    }    

=============================================================

ZoneAvoidanceRule.java

    public static Set<String> getAvailableZones(
            Map<String, ZoneSnapshot> snapshot, double triggeringLoad,
            double triggeringBlackoutPercentage) {
        if (snapshot.isEmpty()) {
            return null;
        }
        Set<String> availableZones = new HashSet<String>(snapshot.keySet());
        if (availableZones.size() == 1) {
            return availableZones;
        }
        Set<String> worstZones = new HashSet<String>();
        double maxLoadPerServer = 0;
        boolean limitedZoneAvailability = false;

        for (Map.Entry<String, ZoneSnapshot> zoneEntry : snapshot.entrySet()) {
            String zone = zoneEntry.getKey();
            ZoneSnapshot zoneSnapshot = zoneEntry.getValue();
            int instanceCount = zoneSnapshot.getInstanceCount();
            if (instanceCount == 0) {
                availableZones.remove(zone);
                limitedZoneAvailability = true;
            } else {
                double loadPerServer = zoneSnapshot.getLoadPerServer();
                // 被断路的实例比例超过阈值或者全部都被断路
                if (((double) zoneSnapshot.getCircuitTrippedCount())
                        / instanceCount >= triggeringBlackoutPercentage
                        || loadPerServer < 0) {
                    availableZones.remove(zone);
                    limitedZoneAvailability = true;
                } else {
                    // 寻找当前平均连接数最多的zone
                    if (Math.abs(loadPerServer - maxLoadPerServer) < 0.000001d) {
                        // they are the same considering double calculation
                        // round error
                        worstZones.add(zone);
                    } else if (loadPerServer > maxLoadPerServer) {
                        maxLoadPerServer = loadPerServer;
                        worstZones.clear();
                        worstZones.add(zone);
                    }
                }
            }
        }

        if (maxLoadPerServer < triggeringLoad && !limitedZoneAvailability) {
            // zone override is not needed here
            return availableZones;
        }
        String zoneToAvoid = randomChooseZone(snapshot, worstZones);
        if (zoneToAvoid != null) {
            availableZones.remove(zoneToAvoid);
        }
        return availableZones;

    }
```

## ping

以上组件组成了负载均衡器的核心功能，但是还有一个可选组件`IPing`。顾名思义，它用于检查能够与目标服务实例正常通信，并作为服务实例是否健康的指标。当然，向服务实例集群发送真实的HTTP请求会产生较大的开销，可能还需要你预定义一个用于健康检查的`path`。除此以外，还可以请求注册中心的内存缓存以检查服务实例是否在线，虽然实时性准确性略低，但是更加快捷。

`IPing`接口的定义如下：

```java
public interface IPing {
    
    /**
     * Checks whether the given <code>Server</code> is "alive" i.e. should be
     * considered a candidate while loadbalancing
     * 
     */
    public boolean isAlive(Server server);
}
```

`IPing`接口的继承体系如下：

![](imageibbon-ping.png)

它的子类实现都非常简单，不多赘述。


## composite

最后，将这些组件组合在一起，即可获得一个完整的负载均衡器。

`ILoadBalancer`接口的定义如下：

```java
/**
 * Interface that defines the operations for a software loadbalancer. A typical
 * loadbalancer minimally need a set of servers to loadbalance for, a method to
 * mark a particular server to be out of rotation and a call that will choose a
 * server from the existing list of server.
 * 
 * @author stonse
 * 
 */
public interface ILoadBalancer {

	/**
	 * Initial list of servers.
	 * This API also serves to add additional ones at a later time
	 * The same logical server (host:port) could essentially be added multiple times
	 * (helpful in cases where you want to give more "weightage" perhaps ..)
	 * 
	 * @param newServers new servers to add
	 */
	public void addServers(List<Server> newServers);
	
	/**
	 * Choose a server from load balancer.
	 * 
	 * @param key An object that the load balancer may use to determine which server to return. null if 
	 *         the load balancer does not use this parameter.
	 * @return server chosen
	 */
	public Server chooseServer(Object key);
	
	/**
	 * To be called by the clients of the load balancer to notify that a Server is down
	 * else, the LB will think its still Alive until the next Ping cycle - potentially
	 * (assuming that the LB Impl does a ping)
	 * 
	 * @param server Server to mark as down
	 */
	public void markServerDown(Server server);
	
	/**
	 * @deprecated 2016-01-20 This method is deprecated in favor of the
	 * cleaner {@link #getReachableServers} (equivalent to availableOnly=true)
	 * and {@link #getAllServers} API (equivalent to availableOnly=false).
	 *
	 * Get the current list of servers.
	 *
	 * @param availableOnly if true, only live and available servers should be returned
	 */
	@Deprecated
	public List<Server> getServerList(boolean availableOnly);

	/**
	 * @return Only the servers that are up and reachable.
     */
    public List<Server> getReachableServers();

    /**
     * @return All known servers, both reachable and unreachable.
     */
	public List<Server> getAllServers();
}

```

它的方法定义也相当直观，大部分方法都是操作服务实例列表，核心方法为`Server chooseServer(Object key)`。

![](imageibbon-loadbalance.png)

`BaseLoadBalancer`实现提供了最基础的负载均衡器实现，默认采用轮询策略。

```java
    public BaseLoadBalancer(String name, IRule rule, LoadBalancerStats stats,
            IPing ping, IPingStrategy pingStrategy) {
	
        logger.debug("LoadBalancer [{}]:  initialized", name);
        
        this.name = name;
        this.ping = ping;
        this.pingStrategy = pingStrategy;
        setRule(rule);
        setupPingTask();
        lbStats = stats;
        init();
    }

    public BaseLoadBalancer(IClientConfig config) {
        initWithNiwsConfig(config);
    }
```

`BaseLoadBalancer`要求使用者自己通过调用`addServer`方法提供服务实例列表，当然作为一个基类这也无可厚非。`BaseLoadBalancer`还提供了一个重要的特性，即当服务实例列表发生变化时，它会和服务实例进行预热。这个过程是同步的，会导致程序阻塞。默认情况下它会通过path `/`请求目标服务实例，对于每个实例的请求可以被异步化，以加速预热过程。不过，预热功能默认是关闭的，你可以通过`<clientName>.<nameSpace>.EnablePrimeConnections`配置项启用。

`DynamicServerListLoadBalancer`引入了`ServerList`和`ServerListFilter`。当`DynamicServerListLoadBalancer`构造时，它会请求`ServerList`接口获取服务列表，并使用`ServerListFilter`进行过滤。默认的`ServerList`实现为`ConfigurationBasedServerList`，默认的`ServerListFilter`实现为`ZoneAffinityServerListFilter`。除此以外，它还会使用`ServerListUpdater`进行服务实例列表的动态更新，默认的实现为`PollingServerListUpdater`，它被构建为一个定时任务，每隔一段时间执行一次更新。

`ZoneAwareLoadBalancer`在`DynamicServerListLoadBalancer`的基础上引入了`zone`，它会根据`ZoneAvoidanceRule`先过滤出可用的`zone`，然后从中随机选择一个`zone`，并在这个`zone`中进行选择。

| | 配置项| 默认 |
| :-: | :-: | :-: |
| 负载均衡器实现 | NFLoadBalancerClassName | com.netflix.loadbalancer.ZoneAwareLoadBalancer |
| 负载均衡策略 | NFLoadBalancerRuleClassName | com.netflix.loadbalancer.AvailabilityFilteringRule |
| IPing实现 | NFLoadBalancerPingClassName | com.netflix.loadbalancer.DummyPing |
| ServerList实现 | NIWSServerListClassName | com.netflix.loadbalancer.ConfigurationBasedServerList |
| ServerListUpdater实现 | ServerListUpdaterClassName | com.netflix.loadbalancer.PollingServerListUpdater |
| ServerListFilter实现 | NIWSServerListFilterClassName | com.netflix.loadbalancer.ZoneAffinityServerListFilter |

# integrate with eureka

`ribbon`在`ribbon-eureka`模块提供了与`Eureka`整合的拓展类，主要包括`IPing`，`ServerList`，`ServerListUpdater`三个组件的实现。

## NIWSDiscoveryPing

由于`Eureka`本身记录了实例的健康状态，因此只要判断服务实例的状态是否为`UP`，即可决定实例是否存活。

```java
    public boolean isAlive(Server server) {
        boolean isAlive = true;
        if (server != null && server instanceof DiscoveryEnabledServer) {
            DiscoveryEnabledServer dServer = (DiscoveryEnabledServer) server;
            InstanceInfo instanceInfo = dServer.getInstanceInfo();
            if (instanceInfo != null) {
                InstanceStatus status = instanceInfo.getStatus();
                if (status != null) {
                    isAlive = status.equals(InstanceStatus.UP);
                }
            }
        }
        return isAlive;
    }
```

## DiscoveryEnabledNIWSServerList

当客户端以消费者的身份向`Eureka`注册后，即可获取到当前可用的服务列表。`DiscoveryEnabledNIWSServerList`要求设置一组`VIPAddress`，当获取服务实例列表时，将会调用`EurekaClient#getInstancesByVipAddress(String vipAddress, boolean secure, @Nullable String region)`方法。

## EurekaNotificationServerListUpdater

由于`Eureka`在本地维护的服务实例列表缓存发生变化时发出`CacheRefreshedEvent`事件，因此`EurekaNotificationServerListUpdater`只需要注册一个监听器监听此事件即可。