---
layout: default
title: 聚合
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

使用聚合，我们可以对数据进行分组，并通过执行简单的查询来进行统计和计算。我们可以使用聚合来分析整个数据集以获得概览。我们可以使用聚合来获取完整数据集的分析视图。

Elasticsearch 根据用例提供不同类型的聚合。在 Elasticsearch 中，我们可以将聚合分为四大类：
- 桶聚合：在桶聚合中，Elasticsearch 根据给定的条件构建桶。我们可以根据文档条件将每个存储桶与键关联起来。例如，如果我们为价格字段创建桶，它们可以是`小于 500`、`从 500 到 1000`、`从 1001 到 1500`或`大于 1500`。这些文档根据其价格字段的值放入存储桶中。这只是一个例子，我们可以类似地应用桶聚合。
- 指标聚合：我们可以使用指标聚合将指标应用于一组文档。因此，只要我们想要查看基于文档某些字段的指标，我们就可以应用指标聚合。
- 矩阵聚合：矩阵聚合适用于多个字段，并根据文档的值创建一个矩阵。
- 管道聚合：管道聚合是多个聚合的分组。在这里，一个聚合的输出被进一步聚合。

现在，让我们了解 Elasticsearch 聚合的结构，以便我们可以构建聚合查询。请参阅以下显示聚合结构的表达式：
```
"aggregationss|aggs": {
    "<聚合名称>": {
        "<聚合类型>": {
            <聚合主体>
        }
    }
}
```
该表达式显示了我们如何可以定义聚合。这是理解 Elasticsearch 聚合结构的一种非常简单的方法。现在，让我们了解前面示例中每一行的含义：
- 第一行显示聚合查询的起点。在这里，我们可以使用关键字`aggregations`或缩写形式`aggs`。
- 在第二行中，我们必须指定聚合名称来标识它。
- 在第三行中，我们必须指定要应用的聚合类型，例如`terms`。
- 最后，我们必须指定实际的聚合主体。

下面，让我们用`kibana_sample_data_flights`来展示如何使用聚合，如果我们想使用`DestCountry`字段来聚合航班数据，我们可以使用下面的表达式：
```
GET kibana_sample_data_flights/_search
{
  "size": 0,
  "aggs": {
    "dest_country_aggs": {
      "terms": {
        "field": "DestCountry",
        "size": 5
      }
    }
  }
}
```
```json
{
  # ...
  "aggregations": {
    "dest_country_aggs": {
      "doc_count_error_upper_bound": 0,
      "sum_other_doc_count": 5887,
      "buckets": [
        {
          "key": "IT",
          "doc_count": 2371
        },
        {
          "key": "US",
          "doc_count": 1987
        },
        {
          "key": "CN",
          "doc_count": 1096
        },
        {
          "key": "CA",
          "doc_count": 944
        },
        {
          "key": "JP",
          "doc_count": 774
        }
      ]
    }
  }
}
```

## Bucket aggregation

我们已经介绍了桶聚合。它创建存储桶，因此得名。我们可以指定字段，它将使用其唯一值创建存储桶。我们还可以指定要构建自定义存储桶的范围。我们可以使用这些聚合的存储桶结果来显示过滤器，用户可以在其中获取完整数据集的快照。例如，通过价格范围，用户可以了解有多少种产品、是否有价格范围，或者是否有人想知道任何疾病在国家/地区的计数。 `Bucket聚合`可以有不同的类型；让我们从了解这些开始。

### Range aggregation

范围聚合使用户能够定义范围，并基于该范围创建存储桶。因此，Elasticsearch 使用范围条件并使用与存储桶条件匹配的文档计数来创建存储桶。我们可以提供`to`和`from`值来定义存储桶范围。

