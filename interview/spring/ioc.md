---
layout: default
title: IoC
parent: spring
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

# Spring IoC

## Spring IoC启动过程

### 解析xml文件
```
parseDefaultElement(Element ele, BeanDefinitionParserDelegate delegate); 解析默认空间标签
    processBeanDefinition(ele, delegate); 解析bean标签
        delegate.parseBeanDefinitionElement(ele); 进行元素解析，返回BeanDifinitionHolder
            ele.getAttribute(ID_ATTRIBUTE); 解析id属性
            ele.getAttribute(NAME_ATTRIBUTE); 解析name属性
            StringUtils.tokenizeToStringArray(nameAttr, ",; "); 解析alias别名
            如果未指定id属性，选取一个别名作为id
            checkNameUniqueness(beanName, aliases, ele); 检查id以及别名是否被注册过
                this.usedNames.contains(beanName);  检查id是否已被注册
                CollectionUtils.findFirstMatch(this.usedNames, aliases); 检查别名是否已被注册
                this.usedNames.add(beanName); 记录id以及别名
                this.usedNames.addAll(aliases);
            parseBeanDefinitionElement(ele, beanName, containingBean); 解析bean标签元素
                ele.getAttribute(CLASS_ATTRIBUTE).trim(); 解析class属性
                ele.getAttribute(PARENT_ATTRIBUTE); 解析parent属性
                createBeanDefinition(className, parent); 创建BeanDefinition保存配置信息
                parseBeanDefinitionAttributes(ele, beanName, containingBean, bd); 硬编码解析bean的各种属性
                    ele.hasAttribute(SINGLETON_ATTRIBUTE) 禁止使用singleton属性
                    bd.setScope(ele.getAttribute(SCOPE_ATTRIBUTE));  解析并记录scope属性
                    bd.setScope(containingBean.getScope()); 未指定scope尝试解析外部bean scope
                    ele.hasAttribute(ABSTRACT_ATTRIBUTE) 解析abstrct属性
                    ele.getAttribute(LAZY_INIT_ATTRIBUTE); 解析lazy-init属性
                    ele.getAttribute(AUTOWIRE_ATTRIBUTE); 解析autwire属性
                    ele.getAttribute(DEPENDENCY_CHECK_ATTRIBUTE); 解析dependency-check属性
                    ele.getAttribute(DEPENDS_ON_ATTRIBUTE); 解析depends-on属性
                    ele.getAttribute(AUTOWIRE_CANDIDATE_ATTRIBUTE); 解析autowire-candidate属性
                    ele.hasAttribute(PRIMARY_ATTRIBUTE) 解析primary属性
                    ele.hasAttribute(INIT_METHOD_ATTRIBUTE) 解析init-method属性
                    ele.hasAttribute(DESTROY_METHOD_ATTRIBUTE) 解析destroy-method属性
                    ele.hasAttribute(FACTORY_METHOD_ATTRIBUTE) 解析factory-method属性
                    ele.hasAttribute(FACTORY_BEAN_ATTRIBUTE) 解析factor-bean属性
                bd.setDescription(DomUtils.getChildElementValueByTagName(ele, DESCRIPTION_ELEMENT)); 解析description元素
                parseMetaElements(ele, bd); 解析meta元数据
                parseLookupOverrideSubElements(ele, bd.getMethodOverrides()); 解析lookup-method
                parseReplacedMethodSubElements(ele, bd.getMethodOverrides()); 解析replaced-method
                parseConstructorArgElements(ele, bd); 解析constructor-arg子元素
                    ele.getAttribute(INDEX_ATTRIBUTE); 解析index属性
                    ele.getAttribute(TYPE_ATTRIBUTE); 解析type属性
                    ele.getAttribute(NAME_ATTRIBUTE); 解析name属性
                    if (StringUtils.hasLength(indexAttr)) 如果指定了index属性
                        Integer.parseInt(indexAttr); 将字符串解析为int
                        parsePropertyValue(ele, bd, null); 解析其他属性以及子元素
                            解析子元素，略过meta以及description子元素
                            ele.hasAttribute(REF_ATTRIBUTE); 解析ref属性
                            ele.hasAttribute(VALUE_ATTRIBUTE); 解析value属性
                            验证：子元素，ref属性，value属性只能存在一个
                            new RuntimeBeanReference(ele.getAttribute(REF_ATTRIBUTE)); 记录ref属性或者
                            TypedStringValue(ele.getAttribute(VALUE_ATTRIBUTE)); 记录value属性或者
                            parsePropertySubElement(subElement, bd); 解析子元素信息，下面只能存在一个
                                !isDefaultNamespace(ele) 如果子元素不属于默认命名空间
                                parseNestedCustomElement(ele, bd); 解析嵌套的自定义元素
                                parseBeanDefinitionElement(ele, bd); 解析<bean>子元素
                                nodeNameEquals(ele, REF_ELEMENT) 解析ref子元素
                                parseIdRefElement(ele); 解析idref子元素
                                parseValueElement(ele, defaultValueType); 解析value子元素
                                nodeNameEquals(ele, NULL_ELEMENT) 解析<null/>子元素
                                parseArrayElement(ele, bd); 解析array子元素
                                parseListElement(ele, bd); 解析list子元素
                                parseSetElement(ele, bd); 解析set子元素
                                parseMapElement(ele, bd); 解析map子元素
                                parsePropsElement(ele); 解析props子元素
                        addIndexedArgumentValue(index, valueHolder); 封装各种信息并记录到BeanDefinition中
                    未指定index属性
                        parsePropertyValue(ele, bd, null);
                        addGenericArgumentValue(valueHolder); 封装各种信息并记录到BeanDefinition中
                parsePropertyElements(ele, bd); 解析property子元素
                    ele.getAttribute(NAME_ATTRIBUTE); 解析name属性
                    parsePropertyValue(ele, bd, propertyName); 解析其他属性以及子元素
                    parseMetaElements(ele, pv); 解析meta元素
                    addPropertyValue(pv); 保存到BeanDefinition中
                parseQualifierElements(ele, bd); 解析qualify子元素
                    ele.getAttribute(TYPE_ATTRIBUTE); 解析type属性
                    ele.getAttribute(VALUE_ATTRIBUTE); 解析value属性
                    解析attribute子元素
                    addQualifier(qualifier); 保存到BeanDefinition中
		delegate.decorateBeanDefinitionIfRequired(ele, bdHolder); 如果bean标签内存在自定义标签，解析它
                    decorateIfRequired(node, finalDefinition, containingBd); 如果存在自定义属性或者自定义子元素
                        getNamespaceURI(node); 获取命名空间
                        getNamespaceHandlerResolver().resolve(namespaceUri); 根据用户提供的NamespaceHandler处理
                        handler.decorate(node, ...);
		registerBeanDefinition(bdHolder, getReaderContext().getRegistry()); 注册bean定义
                    registerBeanDefinition(beanName, definitionHolder.getBeanDefinition()); 通过id注册
                        ((AbstractBeanDefinition) beanDefinition).validate(); 验证bean合法性，方法注入和factory方法不能同时存在
                        如果已存在此bean，允许覆盖则覆盖
                        否则，直接加入到map中
                    registerAlias(beanName, alias); 通过别名注册
                        如果别名已被注册，覆盖
                        checkForAliasCircle(name, alias); 检查别名循环引用
                        this.aliasMap.put(alias, name); 加入别名表中
		getReaderContext().fireComponentRegistered(new BeanComponentDefinition(bdHolder)); 发布注册事件，空实现
	processAliasRegistration(ele); 解析alias标签
            ele.getAttribute(NAME_ATTRIBUTE); 解析name属性
            ele.getAttribute(ALIAS_ATTRIBUTE); 解析alias属性
            registerAlias(name, alias); 注册别名
            getReaderContext().fireAliasRegistered(name, alias, extractSource(ele)); 发布注册事件，空实现
	importBeanDefinitionResource(ele); 解析import标签
            ele.getAttribute(RESOURCE_ATTRIBUTE); 解析resources属性
            resolveRequiredPlaceholders(location); 解析系统属性[占位符]
            ResourcePatternUtils.isUrl(location) || ResourceUtils.toURI(location).isAbsolute(); 判断是绝对路径还是相对路径
            loadBeanDefinitions(location, actualResources); 加载配置文件
            getReaderContext().fireImportProcessed(location, actResArray, extractSource(ele)); 发布注册事件，空实现
	doRegisterBeanDefinitions(ele); 解析beans标签，与前面调用的是一个方法，从profile开始解析
```

