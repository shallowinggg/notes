SpringBoot常规启动方式：

```java
    public static void main(String[] args) {
        SpringApplication.run(DemoApplication.class, args);
    }
```

```java
	public static ConfigurableApplicationContext run(Class<?> primarySource, String... args) {
		return run(new Class<?>[] { primarySource }, args);
	}

	public static ConfigurableApplicationContext run(Class<?>[] primarySources, String[] args) {
		return new SpringApplication(primarySources).run(args);
	}
```

## 构造SpringApplication

```java
    public SpringApplication(Class<?>... primarySources) {
		this(null, primarySources);
	}

	public SpringApplication(ResourceLoader resourceLoader, Class<?>... primarySources) {
		this.resourceLoader = resourceLoader;
		Assert.notNull(primarySources, "PrimarySources must not be null");
		this.primarySources = new LinkedHashSet<>(Arrays.asList(primarySources));
        // 从classpath中推测应用类型
		this.webApplicationType = WebApplicationType.deduceFromClasspath();
        // 从spring.factoreis文件读取ApplicationContextInitializer实例
		setInitializers((Collection) getSpringFactoriesInstances(ApplicationContextInitializer.class));
        // 从spring.factoreis文件读取ApplicationListener实例
		setListeners((Collection) getSpringFactoriesInstances(ApplicationListener.class));
        // 从栈轨迹推测mainApplicationClass
		this.mainApplicationClass = deduceMainApplicationClass();
	}
```

应用类型共有下面三种：

- SERVLET
- REACTIVE
- NONE

只需要在classpath中查询是否存在对应的核心基础类，即可判断应用类型。

```java
	private static final String[] SERVLET_INDICATOR_CLASSES = { "javax.servlet.Servlet",
			"org.springframework.web.context.ConfigurableWebApplicationContext" };

	private static final String WEBMVC_INDICATOR_CLASS = "org.springframework.web.servlet.DispatcherServlet";

	private static final String WEBFLUX_INDICATOR_CLASS = "org.springframework.web.reactive.DispatcherHandler";

	private static final String JERSEY_INDICATOR_CLASS = "org.glassfish.jersey.servlet.ServletContainer";

	static WebApplicationType deduceFromClasspath() {
		if (ClassUtils.isPresent(WEBFLUX_INDICATOR_CLASS, null) && !ClassUtils.isPresent(WEBMVC_INDICATOR_CLASS, null)
				&& !ClassUtils.isPresent(JERSEY_INDICATOR_CLASS, null)) {
			return WebApplicationType.REACTIVE;
		}
		for (String className : SERVLET_INDICATOR_CLASSES) {
			if (!ClassUtils.isPresent(className, null)) {
				return WebApplicationType.NONE;
			}
		}
		return WebApplicationType.SERVLET;
	}
```

## 启动

```java
	public ConfigurableApplicationContext run(String... args) {
        // 计时
		StopWatch stopWatch = new StopWatch();
		stopWatch.start();
		ConfigurableApplicationContext context = null;
		Collection<SpringBootExceptionReporter> exceptionReporters = new ArrayList<>();
        // 设置java.awt.headless属性，默认为true
		configureHeadlessProperty();
        // 从spring.factoreis文件读取SpringApplicationRunListener实例
		SpringApplicationRunListeners listeners = getRunListeners(args);
        // 发出ApplicationStartingEvent事件
		listeners.starting();
		try {
            // 使用args构造SimpleCommandLinePropertySource
			ApplicationArguments applicationArguments = new DefaultApplicationArguments(args);
            // 初始化应用环境
			ConfigurableEnvironment environment = prepareEnvironment(listeners, applicationArguments);
			configureIgnoreBeanInfo(environment);
            // 打印横幅
			Banner printedBanner = printBanner(environment);
            // 根据应用类型构造ApplicationContext
			context = createApplicationContext();
            // 从spring.factoreis文件读取SpringBootExceptionReporter实例，启动失败时报告失败原因
			exceptionReporters = getSpringFactoriesInstances(SpringBootExceptionReporter.class,
					new Class[] { ConfigurableApplicationContext.class }, context);
            // 准备ApplicationContext
			prepareContext(context, environment, listeners, applicationArguments, printedBanner);
            // refresh ApplicationContext
			refreshContext(context);
			afterRefresh(context, applicationArguments);
			stopWatch.stop();
			if (this.logStartupInfo) {
				new StartupInfoLogger(this.mainApplicationClass).logStarted(getApplicationLog(), stopWatch);
			}
			listeners.started(context);
			callRunners(context, applicationArguments);
		}
		catch (Throwable ex) {
			handleRunFailure(context, ex, exceptionReporters, listeners);
			throw new IllegalStateException(ex);
		}

		try {
			listeners.running(context);
		}
		catch (Throwable ex) {
			handleRunFailure(context, ex, exceptionReporters, null);
			throw new IllegalStateException(ex);
		}
		return context;
	}
```

