---
layout: default
title: 消费者
parent: Kafka
grand_parent: 消息队列
---

<details open markdown="block">
  <summary>
    Table of contents
  </summary>
  {: .text-delta }
- TOC
{:toc}
</details>

## Concepts

### Consumers and Consumer Groups

`Kafka` 消费者通常是消费者组的一部分。当多个消费者订阅一个主题并属于同一个消费者组时，该组中的每个消费者都会从该主题中不同的分区子集接收消息。

让我们以具有四个分区的主题 T1 为例。现在假设我们创建了一个新的消费者 C1，它是组 G1 中唯一的消费者，并用它来订阅主题 T1。消费者 C1 将获取来自所有四个 T1 分区的所有消息。请参见下图。

![](https://raw.githubusercontent.com/shallowinggg/notes/main/images/kafka/consumer-group1.png)

如果我们将另一个消费者 C2 添加到组 G1 中，则每个消费者只会从两个分区获取消息。也许来自分区 0 和 2 的消息会发送到 C1，来自分区 1 和 3 的消息会发送到消费者 C2。

![](https://raw.githubusercontent.com/shallowinggg/notes/main/images/kafka/consumer-group2.png)

如果 G1 有四个消费者，那么每个消费者将从单个分区读取消息。

![](https://raw.githubusercontent.com/shallowinggg/notes/main/images/kafka/consumer-group3.png)

如果我们向单个主题的单个组中添加的消费者数量多于分区数量，则某些消费者将处于空闲状态并且根本不会收到任何消息。

![](https://raw.githubusercontent.com/shallowinggg/notes/main/images/kafka/consumer-group4.png)


我们扩展 `Kafka` 主题数据消费的主要方法是向消费者组添加更多消费者。这是创建具有大量分区的主题的一个很好的理由————它允许在负载增加时添加更多消费者。请记住，添加比主题中的分区更多的消费者是没有意义的————一些消费者只是闲置。

除了添加消费者以扩展单个应用程序之外，多个应用程序需要从同一主题读取数据也是很常见的。事实上，`Kafka` 的主要设计目标之一是使 `Kafka` 主题生成的数据可用于整个组织的许多用例。在这些情况下，我们希望每个应用程序都能获取所有消息，而不仅仅是一部分消息。为了确保应用程序获取主题中的所有消息，请确保应用程序有自己的消费者组。与许多传统消息系统不同，`Kafka` 可以扩展到大量消费者和消费者组，而不会降低性能。

### Consumer Groups and Partition Rebalance

消费者组中的消费者共享他们订阅的主题中的分区的所有权。当我们向组中添加一个新的消费者时，它开始消费来自另一个消费者之前消费过的分区的消息。当消费者关闭或崩溃时，也会发生同样的事情；它离开了组，它用来消费的分区将被剩余的消费者之一消费。当消费者组正在消费的主题被修改时（例如，如果管理员添加新分区），也会发生向消费者重新分配分区的情况。将分区所有权从一个消费者转移到另一个消费者称为重新平衡。重新平衡很重要，因为它们为消费者组提供了高可用性和可扩展性（使我们能够轻松、安全地添加和删除消费者）。有两种类型的重新平衡，具体取决于消费者组使用的分区分配策略：

#### Eager rebalance

在紧急重新平衡期间，所有消费者停止消费，放弃所有分区的所有权，重新加入消费者组，并获得全新的分区分配。这本质上是整个消费者组不可用的短暂窗口。窗口的长度取决于消费者组的大小以及几个配置参数。

![](https://raw.githubusercontent.com/shallowinggg/notes/main/images/kafka/eager-rebalance.png)

#### Cooperative rebalance

协作重新平衡（也称为增量重新平衡）通常涉及仅将一小部分分区从一个使用者重新分配给另一个使用者，并允许消费者继续处理来自所有未重新分配的分区的记录。这是通过两个或多个阶段的重新平衡来实现的。最初，消费者组领导者通知所有消费者他们将失去其分区子集的所有权，然后消费者停止从这些分区消费并放弃其所有权。在第二阶段，消费者组领导者将这些现在孤立的分区分配给它们的新所有者。这种增量方法可能需要几次迭代才能实现稳定的分区分配，但它避免了急切方法发生的完全“停止世界”的不可用性。这对于大型消费者群体尤其重要，因为重新平衡可能需要花费大量时间。

![](https://raw.githubusercontent.com/shallowinggg/notes/main/images/kafka/cooperative-rebalance.png)


消费者通过向指定为组协调员的 `Kafka` `broker`发送心跳来维护消费者组中的成员身份以及分配给他们的分区的所有权（对于不同的消费者组，该`broker`可以不同）。心跳由消费者的后台线程发送，只要消费者定期发送心跳，就认为它还活着。

如果消费者停止发送心跳足够长的时间，其会话将超时，并且组协调器会认为它已经死亡并触发重新平衡。如果消费者崩溃并停止处理消息，组协调器将在没有心跳的情况下花费几秒钟的时间来确定它已死亡并触发重新平衡。在这段时间内，不会处理来自失效消费者拥有的分区的任何消息。当彻底关闭一个消费者时，消费者会通知组协调器它要离开，组协调器会立即触发重新平衡，减少处理的间隙。

#### How

当消费者想要加入某个组时，它会向组协调器发送 JoinGroup 请求。第一个加入该组的消费者成为该组的领导者。领导者从组协调器接收组中所有消费者的列表（这将包括最近发送心跳并因此被视为活动的所有消费者），并负责将分区子集分配给每个消费者。它使用 PartitionAssignor 的实现来决定哪个分区应该由哪个消费者处理。

在决定分区分配后，消费者组领导者将分配列表发送给 GroupCoordinator，GroupCoordinator 将此信息发送给所有消费者。每个消费者只能看到自己的分配————领导者是唯一拥有组中消费者及其分配的完整列表的客户端进程。每次重新平衡发生时都会重复此过程。

### 静态组成员

默认情况下，消费者作为其消费者组成员的身份是暂时的。当消费者离开某个消费者组时，分配给该消费者的分区会被撤销，当它重新加入时，会通过再平衡协议为其分配一个新的成员 ID 和一组新的分区。

这一切都是如此，除非你配置了一个消费者具有唯一的 `group.instance.id`，这使得消费者成为该组的静态成员。当消费者首次作为组的静态成员加入消费者组时，通常会根据该组正在使用的分区分配策略为其分配一组分区。但是，当该消费者关闭时，它不会自动离开该组 ———— 它仍然是该组的成员，直到其会话超时。当消费者重新加入该组时，它会以其静态身份被识别，并被重新分配其先前持有的相同分区，而不会触发重新平衡。为组中每个成员缓存分配的组协调器不需要触发重新平衡，而只需将缓存分配发送给重新加入的静态成员。

如果两个消费者使用相同的 `group.instance.id` 加入同一个组，则第二个使用者将收到一条错误消息，指出具有此 ID 的使用者已存在。当你的应用程序维护由分配给每个使用者的分区填充的本地状态或缓存时，静态组成员身份非常有用。当重新创建此缓存非常耗时时，你不希望每次消费者重新启动时都发生此过程。另一方面，重要的是要记住，当消费者重新启动时，每个消费者拥有的分区不会被重新分配。在一定时间内，没有消费者会消费这些分区中的消息，当消费者最终启动时，它会落后于这些分区中的最新消息。你应该相信，拥有这些分区的消费者将能够在重新启动后赶上延迟。

需要注意的是，消费者组的静态成员在关闭时不会主动离开组，并检测它们何时关闭是否“真的消失了”取决于 `session.timeout.ms` 配置。你需要将其设置得足够高，以避免在简单的应用程序重新启动时触发重新平衡，但又要设置得足够低，以允许在出现更严重的停机时间时自动重新分配分区，以避免处理这些分区时出现较大间隙。

## 创建消费者

`Kafka` 消费者拥有三个必需配置：

- `bootstrap.servers`
- `key.deserializer`
- `value.deserializer`

还有第四个属性，它不是严格强制的，但非常常用。该属性为`group.id`，指定消费者实例所属的消费者组。虽然可以创建不属于任何消费者组的消费者，但这并不常见。

## 订阅主题

一旦我们创建了一个消费者，下一步就是订阅一个或多个主题。 `subscribe()` 方法将主题列表作为参数，因此使用起来非常简单：
```java
consumer.subscribe(Collections.singletonList("customerCountries"));
```

这里我们简单地创建一个包含单个元素的列表：主题名称 `customerCountries`。也可以使用正则表达式调用 `subscribe`。该表达式可以匹配多个主题名称，如果有人创建一个名称匹配的新主题，则几乎会立即发生重新平衡，消费者将开始从新主题消费。这对于需要从多个主题消费并且可以处理主题将包含的不同类型的数据的应用程序非常有用。使用正则表达式订阅多个主题最常用于在 `Kafka` 和另一个系统之间复制数据的应用程序或流处理应用程序。例如，要订阅所有测试主题，我们可以调用：
```java
consumer.subscribe(Pattern.compile(" test.*"));
```

> 警告：如果`Kafka` 集群有大量分区，可能有 30,000 个或更多，应该注意订阅主题的过滤是在客户端完成的。这意味着当通过正则表达式而不是通过显式列表订阅主题子集时，消费者将定期向`broker`请求所有主题及其分区的列表。然后，客户端将使用此列表来检测应包含在其订阅中的新主题并订阅它们。当主题列表很大并且有很多消费者时，主题和分区列表的大小很大，正则表达式订阅对`broker`、客户端和网络都有很大的开销。在某些情况下，主题元数据使用的带宽大于发送数据所使用的带宽。这也意味着，为了使用正则表达式订阅，客户端需要描述集群中所有主题的权限，即对整个集群的完整描述授权。

## The Poll Loop

Consumer API 的核心是一个简单的循环，用于轮询服务器以获取更多数据。消费者的主体如下所示：

```java
Duration timeout = Duration.ofMillis(100);

while (true) {
    ConsumerRecords<String, String> records = consumer.poll(timeout);

    for (ConsumerRecord<String, String> record : records) {
        System.out.printf("topic = %s, partition = %d, offset = %d, " +
                        "customer = %s, country = %s\n",
        record.topic(), record.partition(), record.offset(),
                record.key(), record.value());
        int updatedCount = 1;
        if (custCountryMap.containsKey(record.value())) {
            updatedCount = custCountryMap.get(record.value()) + 1;
        }
        custCountryMap.put(record.value(), updatedCount);

        JSONObject json = new JSONObject(custCountryMap);
        System.out.println(json.toString());
    }
}
```

`poll` 循环的作用不仅仅是获取数据。第一次使用新消费者调用 `poll()` 时，它负责查找 GroupCoordinator、加入消费者组并接收分区分配。如果触发重新平衡，它也会在 `poll` 循环内处理，包括相关的回调。这意味着消费者或侦听器中使用的回调中几乎所有可能出错的地方都可能显示为 `poll()` 引发的异常。请记住，如果`poll()` 没有在 `max.poll.interval.ms` 配置的时间内被调用，消费者将被视为死亡并从消费者组中驱逐，因此请避免执行任何可能在 `poll` 循环内阻塞不可预测时间间隔的操作。

### 线程安全

一个线程中不能有属于同一组的多个消费者，也不能让多个线程安全地使用同一个消费者。规则是每个线程一个消费者。要在一个应用程序中的同一组中运行多个使用者，需要分别启动线程来运行每个消费者。将消费者逻辑包装在自己的对象中，然后使用 Java 的 ExecutorService 启动多个线程，每个线程都有自己的消费者，这很有用。

> 警告：在旧版本的 `Kafka` 中，完整的方法签名是 `poll(long)`；此签名现已弃用，新的​​ API 是 `poll(Duration)`。除了参数类型的变化之外，方法阻塞的语义也发生了微妙的变化。原始方法 `poll(long)` 会一直阻塞直到从 `Kafka` 获取所需元数据，即使这比超时时间长。新方法 `poll(Duration)` 将遵守超时限制并且不等待元数据。如果现有的消费者代码使用 `poll(0)` 作为强制 `Kafka` 获取元数据而不消耗任何记录的方法，那么不能将其更改为 `poll(Duration.ofMillis(0))`并期待同样的行为。你需要找到一种新的方法来实现你的目标。通常，解决方案是将逻辑放置在 `rebalanceListener.onPartitionAssignment()` 方法中，保证在拥有分配的分区的元数据之后但在记录开始到达之前调用该方法。 Jesse Anderson 在他的博客文章[`Kafka`’s Got a Brand-New Poll](https://www.jesse-anderson.com/2020/09/kafkas-got-a-brand-new-poll/)中记录了另一种解决方案。
> 另一种方法是让一个消费者填充事件队列，并让多个工作线程从该队列执行工作。您可以在 Igor Buzatović 的[博客文章](https://www.confluent.io/blog/kafka-consumer-multi-threaded-messaging/)中看到此模式的示例。

## 配置消费者

### fetch.min.bytes

此属性允许消费者指定在获取记录时希望从`broker`接收的最小数据量，默认为一个字节。如果`broker`收到来自消费者的记录请求，但新记录的字节数少于 `fetch.min.bytes`，则`broker`将等到有更多消息可用，然后再将记录发送回消费者。这减少了消费者和`broker`的负载，因为在主题没有太多新活动（或一天中活动较少的时间）的情况下，他们处理更少的来回消息。如果消费者在没有太多可用数据时使用过多的 CPU，或者在拥有大量消费者时减少`broker`的负载，则可以将此参数设置为高于默认值 ———— 但请记住，增加此参数值会增加低吞吐量情况下的延迟。

### fetch.max.wait.ms

通过设置 `fetch.min.bytes`，你可以告诉 `Kafka` 在响应消费者之前等待，直到有足够的数据要发送。`fetch.max.wait.ms` 可让你控制等待时间。默认情况下，`Kafka` 最多等待 500 毫秒。如果没有足够的数据流向 `Kafka` 主题来满足要返回的最小数据量，这会导致最多 500 毫秒的额外延迟。如果你想限制潜在的延迟（通常是由于 SLA 控制应用程序的最大延迟），你可以将 `fetch.max.wait.ms` 设置为较低的值。如果将 `fetch.max.wait.ms` 设置为 100 ms并将 `fetch.min.bytes` 设置为 1 MB，`Kafka` 将接收来自消费者的获取请求，并在有 1 MB 数据要返回时或 100 毫秒后（以先发生者为准）响应数据。

### fetch.max.bytes

此属性允许你指定每当消费者轮询`broker`时 `Kafka` 将返回的最大字节数（默认为 50 MB）。它用于限制消费者用于存储从服务器返回的数据的内存大小，无论返回了多少个分区或消息。请注意，记录是分批发送到客户端的，如果`broker`必须发送的第一个记录批次超过此大小，则该批次将被发送，并且该限制将被忽略。这保证了消费者能够不断前进。值得注意的是，有一个匹配的`broker`配置允许 `Kafka` 管理员限制最大获取大小。`broker`配置可能很有用，因为对大量数据的请求可能会导致从磁盘进行大量读取并通过网络进行长时间发送，这可能会导致争用并增加`broker`上的负载。

### max.poll.records

此属性控制单次调用 `poll()` 将返回的最大记录数。使用此属性可以控制应用程序在轮询循环的一次迭代中需要处理的数据量（不是数据大小）。

### max.partition.fetch.bytes

此属性控制服务器将为每个分区返回的最大字节数（默认为 1 MB）。当 `poll()` 返回 ConsumerRecords 时，对于分配给消费者的每个分区，记录对象将最多使用`max.partition.fetch.bytes` 。请注意，使用此配置控制内存使用可能非常复杂，因为你无法控制`broker`响应中将包含多少个分区。因此，我们强烈建议使用 `fetch.max.bytes`，除非你有特殊原因尝试处理每个分区中相似数量的数据。

### session.timeout.ms 和 heartbeat.interval.ms

消费者与`broker`失去联系但仍被视为活动的时间默认为 10 秒。如果超过`session.timeout.ms`，消费者没有向组协调器发送心跳，则认为它已死亡，组协调器将触发消费者组的重新平衡，将死亡消费者的分区分配给组中的其他消费者。此属性与 `heartbeat.interval.ms` 密切相关，后者控制 `Kafka` 消费者向组协调器发送心跳的频率，而 `session.timeout.ms` 控制消费者可以在不发送心跳的情况下持续多长时间。因此，这两个属性通常一起修改 ———— `heartbeat.interval.ms` 必须低于 `session.timeout.ms`，并且通常设置为超时值的三分之一。因此，如果 `session.timeout.ms` 为 3 秒，则 `heartbeat.​interval.ms` 应为 1 秒。将 `session.timeout.ms` 设置为低于默认值将允许消费者组更快地检测到故障并从故障中恢复，但也可能导致不必要的重新平衡。将 `session.timeout.ms` 设置得较高将减少意外重新平衡的机会，但也意味着需要更长的时间才能检测到真正的故障。

### max.poll.interval.ms

此属性允许你设置消费者在被视为死亡之前可以不进行轮询的时间长度。如前所述，心跳和会话超时是 `Kafka` 检测死亡消费者并拿走其分区的主要机制。然而，我们也提到心跳是由后台线程发送的。有可能消费`Kafka`的主线程死锁了，但后台线程仍在发送心跳。这意味着该使用者拥有的分区中的记录不会被处理。了解消费者是否仍在处理记录的最简单方法是检查它是否正在请求更多记录。然而，对更多记录的请求之间的间隔很难预测，并且取决于可用数据量、消费者完成的处理类型，有时还取决于附加服务的延迟。在需要对返回的每条记录进行耗时处理的应用程序中， `max.poll.records` 用于限制返回的数据量，从而限制应用程序再次可用于 `poll()` 之前的持续时间。即使定义了 `max.poll.records`，调用 `poll()` 之间的间隔也很难预测，并且 `max.poll.interval.ms` 被用作故障安全或后备。该间隔必须足够大，以便健康的消费者很少能够达到，但又必须足够低，以避免来自挂起的消费者的重大影响。默认值为 5 分钟。当超时时，后台线程会发送“离开组”请求，让broker知道消费者已经死亡，组必须重新平衡，然后停止发送心跳。

### default.api.timeout.ms

这是在调用 API 时未指定显式超时时的默认超时时间，它适用于消费者进行的（几乎）所有 API 调用。默认值为 1 分钟，由于它高于请求超时默认值，因此会在需要时重试。使用此默认值的 API 的一个值得注意的例外是 `poll()` 方法，该方法始终需要显式超时。

### request.timeout.ms

这是消费者等待`broker`响应的最长时间。如果`broker`在此时间内未响应，客户端将假定`broker`根本不会响应，关闭连接并尝试重新连接。该配置默认为30秒，建议不要降低。在放弃之前让`broker`有足够的时间来处理请求非常重要 ———— 将请求重新发送到已经超载的`broker`几乎没有什么好处，并且断开连接和重新连接的行为会增加更多的开销。

### auto.offset.reset

这个属性控制消费者在开始读取没有提交偏移量的分区，或者它所拥有的提交偏移量无效（通常是因为消费者关闭时间太长，以至于具有该偏移量的记录已经被删除）时的行为。默认值为`latest`，这意味着缺少有效的偏移量，消费者将从最新记录（消费者开始运行后写入的记录）开始读取。另一种选择是`earliest`，这意味着如果缺乏有效的偏移量，消费者将从头开始读取分区中的所有数据。将 `auto.offset.reset` 设置为 `none` 将导致在尝试从无效偏移量消费时引发异常。

### enable.auto.commit

该参数控制消费者是否自动提交偏移量，默认为true。如果你希望控制提交偏移量的时间，请将其设置为 false，这对于最大限度地减少重复并避免丢失数据是必要的。如果将`enable.auto.commit`设置为true，那么你可能还想使用`auto.commit.interval.ms`控制提交偏移量的频率。

### partition.assignment.strategy

分区是分配给消费者组中的消费者的。 PartitionAssignor 是一个类，根据给定的消费者和他们订阅的主题，决定将哪些分区分配给哪个消费者。默认情况下，`Kafka`具有以下分配策略：

#### Range

为每个消费者分配其订阅的每个主题的连续分区子集。因此，如果消费者 C1 和 C2 订阅了两个主题 T1 和 T2，并且每个主题都有三个分区，那么 C1 将被分配来自主题 T1 和 T2 的分区 0 和 1，而 C2 将被分配来自这些主题的分区 2 。由于每个主题的分区数量不均匀，并且每个主题的分配都是独立完成的，因此第一个使用者最终会比第二个使用者拥有更多的分区。每当使用 `Range` 分配并且消费者数量不能整齐地划分每个主题中的分区数量时，就会发生这种情况。

#### RoundRobin

从所有订阅的主题中获取所有分区，然后将它们按顺序一一分配给消费者。如果前面描述的 C1 和 C2 使用 `RoundRobin` 分配，则 C1 将具有来自主题 T1 的分区 0 和 2，以及来自主题 T2 的分区 1。 C2 将具有来自主题 T1 的分区 1，以及来自主题 T2 的分区 0 和 2。一般来说，如果所有消费者都订阅相同的主题（一种非常常见的场景），`RoundRobin` 分配最终将导致所有消费者具有相同数量的分区（或最多一个分区差异）。

#### Sticky

粘性分配器有两个目标：第一个是尽可能平衡分配，第二个是在重新平衡的情况下，它将保留尽可能多的分配，从而最大限度地减少与移动分区相关的开销。在所有消费者订阅同一主题的常见情况下，粘性分配者的初始分配将与`RoundRobin`分配者的初始分配一样平衡。后续分配将同样平衡，但会减少分区移动的次数。在同一组的消费者订阅不同主题的情况下，StickyAssignor实现的分配比RoundRobinAssignor更加平衡。

#### Cooperative Sticky

这种分配策略与StickyAssignor相同，但支持合作再平衡，消费者可以继续使用未重新分配的分区。请注意，如果你从 2.3 之前的版本升级，则需要遵循特定的升级路径才能启用协作粘性分配策略，因此请特别注意升级指南。

`partition.assignment.strategy` 允许你选择分区分配策略。默认是`org.apache.kafka.clients.consumer.RangeAssignor`，它实现了前面描述的`Range`策略。你可以将其替换为 `org.apache.kafka.clients.consumer.RoundRobinAssignor`、`org.apache.kafka.clients.consumer.StickyAssignor` 或 `org.apache.kafka.clients.consumer.CooperativeStickyAssignor`。更高级的选项是实现自己的分配策略，在这种情况下，`partition.assignment.strategy` 应指向你的类的名称。


### client.id

它可以是任何字符串，`broker`将使用它来识别从客户端发送的请求，例如获取请求。它用于日志记录和指标，以及限额。

### client.rack

默认情况下，消费者将从每个分区的`Leader`副本中获取消息。然而，当集群跨越多个数据中心或多个云可用区时，从与消费者位于同一区域的副本中获取消息在性能和成本上都具有优势。要启用从最近的副本获取数据，需要设置 `client.rack` 配置并识别客户端所在的区域。然后，配置`broker`将默认的`replica.selector.class`替换为`org.apache.kafka.common.replica.RackAwareReplicaSelector`。你还可以使用自定义逻辑实现自己的`replica.selector.class`，基于客户端元数据和分区元数据选择要使用的最佳副本。

### group.instance.id

它可以是任何唯一字符串，用于为使用者提供静态组成员身份。

### receive.buffer.bytes 和 send.buffer.bytes

这些是套接字在写入和读取数据时使用的 TCP 发送和接收缓冲区的大小。如果这些设置为 –1，则将使用操作系统默认值。当生产者或消费者与不同数据中心的`broker`进行通信时，增加这些可能是一个好主意，因为这些网络连接通常具有较高的延迟和较低的带宽。

### offsets.retention.minutes

这是一个`broker`配置，之所以了解它很重要，是因为它对消费者行为的影响。只要消费者组有活跃成员（即通过发送心跳主动维护组中成员资格的成员），该组为每个分区提交的最后一个偏移量将被 `Kafka` 保留，因此可以在以下情况下检索它：重新分配或重新启动。但是，一旦组变空，`Kafka` 将仅保留其提交的偏移量至此配置设置的持续时间（默认为 7 天）。一旦删除了偏移量，如果该组再次变得活跃，它将表现得像一个全新的消费者组，不记得它过去消费过的任何东西。请注意，此行为发生了几次更改，因此如果你使用早于 `2.1.0` 的版本，请检查版本文档以了解预期的行为。

## 提交和偏移量

每当调用 `poll()` 时，它都会返回我们组中的消费者尚未读取的记录。这意味着我们有一种方法来跟踪该组的消费者读取了哪些记录。如前所述，`Kafka` 的独特特征之一是它不像许多 JMS 队列那样跟踪来自消费者的确认。相反，它允许消费者使用 `Kafka` 跟踪他们在每个分区中的位置（偏移量）。

我们将更新分区中当前位置的操作称为偏移量提交。与传统的消息队列不同，`Kafka` 不会单独提交记录。相反，消费者提交他们从分区成功处理的最后一条消息，并隐式假设最后一条消息之前的每条消息也都已成功处理。

消费者如何提交偏移量？它向 `Kafka` 发送一条消息，后者使用每个分区的提交偏移量更新一个特殊的 `__consumer_offsets` 主题。只要所有消费者都在启动、运行，这就不会有任何影响。但是，如果某个消费者崩溃或者有新的消费者加入消费者组，这将触发重新平衡。重新平衡后，每个消费者可能会被分配一组新的分区，而不是之前处理的分区。为了知道从哪里开始工作，消费者将读取每个分区的最新提交的偏移量并从那里继续。如果提交的偏移量小于客户端处理的最后一条消息的偏移量，则上次处理的消息偏移量和已提交的偏移量之间的消息将被处理两次。

![](https://raw.githubusercontent.com/shallowinggg/notes/main/images/kafka/offset1.png)

如果提交的偏移量大于客户端实际处理的最后一条消息的偏移量，那么最后处理的偏移量和提交的偏移量之间的所有消息都将被消费者组错过。

![](https://raw.githubusercontent.com/shallowinggg/notes/main/images/kafka/offset2.png)

### 自动提交

提交偏移量的最简单方法是允许消费者为你执行此操作。如果配置`enable.auto.commit=true`，那么消费者每五秒就会提交客户端从`poll()`收到的最新偏移量。五秒间隔是默认值，通过设置 `auto.commit.interval.ms`进行控制。就像消费者中的其他一切一样，自动提交是由轮询循环驱动的。每当轮询时，消费者都会检查是否到了提交的时间，如果是，它将提交上次轮询中返回的偏移量。

但是，在使用这个方便的选项之前，了解后果很重要。请考虑，默认情况下，自动提交每五秒发生一次。假设我们的消费者最近一次提交三秒后崩溃，重新平衡后，幸存的消费者将开始消费先前由崩溃的消费者拥有的分区，但它们将从最后提交的偏移量开始。在这种情况下，偏移量是三秒前的，因此在这三秒内到达的所有事件都将被处理两次。可以配置提交间隔以更频繁地提交并减少记录重复的窗口，但不可能完全消除它们。

启用自动提交后，当需要提交偏移量时，下一次轮询将提交该记录上次轮询返回的最后一个偏移量。它不知道实际处理了哪些事件，因此在再次调用 `poll()` 之前始终处理 `poll()` 返回的所有事件至关重要。 （就像 `poll()` 一样，`close()` 也会自动提交偏移量。）这通常不是问题，但在处理异常或过早退出 `poll` 循环时要注意。自动提交很方便，但并没有给开发人员足够的帮助控制以避免重复消息。

### 提交当前偏移量

大多数开发人员对提交偏移量的时间进行更多控制，以消除丢失消息的可能性并减少重新平衡期间重复的消息数量。 `Consumer API` 可以选择在对应用程序开发人员有意义的时间点提交当前偏移量，而不是基于计时器。通过设置`enable.auto.commit = false`，只有当应用程序明确选择执行以下操作时才会提交偏移量所以。最简单、最可靠的提交 API 是 `commitSync()`。此 API 将提交 `poll()` 返回的最新偏移量，并在提交偏移量后返回，如果由于某种原因提交失败，则抛出异常。

重要的是要记住，`commitSync()` 将提交 `poll()` 返回的最新偏移量，因此，如果在处理完集合中的所有记录之前调用 `commitSync()`，则可能会丢失已提交但未处理的消息。如果应用程序在处理集合中的记录时崩溃，则从最近批次开始到重新平衡时间之间的所有消息都将被处理两次 ———— 这可能会或可能不会比丢失消息更好。

以下是如何在处理完最新一批消息后，使用 `commitSync` 提交偏移量的示例：

```java
Duration timeout = Duration.ofMillis(100);

while (true) {
    ConsumerRecords<String, String> records = consumer.poll(timeout);
    for (ConsumerRecord<String, String> record : records) {
        System.out.printf("topic = %s, partition = %d, offset =
            %d, customer = %s, country = %s\n",
            record.topic(), record.partition(),
            record.offset(), record.key(), record.value());
    }
    try {
        consumer.commitSync();
    } catch (CommitFailedException e) {
        log.error("commit failed", e)
    }
}
```

### 异步提交

手动提交的一个缺点是应用程序会被阻塞，直到`broker`响应提交请求，这将限制应用程序的吞吐量。吞吐量可以通过降低提交频率来提高，但会增加重新平衡可能创建的潜在重复项的数量。

另一个选项是异步提交 API。我们不需要等待`broker`响应提交，而是发送请求并继续：
```java

Duration timeout = Duration.ofMillis(100);

while (true) {
    ConsumerRecords<String, String> records = consumer.poll(timeout);
    for (ConsumerRecord<String, String> record : records) {
        System.out.printf("topic = %s, partition = %s,
            offset = %d, customer = %s, country = %s\n",
            record.topic(), record.partition(), record.offset(),
            record.key(), record.value());
    }
    consumer.commitAsync();
}
```

虽然 `commitSync()` 将重试提交直到成功或遇到不可重试的失败，但 `commitAsync()` 不会重试。它不重试的原因是，当 `commitAsync()` 收到来自服务器的响应时，可能已经有稍后的提交已经成功。

想象一下，我们发送了一个提交偏移量 2000 的请求。存在临时通信问题，因此`broker`永远不会收到该请求，因此永远不会响应。同时，我们处理了另一个批次并成功提交了偏移量 3000。如果 `commit​Async()` 现在重试之前失败的提交，则在处理并提交偏移量 3000 后，它可能会成功提交偏移量 2000。在重新平衡的情况下，这将导致更多重复。

`commitAsync()` 还提供了传递回调的选项，该回调将在`broker`响应时触发。通常使用回调来记录提交错误或将其计入指标中。但如果想使用回调进行重试，则需要注意提交顺序的问题。

#### 重试异步提交

为异步重试获得正确的提交顺序的一个简单模式是使用单调递增的序列号。每次提交时增加序列号，并将提交时的序列号添加到`commitAsync`回调中。当你准备重试时，检查回调得到的提交序列号是否等于实例变量；如果是，则没有更新的提交，并且可以安全地重试。如果实例序列号较高，请不要重试，因为已经发送了较新的提交。

### 结合同步和异步提交

通常，偶尔提交失败而不重试并不是什么大问题，因为如果问题是暂时的，则后续提交将会成功。但是，如果我们知道这是关闭消费者之前或重新平衡之前的最后一次提交，我们需要额外确保提交成功。

因此，一种常见的模式是在关闭之前将 `commitAsync()` 与 `commitSync()` 结合起来。这是它的工作原理：
```java
Duration timeout = Duration.ofMillis(100);

try {
    while (!closing) {
        ConsumerRecords<String, String> records = consumer.poll(timeout);
        for (ConsumerRecord<String, String> record : records) {
            System.out.printf("topic = %s, partition = %s, offset = %d,
                customer = %s, country = %s\n",
                record.topic(), record.partition(),
                record.offset(), record.key(), record.value());
        }
        consumer.commitAsync();
    }
    consumer.commitSync();
} catch (Exception e) {
    log.error("Unexpected error", e);
} finally {
    consumer.close();
}
```

### 提交特定偏移量

提交最新的偏移量仅允许在完成处理批次后提交。但是如果想更频繁地提交怎么办？如果 `poll()` 返回一个巨大的批次，并且你希望在批次中间提交偏移量，以避免在发生重新平衡时再次处理所有这些记录，该怎么办？`commitSync()` 和 `commitAsync()` 可以传递希望提交的分区和偏移量的映射。如下所示：

```java
private Map<TopicPartition, OffsetAndMetadata> currentOffsets =
    new HashMap<>();
int count = 0;

....
Duration timeout = Duration.ofMillis(100);

while (true) {
    ConsumerRecords<String, String> records = consumer.poll(timeout);
    for (ConsumerRecord<String, String> record : records) {
        System.out.printf("topic = %s, partition = %s, offset = %d,
            customer = %s, country = %s\n",
            record.topic(), record.partition(), record.offset(),
            record.key(), record.value());
        currentOffsets.put(
            new TopicPartition(record.topic(), record.partition()),
            new OffsetAndMetadata(record.offset()+1, "no metadata"));
        if (count % 1000 == 0)
            consumer.commitAsync(currentOffsets, null);
        count++;
    }
}
```

## Rebalance Listeners

正如我们之前提到的有关提交偏移量的内容，消费者将希望在退出之前以及分区重新平衡之前执行一些清理工作。如果你知道你的消费者即将失去分区的所有权，你将需要提交该分区的偏移量。也许你还需要关闭文件句柄、数据库连接等。`Consumer API` 允许在向消费者添加或删除分区时运行自己的代码。你可以通过在调用 `subscribe()` 方法时传递 `ConsumerRebalanceListener` 来实现此目的。 `ConsumerRebalanceListener` 具有三种可以实现的方法：

```java
public void onPartitionsAssigned(Collection<TopicPartition>partitions)
// 在分区重新分配给消费者之后但消费者开始消费消息之前调用。你可以在此处准备或加载要与分区一起使用的任何状态，如果需要的话寻求正确的偏移量，或类似的操作。此处完成的任何准备工作都应保证在 max.poll.timeout.ms 内返回，以便消费者可以成功加入组。

public void onPartitionsRevoked(Collection<TopicPartition>partitions)
// 当消费者必须放弃其先前拥有的分区时调用 ———— 无论是由于重新平衡还是当消费者被关闭时。通常情况下，当使用急切重新平衡算法时，会在重新平衡开始之前和消费者停止消费消息之后调用此方法。如果使用协作重新平衡算法，则在重新平衡结束时调用此方法，参数仅包含消费者必须放弃的分区子集。这是你要提交偏移量的位置，因此无论谁接下来获得此分区，都将知道从哪里开始。

public void onPartitionsLost(Collection<TopicPartition>partitions)
// 仅在使用协作重新平衡算法时调用，并且仅在分区不会首先被重新平衡算法撤销就分配给其他消费者的特殊情况下调用（正常情况下，将调用 onPartitions​Revoked()）。你可以在此处清理这些分区使用的任何状态或资源。请注意，必须小心地完成此操作 ———— 分区的新所有者可能已经保存了自己的状态，并且你需要避免冲突。请注意，如果你不实现此方法，则会调用 onPartitions​Revoked()。
```

> 如果使用协作重新平衡算法，请注意：
>> `onPartitionsAssigned()` 将在每次重新平衡时调用，作为通知消费者重新平衡发生的一种方式。但是，如果没有分配给消费者的新分区，则会使用空集合来调用它。
>> `onPartitionsRevoked()` 将在正常的重新平衡条件下调用，但前提是消费者放弃了分区的所有权。不会使用空集合来调用它。
>> `onPartitionsLost()` 将在异常重新平衡条件下调用，并且在调用该方法时集合中的分区已经拥有新的所有者。

如果你实现了所有方法，则可以保证在正常重新平衡期间，只有在前一个所有者完成 `onPartitionsRevoked()` 并放弃其所有权之后，重新分配的分区的新所有者才会调用 `onPartitionsAssigned()`。

此示例将展示如何使用 `onPartitionsRevoked()` 在失去分区所有权之前提交偏移量：
```java
private Map<TopicPartition, OffsetAndMetadata> currentOffsets =
    new HashMap<>();
Duration timeout = Duration.ofMillis(100);

private class HandleRebalance implements ConsumerRebalanceListener {
    public void onPartitionsAssigned(Collection<TopicPartition>
        partitions) {
    }

    public void onPartitionsRevoked(Collection<TopicPartition> partitions) {
        System.out.println("Lost partitions in rebalance. " +
            "Committing current offsets:" + currentOffsets);
        consumer.commitSync(currentOffsets);
    }
}

try {
    consumer.subscribe(topics, new HandleRebalance());

    while (true) {
        ConsumerRecords<String, String> records = consumer.poll(timeout);
        for (ConsumerRecord<String, String> record : records) {
            System.out.printf("topic = %s, partition = %s, offset = %d,
                 customer = %s, country = %s\n",
                 record.topic(), record.partition(), record.offset(),
                 record.key(), record.value());
             currentOffsets.put(
                 new TopicPartition(record.topic(), record.partition()),
                 new OffsetAndMetadata(record.offset()+1, null));
        }
        consumer.commitAsync(currentOffsets, null);
    }
} catch (WakeupException e) {
    // ignore, we're closing
} catch (Exception e) {
    log.error("Unexpected error", e);
} finally {
    try {
        consumer.commitSync(currentOffsets);
    } finally {
        consumer.close();
        System.out.println("Closed consumer and we are done");
    }
}
```

## 消费特定偏移量的记录

有时你想以不同的偏移量开始读取。 `Kafka` 提供了多种方法使下一次 `poll()` 在不同的偏移量中开始消费。如果你想从分区的开头开始读取所有消息，或者你想一路跳到分区的末尾并开始仅使用新消息，有专门用于此目的的 API：`seekToBeginning(Collection<TopicPartition> tp)` 和`seekToEnd(Collection<TopicPartition> tp)`。

`Kafka` API 还允许你寻找特定的偏移量。这种能力可以通过多种方式使用；例如，对时间敏感的应用程序可以在落后时跳过一些记录，或者将数据写入文件的使用者可以重置回特定时间点，以便在文件丢失时恢复数据。

下面是一个简单示例，说明如何将所有分区上的当前偏移量设置为在特定时间点生成的记录：
```java
Long oneHourEarlier = Instant.now().atZone(ZoneId.systemDefault())
          .minusHours(1).toEpochSecond();
Map<TopicPartition, Long> partitionTimestampMap = consumer.assignment()
        .stream()
        .collect(Collectors.toMap(tp -> tp, tp -> oneHourEarlier));
Map<TopicPartition, OffsetAndTimestamp> offsetMap
        = consumer.offsetsForTimes(partitionTimestampMap);

for(Map.Entry<TopicPartition,OffsetAndTimestamp> entry: offsetMap.entrySet()) {
    consumer.seek(entry.getKey(), entry.getValue().offset());
}
```

## 退出

当你决定关闭消费者，并且你想立即退出，如果消费者可能正在等待很长的 `poll()`，你将需要另一个线程来调用`consumer.wakeup()`。如果在主线程中运行消费者循环，则可以通过 `ShutdownHook` 完成此操作。请注意，`consumer.wakeup()` 是唯一可以从不同线程安全调用的消费者方法。调用`wakeup()` 将导致 `poll()` 以 `WakeupException` 退出，如果在线程未等待`poll`时调用`consumer.wakeup()`，当下次调用 `poll()` 时，将抛出异常。 `WakeupException`不需要处理，但是在退出线程之前，必须调用`consumer.close()`。关闭消费者将在需要时提交偏移量，并向组协调器发送消费者正在离开组的消息。消费者协调器将立即触发重新平衡，因此无需等待会话超时，你要关闭的消费者的分区就会被分配给组中的另一个消费者。

这是一个[代码示例](https://github.com/gwenshap/kafka-examples/blob/master/SimpleMovingAvg/src/main/java/com/shapira/examples/newconsumer/simplemovingavg/SimpleMovingAvgNewConsumer.java)。

## 独立消费者

有时你知道有一个消费者始终需要从主题中的所有分区或主题中的特定分区读取数据。在这种情况下，没有理由进行分组或重新平衡 - 只需分配特定于消费者的主题和/或分区、消费消息和偶尔提交偏移量（尽管你仍然需要配置 `group.id` 来提交偏移量，但不需要调用 `subscribe`，消费者不会加入任何团体）。

当你确切知道消费者应该读取哪些分区时，你不需要订阅某个主题，而是为自己分配一些分区。消费者可以订阅主题（并成为消费者组的一部分）或为自己分配分区，但不能同时两者。如下所示：

```java
Duration timeout = Duration.ofMillis(100);
List<PartitionInfo> partitionInfos = null;
partitionInfos = consumer.partitionsFor("topic");

if (partitionInfos != null) {
    for (PartitionInfo partition : partitionInfos)
        partitions.add(new TopicPartition(partition.topic(),
            partition.partition()));
    consumer.assign(partitions);

    while (true) {
        ConsumerRecords<String, String> records = consumer.poll(timeout);

        for (ConsumerRecord<String, String> record: records) {
            System.out.printf("topic = %s, partition = %s, offset = %d,
                customer = %s, country = %s\n",
                record.topic(), record.partition(), record.offset(),
                record.key(), record.value());
        }
        consumer.commitSync();
    }
}
```

除了缺乏重新平衡和需要手动查找分区之外，其他一切都照常进行。请记住，如果有人向主题添加新分区，消费者将不会收到通知。你需要通过定期检查 `consumer.partitionsFor()` 或简单地通过在添加分区时重启应用程序来处理此问题。

