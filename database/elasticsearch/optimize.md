---
layout: default
title: 性能优化
parent: Elasticsearch
grand_parent: 数据库
---

<details open markdown="block">
  <summary>
    Table of contents
  </summary>
  {: .text-delta }
- TOC
{:toc}
</details>

当我们谈论索引、搜索和聚合数据时，Elasticsearch 速度很快，但并非每次都是如此。当数据量增加时，我们可以看到它对性能的影响；此外，这取决于不同的用例。在某些情况下，应用程序可能是索引密集型的，而其他应用程序可能是搜索密集型的。因此，不存在平衡和理想的用例，这就是为什么我们必须根据用例进行某些权衡。

我们无法优化所有用例，例如索引、搜索、聚合，因此我们必须了解业务优先级，并为不太重要的事情做一些权衡。因此，可以根据更重要的事情来决定这些权衡。我们还需要进行一些基准测试，以了解优化的执行情况以及它是否提高了整体性能。与其完成所有调整，不如一次进行一项调整并在进一步进行之前检查影响。如果我们的应用程序索引更加密集，我们可以应用更少的搜索和更多的数据索引，因此我们可以按照选项来调整索引速度。如果应用程序是搜索密集型的，我们可以使用选项来调整搜索速度。

## 优化索引速度

让我们看看可以执行哪些选项来优化索引速度。您需要了解您的应用程序是搜索密集型还是索引密集型，并相应地做出优化决策。有时，需要一次推送大量数据，例如我们将数据从任何来源迁移到 Elasticsearch。对于这种情况，我们可以在较短的时间内优化索引性能，并且可以在迁移完成后恢复更改。因此，我们可以根据应用程序用例需求调整 Elasticsearch 集群性能。现在，我们来讨论一些优化 Elasticsearch 索引性能的选项。

### Bulk R requests

我们可以使用批量请求而不是单文档索引请求来提高索引性能，但是我们可以在单个请求中发送多少数据是一个问题，因为这个数字只能通过基准测试来验证。例如，如果我们有很多文档需要索引，我们可以从 100-200 个文档开始，然后逐渐增加它，除非遇到性能问题。这样，我们就可以根据我们使用的Elasticsearch集群来获得可以批量索引的最佳文档数量。如果我们为单个索引请求添加太多文档，则会对 Elasticsearch 集群造成内存压力。批量索引请求的一个例子如下：

```
POST _bulk
{"index" : {"_index" : "users", "_id" : "1"}}
{"name" : "Anurag Srivastava"}
{"index" : {"_index" : "users", "_id" : "2"}}
{"name" : "Rakesh Kumar"}
{"create" : {"_index" : "users", "_id" : "3"}}
{"name" : "Vinod Kambli"}
{"update" : {"_id" : "2", "_index" : "users"}}
{"doc" : {"name" : "Suresh Raina"}}
```

我们在单个批量请求中执行多个操作。我们正在创建 id 为 1、2 和 3 的文档，并更新 id 为 2 的文档。我们还可以使用批量请求删除文档。

### 巧妙使用集群

我们应该巧妙地使用Elasticsearch集群，比如如果我们需要对大量数据进行批量请求，我们可以使用多个线程和进程来处理数据。这样，我们可以通过提供最大容量来处理更多请求来补充批量索引。为了利用所有Elasticsearch集群资源，我们应该使用Elasticsearch的多个线程或进程。工作线程或线程的最佳数量只能使用基准测试来获取，因为它可能因不同的集群而异。为了对worker数量进行基准测试，我们可以逐渐增加它并监控I/O和CPU，当集群I/O或CPU饱和时停止。这是我们可以努力补充批量上传的另一个因素，这两个因素一起可以为数据索引提供良好的性能提升。

### 增加刷新间隔