### 解析自定义标签
```
parseCustomElement(root); 解析自定义bean
    getNamespaceURI(ele); 获取命名空间
    this.readerContext.getNamespaceHandlerResolver().resolve(namespaceUri); 通过解析命名空间获取NamespaceHandler
        getHandlerMappings(); 获取HandlerMappings
            if (this.handlerMappings == null) 如果handlerMappings未初始化，读取Spring.handlers
                PropertiesLoaderUtils.loadAllProperties(this.handlerMappingsLocation, this.classLoader);
        handlerMappings.get(namespaceUri); 从handlerMappings中根据命名空间查找对应的NamespaceHandler
        如果解析过，直接从缓存中读取
        否则，通过类名实例化
            ClassUtils.forName(className, this.classLoader); 通过反射获取Class对象
            BeanUtils.instantiateClass(handlerClass); 实例化类
            namespaceHandler.init(); 调用此类的init方法
            handlerMappings.put(namespaceUri, namespaceHandler); 记录在缓存中
    handler.parse(ele, new ParserContext(this.readerContext, this, containingBd)); 调用父类NamespaceHandlerSupport的parse方法解析
        findParserForElement(element, parserContext).parse(element, parserContext);
        $findParserForElement(element, parserContext); 寻找自定义解析器，在前面的namespaceHandler.init()方法中注册
            parserContext.getDelegate().getLocalName(element); 获取自定义元素名称
            this.parsers.get(localName); 根据名称获取对应的解析器
        $parse(element, parserContext); 通过解析器解析这个元素
            parseInternal(element, parserContext); 解析元素信息
                BeanDefinitionBuilder.genericBeanDefinition(); 创建BeanDefinition构造器
                getParentName(element); 获取父bean名称，默认为null
                getBeanClass(element); 获取bean class
                doParse(element, parserContext, builder); 解析元素
                    doParse(element, builder); 调用自定义方法
            resolveId(element, definition, parserContext); 解析id属性
            element.getAttribute(NAME_ATTRIBUTE); 解析name属性
            registerBeanDefinition(holder, parserContext.getRegistry()); 注册bean
```

