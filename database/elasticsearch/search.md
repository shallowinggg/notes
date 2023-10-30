---
layout: default
title: 搜索
parent: Elasticsearch
grand_parent: 数据库
---

## Request body search

Elasticsearch request body使用查询 DSL（特定于域的语言），它作为 API 层来执行原始 Elasticsearch 查询。使用请求体查询，我们可以使用方便且简洁的语法轻松构建复杂的搜索查询和数据聚合查询。

```http
GET kibana_sample_data_ecommerce/_search
{
  "query": {
    "term": {
      "customer_first_name": {
        "value": "eddie"
      }
    }
  }
}
```

在前面的查询中，我们通过构造一个查询来将术语值与 `eddie` 相匹配来搜索`customer_first_name` 为 `eddie` 的文档。执行表达式后，我们将得到以下响应：

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
          "category": [
            "Men's Clothing"
          ],
          "currency": "EUR",
          "customer_first_name": "Eddie",
          "customer_full_name": "Eddie Underwood",
          "customer_gender": "MALE",
          "customer_id": 38,
          "customer_last_name": "Underwood",
          "customer_phone": "",
          "day_of_week": "Monday",
          "day_of_week_i": 0,
          "email": "eddie@underwood-family.zzz",
          "manufacturer": [
            "Elitelligence",
            "Oceanavigations"
          ],
          "order_date": "2023-11-13T09:28:48+00:00",
          "order_id": 584677
          // ...
        }
      }
      // ...
    ]
  }
}
```

我们必须明白，这里我们不能搜索名为 `Eddie` 的名称，因为在 `term` 查询中，`term` 被转换为小写。因此，它与 `Eddie` 的术语值不匹配。我们将在接下来详细介绍这一点。

`kibana_sample_data_ecommerce`索引的部分`mappings`如下：
```json
{
  "kibana_sample_data_ecommerce": {
    "mappings": {
      "properties": {
        "category": {
          "type": "text",
          "fields": {
            "keyword": {
              "type": "keyword"
            }
          }
        },
        "currency": {
          "type": "keyword"
        },
        "customer_birth_date": {
          "type": "date"
        },
        "customer_first_name": {
          "type": "text",
          "fields": {
            "keyword": {
              "type": "keyword",
              "ignore_above": 256
            }
          }
        }
      }
    }
  }
}
```


### Query vs Filter

在Elasticsearch中，我们可以使用查询或过滤器来搜索文档，但是查询和过滤器之间是有区别的。通常，当我们想知道查询子句与文档的匹配程度时，我们会使用查询，而过滤器可用于了解文档是否与查询子句完全匹配。在查询的情况下，相关性分数是根据匹配计算的，该分数显示在 `_score` 元字段下。在使用过滤器的情况下，不会计算分数，因为它要么与术语完全匹配，要么不存在匹配，因此在过滤器的情况下不存在相关性。这样，当我们想要进行精确匹配时，我们可以使用过滤器，但是当我们想要执行搜索并希望查看搜索关键字与文档的匹配程度时，我们可以使用查询。

### Query

使用查询关键字，我们可以执行正文搜索，我们可以根据要搜索的字段名称传递搜索值。让我们构建一个查询，看看如何搜索任何字段值。在前面的查询中，我们进行了术语查询搜索，其中我们以小写形式提供了字段值。但是，如果我们想要进行精确搜索，我们可以使用 `customer_first_name.keyword` 在其中搜索精确值而不是分析值。参考下面的表达式：

```http
GET kibana_sample_data_ecommerce/_search
{
  "query": {
    "term": {
      "customer_first_name.keyword": {
        "value": "Eddie"
      }
    }
  }
}
```

#### Query types

我们主要可以在 Elasticsearch 上执行两种类型的查询以及复合查询：
- `Full-text search`：在全文搜索查询中，我们将搜索文本与文本字段进行匹配。在进行实际搜索之前，根据字段类型使用分析器。文本与字段值匹配后返回相关结果。
- `Term-level queries`：对于术语级查询，在搜索之前不执行任何分析，它们用于将精确的术语值与字段进行匹配。
- `Compound queries`：我们可以连接多个简单查询来创建复合查询。我们可以通过连接简单查询来构造复杂查询。在搜索应用程序中，您需要创建复合查询。

#### Full-text search

正如我们之前提到的，执行分析，用于将文本与基于全文搜索的查询的字段值进行匹配。我们有以下查询选项来执行全文搜索查询：
- match_all
- match
- match_phrase
- multi_match
- query_string


##### match_all

使用`match_all`查询，我们可以匹配所有文档，它为所有返回的文档提供了1.0的高分，因为我们没有提供任何搜索词。我们可以通过执行以下表达式来执行匹配所有查询：

```http
GET kibana_sample_data_ecommerce/_search
{
  "query": {
    "match_all": {}
  }
}
```

我们还有`match_none`查询，它与`match_all`查询相反，不匹配任何文档。不匹配查询的语法如下：

```http
GET kibana_sample_data_ecommerce/_search
{
  "query": {
    "match_none": {}
  }
}
```

##### match

使用匹配查询，我们可以获取给定值的匹配文档，给定值可以是文本、数字、布尔值或日期。在此查询中，首先分析提供的文本，然后与字段值进行匹配：

```http
GET kibana_sample_data_ecommerce/_search
{
  "query": {
    "match": {
      "customer_first_name": {
        "query": "Eddie"
      }
    }
  }
}
```

在匹配查询中，我们还可以提供像 `and` 或 `or` 这样的运算符。默认情况下，运算符是or：
```http
GET kibana_sample_data_ecommerce/_search
{
  "query": {
    "match": {
      "customer_full_name": {
        "query": "Eddie Underwood"
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
      "value": 158,
      "relation": "eq"
    }
  }
  // ...
}
```

但我们可以如下设置来使用`and`：
```http
GET kibana_sample_data_ecommerce/_search
{
  "query": {
    "match": {
      "customer_full_name": {
        "query": "Eddie Underwood",
        "operator": "and"
      }
    }
  }
}
```
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
    "max_score": 8.399748,
    "hits": [
      {
        "_index": "kibana_sample_data_ecommerce",
        "_id": "s2i3f4sBzCHv00RXUIpy",
        "_score": 8.399748,
        "_source": {
          "category": [
            "Men's Clothing"
          ],
          "currency": "EUR",
          "customer_first_name": "Eddie",
          "customer_full_name": "Eddie Underwood",
          "customer_gender": "MALE",
          "customer_id": 38,
          "customer_last_name": "Underwood",
          "customer_phone": "",
          "day_of_week": "Monday",
          "day_of_week_i": 0,
          "email": "eddie@underwood-family.zzz",
          // ...
        }
      }
    ]
  }
}
```

##### match_phrase

`match_phrase` 查询检索匹配完整句子而不是单个单词的文档。它还会匹配搜索条件中具有相同单词顺序的文档。参考这个例子：
```http
GET kibana_sample_data_ecommerce/_search
{
  "query": {
    "match_phrase": {
      "customer_full_name": {
        "query": "Eddie Underwood"
      }
    }
  }
}
```

在前面的查询中，我们尝试获取准确的姓名 `Eddie Underwood`，而不是匹配不同文档中的个人名字和姓氏。因此，前面的查询将仅返回姓名为 `Eddie Underwood` 的文档。看一下前面的查询的响应：
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
    "max_score": 8.399748,
    "hits": [
      {
        "_index": "kibana_sample_data_ecommerce",
        "_id": "s2i3f4sBzCHv00RXUIpy",
        "_score": 8.399748,
        "_source": {
          "category": [
            "Men's Clothing"
          ],
          "currency": "EUR",
          "customer_first_name": "Eddie",
          "customer_full_name": "Eddie Underwood",
          "customer_gender": "MALE",
          "customer_id": 38,
          "customer_last_name": "Underwood",
          "customer_phone": "",
          "day_of_week": "Monday",
          "day_of_week_i": 0,
          "email": "eddie@underwood-family.zzz",
          // ...
        }
      }
    ]
  }
}
```

这样，我们可以使用 `match_phrase` 查询来搜索确切的短语而不是单个单词。

##### multi_match

使用 `multi_match` 查询，我们可以搜索文档的多个字段。当我们想要将某些内容与多个字段进行匹配时，这非常适合。使用下面的表达式，我们可以执行 `multi_match` 查询：
```http
GET kibana_sample_data_ecommerce/_search
{
  "query": {
    "multi_match": {
      "query": "Eddie Underwood",
      "fields": ["customer_first_name", "customer_full_name"]
    }
  }
}
```

##### query_string

`query_string`提供了一种通过解析器进行解析的语法，并且可以根据运算符（如 AND、OR 或 NOT）进行拆分。分割后，先对文本进行分析，然后再将其与字段进行匹配。我们可以使用`query_string`构建复杂的查询，因为它支持通配符和多字段搜索。此外，可以使用多个运算符。以下表达式显示了查询字符串示例：
```http
GET kibana_sample_data_ecommerce/_search
{
  "query": {
    "query_string": {
      "query": "Eddie OR Underwood",
      "default_field": "customer_full_name"
    }
  }
}
```

在前面的查询中，我们尝试使用 `OR` 运算符搜索名字和姓氏。因此，此查询将返回与名字、姓氏或名字和姓氏相匹配的所有文档。我们还提供了它应该匹配的默认字段；如果查询字符串中未提供该字段，则将使用该字段。我们还可以针对多种情况创建组。例如，看看下面的例子：
```http
GET kibana_sample_data_ecommerce/_search
{
  "query": {
    "query_string": {
      "query": "(Eddie AND Underwood) OR (Mary AND Bailey)",
      "default_field": "customer_full_name"
    }
  }
}
```

我们可以通过在查询中提供字段参数来对多个字段执行查询。我们可以在查询中添加多个字段，例如： `"fields": ["customer_first_name", "customer_full_name"]`。

#### Term-level queries

我们有以下基于术语的搜索选项，使用它们可以执行不同的基于术语的查询：
- Term query
- Terms query
- Exists query
- Range query
- Fuzzy query
- Wildcard query

##### Term query

正如我们之前讨论的，术语查询使用给定字段的确切术语执行搜索。通常，我们对精确值使用术语查询，例如价格值、年龄、任何 ID 或用户名。因此，我们大多数情况下可以将其用于非文本字段，但不建议用于文本字段。我们可以对文本字段使用匹配查询。以下表达式显示了术语查询示例：

```http
GET kibana_sample_data_ecommerce/_search
{
  "query": {
    "term": {
      "customer_id": {
        "value": 38
      }
    }
  }
}
```

##### Terms query

我们使用`Terms query`来获取给定字段具有一个或多个精确术语的文档。`Terms query`与`Term query`非常相似，只是我们可以使用术语查询搜索多个值。以下表达式显示了`Terms query`：

```http
GET kibana_sample_data_ecommerce/_search
{
  "query": {
    "terms": {
      "customer_id": [37, 38]
    }
  }
}
```
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
      "value": 159,
      "relation": "eq"
    }
    //...
  }
}
```

