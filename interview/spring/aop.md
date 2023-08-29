---
layout: default
title: aop
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

# Spring AOP

## Spring AOP启动过程

```java
parse(..);
    configureAutoProxyCreator(..);
        registerAspectJAutoProxyCreatorIfNecessary(..);
            registerAspectJAutoProxyCreatorIfNecessary(..);
                注册AspectJAwareAdvisorAutoProxyCreator.class
            useClassProxyingIfNecessary(..);
                设置proxy-target-class
                设置expose-proxy
    parsePointcut(elt, parserContext);
    parseAdvisor(elt, parserContext);
    parseAspect(elt, parserContext);

postProcessAfterInitialization(..)
    wrapIfNecessary(..)
        getAdvicesAndAdvisorsForBean(..)
            findEligibleAdvisors(..)
                findCandidateAdvisors(); 寻找所有的Advisor
                    寻找类型为Advisor的bean (advice, advisor, declare-parents)
                findAdvisorsThatCanApply(..); 选择符合条件的
                    IntroductionAdvisor && canApply
                        getClassFilter().matches(targetClass);
                    PointcutAdvisor && canApply
                        getClassFilter().matches(targetClass);
                        MethodMatcher#matches(..);
                extendAdvisors(..); 子类拓展
                sortAdvisors(..); 排序可用的Advisor
                    Ordered / PriorityOrdered
                    @Order / @Priority
        createProxy(..)
            evaluateProxyInterfaces(..); 评估代理接口
                getAllInterfacesForClass(..);
                过滤
            buildAdvisors(..); 构造所有的Advisor
                resolveInterceptorNames(); 获取通用Advisor，默认为空
                wrap(..); 将Adivce包装为Advisor
            customizeProxyFactory(..); 定制代理工厂
            getProxy(..); 获取代理对象
                createAopProxy(..); 选用jdk接口代理或者cglib类代理
                getProxy(..); jdk代理
                    completeProxiedInterfaces(..); 补全接口
                        增加SpringProxy, Advised, DecoratingProxy
                    findDefinedEqualsAndHashCodeMethods(..); 记录接口中是否声明了equals和hashCode方法
                    Proxy.newProxyInstance(..);
                getProxy(..); cglibg代理
                    validateClassIfNecessary(..); 检查是否存在final方法
                    createEnhancer();
                    getCallbacks(..); 获取方法拦截器
                    createProxyClassAndInstance(..);
```

1. 由IOC Bean加载方法栈中找到parseCustomElement方法，找到parse aop:aspectj-autoproxy的handler(org.springframework.aop.config.AopNamespaceHandler)
2. AopNamespaceHandler注册了<aop:aspectj-autoproxy/>的解析类是AspectJAutoProxyBeanDefinitionParserAspectJ
3. AutoProxyBeanDefinitionParser的parse 方法 通过AspectJAwareAdvisorAutoProxyCreator类去创建
4. AspectJAwareAdvisorAutoProxyCreator实现了两类接口，BeanFactoryAware和BeanPostProcessor；根据Bean生命周期方法找到两个核心方法：postProcessBeforeInstantiation和postProcessAfterInitialization
   1. postProcessBeforeInstantiation：主要是处理使用了@Aspect注解的切面类，然后将切面类的所有切面方法根据使用的注解生成对应Advice，并将Advice连同切入点匹配器和切面类等信息一并封装到Advisor
   2. postProcessAfterInitialization：主要负责将Advisor注入到合适的位置，创建代理（cglib或jdk)，为后面给代理进行增强实现做准备。


### 拓展

实现`AdvisorAdapter`接口以对自己实现的`Advice`进行适配。