刷新间隔是索引文档可以准备好进行搜索操作的时间间隔。因此，我们需要等待下一次刷新，以便索引文档出现在搜索操作中，该持续时间是使用 `refresh_interval` 设置定义的。 `refresh_interval`的默认值是`1s`，因此每个新索引的文档最多一秒后就可以被搜索到。然而，只有当 Elasticsearch 索引在过去 30 秒内收到一个或多个搜索请求时，才会进行这1秒刷新操作。回到索引性能调整，我们应该增加`refresh_interval`，因为这是一个成本高昂的操作，并且会影响索引性能。我们可以使用Elasticsearch配置文件定义`index.refresh_interval`设置，也可以通过使用查询的索引设置在每个索引级别实现。因此，如果我们想要执行批量索引，我们可以将`refresh_interval`增加到一个更高的值，比如`30s`或更多。这样，我们就可以避免每1s可能发生的索引刷新。

### 禁用复制

我们可以禁用索引复制来提高索引性能。当我们想要将大量数据加载到 Elasticsearch 中时，此选项非常适合。我们可以将`index.number_of_replicas`设置设置为`0`以提高索引性能，并且可以使用`elasticsearch.yml`文件或设置API更改此设置。如果节点发生故障，删除数据复制会导致数据丢失的风险，我们应该通过将数据保存在其他地方来处理这个问题。一旦数据写入成功，我们就可以使用`index.number_of_replicas`设置启用复制。通过禁用复制，我们可以确保Elasticsearch不必做额外的工作来复制其他节点上的数据。当我们想要推送大量数据时，建议禁用复制，直到数据加载到 Elasticsearch 中。

### 使用自动生成的id

在文档索引过程中，如果使用任何预定义的索引 `id` 字段值，Elasticsearch 必须付出额外的努力，这会影响性能。索引 `id` 字段必须是唯一的，Elasticsearch 必须检查现有文档中的 `id` 来验证这一点。如果 `id` 不可用，则只能对文档建立索引。如果该 `id` 在同一个分片中已经可用，Elasticsearch 将抛出错误。我们可以使用自动生成的 `id` 来修复 Elasticsearch 完成的这项额外工作，因为它将跳过检查并可以增强 Elasticsearch 索引性能。因此，我们应该使用自动生成的 `id`，除非使用我们的 `id` 值很重要。


### 调整索引缓冲区大小

在大量索引的情况下，节点最多使用每个分片 `512 MB` 的大小。我们应该确保`indices.memory.index_buffer_size`足够大，以使数据索引在繁重的索引中顺利进行。在 Elasticsearch 中，我们可以将此设置配置为 Java 堆大小的某个百分比或提供绝对字节大小。默认情况下，Elasticsearch 使用 10% 的 JVM 内存作为索引缓冲区大小，这在许多用例中已经足够了。假设我们的 JVM 内存大小为 10GB，那么索引缓冲区大小为 1GB，足以容纳两个重型索引分片。我们就可以通过基准测试来确定索引缓冲区的最佳大小。


### 使用更快的硬件

为了提高索引性能，我们还可以使用更快的驱动器，例如 `SSD` 驱动器，因为与旋转磁盘相比，它们的性能更好。我们应该始终更喜欢本地存储，而不是像 `SMB` 或 `NFS` 这样的远程文件系统。还应该避免像 `AWS Elastic Block Storage` 这样的虚拟化存储。云存储很容易设置，而且速度也很快，但对于正在进行的过程来说，它比专用本地存储慢，这就是本地存储更好的原因。因此，我们可以使用 `SSD` 驱动器来提高索引性能。

### 为文件系统缓存分配内存

我们可以使用文件系统缓存来缓冲 I/O 操作。这可以提高性能，因为高速缓存可以用作缓冲区。对于文件系统缓存，我们可以在运行 Elasticsearch 的节点上分配一半的内存。


## 优化搜索速度

我们介绍了一些优化索引性能的方法。现在，让我们看看一些优化搜索速度的方法。如果应用程序是搜索密集型而不是索引密集型，我们可以使用这些选项。在很多情况下，数据索引并不频繁，但我们在应用程序中执行密集搜索。例如，在电子商务应用程序中，我们将产品详细信息推送一次，然后由不同的用户搜索。在这些情况下，我们的主要重点是提高集群的搜索性能。根据应用程序用例需求，我们可以调整 Elasticsearch 集群性能。现在，我们将讨论一些优化 Elasticsearch 搜索性能的选项。


### 文档建模

