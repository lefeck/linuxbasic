# 平均负载
&emsp;&emsp;
当系统响应变慢时，一般使用top或者uptime来查看系统负载情况。运行uptime命令的输出信息如下：

```
$ uptime 
 23:12:21 up 42 min,  3:25,  1 user,  load average: 0.00, 0.03, 0.05
其中 23:12:21 为当前系统时间
up 42 min：为系统已经运行的时间
1 users：当前登录的用户数
load average：则是过去 1 分钟、5 分钟、15 分钟的平均负载。
```


平均负载是单位时间内系统处于**可运行状态和不可中断状态**的平均进程数，也就是**平均活跃的进程数**。

* 可运行状态是指正在使用cpu或者正在等待cpu的进程。也就是使用ps命令看到的处于R状态的进程。

* 不可中断状态的进程则是处于内核态关键流程中的进程，且这些进程是不可以被打断的，比如常见的等待硬件设备的IO响应。也就是使用ps命令处于D状态的进程。不可中断状态是系统对进程和硬件设备的一种保护机制。

比如，当一个进程向磁盘读写数据时，为了保证数据的一致性，在得到磁盘回复前，它是不能被其他进程或者中断打断的，这个时候的进程就处于不可中断状态。如果此时的进程被打断了，就容易出现磁盘数据与进程数据不一致的问题。



所以，不可中断状态实际上是系统对进程和硬件设备的一种保护机制。



因此，你可以简单理解为，平均负载其实就是平均活跃进程数。平均活跃进程数，直观上的理解就是单位时间内的活跃进程数，但它实际上是活跃进程数的指数衰减平均值。这个“指数衰减平均”的详细含义你不用计较，这只是系统的一种更快速的计算方式，你把它直接当成活跃进程数的平均值也没问题。



平均活跃进程数最理想的状态就是每个CPU上刚好运行一个进程，这样每个CPU都得到了充分的利用，也就是说平局负载刚好等于系统CPU的个数。
如果平均负载为2意味着什么呢？

- 也就是单位时间平均活跃进程数为2.那么对于只有2个CPU的系统来说，CPU刚好被得到了充分的利用。
- 而在有4个CPU的系统上，有50%的CPU会处于空闲状态。
- 而在只有一个CPU的系统上 则进程需要竞争CPU才能被运行会有50%的进程因为竞争不到CPU而处于等待状态。

如何查看系统有几个CPU：
￼
上面的命令显示 系统cpu数目为2



### 平均负载多少合理

理想情况，一个cpu一个进程最合理，也就是4核cpu，平均负载为4的时候最合理。但是，**通常我们会认为平均负载到了70%的时候，就应该观察了。**如果4核cpu，那么就是2.8的时候。
查看cpu核数：

> grep 'model name' /proc/cpuinfo | wc -l

cpu使用率与cpu平均负载有什么关系呢，真相是没有必然联系。如果是cpu密集型工作，那两者是一致的。如果是io密集型工作，那cpu使用率可能比较低，但是平均负载比较高。



### 平均负载与CPU使用率

在工作中，我们经常容易把平均负载和 CPU 使用率混淆，进行一个区分。

可能你也会有这样的疑惑，既然平均负载代表的是活跃进程数，那平均负载高了，是不是也就意味着 CPU 使用率高？

**平均负载是指单位时间内，处于可运行状态和不可中断状态的进程数。**所以，它不仅包括了正在使用 CPU 的进程，还包括等待 CPU 和等待 I/O 的进程。

**而 CPU 使用率，是单位时间内 CPU 繁忙情况的统计，跟平均负载并不一定完全对应。**比如：

- CPU 密集型进程，使用大量 CPU 会导致平均负载升高，此时这两者是一致的；

- I/O 密集型进程，等待 I/O 也会导致平均负载升高，但 CPU 使用率不一定很高；

大量等待 CPU 的进程调度也会导致平均负载升高，此时的 CPU 使用率也会比较高。

## 案例:
```
apt-get  -y install stress sysstat
```
### 预先安装包
- stress 是一个 Linux 系统压力测试工具，这里我们用作异常进程模拟平均负载升高的场景。
- sysstat 包含了常用的 Linux 性能工具，用来监控和分析系统的性能。我们的案例会用到这个包的两个命令 mpstat 和 pidstat
    1. mpstat 是一个常用的多核 CPU 性能分析工具，用来实时查看每个 CPU 的性能指标，以及所有 CPU 的平均指标。
    2. pidstat 是一个常用的进程性能分析工具，用来实时查看进程的 CPU、内存、I/O 以及上下文切换等性能指标。

- 注意:  
      下面的所有命令，默认以普通用户运行。所以，如果遇到权限不够时，一定要运行 sudo su root 命令切换到 root 用户。


### 场景一：CPU 密集型进程
在第一个终端运行 stress 命令，模拟一个 CPU 使用率 100% 的场景