| 监听器 | 监听事件 | 主要作用 |
| :-: | :-: | :-: |
| org.springframework.boot.ClearCachesApplicationListener | ContextRefreshedEvent | 清空`ReflectionUtils`以及`ClassLoader`的缓存 |
| org.springframework.boot.builder.ParentContextCloserApplicationListener | ParentContextAvailableEvent | 父容器关闭时，让子容器也随之关闭 |
| org.springframework.boot.cloud.CloudFoundryVcapEnvironmentPostProcessor | ApplicationPreparedEvent | |
| org.springframework.boot.context.FileEncodingApplicationListener | ApplicationEnvironmentPreparedEvent | 检查文件编码，`file.encoding`和`spring.mandatory-file-encoding`必须相同 |
| org.springframework.boot.context.config.AnsiOutputApplicationListener | ApplicationEnvironmentPreparedEvent | 控制台输出彩色日志 | 
| org.springframework.boot.context.config.ConfigFileApplicationListener | ApplicationEnvironmentPreparedEvent, ApplicationPreparedEvent | 读取application.properties / yaml文件 |
| org.springframework.boot.context.config.DelegatingApplicationListener | ApplicationEvent | 读取通过`context.listener.classes`配置的`ApplicationListener`，并将事件转发 |
| org.springframework.boot.context.logging.ClasspathLoggingApplicationListener | ApplicationEnvironmentPreparedEvent, ApplicationFailedEvent | 如果启用了`DEBUG`日志，打印当前classpath |
| org.springframework.boot.context.logging.LoggingApplicationListener | ApplicationStartingEvent, ApplicationEnvironmentPreparedEvent, ApplicationPreparedEvent, ContextClosedEvent, ApplicationFailedEvent | 配置日志系统 |
| org.springframework.boot.liquibase.LiquibaseServiceLocatorApplicationListener | ApplicationStartingEvent | 配置liquibase ServiceLocator，如果存在 |
| org.springframework.boot.autoconfigure.BackgroundPreinitializer | ApplicationStartingEvent | 开启一个新线程执行一些资源的预先初始化工作 |

### 准备环境

```java
	private ConfigurableEnvironment prepareEnvironment(SpringApplicationRunListeners listeners,
			ApplicationArguments applicationArguments) {
		// 根据应用类型获取环境
		ConfigurableEnvironment environment = getOrCreateEnvironment();
        // 配置环境
		configureEnvironment(environment, applicationArguments.getSourceArgs());
		ConfigurationPropertySources.attach(environment);
		listeners.environmentPrepared(environment);
		bindToSpringApplication(environment);
		if (!this.isCustomEnvironment) {
			environment = new EnvironmentConverter(getClassLoader()).convertEnvironmentIfNecessary(environment,
					deduceEnvironmentClass());
		}
		ConfigurationPropertySources.attach(environment);
		return environment;
	}
```

```java
	private ConfigurableEnvironment getOrCreateEnvironment() {
		if (this.environment != null) {
			return this.environment;
		}
		switch (this.webApplicationType) {
		case SERVLET:
			return new StandardServletEnvironment();
		case REACTIVE:
			return new StandardReactiveWebEnvironment();
		default:
			return new StandardEnvironment();
		}
	}
```

```java
	protected void configureEnvironment(ConfigurableEnvironment environment, String[] args) {
        // 增加类型转换服务
		if (this.addConversionService) {
			ConversionService conversionService = ApplicationConversionService.getSharedInstance();
			environment.setConversionService((ConfigurableConversionService) conversionService);
		}
		configurePropertySources(environment, args);
		configureProfiles(environment, args);
	}
```