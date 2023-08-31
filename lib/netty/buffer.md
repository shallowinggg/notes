---
layout: default
title: Buffer
parent: Netty
nav_order: 1
grand_parent: Lib
---

<details open markdown="block">
  <summary>
    Table of contents
  </summary>
  {: .text-delta }
- TOC
{:toc}
</details>

# AbstractReferenceCountedByteBuf

几乎所有常用的缓冲区都继承`AbstractReferenceCountedByteBuf`类，这个类提供了引用计数功能，使用乐观锁修改状态。

```java
private static final long REFCNT_FIELD_OFFSET = ReferenceCountUpdater.getUnsafeOffset(AbstractReferenceCountedByteBuf.class, "refCnt");

private static final AtomicIntegerFieldUpdater<AbstractReferenceCountedByteBuf> AIF_UPDATER = AtomicIntegerFieldUpdater.newUpdater(AbstractReferenceCountedByteBuf.class, "refCnt");

private static final ReferenceCountUpdater<AbstractReferenceCountedByteBuf> updater =
    new ReferenceCountUpdater<AbstractReferenceCountedByteBuf>() {
        @Override
        protected AtomicIntegerFieldUpdater<AbstractReferenceCountedByteBuf> updater() {
            return AIF_UPDATER;
        }
        @Override
        protected long unsafeOffset() {
            return REFCNT_FIELD_OFFSET;
        }
    };

private volatile int refCnt = updater.initialValue();

```

`refCount`作为保存引用计数的字段，并不对它直接进行操作，而是获取它在内存中地址偏移量，直接对其进行修改。

```java
# ReferenceCountUpdater.java

    public final int initialValue() {
        return 2;
    }

    // 获取真实的引用计数值
    // 在这个类的实现中，引用计数值为真实值的2倍，而缓冲区被释放后引用计数值
    // 被设置为奇数
    private static int realRefCnt(int rawCnt) {
        return rawCnt != 2 && rawCnt != 4 && (rawCnt & 1) != 0 ? 0 : rawCnt >>> 1;
    }
```

引用计数的值在正常使用下永远都是偶数，这是一个会让人迷惑的地方。让我们先看一下增加引用计数`retain(..)`与减少引用计数`release(..)`方法的实现，再来解释这个问题。

```java
// 最开始的代码片段中描述了ReferenceCountUpdater的匿名构造方法，
// 其中updater()方法是用AtomicIntegerFieldUpdater来实现的
protected abstract AtomicIntegerFieldUpdater<T> updater();

public final T retain(T instance) {
    return retain0(instance, 1, 2);
}

public final T retain(T instance, int increment) {
    // all changes to the raw count are 2x the "real" change - overflow is OK
    int rawIncrement = checkPositive(increment, "increment") << 1;
    return retain0(instance, increment, rawIncrement);
}

// rawIncrement == increment << 1
private T retain0(T instance, final int increment, final int rawIncrement) {
    // 乐观锁，先获取原值，再增加
    int oldRef = updater().getAndAdd(instance, rawIncrement);
    // 如果原值不为偶数，那么代表缓冲区已经被释放
    if (oldRef != 2 && oldRef != 4 && (oldRef & 1) != 0) {
        throw new IllegalReferenceCountException(0, increment);
    }
    // don't pass 0!
    // 如果增加后发生了溢出，回滚并抛出异常
    if ((oldRef <= 0 && oldRef + rawIncrement >= 0)
            || (oldRef >= 0 && oldRef + rawIncrement < oldRef)) {
        // overflow case
        updater().getAndAdd(instance, -rawIncrement);
        throw new IllegalReferenceCountException(realRefCnt(oldRef), increment);
    }
    return instance;
}

---------------------------------------------------------------------------------

public final boolean release(T instance) {
    // 通过内存偏移量获取值
    int rawCnt = nonVolatileRawCnt(instance);
    // 如果真实计数值为1，那么释放缓冲区；否则减2
    return rawCnt == 2 ? tryFinalRelease0(instance, 2) || retryRelease0(instance, 1)
            : nonFinalRelease0(instance, 1, rawCnt, toLiveRealRefCnt(rawCnt, 1));
}

private int nonVolatileRawCnt(T instance) {
    // TODO: Once we compile against later versions of Java we can replace the Unsafe usage here by varhandles.
    final long offset = unsafeOffset();
    return offset != -1 ? PlatformDependent.getInt(instance, offset) : updater().get(instance);
}

public final boolean release(T instance, int decrement) {
    int rawCnt = nonVolatileRawCnt(instance);
    int realCnt = toLiveRealRefCnt(rawCnt, checkPositive(decrement, "decrement"));
    return decrement == realCnt ? tryFinalRelease0(instance, rawCnt) || retryRelease0(instance, decrement)
            : nonFinalRelease0(instance, decrement, rawCnt, realCnt);
}

private boolean tryFinalRelease0(T instance, int expectRawCnt) {
    // 将2 CAS设置为1，设为奇数表示缓存区被释放
    return updater().compareAndSet(instance, expectRawCnt, 1); // any odd number will work
}

private boolean nonFinalRelease0(T instance, int decrement, int rawCnt, int realCnt) {
    if (decrement < realCnt
            // all changes to the raw count are 2x the "real" change - overflow is OK
            && updater().compareAndSet(instance, rawCnt, rawCnt - (decrement << 1))) {
        return false;
    }
    return retryRelease0(instance, decrement);
}

private boolean retryRelease0(T instance, int decrement) {
    // CAS死循环修改
    for (;;) {
        // 获取原始值以及真实值
        int rawCnt = updater().get(instance), realCnt = toLiveRealRefCnt(rawCnt, decrement);
        // 释放缓冲区
        if (decrement == realCnt) {
            if (tryFinalRelease0(instance, rawCnt)) {
                return true;
            }
        } else if (decrement < realCnt) {
            // 只进行-1
            // all changes to the raw count are 2x the "real" change
            if (updater().compareAndSet(instance, rawCnt, rawCnt - (decrement << 1))) {
                return false;
            }
        } else {
            throw new IllegalReferenceCountException(realCnt, -decrement);
        }
        Thread.yield(); // this benefits throughput under high contention
    }
}

private static int toLiveRealRefCnt(int rawCnt, int decrement) {
    if (rawCnt == 2 || rawCnt == 4 || (rawCnt & 1) == 0) {
        return rawCnt >>> 1;
    }
    // odd rawCnt => already deallocated
    throw new IllegalReferenceCountException(0, -decrement);
}

```

注意，`release()`方法返回false并不代表操作失败，而是缓冲区还没有被释放，即只有真实引用计数为1时，释放后才会返回true。

从上面的`retain()`以及`release()`操作中可以看出，在进行引用计数的修改时，并不会先行判断是否会发生溢出，而是先执行，执行完之后再进行判断，如果溢出则进行回滚，这样可以在高竞争的环境下提供吞吐量。但是在之前的版本中，是先判断再修改的，如下所示：

```java
    private ByteBuf retain0(int increment) {
        for (;;) {
            int refCnt = this.refCnt;
            final int nextCnt = refCnt + increment;

            // Ensure we not resurrect (which means the refCnt was 0) and also that we encountered an overflow.
            if (nextCnt <= increment) {
                throw new IllegalReferenceCountException(refCnt, increment);
            }
            if (refCntUpdater.compareAndSet(this, refCnt, nextCnt)) {
                break;
            }
        }
        return this;
    }

    private boolean release0(int decrement) {
        for (;;) {
            int refCnt = this.refCnt;
            if (refCnt < decrement) {
                throw new IllegalReferenceCountException(refCnt, -decrement);
            }

            if (refCntUpdater.compareAndSet(this, refCnt, refCnt - decrement)) {
                if (refCnt == decrement) {
                    deallocate();
                    return true;
                }
                return false;
            }
        }
    }
```

之后进行了修改，变为：

```java
private ReferenceCounted retain0(int increment) {
    int oldRef = refCntUpdater.getAndAdd(this, increment);
    if (oldRef <= 0 || oldRef + increment < oldRef) {
        // Ensure we don't resurrect (which means the refCnt was 0) and also that we encountered an overflow.
        refCntUpdater.getAndAdd(this, -increment);
        throw new IllegalReferenceCountException(oldRef, increment);
    }
    return this;
}

private boolean release0(int decrement) {
    int oldRef = refCntUpdater.getAndAdd(this, -decrement);
    if (oldRef == decrement) {
        deallocate();
        return true;
    } else if (oldRef < decrement || oldRef - decrement > oldRef) {
        // Ensure we don't over-release, and avoid underflow.
        refCntUpdater.getAndAdd(this, decrement);
        throw new IllegalReferenceCountException(oldRef, -decrement);
    }
     return false;
}
```

可以看出，这和我们的惯性思维完全一致，引用计数值每次加一减一，但是这也引发一个并发问题，考虑下面的场景：

```
1. Object has refCnt==1
2. We have 3 threads playing with this object
3. Thread-1 calls obj.release()
4. Thread-2 calls obj.retain() and sees the oldRef==0 then rolls back the increment (but the rollback is not atomic)
5. Thread-3 calls obj.retain() and sees oldRef==1 (from T-2 increment) therefore thinks the object is not dead
6. Thread-1 will call obj.deallocate()
```

此时Thread-3将使用一个已经销毁的缓冲区，如果Thread-3调用obj.release()，那么就会出现两次销毁的情况。为了解决这个问题，Netty的开发者使用偶数记录引用计数值，奇数作为已销毁的状态，这样可以保留一定的性能提升，同时解决这个bug。

关于性能方面的测试，查看：https://github.com/netty/netty/commit/83a19d565064ee36998eb94f946e5a4264001065

关于bug问题的讨论，查看：https://github.com/netty/netty/issues/8563


# UnpooledByteBufAllocator

缓冲区分为池化与非池化两种，其中每种还分为堆缓冲区，直接缓冲区，组合缓冲区，每个缓冲区在构造的时候都需要一个分配器，下面先介绍非池化的分配器。

```java
public final class UnpooledByteBufAllocator extends AbstractByteBufAllocator implements ByteBufAllocatorMetricProvider
```

`UnpooledByteBufAllocator`的声明如上所示，继承自一个骨架类，并且实现了`ByteBufAllocatorMetricProvider`接口，用以跟踪使用此分配器的缓冲区的容量变化。除此以外，这个类还提供了一个默认实现，通过平台本身判定是否优先采用直接缓冲区，并且启用内存泄露跟踪。

```java
public static final UnpooledByteBufAllocator DEFAULT =
            new UnpooledByteBufAllocator(PlatformDependent.directBufferPreferred());

/**
 * Returns {@code true} if the platform has reliable low-level direct buffer access API and a user has not specified
 * {@code -Dio.netty.noPreferDirect} option.
 */
public static boolean directBufferPreferred() {
    return DIRECT_BUFFER_PREFERRED;
}

// We should always prefer direct buffers by default if we can use a Cleaner to release direct buffers.
DIRECT_BUFFER_PREFERRED = CLEANER != NOOP
            && !SystemPropertyUtil.getBoolean("io.netty.noPreferDirect", false);
```

关于Netty中直接缓冲区，其实是使用`java.nio.ByteBuffer`来实现的。所以对应的内存清除器，也是`java.nio.ByteBuffer`提供的，如果能够通过反射获取到此清除器，并且`io.netty.noPreferDirect`选项没有被设置成false，那么在分配某些缓冲区（比如ioBuffer）时会优先采用直接缓冲区，而非堆缓冲区。

分配器的核心API如下：