我们应该根据应用程序的需求进行文档建模。建模的主要重点应该是避免连接或父子关系。例如，如果我们要显示产品详细信息页面，最好将所有必需的属性保留在单个索引中，以便可以快速加载页面。如果我们不进行这样的映射，从不同索引获取数据时我们可能会感到轻微的延迟。因此，文档建模是调整 Elasticsearch 搜索性能的一个重要方面。


### 搜索尽可能少的字段

如果我们想提高搜索性能，最好搜索尽可能少的字段。当我们使用`query_string`或`multi_search`添加更多字段进行搜索时，就会出现问题：获取结果需要更多时间。如果我们可以减少这一计数，那会很有用，但有时可能会有多个字段。假设我们需要在两个字段上应用搜索。对于这些情况，Elasticsearch 提供了一种将多个字段的值复制到单个字段的方法，然后我们可以使用这个字段应用数据搜索。使用 Elasticsearch 的 `copy-to` 指令，我们可以将字段值创建到不同字段的副本。请参阅以下具有两个不同字段的示例：`first_name` 和 `last_name`：

```
PUT user_details
{
  "mappings": {
    "properties": {
      "name": {
        "type": "text"
      },
      "first_name": {
        "type": "text",
        "copy_to": "name"
      },
      "last_first": {
        "type": "text",
        "copy_to": "name"
      }
    }
  }
}
```

我们创建具有两个字段的映射：`first_name` 和 `last_name`。在搜索过程中，用户可以输入任何内容作为名字或姓氏，我们必须为此在两个字段上应用搜索。但是，我们使用 `copy_to` 指令将两个字段的值复制到另一个字段，即`name`。我们可以通过添加文档来测试一下，这是一个例子：

```
POST user_details/_doc
{
  "first_name": "Anurag",
  "last_name": "Srivastava"
}
```

使用前面的命令，我们将一个文档添加到刚刚创建的 `user_details` 索引中。现在，让我们搜索记录以验证数据是否已复制到新字段，使用它我们可以应用数据搜索。我们可以执行以下命令来搜索新字段：
```
GET user_details/_search?q=name:Anurag
```

在前面的示例中使用了`URI 搜索`，其中字段名称是`name`，但我们还没有为文档创建提供了该字段。现在，让我们看看执行上述命令后 Elasticsearch 的响应：

```json
{
  "took": 1,
  "timed_out": false,
  "_shards": {
    "total": 1,
    "successful": 1,
    "skipped": 0,
    "failed": 0
  },
  "hits": {
    "total": {
      "value": 1,
      "relation": "eq"
    },
    "max_score": 0.2876821,
    "hits": [
      {
        "_index": "user_details",
        "_id": "9mgoiosBzCHv00RXRpzc",
        "_score": 0.2876821,
        "_source": {
          "first_name": "Anurag",
          "last_name": "Srivastava"
        }
      }
    ]
  }
}
```

这样，我们就可以使用`name`字段来搜索记录，当我们想将多个字段的数据放在一个字段中时，它非常有用，可以减少数据搜索的字段数量。


### 预索引数据

我们可以使用搜索模式信息来优化数据索引行为。我们可以使用索引来提高搜索性能；例如，如果我们想要聚合数据以显示范围桶（例如鞋码范围），则在搜索过程中聚合数据会花费我们的成本。如果在对文档建立索引的时候能够加上范围就好了，这样可以节省聚合成本并提高搜索性能。举个例子，文档结构如下：

```
POST index/_doc
{
  "category": "Formal shoes",
  "size": 7
}
```

现在，我们必须执行以下命令来聚合数据以了解不同的范围：
```
GET index/_search
{
  "size": 0,
  "aggs": {
    "size_ranges": {
      "range": {
        "field": "size",
        "ranges": [
          {
            "to": 6
          },
          {
            "from": 6,
            "to": 12
          },
          {
            "from": 12
          }
        ]
      }
    }
  }
}
```

我们必须对大小范围过滤器的数据集执行范围聚合，但是在文档的索引时间创建此范围详细信息如何。这样，我们可以节省范围聚合成本，因为范围聚合可以直接应用于单个字段。让我们举个例子来了解如何在文档索引期间添加这些额外的细节：

```
PUT index
{
  "mappings": {
    "properties": {
      "size_range": {
        "type": "keyword"
      }
    }
  }
}
```