让我们使用``索引中的数据来创建范围聚合。我们想要通过范围聚合来查看在每周不同时间购买商品的订单信息：
```
GET kibana_sample_data_ecommerce/_search
{
  "size": 0,
  "aggs": {
    "day_aggs": {
      "range": {
        "field": "day_of_week_i",
        "ranges": [
          {
            "from": 0,
            "to": 5
          },
          {
            "from": 5,
            "to": 7
          }
        ]
      }
    }
  }
}
```
```json
{
  "aggregations": {
    "day_aggs": {
      "buckets": [
        {
          "key": "0.0-5.0",
          "from": 0,
          "to": 5,
          "doc_count": 3325
        },
        {
          "key": "5.0-7.0",
          "from": 5,
          "to": 7,
          "doc_count": 1350
        }
      ]
    }
  }
}
```

在聚合结果中，我们可以看到不同的桶，其中的键值和`doc_count`字段下的文档总数。这样，我们就可以对任何数字字段执行范围聚合。

### Composite aggregation

我们可以使用复合聚合来创建一个包含值组合的复合存储桶。使用复合聚合，我们可以轻松地为大型聚合结果集创建分页结果。我们将 `source` 参数传递给复合聚合，该参数控制构建复合存储桶的源。复合聚合有三种类型的源。

#### Terms

术语值源与我们即将介绍的术语聚合类似。在这种类型中，提取给定字段的值以构建存储桶。每个存储桶显示唯一的字段值，以及具有该字段值的文档数量。以下示例显示基于`terms`的复合聚合：
```
GET kibana_sample_data_ecommerce/_search
{
  "size": 0,
  "aggs": {
    "day_aggs": {
      "composite": {
        "sources": [
          {
            "day": {
              "terms": {
                "field": "day_of_week"
              }
            }
          }
        ]
      }
    }
  }
}
```
```json
{
  "aggregations": {
    "day_aggs": {
      "after_key": {
        "day": "Wednesday"
      },
      "buckets": [
        {
          "key": {
            "day": "Friday"
          },
          "doc_count": 770
        },
        {
          "key": {
            "day": "Monday"
          },
          "doc_count": 579
        },
        {
          "key": {
            "day": "Saturday"
          },
          "doc_count": 736
        },
        {
          "key": {
            "day": "Sunday"
          },
          "doc_count": 614
        },
        {
          "key": {
            "day": "Thursday"
          },
          "doc_count": 775
        },
        {
          "key": {
            "day": "Tuesday"
          },
          "doc_count": 609
        },
        {
          "key": {
            "day": "Wednesday"
          },
          "doc_count": 592
        }
      ]
    }
  }
}
```

#### Histogram

复合聚合通过直方图值源使用数值构建具有固定大小间隔的存储桶。我们可以传递间隔参数来定义数值字段值转换为直方图的方式。请参阅此示例，其中我们将日期间隔设置为2：
```
GET kibana_sample_data_ecommerce/_search
{
  "size": 0,
  "aggs": {
    "day_aggs": {
      "composite": {
        "sources": [
          {
            "day_histo": {
              "histogram": {
                "field": "day_of_week_i",
                "interval": 2
              }
            }
          }
        ]
      }
    }
  }
}
```
```json
{
  "aggregations": {
    "day_aggs": {
      "after_key": {
        "day_histo": 6
      },
      "buckets": [
        {
          "key": {
            "day_histo": 0
          },
          "doc_count": 1188
        },
        {
          "key": {
            "day_histo": 2
          },
          "doc_count": 1367
        },
        {
          "key": {
            "day_histo": 4
          },
          "doc_count": 1506
        },
        {
          "key": {
            "day_histo": 6
          },
          "doc_count": 614
        }
      ]
    }
  }
}
```

#### Date histogram

日期直方图与直方图类似，只不过我们在日期直方图中使用日期/时间表达式作为间隔参数。因此，每当我们想要使用日期时间而不是数字间隔来设置间隔时，我们都可以选择日期直方图而不是直方图源值进行复合聚合。

### Terms aggregation

使用术语聚合，Elasticsearch 可以根据该字段的唯一值创建动态存储桶。这种聚合对于获取字段值的概述非常重要，例如值如何在不同文档之间分布，或者哪个值最突出，哪个值最不突出。我们可以使用术语聚合来获取这些类型的详细信息。以下表达式提供了术语聚合的示例：

