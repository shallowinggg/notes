---
layout: default
title: Elasticsearch
parent: 数据库
has_children: true
---

`Elasticsearch` 是一个用 Java 编写并构建在 `Lucene` 之上的开源搜索引擎。 `Lucene`是一个快速、高性能的搜索引擎库，为`Elasticsearch`的搜索赋能。我们对数据建立索引是为了快速得到搜索结果，索引可以是不同类型的。 `Lucene` 使用倒排索引，其中创建数据结构来保存每个单词的列表。现在，你一定在想，如果 `Lucene` 提供了一切，我们为什么还要使用 `Elasticsearch`。答案是`Lucene`不太好直接使用，因为我们需要编写Java代码来使用它。而且它本质上不是分布式的，因此不容易在多个节点上扩展。 `Elasticsearch`利用了`Lucene`的搜索功能加上其他扩展，这使得它成为当前最著名的搜索引擎。它封装了`Lucene`的复杂性并提供了`REST API`，使用它我们可以轻松地与`Elasticsearch`进行交互。它还通过语言客户端提供对不同编程语言的支持，因此我们可以使用任何特定语言进行编码并与`Elasticsearch`交互。我们还可以使用控制台使用 CURL 与 `Elasticsearch` 进行交互。

总而言之，`Elasticsearch` 是一个构建在 `Lucene` 之上的开源、分布式、可扩展、基于 REST、面向文档的搜索引擎。 `Elasticsearch` 集群可以在一台服务器或数百台服务器上运行，并且可以毫无问题地处理 PB 级数据。


## 基础概念

### Node

节点是 `Elasticsearch` 的单个运行实例。假设我们有一个 `Elasticsearch` 集群在十个不同的服务器上运行；那么，每个服务器被称为一个节点。如果我们不在生产环境中运行`Elasticsearch`，对于某些用例，我们可以运行`Elasticsearch`的单节点集群，我们可以将此类节点称为`Elasticsearch`的单节点集群。如果数据量增加，我们需要多个节点来水平扩展，这也为解决方案提供了容错能力。节点可以将客户端请求传输到适当的节点，因为每个节点都知道集群中的其他节点。节点可以有不同的类型。

### Master Node

主节点用于监督，因为它跟踪哪个节点是集群的一部分或者哪些分片分配给哪些节点。主节点对于维持 `Elasticsearch` 集群的健康运行非常重要。我们可以通过在 `Elasticsearch` 配置文件中将节点的 `node.master` 选项更改为 true 来配置主节点。如果我们想创建一个专用的主节点，我们必须在配置中将其他类型设置为 false。

例如下面的配置：
```yaml
node.master:                true
node.voting_only:           false
node.data:                  false
node.ingest:                false
node.ml:                    false
xpack.ml.enabled:           true
cluster.remote.connect:     false
```

在这里可以看到 `voting_only` 选项；如果我们将其设置为 false，则该节点将作为主合格节点，并且可以被选为主节点。但是，如果我们将`voting_only`选项设置为true，则该节点可以参与主节点选举，但不能自行成为主节点。稍后将解释主节点选择的工作原理。

### Data Node

数据节点负责存储数据并对其执行CRUD操作。它还执行数据搜索和聚合。我们可以通过在 `Elasticsearch` 配置文件中将节点的 `node.data` 选项更改为 true 来配置数据节点。如果我们想创建一个专用的数据节点，我们必须在配置中将其他类型设置为 false。参考如下代码：

```yaml
node.master:                false
node.voting_only:           false
node.data:                  true
node.ingest:                false
node.ml:                    false
cluster.remote.connect:     false
```

### Ingest Node

摄取节点用于在索引数据之前丰富和转换数据。因此，他们创建了一个摄取管道，在索引之前使用该管道转换数据。我们可以通过在 `Elasticsearch` 配置文件中将节点的 `node.ingest` 选项更改为 true 来配置摄取节点。任何节点都可以作为摄取节点，但如果我们要摄取大量数据，建议使用专用的摄取节点。要创建专用的摄取节点，我们必须在配置中将其他类型设置为 false。参考如下代码：

```yaml
node.master:                false
node.voting_only:           false
node.data:                  false
node.ingest:                true
node.ml:                    false
cluster.remote.connect:     false

```

### Cluster

`Elasticsearch` 集群由一组协同工作的一个或多个 `Elasticsearch` 节点组成。 `Elasticsearch` 的分布式行为允许我们将其水平扩展到不同的节点，这些节点协同工作并形成 `Elasticsearch` 集群。多节点`Elasticsearch`集群有几个优点——它是容错的，这意味着即使某些节点出现故障，我们也可以成功运行集群。此外，我们可以容纳无法存储在单个节点（服务器）上的大量数据。 `Elasticsearch` 集群运行流畅且易于配置，我们可以从单节点集群开始，并且可以通过添加节点轻松迁移到多节点集群设置。

### Document

`Elasticsearch` 文档是作为 JSON 文档存储在键值对中的单个记录，其中键是字段的名称，值是该特定字段的值。我们将每条记录存储为 RDBMS 表中的一行，`Elasticsearch` 将它们存储为 JSON 文档。 `Elasticsearch` 文档非常灵活，我们可以在每个文档中存储一组不同的字段。 `Elasticsearch` 中索引的每个文档中存储一组固定字段没有限制，这与 RDBMS 表不同，在 RDBMS 表中我们必须在插入数据之前修复字段。

### Index

`Elasticsearch` 索引是存储相似类型文档的逻辑命名空间。例如，如果我们想要存储产品详细信息，我们应该使用产品名称创建一个索引，然后开始将文档推送到索引中，因为我们已经讨论过 `Elasticsearch` 构建在 `Lucene` 之上，并使用 `Lucene` 写入和读取数据索引。 `Elasticsearch` 索引可以由多个 `Lucene` 索引构建，`Elasticsearch` 使用分片来实现这一点。

### Shard

`Elasticsearch` 的分布式架构只有通过分片才可能实现。分片是一个独立的、功能齐全的 `Lucene` 索引。单个`Elasticsearch`索引可以拆分为多个`Lucene`索引，这就是为什么我们可以存储单个`Elasticsearch`节点无法存储的海量数据。数据可以被分割成多个分片，并且它们可以均匀地分布到`Elasticsearch`集群上的多个节点上。

分片可以有两种类型：主分片和副本分片。主分片包含主数据，而副本分片包含主分片的副本。我们使用副本分片来保护我们免受任何硬件故障的影响并提高集群的搜索性能。