在前面的示例中，我们为 `size_range` 字段创建映射，以添加尺码范围。现在，我们可以通过执行以下命令将一些文档添加到索引中：
```
POST index/_doc
{
  "category": "Formal shoes",
  "size": 5,
  "size_range": "0-5"
}
```

在前面的查询中，我们添加了文档以及 `size_range` 字段来存储鞋子的大小范围。我们不需要使用范围聚合来聚合它，而是使用术语聚合：通过选择 `size_range` 字段的唯一值来轻松显示不同的范围。我们可以使用此处给出的查询来取代大小范围聚合：
```
GET index/_search
{
  "size": 0,
  "aggs": {
    "size_ranges": {
      "terms": {
        "field": "size_range"
      }
    }
  }
}
```

我们可以对数据进行预索引，以节省搜索过程中的额外成本。我们只需要确定可以与实际文档数据一起添加的字段。

### 将标识符映射为关键字

有许多数字字段我们不需要执行数字运算，例如`产品 id` 和`博客 id` 等任何表的 `id` 字段。因此，将它们定义为数字类型是没有用的，因为 Elasticsearch 针对范围查询对数字字段进行了优化。例如，如果我们有价格、数量或尺寸，我们希望使用聚合来获取范围，并且我们应该将这些字段保留为数字。而对于`博客 id` 和`产品 id` 等其他数值，如果我们可以将它们定义为`keyword`字段，那就太好了。这是因为它有助于执行术语查询，而我们主要希望对此类字段执行术语查询。此外，关键字字段的术语查询比数字字段的术语查询更快。这样，我们就可以通过规划适当的数据类型来调整 Elasticsearch 的搜索性能。

### 强制合并只读索引

将索引的多个只读分片合并到一个中总是好的。单个段具有更简单、更高效的数据结构，使我们能够执行更好的搜索。基于时间的索引是我们可以应用强制合并的最佳示例，因为一旦当前时间范围结束，我们就无法在索引中增加更多新文档。因此，这些类型的索引通常是只读的，我们可以应用强制合并。如果索引当前或即将开放写入，我们不应该强制合并索引。

### 使用过滤器代替查询

查询子句可用于确定文档的匹配程度，而过滤器用于查找文档是否与给定的查询参数匹配。因此，Elasticsearch 不会计算过滤器子句的相关性分数，并且在存在过滤器的情况下也可以缓存结果。因此，如果不需要相关性分数，我们应该更喜欢过滤器而不是查询。

### 增加副本数

Elasticsearch 的搜索性能可以通过增加索引的副本数来提高。 Elasticsearch 使用主分片或副本分片来执行搜索，增加副本分片可以使更多节点可用于搜索。


### 只获取必需字段

我们可以只选择必需字段，而不是获取索引的所有字段。示例如下：
```
GET kibana_sample_data_ecommerce/_search
{
  "_source": ["taxful_total_price"],
  "query": {
    "term": {
      "customer_first_name": {
        "value": "eddie"
      }
    }
  }
}
```