```
$ stress --cpu 1 --timeout 600 #这个命令是模拟cpu使用率是100%的情景
```
![img](http://5b0988e595225.cdn.sohucs.com/images/20190215/7d9caf63b3b1436cb676ecf3e00fa996.png)

在第二个终端运行 uptime 查看平均负载的变化情况：
```
$ watch -d uptime  # watch -d 是高亮显示
```
![img](http://5b0988e595225.cdn.sohucs.com/images/20190215/cb690e8482d04d86becceec7c518fe56.png)

可以看到这三个值，比没有执行stress前要高多了

在第三个终端运行 mpstat 查看 CPU 使用率的变化情况：
```
$ mpstat -P ALL 5 # ALL表示监控所有cpu，5表示每隔5秒输出一组数据
```

![img](http://5b0988e595225.cdn.sohucs.com/images/20190215/df59f4bccbd2402fbf166fd7a08faa2a.jpeg)
￼
- 结果:

```
在上图可以看出有一个 CPU 的使用率为 100%，但它的iowait只有0，说明平均负载的升高是由于cpu使用率达到100%的。
```

那么我们要是想看是哪个进程导致的cpu使用率达到100%应该怎么办呢？
就需要执行

```
$ pidstat -u 5 1 # 5 1表示每隔5秒输出1组数据
```
![img](http://5b0988e595225.cdn.sohucs.com/images/20190215/3ed788c3de1d4b9cb511451c38666231.jpeg)

从这里可以明显看到，stress 进程的 CPU 使用率为 99.60%，接近100%。
￼
### 场景二：I/O 密集型进程
首先还是运行 stress 命令，但这次模拟 I/O 压力，即不停地执行 sync：
在终端1执行
```
$ stress -i 1 --timeout 600
```
![img](http://5b0988e595225.cdn.sohucs.com/images/20190215/e1ed1cefe6d54f099ce6efd240a918aa.png)

模拟io密集型
在终端2执行uptime，同样可以看到平均负载值在不断升高
```
￼$ watch -d uptime
```
![img](http://5b0988e595225.cdn.sohucs.com/images/20190215/1af7d504ac274974963f80fa5dbb75e8.png)

在终端3运行 mpstat 查看 CPU 使用率的变化情况：

```
$ mpstat -P ALL 51 # 显示所有 CPU 的指标，并在间隔 5 秒输出一组数据
```
![img](http://5b0988e595225.cdn.sohucs.com/images/20190215/8b7982f950464f7f97339fb644bbbf8d.jpeg)

然后继续执行pidstat -u 5 1可以看到还是stress的wait列数值高
￼
### 场景三：大量进程的场景
当系统中运行进程超出 CPU 运行能力时，就会出现等待 CPU 的进程。我们还是使用 stress，但这次模拟的是 8 个进程：

在第一个终端执行
```
$ stress --cpu 8 --timeout 600
```
![img](http://5b0988e595225.cdn.sohucs.com/images/20190215/25fa0cc65e5a49239ca4cc981f77fc2a.png)

由于系统只有 2 个 CPU，明显比 8 个进程要少得多，因而，系统的 CPU 处于严重过载状态，平均负载高达 7.76：
继续在第二个终端执行
```
$ watch -d uptime
```
![img](http://5b0988e595225.cdn.sohucs.com/images/20190215/547c2ef625d3481190f733402cd7631a.png)

再运行 pidstat 来看一下进程的情况
```
$ pidstat -u 5 1
```
![img](http://5b0988e595225.cdn.sohucs.com/images/20190215/2acd7f9f2b9b471292234f452fe61dcb.jpeg)

可以看出，8 个进程在争抢 2 个 CPU，每个进程等待 CPU 的时间（也就是代码块中的 %wait 列）高达 76%左右。这些超出 CPU 计算能力的进程，最终导致 CPU 过载。

## 总结:
&emsp;&emsp;
平均负载提供了一个快速查看系统整体性能的手段，反映了整体的负载情况。但只看平均
负载本身，我们并不能直接发现，到底是哪里出现了瓶颈。所以，在理解平均负载时，也要注意：
   - 平均负载高有可能是 CPU 密集型进程导致的；
   - 平均负载高并不一定代表 CPU 使用率高，还有可能是 I/O 更繁忙了；
   - 当发现负载高的时候，你可以使用 mpstat、pidstat 等工具，辅助分析负载的来源。





# CPU 上下文切换（上）



## CPU 寄存器和程序计数器

Linux 是一个多任务操作系统，它支持远大于 CPU 数量的任务同时运行。因为系统在很短的时间内，将 CPU 轮流分配给各个任务，造成多任务同时运行的错觉。

而在每个任务运行前，CPU 都需要知道任务从哪里加载、又从哪里开始运行，也就是说，需要系统事先帮它设置好 **CPU 寄存器和程序计数器** （Program Counter, PC）。

> CPU 寄存器，是CPU内置的容量小、但速度极快的内存。
>
> 程序计数器，是用来存储 CPU 正在执行的指令位置、或者即将执行的下一条指令位置。
>
> 它们都是 CPU 在运行任何任务前，必须的依赖环境，因此也被叫做 CPU 上下文。

![分享图片](https://static001.geekbang.org/resource/image/98/5f/98ac9df2593a193d6a7f1767cd68eb5f.png)



## CPU 上下文切换

CPU 上下文切换，就是先把前一个任务的 CPU 上下文（也就是 CPU 寄存器和程序计数器）保存起来，然后加载新任务的上下文到这些寄存器和程序计数器，最后再跳转到程序计数器所指的新位置，运行新任务。

而这些保存下来的上下文，会存储在系统内核中，并在任务重新调度执行时再次加载进来。这样就能保证任务原来的状态不受影响，让任务看起来还是连续运行。

**根据任务的不同**，CPU 的上下文切换就可以分为几个不同的场景，也就是**进程上下文切换、线程上下文切换以及中断上下文切换**。



### 进程上下文切换

Linux 按照特权等级，把进程的运行空间分为内核空间和用户空间，分别对应着下图中 CPU 特权等级的 Ring0 和 Ring3。

- 内核空间(Ring 0) 具有最高权限，可以直接访问所有资源。
- 用户空间(Ring 3) 只能访问受限资源，不能直接访问内存等硬件设备，必须通过系统调用陷入到内核中，才能访问这些特权资源。

![分享图片](https://static001.geekbang.org/resource/image/4d/a7/4d3f622f272c49132ecb9760310ce1a7.png)

换句话说，进程即可以在用户空间运行，又可以在内核空间中运行。进程在用户空间运行时，被称为**进程的用户态**，而陷入内核空间的时候，被称为**进程的内核态**。

从用户态到内核态的转变，需要通过**系统调用**来完成。

> 比如，当我们查看文件内容时，就需要多次系统调用来完成：首先调用 open() 打开文件，然后调用 read() 读取文件内容，并调用 write() 将内容写到标准输出，最后再调用 close() 关闭文件。

系统调用的过程中会发生 CPU 上下文的切换。

> CPU 寄存器里原来用户态的指令位置，需要先保存起来。
>
> 接着，为了执行内核态代码，CPU 寄存器需要更新为内核态指令的新位置。
>
> 最后才是跳转到内核态运行内核任务。
>
> 而系统调用结束后，CPU 寄存器需要恢复原来保存的用户态，然后再切换到用户空间，继续运行进程。
>
> **所以，一次系统调用的过程，其实是发生了两次 CPU 上下文切换。**

不过，需要注意的是，系统调用过程中，并不会涉及到虚拟内存等进程用户态的资源，也不会切换进程。

这跟我们通常所说的进程上下文切换是不一样的：

- 进程上下文切换，是指从一个进程切换到另一个进程运行。
- 而系统调用过程中一直是同一个进程在运行。

所以，**系统调用过程通常称为特权模式切换，而不是上下文切换**。但实际上，系统调用过程中，CPU 的上下文切换还是无法避免的。

那么进程在什么时候才会被调度到 CPU 上运行呢？

最容易想到的一个时机，就是进程执行完终止了，它之前使用的 CPU 会释放出来，这个时候再从就绪队列里，拿一个新的进程过来运行。其实还有很多其他场景，也会触发进程调度，在这里我给你逐个梳理下。

- 其一，为了保证所有进程可以得到公平调度，CPU 时间被划分为一段段的时间片，这些时间片再被轮流分配给各个进程。这样，当某个进程的时间片耗尽了，就会被系统挂起，切换到其它正在等待 CPU 的进程运行。
- 其二，进程在系统资源不足（比如内存不足）时，要等到资源满足后才可以运行，这个时候进程也会被挂起，并由系统调度其他进程运行。
- 其三，当进程通过睡眠函数 sleep 这样的方法将自己主动挂起时，自然也会重新调度。
- 其四，当有优先级更高的进程运行时，为了保证高优先级进程的运行，当前进程会被挂起，由高优先级进程来运行。
- 最后一个，发生硬件中断时，CPU 上的进程会被中断挂起，转而执行内核中的中断服务程序。

了解这几个场景是非常有必要的，因为一旦出现上下文切换的性能问题，它们就是幕后凶手。



### 线程上下文切换

线程与进程最大的区别在于，**线程是调度的基本单位，而进程则是资源拥有的基本单位**。

所谓内核中的任务调度，实际上的调度对象是线程；而进程只是给线程提供了虚拟内存、全局变量等资源。所以，对于线程和进程，我们可以这么理解：

- 当进程只有一个线程时，可以认为进程就等于线程。
- 当进程拥有多个线程时，这些线程会共享相同的虚拟内存和全局变量等资源。这些资源在上下文切换时是不需要修改的。
- 另外，线程也有自己的私有数据，比如栈和寄存器等，这些在上下文切换时也是需要保存的。

线程的上下文切换其实就可以分为两种情况：

- 第一种， 前后两个线程属于不同进程。此时，因为资源不共享，所以切换过程就跟进程上下文切换是一样。
- 第二种，前后两个线程属于同一个进程。此时，因为虚拟内存是共享的，所以在切换时，虚拟内存这些资源就保持不动，只需要切换线程的私有数据、寄存器等不共享的数据。

虽然同为上下文切换，但同进程内的线程切换，要比多进程间的切换消耗更少的资源，而这，也正是多线程代替多进程的一个优势。



### 中断上下文切换

为了快速响应硬件的事件，**中断处理会打断进程的正常调度和执行**，转而调用中断处理程序，响应设备事件。而在打断其他进程时，就需要将进程当前的状态保存下来，这样在中断结束后，进程仍然可以从原来的状态恢复运行。

**对同一个 CPU 来说，中断处理比进程拥有更高的优先级**，所以中断上下文切换并不会与进程上下文切换同时发生。

另外，跟进程上下文切换一样，中断上下文切换也需要消耗 CPU，切换次数过多也会耗费大量的 CPU，甚至严重降低系统的整体性能。所以，当你发现中断次数过多时，就需要注意去排查它是否会给你的系统带来严重的性能问题。



## 小结

不管是哪种场景导致的上下文切换

- CPU 上下文切换，是保证 Linux 系统正常工作的核心功能之一，一般情况下不需要我们特别关注。
- 但过多的上下文切换，会把 CPU 时间消耗在寄存器、内核栈以及虚拟内存等数据的保存和恢复上，从而缩短进程真正运行的时间，导致系统的整体性能大幅下降。



# CPU 上下文切换（下）

上一节，我给你讲了 CPU 上下文切换的工作原理。简单回顾一下，CPU 上下文切换是保证 Linux 系统正常工作的一个核心功能，按照不同场景，可以分为进程上下文切换、线程上下文切换和中断上下文切换。具体的概念和区别，你也要在脑海中过一遍，忘了的话及时查看上一篇。

今天我们就接着来看，究竟怎么分析 CPU 上下文切换的问题。



## 查看系统的上下文切换

通过前面学习我们知道，过多的上下文切换，会把 CPU 时间消耗在寄存器、内核栈以及虚拟内存等数据的保存和恢复上，缩短进程真正运行的时间，成了系统性能大幅下降的一个元凶。

既然上下文切换对系统性能影响那么大，你肯定迫不及待想知道，到底要怎么查看上下文切换呢？在这里，我们可以使用 vmstat 这个工具，来查询系统的上下文切换情况。

vmstat 是一个常用的系统性能分析工具，主要用来分析系统的内存使用情况，也常用来分析 CPU 上下文切换和中断的次数。

比如，下面就是一个 vmstat 的使用示例：

```
# 每隔 5 秒输出 1 组数据
$ vmstat 5
procs -----------memory---------- ---swap-- -----io---- -system-- ------cpu-----
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
 0  0      0 7005360  91564 818900    0    0     0     0   25   33  0  0 100  0  0
```

我们一起来看这个结果，你可以先试着自己解读每列的含义。在这里，我重点强调下，需要特别关注的四列内容：

- cs（context switch）是每秒上下文切换的次数。
- in（interrupt）则是每秒中断的次数。
- r（Running or Runnable）是就绪队列的长度，也就是正在运行和等待 CPU 的进程数。
- b（Blocked）则是处于不可中断睡眠状态的进程数。

可以看到，这个例子中的上下文切换次数 cs 是 33 次，而系统中断次数 in 则是 25 次，而就绪队列长度 r 和不可中断状态进程数 b 都是 0。

vmstat 只给出了系统总体的上下文切换情况，要想查看每个进程的详细情况，就需要使用我们前面提到过的 pidstat 了。给它加上 -w 选项，你就可以查看每个进程上下文切换的情况了。

比如说：

```
# 每隔 5 秒输出 1 组数据
$ pidstat -w 5
Linux 4.15.0 (ubuntu)  09/23/18  _x86_64_  (2 CPU)

08:18:26      UID       PID   cswch/s nvcswch/s  Command
08:18:31        0         1      0.20      0.00  systemd
08:18:31        0         8      5.40      0.00  rcu_sched
...
```

这个结果中有两列内容是我们的重点关注对象。一个是 cswch ，表示每秒自愿上下文切换（voluntary context switches）的次数，另一个则是 nvcswch ，表示每秒非自愿上下文切换（non voluntary context switches）的次数。

这两个概念你一定要牢牢记住，因为它们意味着不同的性能问题：

- 所谓**自愿上下文切换，是指进程无法获取所需资源，导致的上下文切换**。比如说， I/O、内存等系统资源不足时，就会发生自愿上下文切换。
- 而**非自愿上下文切换，则是指进程由于时间片已到等原因，被系统强制调度，进而发生的上下文切换**。比如说，大量进程都在争抢 CPU 时，就容易发生非自愿上下文切换。



## 案例分析

知道了怎么查看这些指标，另一个问题又来了，上下文切换频率是多少次才算正常呢？别急着要答案，同样的，我们先来看一个上下文切换的案例。通过案例实战演练，你自己就可以分析并找出这个标准了。

### 你的准备

今天的案例，我们将使用 sysbench 来模拟系统多线程调度切换的情况。

sysbench 是一个多线程的基准测试工具，一般用来评估不同系统参数下的数据库负载情况。当然，在这次案例中，我们只把它当成一个异常进程来看，作用是模拟上下文切换过多的问题。

下面的案例基于 Ubuntu 18.04，当然，其他的 Linux 系统同样适用。我使用的案例环境如下所示：

- 机器配置：2 CPU，8GB 内存
- 预先安装 sysbench 和 sysstat 包，如 apt install sysbench sysstat

正式操作开始前，你需要打开三个终端，登录到同一台 Linux 机器中，并安装好上面提到的两个软件包。包的安装，可以先 Google 一下自行解决，如果仍然有问题的，在留言区写下你的情况。

另外注意，下面所有命令，都**默认以 root 用户运行**。所以，如果你是用普通用户登陆的系统，记住先运行 sudo su root 命令切换到 root 用户。

安装完成后，你可以先用 vmstat 看一下空闲系统的上下文切换次数：

```
# 间隔 1 秒后输出 1 组数据
$ vmstat 1 1
procs -----------memory---------- ---swap-- -----io---- -system-- ------cpu-----
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
 0  0      0 6984064  92668 830896    0    0     2    19   19   35  1  0 99  0  0
```

这里你可以看到，现在的上下文切换次数 cs 是 35，而中断次数 in 是 19，r 和 b 都是 0。因为这会儿我并没有运行其他任务，所以它们就是空闲系统的上下文切换次数。

### 操作和分析

接下来，我们正式进入实战操作。

首先，在第一个终端里运行 sysbench ，模拟系统多线程调度的瓶颈：

```
# 以 10 个线程运行 5 分钟的基准测试，模拟多线程切换的问题
$ sysbench --threads=10 --max-time=300 threads run
```

接着，在第二个终端运行 vmstat ，观察上下文切换情况：

```
# 每隔 1 秒输出 1 组数据（需要 Ctrl+C 才结束）
$ vmstat 1
procs -----------memory---------- ---swap-- -----io---- -system-- ------cpu-----
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
 6  0      0 6487428 118240 1292772    0    0     0     0 9019 1398830 16 84  0  0  0
 8  0      0 6487428 118240 1292772    0    0     0     0 10191 1392312 16 84  0  0  0
```

你应该可以发现，cs 列的上下文切换次数从之前的 35 骤然上升到了 139 万。同时，注意观察其他几个指标：

- r 列：就绪队列的长度已经到了 8，远远超过了系统 CPU 的个数 2，所以肯定会有大量的 CPU 竞争。
- us（user）和 sy（system）列：这两列的 CPU 使用率加起来上升到了 100%，其中系统 CPU 使用率，也就是 sy 列高达 84%，说明 CPU 主要是被内核占用了。
- in 列：中断次数也上升到了 1 万左右，说明中断处理也是个潜在的问题。

综合这几个指标，我们可以知道，系统的就绪队列过长，也就是正在运行和等待 CPU 的进程数过多，导致了大量的上下文切换，而上下文切换又导致了系统 CPU 的占用率升高。

那么到底是什么进程导致了这些问题呢？

我们继续分析，在第三个终端再用 pidstat 来看一下， CPU 和进程上下文切换的情况：

```
# 每隔 1 秒输出 1 组数据（需要 Ctrl+C 才结束）
# -w 参数表示输出进程切换指标，而 -u 参数则表示输出 CPU 使用指标
$ pidstat -w -u 1
08:06:33      UID       PID    %usr %system  %guest   %wait    %CPU   CPU  Command
08:06:34        0     10488   30.00  100.00    0.00    0.00  100.00     0  sysbench
08:06:34        0     26326    0.00    1.00    0.00    0.00    1.00     0  kworker/u4:2

08:06:33      UID       PID   cswch/s nvcswch/s  Command
08:06:34        0         8     11.00      0.00  rcu_sched
08:06:34        0        16      1.00      0.00  ksoftirqd/1
08:06:34        0       471      1.00      0.00  hv_balloon
08:06:34        0      1230      1.00      0.00  iscsid
08:06:34        0      4089      1.00      0.00  kworker/1:5
08:06:34        0      4333      1.00      0.00  kworker/0:3
08:06:34        0     10499      1.00    224.00  pidstat
08:06:34        0     26326    236.00      0.00  kworker/u4:2
08:06:34     1000     26784    223.00      0.00  sshd
```

从 pidstat 的输出你可以发现，CPU 使用率的升高果然是 sysbench 导致的，它的 CPU 使用率已经达到了 100%。但上下文切换则是来自其他进程，包括非自愿上下文切换频率最高的 pidstat ，以及自愿上下文切换频率最高的内核线程 kworker 和 sshd。

不过，细心的你肯定也发现了一个怪异的事儿：pidstat 输出的上下文切换次数，加起来也就几百，比 vmstat 的 139 万明显小了太多。这是怎么回事呢？难道是工具本身出了错吗？

别着急，在怀疑工具之前，我们再来回想一下，前面讲到的几种上下文切换场景。其中有一点提到， Linux 调度的基本单位实际上是线程，而我们的场景 sysbench 模拟的也是线程的调度问题，那么，是不是 pidstat 忽略了线程的数据呢？

通过运行 man pidstat ，你会发现，pidstat 默认显示进程的指标数据，加上 -t 参数后，才会输出线程的指标。

所以，我们可以在第三个终端里， Ctrl+C 停止刚才的 pidstat 命令，再加上 -t 参数，重试一下看看：

```
# 每隔 1 秒输出一组数据（需要 Ctrl+C 才结束）
# -wt 参数表示输出线程的上下文切换指标
$ pidstat -wt 1
08:14:05      UID      TGID       TID   cswch/s nvcswch/s  Command
...
08:14:05        0     10551         -      6.00      0.00  sysbench
08:14:05        0         -     10551      6.00      0.00  |__sysbench
08:14:05        0         -     10552  18911.00 103740.00  |__sysbench
08:14:05        0         -     10553  18915.00 100955.00  |__sysbench
08:14:05        0         -     10554  18827.00 103954.00  |__sysbench
...
```

现在你就能看到了，虽然 sysbench 进程（也就是主线程）的上下文切换次数看起来并不多，但它的子线程的上下文切换次数却有很多。看来，上下文切换罪魁祸首，还是过多的 sysbench 线程。

我们已经找到了上下文切换次数增多的根源，那是不是到这儿就可以结束了呢？

当然不是。不知道你还记不记得，前面在观察系统指标时，除了上下文切换频率骤然升高，还有一个指标也有很大的变化。是的，正是中断次数。中断次数也上升到了 1 万，但到底是什么类型的中断上升了，现在还不清楚。我们接下来继续抽丝剥茧找源头。

既然是中断，我们都知道，它只发生在内核态，而 pidstat 只是一个进程的性能分析工具，并不提供任何关于中断的详细信息，怎样才能知道中断发生的类型呢？

没错，那就是从 /proc/interrupts 这个只读文件中读取。/proc 实际上是 Linux 的一个虚拟文件系统，用于内核空间与用户空间之间的通信。/proc/interrupts 就是这种通信机制的一部分，提供了一个只读的中断使用情况。

我们还是在第三个终端里， Ctrl+C 停止刚才的 pidstat 命令，然后运行下面的命令，观察中断的变化情况：

```
# -d 参数表示高亮显示变化的区域
$ watch -d cat /proc/interrupts
           CPU0       CPU1
...
RES:    2450431    5279697   Rescheduling interrupts
...
```

观察一段时间，你可以发现，变化速度最快的是**重调度中断**（RES），这个中断类型表示，唤醒空闲状态的 CPU 来调度新的任务运行。这是多处理器系统（SMP）中，调度器用来分散任务到不同 CPU 的机制，通常也被称为**处理器间中断**（Inter-Processor Interrupts，IPI）。

所以，这里的中断升高还是因为过多任务的调度问题，跟前面上下文切换次数的分析结果是一致的。

通过这个案例，你应该也发现了多工具、多方面指标对比观测的好处。如果最开始时，我们只用了 pidstat 观测，这些很严重的上下文切换线程，压根儿就发现不了了。

现在再回到最初的问题，每秒上下文切换多少次才算正常呢？

**这个数值其实取决于系统本身的 CPU 性能**。在我看来，如果系统的上下文切换次数比较稳定，那么从数百到一万以内，都应该算是正常的。但当上下文切换次数超过一万次，或者切换次数出现数量级的增长时，就很可能已经出现了性能问题。

这时，你还需要根据上下文切换的类型，再做具体分析。比方说：

- 自愿上下文切换变多了，说明进程都在等待资源，有可能发生了 I/O 等其他问题；
- 非自愿上下文切换变多了，说明进程都在被强制调度，也就是都在争抢 CPU，说明 CPU 的确成了瓶颈；
- 中断次数变多了，说明 CPU 被中断处理程序占用，还需要通过查看 /proc/interrupts 文件来分析具体的中断类型。

## 小结

今天，我通过一个 sysbench 的案例，给你讲了上下文切换问题的分析思路。碰到上下文切换次数过多的问题时，**我们可以借助 vmstat 、 pidstat 和 /proc/interrupts 等工具**，来辅助排查性能问题的根源。



# CPU 使用率高 (上)

&emsp;&emsp;
       你最常用什么指标来描述系统的 CPU性能呢？我想你的答案，可能不是平均负载，也不是 CPU 上下文切换，而是另一个更直观的指标—— CPU 使用率。CPU 使用率是单位时间内 CPU 使用情况的统计，以百分比的方式展示。那么，作为最常用也是最熟悉的 CPU 指标，你能说出 CPU 使用率到底是怎么算出来的吗？再有，诸如 top、ps 之类的性能工具展示的 %user、%nice、 %system、%iowait、%steal 等等，你又能弄清楚它们之间的不同吗？



### CPU 使用率

&emsp;&emsp;
        Linux 作为一个多任务操作系统，将每个 CPU 的时间划分为很短的时间片，再通过调度器轮流分配给各个任务使用，因此造成多任务同时运行的错觉。为了维护CPU时间，Linux通过事先定义的节拍率（内核中表示为 HZ），触发时间中断，并使用全局变量 Jiffies 记录了开机以来的节拍数。每发生一次时间中断，Jiffies 的值就加 1。节拍率 HZ 是内核的可配选项，可以设置为 100、250、1000 等。不同的系统可能设置不同数值，你可以通过查询 /boot/config 内核选项来查看它的配置值。比如在我的系统中，节拍率设置成了 250，也就是每秒钟触发 250 次时间中断。

```
$ grep 'CONFIG_HZ=' /boot/config-$(uname -r)
CONFIG_HZ=1000
```

&emsp;&emsp;
       同时，正因为节拍率 HZ 是内核选项，所以用户空间程序并不能直接访问。为了方便用户空间程序，内核还提供了一个用户空间节拍率 USER_HZ，它总是固定为 100，也就是1/100 秒。这样，用户空间程序并不需要关心内核中 HZ 被设置成了多少，因为它看到的总是固定值 USER_HZ。  
&emsp;&emsp;
        Linux 通过 /proc 虚拟文件系统，向用户空间提供了系统内部状态的信息，而 /proc/stat 提供的就是系统的 CPU 和任务统计信息。比方说，如果你只关注 CPU 的话，可以执行下面的命令：

```
$ cat /proc/stat |grep ^cpu
 cpu  1360 5 15836 5940988 4567 0 101 0 0 0
 cpu0 743 1 7794 2970951 2458 0 42 0 0 0
 cpu1 616 4 8041 2970037 2109 0 58 0 0 0
```

&emsp;&emsp;
这里的输出结果是一个表格。其中，第一列表示的是 CPU 编号，如 cpu0、cpu1 ，而第一行没有编号的 cpu ，表示的是所有 CPU 的累加。其他列则表示不同场景下 CPU 的累加节拍数，它的单位是 USER_HZ，也就是 10 ms（1/100 秒），所以这其实就是不同场景下的 CPU 时间。当然，这里每一列的顺序并不需要你背下来。你只要记住，有需要的时候，查询  man proc 就可以。不过，你要清楚 man proc 文档里每一列的涵义，它们都是 CPU 使用率相关的重要指标，你还会在很多其他的性能工具中看到它们。

**参数解释:**

- user（通常缩写为 us），代表用户态 CPU 时间。注意，它不包括下面的 nice 时间，但包括了 guest 时间。
- nice（通常缩写为 ni），代表低优先级用户态 CPU 时间，也就是进程的 nice 值被调整为 1-19 之间时的 CPU 时间。这里注意，nice 可取值范围是 -20 到 19，数值越大，优先级反而越低。
- system（通常缩写为 sys），代表内核态 CPU 时间。
- idle（通常缩写为 id），代表空闲时间。注意，它不包括等待 I/O 的时间（iowait）。iowait（通常缩写为 wa），代表等待 I/O 的 CPU 时间。
- irq（通常缩写为 hi），代表处理硬中断的 CPU 时间。softirq（通常缩写为 si），代表处理软中断的 CPU 时间。
- steal（通常缩写为 st），代表当系统运行在虚拟机中的时候，被其他虚拟机占用的CPU 时间。
- guest（通常缩写为 guest），代表通过虚拟化运行其他操作系统的时间，也就是运行虚拟机的 CPU 时间。
- guest_nice（通常缩写为 gnice），代表以低优先级运行虚拟机的时间。


而我们通常所说的**CPU 使用率，就是除了空闲时间外的其他时间占总 CPU 时间的百分比，**用公式来表示就是：

<div align=center>
<img src="https://img2018.cnblogs.com/blog/1250063/201907/1250063-20190713145258364-368453120.png">
</div>

&emsp;&emsp;
    根据这个公式，我们就可以从 /proc/stat 中的数据，很容易地计算出 CPU 使用率。当然，也可以用每一个场景的 CPU 时间，除以总的 CPU 时间，计算出每个场景的 CPU 使用率。
&emsp;&emsp;
不过先不要着急计算，你能说出，直接用 /proc/stat 的数据，算的是什么时间段的 CPU 使用率吗？ 这是开机以来的节拍数累加值，所以直接算出来的，是开机以来的平均 CPU 使用率，一般没啥参考价值。事实上，为了计算 CPU 使用率，性能工具一般都会取间隔一段时间（比如 3 秒）的两次值，作差后，再计算出这段时间内的平均 CPU 使用率，即

<div align=center>
<img src="https://img2018.cnblogs.com/blog/1250063/201907/1250063-20190713145310638-1798061382.png">
</div>

&emsp;&emsp;
    这个公式，就是我们用各种性能工具所看到的 CPU 使用率的实际计算方法。现在，我们知道了系统 CPU 使用率的计算方法，那进程的呢？跟系统的指标类似，Linux 也给每个进程提供了运行情况的统计信息，也就是  /proc/[pid]/stat。不过，这个文件包含的数据就比较丰富了，总共有 52 列的数据。当然，不用担心，因为你并不需要掌握每一列的含义。还是那句话，需要的时候，查 man proc 就行。
&emsp;&emsp;
是不是说要查看 CPU 使用率，就必须先读取 /proc/stat 和 /proc/[pid]/stat 这两个文件，然后再按照上面的公式计算出来呢？当然不是，各种各样的性能分析工具已经帮我们计算好了。不过要注意的是，**性能分析工具给出的都是间隔一段时间的平均 CPU 使用率，所以要注意间隔时间的设置，**特别是用多个工具对比分析时，你一定要保证它们用的是相同的间隔时间。      

- 对比一下 top 和 ps 这两个工具报告的 CPU 使用率，默认的结果很可能不一样，因为 top 默认使用 3 秒时间间隔，而 ps 使用的却是进程的整个生命周期。

### 怎么查看 CPU 使用率

    知道了 CPU 使用率的含义后，我们再来看看要怎么查看 CPU 使用率。说到查看 CPU 使用率的工具，我猜你第一反应肯定是 top 和 ps。的确，top 和 ps 是最常用的性能分析工具：

- top 显示了系统总体的 CPU 和内存使用情况，以及各个进程的资源使用情况。
- ps 则只显示了每个进程的资源使用情况。

比如，top 的输出格式为：

```
#默认每 3 秒刷新一次
top - 03:49:36 up 10:42,  1 user,  load average: 0.00, 0.01, 0.05
Tasks:  92 total,   2 running,  90 sleeping,   0 stopped,   0 zombie
%Cpu(s):  0.0 us, 11.8 sy,  0.0 ni, 88.2 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
KiB Mem :  2028088 total,  1791704 free,    96856 used,   139528 buff/cache
KiB Swap:  2097148 total,  2097148 free,        0 used.  1764088 avail Mem 

   PID USER      PR  NI    VIRT    RES    SHR S %CPU %MEM     TIME+ COMMAND                                                   
     1 root      20   0  128004   6508   4132 S  0.0  0.3   0:01.62 systemd                                                   
     2 root      20   0       0      0      0 S  0.0  0.0   0:00.00 kthreadd                                                  
     3 root      20   0       0      0      0 S  0.0  0.0   0:01.98 ksoftirqd/0                                               
     5 root       0 -20       0      0      0 S  0.0  0.0   0:00.00 kworker/0:0H                                              
     6 root      20   0       0      0      0 S  0.0  0.0   0:00.75 kworker/u256:0                                            
     7 root      rt   0       0      0      0 S  0.0  0.0   0:00.00 migration/0                                               
     8 root      20   0       0      0      0 S  0.0  0.0   0:00.00 rcu_bh                                                    
     9 root      20   0       0      0      0 R  0.0  0.0   0:01.19 rcu_sched       
```

&emsp;&emsp;
这个输出结果中，第三行 %Cpu 就是系统的 CPU 使用率，具体每一列的含义上一节都讲过，只是把 CPU 时间变换成了 CPU 使用率，我就不再重复讲了。不过需要注意，top 默认显示的是所有 CPU 的平均值，这个时候你只需要按下数字 1 ，就可以切换到每个 CPU 的使用率了。  
&emsp;&emsp;
继续往下看，空白行之后是进程的实时信息，每个进程都有一个 %CPU 列，表示进程的CPU 使用率。它是用户态和内核态 CPU 使用率的总和，包括进程用户空间使用的 CPU、通过系统调用执行的内核空间  CPU  、以及在就绪队列等待运行的  CPU。在虚拟化环境中，它还包括了运行虚拟机占用的 CPU。  
&emsp;&emsp;
可以发现，**top 并没有细分进程的用户态 CPU 和内核态 CPU。那要怎么查看每个进程的详细情况呢？你应该还记得上一节用到的 pidstat 吧，它正是一个专门分析每个进程 CPU 使用情况的工具。**比如，下面的 pidstat 命令，就间隔 1 秒展示了进程的 5 组 CPU 使用率，包括：

```
用户态 CPU 使用率 （%usr）；
内核态  CPU  使用率（%system）；
运行虚拟机 CPU 使用率（%guest）；
等待 CPU 使用率（%wait）；
以及总的 CPU 使用率（%CPU）。
```

最后的 Average 部分，还计算了 5 组数据的平均值。

```shell
每隔 1 秒输出一组数据，共输出 5 组
$ pidstat 1 5
Linux 3.10.0-957.21.2.el7.x86_64 (web-01)     07/12/2019     _x86_64_    (2 CPU)

09:01:48 AM   UID       PID    %usr %system  %guest   %wait    %CPU   CPU  Command
09:01:49 AM     0      8423    0.99    0.00    0.00    0.00    0.99     0  node
09:01:49 AM     0      9218    0.00    0.99    0.00    0.00    0.99     0  pidstat

09:01:49 AM   UID       PID    %usr %system  %guest   %wait    %CPU   CPU  Command
09:01:50 AM    27      6908    0.00    1.00    0.00    0.00    1.00     0  mysqld
09:01:50 AM     0      9218    0.00    1.00    0.00    0.00    1.00     0  pidstat

09:01:50 AM   UID       PID    %usr %system  %guest   %wait    %CPU   CPU  Command

09:01:51 AM   UID       PID    %usr %system  %guest   %wait    %CPU   CPU  Command
 09:01:52 AM     0      9218    0.00    1.00    0.00    0.00    1.00     0  pidstat

09:01:52 AM   UID       PID    %usr %system  %guest   %wait    %CPU   CPU  Command
 09:01:53 AM     0      9218    1.00    0.00    0.00    0.00    1.00     0  pidstat

Average:      UID       PID    %usr %system  %guest   %wait    %CPU   CPU  Command
 Average:       27      6908    0.00    0.20    0.00    0.00    0.20     -  mysqld
 Average:        0      8423    0.20    0.00    0.00    0.00    0.20     -  node
 Average:        0      9218    0.20    0.60    0.00    0.00    0.80     -  pidstat
```

### CPU 使用率过高怎么办？

&emsp;&emsp;
通过 top、ps、pidstat 等工具，能够找到 CPU 使用率较高（比如 100% ）的进程。你怎么知道占用 CPU 的到底是代码里的哪个函数呢？找到它，你才能更高效、更针对性地进行优化。

哪种工具适合在第一时间分析进程的 CPU 问题呢？这里介绍2种:

1. GDB 
   GDB（The GNU Project Debugger）是功能强大的程序调试利器。 在调试程序错误方面很强大。GDB 并不适合在性能分析的早期应用。为什么呢？因为 GDB  调试程序的过程会中断程序运行，这在线上环境往往是不允许的。所以，GDB 只适合用在性能分析的后期，当你找到了出问题的大致函数后，线下再借助它来进一步调试函数内部的问题。
2. perf 
   perf 是 Linux 2.6.31以后内置的性能分析工具。它以性能事件采样为基础，不仅可以分析系统的各种事件和内核性能，还可以用来分析指定应用程序的性能问题。使用 perf 分析 CPU 性能问题，我来说两种最常见、也是我最喜欢的用法。

**第一种常见用法是** perf top，类似于 top，它能够实时显示占用 CPU 时钟最多的函数或者指令，因此可以用来查找热点函数，使用界面如下所示：

```
$ yum install -y perf 
```

```
$ perf top
Samples: 591  of event 'cpu-clock', Event count (approx.): 24787480
 Overhead  Shared Object       Symbol
   29.40%  [kernel]            [k] _raw_spin_unlock_irqrestore
   21.50%  [kernel]            [k] generic_exec_single
   15.81%  [kernel]            [k] mpt_put_msg_frame
    8.49%  [kernel]            [k] e1000_xmit_frame
    7.05%  [kernel]            [k] __do_softirq
    2.56%  [kernel]            [k] ata_sff_pio_task
    2.03%  [kernel]            [k] tick_nohz_idle_enter
    1.57%  [kernel]            [k] __x2apic_send_IPI_mask
    1.29%  libslang.so.2.2.4   [.] SLtt_smart_puts
    0.77%  libpthread-2.17.so  [.] 0x000000000000e6a1
......
```

输出结果中，第一行包含三个数据，分别是采样数（Samples）、事件类型（event）和事件总数量（Event count）。

采样数需要注意。如果采样数过少（比如只有十几个），那下面的排序和百分比就没什么实际参考价值。

再往下看是一个表格式样的数据，每一行包含四列，分别是：

- 第一列 Overhead ，是该符号的性能事件在所有采样中的比例，用百分比来表示。
- 第二列 Shared ，是该函数或指令所在的动态共享对象（Dynamic Shared Object）， 如内核、进程名、动态链接库名、内核模块名等。
- 第三列 Object ，是动态共享对象的类型。比如 [.] 表示用户空间的可执行程序、或者动态链接库，而 [k] 则表示内核空间。
- 最后一列 Symbol 是符号名，也就是函数名。当函数名未知时，用十六进制的地址来表示。

- **第二种常见用法**，也就是 perf record 和 perf report。 perf top 虽然实时展示了系统的性能信息，但它的缺点是并不保存数据，也就无法用于离线或者后续的分析。而 perf record 则提供了保存数据的功能，保存后的数据，需要你用 perf report 解析展示。

```
$ perf record    # 按 Ctrl+C 终止采样
^C[ perf record: Woken up 21 times to write data ]
 [ perf record: Captured and wrote 5.271 MB perf.data (109799 samples) ]
```

```
$ perf report     # 展示类似于 perf top 的报告

Samples: 109K of event 'cpu-clock', Event count (approx.): 27449750000
 Overhead  Command         Shared Object      Symbol
   99.88%  swapper         [kernel.kallsyms]  [k] native_safe_halt
    0.03%  swapper         [kernel.kallsyms]  [k] _raw_spin_unlock_irqrestore
    0.02%  kworker/0:2     [kernel.kallsyms]  [k] _raw_spin_unlock_irqrestore
    0.02%  kworker/1:1     [kernel.kallsyms]  [k] _raw_spin_unlock_irqrestore
    0.01%  swapper         [kernel.kallsyms]  [k] __do_softirq
    0.01%  kworker/u256:0  [kernel.kallsyms]  [k] mpt_put_msg_frame
    0.01%  sshd            [kernel.kallsyms]  [k] e1000_xmit_frame
    0.00%  kworker/0:3     [kernel.kallsyms]  [k] ata_sff_pio_task
    0.00%  node            [kernel.kallsyms]  [k] generic_exec_single
    0.00%  swapper         [kernel.kallsyms]  [k] e1000_xmit_frame
    0.00%  swapper         [kernel.kallsyms]  [k] mpt_put_msg_frame
    0.00%  irqbalance      [kernel.kallsyms]  [k] seq_put_decimal_ull
.......
```

在实际使用中，还经常为 perf top 和 perf record 加上 -g 参数，开启调用关系的采样，方便我们根据调用链来分析性能问题。



### 案例分析

&emsp;&emsp;
下面就以Nginx+PHP的Web服务为例，来看看当你发现CPU使用率过高的问题后，要怎么使用top等工具找出异常的进程，又要怎么利用perf找出引发性能问题的函数。

#### 环境准备

以下案例基于Centos7.6，同样适用其他Linux操作系统

机器配置：2CPU，8GB内存

```
预先安装docker，sysstat，perf，ab等工具
[root@localhost ~]# cat /etc/redhat-release 
CentOS Linux release 7.6.1810 (Core) 
[root@localhost ~]# uname -r
3.10.0-957.21.3.el7.x86_64

[root@localhost ~]# yum -y install epel-release
[root@localhost ~]# yum -y install httpd-tools sysstat perf
```

######安装docker

```
[root@localhost ~]# yum -y install yum-utils device-mapper-persistent-data lvm2
[root@localhost ~]# curl https://download.docker.com/linux/centos/docker-ce.repo -o /etc/yum.repos.d/docker-ce.repo
[root@localhost ~]# yum -y install docker-ce
[root@localhost ~]# systemctl start docker
[root@localhost ~]# systemctl enable docker
Created symlink from /etc/systemd/system/multi-user.target.wants/docker.service to /usr/lib/systemd/system/docker.service.

#添加国内镜像源
[root@localhost ~]# cat /etc/docker/daemon.json
{
    "registry-mirrors":[ "https://registry.docker-cn.com" ]
}
[root@localhost ~]# systemctl daemon-reload
[root@localhost ~]# systemctl restart docker

#下载两个镜像
[root@localhost ~]# docker pull feisky/nginx
[root@localhost ~]# docker pull feisky/php-fpm
````

操作说明
需要用到两个虚拟机和一个新的工具ab。

> ab : 一个常用的HTTP服务性能测试工具，这里用来模拟Nginx的客户端。

由于Nginx和PHP配置麻烦，这里使用镜像进行模拟

<div align=center>
<img src="http://static.zybuluo.com/yangwenbo/ipiaoj6vu51lpxf1zbe1qcu0/image.png
">
</div>


你们可以看到，其中一台用作Web服务器，来模拟性能出现问题；
另外一台用作访问Web服务器的客户端，来给Web服务增加压力请求。

接下来，我们打开两个终端，分别SSH登陆到两台机器上，并安装上面提到的工具。

还是同样的情况。下面的所有命令，都默认假设以root身份运行；

### 操作和分析

接下来，我们正式进入操作环节。首先，在第一个终端执行下面的命令来运行 Nginx 和 PHP 应用：

```
$ docker run --name nginx -p 10000:80 -itd feisky/nginx
$ docker run --name phpfpm -itd --network container:nginx feisky/php-fpm
```

然后，在第二个终端使用 curl 访问 http://[VM1 的 IP]:10000，确认 Nginx 已正常启动。你应该可以看到 It works! 的响应。

```
$ curl http://10.0.0.6:10000
It works!
```

接着，我们来测试一下这个 Nginx 服务的性能。在第二个终端运行下面的 ab 命令：

```
# 并发 10 个请求测试 Nginx 性能，总共测试 100 个请求
$ ab -c 10 -n 100 http://10.0.0.6:10000/
. . .
 Complete requests:      100
 Failed requests:        0
 Write errors:           0
 Total transferred:      17200 bytes
 HTML transferred:       900 bytes
 Requests per second:    20.29 [#/sec] (mean)
 Time per request:       492.739 [ms] (mean)
 Time per request:       49.274 [ms] (mean, across all concurrent requests)
Transfer rate:          3.41 [Kbytes/sec] received
. . .
```

从 ab 的输出结果可以看到，Nginx 能承受的每秒平均请求数只有 20.29。太低了,我们用 top 和 pidstat 再来观察下。

这次，我们在第二个终端，将测试的请求总数增加到 10000。这样当你在第一个终端使用性能分析工具时， Nginx 的压力还是继续。继续在第二个终端，运行 ab 命令：

```
$ ab -c 10 -n 10000 http://10.240.0.5:10000/ 
```

接着，回到第一个终端运行 top 命令，并按下数字 1 ，切换到每个 CPU 的使用率：

```
top - 12:37:16 up 13:07,  1 user,  load average: 1.31, 0.33, 0.14
Tasks: 148 total,   6 running, 142 sleeping,   0 stopped,   0 zombie
 %Cpu0  : 99.0 us,  0.3 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi,  0.7 si,  0.0 st
 %Cpu1  : 99.7 us,  0.0 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi,  0.3 si,  0.0 st
 KiB Mem :  2028112 total,   177024 free,   455488 used,  1395600 buff/cache
 KiB Swap:  2097148 total,  2097148 free,        0 used.  1258424 avail Mem

   PID USER      PR  NI    VIRT    RES    SHR S  %CPU %MEM     TIME+ COMMAND
  10463 bin       20   0  336684   9364   1692 R  43.9  0.5   0:05.84 php-fpm
  10460 bin       20   0  336684   9368   1696 R  39.5  0.5   0:06.13 php-fpm
  10461 bin       20   0  336684   9364   1692 R  39.5  0.5   0:05.75 php-fpm
  10462 bin       20   0  336684   9364   1692 R  38.2  0.5   0:07.14 php-fpm
  10459 bin       20   0  336684   9372   1700 R  36.9  0.5   0:05.99 php-fpm
   9900 101       20   0   33092   2152    776 S   1.0  0.1   0:01.70 nginx
      3 root      20   0       0      0      0 S   0.3  0.0   0:00.68 ksoftirqd/0
   9538 root      20   0  520300  62624  25208 S   0.3  3.1   0:22.93 dockerd
  10348 root      20   0       0      0      0 S   0.3  0.0   0:00.17 kworker/0:0
  10464 root      20   0  162012   2280   1592 R   0.3  0.1   0:00.05 top
      1 root      20   0  128040   6600   4144 S   0.0  0.3   0:03.05 systemd
      2 root      20   0       0      0      0 S   0.0  0.0   0:00.02 kthreadd
      5 root       0 -20       0      0      0 S   0.0  0.0   0:00.00 kworker/0:0H
      7 root      rt   0       0      0      0 S   0.0  0.0   0:00.05 migration/0
```

这里可以看到，系统中有几个 php-fpm 进程的 CPU 使用率加起来接近 200%；而每个CPU 的用户使用率（us）也已经超过了 98%，接近饱和。这样，我们就可以确认，正是用户空间的 php-fpm 进程，导致 CPU 使用率骤升。

```
# -g 开启调用关系分析，-p 指定 php-fpm 的进程号 21515
$ perf top -g -p 21515
```

按方向键切换到 php-fpm，再按下回车键展开 php-fpm 的调用关系，你会发现，调用关系最终到了 sqrt 和 add_function。看来，我们需要从这两个函数入手了。

<div align=center>
<img src="https://img2018.cnblogs.com/blog/1250063/201907/1250063-20190713145324071-705988041.png">
</div>

拷贝出 Nginx 应用的源码，看看是不是调用了这两个函数：

```
# 从容器 phpfpm 中将 PHP 源码拷贝出来
$ docker cp phpfpm:/app .
# 使用 grep 查找函数调用
$ grep sqrt -r app/ # 找到了 sqrt 调用
app/index.php:    $x += sqrt($x);
$ grep add_function -r app/ # 没找到 add_function 调用，这其实是 PHP 
```

原来只有 sqrt 函数在 app/index.php 文件中调用了。那最后一步，我们就该看看这个文件的源码了：

```
$ cat app/index.php
<?php
// test only.
$x = 0.0001;
 for ($i = 0; $i <= 1000000; $i++) {
   $x += sqrt($x);
 }

echo "It works!"
```

测试代码没删就直接发布应用了。为了方便你验证优化后的效果，我把修复后的应用也打包成了一个 Docker 镜像，你可以在第一个终端中执行下面的命令来运行它：

```
$ docker run --name nginx -p 10000:80 -itd feisky/nginx:cpu-fix
$ docker run --name phpfpm -itd --network container:nginx feisky/php-fpm:cpu-fix
```

接着，到第二个终端来验证一下修复后的效果。首先 Ctrl+C 停止之前的 ab 命令后，再运行下面的命令：

```
$ ab -c 10 -n 10000 http://10.0.0.6:10000/

......
Complete requests:      10000
Failed requests:        0
Write errors:           0
Total transferred:      1720000 bytes
HTML transferred:       90000 bytes
Requests per second:    1638.15 [#/sec] (mean)
 Time per request:       6.104 [ms] (mean)
 Time per request:       0.610 [ms] (mean, across all concurrent requests)
 Transfer rate:          275.16 [Kbytes/sec] received
......
```

可以发现，现在每秒的平均请求数，已经从原来的 11 变成了 1638。



### 小结

&emsp;&emsp;
		CPU 使用率是最直观和最常用的系统性能指标，更是我们在排查性能问题时，通常会关注的第一个指标。所以我们更要熟悉它的含义，尤其要弄清楚用户（%user）、Nice（%nice）、系统（%system） 、等待 I/O（%iowait） 、中断（%irq）以及软中断（%softirq）这几种不同 CPU 的使用率。比如说：

- 用户 CPU 和 Nice CPU 高，说明用户态进程占用了较多的 CPU，所以应该着重排查进程的性能问题。
- 系统 CPU 高，说明内核态占用了较多的 CPU，所以应该着重排查内核线程或者系统调用的性能问题。
- I/O 等待 CPU 高，说明等待 I/O 的时间比较长，所以应该着重排查系统存储是不是出现了 I/O 问题。
- 软中断和硬中断高，说明软中断或硬中断的处理程序占用了较多的 CPU，所以应该着重排查内核中的中断服务程序。

**遇到 CPU 使用率升高的问题，你可以借助 top、pidstat 等工具，确认引发 CPU 性能问题的来源；再使用 perf 等工具，排查出引起性能问题的具体函数。**



# CPU 使用率高 (下)



## 案例背景

系统的 `CPU 使用率`，不仅包括进程用户态和内核态的运行，还包括`中断处理`、`等待 I/O` 以及`内核线程`等。所以，当你发现系统的 `CPU 使用率`很高的时候，不一定能找到相对应的高`CPU 使用率`的`进程`。

## 案例分析

### 准备工作

```shell
1. 本次案例基于 Ubuntu 18.04，同样适用于其他的 Linux 系统
1. 机器配置：2 CPU，8GB 内存
2. 预先安装 docker、sysstat、perf、ab 等工具，如 apt install docker.io sysstat linux-tools-common apache2-utils

```

### 操作和分析

安装环境

```shell
docker run --name nginx -p 10000:80 -itd feisky/nginx:sp
docker run --name phpfpm -itd --network container:nginx feisky/php-fpm:sp
```

在第二个终端,使用`ab`请求测试 `Nginx` 性能

```shell
# 并发100个请求测试Nginx性能，总共测试1000个请求

$ ab -c 100 -n 1000 http://127.0.0.1:10000/

This is ApacheBench, Version 2.3 <$Revision: 1706008 $>
Copyright 1996 Adam Twiss, Zeus Technology Ltd, 
...
Requests per second:    87.86 [#/sec] (mean)
Time per request:       1138.229 [ms] (mean)
...
```

`Nginx` 能承受的每秒平均请求数，只有`87` 多一点,显然性能很差.那么，到底是哪里出了问题呢？

继续在第二个终端运行 ab 命令测试:

```
#并发请求5个 持续600秒
$ ab -c 5 -t 600 http://192.168.0.10:10000/
```

打开第三个终端,使用`top`查看

```shell
$ top
...
%Cpu(s): 80.8 us, 15.1 sy,  0.0 ni,  2.8 id,  0.0 wa,  0.0 hi,  1.3 si,  0.0 st
...

  PID USER      PR  NI    VIRT    RES    SHR S  %CPU %MEM     TIME+ COMMAND
 6882 root      20   0    8456   5052   3884 S   2.7  0.1   0:04.78 docker-containe
 6947 systemd+  20   0   33104   3716   2340 S   2.7  0.0   0:04.92 nginx
 7494 daemon    20   0  336696  15012   7332 S   2.0  0.2   0:03.55 php-fpm
 7495 daemon    20   0  336696  15160   7480 S   2.0  0.2   0:03.55 php-fpm
10547 daemon    20   0  336696  16200   8520 S   2.0  0.2   0:03.13 php-fpm
10155 daemon    20   0  336696  16200   8520 S   1.7  0.2   0:03.12 php-fpm
10552 daemon    20   0  336696  16200   8520 S   1.7  0.2   0:03.12 php-fpm
15006 root      20   0 1168608  66264  37536 S   1.0  0.8   9:39.51 dockerd
 4323 root      20   0       0      0      0 I   0.3  0.0   0:00.87 kworker/u4:1
...
```

`CPU` 使用率最高的进程也只不过才 `2.7%`，看起来并不高。

但是用户`CPU`使用率`（us）`已经到了 `80%`，系统 `CPU` 为`15.1%`，而空闲`CPU （id`）则只有 `2.8%`。

进一步分析:

> docker-containerd 进程是用来运行容器的，2.7% 的 CPU 使用率看起来正常；
>
> Nginx`和 `php-fpm` 是运行 `Web 服务的，它们会占用一些 `CPU`也不意外，并且`2%`的 `CPU` 使用率也不算高；
>
> 再往下看，后面的进程呢，只有 `0.3%`的`CPU`使用率，看起来不太像会导致用户 `CPU` 使用率达到 `80%`。

**根据上述分析还是找不到高 `CPU 使用率`的`进程`,此时考虑更换工具使用`pidstat`继续查找原因**

运行`pidstat`继续查找原因

```shell
# 间隔1秒输出一组数据（按Ctrl+C结束）
$ pidstat 1
...
04:36:24      UID       PID    %usr %system  %guest   %wait    %CPU   CPU  Command
04:36:25        0      6882    1.00    3.00    0.00    0.00    4.00     0  docker-containe
04:36:25      101      6947    1.00    2.00    0.00    1.00    3.00     1  nginx
04:36:25        1     14834    1.00    1.00    0.00    1.00    2.00     0  php-fpm
04:36:25        1     14835    1.00    1.00    0.00    1.00    2.00     0  php-fpm
04:36:25        1     14845    0.00    2.00    0.00    2.00    2.00     1  php-fpm
04:36:25        1     14855    0.00    1.00    0.00    1.00    1.00     1  php-fpm
04:36:25        1     14857    1.00    2.00    0.00    1.00    3.00     0  php-fpm
04:36:25        0     15006    0.00    1.00    0.00    0.00    1.00     0  dockerd
04:36:25        0     15801    0.00    1.00    0.00    0.00    1.00     1  pidstat
04:36:25        1     17084    1.00    0.00    0.00    2.00    1.00     0  stress
04:36:25        0     31116    0.00    1.00    0.00    0.00    1.00     0  atopacctd
...
```

观察一会儿，发现所有进程的 CPU 使用率也都不高，最高的`Docker`和 `Nginx` 也只有 `4%`和`3%`，即使所有进程的 CPU 使用率都加起来，也不过是 `21%`，离 `80%` 还差得远呢！

重新运行 `top`命令，并观察一会儿

```shell
$ top
top - 04:58:24 up 14 days, 15:47,  1 user,  load average: 3.39, 3.82, 2.74
Tasks: 149 total,   6 running,  93 sleeping,   0 stopped,   0 zombie
%Cpu(s): 77.7 us, 19.3 sy,  0.0 ni,  2.0 id,  0.0 wa,  0.0 hi,  1.0 si,  0.0 st
KiB Mem :  8169348 total,  2543916 free,   457976 used,  5167456 buff/cache
KiB Swap:        0 total,        0 free,        0 used.  7363908 avail Mem

  PID USER      PR  NI    VIRT    RES    SHR S  %CPU %MEM     TIME+ COMMAND
 6947 systemd+  20   0   33104   3764   2340 S   4.0  0.0   0:32.69 nginx
 6882 root      20   0   12108   8360   3884 S   2.0  0.1   0:31.40 docker-containe
15465 daemon    20   0  336696  15256   7576 S   2.0  0.2   0:00.62 php-fpm
15466 daemon    20   0  336696  15196   7516 S   2.0  0.2   0:00.62 php-fpm
15489 daemon    20   0  336696  16200   8520 S   2.0  0.2   0:00.62 php-fpm
 6948 systemd+  20   0   33104   3764   2340 S   1.0  0.0   0:00.95 nginx
15006 root      20   0 1168608  65632  37536 S   1.0  0.8   9:51.09 dockerd
15476 daemon    20   0  336696  16200   8520 S   1.0  0.2   0:00.61 php-fpm
15477 daemon    20   0  336696  16200   8520 S   1.0  0.2   0:00.61 php-fpm
24340 daemon    20   0    8184   1616    536 R   1.0  0.0   0:00.01 stress
24342 daemon    20   0    8196   1580    492 R   1.0  0.0   0:00.01 stress
24344 daemon    20   0    8188   1056    492 R   1.0  0.0   0:00.01 stress
24347 daemon    20   0    8184   1356    540 R   1.0  0.0   0:00.01 stress
...
```

**观察`Tasks`就绪队列中居然有 6 个 `Running`状态的进程,回想一下`ab` 测试的参数，并发请求数是 5。再看进程列表里， `php-fpm` 的数量也是 5，再加上 `Nginx`，好像同时有 6 个进程也并不奇怪.但仔细查看`nginx`和`php-fpm`的状态发现,它们都处于`Sleep（S）`状态，而真正处于 `Running（R）`状态的，却是几个 `stress` 进程。**

使用`pidstat`指定上面`top`中几个进程的`pid`查看

```shell
$ pidstat -p 24344
16:14:55      UID       PID    %usr %system  %guest   %wait    %CPU   CPU  Command
```

**居然没有任何输出, 从所有进程中查找PID是24344的进程通过命令` ps aux | grep 24344`,还是没有输出。现在终于发现问题，原来这个进程已经不存在了，所以 pidstat 就没有任何输出。既然进程都没了，那性能问题应该也跟着没了。**

再用 top 命令确认一下。

```shell
$ top
...
%Cpu(s): 80.9 us, 14.9 sy,  0.0 ni,  2.8 id,  0.0 wa,  0.0 hi,  1.3 si,  0.0 st
...

  PID USER      PR  NI    VIRT    RES    SHR S  %CPU %MEM     TIME+ COMMAND
 6882 root      20   0   12108   8360   3884 S   2.7  0.1   0:45.63 docker-containe
 6947 systemd+  20   0   33104   3764   2340 R   2.7  0.0   0:47.79 nginx
 3865 daemon    20   0  336696  15056   7376 S   2.0  0.2   0:00.15 php-fpm
  6779 daemon    20   0    8184   1112    556 R   0.3  0.0   0:00.01 stress
...
```

用户`CPU 使用率`还是高达 `80.9%`，系统 `CPU` 接近`15%`，而`空闲 CPU`只有 `2.8%`，`Running` 状态的进程有 `Nginx`、`stress` 等

这次`stress` 进程的 `PID` 跟前面不一样了，原来的 `PID 24344` 不见了，现在的是 `6779`

**根据上面分析发现,`stress`的进程`PID`一直在不停的更换,而进程`PID`更换原因一般为如下两种:**

> 进程`在不停地`崩溃重启，比如因为段错误、配置错`等等，这时，进程在退出后可能又被监控系统自动重启了
>
> 这些进程都是短时进程，也就是在其他应用内部通过 `exec` 调用的外面命令。这些命令一般都只运行很短的时间就会结束，你很难用 `top`这种间隔时间比较长的工具发现

**`stress`，我们前面提到过，它是一个常用的压力测试工具。它的 `PID` 在不断变化中，看起来像是被其他进程调用的短时进程。要想继续分析下去，还得找到它们的父进程**

使用pstree命令查看stress的父进程

```shell
$ pstree | grep stress
        |-docker-containe-+-php-fpm-+-php-fpm---sh---stress
        |         |-3*[php-fpm---sh---stress---stress]
```

查看源码中是否又调用

```shell
# 拷贝源码到本地
$ docker cp phpfpm:/app .

# grep 查找看看是不是有代码在调用stress命令
$ grep stress -r app
app/index.php:// fake I/O with stress (via write()/unlink()).
app/index.php:$result = exec("/usr/local/bin/stress -t 1 -d 1 2>&1", $output, $status);
```

**果然是 `app/index.php` 文件中直接调用了 `stress` 命令,果断打开文件查看如下:**

```shell
$ cat app/index.php
<?php
// fake I/O with stress (via write()/unlink()).
$result = exec("/usr/local/bin/stress -t 1 -d 1 2>&1", $output, $status);
if (isset($_GET["verbose"]) && $_GET["verbose"]==1 && $status != 0) {
  echo "Server internal error: ";
  print_r($output);
} else {
  echo "It works!";
}
?>
```

**从代码中可以看到，给请求加入 `verbose=1` 参数后，就可以查看 `stress` 的输出**

```shell
$ curl http://127.0.0.1:10000?verbose=1
Server internal error: Array
(
    [0] => stress: info: [19607] dispatching hogs: 0 cpu, 0 io, 0 vm, 1 hdd
    [1] => stress: FAIL: [19608] (563) mkstemp failed: Permission denied
    [2] => stress: FAIL: [19607] (394) <-- worker 19608 returned error 1
    [3] => stress: WARN: [19607] (396) now reaping child worker processes
    [4] => stress: FAIL: [19607] (400) kill error: No such process
    [5] => stress: FAIL: [19607] (451) failed run completed in 0s
)
```

**看错误消息 `mkstemp failed: Permission denied` ，以及 `failed run completed in 0s`。原来`stress` 命令并没有成功，它因为权限问题失败退出了。看来，我们发现了一个 `PHP` 调用外部 `stress` 命令的 bug：没有权限创建临时文件**

在上面的案例中`top`、`pidstat`、`pstree` 等工具，都没有发现大量的`stress` 进程,此时如果使用`perf`分析`cpu`是非常合适的

```shell
# 记录性能事件，等待大约15秒后按 Ctrl+C 退出
$ perf record -g

# 查看报告
$ perf report
```

![在这里插入图片描述](https://img-blog.csdnimg.cn/20200701114256588.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L0NOX1NIemhhb3l1amll,size_16,color_FFFFFF,t_70)

**`stress`占了所有 `CPU 时钟事件`的 `77%`，而 `stress` 调用栈中比例最高的，是随机数生成函数 `random()`，看来它的确就是 `CPU 使用率`升高的元凶了。随后的优化就很简单了，只要修复权限问题，并减少或删除 `stress` 的调用，就可以减轻系统的 `CPU 压力`**

## 总结

- 当`pidstat`,`vmstat`,`top`无法定位到问题的时候
- 因考虑进程本身,是否存在短时运行的情况
- 对于这类进程，可以用 `pstree` `execsnoop` `perf` 排查

## Tips

### 关于execsnoop

**[execsnoop](https://github.com/brendangregg/perf-tools/blob/master/execsnoop) 是一个专为短时进程设计的工具。它通过 ftrace 实时监控进程的 exec() 行为，并输出短时进程的基本信息，包括进程 PID、父进程 PID、命令行参数以及执行的结果。**

**用 `execsnoop` 监控上述案例，就可以直接得到 `stress` 进程的`父进程 PID` 以及它的命令行参数，并可以发现大量的 `stress` 进程在不停启动：**

```shell
# 按 Ctrl+C 结束
$ execsnoop
PCOMM            PID    PPID   RET ARGS
sh               30394  30393    0
stress           30396  30394    0 /usr/local/bin/stress -t 1 -d 1
sh               30398  30393    0
stress           30399  30398    0 /usr/local/bin/stress -t 1 -d 1
sh               30402  30400    0
stress           30403  30402    0 /usr/local/bin/stress -t 1 -d 1
sh               30405  30393    0
stress           30407  30405    0 /usr/local/bin/stress -t 1 -d 1

```

> execsnoop 所用的 ftrace 是一种常用的动态追踪技术，一般用于分析 Linux 内核的运行时行为







# 不可中断进程和僵尸进程（上）

我们已经在上下文切换的文章中，一起分析了系统 CPU 使用率高的问题，剩下的等待 I/O 的 CPU 使用率（以下简称为 iowait）升高，也是最常见的一个服务器性能问题。今天我们就来看一个多进程 I/O 的案例，并分析这种情况。



## 进程状态

当 iowait 升高时，进程很可能因为得不到硬件的响应，而长时间处于不可中断状态。从 ps 或者 top 命令的输出中，你可以发现它们都处于 D 状态，也就是不可中断状态（Uninterruptible Sleep）。既然说到了进程的状态，进程有哪些状态你还记得吗？我们先来回顾一下。

top 和 ps 是最常用的查看进程状态的工具，我们就从 top 的输出开始。下面是一个 top 命令输出的示例，S 列（也就是 Status 列）表示进程的状态。从这个示例里，你可以看到 R、D、Z、S、I 等几个状态，它们分别是什么意思呢？

```shell
$ top
  PID USER      PR  NI    VIRT    RES    SHR S  %CPU %MEM     TIME+ COMMAND
28961 root      20   0   43816   3148   4040 R   3.2  0.0   0:00.01 top
  620 root      20   0   37280  33676    908 D   0.3  0.4   0:00.01 app
    1 root      20   0  160072   9416   6752 S   0.0  0.1   0:37.64 systemd
 1896 root      20   0       0      0      0 Z   0.0  0.0   0:00.00 devapp
    2 root      20   0       0      0      0 S   0.0  0.0   0:00.10 kthreadd
    4 root       0 -20       0      0      0 I   0.0  0.0   0:00.00 kworker/0:0H
    6 root       0 -20       0      0      0 I   0.0  0.0   0:00.00 mm_percpu_wq
    7 root      20   0       0      0      0 S   0.0  0.0   0:06.37 ksoftirqd/0
```

我们挨个来看一下：

* R 是 Running 或 Runnable 的缩写，表示进程在 CPU 的就绪队列中，正在运行或者正在等待运行。
* D 是 Disk Sleep 的缩写，也就是不可中断状态睡眠（Uninterruptible Sleep），一般表示进程正在跟硬件交互，并且交互过程不允许被其他进程或中断打断。
* Z 是 Zombie 的缩写，如果你玩过“植物大战僵尸”这款游戏，应该知道它的意思。它表示僵尸进程，也就是进程实际上已经结束了，但是父进程还没有回收它的资源（比如进程的描述符、PID 等）。
* S 是 Interruptible Sleep 的缩写，也就是可中断状态睡眠，表示进程因为等待某个事件而被系统挂起。当进程等待的事件发生时，它会被唤醒并进入 R 状态。
* I 是 Idle 的缩写，也就是空闲状态，用在不可中断睡眠的内核线程上。前面说了，硬件交互导致的不可中断进程用 D 表示，但对某些内核线程来说，它们有可能实际上并没有任何负载，用 Idle 正是为了区分这种情况。要注意，D 状态的进程会导致平均负载升高， I 状态的进程却不会。
* **T** 或者 t，是 Stopped 或 Traced 的缩写，表示进程处于暂停或者跟踪状态。如（1）向一个进程发送 SIGSTOP 信号，它就会因响应这个信号变成暂停状态（Stopped）；再向它发送 SIGCONT 信号，进程又会恢复运行（如果进程是终端里直接启动的，则需要你用 fg 命令，恢复到前台运行）。（2）调试器 gdb 调试一个进程时，在使用断点中断进程后，进程就会变成跟踪状态，这其实也是一种特殊的暂停状态，只不过你可以用调试器来跟踪并按需要控制进程的运行。
* **X** 是 Dead 的缩写，表示进程已经消亡，所以你不会在 top 或者 ps 命令中看到它。



我们再回到今天的主题。先看不可中断状态，这其实是为了保证进程数据与硬件状态一致，并且正常情况下，不可中断状态在很短时间内就会结束。所以，短时的不可中断状态进程，我们一般可以忽略。

但如果系统或硬件发生了故障，进程可能会在不可中断状态保持很久，甚至导致系统中出现大量不可中断进程。这时，你就得注意下，系统是不是出现了 I/O 等性能问题。

再看僵尸进程，这是多进程应用很容易碰到的问题。正常情况下，当一个进程创建了子进程后，它应该通过系统调用 wait() 或者 waitpid() 等待子进程结束，回收子进程的资源；而子进程在结束时，会向它的父进程发送 SIGCHLD 信号，所以，父进程还可以注册 SIGCHLD 信号的处理函数，异步回收资源。

如果父进程没这么做，或是子进程执行太快，父进程还没来得及处理子进程状态，子进程就已经提前退出，那这时的子进程就会变成僵尸进程。换句话说，父亲应该一直对儿子负责，善始善终，如果不作为或者跟不上，都会导致“问题少年”的出现。

通常，僵尸进程持续的时间都比较短，在父进程回收它的资源后就会消亡；或者在父进程退出后，由 init 进程回收后也会消亡。一旦父进程没有处理子进程的终止，还一直保持运行状态，那么子进程就会一直处于僵尸状态。大量的僵尸进程会用尽 PID 进程号，导致新进程不能创建，所以这种情况一定要避免。



## 案例分析

接下来，我将用一个多进程应用的案例，带你分析大量不可中断状态和僵尸状态进程的问题。这个应用基于 C 开发，由于它的编译和运行步骤比较麻烦，我把它打包成了一个 Docker 镜像。这样，你只需要运行一个 Docker 容器就可以得到模拟环境。



### 你的准备

下面的案例仍然基于 Centos7，同样适用于其他的 Linux 系统。我使用的案例环境如下所示：

- 机器配置：2 CPU，8GB 内存
- 预先安装 docker、sysstat、dstat 等工具

这里，dstat 是一个新的性能工具，它吸收了 vmstat、iostat、ifstat 等几种工具的优点，可以同时观察系统的 CPU、磁盘 I/O、网络以及内存使用情况。

接下来，我们打开一个终端，SSH 登录到机器上，并安装上述工具。

注意，以下所有命令都默认以 root 用户运行，如果你用普通用户身份登陆系统，请运行 sudo su root 命令切换到 root 用户。如果安装过程有问题，你可以先上网搜索解决，实在解决不了的，记得在留言区向我提问。



### 操作和分析

安装完成后，我们首先执行下面的命令运行案例应用：

```ruby
$ docker run --privileged --name=app -itd feisky/app:iowait
```

**注意：拉取上面这个镜像后电脑可能会卡死，~~~**

然后，输入 ps 命令，确认案例应用已正常启动。如果一切正常，你应该可以看到如下所示的输出：

```ruby
$ ps aux | grep /app
root      4009  0.0  0.0   4376  1008 pts/0    Ss+  05:51   0:00 /app
root      4287  0.6  0.4  37280 33660 pts/0    D+   05:54   0:00 /app
root      4288  0.6  0.4  37280 33668 pts/0    D+   05:54   0:00 /app
```

**注意：如果没有出现D+，或者top里的wa没有太大变化，新建一个虚拟机，然后安装docker，拉取镜像试一下，~~~**

从这个界面，我们可以发现多个 app 进程已经启动，并且它们的状态分别是 Ss+ 和 D+。其中，S 表示可中断睡眠状态，D 表示不可中断睡眠状态，我们在前面刚学过，那后面的 s 和 + 是什么意思呢？不知道也没关系，查一下 man ps 就可以。现在记住，s 表示这个进程是一个会话的领导进程，而 + 表示前台进程组。

这里又出现了两个新概念，进程组和会话。它们用来管理一组相互关联的进程，意思其实很好理解。

- 进程组表示一组相互关联的进程，比如每个子进程都是父进程所在组的成员；
- 而会话是指共享同一个控制终端的一个或多个进程组。

比如，我们通过 SSH 登录服务器，就会打开一个控制终端（TTY），这个控制终端就对应一个会话。而我们在终端中运行的命令以及它们的子进程，就构成了一个个的进程组，其中，在后台运行的命令，构成后台进程组；在前台运行的命令，构成前台进程组。

明白了这些，我们再用 top 看一下系统的资源使用情况：



```objectivec
# 按下数字 1 切换到所有 CPU 的使用情况，观察一会儿按 Ctrl+C 结束
$ top
top - 05:56:23 up 17 days, 16:45,  2 users,  load average: 2.00, 1.68, 1.39
Tasks: 247 total,   1 running,  79 sleeping,   0 stopped, 115 zombie
%Cpu0  :  0.0 us,  0.7 sy,  0.0 ni, 38.9 id, 60.5 wa,  0.0 hi,  0.0 si,  0.0 st
%Cpu1  :  0.0 us,  0.7 sy,  0.0 ni,  4.7 id, 94.6 wa,  0.0 hi,  0.0 si,  0.0 st
...

  PID USER      PR  NI    VIRT    RES    SHR S  %CPU %MEM     TIME+ COMMAND
 4340 root      20   0   44676   4048   3432 R   0.3  0.0   0:00.05 top
 4345 root      20   0   37280  33624    860 D   0.3  0.0   0:00.01 app
 4344 root      20   0   37280  33624    860 D   0.3  0.4   0:00.01 app
    1 root      20   0  160072   9416   6752 S   0.0  0.1   0:38.59 systemd
...
```

从这里你能看出什么问题吗？细心一点，逐行观察，别放过任何一个地方。忘了哪行参数意思的话，也要及时返回去复习。

好的，如果你已经有了答案，那就继续往下走，看看跟我找的问题是否一样。这里，我发现了四个可疑的地方。

- 先看第一行的平均负载（ Load Average），过去 1 分钟、5 分钟和 15 分钟内的平均负载在依次减小，说明平均负载正在升高；而 1 分钟内的平均负载已经达到系统的 CPU 个数，说明系统很可能已经有了性能瓶颈。
- 再看第二行的 Tasks，有 1 个正在运行的进程，但僵尸进程比较多，而且还在不停增加，说明有子进程在退出时没被清理。
- 接下来看两个 CPU 的使用率情况，用户 CPU 和系统 CPU 都不高，但 iowait 分别是 60.5% 和 94.6%，好像有点儿不正常。
- 最后再看每个进程的情况， CPU 使用率最高的进程只有 0.3%，看起来并不高；但有两个进程处于 D 状态，它们可能在等待 I/O，但这里并不能确定是它们导致了 iowait 升高。

我们把这四个问题再汇总一下，就可以得到很明确的两点：

- 第一点，iowait 太高了，导致系统的平均负载升高，甚至达到了系统 CPU 的个数。
- 第二点，僵尸进程在不断增多，说明有程序没能正确清理子进程的资源。

那么，碰到这两个问题该怎么办呢？结合我们前面分析问题的思路，你先自己想想，动手试试，下节课我来继续“分解”。



## 小结

今天我们主要通过简单的操作，熟悉了几个必备的进程状态。用我们最熟悉的 ps 或者 top ，可以查看进程的状态，这些状态包括运行（R）、空闲（I）、不可中断睡眠（D）、可中断睡眠（S）、僵尸（Z）以及暂停（T）等。

其中，不可中断状态和僵尸状态，是我们今天学习的重点。

- 不可中断状态，表示进程正在跟硬件交互，为了保护进程数据和硬件的一致性，系统不允许其他进程或中断打断这个进程。进程长时间处于不可中断状态，通常表示系统有 I/O 性能问题。
- 僵尸进程表示进程已经退出，但它的父进程还没有回收子进程占用的资源。短暂的僵尸状态我们通常不必理会，但进程长时间处于僵尸状态，就应该注意了，可能有应用程序没有正常处理子进程的退出。思考



# 不可中断进程和僵尸进程（下）



首先，请你打开一个终端，登录到上次的机器中。然后执行下面的命令，重新运行这个案例：

```
# 先删除上次启动的案例
$ docker rm -f app# 重新运行案例
$ docker run --privileged --name=app -itd feisky/app:iowait
```

## iowait 

分析我们先来看一下 iowait 升高的问题。我相信，一提到 iowait 升高，你首先会想要查询系统的 I/O 情况。

我一般也是这种思路，那么什么工具可以查询系统的 I/O 情况呢？

这里，我推荐的正是上节课要求安装的 dstat ，它的好处是，可以同时查看 CPU 和 I/O 这两种资源的使用情况，便于对比分析。

那么，我们在终端中运行 dstat 命令，观察 CPU 和 I/O 的使用情况：

```
# 间隔1秒输出10组数据
$ dstat 1 10
You did not select any stats, using -cdngy by default.
--total-cpu-usage-- -dsk/total- -net/total- ---paging-- ---system--
usr sys idl wai stl| read  writ| recv  send|  in   out | int   csw
  0   0  96   4   0|1219k  408k|   0     0 |   0     0 |  42   885
  0   0   2  98   0|  34M    0 | 198B  790B|   0     0 |  42   138
  0   0   0 100   0|  34M    0 |  66B  342B|   0     0 |  42   135
  0   0  84  16   0|5633k    0 |  66B  342B|   0     0 |  52   177
  0   3  39  58   0|  22M    0 |  66B  342B|   0     0 |  43   144
  0   0   0 100   0|  34M    0 | 200B  450B|   0     0 |  46   147
  0   0   2  98   0|  34M    0 |  66B  342B|   0     0 |  45   134
  0   0   0 100   0|  34M    0 |  66B  342B|   0     0 |  39   131
  0   0  83  17   0|5633k    0 |  66B  342B|   0     0 |  46   168
  0   3  39  59   0|  22M    0 |  66B  342B|   0     0 |  37   134
```

从 dstat 的输出，我们可以看到，每当 iowait 升高（wai）时，磁盘的读请求（read）都会很大。这说明 iowait 的升高跟磁盘的读请求有关，很可能就是磁盘读导致的。

那到底是哪个进程在读磁盘呢？不知道你还记不记得，上节在 top 里看到的不可中断状态进程，我觉得它就很可疑，我们试着来分析下。

我们继续在刚才的终端中，运行 top 命令，观察 D 状态的进程：

```
# 观察一会儿按 Ctrl+C 结束
$ top
...
  PID USER      PR  NI    VIRT    RES    SHR S  %CPU %MEM     TIME+ COMMAND
 4340 root      20   0   44676   4048   3432 R   0.3  0.0   0:00.05 top
 4345 root      20   0   37280  33624    860 D   0.3  0.0   0:00.01 app
 4344 root      20   0   37280  33624    860 D   0.3  0.4   0:00.01 app
...

```

我们从 top 的输出找到 D 状态进程的 PID，你可以发现，这个界面里有两个 D 状态的进程，PID 分别是 4344 和 4345。



比如，以 4344 为例，我们在终端里运行下面的 pidstat 命令，并用 -p 4344 参数指定进程号：

```
# -d 展示 I/O 统计数据，-p 指定进程号，间隔 1 秒输出 3 组数据
$ pidstat -d -p 4344 1 3
06:38:50      UID       PID   kB_rd/s   kB_wr/s kB_ccwr/s iodelay  Command
06:38:51        0      4344      0.00      0.00      0.00       0  app
06:38:52        0      4344      0.00      0.00      0.00       0  app
06:38:53        0      4344      0.00      0.00      0.00       0  app
```

在这个输出中，  kB_rd 表示每秒读的 KB 数， kB_wr 表示每秒写的 KB 数，iodelay 表示 I/O 的延迟（单位是时钟周期）。它们都是 0，那就表示此时没有任何的读写，说明问题不是 4344 进程导致的。

可是，用同样的方法分析进程 4345，你会发现，它也没有任何磁盘读写。

那要怎么知道，到底是哪个进程在进行磁盘读写呢？我们继续使用 pidstat，但这次去掉进程号，干脆就来观察所有进程的 I/O 使用情况。

在终端中运行下面的  pidstat 命令：

```
# 间隔 1 秒输出多组数据 (这里是 20 组)
$ pidstat -d 1 20
...
06:48:46      UID       PID   kB_rd/s   kB_wr/s kB_ccwr/s iodelay  Command
06:48:47        0      4615      0.00      0.00      0.00       1  kworker/u4:1
06:48:47        0      6080  32768.00      0.00      0.00     170  app
06:48:47        0      6081  32768.00      0.00      0.00     184  app

06:48:47      UID       PID   kB_rd/s   kB_wr/s kB_ccwr/s iodelay  Command
06:48:48        0      6080      0.00      0.00      0.00     110  app

06:48:48      UID       PID   kB_rd/s   kB_wr/s kB_ccwr/s iodelay  Command
06:48:49        0      6081      0.00      0.00      0.00     191  app

06:48:49      UID       PID   kB_rd/s   kB_wr/s kB_ccwr/s iodelay  Command

06:48:50      UID       PID   kB_rd/s   kB_wr/s kB_ccwr/s iodelay  Command
06:48:51        0      6082  32768.00      0.00      0.00       0  app
06:48:51        0      6083  32768.00      0.00      0.00       0  app

06:48:51      UID       PID   kB_rd/s   kB_wr/s kB_ccwr/s iodelay  Command
06:48:52        0      6082  32768.00      0.00      0.00     184  app
06:48:52        0      6083  32768.00      0.00      0.00     175  app

06:48:52      UID       PID   kB_rd/s   kB_wr/s kB_ccwr/s iodelay  Command
06:48:53        0      6083      0.00      0.00      0.00     105  app
...
```

观察一会儿可以发现，的确是 app 进程在进行磁盘读，并且每秒读的数据有 32 MB，看来就是 app 的问题。不过，app 进程到底在执行啥 I/O 操作呢？

这里，我们需要回顾一下进程用户态和内核态的区别。进程想要访问磁盘，就必须使用系统调用，所以接下来，重点就是找出 app 进程的系统调用了。

**strace 正是最常用的跟踪进程系统调用的工具**。所以，我们从 pidstat 的输出中拿到进程的 PID 号，比如 6082，然后在终端中运行 strace 命令，并用 -p 参数指定 PID 号:

```
$ strace -p 6082
strace: attach: ptrace(PTRACE_SEIZE, 6082): Operation not permitted
```

提示错误，strace 命令居然失败了，并且命令报出的错误是没有权限。按理来说，我们所有操作都已经是以 root 用户运行了，为什么还会没有权限呢？你也可以先想一下，碰到这种情况，你会怎么处理呢？

**一般遇到这种问题时，我会先检查一下进程的状态是否正常。**比如，继续在终端中运行 ps 命令，并使用 grep 找出刚才的 6082 号进程：

```
$ ps aux | grep 6082
root      6082  0.0  0.0      0     0 pts/0    Z+   13:43   0:00 [app] <defunct>
```

果然，进程 6082 已经变成了 Z 状态，也就是僵尸进程。僵尸进程都是已经退出的进程，所以就没法儿继续分析它的系统调用。关于僵尸进程的处理方法，我们一会儿再说，现在还是继续分析 iowait 的问题。

我们发现 top、pidstat  这类工具已经不能给出更多的信息了。这时，我们就应该求助那些基于事件记录的动态追踪工具了。

你可以用  perf top 看看有没有新发现。在终端中运行 perf record，持续一会儿（例如 15 秒），然后按 Ctrl+C 退出，再运行 perf report 查看报告：

```
$ perf record -g
$ perf report
```

![分享图片](https://static001.geekbang.org/resource/image/21/a1/21e79416e946ed049317a4b4c5a576a1.png)

这个图里的 swapper 是内核中的调度进程，你可以先忽略掉。

我们来看其他信息， app 的确在通过系统调用 sys_read() 读取数据。并且从 new_sync_read 和 blkdev_direct_IO 能看出，进程正在对磁盘进行直接读，也就是绕过了系统缓存，每个读请求都会从磁盘直接读，这就可以解释我们观察到的 iowait 升高了。



下面的问题就容易解决了。我们接下来应该从代码层面分析，究竟是哪里出现了直接读请求。查看源码文件 app.c，你会发现它果然使用了 O_DIRECT 选项打开磁盘，于是绕过了系统缓存，直接对磁盘进行读写。

```
open(disk, O_RDONLY|O_DIRECT|O_LARGEFILE, 0755)
```

直接读写磁盘，对 I/O 敏感型应用（比如数据库系统）是很友好的，因为你可以在应用中，直接控制磁盘的读写。但在大部分情况下，我们最好还是通过系统缓存来优化磁盘 I/O，换句话说，删除 O_DIRECT 这个选项就是了。



app-fix1.c 就是修改后的文件，我也打包成了一个镜像文件，运行下面的命令，你就可以启动它了：

```
# 首先删除原来的应用
$ docker rm -f app
# 运行新的应用
$ docker run --privileged --name=app -itd feisky/app:iowait-fix1
```

最后，再用 top 检查一下：

```
$ top
top - 14:59:32 up 19 min,  1 user,  load average: 0.15, 0.07, 0.05
Tasks: 137 total,   1 running,  72 sleeping,   0 stopped,  12 zombie
%Cpu0  :  0.0 us,  1.7 sy,  0.0 ni, 98.0 id,  0.3 wa,  0.0 hi,  0.0 si,  0.0 st
%Cpu1  :  0.0 us,  1.3 sy,  0.0 ni, 98.7 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
...

  PID USER      PR  NI    VIRT    RES    SHR S  %CPU %MEM     TIME+ COMMAND
 3084 root      20   0       0      0      0 Z   1.3  0.0   0:00.04 app
 3085 root      20   0       0      0      0 Z   1.3  0.0   0:00.04 app
    1 root      20   0  159848   9120   6724 S   0.0  0.1   0:09.03 systemd
    2 root      20   0       0      0      0 S   0.0  0.0   0:00.00 kthreadd
    3 root      20   0       0      0      0 I   0.0  0.0   0:00.40 kworker/0:0
...
```

 iowait 已经非常低了，只有 0.3%，说明刚才的改动已经成功修复了 iowait 高的问题，大功告成！但是，僵尸进程还在不断的增长中。



## 僵尸进程

接下来，我们就来处理僵尸进程的问题。既然僵尸进程是因为父进程没有回收子进程的资源而出现的，那么，**要解决掉它们，就是找出父进程，然后在父进程里解决。**

父进程的找法我们前面讲过，最简单的就是运行 pstree 命令:

```
# -a 表示输出命令行选项
# p表PID
# s表示指定进程的父进程
$ pstree -aps 3084
systemd,1
  └─dockerd,15006 -H fd://
      └─docker-containe,15024 --config /var/run/docker/containerd/containerd.toml
          └─docker-containe,3991 -namespace moby -workdir...
              └─app,4009
                  └─(app,3084)
```

会发现 3084 号进程的父进程是 4009，也就是 app 应用。

所以，我们接着查看 app 应用程序的代码，看看子进程结束的处理是否正确，比如有没有调用 wait() 或 waitpid() ，抑或是，有没有注册 SIGCHLD 信号的处理函数。

现在我们查看修复 iowait 后的源码文件 app-fix1.c ，找到子进程的创建和清理的地方：

```
int status = 0;
  for (;;) {
    for (int i = 0; i < 2; i++) {
      if(fork()== 0) {
        sub_process();
      }
    }
    sleep(5);
  }

  while(wait(&status)>0);
```

循环语句本来就容易出错，你能找到这里的问题吗？这段代码虽然看起来调用了 wait() 函数等待子进程结束，但却错误地把 wait() 放到了 for 死循环的外面，也就是说，wait() 函数实际上并没被调用到，我们把它挪到 for 循环的里面就可以了。

修改后的文件我放到了 app-fix2.c 中，也打包成了一个 Docker 镜像，运行下面的命令，你就可以启动它：

```
# 先停止产生僵尸进程的 app
$ docker rm -f app
# 然后启动新的 app
$ docker run --privileged --name=app -itd feisky/app:iowait-fix2
```

启动后，再用 top 最后来检查一遍：

```

$ top
top - 15:00:44 up 20 min,  1 user,  load average: 0.05, 0.05, 0.04
Tasks: 125 total,   1 running,  72 sleeping,   0 stopped,   0 zombie
%Cpu0  :  0.0 us,  1.7 sy,  0.0 ni, 98.3 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
%Cpu1  :  0.0 us,  1.3 sy,  0.0 ni, 98.7 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
...

  PID USER      PR  NI    VIRT    RES    SHR S  %CPU %MEM     TIME+ COMMAND
 3198 root      20   0    4376    840    780 S   0.3  0.0   0:00.01 app
    2 root      20   0       0      0      0 S   0.0  0.0   0:00.00 kthreadd
    3 root      20   0       0      0      0 I   0.0  0.0   0:00.41 kworker/0:0
...
```

僵尸进程（Z 状态）没有了， iowait 也是 0，问题终于全部解决了。



## 小结

今天我用一个多进程的案例，带你分析系统等待 I/O 的 CPU 使用率（也就是 iowait%）升高的情况。

虽然这个案例是磁盘 I/O 导致了 iowait 升高，不过， iowait 高不一定代表 I/O 有性能瓶颈。当系统中只有 I/O 类型的进程在运行时，iowait 也会很高，但实际上，磁盘的读写远没有达到性能瓶颈的程度。

因此，碰到 iowait 升高时，需要先用 dstat、pidstat 等工具，确认是不是磁盘 I/O 的问题，然后再找是哪些进程导致了 I/O。

等待 I/O 的进程一般是不可中断状态，所以用 ps 命令找到的 D 状态（即不可中断状态）的进程，多为可疑进程。但这个案例中，在 I/O 操作后，进程又变成了僵尸进程，所以不能用 strace 直接分析这个进程的系统调用。

这种情况下，我们用了 perf 工具，来分析系统的 CPU 时钟事件，最终发现是直接 I/O 导致的问题。这时，再检查源码中对应位置的问题，就很轻松了。

而僵尸进程的问题相对容易排查，使用 pstree 找出父进程后，去查看父进程的代码，检查 wait() / waitpid() 的调用，或是 SIGCHLD 信号处理函数的注册就行了。



# Linux软中断


上一期，我用一个不可中断进程的案例，带你学习了 iowait（也就是等待 I/O 的 CPU 使用率）升高时的分析方法。这里你要记住，进程的不可中断状态是系统的一种保护机制，可以保证硬件的交互过程不被意外打断。所以，短时间的不可中断状态是很正常的。

但是，当进程长时间都处于不可中断状态时，你就得当心了。这时，你可以使用 dstat、pidstat 等工具，确认是不是磁盘 I/O 的问题，进而排查相关的进程和磁盘设备。关于磁盘 I/O 的性能问题，你暂且不用专门去背，我会在后续的 I/O 部分详细介绍，到时候理解了也就记住了。

其实除了 iowait，软中断（softirq）CPU 使用率升高也是最常见的一种性能问题。接下来的两节课，我们就来学习软中断的内容，我还会以最常见的反向代理服务器 Nginx 的案例，带你分析这种情况。



### 从“取外卖”看中断

说到中断，我在前面关于“上下文切换”的文章，简单说过中断的含义，先来回顾一下。中断是系统用来响应硬件设备请求的一种机制，它会打断进程的正常调度和执行，然后调用内核中的中断处理程序来响应设备的请求。

你可能要问了，为什么要有中断呢？我可以举个生活中的例子，让你感受一下中断的魅力。

比如说你订了一份外卖，但是不确定外卖什么时候送到，也没有别的方法了解外卖的进度，但是，配送员送外卖是不等人的，到了你这儿没人取的话，就直接走人了。所以你只能苦苦等着，时不时去门口看看外卖送到没，而不能干其他事情。

不过呢，如果在订外卖的时候，你就跟配送员约定好，让他送到后给你打个电话，那你就不用苦苦等待了，就可以去忙别的事情，直到电话一响，接电话、取外卖就可以了。

这里的“打电话”，其实就是一个中断。没接到电话的时候，你可以做其他的事情；只有接到了电话（也就是发生中断），你才要进行另一个动作：取外卖。

这个例子你就可以发现，中断其实是一种异步的事件处理机制，可以提高系统的并发处理能力。

由于中断处理程序会打断其他进程的运行，所以，为了减少对正常进程运行调度的影响，中断处理程序就需要尽可能快地运行。如果中断本身要做的事情不多，那么处理起来也不会有太大问题；但如果中断要处理的事情很多，中断服务程序就有可能要运行很长时间。

特别是，中断处理程序在响应中断时，还会临时关闭中断。这就会导致上一次中断处理完成之前，其他中断都不能响应，也就是说中断有可能会丢失。

那么还是以取外卖为例。假如你订了 2 份外卖，一份主食和一份饮料，并且是由 2 个不同的配送员来配送。这次你不用时时等待着，两份外卖都约定了电话取外卖的方式。但是，问题又来了。

当第一份外卖送到时，配送员给你打了个长长的电话，商量发票的处理方式。与此同时，第二个配送员也到了，也想给你打电话。

但是很明显，因为电话占线（也就是关闭了中断响应），第二个配送员的电话是打不通的。所以，第二个配送员很可能试几次后就走掉了（也就是丢失了一次中断）。



### 软中断

如果你弄清楚了“取外卖”的模式，那对系统的中断机制就很容易理解了。事实上，为了解决中断处理程序执行过长和中断丢失的问题，Linux 将中断处理过程分成了两个阶段，也就是上半部和下半部：

- 上半部用来快速处理中断，它在中断禁止模式下运行，主要处理跟硬件紧密相关的或时间敏感的工作。
- 下半部用来延迟处理上半部未完成的工作，通常以内核线程的方式运行。

比如说前面取外卖的例子，上半部就是你接听电话，告诉配送员你已经知道了，其他事儿见面再说，然后电话就可以挂断了；下半部才是取外卖的动作，以及见面后商量发票处理的动作。

这样，第一个配送员不会占用你太多时间，当第二个配送员过来时，照样能正常打通你的电话。

除了取外卖，我再举个最常见的网卡接收数据包的例子，让你更好地理解。

网卡接收到数据包后，会通过硬件中断的方式，通知内核有新的数据到了。这时，内核就应该调用中断处理程序来响应它。你可以自己先想一下，这种情况下的上半部和下半部分别负责什么工作呢？

对上半部来说，既然是快速处理，其实就是要把网卡的数据读到内存中，然后更新一下硬件寄存器的状态（表示数据已经读好了），最后再发送一个软中断信号，通知下半部做进一步的处理。

而下半部被软中断信号唤醒后，需要从内存中找到网络数据，再按照网络协议栈，对数据进行逐层解析和处理，直到把它送给应用程序。

所以，这两个阶段你也可以这样理解：

- 上半部直接处理硬件请求，也就是我们常说的硬中断，特点是快速执行；
- 而下半部则是由内核触发，也就是我们常说的软中断，特点是延迟执行

实际上，上半部会打断 CPU 正在执行的任务，然后立即执行中断处理程序。而下半部以内核线程的方式执行，并且每个 CPU 都对应一个软中断内核线程，名字为 “ksoftirqd/CPU 编号”，比如说， 0 号 CPU 对应的软中断内核线程的名字就是 ksoftirqd/0。

不过要注意的是，软中断不只包括了刚刚所讲的硬件设备中断处理程序的下半部，一些内核自定义的事件也属于软中断，比如内核调度和 RCU 锁（Read-Copy Update 的缩写，RCU 是 Linux 内核中最常用的锁之一）等。

那要怎么知道你的系统里有哪些软中断呢？



### 查看软中断和内核线程

不知道你还记不记得，前面提到过的 proc 文件系统。它是一种内核空间和用户空间进行通信的机制，可以用来查看内核的数据结构，或者用来动态修改内核的配置。其中：

- /proc/softirqs 提供了软中断的运行情况；
- /proc/interrupts 提供了硬中断的运行情况。

运行下面的命令，查看 /proc/softirqs 文件的内容，你就可以看到各种类型软中断在不同 CPU 上的累积运行次数：

```ruby
$ cat /proc/softirqs
                    CPU0       CPU1
          HI:          0          0
       TIMER:     811613    1972736
      NET_TX:         49          7
      NET_RX:    1136736    1506885
       BLOCK:          0          0
    IRQ_POLL:          0          0
     TASKLET:     304787       3691
       SCHED:     689718    1897539
     HRTIMER:          0          0
         RCU:    1330771    1354737
```

在查看 /proc/softirqs 文件内容时，你要特别注意以下这两点。

第一，要注意软中断的类型，也就是这个界面中第一列的内容。从第一列你可以看到，软中断包括了 10 个类别，分别对应不同的工作类型。比如 NET_RX 表示网络接收中断，而 NET_TX 表示网络发送中断。

第二，要注意同一种软中断在不同 CPU 上的分布情况，也就是同一行的内容。正常情况下，同一种中断在不同 CPU 上的累积次数应该差不多。比如这个界面中，NET_RX 在 CPU0 和 CPU1 上的中断次数基本是同一个数量级，相差不大。

另外，刚刚提到过，软中断实际上是以内核线程的方式运行的，每个 CPU 都对应一个软中断内核线程，这个软中断内核线程就叫做 ksoftirqd/CPU 编号。那要怎么查看这些线程的运行状况呢？

其实用 ps 命令就可以做到，比如执行下面的指令：



```ruby
$ ps aux | grep softirq
root         7  0.0  0.0      0     0 ?        S    Oct10   0:01 [ksoftirqd/0]
root        16  0.0  0.0      0     0 ?        S    Oct10   0:01 [ksoftirqd/1]
```

注意，这些线程的名字外面都有中括号，这说明 ps 无法获取它们的命令行参数（cmline）。一般来说，ps 的输出中，名字括在中括号里的，一般都是内核线程。



### 小结

Linux 中的中断处理程序分为上半部和下半部：

- 上半部对应硬件中断，用来快速处理中断。
- 下半部对应软中断，用来异步处理上半部未完成的工作。

Linux 中的软中断包括网络收发、定时、调度、RCU 锁等各种类型，可以通过查看 /proc/softirqs 来观察软中断的运行情况。



# 软中断使CPU使用率升高


上一期我给你讲了软中断的基本原理，我们先来简单复习下。

中断是一种异步的事件处理机制，用来提高系统的并发处理能力。中断事件发生，会触发执行中断处理程序，而中断处理程序被分为上半部和下半部这两个部分。

- 上半部对应硬中断，用来快速处理中断；
- 下半部对应软中断，用来异步处理上半部未完成的工作。

Linux 中的软中断包括网络收发、定时、调度、RCU 锁等各种类型，我们可以查看 proc 文件系统中的 /proc/softirqs ，观察软中断的运行情况。

在 Linux 中，每个 CPU 都对应一个软中断内核线程，名字是 ksoftirqd/CPU 编号。当软中断事件的频率过高时，内核线程也会因为 CPU 使用率过高而导致软中断处理不及时，进而引发网络收发延迟、调度缓慢等性能问题。

软中断 CPU 使用率过高也是一种最常见的性能问题。今天，我就用最常见的反向代理服务器 Nginx 的案例，教你学会分析这种情况。



### 案例

接下来的案例基于 Ubuntu 18.04，也同样适用于其他的 Linux 系统。我使用的案例环境是这样的：

- 机器配置：2 CPU、8 GB 内存。
- 预先安装 docker、sysstat、sar 、hping3、tcpdump 等工具，比如 apt-get install docker.io sysstat hping3 tcpdump。

这里我又用到了三个新工具，sar、 hping3 和 tcpdump，先简单介绍一下：

- sar 是一个系统活动报告工具，既可以实时查看系统的当前活动，又可以配置保存和报告历史统计数据。
- hping3 是一个可以构造 TCP/IP 协议数据包的工具，可以对系统进行安全审计、防火墙测试等。
- tcpdump 是一个常用的网络抓包工具，常用来分析各种网络问题。

本次案例用到两台虚拟机，我画了一张图来表示它们的关系。



![img](https://upload-images.jianshu.io/upload_images/11345047-1e029143e4114377.png?imageMogr2/auto-orient/strip|imageView2/2/w/1200)

image.png

你可以看到，其中一台虚拟机运行 Nginx ，用来模拟待分析的 Web 服务器；而另一台当作 Web 服务器的客户端，用来给 Nginx 增加压力请求。使用两台虚拟机的目的，是为了相互隔离，避免“交叉感染”。

接下来，我们打开两个终端，分别 SSH 登录到两台机器上，并安装上面提到的这些工具。

同以前的案例一样，下面的所有命令都默认以 root 用户运行，如果你是用普通用户身份登陆系统，请运行 sudo su root 命令切换到 root 用户。



### 操作和分析

安装完成后，我们先在第一个终端，执行下面的命令运行案例，也就是一个最基本的 Nginx 应用：



```ruby
# 运行Nginx服务并对外开放80端口
$ docker run -itd --name=nginx -p 80:80 nginx
```

然后，在第二个终端，使用 curl 访问 Nginx 监听的端口，确认 Nginx 正常启动。假设 192.168.58.99 是 Nginx 所在虚拟机的 IP 地址，运行 curl 命令后你应该会看到下面这个输出界面：



```xml
$ curl http://192.168.58.99/
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
```

接着，还是在第二个终端，我们运行 hping3 命令，来模拟 Nginx 的客户端请求：



```ruby
# -S参数表示设置TCP协议的SYN（同步序列号），-p表示目的端口为80
# -i u100表示每隔100微秒发送一个网络帧
# 注：如果你在实践过程中现象不明显，可以尝试把100调小，比如调成10甚至1
$ hping3 -S -p 80 -i u100 192.168.58.99
```

现在我们再回到第一个终端，你应该发现了异常。是不是感觉系统响应明显变慢了，即便只是在终端中敲几个回车，都得很久才能得到响应？这个时候应该怎么办呢？

虽然在运行 hping3 命令时，我就已经告诉你，这是一个 SYN FLOOD 攻击，你肯定也会想到从网络方面入手，来分析这个问题。不过，在实际的生产环境中，没人直接告诉你原因。

所以，我希望你把 hping3 模拟 SYN FLOOD 这个操作暂时忘掉，然后重新从观察到的问题开始，分析系统的资源使用情况，逐步找出问题的根源。

那么，该从什么地方入手呢？刚才我们发现，简单的 SHELL 命令都明显变慢了，先看看系统的整体资源使用情况应该是个不错的注意，比如执行下 top 看看是不是出现了 CPU 的瓶颈。我们在第一个终端运行 top 命令，看一下系统整体的资源使用情况。



```objectivec
# top运行后按数字1切换到显示所有CPU
$ top
top - 10:50:58 up 1 days, 22:10,  1 user,  load average: 0.00, 0.00, 0.00
Tasks: 122 total,   1 running,  71 sleeping,   0 stopped,   0 zombie
%Cpu0  :  0.0 us,  0.0 sy,  0.0 ni, 96.7 id,  0.0 wa,  0.0 hi,  3.3 si,  0.0 st
%Cpu1  :  0.0 us,  0.0 sy,  0.0 ni, 95.6 id,  0.0 wa,  0.0 hi,  4.4 si,  0.0 st
...

  PID USER      PR  NI    VIRT    RES    SHR S  %CPU %MEM     TIME+ COMMAND
    7 root      20   0       0      0      0 S   0.3  0.0   0:01.64 ksoftirqd/0
   16 root      20   0       0      0      0 S   0.3  0.0   0:01.97 ksoftirqd/1
 2663 root      20   0  923480  28292  13996 S   0.3  0.3   4:58.66 docker-containe
 3699 root      20   0       0      0      0 I   0.3  0.0   0:00.13 kworker/u4:0
 3708 root      20   0   44572   4176   3512 R   0.3  0.1   0:00.07 top
    1 root      20   0  225384   9136   6724 S   0.0  0.1   0:23.25 systemd
    2 root      20   0       0      0      0 S   0.0  0.0   0:00.03 kthreadd
...
```

这里你有没有发现异常的现象？我们从第一行开始，逐个看一下：

- 平均负载全是 0，就绪队列里面只有一个进程（1 running）。
- 每个 CPU 的使用率都挺低，最高的 CPU1 的使用率也只有 4.4%，并不算高。
- 再看进程列表，CPU 使用率最高的进程也只有 0.3%，还是不高呀。

那为什么系统的响应变慢了呢？既然每个指标的数值都不大，那我们就再来看看，这些指标对应的更具体的含义。毕竟，哪怕是同一个指标，用在系统的不同部位和场景上，都有可能对应着不同的性能问题。

仔细看 top 的输出，两个 CPU 的使用率虽然分别只有 3.3% 和 4.4%，但都用在了软中断上；而从进程列表上也可以看到，CPU 使用率最高的也是软中断进程 ksoftirqd。看起来，软中断有点可疑了。

根据上一期的内容，既然软中断可能有问题，那你先要知道，究竟是哪类软中断的问题。停下来想想，上一节我们用了什么方法，来判断软中断类型呢？没错，还是 proc 文件系统。观察 /proc/softirqs 文件的内容，你就能知道各种软中断类型的次数。

不过，这里的各类软中断次数，又是什么时间段里的次数呢？它是系统运行以来的累积中断次数。所以我们直接查看文件内容，得到的只是累积中断次数，对这里的问题并没有直接参考意义。因为，这些中断次数的变化速率才是我们需要关注的。

那什么工具可以观察命令输出的变化情况呢？我想你应该想起来了，在前面案例中用过的 watch 命令，就可以定期运行一个命令来查看输出；如果再加上 -d 参数，还可以高亮出变化的部分，从高亮部分我们就可以直观看出，哪些内容变化得更快。

比如，还是在第一个终端，我们运行下面的命令：



```ruby
$ watch -d cat /proc/softirqs
                    CPU0       CPU1
          HI:          0          0
       TIMER:    1083906    2368646
      NET_TX:         53          9
      NET_RX:    1550643    1916776
       BLOCK:          0          0
    IRQ_POLL:          0          0
     TASKLET:     333637       3930
       SCHED:     963675    2293171
     HRTIMER:          0          0
         RCU:    1542111    1590625
```

通过 /proc/softirqs 文件内容的变化情况，你可以发现， TIMER（定时中断）、NET_RX（网络接收）、SCHED（内核调度）、RCU（RCU 锁）等这几个软中断都在不停变化。

其中，NET_RX，也就是网络数据包接收软中断的变化速率最快。而其他几种类型的软中断，是保证 Linux 调度、时钟和临界区保护这些正常工作所必需的，所以它们有一定的变化倒是正常的。

那么接下来，我们就从网络接收的软中断着手，继续分析。既然是网络接收的软中断，第一步应该就是观察系统的网络接收情况。这里你可能想起了很多网络工具，不过，我推荐今天的主人公工具 sar 。

sar 可以用来查看系统的网络收发情况，还有一个好处是，不仅可以观察网络收发的吞吐量（BPS，每秒收发的字节数），还可以观察网络收发的 PPS，即每秒收发的网络帧数。

我们在第一个终端中运行 sar 命令，并添加 -n DEV 参数显示网络收发的报告：



```ruby
# -n DEV 表示显示网络收发的报告，间隔1秒输出一组数据
$ sar -n DEV 1
15:03:46        IFACE   rxpck/s   txpck/s    rxkB/s    txkB/s   rxcmp/s   txcmp/s  rxmcst/s   %ifutil
15:03:47         eth0  12607.00   6304.00    664.86    358.11      0.00      0.00      0.00      0.01
15:03:47      docker0   6302.00  12604.00    270.79    664.66      0.00      0.00      0.00      0.00
15:03:47           lo      0.00      0.00      0.00      0.00      0.00      0.00      0.00      0.00
15:03:47    veth9f6bbcd   6302.00  12604.00    356.95    664.66      0.00      0.00      0.00      0.05
```

对于 sar 的输出界面，我先来简单介绍一下，从左往右依次是：

- 第一列：表示报告的时间。
- 第二列：IFACE 表示网卡。
- 第三、四列：rxpck/s 和 txpck/s 分别表示每秒接收、发送的网络帧数，也就是 PPS。
- 第五、六列：rxkB/s 和 txkB/s 分别表示每秒接收、发送的千字节数，也就是 BPS。
- 后面的其他参数基本接近 0，显然跟今天的问题没有直接关系，你可以先忽略掉。

我们具体来看输出的内容，你可以发现：

- 对网卡 eth0 来说，每秒接收的网络帧数比较大，达到了 12607，而发送的网络帧数则比较小，只有 6304；每秒接收的千字节数只有 664 KB，而发送的千字节数更小，只有 358 KB。
- docker0 和 veth9f6bbcd 的数据跟 eth0 基本一致，只是发送和接收相反，发送的数据较大而接收的数据较小。这是 Linux 内部网桥转发导致的，你暂且不用深究，只要知道这是系统把 eth0 收到的包转发给 Nginx 服务即可。具体工作原理，我会在后面的网络部分详细介绍。

从这些数据，你有没有发现什么异常的地方？

既然怀疑是网络接收中断的问题，我们还是重点来看 eth0 ：接收的 PPS 比较大，达到 12607，而接收的 BPS 却很小，只有 664 KB。直观来看网络帧应该都是比较小的，我们稍微计算一下，664 * 1024/12607 = 54 字节，说明平均每个网络帧只有 54 字节，这显然是很小的网络帧，也就是我们通常所说的小包问题。

那么，有没有办法知道这是一个什么样的网络帧，以及从哪里发过来的呢？

使用 tcpdump 抓取 eth0 上的包就可以了。我们事先已经知道， Nginx 监听在 80 端口，它所提供的 HTTP 服务是基于 TCP 协议的，所以我们可以指定 TCP 协议和 80 端口精确抓包。

接下来，我们在第一个终端中运行 tcpdump 命令，通过 -i eth0 选项指定网卡 eth0，并通过 tcp port 80 选项指定 TCP 协议的 80 端口：



```ruby
# -i eth0 只抓取eth0网卡，-n不解析协议名和主机名
# tcp port 80表示只抓取tcp协议并且端口号为80的网络帧
$ tcpdump -i eth0 -n tcp port 80
15:11:32.678966 IP 192.168.0.2.18238 > 192.168.0.30.80: Flags [S], seq 458303614, win 512, length 0
...
```

从 tcpdump 的输出中，你可以发现

- 192.168.0.2.18238 > 192.168.0.30.80 ，表示网络帧从 192.168.0.2 的 18238 端口发送到 192.168.0.30 的 80 端口，也就是从运行 hping3 机器的 18238 端口发送网络帧，目的为 Nginx 所在机器的 80 端口。
- Flags [S] 则表示这是一个 SYN 包。

再加上前面用 sar 发现的， PPS 超过 12000 的现象，现在我们可以确认，这就是从 192.168.0.2 这个地址发送过来的 SYN FLOOD 攻击。

到这里，我们已经做了全套的性能诊断和分析。从系统的软中断使用率高这个现象出发，通过观察 /proc/softirqs 文件的变化情况，判断出软中断类型是网络接收中断；再通过 sar 和 tcpdump ，确认这是一个 SYN FLOOD 问题。

SYN FLOOD 问题最简单的解决方法，就是从交换机或者硬件防火墙中封掉来源 IP，这样 SYN FLOOD 网络帧就不会发送到服务器中。

案例结束后，也不要忘了收尾，记得停止最开始启动的 Nginx 服务以及 hping3 命令。

在第一个终端中，运行下面的命令就可以停止 Nginx 了：



```ruby
# 停止 Nginx 服务
$ docker rm -f nginx
```

#### 小结

软中断 CPU 使用率（softirq）升高是一种很常见的性能问题。虽然软中断的类型很多，但实际生产中，我们遇到的性能瓶颈大多是网络收发类型的软中断，特别是网络接收的软中断。

在碰到这类问题时，你可以借用 sar、tcpdump 等工具，做进一步分析。

有同学说在查看软中断数据时会显示128个核的数据，我的也是，虽然只有一个核，但是会显示128个核的信息，用下面的命令可以提取有数据的核，我的1核，所以这个命令只能显示1核，多核需要做下修改
```
watch -d "/bin/cat /proc/softirqs | /usr/bin/awk 'NR == 1{printf "%13s %s\n"," ",$1}; NR > 1{printf "%13s %s\n",$1,$2}'"
```
