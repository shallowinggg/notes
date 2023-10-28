---
layout: default
title: 数据准备
parent: Elasticsearch
grand_parent: database
---

## Why

随着我们存储的数据呈指数级增长，从数据集中获取任何特定内容并不容易。当我们谈论搜索时，并不意味着搜索完全匹配的内容。搜索条件可能与实际保存的数据略有不同；这可能是因为拼写错误或使用了拼写不同的同义词或拼音词。在任何这些情况下，我们都应该在实际索引数据之前进行计划。我们应该知道用例是什么以及我们应该在多大程度上支持数据搜索。这意味着如果我们想要应用模糊搜索、同义词搜索或语音搜索，我们只需对搜索词进行词干提取即可实现。在某些情况下，我们不想错过任何情况，并且希望向最终用户显示结果，即使他们输入了错误的单词。


## Analyzer

分析器是特殊的算法，决定如何将字符串字段值转换为术语并以倒排索引的形式存储。分析器有不同类型，它们解析文本的逻辑与其他分析器有很大不同。为用例选择正确的分析器是一门艺术，因为不同的场景有不同的用例。 Elasticsearch 分析器是字符过滤器、分词器和标记过滤器的组合。看一下下图：


![](https://raw.githubusercontent.com/shallowinggg/notes/main/images/es/analyzer.png)

在这里，我们可以看到`字符过滤器`、`分词器`和`分词过滤器`如何协同工作来实现分析器的目的。在图中，我们有一段文字说 `Elasticsearch is an Awesome Search Engine`，其中我们最初有 `<h2>` 标签。在第一级，`html_strip` 字符过滤器从文本中删除 `<h2>` 标记。之后，标准标记器开始工作并将句子转换为单独的标记。最后，小写标记过滤器将标记转换为小写标记。这样，分析器将句子转换为小写标记。

我们有许多分析器作为 Elasticsearch 构建中的默认分析器。如果我们想配置自定义分析器，可以使用Elasticsearch的设置API来完成。以下代码片段显示了自定义分析器的配置：

```http
PUT /test

{
  "settings": {
    "index": {
      "analysis": {
        "analyzer": {
          "customHTMLSnowball": {
            "type": "custom",
            "char_filter": [
              "html_strip"
            ],
            "tokenizer": "standard",
            "filter": [
              "lowercase",
              "stop",
              "snowball"
            ]
          }
        }
      }
    }
  },
  "mappings": {
    "properties": {
      "text": {
        "type": "text",
        "fields": {
          "english": {
            "type": "text",
            "analyzer": "english"
          },
          "custom": {
            "type": "text",
            "analyzer": "customHTMLSnowball"
          }
        }
      }
    }
  }
}
```

在前面的代码块中，我们执行以下操作：

- 我们使用 `html_strip` 字符过滤器从源文本中删除所有 HTML 标记。
- 我们使用标准分词器来分解单词并删除标点符号。
- 然后，我们使用token过滤器，其中第一个是`lowercase`，将所有token转换为小写。
- 之后，我们有一个停止标记过滤器，用于删除所有停止词，如 the、and 等。
- 最后，我们有雪球标记过滤器，使用它我们可以阻止所有标记。

同时，我们通过`mappings`在字段上指定分析器。`text`字段使用默认的标准分析器，`text.english`字段使用`english`分析器，`text.custom`字段使用自定义的`customHTMLSnowball`分析器。

下面，我们使用`_analyze` endpoint测试分析器如何工作。首先，我们测试`text`字段上的默认分析器：

```http
GET /test/_analyze
{
  "field": "text",
  "text": "Elasticsearch is an Awesome Search Engine"
}
```

```json
{
  "tokens": [
    {
      "token": "elasticsearch",
      "start_offset": 0,
      "end_offset": 13,
      "type": "<ALPHANUM>",
      "position": 0
    },
    {
      "token": "is",
      "start_offset": 14,
      "end_offset": 16,
      "type": "<ALPHANUM>",
      "position": 1
    },
    {
      "token": "an",
      "start_offset": 17,
      "end_offset": 19,
      "type": "<ALPHANUM>",
      "position": 2
    },
    {
      "token": "awesome",
      "start_offset": 20,
      "end_offset": 27,
      "type": "<ALPHANUM>",
      "position": 3
    },
    {
      "token": "search",
      "start_offset": 28,
      "end_offset": 34,
      "type": "<ALPHANUM>",
      "position": 4
    },
    {
      "token": "engine",
      "start_offset": 35,
      "end_offset": 41,
      "type": "<ALPHANUM>",
      "position": 5
    }
  ]
}
```

接下来，我们测试`text.english`字段：
```http
GET /test/_analyze
{
  "field": "text.english",
  "text": "Elasticsearch is an Awesome Search Engine"
}
```
```json
{
  "tokens": [
    {
      "token": "elasticsearch",
      "start_offset": 0,
      "end_offset": 13,
      "type": "<ALPHANUM>",
      "position": 0
    },
    {
      "token": "awesom",
      "start_offset": 20,
      "end_offset": 27,
      "type": "<ALPHANUM>",
      "position": 3
    },
    {
      "token": "search",
      "start_offset": 28,
      "end_offset": 34,
      "type": "<ALPHANUM>",
      "position": 4
    },
    {
      "token": "engin",
      "start_offset": 35,
      "end_offset": 41,
      "type": "<ALPHANUM>",
      "position": 5
    }
  ]
}
```

最后，我们测试`text.custom`上的自定义分析器：
```http
GET /test/_analyze
{
  "field": "text.custom",
  "text": "<h2>Elasticsearch</h2> is an Awesome Search Engine"
}
```
```json
{
  "tokens": [
    {
      "token": "elasticsearch",
      "start_offset": 4,
      "end_offset": 17,
      "type": "<ALPHANUM>",
      "position": 0
    },
    {
      "token": "awesom",
      "start_offset": 29,
      "end_offset": 36,
      "type": "<ALPHANUM>",
      "position": 3
    },
    {
      "token": "search",
      "start_offset": 37,
      "end_offset": 43,
      "type": "<ALPHANUM>",
      "position": 4
    },
    {
      "token": "engin",
      "start_offset": 44,
      "end_offset": 50,
      "type": "<ALPHANUM>",
      "position": 5
    }
  ]
}
```

### 内建分析器

Elasticsearch 附带了很多内置的分析器，我们可以直接使用这些分析器，无需任何进一步的配置。

#### Standard analyzer

当我们不指定分析器时，默认使用标准分析器。它使用基于语法的 Unicode 文本分段算法来对句子进行标记。

它接受以下参数：
- `max_token_length`：表示最大token长度。如果我们提供此长度，分析器将根据 `max_token_length` 值提供的长度分割token。 `max_token_length` 的默认值为 255 个字符。 - `stopwords`：在这里，我们可以指定停止词，并且我们可以使用 `the_english` 来指定预定义的停止词。我们还可以指定停用词的数组列表。默认情况下指定`_none_`停用词。
- `stopword_path`：在这里，我们可以指定包含停用词的文件路径。

我们可以使用前面的参数和分析查询来进一步调整分析过程。

#### Simple analyzer

简单分析器为每个非字母术语创建标记；它可以是空格或任何其他字符。我们无法配置简单分析器，因为它只包含一个小写分词器。以下代码片段显示了简单的分析器以及它如何分解标记：

```http
POST _analyze
{
  "analyzer": "simple",
  "text": "Elasticsearch, is an Awesome Search Engine!"
}
```

它分析出的token序列如下：
```
[elasticsearch, is, an, awesome, search, engine]
```

这样，如果在单词之间遇到任何特殊字符，它会将单词分解为token。

#### Whitespace analyzer

空白分析器使用空白字符将文本转换为术语。空白分析器不会将术语转换为小写：

```http
POST _analyze
{
  "analyzer": "whitespace",
  "text": "Elasticsearch, is an Awesome Search Engine!"
}
```

它将创建以下tokens：
```
[Elasticsearch, is, an, awesome, search, engine!]
```

我们可以看到单词`Elasticsearch`没有转换为小写。

#### Stop analyzer

停止词分析器与简单分析器非常相似，具有从术语中删除停止词的附加功能。看一下下面的示例，我们在同一文本上应用停止分析器：
```http
POST _analyze
{
  "analyzer": "stop",
  "text": "Elasticsearch, is an Awesome Search Engine!"
}
```

它将创建以下tokens：
```
[elasticsearch, awesome, search, engine]
```

我们可以看到停止分析器还从术语中删除了停止词 `is` 和 `an`。

#### Keyword analyzer

关键字分析器返回输入字符串的一个完整集合标记。以下示例显示关键字分析器如何创建token：
```http
POST _analyze
{
  "analyzer": "keyword",
  "text": "Elasticsearch, is an Awesome Search Engine!"
}
```
```
["Elasticsearch, is an Awesome Search Engine!"]
```

#### Pattern analyzer

模式分析器使用正则表达式将文本拆分为术语。它还支持停止词并将术语转换为小写。

以下代码显示了如何通过non-word模式来创建模式分析器：
```http
PUT /test2
{
  "settings": {
    "analysis": {
      "analyzer": {
        "my_email": {
          "type": "pattern",
          "pattern": "\\W|_",
          "lowercase": true
        }
      }
    }
  }
}
```

创建分析器后，我们可以将其与字符串一起应用。参考下面的代码片段：
```http
POST /test2/_analyze
{
  "analyzer": "my_email",
  "text": "anurag.srivastava@yopmail.com"
}
```
```
[anurag、srivastava、yopmail、com]
```

#### Language analyzer

语言分析器为特定语言文本创建术语。支持的语言有很多，如阿拉伯语、孟加拉语、捷克语、丹麦语、荷兰语、英语、芬兰语、法语、德语、希腊语、印地语、瑞典语等。

例如，我们可以将英语分析器用作自定义分析器：
```http
PUT /english_index
{
  "settings": {
    "analysis": {
      "filter": {
        "english_stop": {
          "type": "stop",
          "stopwords": "_english_"
        },
        "english_keywords": {
          "type": "keyword_marker",
          "keywords": [
            "example"
          ]
        },
        "english_stemmer": {
          "type": "stemmer",
          "language": "english"
        },
        "english_possessive_stemmer": {
          "type": "stemmer",
          "language": "possessive_english"
        }
      },
      "analyzer": {
        "rebuilt_english": {
          "tokenizer": "standard",
          "filter": [
            "english_possessive_stemmer",
            "lowercase",
            "english_stop",
            "english_keywords",
            "english_stemmer"
          ]
        }
      }
    }
  }
}
```

#### Fingerprint analyzer

指纹分析器使用指纹算法来创建簇。它将文本转换为小写，删除扩展字符，删除重复并将单词连接成单个标记。如果使用指纹分析器配置查询，则停用词将被删除。

以下代码显示了指纹分析器：
```http
POST _analyze
{
  "analyzer": "fingerprint",
  "text": "Elasticsearch, is an Awesome Search Engine! awesome"
}
```
```
["an awesome elasticsearch engine is search"]
```

#### Custom analyzer

如果内置分析器不合适，我们可以使用自定义分析器。我们可以在自定义分析器中组合不同的字符过滤器、分词器和分词过滤器，这样我们就可以根据要求调整分词器和过滤器。每个自定义分析器都是以下各项的组合：

- 分词器
- 零个或多个字符过滤器
- 零个或多个分词过滤器

## Tokenizer

分词器从字符串接收字符流并将其转换为称为`token`的单个单词。分词器还通过字符偏移量的开头和结尾来跟踪每个术语的顺序。

### 面向单词的分词器

现在，我们将讨论用于使用单个单词对全文进行标记的标记器。

#### Standard Tokenizer

标准标记生成器使用 Unicode 文本分段算法来生成基于语法的标记。它支持不同的语言。以下代码片段显示了应用于文本的标准分词器：
```http
POST _analyze
{
  "tokenizer": "standard",
  "text": "Elasticsearch, is an Awesome Search Engine!"
}
```
```
[Elasticsearch, is, an, awesome, search, engine]
```

在上面的token中，我们可以看到所有的停止词，并且 token 没有转换为小写。我们可以配置 `max_token_length` 来设置每个token的最大大小。默认情况下，`max_token_length`的值为255。如果我们想将`max_token_length`配置为6个字符，我们可以通过以下方式配置：
```http
PUT my_index
{
  "settings": {
    "analysis": {
      "analyzer": {
        "my_analyzer": {
          "tokenizer": "my_tokenizer"
        }
      },
      "tokenizer": {
        "my_tokenizer": {
          "type": "standard",
          "max_token_length": 6
        }
      }
    }
  }
}
```

我们可以使用前面的代码创建自定义 `my_analyzer` 分析器。现在，让我们使用这个分析器来分析文本。请参考以下代码片段：
```http
POST my_index/_analyze
{
  "analyzer": "my_analyzer",
  "text": "Elasticsearch, is an Awesome Search Engine!"
}
```
```
[Elasti, csearcharc, h, is, an awesom, e, search, engine]
```

### Letter tokenizer

当遇到非字母字符时，字母标记生成器会将文本转换为标记。以下代码片段显示了字母分词器：
```http
POST _analyze
{
  "tokenizer": "letter",
  "text": "Elasticsearch, is an awesome search-engine!"
}
```
```
[Elasticsearch, is, an, awesome, search, engine]
```

我们可以使用字母分词器获取上述token。它是不可配置的。

#### Lowercase tokenizer

小写分词器与字母分词器非常相似，因为只要遇到任何非字母字符，它就会将文本转换为token。唯一的区别是小写分词器也将token转换为小写。让我们举同样的例子，这次尝试应用小写分词器：
```http
POST _analyze
{
  "tokenizer": "lowercase",
  "text": "Elasticsearch, is an awesome search-engine!"
}
```
```
[elasticsearch, is, an, awesome, search, engine]
```

#### Whitespace tokenizer

空白分词器使用空白字符将文本转换为术语。因此，只要存在空格字符，文本就会被分解为一个术语。看下面的代码片段，我们在其中使用空格标记器分析测试：
```http
POST _analyze
{
  "tokenizer": "whitespace",
  "text": "Elasticsearch, is an awesome search-engine!"
}
```
```
[Elasticsearch, is, an, awesome, search-engine!]
```

在这里，我们可以看到术语被空格字符破坏，因此所有其他字符仍然存在于这些术语中。我们可以通过配置 `max_token_length` 参数来自定义空白标记生成器。

#### UAX URL email tokenizer

`uax_url_email` 标记生成器与标准标记生成器类似，但具有一项附加功能，即它可以识别 URL 和电子邮件地址并将它们作为单个标记。看一下下面的代码片段，我们将在给定的文本上应用 `uax_url_email` 标记生成器：
```http
POST _analyze
{
  "tokenizer": "uax_url_email",
  "text": "Email me at anurag.srivastava@yopmail.com"
}
```
```
[Email, me, at, anurag.srivastava@yopmail.com]
```

在前面的结果中，我们可以看到电子邮件地址已与其他单词一起转换为术语。我们可以通过配置 `max_token_length` 参数来自定义 `uax_url_email` tokenizer。

### Classic tokenizer

我们可以对英语使用经典分词器，因为它是基于语法的分词器。它理解电子邮件地址、互联网主机名等，并将它们存储为单个token。它通过删除标点符号来使用标点符号拆分单词。以下代码片段说明了经典分词器的示例：
```http
POST _analyze
{
  "tokenizer": "classic",
  "text": "Elasticsearch, is an awesome search-engine!"
}
```
```
[Elasticsearch, is, an, Awesome, search, engine]
```

在前面的结果中，我们可以看到连字符也用于创建术语。我们可以通过配置 `max_token_length` 参数来定制经典分词器。

### Partial word tokenizer

对于想要进行部分单词匹配的用例，我们可以使用部分单词标记器，并且为此将单词分解为小片段。

#### N-gram tokenizer

#### Edge n-gram tokenizer

### Structure text tokenizer

当我们想要处理电子邮件地址、邮政编码、标识符、路径等结构化文本时，我们可以使用结构化文本分词器，而不是全文分词器。

#### Keyword tokenizer

关键字分词器接受文本并将相同的文本作为单个术语输出。以下代码片段显示了关键字分词器示例：

```http
POST _analyze
{
  "tokenizer": "keyword",
  "text": "Elasticsearch, is an awesome search-engine!"
}
```
```
["Elasticsearch, is an awesome search-engine!"]
```

#### Pattern tokenizer

模式分词器使用正则表达式将文本拆分为术语。它的工作方式与我们解释模式分析器的方式相同。默认模式是 `\W+`，只要遇到非单词字符就会分割文本。

## Token filters

token过滤器从token生成器接收token流并可以修改token。这些修改可以是将文本转换为小写、删除标记、添加标记等。我们可以使用许多内置的token过滤器来构建自定义分析器。token过滤器包括以下功能：

- 小写token过滤器将接收到的token生成器文本转换为小写token。
- 大写token过滤器将接收到的token生成器文本转换为大写标记。
- 停止token过滤器从token流中删除停止词。
- 我们可以使用反向token过滤器反转token。
- 我们可以使用省略token过滤器删除省略。
- 我们可以使用截断token过滤器将标记切割成特定长度。默认情况下，长度设置为 10。
- 我们可以使用唯一token过滤器对唯一token进行索引。
- 我们可以使用重复token过滤器删除同一位置中相同的重复token。

## Character filters

字符过滤器在字符流传递到分词器之前起作用。它们通过在将字符传递给分词器之前删除、添加或修改字符来处理字符流。 Elasticsearch 中有许多内置的字符过滤器，我们可以使用它们构建自定义分析器。

### HTML strip character filter

使用 `html_strip` 字符过滤器，我们可以从文本中删除 HTML 元素，并使用其解码值替换 HTML 实体。以下代码片段说明了 `html_strip` 字符过滤器：
```http
POST _analyze
{
  "tokenizer": "keyword",
  "char_filter": [
    "html_strip"
  ],
  "text": "<p>I&apos;m so <b>happy</b>!</p>"
}
```
```json
{
  "tokens": [
    {
      "token": """
I'm so happy!
""",
      "start_offset": 0,
      "end_offset": 32,
      "type": "word",
      "position": 0
    }
  ]
}
```

`html_strip` 字符过滤器支持以下参数：
- `escaped_tags`：在这里，我们可以提供不想从原始文本中删除的 HTML 标签数组。

使用前面的参数，我们可以添加一些我们不想修改的 HTML 标签。

### Mapping the char filter

映射字符过滤器使用带有键及其值的关联数组。如果文本与键匹配，过滤器会用其值替换该键。使用这个字符过滤器，我们可以将一种语言转换为任何其他语言。例如，我们可以使用映射字符过滤器轻松地将印度-阿拉伯数字转换为阿拉伯-拉丁数字。

### Pattern replace character filter

使用`pattern_replace`字符过滤器，我们可以通过应用正则表达式来替换字符。我们可以根据正则表达式指定替换字符串。 `pattern_replace`字符过滤器支持以下参数：
- pattern：Java 中的正则表达式。
- replacement：替换字符串，可用于在匹配正则表达式时替换现有字符串。
- flags：Java 正则表达式的管道分隔标志。

例如`CASE_INSESSITIVE|COMMENTS`。我们可以使用前面的参数来调整字符过滤器的行为。

## Normalizer

规范化器与分析器非常相似，但规范化器不生成多个标记，而是仅生成一个标记。规范化器不包含分词器，只接受一些字符过滤器和标记过滤器。我们可以使用的过滤器有 `asciifolding`、`cjk_width`、`decimal_digit`、`elision`、`lowercase` 和 `uppercase`。除了这些过滤器之外，它还使用一些语言过滤器。我们可以通过提供字符过滤器和token过滤器来创建自定义规范化器。看一下下面的代码片段：

```http
PUT index
{
  "settings": {
    "analysis": {
      "char_filter": {
        "quote": {
          "type": "mapping",
          "mappings": [
            "« => \"",
            "» => \""
          ]
        }
      },
      "normalizer": {
        "my_normalizer": {
          "type": "custom",
          "char_filter": [
            "quote"
          ],
          "filter": [
            "lowercase",
            "asciifolding"
          ]
        }
      }
    }
  },
  "mappings": {
    "properties": {
      "foo": {
        "type": "keyword",
        "normalizer": "my_normalizer"
      }
    }
  }
}
```

在前面的示例中，我们使用`quote`、`lowercase`和`asciifolding`过滤器组成规范化器。这样，我们就可以创建自定义规范化器。