### 初始化bean

![](https://pdai.tech/images/spring/springframework/spring-framework-ioc-source-102.png)

```
getBean(..)
    doGetBean(..)
        transformedBeanName(name);  转换传入的beanName(去除工厂&符号，转化别名)
        getSingleton(beanName); 尝试从缓存中获取单例bean
            getSingleton(beanName, true); 允许解决循环依赖
            singletonObjects.get(beanName); 从缓存中获取
            isSingletonCurrentlyInCreation(beanName); 缓存中不存在，并且此bean正在创建[处理循环依赖]
                earlySingletonObjects.get(beanName); 从提前引用缓存获取
                singletonFactories.get(beanName); 如果依赖不存在并允许循环依赖，那么从单例工厂缓存获取
                singletonFactory.getObject();
        getParentBeanFactory(); 如果当前容器不存在此bean，尝试从父容器中查找
        getMergedLocalBeanDefinition(beanName); 合并当前bean及其父bean的定义
        mbd.getDependsOn(); 预先加载depends-on的bean
        getSingleton(beanName, ObjectFactory<T>); 加载单例bean
            synchronized (this.singletonObjects);  双重检查锁定
            beforeSingletonCreation(beanName); 记录此bean正在加载的状态
            singletonFactory.getObject(); 调用工厂方法获取bean
                createBean(beanName, mbd, args); 创建bean
                    resolveBeanClass(mbd, beanName); 解析beanClass
                    mbdToUse.prepareMethodOverrides(); 预处理lookup和replace方法
                        prepareMethodOverride(MethodOverride mo); 预处理，检查是否重载并记录
                    resolveBeforeInstantiation(beanName, mbdToUse); 调用后置处理器InstantiationAwareBeanPostProcessor
                        applyBeanPostProcessorsAfterInitialization(); 如果之前的后置处理器对其进行了创建，则调用后置处理器BeanPostProcessor完成全部创建过程
                    doCreateBean(beanName, mbdToUse, args); 创建bean
                        createBeanInstance(beanName, mbd, args); 创建bean实例
                            instantiateUsingFactoryMethod(beanName, mbd, args); 如果存在工厂方法，调用
                            determineConstructorsFromBeanPostProcessors(beanClass, beanName); 选择构造方法
                            autowireConstructor(beanName, mbd, ctors, args); 构造方法自动注入
                            instantiateBean(beanName, mbd); 默认构造方法实例化
                        applyMergedBeanDefinitionPostProcessors(); 应用后置处理器
                        addSingletonFactory(beanName, ObjectFactory); 处理循环依赖
                        populateBean(beanName, mbd, instanceWrapper); 注入属性
                            postProcessAfterInstantiation();
                        initializeBean(beanName, exposedObject, mbd); 调用初始化方法
                        registerDisposableBeanIfNecessary(beanName, bean, mbd); 注册销毁方法
            afterSingletonCreation(beanName); 移除此bean正在加载的状态
            addSingleton(beanName, singletonObject); 记录到缓存
        createBean(beanName, mbd, args); 加载prototype bean
        scope.get(beanName, ObjectFactory<T>); 加载其他scope bean
        getTypeConverter().convertIfNecessary(bean, requiredType); 类型转换
```

> 除非是通过其他方式提前注册到容器中bean，传统模式定义的bean在第一次加载时无法通过`getSingleton(beanName)`方法的缓存加载。不过，此方法也兼顾了处理循环依赖的任务。

> 三级缓存解决循环依赖的问题，其中第三层是一个工厂方法缓存，用于处理AOP代理等场景，它们会改变实例化后的bean，导致引用发生变化，因此需要此缓存让aop代理提前进行，防止其他bean引用到原始bean而非代理bean。

> 使用构造方法实例化bean的时候，如果存在`loopup-method`或者`replaced-method`，那么将会通过CGLIB创建代理类以实现此特性。

> `resolveBeforeInstantiation(beanName, mbdToUse)`方法调用默认不会进行aop代理，除非你自定义了`TargetSource`类并提供了创建代理的方法。

> Spring 5.0开始在`RootBeanDefinition`中提供了`Supplier<?> instanceSupplier`字段，可以在手动注册bean时提供，它提供了一种自定义创建bean实例的方法，并在`createBeanInstance`方法中通过`obtainFromSupplier(instanceSupplier, beanName)`使用，它的优先级高于工厂方法。

> 后置处理器应用顺序：
InstantiationAwareBeanPostProcessor#postProcessBeforeInstantiation()
通过构造方法实例化bean
MergedBeanDefinitionPostProcessor#postProcessMergedBeanDefinition()
InstantiationAwareBeanPostProcessor#postProcessAfterInstantiation()
准备字段值
InstantiationAwareBeanPostProcessor#postProcessProperties
注入字段值
BeanPostProcessor#postProcessBeforeInitialization()
调用初始化方法
BeanPostProcessor#postProcessAfterInitialization()

> 初始化方法优先级：
InitializingBean#afterPropertiesSet
@PostConstruct
自定义init-method
\
其中`@PostConstruct`定义`在CommonAnnotationBeanPostProcessor`类中，它实现了`BeanPostProcessor`接口，当调用`BeanPostProcessor#postProcessBeforeInitialization()`方法时会执行`@PostConstruct`注解中定义的方法

## Spring IoC可拓展点

### 自定义标签

1. 自定义xsd文件
2. 在`META-INF/spring.schemas`文件中增加xsd映射，格式如下：\
`
http\://www.springframework.org/schema/beans/spring-beans.xsd=org/springframework/beans/factory/xml/spring-beans.xsd
`
\
其中第一部分为xsd文件的`namespace`，第二部分为xsd文件所在的位置(一般位于`resources`目录下)

3. 实现`BeanDefinitionParser`接口，Spring提供了两个方便的基类`AbstractSingleBeanDefinitionParser`和`AbstractSimpleBeanDefinitionParser`，可以实现它们的抽象方法以进行简单的自定义xml标签解析
4. 实现`NamespaceHandler`接口，Spring提供了一个方便的基类`NamespaceHandlerSupport`，可以实现它的`init`方法以注册第三步实现的`BeanDefinitionParser`。
5. 在`META-INF/spring.handlers`文件中增加handler映射，格式如下：
`http\://www.springframework.org/schema/c=org.springframework.beans.factory.xml.SimpleConstructorNamespaceHandler`
\
第一部分为xsd文件的`namespace`，第二部分为第四步中`NamespaceHandler`接口实现类的类名

### InstantiationAwareBeanPostProcessor

`InstantiationAwareBeanPostProcessor`主要提供给Spring框架内部使用，比如AOP模块。它可以抑制默认的实例化过程，并且返回一个自定义实例作为代替。Spring 5.1之后，你还可以对字段值进行处理。