```java
@Override
protected ByteBuf newHeapBuffer(int initialCapacity, int maxCapacity) {
    return PlatformDependent.hasUnsafe() ?
            new InstrumentedUnpooledUnsafeHeapByteBuf(this, initialCapacity, maxCapacity) :
            new InstrumentedUnpooledHeapByteBuf(this, initialCapacity, maxCapacity);
}

@Override
protected ByteBuf newDirectBuffer(int initialCapacity, int maxCapacity) {
    final ByteBuf buf;
    if (PlatformDependent.hasUnsafe()) {
        buf = noCleaner ? new InstrumentedUnpooledUnsafeNoCleanerDirectByteBuf(this, initialCapacity, maxCapacity) :
                new InstrumentedUnpooledUnsafeDirectByteBuf(this, initialCapacity, maxCapacity);
    } else {
        buf = new InstrumentedUnpooledDirectByteBuf(this, initialCapacity, maxCapacity);
    }
    return disableLeakDetector ? buf : toLeakAwareBuffer(buf);
}

@Override
public CompositeByteBuf compositeHeapBuffer(int maxNumComponents) {
    CompositeByteBuf buf = new CompositeByteBuf(this, false, maxNumComponents);
    return disableLeakDetector ? buf : toLeakAwareBuffer(buf);
}

@Override
public CompositeByteBuf compositeDirectBuffer(int maxNumComponents) {
    CompositeByteBuf buf = new CompositeByteBuf(this, true, maxNumComponents);
    return disableLeakDetector ? buf : toLeakAwareBuffer(buf);
}

```

其中`Instrumented`开头的缓冲区，实际上是继承自`Instrumented`后面的缓冲区类，只是在原来的基础上对缓冲区的容量进行了跟踪。

# UnpooledHeapByteBuf

非池化堆缓冲区类的定义如下：

```java
public class UnpooledHeapByteBuf extends AbstractReferenceCountedByteBuf {

    private final ByteBufAllocator alloc;
    byte[] array;
    private ByteBuffer tmpNioBuf;
```

可以发现堆缓冲区内部是使用`byte[]`来实现的，在JVM堆中分配内存，与它的名字一样，关于它的内存释放完全依赖于JVM的垃圾回收机制。

# UnpooledDirectByteBuf

非池化直接缓冲区类的定义如下：

```java
public class UnpooledDirectByteBuf extends AbstractReferenceCountedByteBuf {

    private final ByteBufAllocator alloc;

    ByteBuffer buffer; // accessed by UnpooledUnsafeNoCleanerDirectByteBuf.reallocateDirect()
    private ByteBuffer tmpNioBuf;
    private int capacity;
    private boolean doNotFree;
```

与堆缓冲区不同，直接缓冲区依赖`java.nio.ByteBuffer`，在堆外进行缓冲区的分配。

```java
protected ByteBuffer allocateDirect(int initialCapacity) {
    return ByteBuffer.allocateDirect(initialCapacity);
}

protected void freeDirect(ByteBuffer buffer) {
    PlatformDependent.freeDirectBuffer(buffer);
}

public static void freeDirectBuffer(ByteBuffer buffer) {
    CLEANER.freeDirectBuffer(buffer);
}

# Java6Cleaner ----------------------------------------

@Override
public void freeDirectBuffer(ByteBuffer buffer) {
    if (!buffer.isDirect()) {
        return;
    }
    if (System.getSecurityManager() == null) {
        try {
            freeDirectBuffer0(buffer);
        } catch (Throwable cause) {
            PlatformDependent0.throwException(cause);
        }
    } else {
        freeDirectBufferPrivileged(buffer);
    }
}

private static void freeDirectBuffer0(ByteBuffer buffer) throws Exception {
    final Object cleaner;
    // If CLEANER_FIELD_OFFSET == -1 we need to use reflection to access the cleaner, otherwise we can use
    // sun.misc.Unsafe.
    if (CLEANER_FIELD_OFFSET == -1) {
        cleaner = CLEANER_FIELD.get(buffer);
    } else {
        cleaner = PlatformDependent0.getObject(buffer, CLEANER_FIELD_OFFSET);
    }
    if (cleaner != null) {
        CLEAN_METHOD.invoke(cleaner);
    }
}

# Java9Cleaner ----------------------------------------

@Override
public void freeDirectBuffer(ByteBuffer buffer) {
    // Try to minimize overhead when there is no SecurityManager present.
    // See https://bugs.openjdk.java.net/browse/JDK-8191053.
    if (System.getSecurityManager() == null) {
        try {
            INVOKE_CLEANER.invoke(PlatformDependent0.UNSAFE, buffer);
        } catch (Throwable cause) {
            PlatformDependent0.throwException(cause);
        }
    } else {
        freeDirectBufferPrivileged(buffer);
    }
}
```

关于直接缓冲区的释放，分为Java6之后以及Java9之后两个版本，原因在于Java9在`Unsafe`类中直接提供了一个释放`java.nio.ByteBuffer`缓冲区的方法，无需通过反射从`java.nio.ByteBuffer`中获取相应的清除方法，相比之下性能提高了许多。

# jemalloc

https://people.freebsd.org/~jasone/jemalloc/bsdcan2006/jemalloc.pdf

进入多线程时代后，原先的phkmalloc虽然在单线程环境下表现优秀，但在多线程环境下的性能已经不尽人意。一个显著的例子就是缓存行争用，当多个线程在同一缓存行分配变量时，它们必须轮流访问缓存行以避免不安全的线程操作。一种解决方案是填充缓冲行，在每个类中追加额外无用的字段，以使得这个类的大小可以占用整个缓存行，这可以大幅提高性能，但是也在很大程度上造成了缓冲行的浪费。因此为了在这两者之间取得平衡，jemalloc使用了一个别出心裁的设计：arena。在进行内存分配的时候根据CPU核心数创建一定的arena区，在jemalloc为数量为 4 * cores，每个线程采用轮询的方式占用一个arena区，分配内存时在自己所述的arena中进行分配，这可以在很大程度上减少内存争用。比如一个拥有4个核心的CPU，我们将分配16个arena区，当只有16个线程的时候，它们之间将没有任何竞争。

除此之外，我们都知道现代操作系统使用分页管理内存，一般情况每页的大小为4KB，在此之上jemalloc维护了一个区域叫做chunk(块)，每一块的大小默认为2MB，一个arena管理多个chunk。

现在我们将分配空间按大小进行分为三个主要的类别：small，large，huge。
- small的范围为2B ~  2KB
- large的范围为4KB ~ 1MB
- huge的范围为 2MB ~

对于small类别，进行再一步的细分：
- tiny         2B - 8B
- quantum      16B - 512B
- sub-page     1KB - 4KB

至此，针对不同的需求，将分配不同的内存块。在arena中，以chunk为单位进行管理，对每个chunk的
使用了进行跟踪，分为QINIT, Q0, Q25, Q50, Q75, Q100
- QINIT使用量为 [0 , 25%)
- Q0使用量为 (0, 50%)
- Q25使用量为 [25%, 50%)
- Q50使用量为 [50%, 100%)
- Q75使用量为 [75%, 100%)
- Q100使用量为 [100%, )

当进行分配时，查找顺序为Q50, Q25, Q0, Q75。Q50是一个较为折中的选择，从此处开始查找，可以
让每个chunk的使用量尽可能的高，而不从Q75开始的原因是有一定的可能容量不够导致分配失败，增加了
切换到另一个有更多可用容量的chunk的开销。

为了能够更快的在chunk中定位到可分配的内存区域，在chunk中维护一个二叉平衡树，以页为基本单位
构造，结构为：

层数 大小<br/>
1 2MB<br/>
2 1MB 1MB<br/>
3 512K 512K 512K 512K<br/>
...<br/>
10 4K 4K 4K ...<br/>

当给定一个请求分配的大小时，从树顶部开始遍历即可。

<br/>
Netty的池化缓冲区就是根据jemalloc来实现的，并且进行了一些微妙的修改：

- 页大小：8K
- 块大小：16M
- arena数量：2 * cores
- 最小分配大小：16B
- 使用ThreadLocalCache，为每个线程维护一块自己的缓冲区


# PooledByteBufAllocator

池化分配器的定义如下所示，其中定义了许多常量，与之前提到的各种概念相对应：

```java
public class PooledByteBufAllocator extends AbstractByteBufAllocator implements ByteBufAllocatorMetricProvider {

    private static final int DEFAULT_NUM_HEAP_ARENA;
    private static final int DEFAULT_NUM_DIRECT_ARENA;

    private static final int DEFAULT_PAGE_SIZE; // 8192
    private static final int DEFAULT_MAX_ORDER; // 8192 << 11 = 16 MiB per chunk
    private static final int DEFAULT_TINY_CACHE_SIZE; // 512
    private static final int DEFAULT_SMALL_CACHE_SIZE; // 256
    private static final int DEFAULT_NORMAL_CACHE_SIZE; // 64
    private static final int DEFAULT_MAX_CACHED_BUFFER_CAPACITY; // 32K
    private static final int DEFAULT_CACHE_TRIM_INTERVAL; // 8192
    private static final long DEFAULT_CACHE_TRIM_INTERVAL_MILLIS; // 0
    private static final boolean DEFAULT_USE_CACHE_FOR_ALL_THREADS; // true
    private static final int DEFAULT_DIRECT_MEMORY_CACHE_ALIGNMENT; // 0
    static final int DEFAULT_MAX_CACHED_BYTEBUFFERS_PER_CHUNK; // 1023

    private static final int MIN_PAGE_SIZE = 4096;
    private static final int MAX_CHUNK_SIZE = (int) (((long) Integer.MAX_VALUE + 1) / 2);
```

关于DEFAULT_MAX_CACHED_BYTEBUFFERS_PER_CHUNK = 1023：<br/>
使用`ArrayDeque`时的大小初始化并不只是简单的变为pow2

```java
initialCapacity = numElements;
initialCapacity |= (initialCapacity >>>  1);
initialCapacity |= (initialCapacity >>>  2);
initialCapacity |= (initialCapacity >>>  4);
initialCapacity |= (initialCapacity >>>  8);
initialCapacity |= (initialCapacity >>> 16);
initialCapacity++;
```

如果传入1024，那么最终得到的结果将会是2048，无疑会浪费很多空间。

下面是`PooledByteBufAllocator`的构造方法：

```java
public PooledByteBufAllocator(boolean preferDirect, int nHeapArena, int nDirectArena, int pageSize, int maxOrder,
                              int tinyCacheSize, int smallCacheSize, int normalCacheSize,
                              boolean useCacheForAllThreads, int directMemoryCacheAlignment) {
    super(preferDirect);
    // true
    threadCache = new PoolThreadLocalCache(useCacheForAllThreads);
    // 512
    this.tinyCacheSize = tinyCacheSize;
    // 256
    this.smallCacheSize = smallCacheSize;
    // 64
    this.normalCacheSize = normalCacheSize;
    // 16MiB
    chunkSize = validateAndCalculateChunkSize(pageSize, maxOrder);

    checkPositiveOrZero(nHeapArena, "nHeapArena");
    checkPositiveOrZero(nDirectArena, "nDirectArena");

    checkPositiveOrZero(directMemoryCacheAlignment, "directMemoryCacheAlignment");
    if (directMemoryCacheAlignment > 0 && !isDirectMemoryCacheAlignmentSupported()) {
        throw new IllegalArgumentException("directMemoryCacheAlignment is not supported");
    }

    if ((directMemoryCacheAlignment & -directMemoryCacheAlignment) != directMemoryCacheAlignment) {
        throw new IllegalArgumentException("directMemoryCacheAlignment: "
                + directMemoryCacheAlignment + " (expected: power of two)");
    }

    // 13
    int pageShifts = validateAndCalculatePageShifts(pageSize);

    if (nHeapArena > 0) {
        heapArenas = newArenaArray(nHeapArena);
        List<PoolArenaMetric> metrics = new ArrayList<PoolArenaMetric>(heapArenas.length);
        for (int i = 0; i < heapArenas.length; i ++) {
            // 8K, 11, 13, 16MiB, 0
            PoolArena.HeapArena arena = new PoolArena.HeapArena(this,
                    pageSize, maxOrder, pageShifts, chunkSize,
                    directMemoryCacheAlignment);
            heapArenas[i] = arena;
            metrics.add(arena);
        }
        heapArenaMetrics = Collections.unmodifiableList(metrics);
    } else {
        heapArenas = null;
        heapArenaMetrics = Collections.emptyList();
    }

    if (nDirectArena > 0) {
        directArenas = newArenaArray(nDirectArena);
        List<PoolArenaMetric> metrics = new ArrayList<PoolArenaMetric>(directArenas.length);
        for (int i = 0; i < directArenas.length; i ++) {
            PoolArena.DirectArena arena = new PoolArena.DirectArena(
                    this, pageSize, maxOrder, pageShifts, chunkSize, directMemoryCacheAlignment);
            directArenas[i] = arena;
            metrics.add(arena);
        }
        directArenaMetrics = Collections.unmodifiableList(metrics);
    } else {
        directArenas = null;
        directArenaMetrics = Collections.emptyList();
    }
    metric = new PooledByteBufAllocatorMetric(this);
}
```