```
GET kibana_sample_data_ecommerce/_search
{
  "size": 0,
  "aggs": {
    "day_terms_agg": {
      "terms": {
        "field": "day_of_week",
        "size": 3
      }
    }
  }
}
```
```json
{
  "aggregations": {
    "day_terms_agg": {
      "doc_count_error_upper_bound": 0,
      "sum_other_doc_count": 2394,
      "buckets": [
        {
          "key": "Thursday",
          "doc_count": 775
        },
        {
          "key": "Friday",
          "doc_count": 770
        },
        {
          "key": "Saturday",
          "doc_count": 736
        }
      ]
    }
  }
}
```

响应显示，`kibana_sample_data_ecommerce`索引中有三个可用的星期几：`Thursday`, `Friday`和`Saturday`。每个星期几值显示为一个桶，我们可以通过 `doc_count` 字段看到文档总数。作为响应，我们可以在存储桶键之前看到一些键，例如 `doc_count_error_upper_bound` 和 `sum_other_doc_count` 。 `doc_count_error_upper_bound` 键的值显示错误的上限，该错误可能在每个聚合字段值的文档计数期间发生。 `sum_other_doc_count` 键的值是所有存储桶中所有文档计数的总和。如果由于唯一值太多而导致存储桶计数太大，Elasticsearch 只会显示最前面的术语，在这种情况下我们可以参考 `sum_other_doc_count` 值来了解完整的文档计数。这样，我们就可以将术语聚合应用于任何字段。

### Filter aggregation

使用过滤器聚合，我们可以通过对数据应用过滤器来将数据聚合到单个存储桶中。我们可以使用此聚合将聚合范围缩小到某些过滤条件，而不是完整的数据集。让我们以相同的 `kibana_sample_data_ecommerce` 索引数据为例。现在，我们如何确定数据中星期一订单的平均金额？答案是使用过滤器聚合，因为它非常适合这种聚合。以下表达式解释了过滤器聚合的工作原理：

```
GET kibana_sample_data_ecommerce/_search
{
  "size": 0,
  "aggs": {
    "day_filter": {
      "filter": {
        "term": {
          "day_of_week": "Monday"
        }
      },
      "aggs": {
        "avg_total_price_monday": {
          "avg": {
            "field": "taxful_total_price"
          }
        }
      }
    }
  }
}
```
```json
{
  "took": 2,
  "timed_out": false,
  "_shards": {
    "total": 1,
    "successful": 1,
    "skipped": 0,
    "failed": 0
  },
  "hits": {
    "total": {
      "value": 4675,
      "relation": "eq"
    },
    "max_score": null,
    "hits": []
  },
  "aggregations": {
    "day_filter": {
      "doc_count": 579,
      "avg_total_price_monday": {
        "value": 78.42882394214162
      }
    }
  }
}
```

Elasticsearch 响应显示了一个存储桶，我们可以在其中看到我们已在查询中应用的 `avg_total_price_monday` 键。该键的值为 `78.42`，这意味着该数据集星期一订单的平均金额为 `78.42`。当我们需要在实际聚合之前应用过滤器时，我们可以使用过滤器聚合。


### Filters aggregation

使用`filters aggregation`，我们可以创建多桶聚合，其中每个桶都使用过滤器创建。我们可以将其视为使用多个过滤器聚合索引以创建多个存储桶。以下表达式提供了`Filters aggregation`的示例：

```
GET kibana_sample_data_ecommerce/_search
{
  "size": 0,
  "aggs": {
    "messages": {
      "filters": {
        "filters": {
          "Monday": {
            "term": {
              "day_of_week": "Monday"
            }
          },
          "Tuesday": {
            "term": {
              "day_of_week": "Tuesday"
            }
          }
        }
      }
    }
  }
}
```

在这里，我们使用 `kibana_sample_data_ecommerce` 索引的`day_of_week`字段应用过滤器聚合。我们正在尝试创建两个存储桶：一个用于`Monday`，另一个用于`Tuesday`：