```json
{
  "took": 1,
  "timed_out": false,
  "_shards": {
    "total": 1,
    "successful": 1,
    "skipped": 0,
    "failed": 0
  },
  "hits": {
    "total": {
      "value": 100,
      "relation": "eq"
    },
    "max_score": 4.016948,
    "hits": [
      {
        "_index": "kibana_sample_data_ecommerce",
        "_id": "s2i3f4sBzCHv00RXUIpy",
        "_score": 4.016948,
        "_source": {
          "taxful_total_price": 36.98
        }
      },
      {
        "_index": "kibana_sample_data_ecommerce",
        "_id": "t2i3f4sBzCHv00RXUIpy",
        "_score": 4.016948,
        "_source": {
          "taxful_total_price": 80.98
        }
      },
      {
        "_index": "kibana_sample_data_ecommerce",
        "_id": "vmi3f4sBzCHv00RXUIpy",
        "_score": 4.016948,
        "_source": {
          "taxful_total_price": 68.96
        }
      },
      {
        "_index": "kibana_sample_data_ecommerce",
        "_id": "wGi3f4sBzCHv00RXUIpy",
        "_score": 4.016948,
        "_source": {
          "taxful_total_price": 266.96
        }
      },
      {
        "_index": "kibana_sample_data_ecommerce",
        "_id": "gWi3f4sBzCHv00RXUIty",
        "_score": 4.016948,
        "_source": {
          "taxful_total_price": 39.98
        }
      },
      {
        "_index": "kibana_sample_data_ecommerce",
        "_id": "hmi3f4sBzCHv00RXUIty",
        "_score": 4.016948,
        "_source": {
          "taxful_total_price": 149.96
        }
      },
      {
        "_index": "kibana_sample_data_ecommerce",
        "_id": "oGi3f4sBzCHv00RXUIty",
        "_score": 4.016948,
        "_source": {
          "taxful_total_price": 99.96
        }
      },
      {
        "_index": "kibana_sample_data_ecommerce",
        "_id": "xWi3f4sBzCHv00RXUIty",
        "_score": 4.016948,
        "_source": {
          "taxful_total_price": 41.98
        }
      },
      {
        "_index": "kibana_sample_data_ecommerce",
        "_id": "7mi3f4sBzCHv00RXUIty",
        "_score": 4.016948,
        "_source": {
          "taxful_total_price": 39.98
        }
      },
      {
        "_index": "kibana_sample_data_ecommerce",
        "_id": "J2i3f4sBzCHv00RXUIxy",
        "_score": 4.016948,
        "_source": {
          "taxful_total_price": 134.98
        }
      }
    ]
  }
}
```

### 使用更快的硬件


### 为文件系统缓存分配内存


### 避免在搜索中包含停用词

我们应该避免在查询中包含停止词，因为它们可能会导致结果数量激增。例如，如果我们从文档集中搜`cow`，它将显示很少的与`cow`匹配的结果，但是如果我们搜索`the cow`，它将返回几乎所有文档，因为这个停止词`the`非常常见并且可以可以在所有文档中找到。 Elasticsearch 会为不同的搜索生成分数，如果我们使用停用词，Elasticsearch 必须付出额外的努力，这会降低性能。如果需要得到`the cow`的结果，我们可以在`the`和`cow`之间使用`and`运算符来获得相同的匹配。

### 避免在查询中使用脚本

我们应该避免使用脚本，因为它的查询成本更高。让我们举一个脚本查询的例子，我们想要搜索索引中以`Men`开头的产品类别的所有文档。我们必须为此执行以下脚本查询：
```
GET kibana_sample_data_ecommerce/_search
{
  "query": {
    "bool": {
      "filter": [
        {
          "script": {
            "script": {
              "source": "doc['category.keyword'].value.startsWith('Men')"
            }
          }
        }
      ]
    }
  }
}
```