构造方法经历了下面几步：

1. 构造线程缓存
2. 构造堆arena
3. 构造直接arena
4. 构造metric跟踪器

## 构造线程缓存

`PoolThreadLocalCache`是一个`ThreadLocal`，netty中实现了一个变种形式`FastThreadLocal`，使用数组代替原来的Map实现。

```java
final class PoolThreadLocalCache extends FastThreadLocal<PoolThreadCache> {
    private final boolean useCacheForAllThreads;

    PoolThreadLocalCache(boolean useCacheForAllThreads) {
        this.useCacheForAllThreads = useCacheForAllThreads;
    }
```

我们先看一下Netty实现的变种ThreadLocal。

```java
public class FastThreadLocal<V> {

    private static final int variablesToRemoveIndex = InternalThreadLocalMap.nextVariableIndex();

    private final int index;

    public FastThreadLocal() {
        index = InternalThreadLocalMap.nextVariableIndex();
    }

## InternalThreadLocalMap.java ----------------------------------------------

    public static int nextVariableIndex() {
        int index = nextIndex.getAndIncrement();
        if (index < 0) {
            nextIndex.decrementAndGet();
            throw new IllegalStateException("too many thread-local indexed variables");
        }
        return index;
    }

## UnpaddedInternalThreadLocalMap.java ---------------------------------------

class UnpaddedInternalThreadLocalMap {

    static final ThreadLocal<InternalThreadLocalMap> slowThreadLocalMap = new ThreadLocal<InternalThreadLocalMap>();
    static final AtomicInteger nextIndex = new AtomicInteger();

    /** Used by {@link FastThreadLocal} */
    Object[] indexedVariables;
```

每一个`FastThreadLocal`内部维护了一个属于自己的`index`，它代表储存所有`FastThreadLocal`值的数组的下标，这个`index`是通过原子变量实现的，所有不会发生重复，每一个线程独有。

```java
public final class InternalThreadLocalMap extends UnpaddedInternalThreadLocalMap {
    private InternalThreadLocalMap() {
        super(newIndexedVariableTable());
    }

    private static Object[] newIndexedVariableTable() {
        Object[] array = new Object[32];
        Arrays.fill(array, UNSET);
        return array;
    }

    // other
}

class UnpaddedInternalThreadLocalMap {
    UnpaddedInternalThreadLocalMap(Object[] indexedVariables) {
        this.indexedVariables = indexedVariables;
    }

    // other
}
```

在初始构造过程中，创建一个大小为32的数组，可以储存31个`FastThreadLocal`，注意`FastThreadLocal`有一个static变量`variablesToRemoveIndex`，它占用了第一个元素。接下来让我们看一下最关心的`get()`方法，以此来观察`FastThreadLocal`的全貌：

```java
    /**
     * Returns the current value for the current thread
     */
    @SuppressWarnings("unchecked")
    public final V get() {
        InternalThreadLocalMap threadLocalMap = InternalThreadLocalMap.get();
        Object v = threadLocalMap.indexedVariable(index);
        if (v != InternalThreadLocalMap.UNSET) {
            return (V) v;
        }

        return initialize(threadLocalMap);
    }

    private V initialize(InternalThreadLocalMap threadLocalMap) {
        V v = null;
        try {
            v = initialValue();
        } catch (Exception e) {
            PlatformDependent.throwException(e);
        }

        threadLocalMap.setIndexedVariable(index, v);
        addToVariablesToRemove(threadLocalMap, this);
        return v;
    }


    public static InternalThreadLocalMap get() {
        Thread thread = Thread.currentThread();
        if (thread instanceof FastThreadLocalThread) {
            return fastGet((FastThreadLocalThread) thread);
        } else {
            return slowGet();
        }
    }

    private static InternalThreadLocalMap fastGet(FastThreadLocalThread thread) {
        InternalThreadLocalMap threadLocalMap = thread.threadLocalMap();
        if (threadLocalMap == null) {
            thread.setThreadLocalMap(threadLocalMap = new InternalThreadLocalMap());
        }
        return threadLocalMap;
    }

```

在`get()`方法的调用过程中，出现了一个线程类`FastThreadLocalThread`。熟悉`ThreadLocal`的话就会知道`Thread`类的内部有一个字段是用来保存`ThreadLocalMap`的，与此类似，既然`FastThreadLocal`使用另一种储存形式，那么也需要一个字段用以保存，所以需要使用一个新的`FastThreadLocalThread`类新增这个字段。

在获取到`InternalThreadLocalMap`后，就可以通过`FastThreadLocal`自己的下标从中获取值，虽然`InternalThreadLocalMap`的名字仍然叫Map，但是它本质上是一个数组。

jdk库中的`ThreadLocal`是通过hash值计算自己在`ThreadLocalMap`中的位置，而`FastThreadLocal`通过数组以及下标去除这一步计算过程，在性能上有一些微小的提升。


## 构造堆arena

堆arena的构造过程如下：

```java
static final class HeapArena extends PoolArena<byte[]> {

    HeapArena(PooledByteBufAllocator parent, int pageSize, int maxOrder,
            int pageShifts, int chunkSize, int directMemoryCacheAlignment) {
        super(parent, pageSize, maxOrder, pageShifts, chunkSize,
                directMemoryCacheAlignment);
    }

    // other
}

protected PoolArena(PooledByteBufAllocator parent, int pageSize,
      int maxOrder, int pageShifts, int chunkSize, int cacheAlignment) {
    this.parent = parent;
    // 8K
    this.pageSize = pageSize;
    // 11
    this.maxOrder = maxOrder;
    // 13
    this.pageShifts = pageShifts;
    // 16M
    this.chunkSize = chunkSize;
    // 0
    directMemoryCacheAlignment = cacheAlignment;
    // -1
    directMemoryCacheAlignmentMask = cacheAlignment - 1;
    subpageOverflowMask = ~(pageSize - 1);
    // 32
    tinySubpagePools = newSubpagePoolArray(numTinySubpagePools);
    for (int i = 0; i < tinySubpagePools.length; i ++) {
        tinySubpagePools[i] = newSubpagePoolHead(pageSize);
    }

    // 4
    numSmallSubpagePools = pageShifts - 9;
    smallSubpagePools = newSubpagePoolArray(numSmallSubpagePools);
    for (int i = 0; i < smallSubpagePools.length; i ++) {
        smallSubpagePools[i] = newSubpagePoolHead(pageSize);
    }

    q100 = new PoolChunkList<T>(this, null, 100, Integer.MAX_VALUE, chunkSize);
    q075 = new PoolChunkList<T>(this, q100, 75, 100, chunkSize);
    q050 = new PoolChunkList<T>(this, q075, 50, 100, chunkSize);
    q025 = new PoolChunkList<T>(this, q050, 25, 75, chunkSize);
    q000 = new PoolChunkList<T>(this, q025, 1, 50, chunkSize);
    qInit = new PoolChunkList<T>(this, q000, Integer.MIN_VALUE, 25, chunkSize);

    q100.prevList(q075);
    q075.prevList(q050);
    q050.prevList(q025);
    q025.prevList(q000);
    q000.prevList(null);
    qInit.prevList(qInit);

    List<PoolChunkListMetric> metrics = new ArrayList<PoolChunkListMetric>(6);
    metrics.add(qInit);
    metrics.add(q000);
    metrics.add(q025);
    metrics.add(q050);
    metrics.add(q075);
    metrics.add(q100);
    chunkListMetrics = Collections.unmodifiableList(metrics);
}

private PoolSubpage<T> newSubpagePoolHead(int pageSize) {
    PoolSubpage<T> head = new PoolSubpage<T>(pageSize);
    head.prev = head;
    head.next = head;
    return head;
}
```

注意，其中构造了32个tinySubPage以及4个smallSubPage，用以储存小对象，它的`prev`以及`next`指针都市指向自己的，在之后分配对象的过程中就会知道为何要这么做。


`ChunkList`的结构如下：

```
----------    ----------    ----------    ----------    ----------    ----------
- QINIT  -    -   Q0   -    -   Q25  -    -  Q50   -    -  Q75   -    -  Q100  -
-  MIN   -    -   1    -    -   25   -    -  50    -    -  75    -    -  100   -
-  25    -    -   50   -    -   75   -    -  100   -    -  100   -    -  MAX   -
----------    ----------    ----------    ----------    ----------    ----------
```

当某个chunk被分配或回收后，如果不满足所在`ChunkList`的区间，那么需要将其前移或后移。

## 构造直接arena

与堆arena的构造过程相同，只不过一个是`HeapArena`，一个是`DirectArena`类，它们在分配与销毁对象上略有不同。


## 缓冲区分配

```java
@Override
protected ByteBuf newHeapBuffer(int initialCapacity, int maxCapacity) {
    // 获取线程缓存
    PoolThreadCache cache = threadCache.get();
    // 获取堆arena
    PoolArena<byte[]> heapArena = cache.heapArena;

    final ByteBuf buf;
    if (heapArena != null) {
        // 从堆arena中分配内存
        buf = heapArena.allocate(cache, initialCapacity, maxCapacity);
    } else {
        buf = PlatformDependent.hasUnsafe() ?
                new UnpooledUnsafeHeapByteBuf(this, initialCapacity, maxCapacity) :
                new UnpooledHeapByteBuf(this, initialCapacity, maxCapacity);
    }

    return toLeakAwareBuffer(buf);
}

```

前面已经提及`PoolThreadCache`，也了解了它的`get()`方法，但是并没有关注`initialValue()`方法，现在我们已经了解了arena的构造过程，所以让我们看一下它的`initialValue()`方法到底是如何实现的。