```json
{
  "hits": {
    "total": {
      "value": 4675,
      "relation": "eq"
    },
    "max_score": null,
    "hits": []
  },
  "aggregations": {
    "messages": {
      "buckets": {
        "Monday": {
          "doc_count": 579
        },
        "Tuesday": {
          "doc_count": 609
        }
      }
    }
  }
}
```

## Metrics aggregation

在指标聚合中，Elasticsearch 在聚合文档后将 `sum`、`avg` 和 `stats` 等指标应用于字段值。指标聚合可以是单值数值聚合或多值数值聚合。单值数字聚合返回单个指标，这种类型下的聚合示例是 `avg`、`max` 和 `min`。多值数字聚合返回多个指标，例如`stats`。现在，让我们通过示例讨论一些指标聚合类型，以便更好地理解。

### Min aggregation

最小值聚合是单值指标聚合，它在聚合文档后返回数值字段的最小值。该值可以是文档的数字字段值，也可以通过执行脚本来提供。以下示例显示使用相同 `kibana_sample_data_ecommerce` 索引的最小聚合：

```
GET kibana_sample_data_ecommerce/_search
{
  "size": 0,
  "aggs": {
    "min_total_price": {
      "min": {
        "field": "taxful_total_price"
      }
    }
  }
}
```

在这里，我们从 `kibana_sample_data_ecommerce` 索引的`taxful_total_price`字段值中获取最小价格。执行此命令后，我们将得到以下响应：

```json
{
  "aggregations": {
    "min_total_price": {
      "value": 6.98828125
    }
  }
}
```
我们可以看到最小价格是`6.98`，这是使用 `min` 聚合得出的。这样，我们就可以使用指标类型的最小聚合从 Elasticsearch 的索引中获取字段的最小数值。

### Max aggregation

最大聚合是单值指标聚合，它在聚合文档后返回数字字段的最大值。该值可以是文档的数字字段值，也可以通过执行脚本来提供。此示例显示使用相同 `kibana_sample_data_ecommerce` 索引的最大聚合：
```
GET kibana_sample_data_ecommerce/_search
{
  "size": 0,
  "aggs": {
    "max_total_price": {
      "max": {
        "field": "taxful_total_price"
      }
    }
  }
}
```
```json
{
  "aggregations": {
    "max_total_price": {
      "value": 2250
    }
  }
}
```

### Avg aggregation

`avg` 聚合是一种单值指标聚合，它在聚合文档后返回数字字段的平均值。该值可以是文档的数字字段值，也可以通过执行脚本来提供。我可以使用 avg 聚合从 `kibana_sample_data_ecommerce` 索引中确定订单的平均金额。以下示例显示使用相同 `kibana_sample_data_ecommerce` 索引的 `avg` 聚合：

```
GET kibana_sample_data_ecommerce/_search
{
  "size": 0,
  "aggs": {
    "avg_total_price": {
      "avg": {
        "field": "taxful_total_price"
      }
    }
  }
}
```
```json
{
  "aggregations": {
    "avg_total_price": {
      "value": 75.05542864304813
    }
  }
}
```

### Sum aggregation

总和聚合是一种单值指标聚合，它在聚合文档后返回数值字段中所有数值的总和。该值可以是文档的数字字段值，也可以通过执行脚本来提供。我可以使用 `sum` 聚合从 `kibana_sample_data_ecommerce` 索引中了解所有订单金额的总和。以下示例显示使用相同 `kibana_sample_data_ecommerce` 索引的 `avg` 聚合：

```
GET kibana_sample_data_ecommerce/_search
{
  "size": 0,
  "aggs": {
    "sum_total_price": {
      "sum": {
        "field": "taxful_total_price"
      }
    }
  }
}
```
```json
{
  "aggregations": {
    "sum_total_price": {
      "value": 350884.12890625
    }
  }
}
```

### Value count aggregation

值计数聚合是单值指标聚合，用于查找从聚合文档中获取的值的数量。例如，我们可以在 `avg` 聚合中获取数字字段的平均值，但如果我们想知道用于提取平均值的字段值的计数，则可以使用值计数聚合。下一个示例显示使用相同 `kibana_sample_data_ecommerce` 索引的 `value_count` 聚合：

