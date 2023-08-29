---
layout: default
title: Netty
parent: Lib
has_children: true
---

阅读此文章前请先了解`java nio`以及`netty`的基本使用。可以阅读`《Java NIO》`以及`《Netty实战》`这两本书以获取基础知识。

本文共分为四节：

- buffer. 介绍Netty针对jdk ByteBuffer进行的改进
- concurrency. 介绍Netty的线程模型
- bootstrap. 介绍Netty如何启动
- read/write. 介绍Netty如何处理NIO四种事件

如果你没有`java nio`以及`netty`基础，你仍然可以阅读前两节，此两节不涉及到Netty的核心代码，只针对其底层组件进行分析。