我们将获取所有产品类别以`Men`开头的匹配文档；例如，参考如下结果文档：
```json
{
  "took": 8,
  "timed_out": false,
  "_shards": {
    "total": 1,
    "successful": 1,
    "skipped": 0,
    "failed": 0
  },
  "hits": {
    "total": {
      "value": 2310,
      "relation": "eq"
    },
    "max_score": 0,
    "hits": [
      {
        "_index": "kibana_sample_data_ecommerce",
        "_id": "s2i3f4sBzCHv00RXUIpy",
        "_score": 0,
        "_source": {
          "category": [
            "Men's Clothing"
          ]
        }
      },
      {
        "_index": "kibana_sample_data_ecommerce",
        "_id": "t2i3f4sBzCHv00RXUIpy",
        "_score": 0,
        "_source": {
          "category": [
            "Men's Clothing",
            "Men's Accessories"
          ]
        }
      },
      {
        "_index": "kibana_sample_data_ecommerce",
        "_id": "uWi3f4sBzCHv00RXUIpy",
        "_score": 0,
        "_source": {
          "category": [
            "Men's Clothing"
          ]
        }
      },
      {
        "_index": "kibana_sample_data_ecommerce",
        "_id": "umi3f4sBzCHv00RXUIpy",
        "_score": 0,
        "_source": {
          "category": [
            "Men's Clothing",
            "Men's Accessories",
            "Men's Shoes"
          ]
        }
      },
      {
        "_index": "kibana_sample_data_ecommerce",
        "_id": "vmi3f4sBzCHv00RXUIpy",
        "_score": 0,
        "_source": {
          "category": [
            "Men's Accessories",
            "Men's Clothing"
          ]
        }
      },
      {
        "_index": "kibana_sample_data_ecommerce",
        "_id": "v2i3f4sBzCHv00RXUIpy",
        "_score": 0,
        "_source": {
          "category": [
            "Men's Accessories",
            "Men's Clothing",
            "Men's Shoes"
          ]
        }
      },
      {
        "_index": "kibana_sample_data_ecommerce",
        "_id": "wGi3f4sBzCHv00RXUIpy",
        "_score": 0,
        "_source": {
          "category": [
            "Men's Clothing"
          ]
        }
      },
      {
        "_index": "kibana_sample_data_ecommerce",
        "_id": "wWi3f4sBzCHv00RXUIpy",
        "_score": 0,
        "_source": {
          "category": [
            "Men's Clothing",
            "Men's Shoes",
            "Women's Accessories"
          ]
        }
      },
      {
        "_index": "kibana_sample_data_ecommerce",
        "_id": "wmi3f4sBzCHv00RXUIpy",
        "_score": 0,
        "_source": {
          "category": [
            "Men's Shoes",
            "Men's Clothing",
            "Women's Accessories",
            "Men's Accessories"
          ]
        }
      },
      {
        "_index": "kibana_sample_data_ecommerce",
        "_id": "w2i3f4sBzCHv00RXUIpy",
        "_score": 0,
        "_source": {
          "category": [
            "Men's Clothing",
            "Men's Shoes"
          ]
        }
      }
    ]
  }
}
```

问题是脚本查询将需要额外的资源，并且会减慢搜索查询的速度。我们可以使用其他方法来避免脚本标签，例如前缀查询。这是一个例子：

```
GET kibana_sample_data_ecommerce/_search
{
  "query": {
    "prefix": {
      "category.keyword": {
        "value": "Men"
      }
    }
  }
}
```

执行上述命令可以提供与使用前面提到的脚本查询得到的相同结果。这样，我们就可以通过避免脚本查询来提高Elasticsearch的查询性能。


## 优化磁盘使用

现在我们已经介绍了一些调整 Elasticsearch 索引性能和搜索性能的方法，让我们探索优化磁盘使用的不同方法。优化磁盘使用并从磁盘中删除任何不必要的数据非常重要，因为它可能会消耗资源并成为瓶颈。让我们讨论一些优化 Elasticsearch 磁盘使用的选项。

### 收缩缩阴

我们可以使用`shrink API`减少索引中的分片数量。我们可以使用此 API 以及强制合并 API 显着减少索引的分片数量和段。`shrink API`会收缩索引并创建一个包含更少主分片的新索引。在应用`shrink API`之前，我们必须检查一些事情：源索引应该是只读的，每个分片的副本必须驻留在同一节点中，并且集群运行状况必须为绿色。以下表达式提供了`shrink API` 示例：

```
POST /source_index/_shrink/target_index
{
  "settings": {
    "index.number_of_replicas": 1,
    "index.number_of_shards": 1,
    "index.codec": "best_compression"
  }
}
```

我们将源索引收缩到目标索引中。这样，我们就可以使用`shrink API`来收缩只读索引并节省磁盘利用。

### 强制合并

Elasticsearch 使用分片来存储索引数据，每个分片都是一个 `Lucene` 索引。分片由一个或多个段组成，这些是保存在磁盘上的实际文件。为了提高效率，最好有更大的段来存储数据。使用强制合并 API，我们可以通过合并段来减少段数量。我们可以使用强制合并 API 来合并一个或多个索引的分片。尽管合并在 Elasticsearch 中自动发生，但有时最好手动执行。我们应该仅在该索引的数据写入完成后才进行强制合并。以下命令提供了强制合并索引的示例：
```
POST /indexname/_forcemerge
```

我们可以通过将 `_forcemerge` 端点应用于索引来强制合并索引分片。我们可以使用以下命令强制合并所有索引：
```
POST /_forcemerge
```

前面的命令将强制合并所有索引。我们还可以通过以逗号分隔的形式提供某些索引来强制合并它们，如本示例所示：
```
POST /indexname1, indexname2, indexname3/_forcemerge
```