```
GET kibana_sample_data_ecommerce/_search
{
  "size": 0,
  "aggs": {
    "total_price_count": {
      "value_count": {
        "field": "taxful_total_price"
      }
    }
  }
}
```
```json
{
  "aggregations": {
    "total_price_count": {
      "value": 4675
    }
  }
}
```

我们可以看到`taxful_total_price`字段的值计数为`4675`，这是使用值计数聚合得出的。这样，我们就可以使用指标类型的值计数聚合从 Elasticsearch 中的索引中获取数字字段的出现次数。

### Stats aggregation

统计聚合是一种多值度量聚合，它通过聚合文档来计算数字字段值的统计数据。这些统计数据可以是最小值、最大值、总和、计数、平均值等。该值可以是文档的数字字段值，也可以通过执行脚本来提供。下面是一个示例，显示使用相同的 `kibana_sample_data_ecommerce` 索引进行统计数据聚合：

```
GET kibana_sample_data_ecommerce/_search
{
  "size": 0,
  "aggs": {
    "total_price_stats": {
      "stats": {
        "field": "taxful_total_price"
      }
    }
  }
}
```
```json
{
  "aggregations": {
    "total_price_stats": {
      "count": 4675,
      "min": 6.98828125,
      "max": 2250,
      "avg": 75.05542864304813,
      "sum": 350884.12890625
    }
  }
}
```

### Extended stats aggregation

扩展统计信息聚合是一种多值度量聚合，它通过聚合文档来计算数字字段值的统计信息。扩展统计信息聚合是统计信息聚合的扩展版本，还显示 `sum_of_square`、`variance`、`std_deviation` 和 `std_deviation_bounds` 等其他详细信息。该值可以是文档的数字字段值，也可以通过执行脚本来提供。看一下这个示例，显示使用相同的 `kibana_sample_data_ecommerce` 索引的扩展统计信息聚合：

```
GET kibana_sample_data_ecommerce/_search
{
  "size": 0,
  "aggs": {
    "total_price_extended_stats": {
      "extended_stats": {
        "field": "taxful_total_price"
      }
    }
  }
}
```
```json
{
  "aggregations": {
    "total_price_extended_stats": {
      "count": 4675,
      "min": 6.98828125,
      "max": 2250,
      "avg": 75.05542864304813,
      "sum": 350884.12890625,
      "sum_of_squares": 39367749.294174194,
      "variance": 2787.59157113862,
      "variance_population": 2787.59157113862,
      "variance_sampling": 2788.187974983536,
      "std_deviation": 52.79764740155209,
      "std_deviation_population": 52.79764740155209,
      "std_deviation_sampling": 52.80329511482722,
      "std_deviation_bounds": {
        "upper": 180.6507234461523,
        "lower": -30.53986616005605,
        "upper_population": 180.6507234461523,
        "lower_population": -30.53986616005605,
        "upper_sampling": 180.66201887270256,
        "lower_sampling": -30.551161586606312
      }
    }
  }
}
```

### Percentile aggregation

百分位数聚合是一种多值度量聚合，它通过聚合文档来计算数值字段值的一个或多个百分位数。该值可以是文档的数字字段值，也可以通过执行脚本来提供。以下示例显示使用相同 `kibana_sample_data_ecommerce` 索引的百分位数聚合：

```
GET kibana_sample_data_ecommerce/_search
{
  "size": 0,
  "aggs": {
    "total_price_percentiles": {
      "percentiles": {
        "field": "taxful_total_price"
      }
    }
  }
}
```

我们从 `kibana_sample_data_ecommerce` 索引中获取`taxful_total_price`字段的百分位数。百分位数聚合的默认百分位数为 1、5、25、50、75、95、99。执行上述命令后，我们得到以下响应：