```java
@Override
protected synchronized PoolThreadCache initialValue() {
    final PoolArena<byte[]> heapArena = leastUsedArena(heapArenas);
    final PoolArena<ByteBuffer> directArena = leastUsedArena(directArenas);

    final Thread current = Thread.currentThread();
    if (useCacheForAllThreads || current instanceof FastThreadLocalThread) {
        // x, y, 512, 256, 64, 32K, 8192
        final PoolThreadCache cache = new PoolThreadCache(
                heapArena, directArena, tinyCacheSize, smallCacheSize, normalCacheSize,
                DEFAULT_MAX_CACHED_BUFFER_CAPACITY, DEFAULT_CACHE_TRIM_INTERVAL);

        // 如果指定了DEFAULT_CACHE_TRIM_INTERVAL_MILLIS，那么开启定时回收
        if (DEFAULT_CACHE_TRIM_INTERVAL_MILLIS > 0) {
            final EventExecutor executor = ThreadExecutorMap.currentExecutor();
            if (executor != null) {
                executor.scheduleAtFixedRate(trimTask, DEFAULT_CACHE_TRIM_INTERVAL_MILLIS,
                        DEFAULT_CACHE_TRIM_INTERVAL_MILLIS, TimeUnit.MILLISECONDS);
            }
        }
        return cache;
    }
    // No caching so just use 0 as sizes.
    return new PoolThreadCache(heapArena, directArena, 0, 0, 0, 0, 0);
}

private <T> PoolArena<T> leastUsedArena(PoolArena<T>[] arenas) {
    if (arenas == null || arenas.length == 0) {
        return null;
    }

    PoolArena<T> minArena = arenas[0];
    for (int i = 1; i < arenas.length; i++) {
        PoolArena<T> arena = arenas[i];
        if (arena.numThreadCaches.get() < minArena.numThreadCaches.get()) {
            minArena = arena;
        }
    }

    return minArena;
}



PoolThreadCache(PoolArena<byte[]> heapArena, PoolArena<ByteBuffer> directArena,
                int tinyCacheSize, int smallCacheSize, int normalCacheSize,
                int maxCachedBufferCapacity, int freeSweepAllocationThreshold) {
    // x, y, 512, 256, 64, 32K, 8192
    checkPositiveOrZero(maxCachedBufferCapacity, "maxCachedBufferCapacity");
    this.freeSweepAllocationThreshold = freeSweepAllocationThreshold;
    this.heapArena = heapArena;
    this.directArena = directArena;
    if (directArena != null) {
        // 512, 32
        tinySubPageDirectCaches = createSubPageCaches(
                tinyCacheSize, PoolArena.numTinySubpagePools, SizeClass.Tiny);
        // 256, 4
        smallSubPageDirectCaches = createSubPageCaches(
                smallCacheSize, directArena.numSmallSubpagePools, SizeClass.Small);

        // 13
        numShiftsNormalDirect = log2(directArena.pageSize);
        normalDirectCaches = createNormalCaches(
                normalCacheSize, maxCachedBufferCapacity, directArena);

        directArena.numThreadCaches.getAndIncrement();
    } else {
        // No directArea is configured so just null out all caches
        tinySubPageDirectCaches = null;
        smallSubPageDirectCaches = null;
        normalDirectCaches = null;
        numShiftsNormalDirect = -1;
    }
    if (heapArena != null) {
        // Create the caches for the heap allocations
        tinySubPageHeapCaches = createSubPageCaches(
                tinyCacheSize, PoolArena.numTinySubpagePools, SizeClass.Tiny);
        smallSubPageHeapCaches = createSubPageCaches(
                smallCacheSize, heapArena.numSmallSubpagePools, SizeClass.Small);

        numShiftsNormalHeap = log2(heapArena.pageSize);
        normalHeapCaches = createNormalCaches(
                normalCacheSize, maxCachedBufferCapacity, heapArena);

        heapArena.numThreadCaches.getAndIncrement();
    } else {
        // No heapArea is configured so just null out all caches
        tinySubPageHeapCaches = null;
        smallSubPageHeapCaches = null;
        normalHeapCaches = null;
        numShiftsNormalHeap = -1;
    }

    // Only check if there are caches in use.
    if ((tinySubPageDirectCaches != null || smallSubPageDirectCaches != null || normalDirectCaches != null
            || tinySubPageHeapCaches != null || smallSubPageHeapCaches != null || normalHeapCaches != null)
            && freeSweepAllocationThreshold < 1) {
        throw new IllegalArgumentException("freeSweepAllocationThreshold: "
                + freeSweepAllocationThreshold + " (expected: > 0)");
    }
}

private static <T> MemoryRegionCache<T>[] createSubPageCaches(
        int cacheSize, int numCaches, SizeClass sizeClass) {
    if (cacheSize > 0 && numCaches > 0) {
        @SuppressWarnings("unchecked")
        MemoryRegionCache<T>[] cache = new MemoryRegionCache[numCaches];
        for (int i = 0; i < cache.length; i++) {
            // TODO: maybe use cacheSize / cache.length
            cache[i] = new SubPageMemoryRegionCache<T>(cacheSize, sizeClass);
        }
        return cache;
    } else {
        return null;
    }
}

private static final class SubPageMemoryRegionCache<T> extends MemoryRegionCache<T> {
    SubPageMemoryRegionCache(int size, SizeClass sizeClass) {
        super(size, sizeClass);
    }

    // other
}

MemoryRegionCache(int size, SizeClass sizeClass) {
    this.size = MathUtil.safeFindNextPositivePowerOfTwo(size);
    queue = PlatformDependent.newFixedMpscQueue(this.size);
    this.sizeClass = sizeClass;
}
```

其中主要构造了三类子页缓冲区，用以分配小对象。注意，`SubPageMemoryRegionCache`的`queue`字段初始化之后是一个空队列。

从线程缓存中获取到堆arena之后，尝试进行缓冲区的分配：

```java
PooledByteBuf<T> allocate(PoolThreadCache cache, int reqCapacity, int maxCapacity) {
    PooledByteBuf<T> buf = newByteBuf(maxCapacity);
    allocate(cache, buf, reqCapacity);
    return buf;
}

private void allocate(PoolThreadCache cache, PooledByteBuf<T> buf, final int reqCapacity) {
    // >=512 则变为pow2
    // <512  则变为16的倍数
    final int normCapacity = normalizeCapacity(reqCapacity);
    if (isTinyOrSmall(normCapacity)) { // capacity < pageSize
        int tableIdx;
        PoolSubpage<T>[] table;
        boolean tiny = isTiny(normCapacity);
        if (tiny) { // < 512
            // 尝试从线程缓存分配
            if (cache.allocateTiny(this, buf, reqCapacity, normCapacity)) {
                // was able to allocate out of the cache so move on
                return;
            }
            // >>> 4
            // 根据请求大小获取在子页池中对应的下标
            tableIdx = tinyIdx(normCapacity);
            table = tinySubpagePools;
        } else {
            if (cache.allocateSmall(this, buf, reqCapacity, normCapacity)) {
                // was able to allocate out of the cache so move on
                return;
            }
            tableIdx = smallIdx(normCapacity);
            table = smallSubpagePools;
        }

        final PoolSubpage<T> head = table[tableIdx];

        /**
         * Synchronize on the head. This is needed as {@link PoolChunk#allocateSubpage(int)} and
         * {@link PoolChunk#free(long)} may modify the doubly linked list as well.
         */
        synchronized (head) {
            // 首次分配时，head.next == head
            final PoolSubpage<T> s = head.next;
            if (s != head) {
                assert s.doNotDestroy && s.elemSize == normCapacity;
                long handle = s.allocate();
                assert handle >= 0;
                s.chunk.initBufWithSubpage(buf, null, handle, reqCapacity);
                incTinySmallAllocation(tiny);
                return;
            }
        }
        synchronized (this) {
            allocateNormal(buf, reqCapacity, normCapacity);
        }

        incTinySmallAllocation(tiny);
        return;
    }
    if (normCapacity <= chunkSize) {
        if (cache.allocateNormal(this, buf, reqCapacity, normCapacity)) {
            // was able to allocate out of the cache so move on
            return;
        }
        synchronized (this) {
            allocateNormal(buf, reqCapacity, normCapacity);
            ++allocationsNormal;
        }
    } else {
        // Huge allocations are never served via the cache so just call allocateHuge
        allocateHuge(buf, reqCapacity);
    }
}
```

请求分配一个给定容量的缓冲区时，需要经过如下几步：

1. 标准化容量
2. 分配小缓冲区
    - 先尝试从线程缓存中分配
    - 再尝试从子页池中分配
3. 分配常规缓冲区
4. 分配大缓冲区

### 标准化容量

如果请求的容量大于512，那么将它调整为最接近的下一个pow2数。<br/>
否则，如果请求容量已经是16的倍数，那么直接返回；<br/>
否则，将它调整为最接近的下一个16的倍数。

回忆之前所提到的，Netty分配时的最小容量为16B。

```java
int normalizeCapacity(int reqCapacity) {
    checkPositiveOrZero(reqCapacity, "reqCapacity");

    // directMemoryCacheAlignment == 0
    if (reqCapacity >= chunkSize) {
        return directMemoryCacheAlignment == 0 ? reqCapacity : alignCapacity(reqCapacity);
    }

    if (!isTiny(reqCapacity)) { // >= 512
        // Doubled

        int normalizedCapacity = reqCapacity;
        normalizedCapacity --;
        normalizedCapacity |= normalizedCapacity >>>  1;
        normalizedCapacity |= normalizedCapacity >>>  2;
        normalizedCapacity |= normalizedCapacity >>>  4;
        normalizedCapacity |= normalizedCapacity >>>  8;
        normalizedCapacity |= normalizedCapacity >>> 16;
        normalizedCapacity ++;

        if (normalizedCapacity < 0) {
            normalizedCapacity >>>= 1;
        }
        assert directMemoryCacheAlignment == 0 || (normalizedCapacity & directMemoryCacheAlignmentMask) == 0;

        return normalizedCapacity;
    }

    if (directMemoryCacheAlignment > 0) {
        return alignCapacity(reqCapacity);
    }

    // Quantum-spaced
    if ((reqCapacity & 15) == 0) {
        return reqCapacity;
    }

    return (reqCapacity & ~15) + 16;
}
```

### 分配小缓冲区

使用掩码而非比较符的减法来判断缓冲区大小。

```java
// 相当于 subpageOverflowMask = -pageSize
// 11111111 11111111 11100000 00000000
subpageOverflowMask = ~(pageSize - 1);

// capacity < pageSize
boolean isTinyOrSmall(int normCapacity) {
    return (normCapacity & subpageOverflowMask) == 0;
}

// normCapacity < 512
static boolean isTiny(int normCapacity) {
    return (normCapacity & 0xFFFFFE00) == 0;
}

```

接下来先看tiny缓冲区分配：

```java
boolean allocateTiny(PoolArena<?> area, PooledByteBuf<?> buf, int reqCapacity, int normCapacity) {
    return allocate(cacheForTiny(area, normCapacity), buf, reqCapacity);
}

private MemoryRegionCache<?> cacheForTiny(PoolArena<?> area, int normCapacity) {
    // >>> 4
    // 16B 分配在第一格
    // 32B 分配在第二格
    // 48B 分配在第三格
    int idx = PoolArena.tinyIdx(normCapacity);
    if (area.isDirect()) {
        return cache(tinySubPageDirectCaches, idx);
    }
    return cache(tinySubPageHeapCaches, idx);
}

static int tinyIdx(int normCapacity) {
    return normCapacity >>> 4;
}

private static <T> MemoryRegionCache<T> cache(MemoryRegionCache<T>[] cache, int idx) {
    if (cache == null || idx > cache.length - 1) {
        return null;
    }
    return cache[idx];
}


private boolean allocate(MemoryRegionCache<?> cache, PooledByteBuf buf, int reqCapacity) {
    if (cache == null) {
        // no cache found so just return false here
        return false;
    }
    // 从线程缓存中分配，首次分配时线程缓存为空，返回false
    // 直到常规缓存用完并被回收时，才加入到线程缓存
    boolean allocated = cache.allocate(buf, reqCapacity);
    if (++ allocations >= freeSweepAllocationThreshold) {
        allocations = 0;
        trim();
    }
    return allocated;
}

public final boolean allocate(PooledByteBuf<T> buf, int reqCapacity) {
    Entry<T> entry = queue.poll();
    if (entry == null) {
        return false;
    }
    initBuf(entry.chunk, entry.nioBuffer, entry.handle, buf, reqCapacity);
    entry.recycle();

    // allocations is not thread-safe which is fine as this is only called from the same thread all time.
    ++ allocations;
    return true;
}
```

在构造`PoolThreadCache`以及`PoolArena`时，tinySubPage一共分配了32个，tiny缓冲区的大小范围为[16B, 512B)，512/32=16，相当于>>>4。在标准化容量的时候，tiny大小的容量被调整为16的倍数，因此16B, 32B, 48B, 64B等容量对应了32个tinySubPage。

获取到对应的tinySubPage后，需要从中分配一块容量，之前构造`PoolThreadLocal`时提到，每一个tinySubPage初始化时它的`queue`字段都是一个空队列，因此分配失败。所以初始分配时，并不是从缓冲区中分配的，而是从arena中分配。关于缓冲区分配，后续再说。


small缓冲区的分配与tiny类似。