### 禁用不需要的功能

Elasticsearch 的索引行为允许我们为几乎所有字段建立索引并添加文档值，以使它们可用于搜索和聚合。但是，我们需要对所有字段都建立索引吗？可能不会。这是因为我们可以使用某些字段的值，但不一定使用它们来过滤数据。因此，我们可以使用以下命令禁用字段的索引：

```
PUT index
{
  "mappings": {
    "properties": {
      "product_code": {
        "type": "integer",
        "index": false
      }
    }
  }
}
```

在前面的示例中，我们为 `product_code` 字段创建映射，并将`index`定义为 `false` 以指示 Elasticsearch 不索引该字段。同样，如果我们想使用文本字段进行匹配，但不关心该字段的评分，我们可以将`norms`设置为`false`，如下例所示：

```
PUT index
{
  "mappings": {
    "properties": {
      "color": {
        "type": "text",
        "norms": false
      }
    }
  }
}
```

在前面的示例中，我们将`color`字段的`norms`设置为 `false`，因为我们不想要该字段的分数。

我们可以调整映射以仅设置所需的选项并禁用其他选项。默认情况下，Elasticsearch 存储文本字段的位置并使用它来执行短语查询。如果我们不需要字段的短语查询，我们可以使用此处给出的示例禁用此选项：

```
PUT index
{
  "mappings": {
    "properties": {
      "color": {
        "type": "text",
        "index_options": "freqs"
      }
    }
  }
}
```

### 避免动态字符串映射

默认情况下，Elasticsearch 动态字符串映射应用于字符串字段，其中它们被映射为文本和关键字。这种双重映射并不总是需要的，并且对于许多领域来说可能是一种浪费。例如，我们可能不需要将 `id` 字段映射为文本，将 `body` 字段映射为关键字。原因是我们永远不想部分匹配 `id` 字段，因为我们应该完全匹配它并且必须将其映射为关键字。对于`body`字段，我们应该使用文本映射来匹配它，我们可以进行全文搜索而不是精确匹配。我们可以通过显式映射或创建索引模板来处理这种情况。以下示例说明了如何将字段映射为关键字：

```
PUT my_index
{
  "mappings": {
    "properties": {
      "product_code": {
        "type": "keyword"
      }
    }
  }
}
```

我们映射`product_code`字段作为关键字。关键字有利于对字符串字段执行精确匹配。这样，我们可以应用显式映射来避免字符串字段的双重映射，这在很多情况下是浪费的。

### 禁用_source

Elasticsearch 响应中的 `_source` 字段显示文档的实际 JSON 正文。如果我们不需要文档，我们可以禁用 `_source` 字段。下面是禁用 `_source` 字段的示例：

```
PUT index
{
  "mappings": {
    "_source": {
      "enabled": false
    }
  }
}
```

在前面的操作中，我们使用映射禁用了 `_source` 字段。现在，让我们向索引添加一些文档，以了解搜索文档时此更改将如何影响输出。下面是一个例子：

```
POST index/_doc/
{
  "product Category": "Formal Shoes",
  "size": 5,
  "size_range": "0-5"
}
```

这个例子展示了文档的创建，我们可以添加此文档到索引。现在，让我们执行以下命令来搜索索引以返回文档：

```
GET index/_search
```

我们将得到以下响应：
```json
{
  "took": 0,
  "timed_out": false,
  "_shards": {
    "total": 1,
    "successful": 1,
    "skipped": 0,
    "failed": 0
  },
  "hits": {
    "total": {
      "value": 1,
      "relation": "eq"
    },
    "max_score": 1,
    "hits": [
      {
        "_index": "index",
        "_id": "-WhbiosBzCHv00RXT5wJ",
        "_score": 1
      }
    ]
  }
}
```

前面的响应中没有 `_source` 字段，因此我们看不到实际的JSON文档，但仍然可以使用文档字段进行搜索。因此，如果我们不需要响应中的JSON文档，我们可以通过在索引映射中将 `_source` 字段设置为 `false` 来禁用它。

### 使用最小的数值类型