```json
{
  "aggregations": {
    "total_price_percentiles": {
      "values": {
        "1.0": 21.776810897435897,
        "5.0": 28.34459881573229,
        "25.0": 44.633076632815076,
        "50.0": 64.4224881848619,
        "75.0": 93.6930225380399,
        "95.0": 156.58399439102564,
        "99.0": 221.828125
      }
    }
  }
}
```

## Matrix aggregation

矩阵聚合适用于索引的多个字段，并使用从文档的给定字段中提取的值创建一个矩阵。矩阵聚合不支持脚本。

### Matrix stats aggregation

矩阵统计聚合是一种矩阵聚合，适用于单个或多个数字字段，并计算计数、均值、方差、偏度、峰度、协方差、相关性等统计数据。我们可以将其应用于多个数字字段，但我们将使用相同的 `kibana_sample_data_ecommerce` 索引示例将其用于年龄字段。此示例显示使用相同 `kibana_sample_data_ecommerce` 索引的矩阵统计聚合：

```
GET kibana_sample_data_ecommerce/_search
{
  "size": 0,
  "aggs": {
    "total_price_matrix_stats": {
      "matrix_stats": {
        "fields": ["taxful_total_price"]
      }
    }
  }
}
```
```json
{
  "aggregations": {
    "total_price_matrix_stats": {
      "doc_count": 4675,
      "fields": [
        {
          "name": "taxful_total_price",
          "count": 4675,
          "mean": 75.05542864304827,
          "variance": 2788.187974983535,
          "skewness": 15.8121491399241,
          "kurtosis": 619.1235507385912,
          "covariance": {
            "taxful_total_price": 2788.187974983535
          },
          "correlation": {
            "taxful_total_price": 1
          }
        }
      ]
    }
  }
}
```

## Pipeline aggregation

管道聚合是一种不使用文档集而是使用其他聚合的输出的聚合类型。管道聚合主要有两个系列：父级和同级。这种聚合节省了用于获取聚合结果的额外文档扫描；相反，它使用同级聚合输出作为输入。管道聚合有两个部分：
- Parent：父级是一系列管道聚合，其中聚合是在父级聚合的输出上执行的。在父族中，管道聚合可以计算新的存储桶或将新的聚合应用于现有的存储桶。
- Sibling：Sibling 是一系列管道聚合，其中聚合是对同级聚合的输出执行的。在这里，管道聚合在与同级聚合相同的级别上工作。

### Avg bucket aggregation

平均桶聚合是`Sibling`系列的管道聚合。它计算同级聚合输出的平均值，该聚合必须是多桶聚合。以下示例说明了使用相同 `kibana_sample_data_ecommerce` 索引的平均存储桶聚合：

```
GET kibana_sample_data_ecommerce/_search
{
  "size": 0,
  "aggs": {
    "total_price_range": {
      "range": {
        "field": "taxful_total_price",
        "ranges": [
          {
            "key": "0-100",
            "from": 0,
            "to": 100
          },
          {
            "key": "100-1000",
            "from": 100,
            "to": 1000
          },
          {
            "key": "More than 1000",
            "from": 1000
          }
        ]
      },
      "aggs": {
        "avg_total_price": {
          "avg": {
            "field": "taxful_total_price"
          }
        }
      }
    },
    "total_avg_total_price": {
      "avg_bucket": {
        "buckets_path": "total_price_range>avg_total_price"
      }
    }
  }
}
```

我们获取每个桶中的平均金额。现在，我们正在创建附加聚合以使用此存储桶获取 `kibana_sample_data_ecommerce` 索引的总平均金额。执行上述命令将得到以下响应：

```json
{
  "aggregations": {
    "total_price_range": {
      "buckets": [
        {
          "key": "0-100",
          "from": 0,
          "to": 100,
          "doc_count": 3669,
          "avg_total_price": {
            "value": 57.22012235111747
          }
        },
        {
          "key": "100-1000",
          "from": 100,
          "to": 1000,
          "doc_count": 1005,
          "avg_total_price": {
            "value": 138.00348258706467
          }
        },
        {
          "key": "More than 1000",
          "from": 1000,
          "doc_count": 1,
          "avg_total_price": {
            "value": 2250
          }
        }
      ]
    },
    "total_avg_total_price": {
      "value": 815.0745349793941
    }
  }
}
```