##### Exists query

使用`Exists query`，我们可以获取包含我们正在查找的字段的文档。由于 Elasticsearch 是`schema-less`的，因此该字段可能并不存在于所有文档中。我们可以使用以下表达式来查找文档中存在的任何字段：

```http
GET kibana_sample_data_ecommerce/_search
{
  "query": {
    "exists": {
      "field": "event"
    }
  }
}
```

> `kibana_sample_data_ecommerce`索引中没有空字段，因此上面的请求无法测试`exists`，仅供演示

##### Range query

使用范围查询，我们可以获取包含给定范围内字段值的文档，例如获取`customer_id`在 37 到 38 之间的所有文档。以下表达式提供了范围查询的示例：
```http
GET kibana_sample_data_ecommerce/_search
{
  "query": {
    "range": {
      "customer_id": {
        "gte": 37,
        "lte": 38
      }
    }
  }
}
```
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
      "value": 159,
      "relation": "eq"
    }
    //...
  }
}
```

##### Fuzzy query

使用模糊查询，我们可以获取与搜索词相似的文档，并且可以衡量该相似性的`Levenshtein edit distance`。`Levenshtein edit distance`是一个字符串度量，使用它我们可以测量两个序列之间的差异。`Levenshtein edit distance`是根据一个字符将一个术语变成另一术语所需的更改次数来计算的。一个例子是通过将 `c` 更改为 `r` 来将`cat`转换为`rat`。请参阅以下示例：
```http
GET kibana_sample_data_ecommerce/_search
{
  "query": {
    "fuzzy": {
      "customer_first_name": "eddi"
    }
  }
}
```

前面的表达式显示了一个模糊查询，我们尝试使用文本 `eddi` 搜索名称。这将返回单字符修改可以将值与任何字段匹配的所有文档。这种修改可以是字符替换、添加、删除或调换两个相邻字符。执行上述命令后，我们可以得到以下响应：

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
    }
    // ...
  }
}
```