我们应该使用最有效的数值数据类型来保存我们想要为字段存储的数据。数据类型对磁盘使用有重大影响，因此有必要使用足以存储数据的类型，而不是通过映射到比我们计划保存的大小更大的类型来浪费空间。例如，整数应使用 `byte`、`short`、`integer` 或 `long` 等整数类型保存，而浮点值可以使用 `float`、`double` 或 `half_float` 保存。我们应该知道 `float` 类型是否足够或者需要 `double` 类型来存储我们的数据。这样，我们就可以决定合适的类型并节省磁盘使用量。


## 最佳实践

我们应该遵循某些最佳实践来优化 Elasticsearch 性能并防止未来出现任何问题。在这里，我们将讨论一些 Elasticsearch 最佳实践。

### 始终定义映射

最佳实践是在添加文档之前定义 Elasticsearch 索引的映射。在将 JSON 数据推送到 Elasticsearch 之前，最好先了解我们要推送的数据及其结构。一旦该信息准备好，我们就可以创建映射，然后开始推送数据。这种方法背后的原因是为了避免任何与数据类型相关的问题，因为如果我们没有显式映射，Elasticsearch 就会猜测数据类型，但这有时可能是错误的。我们还介绍了一些性能调整选项，只有遵循 Elasticsearch 索引的显式映射，这些选项才可能实现。因此，始终建议为文档字段显式创建 Elasticsearch 映射。

### 进行容量规划

我们应该根据磁盘、内存或 CPU 利用率来规划容量。我们在容量规划时必须考虑不同的方面，例如数据保留期限是多少，数据索引率是多少，数据搜索率是多少。我们还应该考虑所需的副本数量。容量规划需要付出很大的努力，不可能一蹴而就，所以我们必须经过一些对标之后，通过细化来改进。 Elasticsearch 是可扩展的，因此当我们需要更多容量时，我们可以选择水平扩展。无论如何，始终需要进行初步规划，以建立一个稳定的集群，可以毫无问题地满足用户请求。

### 避免脑裂问题

Elasticsearch 具有分布式架构，这意味着单个集群可以分布到多个节点。如果我们启用副本分片，数据可以分布到多个节点，并且在单个节点故障的情况下不会造成任何数据丢失。 Elasticsearch 的这种分布式特性为我们提供了性能和高可用性。现在，让我们了解一下裂脑问题。如果集群由于任何原因（例如连接故障）而分裂，则可能会发生这种情况。在这种情况下，从节点无法与主节点通信，并且它们假设主节点已关闭。该过程在连接的节点中发起主节点选举，选举后新的主节点接管。在连接恢复时，我们会有两个主节点。在这种情况下，前一个主节点假设断开连接的节点将作为从节点重新加入，而新的主节点假设原来的主节点已关闭并将作为从节点重新加入。这种情况被称为脑裂。我们可以通过配置 Elasticsearch 参数 `discovery.zen.minimum_master_nodes` 来解决这个问题。我们可以将此参数设置为节点数的`n/2+1`，这样我们总是需要足够数量的节点来选举主节点，就可以避免裂脑问题。

### 启用慢查询日志

我们可以通过启用慢查询日志来关注查询性能并在查询慢时获取日志。我们可以提供查询执行的持续时间，日志将选择查询执行时间大于我们可以设置的阈值的查询。收到慢查询日志后，我们可以对其进行处理以优化其性能。我们需要执行以下命令来启用慢查询日志：

```
PUT /index_name/_settings
{
  "index.search.slowlog.threshold.query.warn": "10s",
  "index.search.slowlog.threshold.query.info": "5s",
  "index.search.slowlog.threshold.query.debug": "2s",
  "index.search.slowlog.threshold.query.trace": "500ms",
  "index.search.slowlog.threshold.fetch.warn": "1s",
  "index.search.slowlog.threshold.fetch.info": "800ms",
  "index.search.slowlog.threshold.fetch.debug": "500ms",
  "index.search.slowlog.threshold.fetch.trace": "200ms",
  "index.search.slowlog.level": "info"
}
```

在前面的操作中，我们设置了各种阈值来记录慢速查询。在这里，我们可以看到`warn`阈值设置为 `10s`，`info`阈值设置为 `5s`，`debug`阈值设置为`2s`。



