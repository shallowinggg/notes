---
layout: default
title: 并发
parent: java
grand_parent: interview
---

# Java 并发

<details open markdown="block">
  <summary>
    Table of contents
  </summary>
  {: .text-delta }
- TOC
{:toc}
</details>

引用： [Cyc2018](https://github.com/CyC2018/CS-Notes)

## 一、使用线程

有三种使用线程的方法：

- 实现 Runnable 接口；
- 实现 Callable 接口；
- 继承 Thread 类。

实现 Runnable 和 Callable 接口的类只能当做一个可以在线程中运行的任务，不是真正意义上的线程，因此最后还需要通过 Thread 来调用。可以理解为任务是通过线程驱动从而执行的。

### 实现 Runnable 接口

需要实现接口中的 run() 方法。

```java
public class MyRunnable implements Runnable {
    @Override
    public void run() {
        // ...
    }
}
```

使用 Runnable 实例再创建一个 Thread 实例，然后调用 Thread 实例的 start() 方法来启动线程。

```java
public static void main(String[] args) {
    MyRunnable instance = new MyRunnable();
    Thread thread = new Thread(instance);
    thread.start();
}
```

### 实现 Callable 接口

与 Runnable 相比，Callable 可以有返回值，返回值通过 FutureTask 进行封装。

```java
public class MyCallable implements Callable<Integer> {
    public Integer call() {
        return 123;
    }
}
```

```java
public static void main(String[] args) throws ExecutionException, InterruptedException {
    MyCallable mc = new MyCallable();
    FutureTask<Integer> ft = new FutureTask<>(mc);
    Thread thread = new Thread(ft);
    thread.start();
    System.out.println(ft.get());
}
```

### 继承 Thread 类

同样也是需要实现 run() 方法，因为 Thread 类也实现了 Runable 接口。

当调用 start() 方法启动一个线程时，虚拟机会将该线程放入就绪队列中等待被调度，当一个线程被调度时会执行该线程的 run() 方法。

```java
public class MyThread extends Thread {
    public void run() {
        // ...
    }
}
```

```java
public static void main(String[] args) {
    MyThread mt = new MyThread();
    mt.start();
}
```

### 实现接口 VS 继承 Thread

实现接口会更好一些，因为：

- Java 不支持多重继承，因此继承了 Thread 类就无法继承其它类，但是可以实现多个接口；
- 类可能只要求可执行就行，继承整个 Thread 类开销过大。

## 二、基础线程机制

### Executor

Executor 管理多个异步任务的执行，而无需程序员显式地管理线程的生命周期。这里的异步是指多个任务的执行互不干扰，不需要进行同步操作。

主要有三种 Executor：

- CachedThreadPool：一个任务创建一个线程；
- FixedThreadPool：所有任务只能使用固定大小的线程；
- SingleThreadExecutor：相当于大小为 1 的 FixedThreadPool。

```java
public static void main(String[] args) {
    ExecutorService executorService = Executors.newCachedThreadPool();
    for (int i = 0; i < 5; i++) {
        executorService.execute(new MyRunnable());
    }
    executorService.shutdown();
}
```

### Daemon

守护线程是程序运行时在后台提供服务的线程，不属于程序中不可或缺的部分。

当所有非守护线程结束时，程序也就终止，同时会杀死所有守护线程。

main() 属于非守护线程。

在线程启动之前使用 setDaemon() 方法可以将一个线程设置为守护线程。

```java
public static void main(String[] args) {
    Thread thread = new Thread(new MyRunnable());
    thread.setDaemon(true);
}
```

### sleep()

Thread.sleep(millisec) 方法会休眠当前正在执行的线程，millisec 单位为毫秒。

sleep() 可能会抛出 InterruptedException，因为异常不能跨线程传播回 main() 中，因此必须在本地进行处理。线程中抛出的其它异常也同样需要在本地进行处理。

```java
public void run() {
    try {
        Thread.sleep(3000);
    } catch (InterruptedException e) {
        e.printStackTrace();
    }
}
```

### yield()

对静态方法 Thread.yield() 的调用声明了当前线程已经完成了生命周期中最重要的部分，可以切换给其它线程来执行。该方法只是对线程调度器的一个建议，而且也只是建议具有相同优先级的其它线程可以运行。

```java
public void run() {
    Thread.yield();
}
```

## 三、中断

一个线程执行完毕之后会自动结束，如果在运行过程中发生异常也会提前结束。

### InterruptedException

通过调用一个线程的 interrupt() 来中断该线程，如果该线程处于阻塞、限期等待或者无限期等待状态，那么就会抛出 InterruptedException，从而提前结束该线程。但是不能中断 I/O 阻塞和 synchronized 锁阻塞。

对于以下代码，在 main() 中启动一个线程之后再中断它，由于线程中调用了 Thread.sleep() 方法，因此会抛出一个 InterruptedException，从而提前结束线程，不执行之后的语句。

```java
public class InterruptExample {

    private static class MyThread1 extends Thread {
        @Override
        public void run() {
            try {
                Thread.sleep(2000);
                System.out.println("Thread run");
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        }
    }
}
```

```java
public static void main(String[] args) throws InterruptedException {
    Thread thread1 = new MyThread1();
    thread1.start();
    thread1.interrupt();
    System.out.println("Main run");
}
```

```html
Main run
java.lang.InterruptedException: sleep interrupted
    at java.lang.Thread.sleep(Native Method)
    at InterruptExample.lambda$main$0(InterruptExample.java:5)
    at InterruptExample$$Lambda$1/713338599.run(Unknown Source)
    at java.lang.Thread.run(Thread.java:745)
```

### interrupted()

如果一个线程的 run() 方法执行一个无限循环，并且没有执行 sleep() 等会抛出 InterruptedException 的操作，那么调用线程的 interrupt() 方法就无法使线程提前结束。

但是调用 interrupt() 方法会设置线程的中断标记，此时调用 interrupted() 方法会返回 true。因此可以在循环体中使用 interrupted() 方法来判断线程是否处于中断状态，从而提前结束线程。

```java
public class InterruptExample {

    private static class MyThread2 extends Thread {
        @Override
        public void run() {
            while (!interrupted()) {
                // ..
            }
            System.out.println("Thread end");
        }
    }
}
```

```java
public static void main(String[] args) throws InterruptedException {
    Thread thread2 = new MyThread2();
    thread2.start();
    thread2.interrupt();
}
```

```html
Thread end
```

### Executor 的中断操作

调用 Executor 的 shutdown() 方法会等待线程都执行完毕之后再关闭，但是如果调用的是 shutdownNow() 方法，则相当于调用每个线程的 interrupt() 方法。

以下使用 Lambda 创建线程，相当于创建了一个匿名内部线程。

```java
public static void main(String[] args) {
    ExecutorService executorService = Executors.newCachedThreadPool();
    executorService.execute(() -> {
        try {
            Thread.sleep(2000);
            System.out.println("Thread run");
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
    });
    executorService.shutdownNow();
    System.out.println("Main run");
}
```

```html
Main run
java.lang.InterruptedException: sleep interrupted
    at java.lang.Thread.sleep(Native Method)
    at ExecutorInterruptExample.lambda$main$0(ExecutorInterruptExample.java:9)
    at ExecutorInterruptExample$$Lambda$1/1160460865.run(Unknown Source)
    at java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1142)
    at java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:617)
    at java.lang.Thread.run(Thread.java:745)
```

如果只想中断 Executor 中的一个线程，可以通过使用 submit() 方法来提交一个线程，它会返回一个 Future\<?\> 对象，通过调用该对象的 cancel(true) 方法就可以中断线程。

```java
Future<?> future = executorService.submit(() -> {
    // ..
});
future.cancel(true);
```

## 四、互斥同步

Java 提供了两种锁机制来控制多个线程对共享资源的互斥访问，第一个是 JVM 实现的 synchronized，而另一个是 JDK 实现的 ReentrantLock。

### synchronized

**1. 同步一个代码块**

```java
public void func() {
    synchronized (this) {
        // ...
    }
}
```

它只作用于同一个对象，如果调用两个对象上的同步代码块，就不会进行同步。

对于以下代码，使用 ExecutorService 执行了两个线程，由于调用的是同一个对象的同步代码块，因此这两个线程会进行同步，当一个线程进入同步语句块时，另一个线程就必须等待。

```java
public class SynchronizedExample {

    public void func1() {
        synchronized (this) {
            for (int i = 0; i < 10; i++) {
                System.out.print(i + " ");
            }
        }
    }
}
```

```java
public static void main(String[] args) {
    SynchronizedExample e1 = new SynchronizedExample();
    ExecutorService executorService = Executors.newCachedThreadPool();
    executorService.execute(() -> e1.func1());
    executorService.execute(() -> e1.func1());
}
```

```html
0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9
```

对于以下代码，两个线程调用了不同对象的同步代码块，因此这两个线程就不需要同步。从输出结果可以看出，两个线程交叉执行。

```java
public static void main(String[] args) {
    SynchronizedExample e1 = new SynchronizedExample();
    SynchronizedExample e2 = new SynchronizedExample();
    ExecutorService executorService = Executors.newCachedThreadPool();
    executorService.execute(() -> e1.func1());
    executorService.execute(() -> e2.func1());
}
```

```html
0 0 1 1 2 2 3 3 4 4 5 5 6 6 7 7 8 8 9 9
```


**2. 同步一个方法**

```java
public synchronized void func () {
    // ...
}
```

它和同步代码块一样，作用于同一个对象。

**3. 同步一个类**

```java
public void func() {
    synchronized (SynchronizedExample.class) {
        // ...
    }
}
```

作用于整个类，也就是说两个线程调用同一个类的不同对象上的这种同步语句，也会进行同步。

```java
public class SynchronizedExample {

    public void func2() {
        synchronized (SynchronizedExample.class) {
            for (int i = 0; i < 10; i++) {
                System.out.print(i + " ");
            }
        }
    }
}
```

```java
public static void main(String[] args) {
    SynchronizedExample e1 = new SynchronizedExample();
    SynchronizedExample e2 = new SynchronizedExample();
    ExecutorService executorService = Executors.newCachedThreadPool();
    executorService.execute(() -> e1.func2());
    executorService.execute(() -> e2.func2());
}
```

```html
0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9
```

**4. 同步一个静态方法**

```java
public synchronized static void fun() {
    // ...
}
```

作用于整个类。

### ReentrantLock

ReentrantLock 是 java.util.concurrent（J.U.C）包中的锁。

```java
public class LockExample {

    private Lock lock = new ReentrantLock();

    public void func() {
        lock.lock();
        try {
            for (int i = 0; i < 10; i++) {
                System.out.print(i + " ");
            }
        } finally {
            lock.unlock(); // 确保释放锁，从而避免发生死锁。
        }
    }
}
```

```java
public static void main(String[] args) {
    LockExample lockExample = new LockExample();
    ExecutorService executorService = Executors.newCachedThreadPool();
    executorService.execute(() -> lockExample.func());
    executorService.execute(() -> lockExample.func());
}
```

```html
0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9
```


### 比较

**1. 锁的实现**

synchronized 是 JVM 实现的，而 ReentrantLock 是 JDK 实现的。

**2. 性能**

新版本 Java 对 synchronized 进行了很多优化，例如自旋锁等，synchronized 与 ReentrantLock 大致相同。

**3. 等待可中断**

当持有锁的线程长期不释放锁的时候，正在等待的线程可以选择放弃等待，改为处理其他事情。

ReentrantLock 可中断，而 synchronized 不行。

**4. 公平锁**

公平锁是指多个线程在等待同一个锁时，必须按照申请锁的时间顺序来依次获得锁。

synchronized 中的锁是非公平的，ReentrantLock 默认情况下也是非公平的，但是也可以是公平的。

**5. 锁绑定多个条件**

一个 ReentrantLock 可以同时绑定多个 Condition 对象。

### 使用选择

除非需要使用 ReentrantLock 的高级功能，否则优先使用 synchronized。这是因为 synchronized 是 JVM 实现的一种锁机制，JVM 原生地支持它，而 ReentrantLock 不是所有的 JDK 版本都支持。并且使用 synchronized 不用担心没有释放锁而导致死锁问题，因为 JVM 会确保锁的释放。

## 五、线程之间的协作

当多个线程可以一起工作去解决某个问题时，如果某些部分必须在其它部分之前完成，那么就需要对线程进行协调。

### join()

在线程中调用另一个线程的 join() 方法，会将当前线程挂起，而不是忙等待，直到目标线程结束。

对于以下代码，虽然 b 线程先启动，但是因为在 b 线程中调用了 a 线程的 join() 方法，b 线程会等待 a 线程结束才继续执行，因此最后能够保证 a 线程的输出先于 b 线程的输出。

```java
public class JoinExample {

    private class A extends Thread {
        @Override
        public void run() {
            System.out.println("A");
        }
    }

    private class B extends Thread {

        private A a;

        B(A a) {
            this.a = a;
        }

        @Override
        public void run() {
            try {
                a.join();
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
            System.out.println("B");
        }
    }

    public void test() {
        A a = new A();
        B b = new B(a);
        b.start();
        a.start();
    }
}
```

```java
public static void main(String[] args) {
    JoinExample example = new JoinExample();
    example.test();
}
```

```
A
B
```

### wait() notify() notifyAll()

调用 wait() 使得线程等待某个条件满足，线程在等待时会被挂起，当其他线程的运行使得这个条件满足时，其它线程会调用 notify() 或者 notifyAll() 来唤醒挂起的线程。

它们都属于 Object 的一部分，而不属于 Thread。

只能用在同步方法或者同步控制块中使用，否则会在运行时抛出 IllegalMonitorStateException。

使用 wait() 挂起期间，线程会释放锁。这是因为，如果没有释放锁，那么其它线程就无法进入对象的同步方法或者同步控制块中，那么就无法执行 notify() 或者 notifyAll() 来唤醒挂起的线程，造成死锁。

```java
public class WaitNotifyExample {

    public synchronized void before() {
        System.out.println("before");
        notifyAll();
    }

    public synchronized void after() {
        try {
            wait();
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
        System.out.println("after");
    }
}
```

```java
public static void main(String[] args) {
    ExecutorService executorService = Executors.newCachedThreadPool();
    WaitNotifyExample example = new WaitNotifyExample();
    executorService.execute(() -> example.after());
    executorService.execute(() -> example.before());
}
```

```html
before
after
```

**wait() 和 sleep() 的区别**

- wait() 是 Object 的方法，而 sleep() 是 Thread 的静态方法；
- wait() 会释放锁，sleep() 不会。

### await() signal() signalAll()

java.util.concurrent 类库中提供了 Condition 类来实现线程之间的协调，可以在 Condition 上调用 await() 方法使线程等待，其它线程调用 signal() 或 signalAll() 方法唤醒等待的线程。

相比于 wait() 这种等待方式，await() 可以指定等待的条件，因此更加灵活。

使用 Lock 来获取一个 Condition 对象。

```java
public class AwaitSignalExample {

    private Lock lock = new ReentrantLock();
    private Condition condition = lock.newCondition();

    public void before() {
        lock.lock();
        try {
            System.out.println("before");
            condition.signalAll();
        } finally {
            lock.unlock();
        }
    }

    public void after() {
        lock.lock();
        try {
            condition.await();
            System.out.println("after");
        } catch (InterruptedException e) {
            e.printStackTrace();
        } finally {
            lock.unlock();
        }
    }
}
```

```java
public static void main(String[] args) {
    ExecutorService executorService = Executors.newCachedThreadPool();
    AwaitSignalExample example = new AwaitSignalExample();
    executorService.execute(() -> example.after());
    executorService.execute(() -> example.before());
}
```

```html
before
after
```

## 六、线程状态

一个线程只能处于一种状态，并且这里的线程状态特指 Java 虚拟机的线程状态，不能反映线程在特定操作系统下的状态。

![](https://raw.githubusercontent.com/shallowinggg/notes/main/images/java/13068256-5068a578fc4cac1e.webp)


### 新建（NEW）

创建后尚未启动。

### 可运行（RUNABLE）

正在 Java 虚拟机中运行。但是在操作系统层面，它可能处于运行状态，也可能等待资源调度（例如处理器资源），资源调度完成就进入运行状态。所以该状态的可运行是指可以被运行，具体有没有运行要看底层操作系统的资源调度。

### 阻塞（BLOCKED）

请求获取 monitor lock 从而进入 synchronized 函数或者代码块，但是其它线程已经占用了该 monitor lock，所以出于阻塞状态。要结束该状态进入从而 RUNABLE 需要其他线程释放 monitor lock。

### 无限期等待（WAITING）

等待其它线程显式地唤醒。

阻塞和等待的区别在于，阻塞是被动的，它是在等待获取 monitor lock。而等待是主动的，通过调用  Object.wait() 等方法进入。

| 进入方法 | 退出方法 |
| --- | --- |
| 没有设置 Timeout 参数的 Object.wait() 方法 | Object.notify() / Object.notifyAll() |
| 没有设置 Timeout 参数的 Thread.join() 方法 | 被调用的线程执行完毕 |
| LockSupport.park() 方法 | LockSupport.unpark(Thread) |

### 限期等待（TIMED_WAITING）

无需等待其它线程显式地唤醒，在一定时间之后会被系统自动唤醒。

| 进入方法 | 退出方法 |
| --- | --- |
| Thread.sleep() 方法 | 时间结束 |
| 设置了 Timeout 参数的 Object.wait() 方法 | 时间结束 / Object.notify() / Object.notifyAll()  |
| 设置了 Timeout 参数的 Thread.join() 方法 | 时间结束 / 被调用的线程执行完毕 |
| LockSupport.parkNanos() 方法 | LockSupport.unpark(Thread) |
| LockSupport.parkUntil() 方法 | LockSupport.unpark(Thread) |

调用 Thread.sleep() 方法使线程进入限期等待状态时，常常用“使一个线程睡眠”进行描述。调用 Object.wait() 方法使线程进入限期等待或者无限期等待时，常常用“挂起一个线程”进行描述。睡眠和挂起是用来描述行为，而阻塞和等待用来描述状态。

### 死亡（TERMINATED）

可以是线程结束任务之后自己结束，或者产生了异常而结束。

[Java SE 9 Enum Thread.State](https://docs.oracle.com/javase/9/docs/api/java/lang/Thread.State.html)

### 实现

Java中有两种线程实现。native线程映射到由主机操作系统实现的线程抽象，操作系统负责native线程调度和时间切片。

第二种线程是“绿色线程”。这些都是由JVM本身实现和管理的，由JVM实现线程调度。自 Java 1.2 以来，Sun / Oracle JVM 不再支持 Java 绿色线程实现。（参见[Green Threads vs Non Green Threads](https://stackoverflow.com/questions/5713142/green-threads-vs-non-green-threads)）

## 七、J.U.C - AQS

java.util.concurrent（J.U.C）大大提高了并发性能，AQS 被认为是 J.U.C 的核心。

### AQS

![](https://raw.githubusercontent.com/shallowinggg/notes/main/images/java/aqs.png)


线程构造节点同步入队后，如果前一个节点是头节点，那么可以尝试获取锁，此时获取锁的几率较大；否则更改前驱节点的状态为`SIGNAL`，这样如果前驱节点释放锁时将能够唤醒此节点以获取锁。如果下一次循环依然无法获取锁，则阻塞等待唤醒。由于将前驱节点设置为`SIGNAL`后，前驱节点可能正好释放了锁，因此需要再循环一次以尝试获取锁，否则此线程将会永远阻塞。

![](https://raw.githubusercontent.com/shallowinggg/notes/main/images/java/aqs-unlock.png)

#### PROPAGATE状态的引入

```java
public class TestSemaphore {

    private static Semaphore sem = new Semaphore(0);

    private static class Thread1 extends Thread {
        @Override
        public void run() {
            sem.acquireUninterruptibly();
        }
    }

    private static class Thread2 extends Thread {
        @Override
        public void run() {
            sem.release();
        }
    }

    public static void main(String[] args) throws InterruptedException {
        for (int i = 0; i < 10000000; i++) {
            Thread t1 = new Thread1();
            Thread t2 = new Thread1();
            Thread t3 = new Thread2();
            Thread t4 = new Thread2();
            t1.start();
            t2.start();
            t3.start();
            t4.start();
            t1.join();
            t2.join();
            t3.join();
            t4.join();
            System.out.println(i);
        }
    }
}
```

```
同步队列中存在两个节点等待获取锁
1. thread3 释放锁，头节点`waitStatus`更改为0，唤醒第一个节点获取锁
2. 节点1获取锁，返回值为0
3. thread4 释放锁，头节点`waitStatus`为0，因此不唤醒后继结点
4. 节点1调用`setHeadAndPropagate`，propagate为0并且原头节点状态为0，因此不唤醒节点2
```

此时节点2永久阻塞，因为没有线程将会再唤醒它。

引入`PROPAGATE`后，线程4释放锁并且头节点`waitStatus`为0时，更改状态为`PROPAGATE`，因此节点1调用`setHeadAndPropagate`时原头节点`waitStatus`为`PROPAGATE` < 0，因此将会唤醒节点2。

### ReentrantLock

#### 非公平锁吞吐量高的关键

```java
final void lock() {
    if (compareAndSetState(0, 1))
        setExclusiveOwnerThread(Thread.currentThread());
    else
        acquire(1);
}
```

线程释放锁后再加锁时可以直接调用`compareAndSetState(0, 1)`尝试加锁，无需进行繁琐的`acquire(1)`常规调用，并且后继线程被唤醒后不一定立刻被CPU调度执行，因此当前线程更有机会获取到锁，可以立即执行任务；而公平锁需要则等待后继线程被CPU调度执行，其中已经存在了大量的时间差。

#### Condition

![Condition](https://raw.githubusercontent.com/shallowinggg/notes/main/images/java/condition.png)

调用`Condition`的常用方法时要求一定要已经持有互斥锁，否则将抛出异常。

调用`signal()`后并不一定会立即唤醒阻塞的线程，直到其可以获取锁了才会被真正唤醒。


### CountDownLatch

用来控制一个或者多个线程等待多个线程。

维护了一个计数器 cnt，每次调用 countDown() 方法会让计数器的值减 1，减到 0 的时候，那些因为调用 await() 方法而在等待的线程就会被唤醒。

<div align="center"> <img src="https://cs-notes-1256109796.cos.ap-guangzhou.myqcloud.com/ba078291-791e-4378-b6d1-ece76c2f0b14.png" width="300px"> </div><br>

```java
public class CountdownLatchExample {

    public static void main(String[] args) throws InterruptedException {
        final int totalThread = 10;
        CountDownLatch countDownLatch = new CountDownLatch(totalThread);
        ExecutorService executorService = Executors.newCachedThreadPool();
        for (int i = 0; i < totalThread; i++) {
            executorService.execute(() -> {
                System.out.print("run..");
                countDownLatch.countDown();
            });
        }
        countDownLatch.await();
        System.out.println("end");
        executorService.shutdown();
    }
}
```

```html
run..run..run..run..run..run..run..run..run..run..end
```

### CyclicBarrier

用来控制多个线程互相等待，只有当多个线程都到达时，这些线程才会继续执行。

和 CountdownLatch 相似，都是通过维护计数器来实现的。线程执行 await() 方法之后计数器会减 1，并进行等待，直到计数器为 0，所有调用 await() 方法而在等待的线程才能继续执行。

CyclicBarrier 和 CountdownLatch 的一个区别是，CyclicBarrier 的计数器通过调用 reset() 方法可以循环使用，所以它才叫做循环屏障。

CyclicBarrier 有两个构造函数，其中 parties 指示计数器的初始值，barrierAction 在所有线程都到达屏障的时候会执行一次。

```java
public CyclicBarrier(int parties, Runnable barrierAction) {
    if (parties <= 0) throw new IllegalArgumentException();
    this.parties = parties;
    this.count = parties;
    this.barrierCommand = barrierAction;
}

public CyclicBarrier(int parties) {
    this(parties, null);
}
```

<div align="center"> <img src="https://cs-notes-1256109796.cos.ap-guangzhou.myqcloud.com/f71af66b-0d54-4399-a44b-f47b58321984.png" width="300px"> </div><br>

```java
public class CyclicBarrierExample {

    public static void main(String[] args) {
        final int totalThread = 10;
        CyclicBarrier cyclicBarrier = new CyclicBarrier(totalThread);
        ExecutorService executorService = Executors.newCachedThreadPool();
        for (int i = 0; i < totalThread; i++) {
            executorService.execute(() -> {
                System.out.print("before..");
                try {
                    cyclicBarrier.await();
                } catch (InterruptedException | BrokenBarrierException e) {
                    e.printStackTrace();
                }
                System.out.print("after..");
            });
        }
        executorService.shutdown();
    }
}
```

```html
before..before..before..before..before..before..before..before..before..before..after..after..after..after..after..after..after..after..after..after..
```

### Semaphore

Semaphore 类似于操作系统中的信号量，可以控制对互斥资源的访问线程数。

以下代码模拟了对某个服务的并发请求，每次只能有 3 个客户端同时访问，请求总数为 10。

```java
public class SemaphoreExample {

    public static void main(String[] args) {
        final int clientCount = 3;
        final int totalRequestCount = 10;
        Semaphore semaphore = new Semaphore(clientCount);
        ExecutorService executorService = Executors.newCachedThreadPool();
        for (int i = 0; i < totalRequestCount; i++) {
            executorService.execute(()->{
                try {
                    semaphore.acquire();
                    System.out.print(semaphore.availablePermits() + " ");
                } catch (InterruptedException e) {
                    e.printStackTrace();
                } finally {
                    semaphore.release();
                }
            });
        }
        executorService.shutdown();
    }
}
```

```html
2 1 2 2 2 2 2 1 2 2
```

### 读写锁
![read-write](https://raw.githubusercontent.com/shallowinggg/notes/main/images/java/rwlock.png)

读写锁将同步状态按位切割，高16位存储读锁状态，低16位存储写锁状态。通过移位计算`s >>> 16`获取读锁状态，`s & ((1 << 16) -1)`读取写锁状态。

#### 写锁

1. 如果读状态不为0或者写状态不为0并且持有锁的线程不是当前线程，那么失败
2. 如果写状态已经到了上限`(1 << 16) -1`，失败（这只会在同步状态不为0时发生）
3. 否则同步状态为0，首次竞争写锁，CAS成功则获取锁

存在读锁时不允许获取写锁，因为如果允许，读线程将会读取到脏数据。

#### 读锁

当有其他线程获取写锁时，无法获取读锁。否则对于非公平锁，如果同步队列头部存在一个写线程等待，那么也无法获取锁，这可以一定程度上缓解写线程饥饿的情况。如果不需要退让写线程，那么通过CAS更新同步状态获取锁。

同时，为了维护每个线程重入读锁的次数，使用了一个`ThreadLocal`变量进行存储；同时，还额外维护了第一个读线程以及最后一个获取读锁的线程的重入次数的缓存，因此可以一定程度上提高读重入的性能。最后一个获取读锁的线程的重入次数的缓存`cachedHolderCounter`并不是一个`volatile`变量，因此即使发生了严重的竞争，也不会影响性能，并且每个线程持有的此对象引用很有可能会是自己的重入次数缓存，反而会一定程度上提升性能。

获取读锁时支持已经持有写锁的线程尝试获取，因此存在了一个锁降级的概念。

```java
r.lock();
if(!unpdate) {
    r.unlock();
    w.lock();
    try{
        //修改
        r.lock();       //核心，在不释放写锁时获取读锁
    } finally {
        w.unlock();
    }
}
try {
    //使用数据
} finally {
    r.unlock();
}
```

通过锁降级的方式，可以提高吞吐量。不过如果此时存在其他写线程阻塞，那么可能会导致其饥饿。

### StampedLock

`StampedLock`是Java 8提供的另一个读写锁，它对`ReentrantReadWriteLock`进行了很多的改进，例如：

- 扩大了最大读线程数量
- 新增了一个乐观读的概念，提高吞吐量
- 获取锁时先自旋多次尝试，因此线程可以减少不必要的阻塞与唤醒

#### 使用long维护同步状态

![state](https://raw.githubusercontent.com/shallowinggg/notes/main/images/java/stamped-lock.png)

初始状态如上图所示，它依然是按位分离，分别存储读写状态，不过读锁只占7位，当读锁被获取的次数超过最大值时，将使用一个新的`int`值存储溢出值。因此读状态最大可达`Integer#MAX_VALUE + (1 << 7) - 2` 。写锁则独占第8位，当第8位被置位了，则代表写锁被持有了。同步状态剩余的位数都提供给写状态使用，用于记录写锁被获取的次数。不过这个锁不支持写可重入，并且读状态溢出时也需要进行额外的处理步骤。

#### 乐观读锁

`tryOptimisticRead`方法只有当写锁没有被获取时会返回一个非0的stamp，并且它不会修改同步状态。在获取这个stamp后直到调用`validate`方法这段时间，如果写锁没有被获取，那么`validate`方法将会返回true。这个模式可以被认为是读锁的一个弱化版本，因为它的状态可能随时被写锁破坏。这个乐观模式的主要是为一些很短的只读代码块的使用设计，它可以降低竞争并且提高吞吐量。但是，它的使用本质上是很脆弱的。乐观读的代码区域应当只读取共享数据并将它们储存在局部变量中以待后来使用，当然在使用前要先验证这些数据是否过期，这可以使用前面提到的`validate`方法。在乐观读模式下的数据读取可能是非常不一致的过程，因此只有当你对数据的表示很熟悉并且重复调用`validate`方法来检查数据的一致性时使用此模式。例如，当先读取一个对象或者数组引用，然后访问它的字段、元素或者方法之一时上面的步骤都是需要的。

只要当前没有线程获取写锁，那么一定可以获取乐观读锁。获取乐观读锁并读取数据后，如果需要使用这些数据，必须先调用`validate`方法检查是否有线程已经获取过写锁，如果有那么当前数据就可能为脏数据，需要丢弃并重新获取。

#### 自旋

在`StampedLock`中，读节点不像`AQS`那样每个读线程都会构造一个自己的节点并加入到同步队列中，而是将许多连续的读节点挂载在一个读节点上，此时同步队列中就不会出现多个连续的读节点，当此读节点获取到锁时，会唤醒在其上挂载的所有读线程，此时其他需要增加到同步队列中的线程无论读写都会帮助头节点唤醒，如此就大大加快了读线程的唤醒速度。

同时，如果前驱节点为头节点，那么不会像`AQS`自旋一次后一样立刻阻塞自己，而是多次自旋（分别为64次以及1024次）继续尝试获取锁。因为头节点是获取锁的线程，因此下一个获取锁的线程必将是自己，并且在可见的未来自己很有可能获取锁成功，所以自旋尝试而不是阻塞自己。因此，将不会出现阻塞后很快自己就被唤醒，等待CPU调度的情况，吞吐量也因此获得大量提升。

而读节点由于大量挂载在同一个节点上，当根读节点获取锁成功后，其他尝试获取锁的线程也将会帮助唤醒挂载节点，相比`AQS`一个节点一个节点顺次唤醒来说，性能也获得了大量提升。

#### 写锁

如果当前不存在悲观读锁或者写锁还未被其他线程持有，那么可以尝试获取写锁。判断悲观读锁以及写锁是否存在的方式便是通过位运算`11111111 & state == 0`快速决定。其中低7位为悲观读锁所修改，第8位则是写锁获取时修改。

如果当前无法获取锁，并且CLH队列中不存在节点等待获取锁，那么自旋尝试获取锁。如果多次自旋结束后仍未获取到锁，那么将自己加入到队列中。如果前驱节点为头节点之后，那么继续自旋尝试获取锁，否则如果头节点为读节点，那么帮助其释放挂载的多个读线程并阻塞自己。当然，如果只有一个处理器，那么将不会进行自旋。

写锁被释放时会在同步状态上增加`10000000`，即记录写锁被获取的次数。

![StampedLock-write](https://raw.githubusercontent.com/shallowinggg/notes/main/images/java/StampedLock-write.png)

#### 悲观读锁

```
如果写锁未被持有并且CLH队列为空，那么尝试CAS获取读锁，否则
    如果队列为空，则自旋尝试获取读锁；自旋结束后仍未获取成功，将自己增加到队列中。
    否则，直接加入队列。
    如果前驱节点也是读节点，那么直接将自己挂载到其上。
    如果头节点为读节点，那么帮助它唤醒挂载其上的读线程。

如果前驱节点为头节点，自旋尝试获取锁；自旋结束后仍未成功，结束自旋。
设置前驱节点为`WATING`，并阻塞自己。
```

如果CLH队列中存在等待锁的线程，那么即使已经有其他线程获取到了读锁，此线程依然无法获取读锁，因为需要避免写线程饥饿。

![StampedLock-read](https://raw.githubusercontent.com/shallowinggg/notes/main/images/java/StampedLock-read.png)


## 八、J.U.C - 其它组件

### FutureTask

在介绍 Callable 时我们知道它可以有返回值，返回值通过 Future\<V\> 进行封装。FutureTask 实现了 RunnableFuture 接口，该接口继承自 Runnable 和 Future\<V\> 接口，这使得 FutureTask 既可以当做一个任务执行，也可以有返回值。

```java
public class FutureTask<V> implements RunnableFuture<V>
```

```java
public interface RunnableFuture<V> extends Runnable, Future<V>
```

FutureTask 可用于异步获取执行结果或取消执行任务的场景。当一个计算任务需要执行很长时间，那么就可以用 FutureTask 来封装这个任务，主线程在完成自己的任务之后再去获取结果。

```java
public class FutureTaskExample {

    public static void main(String[] args) throws ExecutionException, InterruptedException {
        FutureTask<Integer> futureTask = new FutureTask<Integer>(new Callable<Integer>() {
            @Override
            public Integer call() throws Exception {
                int result = 0;
                for (int i = 0; i < 100; i++) {
                    Thread.sleep(10);
                    result += i;
                }
                return result;
            }
        });

        Thread computeThread = new Thread(futureTask);
        computeThread.start();

        Thread otherThread = new Thread(() -> {
            System.out.println("other task is running...");
            try {
                Thread.sleep(1000);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        });
        otherThread.start();
        System.out.println(futureTask.get());
    }
}
```

```html
other task is running...
4950
```

### ThreadPool

`ThreadPoolExecutor`的配置参数如下：
- `corePoolSize`: 核心线程池大小，线程池预热后将会保持至少此数量的线程存活
- `maximumPoolSize`: 最大线程池大小，当任务过多撑满任务队列后将会创建临时线程执行任务，临时线程与核心线程总数不得超过此字段
- `workQueue`: 任务队列
- `keepAliveTime`: 临时线程存活时间，当线程从任务队列获取任务的时间超过此字段时，结束此线程的生命
- `threadFactory`: 线程工厂，创建线程
- `handler`: 任务拒绝处理器，拒绝任务

线程池使用一个`AtomicInteger`来存储线程池状态以及存活线程数量，线程池状态占3位，存活线程数量占29位。

当向线程池提交任务时，首先尝试核心线程；如果核心线程已饱和，则加入到任务队列中；如果任务队列已满，那么创建临时线程执行；如果线程池已饱和，那么使用任务拒绝处理器拒绝此任务。

可以调用`submit`等方法代替`execute`方法向线程池提交任务，这些方法会返回一个`Future`，用户可以通过此`Future`等待任务执行完成或者取消任务。当任务正常完成时，会通知在此`Future`上等待结果的所有线程获取结果；任务处理出现用户自定义异常时，等待线程将会获取一个`ExecutionException`，它包装了真实异常；当任务被取消了，则会抛出`CancellationException`。

![image.png](https://raw.githubusercontent.com/shallowinggg/notes/main/images/java/threadpool.webp)

#### ScheduledThreadPoolExecutor

向定时线程池提交的任务并不会立刻被执行，而是先加入到它内部实现的延时队列中，这个延时队列使用了一个最小堆维护，排序根据任务被执行的具体时间实现。因此，常规线程的任务触发机制已经无法正常执行，需要提前启动线程使得其直接向延时队列获取任务。

这样实现的目的是避免刚启动的线程由于长延时的任务而长期阻塞，导致创建了更多的临时线程或者整个线程池直接假死。

工作线程获取延时队列的第一个任务时，如果还未到执行时间，那么将自己设置为`leader`，等待这个任务可以执行。此时其他线程尝试获取任务时发现`leader`已经被设置，于是直接阻塞等待。当出现一个更快需要执行的任务或者`leader`获取任务成功后随机唤醒一个等待线程。

### BlockingQueue

java.util.concurrent.BlockingQueue 接口有以下阻塞队列的实现：

-   **FIFO 队列**  ：LinkedBlockingQueue、ArrayBlockingQueue（固定长度）
-   **优先级队列**  ：PriorityBlockingQueue

提供了阻塞的 take() 和 put() 方法：如果队列为空 take() 将阻塞，直到队列中有内容；如果队列为满 put() 将阻塞，直到队列有空闲位置。

**使用 BlockingQueue 实现生产者消费者问题**

```java
public class ProducerConsumer {

    private static BlockingQueue<String> queue = new ArrayBlockingQueue<>(5);

    private static class Producer extends Thread {
        @Override
        public void run() {
            try {
                queue.put("product");
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
            System.out.print("produce..");
        }
    }

    private static class Consumer extends Thread {

        @Override
        public void run() {
            try {
                String product = queue.take();
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
            System.out.print("consume..");
        }
    }
}
```

```java
public static void main(String[] args) {
    for (int i = 0; i < 2; i++) {
        Producer producer = new Producer();
        producer.start();
    }
    for (int i = 0; i < 5; i++) {
        Consumer consumer = new Consumer();
        consumer.start();
    }
    for (int i = 0; i < 3; i++) {
        Producer producer = new Producer();
        producer.start();
    }
}
```

```html
produce..produce..consume..consume..produce..consume..produce..consume..produce..consume..
```

#### ArrayBlockingQueue

- 内部使用了一个循环数组
- 是一个有界数组，提供了容量后无法被更改
- FIFO存储
- 可以指定锁的公平性

#### LinkedBlockingQueue

- 内部使用一个单向链表，以FIFO顺序存储
- 可以在链表两头同时进行操作，所以使用两个锁分别保护；同时使用原子变量存储大小，避免数据不一致
- 插入线程在执行完操作后如果队列未满会唤醒其他等待插入的线程，同时队列非空还会唤醒等待获取元素的线程；提取线程同理。
- 迭代器与单向链表保持弱一致性，调用`remove(T)`方法删除一个元素后，不会解除其对下一个结点的next引用，否则迭代器将无法工作。
- 迭代器的`forEachRemaining(Consumer<? super E> action)`操作以64个元素为一批进行操作

#### DelayQueue

- 使用此队列时，元素必须要实现`Delayed`接口
- 当已经有一个线程等待获取队列头元素时，其他也想要获取元素的线程就会进行等待阻塞状态
- 迭代器不和内部的优先级队列保持一致性
- 迭代器的`remove()`方法与内部的优先级队列保持一致性

#### PriorityBlockingQueue

- 必须提供要`Comparator`接口或者队列元素实现`Comparable`接口。
- 可以同时进行扩容和提取元素的操作，不过只能有一个线程进行扩容
- 数组大小小于64时，进行双倍容量的扩展，否则扩容1.5倍
- 使用迭代器访问元素的顺序不会按指定的比较器顺序
- 迭代器不会与原数组保持一致性

#### SynchronousQueue

- 可以指定锁的公平性
- 队列内部不储存元素，所以尽量避免使用add,offer此类立即返回的方法，除非有特殊需求
- 自旋加速匹配

##### 非公平

使用栈作为数据结构，后进先出。

![](https://raw.githubusercontent.com/shallowinggg/notes/main/images/java/sq-stack-lock.png)

![](https://raw.githubusercontent.com/shallowinggg/notes/main/images/java/sq-stack-unlock.png)

##### 公平

使用队列作为数据结构，先进先出。

![](https://raw.githubusercontent.com/shallowinggg/notes/main/images/java/sq-queue-lock.png)

![](https://raw.githubusercontent.com/shallowinggg/notes/main/images/java/sq-queue-unlock.png)

### LongAdder

虽然`AtomicInteger`, `AtomicLong`等提供原子更新的能力，但是当在高并发的场景下会存在大量线程自旋，导致CPU消耗过多且还是无效执行。而`LongAdder`则缓解了这个问题，它是基于分段锁的思想实现的：

![LongAdder](https://raw.githubusercontent.com/shallowinggg/notes/main/images/java/LongAdder.png)

 `LongAdder` 也是基于 `Unsafe` 提供的 `CAS` 操作 + `volatile` 去实现的。在 `LongAdder` 的父类 `Striped64` 中维护着一个 base 变量和一个 cell 数组，当多个线程操作一个变量的时候，先会在这个 base 变量上进行 cas 操作，当它发现线程增多的时候，就会使用 cell 数组。比如当 base 将要更新的时候发现线程增多（也就是调用 casBase 方法更新 base 值失败），那么它会自动使用 cell 数组，每一个线程对应于一个 cell ，在每一个线程中对该 cell 进行 cas 操作，这样就可以将单一 value 的更新压力分担到多个 value 中去，降低单个 value 的 “热度”，同时也减少了大量线程的空转，提高并发效率，分散并发压力。这种分段锁需要额外维护一个内存空间 cells ，不过在高并发场景下，这点成本几乎可以忽略。

### ConcurrentHashMap

- 高16位与低16位异或计算key实际存储所用哈希值
- 一次只能有一个线程初始化哈希表
- 哈希表某个索引为空，则CAS新增数据；否则`synchronize`锁住头节点再执行插入。
- 扩容时可以多线程扩容，每个线程最少扩容16个桶。初始扩容时将`transferIndex`设置为原数组的长度，第一个线程负责扩容`[transferIndex - 16, transferIndex)`这一段桶。其他线程插入或者删除这一段桶内的元素时发现正在扩容，则帮助扩容下一段`[transferIndex - 16, transferIndex)`范围内的桶。扩容的线程数量也有限制，或者是`transferIndex`变为0，或者达到最大扩容线程限制。

Java 7 与 8的区别：

- 不采用segment而采用node，锁住node来实现减小锁粒度。
- 设计了MOVED状态 当resize的中过程中 线程2还在put数据，线程2会帮助resize。
- 使用3个CAS操作来确保node的一些操作的原子性，这种方式代替了锁。
- sizeCtl的不同值来代表不同含义，起到了控制的作用。

### ConcurrentSkipListMap

![](https://raw.githubusercontent.com/shallowinggg/notes/main/images/java/SkipList.png)


### ForkJoin

主要用于并行计算中，和 MapReduce 原理类似，都是把大的计算任务拆分成多个小任务并行计算。

```java
public class ForkJoinExample extends RecursiveTask<Integer> {

    private final int threshold = 5;
    private int first;
    private int last;

    public ForkJoinExample(int first, int last) {
        this.first = first;
        this.last = last;
    }

    @Override
    protected Integer compute() {
        int result = 0;
        if (last - first <= threshold) {
            // 任务足够小则直接计算
            for (int i = first; i <= last; i++) {
                result += i;
            }
        } else {
            // 拆分成小任务
            int middle = first + (last - first) / 2;
            ForkJoinExample leftTask = new ForkJoinExample(first, middle);
            ForkJoinExample rightTask = new ForkJoinExample(middle + 1, last);
            leftTask.fork();
            rightTask.fork();
            result = leftTask.join() + rightTask.join();
        }
        return result;
    }
}
```

```java
public static void main(String[] args) throws ExecutionException, InterruptedException {
    ForkJoinExample example = new ForkJoinExample(1, 10000);
    ForkJoinPool forkJoinPool = new ForkJoinPool();
    Future result = forkJoinPool.submit(example);
    System.out.println(result.get());
}
```

ForkJoin 使用 ForkJoinPool 来启动，它是一个特殊的线程池，线程数量取决于 CPU 核数。

```java
public class ForkJoinPool extends AbstractExecutorService
```

ForkJoinPool 实现了工作窃取算法来提高 CPU 的利用率。每个线程都维护了一个双端队列，用来存储需要执行的任务。工作窃取算法允许空闲的线程从其它线程的双端队列中窃取一个任务来执行。窃取的任务必须是最晚的任务，避免和队列所属线程发生竞争。例如下图中，Thread2 从 Thread1 的队列中拿出最晚的 Task1 任务，Thread1 会拿出 Task2 来执行，这样就避免发生竞争。但是如果队列中只有一个任务时还是会发生竞争。

<div align="center"> <img src="https://cs-notes-1256109796.cos.ap-guangzhou.myqcloud.com/e42f188f-f4a9-4e6f-88fc-45f4682072fb.png" width="300px"> </div><br>

## 九、线程不安全示例

如果多个线程对同一个共享数据进行访问而不采取同步操作的话，那么操作的结果是不一致的。

以下代码演示了 1000 个线程同时对 cnt 执行自增操作，操作结束之后它的值有可能小于 1000。

```java
public class ThreadUnsafeExample {

    private int cnt = 0;

    public void add() {
        cnt++;
    }

    public int get() {
        return cnt;
    }
}
```

```java
public static void main(String[] args) throws InterruptedException {
    final int threadSize = 1000;
    ThreadUnsafeExample example = new ThreadUnsafeExample();
    final CountDownLatch countDownLatch = new CountDownLatch(threadSize);
    ExecutorService executorService = Executors.newCachedThreadPool();
    for (int i = 0; i < threadSize; i++) {
        executorService.execute(() -> {
            example.add();
            countDownLatch.countDown();
        });
    }
    countDownLatch.await();
    executorService.shutdown();
    System.out.println(example.get());
}
```

```html
997
```

## 十、Java 内存模型

Java 内存模型试图屏蔽各种硬件和操作系统的内存访问差异，以实现让 Java 程序在各种平台下都能达到一致的内存访问效果。

### 主内存与工作内存

处理器上的寄存器的读写的速度比内存快几个数量级，为了解决这种速度矛盾，在它们之间加入了高速缓存。

加入高速缓存带来了一个新的问题：缓存一致性。如果多个缓存共享同一块主内存区域，那么多个缓存的数据可能会不一致，需要一些协议来解决这个问题。

<div align="center"> <img src="https://cs-notes-1256109796.cos.ap-guangzhou.myqcloud.com/942ca0d2-9d5c-45a4-89cb-5fd89b61913f.png" width="600px"> </div><br>

所有的变量都存储在主内存中，每个线程还有自己的工作内存，工作内存存储在高速缓存或者寄存器中，保存了该线程使用的变量的主内存副本拷贝。

线程只能直接操作工作内存中的变量，不同线程之间的变量值传递需要通过主内存来完成。

<div align="center"> <img src="https://cs-notes-1256109796.cos.ap-guangzhou.myqcloud.com/15851555-5abc-497d-ad34-efed10f43a6b.png" width="600px"> </div><br>

### 内存间交互操作

Java 内存模型定义了 8 个操作来完成主内存和工作内存的交互操作。

<div align="center"> <img src="https://cs-notes-1256109796.cos.ap-guangzhou.myqcloud.com/8b7ebbad-9604-4375-84e3-f412099d170c.png" width="450px"> </div><br>

- read：把一个变量的值从主内存传输到工作内存中
- load：在 read 之后执行，把 read 得到的值放入工作内存的变量副本中
- use：把工作内存中一个变量的值传递给执行引擎
- assign：把一个从执行引擎接收到的值赋给工作内存的变量
- store：把工作内存的一个变量的值传送到主内存中
- write：在 store 之后执行，把 store 得到的值放入主内存的变量中
- lock：作用于主内存的变量
- unlock

### 内存模型三大特性

#### 1. 原子性

Java 内存模型保证了 read、load、use、assign、store、write、lock 和 unlock 操作具有原子性，例如对一个 int 类型的变量执行 assign 赋值操作，这个操作就是原子性的。但是 Java 内存模型允许虚拟机将没有被 volatile 修饰的 64 位数据（long，double）的读写操作划分为两次 32 位的操作来进行，即 load、store、read 和 write 操作可以不具备原子性。

有一个错误认识就是，int 等原子性的类型在多线程环境中不会出现线程安全问题。前面的线程不安全示例代码中，cnt 属于 int 类型变量，1000 个线程对它进行自增操作之后，得到的值为 997 而不是 1000。

为了方便讨论，将内存间的交互操作简化为 3 个：load、assign、store。

下图演示了两个线程同时对 cnt 进行操作，load、assign、store 这一系列操作整体上看不具备原子性，那么在 T1 修改 cnt 并且还没有将修改后的值写入主内存，T2 依然可以读入旧值。可以看出，这两个线程虽然执行了两次自增运算，但是主内存中 cnt 的值最后为 1 而不是 2。因此对 int 类型读写操作满足原子性只是说明 load、assign、store 这些单个操作具备原子性。

<div align="center"> <img src="https://cs-notes-1256109796.cos.ap-guangzhou.myqcloud.com/2797a609-68db-4d7b-8701-41ac9a34b14f.jpg" width="300px"> </div><br>

AtomicInteger 能保证多个线程修改的原子性。

<div align="center"> <img src="https://cs-notes-1256109796.cos.ap-guangzhou.myqcloud.com/dd563037-fcaa-4bd8-83b6-b39d93a12c77.jpg" width="300px"> </div><br>

使用 AtomicInteger 重写之前线程不安全的代码之后得到以下线程安全实现：

```java
public class AtomicExample {
    private AtomicInteger cnt = new AtomicInteger();

    public void add() {
        cnt.incrementAndGet();
    }

    public int get() {
        return cnt.get();
    }
}
```

```java
public static void main(String[] args) throws InterruptedException {
    final int threadSize = 1000;
    AtomicExample example = new AtomicExample(); // 只修改这条语句
    final CountDownLatch countDownLatch = new CountDownLatch(threadSize);
    ExecutorService executorService = Executors.newCachedThreadPool();
    for (int i = 0; i < threadSize; i++) {
        executorService.execute(() -> {
            example.add();
            countDownLatch.countDown();
        });
    }
    countDownLatch.await();
    executorService.shutdown();
    System.out.println(example.get());
}
```

```html
1000
```

除了使用原子类之外，也可以使用 synchronized 互斥锁来保证操作的原子性。它对应的内存间交互操作为：lock 和 unlock，在虚拟机实现上对应的字节码指令为 monitorenter 和 monitorexit。

```java
public class AtomicSynchronizedExample {
    private int cnt = 0;

    public synchronized void add() {
        cnt++;
    }

    public synchronized int get() {
        return cnt;
    }
}
```

```java
public static void main(String[] args) throws InterruptedException {
    final int threadSize = 1000;
    AtomicSynchronizedExample example = new AtomicSynchronizedExample();
    final CountDownLatch countDownLatch = new CountDownLatch(threadSize);
    ExecutorService executorService = Executors.newCachedThreadPool();
    for (int i = 0; i < threadSize; i++) {
        executorService.execute(() -> {
            example.add();
            countDownLatch.countDown();
        });
    }
    countDownLatch.await();
    executorService.shutdown();
    System.out.println(example.get());
}
```

```html
1000
```

#### 2. 可见性

可见性指当一个线程修改了共享变量的值，其它线程能够立即得知这个修改。Java 内存模型是通过在变量修改后将新值同步回主内存，在变量读取前从主内存刷新变量值来实现可见性的。

主要有三种实现可见性的方式：

- volatile
- synchronized，对一个变量执行 unlock 操作之前，必须把变量值同步回主内存。
- final，被 final 关键字修饰的字段在构造器中一旦初始化完成，并且没有发生 this 逃逸（其它线程通过 this 引用访问到初始化了一半的对象），那么其它线程就能看见 final 字段的值。

对前面的线程不安全示例中的 cnt 变量使用 volatile 修饰，不能解决线程不安全问题，因为 volatile 并不能保证操作的原子性。

#### 3. 有序性

有序性是指：在本线程内观察，所有操作都是有序的。在一个线程观察另一个线程，所有操作都是无序的，无序是因为发生了指令重排序。在 Java 内存模型中，允许编译器和处理器对指令进行重排序，重排序过程不会影响到单线程程序的执行，却会影响到多线程并发执行的正确性。

volatile 关键字通过添加内存屏障的方式来禁止指令重排，即重排序时不能把后面的指令放到内存屏障之前。

也可以通过 synchronized 来保证有序性，它保证每个时刻只有一个线程执行同步代码，相当于是让线程顺序执行同步代码。

### 先行发生原则

上面提到了可以用 volatile 和 synchronized 来保证有序性。除此之外，JVM 还规定了先行发生原则，让一个操作无需控制就能先于另一个操作完成。

#### 1. 单一线程原则

> Single Thread rule

在一个线程内，在程序前面的操作先行发生于后面的操作。

<div align="center"> <img src="https://cs-notes-1256109796.cos.ap-guangzhou.myqcloud.com/874b3ff7-7c5c-4e7a-b8ab-a82a3e038d20.png" width="180px"> </div><br>

#### 2. 管程锁定规则

> Monitor Lock Rule

一个 unlock 操作先行发生于后面对同一个锁的 lock 操作。

<div align="center"> <img src="https://cs-notes-1256109796.cos.ap-guangzhou.myqcloud.com/8996a537-7c4a-4ec8-a3b7-7ef1798eae26.png" width="350px"> </div><br>

#### 3. volatile 变量规则

> Volatile Variable Rule

对一个 volatile 变量的写操作先行发生于后面对这个变量的读操作。

<div align="center"> <img src="https://cs-notes-1256109796.cos.ap-guangzhou.myqcloud.com/942f33c9-8ad9-4987-836f-007de4c21de0.png" width="400px"> </div><br>

#### 4. 线程启动规则

> Thread Start Rule

Thread 对象的 start() 方法调用先行发生于此线程的每一个动作。

<div align="center"> <img src="https://cs-notes-1256109796.cos.ap-guangzhou.myqcloud.com/6270c216-7ec0-4db7-94de-0003bce37cd2.png" width="380px"> </div><br>

#### 5. 线程加入规则

> Thread Join Rule

Thread 对象的结束先行发生于 join() 方法返回。

<div align="center"> <img src="https://cs-notes-1256109796.cos.ap-guangzhou.myqcloud.com/233f8d89-31d7-413f-9c02-042f19c46ba1.png" width="400px"> </div><br>

#### 6. 线程中断规则

> Thread Interruption Rule

对线程 interrupt() 方法的调用先行发生于被中断线程的代码检测到中断事件的发生，可以通过 interrupted() 方法检测到是否有中断发生。

#### 7. 对象终结规则

> Finalizer Rule

一个对象的初始化完成（构造函数执行结束）先行发生于它的 finalize() 方法的开始。

#### 8. 传递性

> Transitivity

如果操作 A 先行发生于操作 B，操作 B 先行发生于操作 C，那么操作 A 先行发生于操作 C。

### volatile

####  提供了可见性保证

- 对volatile变量的所有写操作都将立即写回主存储器，volatile变量的所有读取都将直接从主存储器中读取
- 当写一个volatile变量时，JMM会把该线程对应的本地内存中的共享变量刷新到主内存
- 当读一个volatile变量时，JMM会把该线程对应的本地内存置为无效。线程接下来将从主内存中读取共享变量

#### 避免指令重排序

|是否能重排序	|第二个操作|	第二个操作|	第二个操作|
|:-:|:-:|:-:|:-:|
|第一个操作|	普通读/写|	volatile读|	volatile写|
|普通读/写|			||NO|
|volatile读|	NO	|NO	|NO|
|volatile写|		|NO	|NO|

- 在每个volatile写操作的前面插入一个StoreStore屏障。
- 在每个volatile写操作的后面插入一个StoreLoad屏障。
- 在每个volatile读操作的后面插入一个LoadLoad屏障。
- 在每个volatile读操作的后面插入一个LoadStore屏障。

### final

1. 在构造函数内对一个 final 域的写入，与随后把这个被构造对象的引用赋值给一个引用变量，这两个操作之间不能重排序。
2. 初次读一个包含 final 域的对象的引用，与随后初次读这个 final 域，这两个操作之间不能重排序。
3. 在构造函数内对一个 final 引用的对象的成员域的写入，与随后在构造函数外把这个被构造对象的引用赋值给一个引用变量，这两个操作之间不能重排序。


## 十一、线程安全

多个线程不管以何种方式访问某个类，并且在主调代码中不需要进行同步，都能表现正确的行为。

线程安全有以下几种实现方式：

### 不可变

不可变（Immutable）的对象一定是线程安全的，不需要再采取任何的线程安全保障措施。只要一个不可变的对象被正确地构建出来，永远也不会看到它在多个线程之中处于不一致的状态。多线程环境下，应当尽量使对象成为不可变，来满足线程安全。

不可变的类型：

- final 关键字修饰的基本数据类型
- String
- 枚举类型
- Number 部分子类，如 Long 和 Double 等数值包装类型，BigInteger 和 BigDecimal 等大数据类型。但同为 Number 的原子类 AtomicInteger 和 AtomicLong 则是可变的。

对于集合类型，可以使用 Collections.unmodifiableXXX() 方法来获取一个不可变的集合。

```java
public class ImmutableExample {
    public static void main(String[] args) {
        Map<String, Integer> map = new HashMap<>();
        Map<String, Integer> unmodifiableMap = Collections.unmodifiableMap(map);
        unmodifiableMap.put("a", 1);
    }
}
```

```html
Exception in thread "main" java.lang.UnsupportedOperationException
    at java.util.Collections$UnmodifiableMap.put(Collections.java:1457)
    at ImmutableExample.main(ImmutableExample.java:9)
```

Collections.unmodifiableXXX() 先对原始的集合进行拷贝，需要对集合进行修改的方法都直接抛出异常。

```java
public V put(K key, V value) {
    throw new UnsupportedOperationException();
}
```

### 互斥同步

synchronized 和 ReentrantLock。

### 非阻塞同步

互斥同步最主要的问题就是线程阻塞和唤醒所带来的性能问题，因此这种同步也称为阻塞同步。

互斥同步属于一种悲观的并发策略，总是认为只要不去做正确的同步措施，那就肯定会出现问题。无论共享数据是否真的会出现竞争，它都要进行加锁（这里讨论的是概念模型，实际上虚拟机会优化掉很大一部分不必要的加锁）、用户态核心态转换、维护锁计数器和检查是否有被阻塞的线程需要唤醒等操作。

随着硬件指令集的发展，我们可以使用基于冲突检测的乐观并发策略：先进行操作，如果没有其它线程争用共享数据，那操作就成功了，否则采取补偿措施（不断地重试，直到成功为止）。这种乐观的并发策略的许多实现都不需要将线程阻塞，因此这种同步操作称为非阻塞同步。

#### 1. CAS

乐观锁需要操作和冲突检测这两个步骤具备原子性，这里就不能再使用互斥同步来保证了，只能靠硬件来完成。硬件支持的原子性操作最典型的是：比较并交换（Compare-and-Swap，CAS）。CAS 指令需要有 3 个操作数，分别是内存地址 V、旧的预期值 A 和新值 B。当执行操作时，只有当 V 的值等于 A，才将 V 的值更新为 B。

#### 2. AtomicInteger

J.U.C 包里面的整数原子类 AtomicInteger 的方法调用了 Unsafe 类的 CAS 操作。

以下代码使用了 AtomicInteger 执行了自增的操作。

```java
private AtomicInteger cnt = new AtomicInteger();

public void add() {
    cnt.incrementAndGet();
}
```

以下代码是 incrementAndGet() 的源码，它调用了 Unsafe 的 getAndAddInt() 。

```java
public final int incrementAndGet() {
    return unsafe.getAndAddInt(this, valueOffset, 1) + 1;
}
```

以下代码是 getAndAddInt() 源码，var1 指示对象内存地址，var2 指示该字段相对对象内存地址的偏移，var4 指示操作需要加的数值，这里为 1。通过 getIntVolatile(var1, var2) 得到旧的预期值，通过调用 compareAndSwapInt() 来进行 CAS 比较，如果该字段内存地址中的值等于 var5，那么就更新内存地址为 var1+var2 的变量为 var5+var4。

可以看到 getAndAddInt() 在一个循环中进行，发生冲突的做法是不断的进行重试。

```java
public final int getAndAddInt(Object var1, long var2, int var4) {
    int var5;
    do {
        var5 = this.getIntVolatile(var1, var2);
    } while(!this.compareAndSwapInt(var1, var2, var5, var5 + var4));

    return var5;
}
```

#### 3. ABA

如果一个变量初次读取的时候是 A 值，它的值被改成了 B，后来又被改回为 A，那 CAS 操作就会误认为它从来没有被改变过。

J.U.C 包提供了一个带有标记的原子引用类 AtomicStampedReference 来解决这个问题，它可以通过控制变量值的版本来保证 CAS 的正确性。大部分情况下 ABA 问题不会影响程序并发的正确性，如果需要解决 ABA 问题，改用传统的互斥同步可能会比原子类更高效。

### 无同步方案

要保证线程安全，并不是一定就要进行同步。如果一个方法本来就不涉及共享数据，那它自然就无须任何同步措施去保证正确性。

#### 1. 栈封闭

多个线程访问同一个方法的局部变量时，不会出现线程安全问题，因为局部变量存储在虚拟机栈中，属于线程私有的。

```java
public class StackClosedExample {
    public void add100() {
        int cnt = 0;
        for (int i = 0; i < 100; i++) {
            cnt++;
        }
        System.out.println(cnt);
    }
}
```

```java
public static void main(String[] args) {
    StackClosedExample example = new StackClosedExample();
    ExecutorService executorService = Executors.newCachedThreadPool();
    executorService.execute(() -> example.add100());
    executorService.execute(() -> example.add100());
    executorService.shutdown();
}
```

```html
100
100
```

#### 2. 线程本地存储（Thread Local Storage）

如果一段代码中所需要的数据必须与其他代码共享，那就看看这些共享数据的代码是否能保证在同一个线程中执行。如果能保证，我们就可以把共享数据的可见范围限制在同一个线程之内，这样，无须同步也能保证线程之间不出现数据争用的问题。

符合这种特点的应用并不少见，大部分使用消费队列的架构模式（如“生产者-消费者”模式）都会将产品的消费过程尽量在一个线程中消费完。其中最重要的一个应用实例就是经典 Web 交互模型中的“一个请求对应一个服务器线程”（Thread-per-Request）的处理方式，这种处理方式的广泛应用使得很多 Web 服务端应用都可以使用线程本地存储来解决线程安全问题。

可以使用 java.lang.ThreadLocal 类来实现线程本地存储功能。

对于以下代码，thread1 中设置 threadLocal 为 1，而 thread2 设置 threadLocal 为 2。过了一段时间之后，thread1 读取 threadLocal 依然是 1，不受 thread2 的影响。

```java
public class ThreadLocalExample {
    public static void main(String[] args) {
        ThreadLocal threadLocal = new ThreadLocal();
        Thread thread1 = new Thread(() -> {
            threadLocal.set(1);
            try {
                Thread.sleep(1000);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
            System.out.println(threadLocal.get());
            threadLocal.remove();
        });
        Thread thread2 = new Thread(() -> {
            threadLocal.set(2);
            threadLocal.remove();
        });
        thread1.start();
        thread2.start();
    }
}
```

```html
1
```

为了理解 ThreadLocal，先看以下代码：

```java
public class ThreadLocalExample1 {
    public static void main(String[] args) {
        ThreadLocal threadLocal1 = new ThreadLocal();
        ThreadLocal threadLocal2 = new ThreadLocal();
        Thread thread1 = new Thread(() -> {
            threadLocal1.set(1);
            threadLocal2.set(1);
        });
        Thread thread2 = new Thread(() -> {
            threadLocal1.set(2);
            threadLocal2.set(2);
        });
        thread1.start();
        thread2.start();
    }
}
```

它所对应的底层结构图为：

<div align="center"> <img src="https://cs-notes-1256109796.cos.ap-guangzhou.myqcloud.com/6782674c-1bfe-4879-af39-e9d722a95d39.png" width="500px"> </div><br>

每个 Thread 都有一个 ThreadLocal.ThreadLocalMap 对象。

```java
/* ThreadLocal values pertaining to this thread. This map is maintained
 * by the ThreadLocal class. */
ThreadLocal.ThreadLocalMap threadLocals = null;
```

当调用一个 ThreadLocal 的 set(T value) 方法时，先得到当前线程的 ThreadLocalMap 对象，然后将 ThreadLocal-\>value 键值对插入到该 Map 中。

```java
public void set(T value) {
    Thread t = Thread.currentThread();
    ThreadLocalMap map = getMap(t);
    if (map != null)
        map.set(this, value);
    else
        createMap(t, value);
}
```

get() 方法类似。

```java
public T get() {
    Thread t = Thread.currentThread();
    ThreadLocalMap map = getMap(t);
    if (map != null) {
        ThreadLocalMap.Entry e = map.getEntry(this);
        if (e != null) {
            @SuppressWarnings("unchecked")
            T result = (T)e.value;
            return result;
        }
    }
    return setInitialValue();
}
```

ThreadLocal 从理论上讲并不是用来解决多线程并发问题的，因为根本不存在多线程竞争。

在一些场景 (尤其是使用线程池) 下，由于 ThreadLocal.ThreadLocalMap 的底层数据结构导致 ThreadLocal 有内存泄漏的情况，应该尽可能在每次使用 ThreadLocal 后手动调用 remove()，以避免出现 ThreadLocal 经典的内存泄漏甚至是造成自身业务混乱的风险。

#### 3. 可重入代码（Reentrant Code）

这种代码也叫做纯代码（Pure Code），可以在代码执行的任何时刻中断它，转而去执行另外一段代码（包括递归调用它本身），而在控制权返回后，原来的程序不会出现任何错误。

可重入代码有一些共同的特征，例如不依赖存储在堆上的数据和公用的系统资源、用到的状态量都由参数中传入、不调用非可重入的方法等。

## 十二、锁优化

这里的锁优化主要是指 JVM 对 synchronized 的优化。

### 自旋锁

互斥同步进入阻塞状态的开销都很大，应该尽量避免。在许多应用中，共享数据的锁定状态只会持续很短的一段时间。自旋锁的思想是让一个线程在请求一个共享数据的锁时执行忙循环（自旋）一段时间，如果在这段时间内能获得锁，就可以避免进入阻塞状态。

自旋锁虽然能避免进入阻塞状态从而减少开销，但是它需要进行忙循环操作占用 CPU 时间，它只适用于共享数据的锁定状态很短的场景。

在 JDK 1.6 中引入了自适应的自旋锁。自适应意味着自旋的次数不再固定了，而是由前一次在同一个锁上的自旋次数及锁的拥有者的状态来决定。

### 锁消除

锁消除是指对于被检测出不可能存在竞争的共享数据的锁进行消除。

锁消除主要是通过逃逸分析来支持，如果堆上的共享数据不可能逃逸出去被其它线程访问到，那么就可以把它们当成私有数据对待，也就可以将它们的锁进行消除。

对于一些看起来没有加锁的代码，其实隐式的加了很多锁。例如下面的字符串拼接代码就隐式加了锁：

```java
public static String concatString(String s1, String s2, String s3) {
    return s1 + s2 + s3;
}
```

String 是一个不可变的类，编译器会对 String 的拼接自动优化。在 JDK 1.5 之前，会转化为 StringBuffer 对象的连续 append() 操作：

```java
public static String concatString(String s1, String s2, String s3) {
    StringBuffer sb = new StringBuffer();
    sb.append(s1);
    sb.append(s2);
    sb.append(s3);
    return sb.toString();
}
```

每个 append() 方法中都有一个同步块。虚拟机观察变量 sb，很快就会发现它的动态作用域被限制在 concatString() 方法内部。也就是说，sb 的所有引用永远不会逃逸到 concatString() 方法之外，其他线程无法访问到它，因此可以进行消除。

### 锁粗化

如果一系列的连续操作都对同一个对象反复加锁和解锁，频繁的加锁操作就会导致性能损耗。

上一节的示例代码中连续的 append() 方法就属于这类情况。如果虚拟机探测到由这样的一串零碎的操作都对同一个对象加锁，将会把加锁的范围扩展（粗化）到整个操作序列的外部。对于上一节的示例代码就是扩展到第一个 append() 操作之前直至最后一个 append() 操作之后，这样只需要加锁一次就可以了。

### 轻量级锁

JDK 1.6 引入了偏向锁和轻量级锁，从而让锁拥有了四个状态：无锁状态（unlocked）、偏向锁状态（biasble）、轻量级锁状态（lightweight locked）和重量级锁状态（inflated）。

以下是 HotSpot 虚拟机对象头的内存布局，这些数据被称为 Mark Word。其中 tag bits 对应了五个状态，这些状态在右侧的 state 表格中给出。除了 marked for gc 状态，其它四个状态已经在前面介绍过了。

<div align="center"> <img src="https://cs-notes-1256109796.cos.ap-guangzhou.myqcloud.com/bb6a49be-00f2-4f27-a0ce-4ed764bc605c.png" width="500"/> </div><br>

下图左侧是一个线程的虚拟机栈，其中有一部分称为 Lock Record 的区域，这是在轻量级锁运行过程创建的，用于存放锁对象的 Mark Word。而右侧就是一个锁对象，包含了 Mark Word 和其它信息。

<div align="center"> <img src="https://cs-notes-1256109796.cos.ap-guangzhou.myqcloud.com/051e436c-0e46-4c59-8f67-52d89d656182.png" width="500"/> </div><br>

轻量级锁是相对于传统的重量级锁而言，它使用 CAS 操作来避免重量级锁使用互斥量的开销。对于绝大部分的锁，在整个同步周期内都是不存在竞争的，因此也就不需要都使用互斥量进行同步，可以先采用 CAS 操作进行同步，如果 CAS 失败了再改用互斥量进行同步。

当尝试获取一个锁对象时，如果锁对象标记为 0 01，说明锁对象的锁未锁定（unlocked）状态。此时虚拟机在当前线程的虚拟机栈中创建 Lock Record，然后使用 CAS 操作将对象的 Mark Word 更新为 Lock Record 指针。如果 CAS 操作成功了，那么线程就获取了该对象上的锁，并且对象的 Mark Word 的锁标记变为 00，表示该对象处于轻量级锁状态。

<div align="center"> <img src="https://cs-notes-1256109796.cos.ap-guangzhou.myqcloud.com/baaa681f-7c52-4198-a5ae-303b9386cf47.png" width="400"/> </div><br>

如果 CAS 操作失败了，虚拟机首先会检查对象的 Mark Word 是否指向当前线程的虚拟机栈，如果是的话说明当前线程已经拥有了这个锁对象，那就可以直接进入同步块继续执行，否则说明这个锁对象已经被其他线程线程抢占了。如果有两条以上的线程争用同一个锁，那轻量级锁就不再有效，要膨胀为重量级锁。

### 偏向锁

偏向锁的思想是偏向于让第一个获取锁对象的线程，这个线程在之后获取该锁就不再需要进行同步操作，甚至连 CAS 操作也不再需要。

当锁对象第一次被线程获得的时候，进入偏向状态，标记为 1 01。同时使用 CAS 操作将线程 ID 记录到 Mark Word 中，如果 CAS 操作成功，这个线程以后每次进入这个锁相关的同步块就不需要再进行任何同步操作。

当有另外一个线程去尝试获取这个锁对象时，偏向状态就宣告结束，此时撤销偏向（Revoke Bias）后恢复到未锁定状态或者轻量级锁状态。

<div align="center"> <img src="https://cs-notes-1256109796.cos.ap-guangzhou.myqcloud.com/390c913b-5f31-444f-bbdb-2b88b688e7ce.jpg" width="600"/> </div><br>

## 十三、多线程开发良好的实践

- 给线程起个有意义的名字，这样可以方便找 Bug。

- 缩小同步范围，从而减少锁争用。例如对于 synchronized，应该尽量使用同步块而不是同步方法。

- 多用同步工具少用 wait() 和 notify()。首先，CountDownLatch, CyclicBarrier, Semaphore 和 Exchanger 这些同步类简化了编码操作，而用 wait() 和 notify() 很难实现复杂控制流；其次，这些同步类是由最好的企业编写和维护，在后续的 JDK 中还会不断优化和完善。

- 使用 BlockingQueue 实现生产者消费者问题。

- 多用并发集合少用同步集合，例如应该使用 ConcurrentHashMap 而不是 Hashtable。

- 使用本地变量和不可变类来保证线程安全。

- 使用线程池而不是直接创建线程，这是因为创建线程代价很高，线程池可以有效地利用有限的线程来启动任务。

## 参考资料

- BruceEckel. Java 编程思想: 第 4 版 [M]. 机械工业出版社, 2007.
- 周志明. 深入理解 Java 虚拟机 [M]. 机械工业出版社, 2011.
- [Threads and Locks](https://docs.oracle.com/javase/specs/jvms/se6/html/Threads.doc.html)
- [线程通信](http://ifeve.com/thread-signaling/#missed_signal)
- [Java 线程面试题 Top 50](http://www.importnew.com/12773.html)
- [BlockingQueue](http://tutorials.jenkov.com/java-util-concurrent/blockingqueue.html)
- [thread state java](https://stackoverflow.com/questions/11265289/thread-state-java)
- [CSC 456 Spring 2012/ch7 MN](http://wiki.expertiza.ncsu.edu/index.php/CSC_456_Spring_2012/ch7_MN)
- [Java - Understanding Happens-before relationship](https://www.logicbig.com/tutorials/core-java-tutorial/java-multi-threading/happens-before.html)
- [6장 Thread Synchronization](https://www.slideshare.net/novathinker/6-thread-synchronization)
- [How is Java's ThreadLocal implemented under the hood?](https://stackoverflow.com/questions/1202444/how-is-javas-threadlocal-implemented-under-the-hood/15653015)
- [Concurrent](https://sites.google.com/site/webdevelopart/21-compile/06-java/javase/concurrent?tmpl=%2Fsystem%2Fapp%2Ftemplates%2Fprint%2F&showPrintDialog=1)
- [JAVA FORK JOIN EXAMPLE](http://www.javacreed.com/java-fork-join-example/ "Java Fork Join Example")
- [聊聊并发（八）——Fork/Join 框架介绍](http://ifeve.com/talk-concurrency-forkjoin/)
- [Eliminating SynchronizationRelated Atomic Operations with Biased Locking and Bulk Rebiasing](http://www.oracle.com/technetwork/java/javase/tech/biasedlocking-oopsla2006-preso-150106.pdf)
- [聊聊 Java 的几把 JVM 级锁](https://mp.weixin.qq.com/s/h3VIUyH9L0v14MrQJiiDbw)

# 常见并发模型

## CSP

![CSP](https://res.cloudinary.com/practicaldev/image/fetch/s--J_DgxtEP--/c_limit%2Cf_auto%2Cfl_progressive%2Cq_auto%2Cw_800/https://raw.githubusercontent.com/karanpratapsingh/portfolio/master/public/static/blogs/csp-actor-model-concurrency/csp.png)

Communicating Sequential Processes (CSP) is a model put forth by Tony Hoare in 1978 which describes interactions between concurrent processes.
It made a breakthrough in Computer Science, especially in the field of concurrency.

In CSP we use "channels" for communication and synchronization. Although there is decoupling between the processes, they are still coupled to the channel.

It is fully synchronous, a channel writer must block until a channel reader reads. The advantage of that blocking based mechanism is that a channel only needs to ever hold one message. It's also in many ways easier to reason about.

CSP is implemented in languages like Go with goroutines and channels.

## Actor

![Actor](https://res.cloudinary.com/practicaldev/image/fetch/s--XVf_ETHg--/c_limit%2Cf_auto%2Cfl_progressive%2Cq_auto%2Cw_800/https://raw.githubusercontent.com/karanpratapsingh/portfolio/master/public/static/blogs/csp-actor-model-concurrency/actor.png)

Actor model was put forth by Carl Hewitt in 1973 and it adopts the philosophy that everything is an actor. This is similar to the everything is an object philosophy used by some object-oriented programming languages.

It is inherently asynchronous, a message sender will not block whether the reader is ready to pull from the mailbox or not, instead the message goes into a queue usually called a "mailbox". Which is convenient, but it's a bit harder to reason about and mailboxes potentially have to hold a lot of messages.

Each process has a single mailbox, messages are put into the receiver's mailbox by the sender, and fetched by the receiver.

Actor model is implemented in languages such as Erlang and Scala. In Java world, Akka is commonly used for this.

### Actor vs CSP

Some differences between the actor model and communicating sequential processes:

- Processes in CSP are anonymous, while actors have identities.
- CSP uses channels for message passing, whereas actors use mailboxes.
- Actor must only communicate through message delivery, hence making them stateless.
- CSP messages are delivered in the order they were sent.
- The actor model was designed for distributed programs, so it can scale across several machines.
- Actor model is more decoupled than CSP.

## BSP

![BSP](https://people.cs.rutgers.edu/~pxk/417/notes/images/bsp-500.png)

[Bulk Synchronous Parallel and Pregel](https://people.cs.rutgers.edu/~pxk/417/notes/pregel.html)

## 参考资料

- [CSP vs Actor model for concurrency](https://dev.to/karanpratapsingh/csp-vs-actor-model-for-concurrency-1cpg)
- [Bulk Synchronous Parallel and Pregel](https://people.cs.rutgers.edu/~pxk/417/notes/pregel.html)
- [Concurrency_(computer_science)#Models](https://en.wikipedia.org/wiki/Concurrency_(computer_science)#Models)


## 常见面试题

### 进程线程区别

线程是指进程内的一个执行单元,也是进程内的可调度实体。线程与进程的区别:
1) 地址空间:线程是进程内的一个执行单元，进程内至少有一个线程，它们共享进程的地址空间，而进程有自己独立的地址空间
2) 资源拥有:进程是资源分配和拥有的单位,同一个进程内的线程共享进程的资源
3) 线程是处理器调度的基本单位,但进程不是
4) 二者均可并发执行

5) 每个独立的线程有一个程序运行的入口、顺序执行序列和程序的出口，但是线程不能够独立执行，必须依存在应用程序中，由应用程序提供多个线程执行控制

### 什么是多线程并发和并行？

并发意味着应用程序有多个任务同时进行（并发）。如果计算机只有一个CPU，则应用程序无法同一时间在多个任务上取得进展 ，但是在应用程序内部有多个任务正在执行。在下一个任务开始之前，它并没有完全完成任务。
并行意味着应用程序将其任务分成较小的子任务，这些子任务可以并行处理，例如在同一时间在多个CPU上。

### 什么是线程安全问题？

临界资源访问。当有多个线程同时访问同一资源时，可能会出现不一致问题。例如最常见的i++，thread1与thread2同时执行，结果可能只加了一次。

### 什么是共享变量的内存可见性问题？

现代cpu一般有多个核心，同时每个核都会有一个自己的缓冲区，可以用来存储共享变量，当某一线程对共享变量更改时，如果不做相应的同步处理，那么更改结果只会储存在缓冲区，不会刷新到主内存，因此其它线程无法看到此次更改。

### 什么是Java中原子性操作？

CAS操作。多条指令一起完成，比如i++事实上是三条命令：iload,inc,istore，原子性可以保证这三条命令一起完成，就好像是执行一条命令一样。

### 什么是Java中的CAS操作,AtomicLong实现原理？

compare and swap。
Java8使用`Unsafe`类的原子性操作来实现

```java
public final long getAndIncrement() {
    return U.getAndAddLong(this, VALUE, 1L);
}

public final long getAndAddLong(Object o, long offset, long delta) {
    long v;
    do {
        v = getLongVolatile(o, offset);
    } while (!weakCompareAndSetLong(o, offset, v, v + delta));
    return v;
}
```

### 什么是Java指令重排序？

在执行程序时为了提高性能，编译器和处理器常常会对指令做重排序。重排序分三种类型：
1. 编译器优化的重排序。编译器在不改变单线程程序语义的前提下，可以重新安排语句的执行顺序。
2. 指令级并行的重排序。现代处理器采用了指令级并行技术（Instruction-Level Parallelism， ILP）来将多条指令重叠执行。如果不存在数据依赖性，处理器可以改变语句对应机器指令的执行顺序。
3. 内存系统的重排序。由于处理器使用缓存和读/写缓冲区，这使得加载和存储操作看上去可能是在乱序执行。

### Java中Synchronized关键字的内存语义是什么？

1. 线程解锁前，必须把共享变量的最新值刷到主内存
2. 线程加锁时，将清空工作内存中共享变量的值，从而使用共享变量时需要从主内存中重新读取最新的值

### Java中Volatile关键字的内存语义是什么？

1. 当写一个volatile变量时，JMM会把该线程对应的本地内存中的共享变量刷新到主内存。
2. 当读一个volatile变量时，JMM会把该线程对应的本地内存置为无效。线程接下来将从主内存中读取共享变量。

事实上Java5对volatile的加强不止上面所述：
1. 如果线程A写入volatile变量并且线程B随后读取这个volatile变量，则在写入volatile变量之前对线程A可见的所有变量在线程B读取volatile变量后也将对线程B可见。
2. 如果线程A读取volatile变量，则读取volatile变量时对线程A可见的所有变量也将从主存储器重新读取。

### 什么是伪共享,为何会出现，以及如何避免？

CPU缓存系统中是以缓存行（cache line）为单位存储的。目前主流的CPU Cache的Cache Line大小都是64/128 Bytes。在多线程情况下，如果需要修改“共享同一个缓存行的变量”，就会无意中影响彼此的性能，这就是伪共享（False Sharing）。

出现原因是因为现在的CPU架构，每个核心都有L1,L2,L3等缓存，当多个线程想要修改同一缓存行的变量时，就会对此缓存行进行竞争，同时还有可能多次进行缓存行写回主内存，从主内存读取最新数据到缓存行的操作，影响性能。

缓存行填充，填充一定量的Long变量，使其与真实变量位于同一行，以此占用整个缓存行，这样不同的变量就会处于不同的缓存行中。
Java8中也提供了官方的解决方案，Java8中新增了一个注解：`@sun.misc.Contended`。加上这个注解的类会自动补齐缓存行，需要注意的是此注解默认是无效的，需要在jvm启动时设置`-XX:-RestrictContended`才会生效。

### 什么是可重入锁、乐观锁、悲观锁、公平锁、非公平锁、独占锁、共享锁？

1. 可重入锁：当一个线程获取锁以后，可以再次获取这个锁
2. 乐观锁：顾名思义，就是很乐观，每次去拿数据的时候都认为别人不会修改，所以不会上锁，但是在更新的时候会判断一下在此期间别人有没有去更新这个数据，可以使用版本号等机制。乐观锁适用于多读的应用类型，这样可以提高吞吐量
3. 悲观锁：总是假设最坏的情况，每次去拿数据的时候都认为别人会修改，所以每次在拿数据的时候都会上锁，这样别人想拿这个数据就会阻塞直到它拿到锁。传统的关系型数据库里边就用到了很多这种锁机制，比如行锁，表锁等，读锁，写锁等，都是在做操作之前先上锁。
4. 公平锁：加锁前先查看是否有排队等待的线程，有的话优先处理排在前面的线程，先来先得
5. 非公平锁：线程加锁时直接尝试获取锁，获取不到就自动到队尾等待。
6. 独占锁：独占锁锁定的资源只允许进行锁定操作的程序使用，其它任何对它的操作均不会被接受。
7. 共享锁：共享锁锁定的资源可以被其它用户读取，但其它用户不能修改它。

### 讲讲ThreadLocal 的实现原理？

```java
public T get() {
    Thread t = Thread.currentThread();
    ThreadLocalMap map = getMap(t);
    if (map != null) {
        ThreadLocalMap.Entry e = map.getEntry(this);
        if (e != null) {
            @SuppressWarnings("unchecked")
            T result = (T)e.value;
            return result;
        }
    }
    return setInitialValue();
}
ThreadLocalMap getMap(Thread t) {
    return t.threadLocals;
}

void createMap(Thread t, T firstValue) {
    t.threadLocals = new ThreadLocalMap(this, firstValue);
}

private T setInitialValue() {
    T value = initialValue();
    Thread t = Thread.currentThread();
    ThreadLocalMap map = getMap(t);
    if (map != null)
        map.set(this, value);
    else
        createMap(t, value);
    return value;
}

static class ThreadLocalMap {

    /**
     * The entries in this hash map extend WeakReference, using
     * its main ref field as the key (which is always a
     * ThreadLocal object).  Note that null keys (i.e. entry.get()
     * == null) mean that the key is no longer referenced, so the
     * entry can be expunged from table.  Such entries are referred to
     * as "stale entries" in the code that follows.
     */
    static class Entry extends WeakReference<ThreadLocal<?>> {
        /** The value associated with this ThreadLocal. */
        Object value;

        Entry(ThreadLocal<?> k, Object v) {
            super(k);
            value = v;
        }
    }
```

### 说说InheritableThreadLocal 的实现原理？

```java
public class InheritableThreadLocal<T> extends ThreadLocal<T> {
    /**
     * Computes the child's initial value for this inheritable thread-local
     * variable as a function of the parent's value at the time the child
     * thread is created.  This method is called from within the parent
     * thread before the child is started.
     * <p>
     * This method merely returns its input argument, and should be overridden
     * if a different behavior is desired.
     *
     * @param parentValue the parent thread's value
     * @return the child thread's initial value
     */
    protected T childValue(T parentValue) {
        return parentValue;
    }

    /**
     * Get the map associated with a ThreadLocal.
     *
     * @param t the current thread
     */
    ThreadLocalMap getMap(Thread t) {
       return t.inheritableThreadLocals;
    }

    /**
     * Create the map associated with a ThreadLocal.
     *
     * @param t the current thread
     * @param firstValue value for the initial entry of the table.
     */
    void createMap(Thread t, T firstValue) {
        t.inheritableThreadLocals = new ThreadLocalMap(this, firstValue);
    }
}
```

在Thread类的初始化过程中：

```java
if (inheritThreadLocals && parent.inheritableThreadLocals != null)
    this.inheritableThreadLocals =
        ThreadLocal.createInheritedMap(parent.inheritableThreadLocals);
```

`parent.inheritableThreadLocals`的创建过程在`InheritableThreadLocal`类的`createMap`方法中。

### CyclicBarrier内部的实现与 CountDownLatch 有何不同？

CyclicBarrier在使用完以后可以再次使用，而CountDownLatch不可以。

### 随机数生成器 Random 类如何使用 CAS 算法保证多线程下新种子的唯一性？

Random类内部使用了AtomicLong保存种子，当多个线程尝试获取随机数时，轮流进行(cas)，使用上一次的旧种子来计算新种子，虽然产生新种子的算法是一样的，但也不会出现多个线程获得的随机数是一样的。
```java
protected int next(int bits) {
    long oldseed, nextseed;
    AtomicLong seed = this.seed;
    do {
        oldseed = seed.get();
        nextseed = (oldseed * multiplier + addend) & mask;
    } while (!seed.compareAndSet(oldseed, nextseed));
    return (int)(nextseed >>> (48 - bits));
}
```

### ThreadLocalRandom 是如何利用 ThreadLocal 的原理来解决 Random 的局限性？

ThreadLocalRandom类是JDK7在JUC包下新增的随机数生成器，它解决了Random类在多线程下多个线程竞争内部唯一的原子性种子变量而导致大量线程自旋重试的不足。
ThreadLocalRandom使用ThreadLocal的原理，让每个线程内持有一个本地的种子变量，该种子变量只有在使用随机数时候才会被初始化，多线程下计算新种子时候是根据自己线程内维护的种子变量进行更新，从而避免了竞争

### Spring 框架中如何使用 ThreadLocal 实现 request scope 作用域 Bean？
### 并发包中锁的实现底层（对AQS的理解）？

AQS内部维护一个节点列表，一个状态state。当线程尝试获取锁时，调用其try方法，如果成功则直接返回，失败则加入到链表中等待。在加入到链表的过程中，使用CAS继续尝试获取锁，如果尝试两次后依然失败，那么插入链表，直到前驱节点为头节点并且释放锁后，才会被唤醒。节点内部会保存一个线程引用，以便唤醒线程，同时节点还分为独占节点与共享节点，分别对应独占锁与共享锁的获取。当获取共享状态的时候，如果有其他线程在等待并且还有资源可以供其获取，那么便唤醒它，使其获取，如此逐个传递，直到没有共享状态再能被获取。

AQS还提供了Condition接口，用以模拟wait/notify机制，Condition内部也维护了一个同步队列，在该Condition上等待的线程被加入到其中。

### 讲讲独占锁 ReentrantLock 原理？

ReentrantLock内部使用AQS实现了公平锁以及非公平锁两个版本，同时还实现了可重入性，即当一个线程获取了锁之后，当它再次尝试获取这个锁的时候，直接返回成功，无需再经过AQS尝试获取，也不会在获取锁的时候因为锁已经被获取了而阻塞，只需在同步状态上增加1即可，当然释放锁的时候也需要多次释放。

### 谈谈读写锁 ReentrantReadWriteLock 原理？

读写锁内部将同步状态state分为两块，前16位作为写锁，后16位作为读锁，使用移位操作进行锁状态的检查，当有线程获取写锁，那么读锁将不能被获取，反之同理。当然读写锁也有公平与非公平两种版本，使用公平锁时需要先判断是否有其他线程在等待获取锁，而使用非公平锁则无需顾忌，同时为了不使写线程饥饿，当写线程位于同步队列的头部时，也将自己插入同步队列中，而不是获取读锁。读写锁还提供了锁降级的功能，当获取写锁后，获取写锁的线程可以直接获取读锁。

在Java6时，对读锁的获取进行了一定的改动，使用ThreadLocal来维护读线程重入的次数，其中使用了多个缓存来提高性能。

### StampedLock 锁原理的理解？

StampedLock是对读写锁的改进，增加了乐观读锁，并且它获取释放锁的方法与读写锁也不同。StampedLock只使用同步状态的后8位用作读锁，不过当获取读锁的线程数量超过2^7时，它还使用了一个变量储存溢出数，以此增加读锁获取的上限。当获取写锁后，乐观读锁以及悲观读锁都不能被获取，而悲观读锁被获取后，乐观读锁依然可以获取，乐观都铎被获取后，悲观读锁与写锁都能被获取，因为获取乐观读锁时不对同步状态进行改动。当然，使用乐观读锁时需要对数据进行验证，防止数据被获取后被写线程修改（乐观读锁被获取后写锁依然可以获取），出现脏读。
同时悲观读锁也进行了优化，当写锁被获取时，多个读线程会挂载在一个同步节点上，当读线程获取锁后，会对挂载线程进行唤醒，因此避免了AQS对共享节点的逐个判断以及释放，提升了性能，同时，当此时有线程获取锁，那么还会帮助头节点的读线程唤醒挂载线程，加快读线程的唤醒速度。
相比读写多，StampedLock还在获取锁的过程进行了优化，由于处于同步队列头部的节点获取锁的几率很大，因为头节点很有可能会释放锁，所以头部节点不会阻塞，而是一直自旋，这样可以更快的获取锁。

### 谈下对基于链表的非阻塞无界队列 ConcurrentLinkedQueue 原理的理解？

ConcurrentLinkedQueue内部维护了一个单向链表，当入队列时，并不会每次都更新尾节点，而是每插入两次才更新一次尾节点，出队列同理，这样可以大幅减少CAS设置头尾节点的时间，提升了性能。

### ConcurrentLinkedQueue 内部是如何使用 CAS 非阻塞算法来保证多线程下入队出队操作的线程安全？
同23

### 基于链表的阻塞队列 LinkedBlockingQueue 原理。

LinkedBlockingQueue基于链表结构，使用两个锁分别对插入和提取进行控制，同时链表的长度使用原子变量来保存，因此只获取一个锁依然可以正确的更新长度。
LinkedBlockingQueue在构造时可以指定一个长度，当队列为空时获取线程将会被阻塞，而队列已满时插入线程也会被阻塞，同时当相应条件发生时，它们会被唤醒。
LinkedBlockingQueue的迭代器与内部链表保持弱一致性，当链表节点被删除时，它不会被移除链表中，只会将保存的元素设为null，因此当迭代器访问到此节点时不会发生链表断裂的情况，同时迭代器会负责彻底删除此节点。

### 阻塞队列LinkedBlockingQueue 内部是如何使用两个独占锁 ReentrantLock 以及对应的条件变量保证多线程先入队出队操作的线程安全？
同25

### 分析下JUC 中倒数计数器 CountDownLatch 的使用与原理？

CountDownLatch基于AQS共享锁实现，在创建时指定一个数，此数也会作为同步状态state使用，表示拦截的线程数量。它的主要方法为countDown()和await()，调用await()的线程会进行等待，直到对应线程全部调用countDown()方法。当调用await()方法时，向AQS发送一个acquireShared的请求，而countDown()则发出releaseShared()，调用成功同步状态会减一，当同步状态减为0，则唤醒等待线程。

### CountDownLatch 与线程的 Join 方法区别是什么？

CountDownLatch提供了比join方法更强大的功能，join只能够无限期等待，而CountDownLatch增加了超时等待以及可中断等待，并且还提供了一个监视方法。同时join方法必须要求相应线程运行完，而CountDownLatch只需要到达某一个点即可。

### 讲讲对JUC 中回环屏障 CyclicBarrier 的使用？

CyclicBarrier与CountDownLatch提供的功能类似，都可以作为一个栅栏使用，不过CyclicBarrier可以多次复用，同时还可以在构造时提供一个Runnable，它会在所有等待线程之前运行，运行完成之后唤醒所有等待的线程。核心方法为await()，提供了可中断以及超时版本。
CyclicBarrier也是基于AQS共享锁实现的，当调用await方法时，对共享状态减1，然后在Condition上等待，直到所有线程都到达此点。

### Semaphore 的内部实现是怎样的？

Semaphore内部也是基于AQS共享锁实现的，提供了公平锁以及非公平锁两个版本。在构造时提供一个数值，作为同步状态，当调用acquire方法时，对同步状态减1，当同步状态减为0时，阻塞等待，而release方法则对同步状态加1，同时也会唤醒等待的线程。

### 并发组件CopyOnWriteArrayList 是如何通过写时拷贝实现并发安全的 List？

CopyOnWriteArrayList在修改时会加锁，保证一次只能有一个线程修改数组，当增加或修改元素时，会先获取一份数组的副本，对此副本进行修改，因此不会影响其他线程的读取，当修改完成后，让新数组替换原数组，实现了写时拷贝。