##### Wildcard query

使用通配符查询，我们可以提供通配符模式来获取与通配符模式匹配的文档。我们可以提供通配符运算符来匹配零个或多个字符。看看这个表达式：
```http
GET kibana_sample_data_ecommerce/_search
{
  "query": {
    "wildcard": {
      "customer_first_name": {
        "value": "edd*"
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
    }
    // ...
  }
}
```

此结果基于我们提到的 `edd*` 的通配符查询。我们可以根据我们的要求调整通配符查询。这样，我们就可以应用通配符查询来使用提供的模式来获取文档。

#### Compound queries

在 Elasticsearch 中，我们创建查询子句来执行搜索操作。这些对于执行简单的搜索操作很有用，但是我们可以通过组合这些查询子句来执行复杂的搜索操作。这可以通过组合查询 JSON 结构来完成。这些 Elasticsearch 子句可以有两种类型：叶子句和复合子句。在叶子子句中，我们通常根据索引搜索关键字，因此结构非常简单。另一方面，我们将不同的子句组合成复合子句。

##### Boolean query

在布尔查询中，我们通过布尔运算符组合其他查询来获取匹配的文档。布尔查询中有不同的出现类型：
- must：匹配文档必须与子句匹配。
- should：匹配的文档应该与子句匹配。
- must_not：匹配的文档不能与子句匹配。
- filter：该子句必须出现在匹配的文档中。唯一的区别是`must`会影响分数，而`filter`则不会。