我们可以看到每个桶里面都有一个 `avg_total_price` 字段，以及 `doc_count` ，它显示了该桶的平均金额。我们应用了附加聚合来获取总平均金额，这是使用前面的同级桶聚合作为计算总平均金额的输入。这样，我们就可以使用管道类型的平均桶聚合对同级聚合应用附加聚合，以在 Elasticsearch 中获得所需的结果。

### Max bucket aggregation

最大桶聚合与平均桶聚合类似，唯一的区别是最大桶聚合用于获取最大值而不是平均值。以下示例显示使用相同 `kibana_sample_data_ecommerce` 索引的平均存储桶聚合：

```
GET kibana_sample_data_ecommerce/_search
{
  "size": 0,
  "aggs": {
    "total_price_range": {
      "range": {
        "field": "taxful_total_price",
        "ranges": [
          {
            "key": "0-100",
            "from": 0,
            "to": 100
          },
          {
            "key": "100-1000",
            "from": 100,
            "to": 1000
          },
          {
            "key": "More than 1000",
            "from": 1000
          }
        ]
      },
      "aggs": {
        "avg_total_price": {
          "avg": {
            "field": "taxful_total_price"
          }
        }
      }
    },
    "total_max_total_price": {
      "max_bucket": {
        "buckets_path": "total_price_range>avg_total_price"
      }
    }
  }
}
```
```json
{
  "aggregations": {
    "total_price_range": {
      "buckets": [
        {
          "key": "0-100",
          "from": 0,
          "to": 100,
          "doc_count": 3669,
          "avg_total_price": {
            "value": 57.22012235111747
          }
        },
        {
          "key": "100-1000",
          "from": 100,
          "to": 1000,
          "doc_count": 1005,
          "avg_total_price": {
            "value": 138.00348258706467
          }
        },
        {
          "key": "More than 1000",
          "from": 1000,
          "doc_count": 1,
          "avg_total_price": {
            "value": 2250
          }
        }
      ]
    },
    "total_max_total_price": {
      "value": 2250,
      "keys": [
        "More than 1000"
      ]
    }
  }
}
```

### Sum bucket aggregation

`Sum bucket aggregation`是`Sibling`家族的管道聚合。它计算同级聚合的所有存储桶中指定字段的总和。此示例说明使用相同 `kibana_sample_data_ecommerce` 索引的`Sum bucket aggregation`：

```
GET kibana_sample_data_ecommerce/_search
{
  "size": 0,
  "aggs": {
    "total_price_range": {
      "range": {
        "field": "taxful_total_price",
        "ranges": [
          {
            "key": "0-100",
            "from": 0,
            "to": 100
          },
          {
            "key": "100-1000",
            "from": 100,
            "to": 1000
          },
          {
            "key": "More than 1000",
            "from": 1000
          }
        ]
      },
      "aggs": {
        "avg_total_price": {
          "avg": {
            "field": "taxful_total_price"
          }
        }
      }
    },
    "total_sum_total_price": {
      "sum_bucket": {
        "buckets_path": "total_price_range>avg_total_price"
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
      "value": 4675,
      "relation": "eq"
    },
    "max_score": null,
    "hits": []
  },
  "aggregations": {
    "total_price_range": {
      "buckets": [
        {
          "key": "0-100",
          "from": 0,
          "to": 100,
          "doc_count": 3669,
          "avg_total_price": {
            "value": 57.22012235111747
          }
        },
        {
          "key": "100-1000",
          "from": 100,
          "to": 1000,
          "doc_count": 1005,
          "avg_total_price": {
            "value": 138.00348258706467
          }
        },
        {
          "key": "More than 1000",
          "from": 1000,
          "doc_count": 1,
          "avg_total_price": {
            "value": 2250
          }
        }
      ]
    },
    "total_sum_total_price": {
      "value": 2445.2236049381822
    }
  }
}
```

