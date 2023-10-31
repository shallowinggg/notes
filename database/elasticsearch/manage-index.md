---
layout: default
title: 管理索引
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

## 创建索引

在Elasticsearch中，我们可以创建索引来保存相似类型的记录；它类似于关系数据库中的表。我们可以在Elasticsearch中创建多个索引，每个索引可以有多个文档。我们可以通过 PUT 请求使用 Elasticsearch `create index API`创建索引。 Elasticsearch 索引可以使用不同的方式创建，例如不使用任何文档创建空白索引，或者对自动创建索引的文档建立索引。我们还可以通过不同的来源创建索引，例如从不同的 Beats 或 Logstash 推送数据。

### without document

```
PUT testindex
```

获取索引：
```
GET testindex
```

### with document

```
POST testindex1/_doc/1
{
  "name": "test",
  "gender": "male",
  "city": "Shanghai"
}
```

当我们直接索引文档而不显式创建映射时，会出现问题。这是因为 Elasticsearch 猜测我们尝试索引的文档字段的数据类型，但这种猜测并不总是正确的。将字段与每个字段包含的数据的确切类型进行映射是必要的。

### Get mapping

```
GET testindex1/_mapping
```

### Create mapping

```
PUT testindex1/_mapping
{
  "properties": {
    "firstname": {
      "type": "keyword"
    },
    "lastname": {
      "type": "keyword"
    },
    "account_number": {
      "type": "integer"
    },
    "balance": {
      "type": "integer"
    },
    "age": {
      "type": "integer"
    },
    "gender": {
      "type": "keyword"
    }
  }
}
```
