---
layout: default
title: tx
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

# Spring Tx

- [Spring 事务详解](https://javaguide.cn/system-design/framework/spring/spring-transaction.html)





## @Transactional失效场景

- @Transactional 应用在非 public 修饰的方法上

- @Transactional 注解属性 propagation 设置错误
<br/>这种失效是由于配置错误，若是错误的配置以下三种 propagation，事务将不会发生回滚。

  - TransactionDefinition.PROPAGATION_SUPPORTS：如果当前存在事务，则加入该事务；如果当前没有事务，则以非事务的方式继续运行。
  - TransactionDefinition.PROPAGATION_NOT_SUPPORTED：以非事务方式运行，如果当前存在事务，则把当前事务挂起。
  - TransactionDefinition.PROPAGATION_NEVER：以非事务方式运行，如果当前存在事务，则抛出异常。

- @Transactional 注解属性 rollbackFor 设置错误
<br/>
rollbackFor 可以指定能够触发事务回滚的异常类型。Spring默认抛出了未检查unchecked异常（继承自 RuntimeException的异常）或者 Error才回滚事务；其他异常不会触发回滚事务。如果在事务中抛出其他类型的异常，但却期望 Spring 能够回滚事务，就需要指定 rollbackFor属性。

- 同一个类中方法调用，导致@Transactional失效

- 异常被catch导致@Transactional失效