我们可以使用 bool 关键字来组合不同的子句；参考给定的例子：
```http
GET kibana_sample_data_ecommerce/_search
{
  "query": {
    "bool": {
      "must": [
        {
          "term": {
            "customer_first_name": {
              "value": "eddie"
            }
          }
        }
      ],
      "must_not": [
        {
          "range": {
            "day_of_week_i": {
              "gte": 0,
              "lte": 3
            }
          }
        }
      ],
      "should": [
        {
          "term": {
            "total_quantity": {
              "value": 1
            }
          }
        }
      ]
    }
  }
}
```

##### Boosting query

提升查询可用于获取与正查询匹配的文档，但如果它与负查询匹配，则会降低文档的相关性得分。在提升查询中，我们提供正面和负面匹配标准来影响相关性得分。请参阅此处给出的示例：
```http
GET kibana_sample_data_ecommerce/_search
{
  "query": {
    "boosting": {
      "positive": {
        "term": {
          "customer_first_name": {
            "value": "eddie"
          }
        }
      },
      "negative": {
        "term": {
          "day_of_week_i": {
            "value": 0
          }
        }
      },
      "negative_boost": 0.5
    }
  }
}
```

观察返回结果中`_score`的变化。

## Multi-search

我们可以使用多搜索 API 或多搜索模板在 Elasticsearch 上执行多搜索。使用多搜索，我们可以在一次点击 Elasticsearch 时提供多个搜索查询。多搜索的结构如下：
```
header\n
body\n
header\n
body\n
```

使用前面的结构，我们可以提供多个查询。现在，让我们看看如何使用多搜索 API 和模板来完成此操作。

### Multi-search API

使用多搜索 API，我们可以在单个 API 请求中执行多个搜索。请参阅以下示例来执行多次搜索：
```http
GET kibana_sample_data_flights/_msearch
{}
{"query": {"match": {"FlightNum": "9HY9SWR"}}}
{"index": "kibana_sample_data_ecommerce"}
{"query": {"match": {"customer_first_name": "George"}}}
```

使用前面的表达式，我们在单个 API 命中中跨多个索引搜索数据。在第一次搜索中，我们从 `kibana_sample_data_flights` 索引中获取`FlightNum`为 `9HY9SWR` 的文档，并从下一个索引 `kibana_sample_data_ecommerce` 中获取 `customer_first_name` 为 `George` 的文档。这样，我们可以在一次命中中搜索多个索引。

### Multi-search template

多搜索模板与多搜索 API 类似，因为它们遵循相同的结构。唯一的区别是多搜索模板支持文件、存储和内联模板。


## Explain API

解释 API 解释查询和文档的分数。它为我们提供了有关查询匹配或不匹配特定文档的原因的信息。在这里，我们必须提供文档 ID 作为参数，因为解释查询使用此 ID 提供是否匹配的解释。

```http
GET kibana_sample_data_ecommerce/_explain/w2i3f4sBzCHv00RXUIpy
{
  "query": {
    "match": {
      "customer_first_name": "eddie"
    }
  }
}
```
```json
{
  "_index": "kibana_sample_data_ecommerce",
  "_id": "w2i3f4sBzCHv00RXUIpy",
  "matched": false,
  "explanation": {
    "value": 0,
    "description": "no matching term",
    "details": []
  }
}
```

