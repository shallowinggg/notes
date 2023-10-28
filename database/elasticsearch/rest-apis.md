---
layout: default
title: Rest APIs
parent: Elasticsearch
grand_parent: database
---

## cat APIs

Elasticsearch为我们提供了获取所有详细信息的API，但它们提供了JSON数据，这通常不太好看到状态。例如，如果我们想查看集群的健康状况，最好获取快照而不是 JSON 文档来探索。 Elasticsearch cat API 帮助我们实现了这一点，并且我们可以获得对我们重要的数字。我们可以使用cat API获取集群、索引、分片等的健康状态，并且它还列出了所有索引。

### API参数

#### Verbose

```sh
curl -XGET http://localhost:9200/_cat/nodes
#127.0.0.1 4 79 0 0.00 0.01 0.03 cdfhilmrstw * test
```

```sh
curl -XGET http://localhost:9200/_cat/nodes?v
#ip        heap.percent ram.percent cpu load_1m load_5m load_15m node.role   master name
#127.0.0.1            4          79   0    0.02    0.10     0.08 cdfhilmrstw *      test
```

#### Help

如果我们在任何命令中将 help 选项作为参数传递，它将输出字段的详细信息。

```sh
curl -XGET http://localhost:9200/_cat/master?v
#id                     host      ip        node
#4qt6LP0PTai4mu6oRDRi0g 127.0.0.1 127.0.0.1 test
```

```sh
curl -XGET http://localhost:9200/_cat/master?v&help
#id   |   | node id
#host | h | host name
#ip   |   | ip address
#node | n | node name
```

#### Headers

我们可以在每个 `cat` 命令中传递标头字段，以便在输出中仅显示这些字段。例如，如果我们只想从节点命令中选择IP地址和CPU，我们可以编写以下表达式：

```sh
curl -XGET http://localhost:9200/_cat/nodes?v&h=ip,cpu
#ip        cpu
#127.0.0.1   0
```

#### Response format

我们可以通过提供参数的格式选项来更改API的输出格式。我们可以根据需求设置 `JSON`、`text`、`YAML`、`smile` 或 `cbor` 格式。例如，我们可以使用以下命令以文本格式列出节点：

```sh
curl -XGET http://localhost:9200/_cat/nodes?v
#ip        heap.percent ram.percent cpu load_1m load_5m load_15m node.role   master name
#127.0.0.1            4          79   0    0.02    0.10     0.08 cdfhilmrstw *      test
```

现在，如果我们想以 JSON 形式输出相同的结果，则必须将格式更改为 JSON。参考下面的表达式：

```sh
curl -XGET http://localhost:9200/_cat/nodes?v&format=json
# [
#   {
#     "ip": "127.0.0.1",
#     "heap.percent": "4",
#     "ram.percent": "79",
#     "cpu": "0",
#     "load_1m": "0.00",
#     "load_5m": "0.00",
#     "load_15m": "0.00",
#     "node.role": "cdfhilmrstw",
#     "master": "*",
#     "name": "r68s-1"
#   }
# ]
```

#### Sort

每个命令还支持排序，我们必须提供要排序的字段名称以及我们想要的排序顺序。为了排序，我们必须添加带有等号的 `s` 关键字、带有冒号的字段名称以及排序顺序。参考下面的表达式：

```sh
curl -XGET http://localhost:9200/_cat/templates?v&s=version:desc,order
# name                                index_patterns                     order      version composed_of
# .ml-state                           [.ml-state*]                       2147483647 8100499 []
# .ml-anomalies-                      [.ml-anomalies-*]                  2147483647 8100499 []
# .ml-notifications-000002            [.ml-notifications-000002]         2147483647 8100499 []
# .ml-stats                           [.ml-stats-*]                      2147483647 8100499 []
# .monitoring-beats                   [.monitoring-beats-7-*]            0          8080099
# .monitoring-alerts-7                [.monitoring-alerts-7]             0          8080099
# .monitoring-logstash                [.monitoring-logstash-7-*]         0          8080099
# .monitoring-kibana                  [.monitoring-kibana-7-*]           0          8080099
# .monitoring-es                      [.monitoring-es-7-*]               0          8080099
```

### count API

使用 cat count API，我们可以统计单个索引或所有索引中的文档数量。 cat count API 的格式如下：

```
GET /_cat/count/<index>
GET /_cat/count
```

第一个表达式统计单个索引的文档，第二个表达式统计所有索引的文档。

### health API

我们可以使用 cat health API 获取集群的健康状态。它与集群健康API类似，cat health API的格式如下：

```
GET /_cat/health
```

如果我们想使用cat health API获取集群健康状况，我们必须运行以下命令：

```sh
curl -X GET localhost:9200/_cat/health?v&pretty
# epoch      timestamp cluster       status node.total node.data shards pri relo init unassign pending_tasks max_task_wait_time active_shards_percent
# 1698404261 10:57:41  elasticsearch green           1         1      1   1    0    0        0             0                  -                100.0%
```

### indices API

使用 cat indices API，我们可以获得集群索引的高级信息。如果我们想列出集群的所有索引，我们必须运行以下命令：

```sh
curl -XGET http://localhost:9200/_cat/indices?v
TODO!!!
```

### master API

使用这个API，我们可以获取主节点的详细信息。我们必须执行以下命令来获取主节点信息：

```sh
curl -XGET http://localhost:9200/_cat/master?v
#id                     host      ip        node
#4qt6LP0PTai4mu6oRDRi0g 127.0.0.1 127.0.0.1 test
```

### nodes API

使用这个API，我们可以获取集群节点的详细信息。我们需要执行以下命令来获取集群的节点信息：

```sh
curl -XGET http://localhost:9200/_cat/nodes?v
#ip        heap.percent ram.percent cpu load_1m load_5m load_15m node.role   master name
#127.0.0.1            4          79   0    0.02    0.10     0.08 cdfhilmrstw *      test
```

### shards API

cat shards API 为我们提供了有关不同节点及其分片的详细信息，例如它们是主分片还是副本分片、它们在磁盘上占用的总字节数以及文档数量。要获取分片详细信息，我们必须执行以下命令：

```sh
curl -XGET http://localhost:9200/_cat/shards?v
# index       shard prirep state   docs store ip        node
# .security-7 0     p      STARTED    1 4.5kb 127.0.0.1 test
```

## cluster APIs

集群API应用于集群的节点，它们提供节点统计、信息等详细信息。

### health API

我们可以使用集群健康API来获取集群的健康状态。与 cat API 不同，此 API 以 JSON 格式返回结果。我们必须执行以下命令来获取集群健康状态：

```sh
curl -XGET http://localhost:9200/_cluster/health
# {
#   "cluster_name": "elasticsearch",
#   "status": "green",
#   "timed_out": false,
#   "number_of_nodes": 1,
#   "number_of_data_nodes": 1,
#   "active_primary_shards": 1,
#   "active_shards": 1,
#   "relocating_shards": 0,
#   "initializing_shards": 0,
#   "unassigned_shards": 0,
#   "delayed_unassigned_shards": 0,
#   "number_of_pending_tasks": 0,
#   "number_of_in_flight_fetch": 0,
#   "task_max_waiting_in_queue_millis": 0,
#   "active_shards_percent_as_number": 100.0
# }
```

### stats API

该API返回集群的统计信息，使用它我们可以获得不同的详细信息，例如索引指标和节点指标。在单个 API 中，我们可以获得分片数量、内存使用情况、存储大小、JVM 版本、CPU 使用情况、操作系统等详细信息。要获取集群统计信息，我们必须运行以下命令：

```sh
curl -XGET http://localhost:9200/_cluster/state
```