```java
boolean allocateSmall(PoolArena<?> area, PooledByteBuf<?> buf, int reqCapacity, int normCapacity) {
    return allocate(cacheForSmall(area, normCapacity), buf, reqCapacity);
}

private MemoryRegionCache<?> cacheForSmall(PoolArena<?> area, int normCapacity) {
    int idx = PoolArena.smallIdx(normCapacity);
    if (area.isDirect()) {
        return cache(smallSubPageDirectCaches, idx);
    }
    return cache(smallSubPageHeapCaches, idx);
}

static int smallIdx(int normCapacity) {
    int tableIdx = 0;
    int i = normCapacity >>> 10;
    while (i != 0) {
        i >>>= 1;
        tableIdx ++;
    }
    return tableIdx;
}
```

`smallSubPageHeapCaches`缓冲区在构造时一共分配了4个，容量范围为[512B, 4KB]。<br/>
<br/>

从线程缓存中分配失败后，就只能从arena中直接分配。

```java
final PoolSubpage<T> head = table[tableIdx];

/**
 * Synchronize on the head. This is needed as {@link PoolChunk#allocateSubpage(int)} and
 * {@link PoolChunk#free(long)} may modify the doubly linked list as well.
 */
synchronized (head) {
    // 首次分配时，head.next == head
    final PoolSubpage<T> s = head.next;
    if (s != head) {
        assert s.doNotDestroy && s.elemSize == normCapacity;
        long handle = s.allocate();
        assert handle >= 0;
        s.chunk.initBufWithSubpage(buf, null, handle, reqCapacity);
        incTinySmallAllocation(tiny);
        return;
    }
}

```

这里的`table`以及`tableIdx`与前面线程缓存中`tinySubPage`与`idx`的获取完全一样，只不过是从arena区中的子页缓冲池中获取。

之前构造子页缓冲池时，`head.next = head`，因此首次分配时也无法从子页缓冲区中分配。

```java
private PoolSubpage<T> newSubpagePoolHead(int pageSize) {
    PoolSubpage<T> head = new PoolSubpage<T>(pageSize);
    head.prev = head;
    head.next = head;
    return head;
}
```

接下来使用`allocateNormal`方法分配，在构造`PoolArena`时，`ChunkList`只进行了各种区域的连接，并没有构造`Chunk`，因此无法从`ChunkList`中分配，需要先构造一个新的chunk，从中分配容量，并加入到`ChunkList`中。

```java
private void allocateNormal(PooledByteBuf<T> buf, int reqCapacity, int normCapacity) {
    // 首次分配时，全部为空
    if (q050.allocate(buf, reqCapacity, normCapacity) || q025.allocate(buf, reqCapacity, normCapacity) ||
        q000.allocate(buf, reqCapacity, normCapacity) || qInit.allocate(buf, reqCapacity, normCapacity) ||
        q075.allocate(buf, reqCapacity, normCapacity)) {
        return;
    }

    // Add a new chunk.
    PoolChunk<T> c = newChunk(pageSize, maxOrder, pageShifts, chunkSize);
    // 从chunk中分配
    boolean success = c.allocate(buf, reqCapacity, normCapacity);
    assert success;
    qInit.add(c);
}

protected PoolChunk<byte[]> newChunk(int pageSize, int maxOrder, int pageShifts, int chunkSize) {
    return new PoolChunk<byte[]>(this, newByteArray(chunkSize), pageSize, maxOrder, pageShifts, chunkSize, 0);
}

PoolChunk(PoolArena<T> arena, T memory, int pageSize, int maxOrder, int pageShifts, int chunkSize, int offset) {
    unpooled = false;
    this.arena = arena;
    this.memory = memory;
    // 8192
    this.pageSize = pageSize;
    // 13
    this.pageShifts = pageShifts;
    // 11
    this.maxOrder = maxOrder;
    // 16M
    this.chunkSize = chunkSize;
    // 0
    this.offset = offset;
    unusable = (byte) (maxOrder + 1);
    // 24
    log2ChunkSize = log2(chunkSize);
    subpageOverflowMask = ~(pageSize - 1);
    freeBytes = chunkSize;

    assert maxOrder < 30 : "maxOrder should be < 30, but is: " + maxOrder;
    // 2048
    maxSubpageAllocs = 1 << maxOrder;

    // Generate the memory map.
    memoryMap = new byte[maxSubpageAllocs << 1];
    depthMap = new byte[memoryMap.length];
    int memoryMapIndex = 1;
    for (int d = 0; d <= maxOrder; ++ d) { // move down the tree one level at a time
        int depth = 1 << d;
        for (int p = 0; p < depth; ++ p) {
            // in each level traverse left to right and set value to the depth of subtree
            memoryMap[memoryMapIndex] = (byte) d;
            depthMap[memoryMapIndex] = (byte) d;
            memoryMapIndex ++;
        }
    }

    subpages = newSubpageArray(maxSubpageAllocs);
    cachedNioBuffers = new ArrayDeque<ByteBuffer>(8);
}

private PoolSubpage<T>[] newSubpageArray(int size) {
    return new PoolSubpage[size];
}
```

`PoolChunk`的结构是一个二叉树，将16M大小的块以8K的页为单位，分为2048份，自顶而下容量逐层减半，直到最后一层容量为8K。

```
 depth=0        1 node (chunkSize)
 depth=1        2 nodes (chunkSize/2)
 ..
 ..
 depth=d        2^d nodes (chunkSize/2^d)
 ..
 depth=maxOrder 2^maxOrder nodes (chunkSize/2^{maxOrder} = pageSize)
```

给定一个`chunkSize/2^d`大小的容量，只需要到第 d 层寻找未使用过的节点即可。注意，为了迅速定位，使用`memoryMap`以及`depthMap`两个字段来表示这个二叉树（实际上更像一个堆），在初始化时，每一层的节点对应的`memoryMap`以及`depthMap`的值为这一层的深度。

某一个节点id对应的值的含义如下：

```
1) memoryMap[id] = depth_of_id  => 空闲/未分配

2) memoryMap[id] > depth_of_id  => 至少一个子节点被分配了，所以我们不能分配它，但是它的其他子节点依然可以用来分配

3) memoryMap[id] = maxOrder + 1 => 这个节点被完全分配了，它的所有子节点也都被分配了，因此它被标记为不可用
```

注意：当子节点被分配后，需要修改它的父节点的状态。
<br/>
<br/>

在了解了`PoolChunk`的结构后，让我们看一下如何从`PoolChunk`中分配小内存。

```java
boolean allocate(PooledByteBuf<T> buf, int reqCapacity, int normCapacity) {
    final long handle;
    if ((normCapacity & subpageOverflowMask) != 0) { // >= pageSize
        handle =  allocateRun(normCapacity);
    } else {
        handle = allocateSubpage(normCapacity);
    }

    if (handle < 0) {
        return false;
    }
    ByteBuffer nioBuffer = cachedNioBuffers != null ? cachedNioBuffers.pollLast() : null;
    initBuf(buf, nioBuffer, handle, reqCapacity);
    return true;
}

private long allocateSubpage(int normCapacity) {
    // Obtain the head of the PoolSubPage pool that is owned by the PoolArena and synchronize on it.
    // This is need as we may add it back and so alter the linked-list structure.
    PoolSubpage<T> head = arena.findSubpagePoolHead(normCapacity);
    // subpages are only be allocated from pages i.e., leaves
    int d = maxOrder;
    synchronized (head) {
        int id = allocateNode(d);
        if (id < 0) {
            return id;
        }

        final PoolSubpage<T>[] subpages = this.subpages;
        final int pageSize = this.pageSize;

        freeBytes -= pageSize;

        int subpageIdx = subpageIdx(id);
        PoolSubpage<T> subpage = subpages[subpageIdx];
        if (subpage == null) {
            subpage = new PoolSubpage<T>(head, this, id, runOffset(id), pageSize, normCapacity);
            subpages[subpageIdx] = subpage;
        } else {
            subpage.init(head, normCapacity);
        }
        return subpage.allocate();
    }
}

// 此步与之前从subPagePool中获取相同
PoolSubpage<T> findSubpagePoolHead(int elemSize) {
    int tableIdx;
    PoolSubpage<T>[] table;
    if (isTiny(elemSize)) { // < 512
        tableIdx = elemSize >>> 4;
        table = tinySubpagePools;
    } else {
        tableIdx = 0;
        elemSize >>>= 10;
        while (elemSize != 0) {
            elemSize >>>= 1;
            tableIdx ++;
        }
        table = smallSubpagePools;
    }

    return table[tableIdx];
}

private int allocateNode(int d) {
    int id = 1;
    int initial = - (1 << d); // has last d bits = 0 and rest all = 1
    byte val = value(id);
    if (val > d) { // unusable
        return -1;
    }
    while (val < d || (id & initial) == 0) { // id & initial == 1 << d for all ids at depth d, for < d it is 0
        id <<= 1;
        val = value(id);
        // 如果此节点没有足够空间分配
        if (val > d) {
            // 获取兄弟节点
            id ^= 1;
            val = value(id);
        }
    }
    byte value = value(id);
    assert value == d && (id & initial) == 1 << d : String.format("val = %d, id & initial = %d, d = %d",
            value, id & initial, d);
    setValue(id, unusable); // mark as unusable
    updateParentsAlloc(id);
    return id;
}

private void updateParentsAlloc(int id) {
    while (id > 1) {
        int parentId = id >>> 1;
        byte val1 = value(id);
        byte val2 = value(id ^ 1);
        byte val = val1 < val2 ? val1 : val2;
        setValue(parentId, val);
        id = parentId;
    }
}
```

当分配小内存时，由于它必定比页小，所以可以确定从叶节点即最后一层寻找空闲内存。首先从顶部节点开始，判断是否还有足够内存使用(`val > d`)，然后逐级向下寻找有足够空闲内存的节点，直到最后一层。寻找到空闲的叶节点后，将它设置为`unusable`，然后更新父节点的状态。接下来根据这个节点构造`PoolSubpage`对象，在此对象内部进行内存分配。

```java
int subpageIdx = subpageIdx(id);
PoolSubpage<T> subpage = subpages[subpageIdx];
if (subpage == null) {
    subpage = new PoolSubpage<T>(head, this, id, runOffset(id), pageSize, normCapacity);
    subpages[subpageIdx] = subpage;
} else {
    subpage.init(head, normCapacity);
}
return subpage.allocate();



private int subpageIdx(int memoryMapIdx) {
    // maxSubpageAllocs = 00000000 00000000 00001000 00000000
    return memoryMapIdx ^ maxSubpageAllocs; // remove highest set bit, to get offset
}

private int runOffset(int id) {
    // represents the 0-based offset in #bytes from start of the byte-array chunk
    int shift = id ^ 1 << depth(id);
    return shift * runLength(id);
}

PoolSubpage(PoolSubpage<T> head, PoolChunk<T> chunk, int memoryMapIdx, int runOffset, int pageSize, int elemSize) {
    this.chunk = chunk;
    this.memoryMapIdx = memoryMapIdx;
    this.runOffset = runOffset;
    this.pageSize = pageSize;
    bitmap = new long[pageSize >>> 10]; // pageSize / 16 / 64
    init(head, elemSize);
}

void init(PoolSubpage<T> head, int elemSize) {
    doNotDestroy = true;
    this.elemSize = elemSize;
    if (elemSize != 0) {
        // 获取一个页总共可以分配多少个elemSize
        maxNumElems = numAvail = pageSize / elemSize;
        nextAvail = 0;
        // 获取elemSize需要多少个long变量记录
        bitmapLength = maxNumElems >>> 6;
        if ((maxNumElems & 63) != 0) {
            bitmapLength ++;
        }

        // 初始化bitmap
        for (int i = 0; i < bitmapLength; i ++) {
            bitmap[i] = 0;
        }
    }
    // 增加到PoolArena中分配的子页缓冲区中
    addToPool(head);
}

private void addToPool(PoolSubpage<T> head) {
    assert prev == null && next == null;
    prev = head;
    next = head.next;
    next.prev = this;
    head.next = this;
}
```