在前面的查询中，`w2i3f4sBzCHv00RXUIpy`是与给定查询匹配的文档的 id，我们利用这个 id 来了解该文档是如何与给定查询匹配的。

## Profile API

我们可以使用 `Profile API` 进行调试，因为它提供了搜索请求的各个组件的执行时间的详细信息。使用此 API，我们可以获得有关某些请求速度缓慢的详细信息，并且可以使用该信息来提高性能。在任何搜索请求中，我们可以通过添加`profile`参数来启用分析。以下表达式提供了 `Profile API` 的示例：
```http
GET kibana_sample_data_ecommerce/_search
{
  "profile": true,
  "query": {
    "match": {
      "customer_first_name": "eddie"
    }
  }
}
```
```json
{
  "took": 21,
  "timed_out": false,
  // ...
  "profile": {
    "shards": [
      {
        "id": "[4qt6LP0PTai4mu6oRDRi0g][kibana_sample_data_ecommerce][0]",
        "node_id": "4qt6LP0PTai4mu6oRDRi0g",
        "shard_id": 0,
        "index": "kibana_sample_data_ecommerce",
        "cluster": "(local)",
        "searches": [
          {
            "query": [
              {
                "type": "TermQuery",
                "description": "customer_first_name:eddie",
                "time_in_nanos": 536718,
                "breakdown": {
                  "set_min_competitive_score_count": 2,
                  "match_count": 0,
                  "shallow_advance_count": 0,
                  "set_min_competitive_score": 4205,
                  "next_doc": 32216,
                  "match": 0,
                  "next_doc_count": 100,
                  "score_count": 100,
                  "compute_max_score_count": 0,
                  "compute_max_score": 0,
                  "advance": 9032,
                  "advance_count": 2,
                  "count_weight_count": 0,
                  "score": 42178,
                  "build_scorer_count": 4,
                  "create_weight": 87085,
                  "shallow_advance": 0,
                  "count_weight": 0,
                  "create_weight_count": 1,
                  "build_scorer": 362002
                }
              }
            ],
            "rewrite_time": 8526,
            "collector": [
              {
                "name": "QueryPhaseCollector",
                "reason": "search_query_phase",
                "time_in_nanos": 437629,
                "children": [
                  {
                    "name": "SimpleTopScoreDocCollector",
                    "reason": "search_top_hits",
                    "time_in_nanos": 152983
                  }
                ]
              }
            ]
          }
        ],
        "aggregations": [],
        "fetch": {
          "type": "fetch",
          "description": "",
          "time_in_nanos": 4453339,
          "breakdown": {
            "load_stored_fields": 282643,
            "load_source": 39182,
            "load_stored_fields_count": 10,
            "next_reader_count": 1,
            "load_source_count": 10,
            "next_reader": 2533878
          },
          "debug": {
            "stored_fields": [
              "_id",
              "_routing",
              "_source"
            ]
          },
          "children": [
            {
              "type": "FetchSourcePhase",
              "description": "",
              "time_in_nanos": 6788,
              "breakdown": {
                "process_count": 10,
                "process": 5963,
                "next_reader": 825,
                "next_reader_count": 1
              },
              "debug": {
                "fast_path": 10
              }
            },
            {
              "type": "StoredFieldsPhase",
              "description": "",
              "time_in_nanos": 9856,
              "breakdown": {
                "process_count": 10,
                "process": 5324,
                "next_reader": 4532,
                "next_reader_count": 1
              }
            }
          ]
        }
      }
    ]
  }
}
```

在前面的分析结果中，我们可以看到不同的详细信息，我们将在此处了解这些细节：
- 在`shards`部分下，我们可以看到响应中使用的分片 ID。
- 然后，我们在`searches`下有一个`query`，其中包含查询执行的详细信息。
- 在`query`下，我们有一个`breakdown`部分，显示低级 `Lucene` 查询的执行统计信息。
- 对于每个查询，我们都有`rewrite_time`，它表示累积重写时间。
- 有一个`collector`，用于介绍 `Lucene` 收集器，使用它来执行搜索。
- 然后，我们有`aggregation`部分，它告诉我们聚合的执行情况。

这样，我们就可以使用 `Profile API` 来获取查询执行的详细信息，例如各个查询组件的计时。我们还可以确定查询速度慢的原因，并可以对其进行调整以提高性能。