`PoolSubpage`对象内部使用`bitmap`记录哪些内存已经被分配了，由于每一个`PoolSubpage`对象与一个页关联，它的总大小也是一个页大小，同时Netty最小的分配容量为16，一个long变量有64位，所以最多只需要`pageSize / 16 / 64`个long变量即可记录内存使用情况。

注意，`PoolSubpage`构造完之后，被加入到了PoolArena中分配的子页缓冲区中，当再次分配一个容量为elemSize的缓冲区时，可以不需要再走`PoolChunk`进行分配，而是直接从`PoolArena`中的子页缓冲池获取到这个`PoolSubpage`，然后分配容量。

```java
final PoolSubpage<T> head = table[tableIdx];

/**
 * Synchronize on the head. This is needed as {@link PoolChunk#allocateSubpage(int)} and
 * {@link PoolChunk#free(long)} may modify the doubly linked list as well.
 */
synchronized (head) {
    // 首次分配时，head.next == head
    final PoolSubpage<T> s = head.next;
    if (s != head) {
        assert s.doNotDestroy && s.elemSize == normCapacity;
        long handle = s.allocate();
        assert handle >= 0;
        s.chunk.initBufWithSubpage(buf, null, handle, reqCapacity);
        incTinySmallAllocation(tiny);
        return;
    }
}
```

下面看`PoolSubpage`是如何分配内存的：

```java
long allocate() {
    if (elemSize == 0) {
        return toHandle(0);
    }

    if (numAvail == 0 || !doNotDestroy) {
        return -1;
    }

    final int bitmapIdx = getNextAvail();
    int q = bitmapIdx >>> 6;
    int r = bitmapIdx & 63;
    assert (bitmap[q] >>> r & 1) == 0;
    bitmap[q] |= 1L << r;

    if (-- numAvail == 0) {
        removeFromPool();
    }

    return toHandle(bitmapIdx);
}

private int getNextAvail() {
    int nextAvail = this.nextAvail;
    // 表示nextAvail指向下一个可分配的偏移量
    if (nextAvail >= 0) {
        // 每次分配后，将nextAvail置为0，下次分配时重新计算
        this.nextAvail = -1;
        return nextAvail;
    }
    return findNextAvail();
}

private int findNextAvail() {
    final long[] bitmap = this.bitmap;
    final int bitmapLength = this.bitmapLength;
    for (int i = 0; i < bitmapLength; i ++) {
        long bits = bitmap[i];
        // 表示这一块内存段没有全部使用完
        if (~bits != 0) {
            return findNextAvail0(i, bits);
        }
    }
    return -1;
}

private int findNextAvail0(int i, long bits) {
    final int maxNumElems = this.maxNumElems;
    final int baseVal = i << 6;

    for (int j = 0; j < 64; j ++) {
        if ((bits & 1) == 0) {
            int val = baseVal | j;
            if (val < maxNumElems) {
                return val;
            } else {
                break;
            }
        }
        bits >>>= 1;
    }
    return -1;
}

private long toHandle(int bitmapIdx) {
    return 0x4000000000000000L | (long) bitmapIdx << 32 | memoryMapIdx;
}
```

1. 方法`getNextAvail()`负责找到当前page中可分配内存段的bitmapIdx；
2. `q = bitmapIdx >>> 6`，确定bitmap数组下标为q的long数，用来描述 bitmapIdx 内存段的状态；
3. `bitmapIdx & 63`将超出64的那一部分二进制数抹掉，得到一个小于64的数r；
4. `bitmap[q] |= 1L << r`将对应位置q设置为1；


### 分配常规缓冲区

当请求容量处于pageSize到chunkSize之内时，使用`allocateNormal`方法分配：

```java
if (normCapacity <= chunkSize) {
    // 尝试从线程缓存中分配
    if (cache.allocateNormal(this, buf, reqCapacity, normCapacity)) {
        // was able to allocate out of the cache so move on
        return;
    }
    synchronized (this) {
        allocateNormal(buf, reqCapacity, normCapacity);
        ++allocationsNormal;
    }
}

boolean allocateNormal(PoolArena<?> area, PooledByteBuf<?> buf, int reqCapacity, int normCapacity) {
    return allocate(cacheForNormal(area, normCapacity), buf, reqCapacity);
}

private MemoryRegionCache<?> cacheForNormal(PoolArena<?> area, int normCapacity) {
    if (area.isDirect()) {
        int idx = log2(normCapacity >> numShiftsNormalDirect);
        return cache(normalDirectCaches, idx);
    }
    // numShiftsNormalHeap = 13
    int idx = log2(normCapacity >> numShiftsNormalHeap);
    return cache(normalHeapCaches, idx);
}
```

与tiny和small缓存一样，normal线程缓存在初始分配时也会失败，所以从chunk中分配内存。

```java
private void allocateNormal(PooledByteBuf<T> buf, int reqCapacity, int normCapacity) {
    // 首次分配时，全部为空
    if (q050.allocate(buf, reqCapacity, normCapacity) || q025.allocate(buf, reqCapacity, normCapacity) ||
        q000.allocate(buf, reqCapacity, normCapacity) || qInit.allocate(buf, reqCapacity, normCapacity) ||
        q075.allocate(buf, reqCapacity, normCapacity)) {
        return;
    }

    // Add a new chunk.
    PoolChunk<T> c = newChunk(pageSize, maxOrder, pageShifts, chunkSize);
    // 从chunk中分配
    boolean success = c.allocate(buf, reqCapacity, normCapacity);
    assert success;
    qInit.add(c);
}

boolean allocate(PooledByteBuf<T> buf, int reqCapacity, int normCapacity) {
    final long handle;
    if ((normCapacity & subpageOverflowMask) != 0) { // >= pageSize
        handle =  allocateRun(normCapacity);
    } else {
        handle = allocateSubpage(normCapacity);
    }

    if (handle < 0) {
        return false;
    }
    ByteBuffer nioBuffer = cachedNioBuffers != null ? cachedNioBuffers.pollLast() : null;
    initBuf(buf, nioBuffer, handle, reqCapacity);
    return true;
}
```

这一步与之前一样，不过分配normal大小的内存。

```java
private long allocateRun(int normCapacity) {
    int d = maxOrder - (log2(normCapacity) - pageShifts);
    int id = allocateNode(d);
    if (id < 0) {
        return id;
    }
    freeBytes -= runLength(id);
    return id;
}
```

分配normal大小的内存相比来说简单了许多，只在chunk中寻找空闲内存，然后返回。

### 分配大缓冲区

```java
private void allocateHuge(PooledByteBuf<T> buf, int reqCapacity) {
    PoolChunk<T> chunk = newUnpooledChunk(reqCapacity);
    activeBytesHuge.add(chunk.chunkSize());
    buf.initUnpooled(chunk, reqCapacity);
    allocationsHuge.increment();
}
```

大缓冲区的分配则更为简单，直接分配一块`UnpooledChunk`，并将它与`PooledByteBuf`关联起来即可。


## arena的释放

`PoolChunk`, `PoolSubpage`等的释放会直接回到对应的arena中，所以这里只讨论arena的释放。

```java
## PooledByteBuf.java

@Override
protected final void deallocate() {
    if (handle >= 0) {
        final long handle = this.handle;
        this.handle = -1;
        memory = null;
        chunk.arena.free(chunk, tmpNioBuf, handle, maxLength, cache);
        tmpNioBuf = null;
        chunk = null;
        recycle();
    }
}

void free(PoolChunk<T> chunk, ByteBuffer nioBuffer, long handle, int normCapacity, PoolThreadCache cache) {
    if (chunk.unpooled) {
        int size = chunk.chunkSize();
        destroyChunk(chunk);
        activeBytesHuge.add(-size);
        deallocationsHuge.increment();
    } else {
        SizeClass sizeClass = sizeClass(normCapacity);
        if (cache != null && cache.add(this, chunk, nioBuffer, handle, normCapacity, sizeClass)) {
            // cached so not free it.
            return;
        }

        freeChunk(chunk, handle, sizeClass, nioBuffer, false);
    }
}

boolean add(PoolArena<?> area, PoolChunk chunk, ByteBuffer nioBuffer,
            long handle, int normCapacity, SizeClass sizeClass) {
    MemoryRegionCache<?> cache = cache(area, normCapacity, sizeClass);
    if (cache == null) {
        return false;
    }
    return cache.add(chunk, nioBuffer, handle);
}

private MemoryRegionCache<?> cache(PoolArena<?> area, int normCapacity, SizeClass sizeClass) {
    switch (sizeClass) {
    case Normal:
        return cacheForNormal(area, normCapacity);
    case Small:
        return cacheForSmall(area, normCapacity);
    case Tiny:
        return cacheForTiny(area, normCapacity);
    default:
        throw new Error();
    }
}

public final boolean add(PoolChunk<T> chunk, ByteBuffer nioBuffer, long handle) {
    Entry<T> entry = newEntry(chunk, nioBuffer, handle);
    boolean queued = queue.offer(entry);
    if (!queued) {
        // If it was not possible to cache the chunk, immediately recycle the entry
        entry.recycle();
    }

    return queued;
}
```

当某个`PooledByteBuf`被回收时，会调用`PooledArena`的`free(..)`方法，此方法会优先将这个缓冲区增加到线程缓存以供后续使用。因此，当下一次有一个分配相同大小缓冲区的请求来到时，就可以从`PoolThreadCache`中直接分配，无需再走`PoolChunk`分配。除了缓冲区的再利用，增加到线程缓存中的`Entry`也会再利用，感兴趣可以自行研究。

## PoolThreadCache的释放

前面提到了`PooledByteBuf`被回收后会被加入到线程缓存中，那么线程缓存是如何被释放的呢？关于这一点也是出人预料的，线程缓存的释放操作在线程缓存的分配方法中，注意下面的`trim()`方法：

```java
private boolean allocate(MemoryRegionCache<?> cache, PooledByteBuf buf, int reqCapacity) {
    if (cache == null) {
        // no cache found so just return false here
        return false;
    }
    // 从线程缓存中分配，首次分配时线程缓存为空，返回false
    // 直到常规缓存用完并被回收时，才加入到线程缓存
    boolean allocated = cache.allocate(buf, reqCapacity);
    if (++ allocations >= freeSweepAllocationThreshold) {
        allocations = 0;
        trim();
    }
    return allocated;
}

void trim() {
    trim(tinySubPageDirectCaches);
    trim(smallSubPageDirectCaches);
    trim(normalDirectCaches);
    trim(tinySubPageHeapCaches);
    trim(smallSubPageHeapCaches);
    trim(normalHeapCaches);
}

private static void trim(MemoryRegionCache<?>[] caches) {
    if (caches == null) {
        return;
    }
    for (MemoryRegionCache<?> c: caches) {
        trim(c);
    }
}

private static void trim(MemoryRegionCache<?> cache) {
    if (cache == null) {
        return;
    }
    cache.trim();
}
```

当分配达到一定次数之后，就会触发回收空闲缓存的操作。

关于`PoolThreadCache`的回收操作，涉及到了一个优化操作。设想如果应用持续的分配内存，那么这个回收操作将可以良好的运行，但是如果应用很长时间不再分配内存，那么回收操作将永远不会被触发，这将浪费许多内存空间。因此，Netty提供了一个新的选项，如果设置了`io.netty.allocation.cacheTrimIntervalMillis`，那么Netty将会开启一个线程用以定时回收空闲内存。

```java
@Override
protected synchronized PoolThreadCache initialValue() {
    final PoolArena<byte[]> heapArena = leastUsedArena(heapArenas);
    final PoolArena<ByteBuffer> directArena = leastUsedArena(directArenas);

    final Thread current = Thread.currentThread();
    if (useCacheForAllThreads || current instanceof FastThreadLocalThread) {
        // x, y, 512, 256, 64, 32K, 8192
        final PoolThreadCache cache = new PoolThreadCache(
                heapArena, directArena, tinyCacheSize, smallCacheSize, normalCacheSize,
                DEFAULT_MAX_CACHED_BUFFER_CAPACITY, DEFAULT_CACHE_TRIM_INTERVAL);

        if (DEFAULT_CACHE_TRIM_INTERVAL_MILLIS > 0) {
            final EventExecutor executor = ThreadExecutorMap.currentExecutor();
            if (executor != null) {
                executor.scheduleAtFixedRate(trimTask, DEFAULT_CACHE_TRIM_INTERVAL_MILLIS,
                        DEFAULT_CACHE_TRIM_INTERVAL_MILLIS, TimeUnit.MILLISECONDS);
            }
        }
        return cache;
    }
    // No caching so just use 0 as sizes.
    return new PoolThreadCache(heapArena, directArena, 0, 0, 0, 0, 0);
}
```

注意`if (DEFAULT_CACHE_TRIM_INTERVAL_MILLIS > 0)`。

关于这个优化的问题的讨论，查看 https://github.com/netty/netty/pull/8941

# PooledByteBuf

```java
##PooledHeapByteBuf.java

private static final Recycler<PooledHeapByteBuf> RECYCLER = new Recycler<PooledHeapByteBuf>() {
    @Override
    protected PooledHeapByteBuf newObject(Handle<PooledHeapByteBuf> handle) {
        return new PooledHeapByteBuf(handle, 0);
    }
};

static PooledHeapByteBuf newInstance(int maxCapacity) {
    PooledHeapByteBuf buf = RECYCLER.get();
    buf.reuse(maxCapacity);
    return buf;
}

@SuppressWarnings("unchecked")
public final T get() {
    if (maxCapacityPerThread == 0) {
        return newObject((Handle<T>) NOOP_HANDLE);
    }
    Stack<T> stack = threadLocal.get();
    DefaultHandle<T> handle = stack.pop();
    if (handle == null) {
        handle = stack.newHandle();
        handle.value = newObject(handle);
    }
    return (T) handle.value;
}

PooledHeapByteBuf(Recycler.Handle<? extends PooledHeapByteBuf> recyclerHandle, int maxCapacity) {
    super(recyclerHandle, maxCapacity);
}

@SuppressWarnings("unchecked")
protected PooledByteBuf(Recycler.Handle<? extends PooledByteBuf<T>> recyclerHandle, int maxCapacity) {
    super(maxCapacity);
    this.recyclerHandle = (Handle<PooledByteBuf<T>>) recyclerHandle;
}
```

池化缓冲区的构造是通过`Recycler`做到的，`Recycler`提供了缓冲区复用的功能。池化缓冲区的构造过程很短，没有什么有用的信息。回忆之前`PooledByteBufAllocator`分配缓存，会经常调用`init`方法来初始化缓冲区。

```java
void init(PoolChunk<T> chunk, ByteBuffer nioBuffer,
          long handle, int offset, int length, int maxLength, PoolThreadCache cache) {
    init0(chunk, nioBuffer, handle, offset, length, maxLength, cache);
}

private void init0(PoolChunk<T> chunk, ByteBuffer nioBuffer,
                   long handle, int offset, int length, int maxLength, PoolThreadCache cache) {
    assert handle >= 0;
    assert chunk != null;

    this.chunk = chunk;
    memory = chunk.memory;
    tmpNioBuf = nioBuffer;
    allocator = chunk.arena.parent;
    this.cache = cache;
    this.handle = handle;
    this.offset = offset;
    this.length = length;
    this.maxLength = maxLength;
}
```

池化缓冲区的初始化方法用来将缓冲区与对应的`Chunk`关联到一起，所以池化缓冲区所使用的内存实际上就是`PoolChunk`中的内存。
<br/>
<br/>

关于`ByteBuf`的扩容操作，有一个优化： https://github.com/netty/netty/pull/9086

# UnpooledSlicedByteBuf

派生缓冲区为`ByteBuf`提供了以专门的方式来呈现其内容的视图。这类视图是通过以下方
法被创建的：

- duplicate()
- slice()
- slice(int, int)
- Unpooled.unmodifiableBuffer(…)
- order(ByteOrder)
- readSlice(int)

每个这些方法都将返回一个新的`ByteBuf`实例，它具有自己的读索引、写索引和标记
索引。其内部存储和JDK的`ByteBuffer`一样也是共享的。这使得派生缓冲区的创建成本
是很低廉的，但是这也意味着，如果你修改了它的内容，也同时修改了其对应的源实例，所
以要小心。

```java
@Override
public ByteBuf slice() {
    return slice(readerIndex, readableBytes());
}

@Override
public ByteBuf slice(int index, int length) {
    ensureAccessible();
    return new UnpooledSlicedByteBuf(this, index, length);
}

UnpooledSlicedByteBuf(AbstractByteBuf buffer, int index, int length) {
    super(buffer, index, length);
}

## AbstractUnpooledSlicedByteBuf.java ---------------------------------

private final ByteBuf buffer;
private final int adjustment;

AbstractUnpooledSlicedByteBuf(ByteBuf buffer, int index, int length) {
    super(length);
    checkSliceOutOfBounds(index, length, buffer);

    if (buffer instanceof AbstractUnpooledSlicedByteBuf) {
        this.buffer = ((AbstractUnpooledSlicedByteBuf) buffer).buffer;
        adjustment = ((AbstractUnpooledSlicedByteBuf) buffer).adjustment + index;
    } else if (buffer instanceof DuplicatedByteBuf) {
        this.buffer = buffer.unwrap();
        adjustment = index;
    } else {
        this.buffer = buffer;
        adjustment = index;
    }

    initLength(length);
    writerIndex(length);
}

@Override
public ByteBuf writerIndex(int writerIndex) {
    if (checkBounds) {
        checkIndexBounds(readerIndex, writerIndex, capacity());
    }
    this.writerIndex = writerIndex;
    return this;
}
```

分片缓冲区内部维护了一个指向源缓冲区的指针，因此修改时也会影响源缓冲区。

在构造分片缓冲区时，维护了一个相对于源缓冲区的偏移量，这样访问分片缓冲区时也可以从0开始。当对分片缓冲区再分片时，新的分片缓冲区依然指向最开始的源缓冲区，只是偏移量进行了一定的修改。

```java
@Override
public AbstractByteBuf unwrap() {
    return (AbstractByteBuf) super.unwrap();
}

@Override
protected byte _getByte(int index) {
    return unwrap()._getByte(idx(index));
}

final int idx(int index) {
    return index + adjustment;
}
```

# UnpooledDuplicatedByteBuf

复制缓冲区与分片缓冲区类似。

```java
@Override
public ByteBuf duplicate() {
    ensureAccessible();
    return new UnpooledDuplicatedByteBuf(this);
}

UnpooledDuplicatedByteBuf(AbstractByteBuf buffer) {
    super(buffer);
}

public DuplicatedByteBuf(ByteBuf buffer) {
    this(buffer, buffer.readerIndex(), buffer.writerIndex());
}

DuplicatedByteBuf(ByteBuf buffer, int readerIndex, int writerIndex) {
    super(buffer.maxCapacity());

    if (buffer instanceof DuplicatedByteBuf) {
        this.buffer = ((DuplicatedByteBuf) buffer).buffer;
    } else if (buffer instanceof AbstractPooledDerivedByteBuf) {
        this.buffer = buffer.unwrap();
    } else {
        this.buffer = buffer;
    }

    setIndex(readerIndex, writerIndex);
    markReaderIndex();
    markWriterIndex();
}
```

# CompositeByteBuf

第三种也是最后一种模式使用的是复合缓冲区，它为多个ByteBuf提供一个聚合视图。在这里你可以根据需要添加或者删除ByteBuf实例，这是一个JDK的ByteBuffer实现完全缺失的特性。

Netty通过一个ByteBuf子类——CompositeByteBuf——实现了这个模式，它提供了一个将多个缓冲区表示为单个合并缓冲区的虚拟表示。

> **警告** CompositeByteBuf中的ByteBuf实例可能同时包含直接内存分配和非直接内存分配。如果其中只有一个实例，那么对CompositeByteBuf上的hasArray()方法的调用将返回该组件上的hasArray()方法的值；否则它将返回false。

为了举例说明，让我们考虑一下一个由两部分——头部和主体——组成的将通过HTTP协议传输的消息。这两部分由应用程序的不同模块产生，将会在消息被发送的时候组装。该应用程序可以选择为多个消息重用相同的消息主体。当这种情况  发生时，对于每个消息都将会创建一个新的头部。

因为我们不想为每个消息都重新分配这两个缓冲区，所以使用CompositeByteBuf是一个完美的选择。它在消除了没必要的复制的同时，暴露了通用的ByteBuf API。下图展示了生成的消息布局：

![](/images/netty/CompositeByteBuf.png)

下面展示了如何通过使用JDK的ByteBuffer来实现这一需求。创建了一个包含两个ByteBuffer的数组用来保存这些消息组件，同时创建了第三个ByteBuffer用来保存所有这些数据的副本。

```java
//   Use    an   array to   hold the    message parts
ByteBuffer[] message = new ByteBuffer[] { header, body };
//   Create a new ByteBuffer and use copy to merge the header and    body
ByteBuffer message2 = ByteBuffer.allocate(header.remaining() + body.remaining());
message2.put(header);
message2.put(body); message2.flip();
```

分配和复制操作，以及伴随着对数组管理的需要，使得这个版本的实现效率低下而且笨拙。下面展示了一个使用了CompositeByteBuf的版本：

```java
CompositeByteBuf messageBuf = Unpooled.compositeBuffer();
ByteBuf headerBuf = ...;   // can be backing or direct
ByteBuf bodyBuf = ...;     // can be backing or direct message
Buf.addComponents(headerBuf, bodyBuf);
.....
messageBuf.removeComponent(0);
// remove the header
for (ByteBuf buf : messageBuf) {
      System.out.println(buf.toString());
}
```

CompositeByteBuf可能不支持访问其支撑数组，因此访问CompositeByteBuf中的数据类似于（访问）直接缓冲区的模式，如下所示：

```java
CompositeByteBuf compBuf = Unpooled.compositeBuffer();
int length = compBuf.readableBytes();
byte[] array = new byte[length];
compBuf.getBytes(compBuf.readerIndex(), array);
handleArray(array, 0, array.length);
```

需要注意的是，Netty使用了CompositeByteBuf来优化套接字的I/O操作，尽可能地消除了由JDK的缓冲区实现所导致的性能以及内存使用率的惩罚。这尤其适用于JDK所使用的一种称为分散/收集I/O（Scatter/Gather I/O）的技术，定义为“一种输入和输出的方法，其中，单个系统调用从单个数据流写到一组缓冲区中，或者，从单个数据源读到一组缓冲区中” 。《Linux System Programming》，作者Robert Love（O’Reilly, 2007）。这种优化发生在Netty的核心代码中，因此不会被暴露出来，但是你应该知道它所带来的影响。

## 源码分析

CompositeByteBuf类的定义如下，除了直接继承`AbstractReferenceCountedByteBuf`以外，它还实现了`Iterable<ByteBuf>`接口，用以遍历内部的`ByteBuf`集合。

```java
public class CompositeByteBuf extends AbstractReferenceCountedByteBuf implements Iterable<ByteBuf>
```

除此以外，它并不是直接保存这些`ByteBuf`，而是使用`Component`类对它们进行包装。

```java
private final ByteBufAllocator alloc;
private final boolean direct;
private final int maxNumComponents;

private int componentCount;
private Component[] components; // resized when needed

private boolean freed;
```

`Component`类的定义如下：

```java
private static final class Component {
    final ByteBuf buf;
    int adjustment;
    int offset;
    int endOffset;

    private ByteBuf slice; // cached slice, may be null
```

### 构造方法

相比`UnpooledHeapByteBuf`和`UnpooledDirectByteBuf`来说，`CompositeByteBuf`提供了更多的构造方法，但是依然建议最好使用`UnpooledByteBufAllocator#heapBuffer(int, int)`，`Unpooled#buffer(int)`或者`Unpooled#wrappedBuffer(byte[])`代替直接调用构造方法。

一共有两个public方法共用`private CompositeByteBuf(ByteBufAllocator alloc, boolean direct, int maxNumComponents, int initSize)`私有构造方法，第一个public构造方法较为简单，只进行了一系列默认值的初始化，而第二个public构造方法传入了一个`Iterable<ByteBuf>`，在构造时需要将它里面包含的`ByteBuf`加入到当前的`CompositeByteBuf`中。

```java
public CompositeByteBuf(ByteBufAllocator alloc, boolean direct, int maxNumComponents) {
    // 1
    this(alloc, direct, maxNumComponents, 0);
}

// 1
private CompositeByteBuf(ByteBufAllocator alloc, boolean direct, int maxNumComponents, int initSize) {
    super(AbstractByteBufAllocator.DEFAULT_MAX_CAPACITY);
    if (alloc == null) {
        throw new NullPointerException("alloc");
    }
    if (maxNumComponents < 1) {
        throw new IllegalArgumentException(
                "maxNumComponents: " + maxNumComponents + " (expected: >= 1)");
    }
    this.alloc = alloc;
    this.direct = direct;
    this.maxNumComponents = maxNumComponents;
    components = newCompArray(initSize, maxNumComponents);
}

private static Component[] newCompArray(int initComponents, int maxNumComponents) {
    // static final int DEFAULT_MAX_COMPONENTS = 16;
    int capacityGuess = Math.min(AbstractByteBufAllocator.DEFAULT_MAX_COMPONENTS, maxNumComponents);
    return new Component[Math.max(initComponents, capacityGuess)];
}
```

从初始化的过程中可以看出，`Component[]`数组的大小为传入的`maxNumComponents`参数与16之间的较小值。

第二个构造方法与第一个类似，不过它的initSize不再总是0，而是`Iterable<ByteBuf>`的大小(如果`Iterable<ByteBuf>`同时还是一个`Collection`)。

```java
public CompositeByteBuf(
        ByteBufAllocator alloc, boolean direct, int maxNumComponents, Iterable<ByteBuf> buffers) {
    // 1
    this(alloc, direct, maxNumComponents,
            buffers instanceof Collection ? ((Collection<ByteBuf>) buffers).size() : 0);

    // 增加Iterable<ByteBuf>中的缓冲区，增加时不改变writerIndex索引
    addComponents(false, 0, buffers);
    setIndex(0, capacity());
}
```

在增加完`Iterable<ByteBuf>`的缓冲区后设置写索引。

```java
private CompositeByteBuf addComponents(boolean increaseIndex, int cIndex, Iterable<ByteBuf> buffers) {
    // 如果buffers本来也是ByteBuf，即CompositeByteBuf或其子类，或者自己实现的
    // 那么需要进行特殊处理，如果是包装缓冲区，需要先去掉外层包装
    if (buffers instanceof ByteBuf) {
        // If buffers also implements ByteBuf (e.g. CompositeByteBuf), it has to go to addComponent(ByteBuf).
        return addComponent(increaseIndex, cIndex, (ByteBuf) buffers);
    }
    checkNotNull(buffers, "buffers");
    // 逐个增加迭代器中记录的ByteBuf
    Iterator<ByteBuf> it = buffers.iterator();
    try {
        // 检查索引合法性
        checkComponentIndex(cIndex);

        // No need for consolidation
        while (it.hasNext()) {
            ByteBuf b = it.next();
            if (b == null) {
                break;
            }
            // cIndex代表下一个在Component数组中增加的位置
            // componentCount代表当前Component数组中元素的数量
            cIndex = addComponent0(increaseIndex, cIndex, b) + 1;
            cIndex = Math.min(cIndex, componentCount);
        }
    } finally {
        // 如果出现了异常，需要安全释放还未增加的缓冲区，否则将会出现内存泄漏
        while (it.hasNext()) {
            ReferenceCountUtil.safeRelease(it.next());
        }
    }
    consolidateIfNeeded();
    return this;
}

private int addComponent0(boolean increaseWriterIndex, int cIndex, ByteBuf buffer) {
    assert buffer != null;
    boolean wasAdded = false;
    try {
        checkComponentIndex(cIndex);

        // No need to consolidate - just add a component to the list.
        // 不需要去除包装，直接构造一个Component即可
        Component c = newComponent(buffer, 0);
        int readableBytes = c.length();

        // 增加到数组中
        addComp(cIndex, c);
        wasAdded = true;
        if (readableBytes > 0 && cIndex < componentCount - 1) {
            updateComponentOffsets(cIndex);
        } else if (cIndex > 0) {
            c.reposition(components[cIndex - 1].endOffset);
        }
        if (increaseWriterIndex) {
            writerIndex(writerIndex() + readableBytes);
        }
        return cIndex;
    } finally {
        if (!wasAdded) {
            buffer.release();
        }
    }
}

private Component newComponent(ByteBuf buf, int offset) {
    if (checkAccessible && !buf.isAccessible()) {
        throw new IllegalReferenceCountException(0);
    }
    int srcIndex = buf.readerIndex(), len = buf.readableBytes();
    ByteBuf slice = null;
    // unwrap if already sliced
    // 非切片缓冲区不需要去掉外层包装
    // 调用slice()方法切片时会对原缓冲区进行包装，然后再使用
    if (buf instanceof AbstractUnpooledSlicedByteBuf) {
        srcIndex += ((AbstractUnpooledSlicedByteBuf) buf).idx(0);
        slice = buf;
        buf = buf.unwrap();
    } else if (buf instanceof PooledSlicedByteBuf) {
        srcIndex += ((PooledSlicedByteBuf) buf).adjustment;
        slice = buf;
        buf = buf.unwrap();
    }
    return new Component(buf.order(ByteOrder.BIG_ENDIAN), srcIndex, offset, len, slice);
}

private void addComp(int i, Component c) {
    // 如果需要移动数组中的元素或者扩容数组，那么执行相应操作
    // 不过默认情况下无需执行这些操作，只更新一下数组中的元素数量
    shiftComps(i, 1);
    // 存储到对应位置中
    components[i] = c;
}

private void shiftComps(int i, int count) {
    final int size = componentCount, newSize = size + count;
    assert i >= 0 && i <= size && count > 0;
    if (newSize > components.length) {
        // grow the array
        int newArrSize = Math.max(size + (size >> 1), newSize);
        Component[] newArr;
        if (i == size) {
            newArr = Arrays.copyOf(components, newArrSize, Component[].class);
        } else {
            newArr = new Component[newArrSize];
            if (i > 0) {
                System.arraycopy(components, 0, newArr, 0, i);
            }
            if (i < size) {
                System.arraycopy(components, i, newArr, i + count, size - i);
            }
        }
        components = newArr;
    } else if (i < size) {
        System.arraycopy(components, i, components, i + count, size - i);
    }

    // 更新当前元素数量
    componentCount = newSize;
}
```

从上面的代码中可以看出，在构造时增加`ByteBuf`的过程是较为复杂的，大致过程如下：

1. 检查传入的`Iterable`是否本身也是一个`CompositeByteBuf`或其子类
2. 逐个增加迭代器记录的`ByteBuf`
3. 增加时并不直接增加`ByteBuf`，而是将其封装在一个`Component`中

关于其构造过程稍加了解即可，其中一些方法已经标记为废弃方法，在以后的版本可能会删除它们，所以无需了解清楚每一个细节。

除了传入迭代器作为参数以外，还有一个接受可变参数的构造方法，因此传入数组也可以。关于它的构造过程不再详述。

```java
public CompositeByteBuf(ByteBufAllocator alloc, boolean direct, int maxNumComponents, ByteBuf... buffers) {
    // 2
    this(alloc, direct, maxNumComponents, buffers, 0);
}

// 2
CompositeByteBuf(ByteBufAllocator alloc, boolean direct, int maxNumComponents,
        ByteBuf[] buffers, int offset) {
    this(alloc, direct, maxNumComponents, buffers.length - offset);

    addComponents0(false, 0, buffers, offset);
    consolidateIfNeeded();
    setIndex0(0, capacity());
}

```

之前提到，在增加`ByteBuf`的时候并不会更新writerIndex索引，而是在增加完成后才进行设置，值为`capacity()`。事实上，正常情况下`capacity()`方法的返回值也是0，即使`componentCount`不为0。

```java
@Override
public int capacity() {
    int size = componentCount;
    return size > 0 ? components[size - 1].endOffset : 0;
}
```

### 常用API

与之前的缓冲区不同，`CompositeByteBuf`提供了一些操作用于管理内部的缓冲区列表，例如增加新的缓冲区或者删除某个缓冲区，如下所示：

|方法|描述|
|:-:|:-:|
|addComponent(ByteBuf buffer)|增加一个给定的缓冲区，此方法不会修改writerIndex|
|addComponents(ByteBuf... buffers)|增加给定的多个缓冲区，此方法不会修改writerIndex|
|addComponents(Iterable<ByteBuf> buffers)|增加多个缓冲区，此方法不会修改writerIndex|
|addComponent(int cIndex, ByteBuf buffer)|在给定的位置增加一个缓冲区|
|addComponent(boolean increaseWriterIndex, ByteBuf buffer)|增加一个缓冲区，第一个参数表明是否修改writerIndex|
|addComponents(boolean increaseWriterIndex, ByteBuf... buffers)|增加多个缓冲区，第一个参数表明是否修改writerIndex|
|addComponents(boolean increaseWriterIndex, Iterable<ByteBuf> buffers)|增加多个缓冲区，第一个参数表明是否修改writerIndex|
|addComponent(boolean increaseWriterIndex, int cIndex, ByteBuf buffer)|在给定位置增加一个缓冲区，第一个参数表明是否修改writerIndex|
|addComponents(int cIndex, ByteBuf... buffers)|在给定位置增加多个缓冲区，此方法不会修改writerIndex|
|addComponents(int cIndex, Iterable<ByteBuf> buffers)|在给定位置增加多个缓冲区，此方法不会修改writerIndex|
|removeComponent(int cIndex)|删除给定位置的缓冲区|
|removeComponents(int cIndex, int numComponents)|删除给定位置开始的多个缓冲区|

除此以外，由于`CompositeByteBuf`还实现了`Iterable`接口，所以可以获取它的迭代器。

`CompositeByteBuf`的各个属性依据于它内部存储的缓冲区，如下所示：

```java
@Override
public boolean isDirect() {
    int size = componentCount;
    if (size == 0) {
        return false;
    }
    for (int i = 0; i < size; i++) {
       if (!components[i].buf.isDirect()) {
           return false;
       }
    }
    return true;
}

@Override
public boolean hasArray() {
    switch (componentCount) {
    case 0:
        return true;
    case 1:
        return components[0].buf.hasArray();
    default:
        return false;
    }
}

@Override
public byte[] array() {
    switch (componentCount) {
    case 0:
        return EmptyArrays.EMPTY_BYTES;
    case 1:
        return components[0].buf.array();
    default:
        throw new UnsupportedOperationException();
    }
}

@Override
public int arrayOffset() {
    switch (componentCount) {
    case 0:
        return 0;
    case 1:
        Component c = components[0];
        return c.idx(c.buf.arrayOffset());
    default:
        throw new UnsupportedOperationException();
    }
}

@Override
public boolean hasMemoryAddress() {
    switch (componentCount) {
    case 0:
        return Unpooled.EMPTY_BUFFER.hasMemoryAddress();
    case 1:
        return components[0].buf.hasMemoryAddress();
    default:
        return false;
    }
}

@Override
public long memoryAddress() {
    switch (componentCount) {
    case 0:
        return Unpooled.EMPTY_BUFFER.memoryAddress();
    case 1:
        Component c = components[0];
        return c.buf.memoryAddress() + c.adjustment;
    default:
        throw new UnsupportedOperationException();
    }
}

@Override
public int capacity() {
    int size = componentCount;
    return size > 0 ? components[size - 1].endOffset : 0;
}

```
