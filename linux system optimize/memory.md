# Linux内存工作原理


同 CPU 管理一样，内存管理也是操作系统最核心的功能之一。内存主要用来存储系统和应用程序的指令、数据、缓存等。

那么，Linux 到底是怎么管理内存的呢？今天，我就来带你一起来看看这个问题。



### 内存映射

说到内存，你能说出你现在用的这台计算机内存有多大吗？我估计你记得很清楚，因为这是我们购买时，首先考虑的一个重要参数，比方说，我的笔记本电脑内存就是 8GB 的 。

我们通常所说的内存容量，就像我刚刚提到的 8GB，其实指的是物理内存。物理内存也称为主存，大多数计算机用的主存都是动态随机访问内存（DRAM）。只有内核才可以直接访问物理内存。那么，进程要访问内存时，该怎么办呢？

Linux 内核给每个进程都提供了一个独立的虚拟地址空间，并且这个地址空间是连续的。这样，进程就可以很方便地访问内存，更确切地说是访问虚拟内存。

虚拟地址空间的内部又被分为内核空间和用户空间两部分，不同字长（也就是单个 CPU 指令可以处理数据的最大长度）的处理器，地址空间的范围也不同。比如最常见的 32 位和 64 位系统，我画了两张图来分别表示它们的虚拟地址空间，如下所示：

![img](https://upload-images.jianshu.io/upload_images/11345047-7110895d4564dd0f.png?imageMogr2/auto-orient/strip|imageView2/2/w/1004)

通过这里可以看出，32 位系统的内核空间占用 1G，位于最高处，剩下的 3G 是用户空间。而 64 位系统的内核空间和用户空间都是 128T，分别占据整个内存空间的最高和最低处，剩下的中间部分是未定义的。

还记得进程的用户态和内核态吗？进程在用户态时，只能访问用户空间内存；只有进入内核态后，才可以访问内核空间内存。虽然每个进程的地址空间都包含了内核空间，但这些内核空间，其实关联的都是相同的物理内存。这样，进程切换到内核态后，就可以很方便地访问内核空间内存。

既然每个进程都有一个这么大的地址空间，那么所有进程的虚拟内存加起来，自然要比实际的物理内存大得多。所以，并不是所有的虚拟内存都会分配物理内存，只有那些实际使用的虚拟内存才分配物理内存，并且分配后的物理内存，是通过内存映射来管理的。

**内存映射，其实就是将虚拟内存地址映射到物理内存地址。**为了完成内存映射，内核为每个进程都维护了一张页表，记录虚拟地址与物理地址的映射关系，如下图所示：

![img](https://upload-images.jianshu.io/upload_images/11345047-613d82c2dd79a6ca.png?imageMogr2/auto-orient/strip|imageView2/2/w/572)

页表实际上存储在 CPU 的内存管理单元 MMU 中，这样，正常情况下，处理器就可以直接通过硬件，找出要访问的内存。

而当进程访问的虚拟地址在页表中查不到时，系统会产生一个缺页异常，进入内核空间分配物理内存、更新进程页表，最后再返回用户空间，恢复进程的运行。

不过要注意，MMU 并不以字节为单位来管理内存，而是规定了一个内存映射的最小单位，也就是页，通常是 4 KB 大小。这样，每一次内存映射，都需要关联 4 KB 或者 4KB 整数倍的内存空间。

的大小只有 4 KB ，导致的另一个问题就是，整个页表会变得非常大。比方说，仅 32 位系统就需要 100 多万个页表项（4GB/4KB），才可以实现整个地址空间的映射。为了解决页表项过多的问题，Linux 提供了两种机制，也就是多级页表和大页（HugePage）。

多级页表就是把内存分成区块来管理，将原来的映射关系改成区块索引和区块内的偏移。由于虚拟内存空间通常只用了很少一部分，那么，多级页表就只保存这些使用中的区块，这样就可以大大地减少页表的项数。

Linux 用的正是四级页表来管理内存页，如下图所示，虚拟地址被分为 5 个部分，前 4 个表项用于选择页，而最后一个索引表示页内偏移。

![img](https://upload-images.jianshu.io/upload_images/11345047-7c07650fc95a5bc0.png?imageMogr2/auto-orient/strip|imageView2/2/w/1200)

再看大页，顾名思义，就是比普通页更大的内存块，常见的大小有 2MB 和 1GB。大页通常用在使用大量内存的进程上，比如 Oracle、DPDK 等。

通过这些机制，在页表的映射下，进程就可以通过虚拟地址来访问物理内存了。那么具体到一个 Linux 进程中，这些内存又是怎么使用的呢？

### 虚拟内存空间分布

首先，我们需要进一步了解虚拟内存空间的分布情况。最上方的内核空间不用多讲，下方的用户空间内存，其实又被分成了多个不同的段。以 32 位系统为例，我画了一张图来表示它们的关系。

![img](https://upload-images.jianshu.io/upload_images/11345047-927089257c8a7188.png?imageMogr2/auto-orient/strip|imageView2/2/w/266)

通过这张图你可以看到，用户空间内存，从低到高分别是五种不同的内存段。

1. 只读段，包括代码和常量等。
2. 数据段，包括全局变量等。
3. 堆，包括动态分配的内存，从低地址开始向上增长。
4. 文件映射段，包括动态库、共享内存等，从高地址开始向下增长。
5. 栈，包括局部变量和函数调用的上下文等。栈的大小是固定的，一般是 8 MB。

在这五个内存段中，堆和文件映射段的内存是动态分配的。比如说，使用 C 标准库的 malloc() 或者 mmap() ，就可以分别在堆和文件映射段动态分配内存。

其实 64 位系统的内存分布也类似，只不过内存空间要大得多。那么，更重要的问题来了，内存究竟是怎么分配的呢？



### 内存分配与回收

malloc() 是 C 标准库提供的内存分配函数，对应到系统调用上，有两种实现方式，即 brk() 和 mmap()。

对小块内存（小于 128K），C 标准库使用 brk() 来分配，也就是通过移动堆顶的位置来分配内存。这些内存释放后并不会立刻归还系统，而是被缓存起来，这样就可以重复使用。

而大块内存（大于 128K），则直接使用内存映射 mmap() 来分配，也就是在文件映射段找一块空闲内存分配出去。

这两种方式，自然各有优缺点。

brk() 方式的缓存，可以减少缺页异常的发生，提高内存访问效率。不过，由于这些内存没有归还系统，在内存工作繁忙时，频繁的内存分配和释放会造成内存碎片。

而 mmap() 方式分配的内存，会在释放时直接归还系统，所以每次 mmap 都会发生缺页异常。在内存工作繁忙时，频繁的内存分配会导致大量的缺页异常，使内核的管理负担增大。这也是 malloc 只对大块内存使用 mmap 的原因。

了解这两种调用方式后，我们还需要清楚一点，那就是，当这两种调用发生后，其实并没有真正分配内存。这些内存，都只在首次访问时才分配，也就是通过缺页异常进入内核中，再由内核来分配内存。

整体来说，Linux 使用伙伴系统来管理内存分配。前面我们提到过，这些内存在 MMU 中以页为单位进行管理，伙伴系统也一样，以页为单位来管理内存，并且会通过相邻页的合并，减少内存碎片化（比如 brk 方式造成的内存碎片）。

你可能会想到一个问题，如果遇到比页更小的对象，比如不到 1K 的时候，该怎么分配内存呢？

实际系统运行中，确实有大量比页还小的对象，如果为它们也分配单独的页，那就太浪费内存了。

所以，在用户空间，malloc 通过 brk() 分配的内存，在释放时并不立即归还系统，而是缓存起来重复利用。在内核空间，Linux 则通过 slab 分配器来管理小内存。你可以把 slab 看成构建在伙伴系统上的一个缓存，主要作用就是分配并释放内核中的小对象。

对内存来说，如果只分配而不释放，就会造成内存泄漏，甚至会耗尽系统内存。所以，在应用程序用完内存后，还需要调用 free() 或 unmap() ，来释放这些不用的内存。

当然，系统也不会任由某个进程用完所有内存。在发现内存紧张时，系统就会通过一系列机制来回收内存，比如下面这三种方式：

1. 回收缓存，比如使用 LRU（Least Recently Used）算法，回收最近使用最少的内存页面；
2. 回收不常访问的内存，把不常用的内存通过交换分区直接写到磁盘中；
3. 杀死进程，内存紧张时系统还会通过 OOM（Out of Memory），直接杀掉占用大量内存的进程。

其中，第二种方式回收不常访问的内存时，会用到交换分区（以下简称 Swap）。Swap 其实就是把一块磁盘空间当成内存来用。它可以把进程暂时不用的数据存储到磁盘中（这个过程称为换出），当进程访问这些内存时，再从磁盘读取这些数据到内存中（这个过程称为换入）。

第三种方式提到的 OOM（Out of Memory），其实是内核的一种保护机制。它监控进程的内存使用情况，并且使用 oom_score 为每个进程的内存使用情况进行评分：

- 一个进程消耗的内存越大，oom_score 就越大；
- 一个进程运行占用的 CPU 越多，oom_score 就越小。

这样，进程的 oom_score 越大，代表消耗的内存越多，也就越容易被 OOM 杀死，从而可以更好保护系统。

当然，为了实际工作的需要，管理员可以通过 /proc 文件系统，手动设置进程的 oom_adj ，从而调整进程的 oom_score。

oom_adj 的范围是 [-17, 15]，数值越大，表示进程越容易被 OOM 杀死；数值越小，表示进程越不容易被 OOM 杀死，其中 -17 表示禁止 OOM。

比如用下面的命令，你就可以把 sshd 进程的 oom_adj 调小为 -16，这样， sshd 进程就不容易被 OOM 杀死。

```jsx
echo -16 > /proc/$(pidof sshd)/oom_adj
```

### 如何查看内存使用情况

通过了解内存空间的分布，以及内存的分配和回收，我想你对内存的工作原理应该有了大概的认识。当然，系统的实际工作原理更加复杂，也会涉及其他一些机制，这里只讲了最主要的原理。

那么在了解内存的工作原理之后，该怎么查看系统内存使用情况呢？

其实前面 CPU 内容的学习中，也提到过一些相关工具。在这里，你第一个想到的应该是 free 工具吧。下面是一个 free 的输出示例：

```cpp
# 注意不同版本的free输出可能会有所不同
$ free
              total        used        free      shared  buff/cache   available
Mem:        8169348      263524     6875352         668     1030472     7611064
Swap:             0           0           0
```

你可以看到，free 输出的是一个表格，其中的数值都默认以字节为单位。表格总共有两行六列，这两行分别是物理内存 Mem 和交换分区 Swap 的使用情况，而六列中，每列数据的含义分别为：

>  第一列，total 是总内存大小；
> 	第二列，used 是已使用内存的大小，包含了共享内存；
> 	第三列，free 是未使用内存的大小；
> 	第四列，shared 是共享内存的大小；
> 	第五列，buff/cache 是缓存和缓冲区的大小；
> 	最后一列，available 是新进程可用内存的大小。

这里尤其注意一下，最后一列的可用内存 available 。available 不仅包含未使用内存，还包括了可回收的缓存，所以一般会比未使用内存更大。不过，并不是所有缓存都可以回收，因为有些缓存可能正在使用中。

不过，我们知道，free 显示的是整个系统的内存使用情况。如果你想查看进程的内存使用情况，可以用 top 或者 ps 等工具。比如，下面是 top 的输出示例：

```cpp
# 按下M切换到内存排序
$ top
...
KiB Mem :  8169348 total,  6871440 free,   267096 used,  1030812 buff/cache
KiB Swap:        0 total,        0 free,        0 used.  7607492 avail Mem


  PID USER      PR  NI    VIRT    RES    SHR S  %CPU %MEM     TIME+ COMMAND
  430 root      19  -1  122360  35588  23748 S   0.0  0.4   0:32.17 systemd-journal
 1075 root      20   0  771860  22744  11368 S   0.0  0.3   0:38.89 snapd
 1048 root      20   0  170904  17292   9488 S   0.0  0.2   0:00.24 networkd-dispat
    1 root      20   0   78020   9156   6644 S   0.0  0.1   0:22.92 systemd
12376 azure     20   0   76632   7456   6420 S   0.0  0.1   0:00.01 systemd
12374 root      20   0  107984   7312   6304 S   0.0  0.1   0:00.00 sshd
...
```

top 输出界面的顶端，也显示了系统整体的内存使用情况，这些数据跟 free 类似，我就不再重复解释。我们接着看下面的内容，跟内存相关的几列数据，比如 VIRT、RES、SHR 以及 %MEM 等。

这些数据，包含了进程最重要的几个内存使用情况。

- VIRT 是进程虚拟内存的大小，只要是进程申请过的内存，即便还没有真正分配物理内存，也会计算在内。
- RES`(resident memory)` 是常驻内存的大小，也就是进程实际使用的物理内存大小，但不包括 Swap 和共享内存。
- SHR 是共享内存的大小，比如与其他进程共同使用的共享内存、加载的动态链接库以及程序的代码段等。
- MEM 是进程使用物理内存占系统总内存的百分比。

除了要认识这些基本信息，在查看 top 输出时，你还要注意两点。

- 第一，虚拟内存通常并不会全部分配物理内存。从上面的输出，你可以发现每个进程的虚拟内存都比常驻内存大得多。
- 第二，共享内存 SHR 并不一定是共享的，比方说，程序的代码段、非共享的动态链接库，也都算在 SHR 里。当然，SHR 也包括了进程间真正共享的内存。所以在计算多个进程的内存使用时，不要把所有进程的 SHR 直接相加得出结果。

#### 小结

今天，我们梳理了 Linux 内存的工作原理。对普通进程来说，它能看到的其实是内核提供的虚拟内存，这些虚拟内存还需要通过页表，由系统映射为物理内存。

当进程通过 malloc() 申请内存后，内存并不会立即分配，而是在首次访问时，才通过缺页异常陷入内核中分配内存。

由于进程的虚拟地址空间比物理内存大很多，Linux 还提供了一系列的机制，应对内存不足的问题，比如缓存的回收、交换分区 Swap 以及 OOM 等。

当你需要了解系统或者进程的内存使用情况时，可以用 free 和 top 、ps 等性能工具。它们都是分析性能问题时最常用的性能工具，希望你能熟练使用它们，并真正理解各个指标的含义。



# 理解内存中的Buffer和Cache

上一节，我们梳理了 Linux 内存管理的基本原理，并学会了用 free 和 top 等工具，来查看系统和进程的内存使用情况。

内存和 CPU 的关系非常紧密，而内存管理本身也是很复杂的机制，所以感觉知识很硬核、很难啃，都是正常的。但还是那句话，初学时不用非得理解所有内容，继续往后学，多理解相关的概念并配合一定的实践之后，再回头复习往往会容易不少。当然，基本功不容放弃。

在今天的内容开始之前，我们先来回顾一下系统的内存使用情况，比如下面这个 free 输出界面：

```cpp
# 注意不同版本的free输出可能会有所不同
$ free
              total        used        free      shared  buff/cache   available
Mem:        8169348      263524     6875352         668     1030472     7611064
Swap:             0           0           0
```

显然，这个界面包含了物理内存 Mem 和交换分区 Swap 的具体使用情况，比如总内存、已用内存、缓存、可用内存等。其中缓存是 Buffer 和 Cache 两部分的总和 。

这里的大部分指标都比较容易理解，但 Buffer 和 Cache 可能不太好区分。从字面上来说，Buffer 是缓冲区，而 Cache 是缓存，两者都是数据在内存中的临时存储。那么，你知道这两种“临时存储”有什么区别吗？

注：今天内容接下来的部分，Buffer 和 Cache 我会都用英文来表示，避免跟文中的“缓存”一词混淆。而文中的“缓存”，则通指内存中的临时存储。



### free 数据的来源

在我正式讲解两个概念前，你可以先想想，你有没有什么途径来进一步了解它们？除了中文翻译直接得到概念，别忘了，Buffer 和 Cache 还是我们用 free 获得的指标。

用 man 命令查询 free 的文档，就可以找到对应指标的详细说明。比如，我们执行 man free ，就可以看到下面这个界面。

```csharp
buffers
              Memory used by kernel buffers (Buffers in /proc/meminfo)

       cache  Memory used by the page cache and slabs (Cached and SReclaimable in /proc/meminfo)

       buff/cache
              Sum of buffers and cache
```

从 free 的手册中，你可以看到 buffer 和 cache 的说明。

1. Buffers 是内核缓冲区用到的内存，对应的是 /proc/meminfo 中的 Buffers 值。
2. Cache 是内核页缓存和 Slab 用到的内存，对应的是 /proc/meminfo 中的 Cached 与 SReclaimable 之和。

这些数值都来自 /proc/meminfo，但更具体的 Buffers、Cached 和 SReclaimable 的含义，还是没有说清楚。



#### proc 文件系统

我在前面 CPU 性能模块就曾经提到过，/proc 是 Linux 内核提供的一种特殊文件系统，是用户跟内核交互的接口。比方说，用户可以从 /proc 中查询内核的运行状态和配置选项，查询进程的运行状态、统计数据等，当然，你也可以通过 /proc 来修改内核的配置。

proc 文件系统同时也是很多性能工具的最终数据来源。比如我们刚才看到的 free ，就是通过读取 /proc/meminfo ，得到内存的使用情况。

继续说回 /proc/meminfo，既然 Buffers、Cached、SReclaimable 这几个指标不容易理解，那我们还得继续查 proc 文件系统，获取它们的详细定义。

执行 man proc ，你就可以得到 proc 文件系统的详细文档。

注意这个文档比较长，你最好搜索一下（比如搜索 meminfo），以便更快定位到内存部分。

```php
Buffers %lu
    Relatively temporary storage for raw disk blocks that shouldn't get tremendously large (20MB or so).

Cached %lu
   In-memory cache for files read from the disk (the page cache).  Doesn't include SwapCached.
...
SReclaimable %lu (since Linux 2.6.19)
    Part of Slab, that might be reclaimed, such as caches.
    
SUnreclaim %lu (since Linux 2.6.19)
    Part of Slab, that cannot be reclaimed on memory pressure.
```

通过这个文档，我们可以看到：

- Buffers 是对原始磁盘块的临时存储，也就是用来缓存磁盘的数据，通常不会特别大（20MB 左右）。这样，内核就可以把分散的写集中起来，统一优化磁盘的写入，比如可以把多次小的写合并成单次大的写等等。
- Cached 是从磁盘读取文件的页缓存，也就是用来缓存从文件读取的数据。这样，下次访问这些文件数据时，就可以直接从内存中快速获取，而不需要再次访问缓慢的磁盘。
- SReclaimable 是 Slab 的一部分。Slab 包括两部分，其中的可回收部分，用 SReclaimable 记录；而不可回收部分，用 SUnreclaim 记录。

好了，我们终于找到了这三个指标的详细定义。到这里，你是不是长舒一口气，满意地想着，总算弄明白 Buffer 和 Cache 了。不过，知道这个定义就真的理解了吗？这里我给你提了两个问题，你先想想能不能回答出来。

第一个问题，Buffer 的文档没有提到这是磁盘读数据还是写数据的缓存，而在很多网络搜索的结果中都会提到 Buffer 只是对将要写入磁盘数据的缓存。那反过来说，它会不会也缓存从磁盘中读取的数据呢？

第二个问题，文档中提到，Cache 是对从文件读取数据的缓存，那么它是不是也会缓存写文件的数据呢？

为了解答这两个问题，接下来，我将用几个案例来展示， Buffer 和 Cache 在不同场景下的使用情况。



#### 案例

预先安装 sysstat 包，如 apt install sysstat。

之所以要安装 sysstat ，是因为我们要用到 vmstat ，来观察 Buffer 和 Cache 的变化情况。虽然从 /proc/meminfo 里也可以读到相同的结果，但毕竟还是 vmstat 的结果更加直观。

另外，这几个案例使用了 dd 来模拟磁盘和文件的 I/O，所以我们也需要观测 I/O 的变化情况。

上面的工具安装完成后，你可以打开两个终端，连接到机器上。

准备环节的最后一步，为了减少缓存的影响，记得在第一个终端中，运行下面的命令来清理系统缓存：

```ruby
# 清理文件页、目录项、Inodes等各种缓存
$ echo 3 > /proc/sys/vm/drop_caches
```

这里的 /proc/sys/vm/drop_caches ，就是通过 proc 文件系统修改内核行为的一个示例，写入 3 表示清理文件页、目录项、Inodes 等各种缓存。这几种缓存的区别，后面都会讲到。

#### 场景 1：磁盘和文件写案例

先来模拟第一个场景。首先，在第一个终端，运行下面这个 vmstat 命令：

```objectivec
# 每隔1秒输出1组数据
$ vmstat 1
procs -----------memory---------- ---swap-- -----io---- -system-- ------cpu-----
r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
0  0      0 7743608   1112  92168    0    0     0     0   52  152  0  1 100  0  0
 0  0      0 7743608   1112  92168    0    0     0     0   36   92  0  0 100  0  0
```

输出界面里， 内存部分的 buff 和 cache ，以及 io 部分的 bi 和 bo 就是我们要关注的重点。

- buff 和 cache 就是我们前面看到的 Buffers 和 Cache，单位是 KB。
- bi 和 bo 则分别表示块设备读取和写入的大小，单位为块 / 秒。因为 Linux 中块的大小是 1KB，所以这个单位也就等价于 KB/s。

接下来，到第二个终端执行 dd 命令，通过读取随机设备，生成一个 500MB 大小的文件：

```ruby
$ dd if=/dev/urandom of=/tmp/file bs=1M count=500
```

然后再回到第一个终端，观察 Buffer 和 Cache 的变化情况：

```cpp
procs -----------memory---------- ---swap-- -----io---- -system-- ------cpu-----
r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
0  0      0 7499460   1344 230484    0    0     0     0   29  145  0  0 100  0  0
 1  0      0 7338088   1752 390512    0    0   488     0   39  558  0 47 53  0  0
 1  0      0 7158872   1752 568800    0    0     0     4   30  376  1 50 49  0  0
 1  0      0 6980308   1752 747860    0    0     0     0   24  360  0 50 50  0  0
 0  0      0 6977448   1752 752072    0    0     0     0   29  138  0  0 100  0  0
 0  0      0 6977440   1760 752080    0    0     0   152   42  212  0  1 99  1  0
...
 0  1      0 6977216   1768 752104    0    0     4 122880   33  234  0  1 51 49  0
 0  1      0 6977440   1768 752108    0    0     0 10240   38  196  0  0 50 50  0
```

通过观察 vmstat 的输出，我们发现，在 dd 命令运行时， Cache 在不停地增长，而 Buffer 基本保持不变。

再进一步观察 I/O 的情况，你会看到，

- 在 Cache 刚开始增长时，块设备 I/O 很少，bi 只出现了一次 488 KB/s，bo 则只有一次 4KB。而过一段时间后，才会出现大量的块设备写，比如 bo 变成了 122880。
- 当 dd 命令结束后，Cache 不再增长，但块设备写还会持续一段时间，并且，多次 I/O 写的结果加起来，才是 dd 要写的 500M 的数据。

把这个结果，跟我们刚刚了解到的 Cache 的定义做个对比，你可能会有点晕乎。为什么前面文档上说 Cache 是文件读的页缓存，怎么现在写文件也有它的份？

这个疑问，我们暂且先记下来，接着再来看另一个磁盘写的案例。两个案例结束后，我们再统一进行分析。

不过，对于接下来的案例，我必须强调一点：

下面的命令对环境要求很高，需要你的系统配置多块磁盘，并且磁盘分区 /dev/sdb1 还要处于未使用状态。如果你只有一块磁盘，千万不要尝试，否则将会对你的磁盘分区造成损坏。

如果你的系统符合标准，就可以继续在第二个终端中，运行下面的命令。清理缓存后，向磁盘分区 /dev/sdb1 写入 2GB 的随机数据：

```ruby
# 首先清理缓存
$ echo 3 > /proc/sys/vm/drop_caches
# 然后运行dd命令向磁盘分区/dev/sdb1写入2G数据
$ dd if=/dev/urandom of=/dev/sdb1 bs=1M count=2048
```

然后，再回到终端一，观察内存和 I/O 的变化情况：

```cpp
procs -----------memory---------- ---swap-- -----io---- -system-- ------cpu-----
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
1  0      0 7584780 153592  97436    0    0   684     0   31  423  1 48 50  2  0
 1  0      0 7418580 315384 101668    0    0     0     0   32  144  0 50 50  0  0
 1  0      0 7253664 475844 106208    0    0     0     0   20  137  0 50 50  0  0
 1  0      0 7093352 631800 110520    0    0     0     0   23  223  0 50 50  0  0
 1  1      0 6930056 790520 114980    0    0     0 12804   23  168  0 50 42  9  0
 1  0      0 6757204 949240 119396    0    0     0 183804   24  191  0 53 26 21  0
 1  1      0 6591516 1107960 123840    0    0     0 77316   22  232  0 52 16 33  0
```

从这里你会看到，虽然同是写数据，写磁盘跟写文件的现象还是不同的。写磁盘时（也就是 bo 大于 0 时），Buffer 和 Cache 都在增长，但显然 Buffer 的增长快得多。

这说明，写磁盘用到了大量的 Buffer，这跟我们在文档中查到的定义是一样的。

对比两个案例，我们发现，**写文件时会用到 Cache 缓存数据，而写磁盘则会用到 Buffer 来缓存数据。**所以，回到刚刚的问题，虽然文档上只提到，Cache 是文件读的缓存，但实际上，Cache 也会缓存写文件时的数据。



#### 场景 2：磁盘和文件读案例

了解了磁盘和文件写的情况，我们再反过来想，磁盘和文件读的时候，又是怎样的呢？

我们回到第二个终端，运行下面的命令。清理缓存后，从文件 /tmp/file 中，读取数据写入空设备：

```ruby
# 首先清理缓存
$ echo 3 > /proc/sys/vm/drop_caches
# 运行dd命令读取文件数据
$ dd if=/tmp/file of=/dev/null
```

然后，再回到终端一，观察内存和 I/O 的变化情况：

```cpp
procs -----------memory---------- ---swap-- -----io---- -system-- ------cpu-----
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
 0  1      0 7724164   2380 110844    0    0 16576     0   62  360  2  2 76 21  0
 0  1      0 7691544   2380 143472    0    0 32640     0   46  439  1  3 50 46  0
 0  1      0 7658736   2380 176204    0    0 32640     0   54  407  1  4 50 46  0
 0  1      0 7626052   2380 208908    0    0 32640    40   44  422  2  2 50 46  0
```

观察 vmstat 的输出，你会发现读取文件时（也就是 bi 大于 0 时），Buffer 保持不变，而 Cache 则在不停增长。说明: **“Cache 是对文件读的页缓存”和定义是一致的。**

那么，磁盘读又是什么情况呢？我们再运行第二个案例来看看。

首先，回到第二个终端，运行下面的命令。清理缓存后，从磁盘分区 /dev/sda1 中读取数据，写入空设备：

```ruby
# 首先清理缓存
$ echo 3 > /proc/sys/vm/drop_caches
# 运行dd命令读取文件
$ dd if=/dev/sda1 of=/dev/null bs=1M count=1024
```

然后，再回到终端一，观察内存和 I/O 的变化情况：

```cpp
procs -----------memory---------- ---swap-- -----io---- -system-- ------cpu-----
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
0  0      0 7225880   2716 608184    0    0     0     0   48  159  0  0 100  0  0
 0  1      0 7199420  28644 608228    0    0 25928     0   60  252  0  1 65 35  0
 0  1      0 7167092  60900 608312    0    0 32256     0   54  269  0  1 50 49  0
 0  1      0 7134416  93572 608376    0    0 32672     0   53  253  0  0 51 49  0
 0  1      0 7101484 126320 608480    0    0 32748     0   80  414  0  1 50 49  0
```

观察 vmstat 的输出，你会发现读磁盘时（也就是 bi 大于 0 时），Buffer 和 Cache 都在增长，但显然 Buffer 的增长快很多。这说明读磁盘时，数据缓存到了 Buffer 中。

经过上一个场景中两个案例的分析，**得出这个结论：读文件时数据会缓存到 Cache 中，而读磁盘时数据会缓存到 Buffer 中。**

到这里你应该发现了，虽然文档提供了对 Buffer 和 Cache 的说明，但是仍不能覆盖到所有的细节。比如说，今天我们了解到的这两点：

- Buffer 既可以用作“将要写入磁盘数据的缓存”，也可以用作“从磁盘读取数据的缓存”。
- Cache 既可以用作“从文件读取数据的页缓存”，也可以用作“写文件的页缓存”。

简单来说**，Buffer 是对磁盘数据的缓存，而 Cache 是文件数据的缓存，它们既会用在读请求中，也会用在写请求中。**



### 小结

今天，我们一起探索了内存性能中 Buffer 和 Cache 的详细含义。Buffer 和 Cache 分别缓存磁盘和文件系统的读写数据。

- 从写的角度来说，不仅可以优化磁盘和文件的写入，对应用程序也有好处，应用程序可以在数据真正落盘前，就返回去做其他工作。
- 从读的角度来说，既可以加速读取那些需要频繁访问的数据，也降低了频繁 I/O 对磁盘的压力。



#  系统缓存优化



上一节，我们学习了[内存性能中 Buffer 和 Cache 的概念](https://blog.csdn.net/Mr_SCX/article/details/103140139)。简单复习一下，Buffer 和 Cache 的设计目的，是为了提升系统的 I/O 性能。它们利用内存，充当起慢速磁盘与快速 CPU 之间的桥梁，可以加速 I/O 的访问速度。

Buffer 和 Cache 分别缓存的是对磁盘和文件系统的读写数据。

- 从写的角度来说，不仅可以优化磁盘和文件的写入，对应用程序也有好处，应用程序可以在数据真正落盘前，就返回去做其他工作。
- 从读的角度来说，不仅可以提高那些频繁访问数据的读取速度，也降低了频繁 I/O 对磁盘的压力。

既然 Buffer 和 Cache 对系统性能有很大影响，那我们在软件开发的过程中，能不能利用这一点，来优化 I/O 性能，提升应用程序的运行效率呢？

答案自然是肯定的。下面，用几个案例帮助你更好地理解缓存的作用，并学习如何充分利用这些缓存来提高程序效率。为了方便理解，下文中的Buffer 和 Cache 仍然用英文表示，避免跟“缓存”一词混淆。而文中的“缓存”，通指数据在内存中的临时存储。



### 缓存命中率

如果我们想利用缓存来提升程序的运行效率，应该怎么评估这个效果呢？换句话说，有没有哪个指标可以衡量缓存使用的好坏呢？

所谓**缓存命中率**，是指直接通过缓存获取数据的请求次数，占所有数据请求次数的百分比。
**命中率越高，表示使用缓存带来的收益越高，应用程序的性能也就越好。**

实际上，缓存是现在所有高并发系统必需的核心模块，主要作用就是把经常访问的数据（也就是热点数据），提前读入到内存中。这样，下次访问时就可以直接从内存读取数据，而不需要经过硬盘，从而加快应用程序的响应速度。

这些独立的缓存模块通常会提供查询接口，方便我们随时查看缓存的命中情况。不过 Linux 系统中并没有直接提供这些接口，所以这里要介绍一下cachestat 和 cachetop ，它们正是查看系统缓存命中情况的工具。

- cachestat 提供了整个操作系统缓存的读写命中情况。
- cachetop 提供了每个进程的缓存命中情况。

这两个工具都是 [bcc 软件包](https://github.com/iovisor/bcc)的一部分，它们基于 Linux 内核的 eBPF（extended Berkeley Packet Filters）机制，来跟踪内核中管理的缓存，并输出缓存的使用和命中情况。

使用 cachestat 和 cachetop 前，我们首先要安装 bcc 软件包。比如，在 Ubuntu 系统中，你可以运行下面的命令来安装：

```python
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 4052245BD4284CDD
echo "deb https://repo.iovisor.org/apt/xenial xenial main" | sudo tee /etc/apt/sources.list.d/iovisor.list
sudo apt-get update
sudo apt-get install -y bcc-tools libbcc-examples linux-headers-$(uname -r)
```

注意：bcc-tools 需要内核版本为 4.1 或者更新的版本，如果你用的是 CentOS，那就需要[手动升级内核版本](https://github.com/iovisor/bcc/issues/462)后再安装。

操作完这些步骤，bcc 提供的所有工具就都安装到 /usr/share/bcc/tools 这个目录中了。不过这里提醒你，bcc 软件包默认不会把这些工具配置到系统的 PATH 路径中，所以你得自己手动配置：

```python
$ export PATH=$PATH:/usr/share/bcc/tools
```

配置完，你就可以运行 cachestat 和 cachetop 命令了。比如，下面就是一个 cachestat 的运行界面，它以 1 秒的时间间隔，输出了 3 组缓存统计数据：

```python
$ cachestat 1 3
   TOTAL   MISSES     HITS  DIRTIES   BUFFERS_MB  CACHED_MB
       2        0        2        1           17        279
       2        0        2        1           17        279
       2        0        2        1           17        279 
```

可以看到，cachestat 的输出其实是一个表格。每行代表一组数据，而每一列代表不同的缓存统计指标。这些指标从左到右依次表示：

- TOTAL ，表示总的 I/O 次数；
- MISSES ，表示缓存未命中的次数；
- HITS ，表示缓存命中的次数；
- DIRTIES， 表示新增到缓存中的脏页数；
- BUFFERS_MB 表示 Buffers 的大小，以 MB 为单位；
- CACHED_MB 表示 Cache 的大小，以 MB 为单位。

再来看一个 cachetop 的运行界面：

```python
$ cachetop
11:58:50 Buffers MB: 258 / Cached MB: 347 / Sort: HITS / Order: ascending
PID      UID      CMD              HITS     MISSES   DIRTIES  READ_HIT%  WRITE_HIT%
13029    root     python             1        0         0       100.0%       0.0%
```

它的输出跟 top 类似，默认按照缓存的命中次数（HITS）排序，展示了每个进程的缓存命中情况。具体到每一个指标，这里的 HITS、MISSES 和 DIRTIES ，跟 cachestat 里的含义一样，分别代表间隔时间内的缓存命中次数、未命中次数以及新增到缓存中的脏页数。而 READ_HIT 和 WRITE_HIT ，分别表示读和写的缓存命中率。



### 指定文件的缓存大小

除了缓存的命中率外，还有一个指标你可能也会很感兴趣，那就是指定文件在内存中的缓存大小。你可以使用 [pcstat](https://github.com/tobert/pcstat) 这个工具，来查看文件在内存中的缓存大小以及缓存比例。

pcstat 是一个基于 Go 语言开发的工具，所以安装它之前，你首先应该[安装 Go 语言](https://golang.org/dl/)

安装完 Go 语言，再运行下面的命令安装 pcstat：

```python
$ export GOPATH=~/go
$ export PATH=~/go/bin:$PATH
$ go get golang.org/x/sys/unix
$ go get github.com/tobert/pcstat/pcstat
```

全部安装完成后，你就可以运行 pcstat 来查看文件的缓存情况了。比如，下面就是一个 pcstat 运行的示例，它展示了 /bin/ls 这个文件的缓存情况：

```python
$ pcstat /bin/ls
+---------+----------------+------------+-----------+---------+
| Name    | Size (bytes)   | Pages      | Cached    | Percent |
|---------+----------------+------------+-----------+---------|
| /bin/ls | 133792         | 33         | 0         | 000.000 |
+---------+----------------+------------+-----------+---------+
123456
```

这个输出中，Cached 就是 /bin/ls 在缓存中的大小，而 Percent 则是缓存的百分比。这里它们都是 0，这说明 /bin/ls 并不在缓存中。

接着，如果你执行一下 ls 命令，再运行相同的命令来查看的话，就会发现 /bin/ls 都在缓存中了：

```python
$ ls
$ pcstat /bin/ls
+---------+----------------+------------+-----------+---------+
| Name    | Size (bytes)   | Pages      | Cached    | Percent |
|---------+----------------+------------+-----------+---------|
| /bin/ls | 133792         | 33         | 33        | 100.000 |
+---------+----------------+------------+-----------+---------+
1234567
```

知道了缓存相应的指标和查看系统缓存的方法后，接下来，我们进入今天的案例学习。

- 机器配置：Ubuntu 18.04，2 CPU，8GB 内存。
- 预先按照上面的步骤安装 bcc 和 pcstat 软件包，并把这些工具的安装路径添加到到 PATH 环境变量中。
- 预先安装 Docker 软件包，使用 `apt-get install docker.io`



### 案例一

dd 作为一个磁盘和文件的拷贝工具，经常被拿来测试磁盘或者文件系统的读写性能。不过，既然缓存会影响到性能，如果用 dd 对同一个文件进行多次读取测试，测试的结果会怎么样呢？

我们来动手试试。首先，打开两个终端，连接到 Ubuntu 机器上，确保 bcc 已经安装配置成功。

然后，使用 dd 命令生成一个临时文件，用于后面的文件读取测试：

```python
# 生成一个512MB的临时文件
$ dd if=/dev/sda1 of=file bs=1M count=512
# 清理缓存
$ echo 3 > /proc/sys/vm/drop_caches
```

继续在第一个终端，运行 pcstat 命令，确认刚刚生成的文件不在缓存中。如果一切正常，你会看到 Cached 和 Percent 都是 0:

```python
$ pcstat file
+-------+----------------+------------+-----------+---------+
| Name  | Size (bytes)   | Pages      | Cached    | Percent |
|-------+----------------+------------+-----------+---------|
| file  | 536870912      | 131072     | 0         | 000.000 |
+-------+----------------+------------+-----------+---------+
```

还是在第一个终端中，现在运行 cachetop 命令：

```python
# 每隔5秒刷新一次数据
$ cachetop 5
```

这次是第二个终端，运行 dd 命令测试文件的读取速度：

```python
$ dd if=file of=/dev/null bs=1M
512+0 records in
512+0 records out
536870912 bytes (537 MB, 512 MiB) copied, 16.0509 s, 33.4 MB/s
```

从 dd 的结果可以看出，这个文件的读性能是 33.4 MB/s。由于在 dd 命令运行前我们已经清理了缓存，所以 dd 命令读取数据时，肯定要通过文件系统从磁盘中读取。

不过，这是不是意味着， dd 所有的读请求都能直接发送到磁盘呢？

我们再回到第一个终端， 查看 cachetop 界面的缓存命中情况：

```python
PID      UID      CMD              HITS     MISSES   DIRTIES  READ_HIT%  WRITE_HIT%
3264     root     dd               37077    37330        0      49.8%      50.2%
```

从 cachetop 的结果可以发现，并不是所有的读都落到了磁盘上，事实上读请求的缓存命中率只有 50% 。

接下来，我们继续尝试相同的测试命令。先切换到第二个终端，再次执行刚才的 dd 命令：

```python
$ dd if=file of=/dev/null bs=1M
512+0 records in
512+0 records out
536870912 bytes (537 MB, 512 MiB) copied, 0.118415 s, 4.5 GB/s
```

这次的结果，磁盘的读性能居然变成了 4.5 GB/s，比第一次的结果明显高了太多。为什么这次的结果这么好呢？不妨再回到第一个终端，看看 cachetop 的情况：

```python
10:45:22 Buffers MB: 4 / Cached MB: 719 / Sort: HITS / Order: ascending
PID      UID      CMD              HITS     MISSES   DIRTIES  READ_HIT%  WRITE_HIT%
32642    root     dd              131637       0        0     100.0%       0.0%
```

显然，cachetop 也有了不小的变化。你可以发现，这次的读的缓存命中率是 100.0%，也就是说这次的 dd 命令全部命中了缓存，所以才会看到那么高的性能。

然后，回到第二个终端，再次执行 pcstat 查看文件 file 的缓存情况：

```python
$ pcstat file
+-------+----------------+------------+-----------+---------+
| Name  | Size (bytes)   | Pages      | Cached    | Percent |
|-------+----------------+------------+-----------+---------|
| file  | 536870912      | 131072     | 131072    | 100.000 |
+-------+----------------+------------+-----------+---------+
```

从 pcstat 的结果你可以发现，测试文件 file 已经被全部缓存了起来，这跟刚才观察到的缓存命中率 100% 是一致的。

这两次结果说明，系统缓存对第二次 dd 操作有明显的加速效果，可以大大提高文件读取的性能。

但同时也要注意，**如果我们把 dd 当成测试文件系统性能的工具，由于缓存的存在，就会导致测试结果严重失真。**

### 案例二

接下来，我们再来看一个文件读写的案例。它的基本功能比较简单，也就是每秒从磁盘分区 /dev/sda1 中读取 32MB 的数据，并打印出读取数据花费的时间。

为了方便你运行案例，这里把它打包成了一个 [Docker 镜像](https://github.com/feiskyer/linux-perf-examples/tree/master/io-cached)。 我提供了下面两个选项，你可以根据系统配置，自行调整磁盘分区的路径以及 I/O 的大小。

- -d 选项，设置要读取的磁盘或分区路径，默认是查找前缀为 /dev/sd 或者 /dev/xvd 的磁盘。
- -s 选项，设置每次读取的数据量大小，单位为字节，默认为 33554432（也就是 32MB）。

这个案例同样需要你开启两个终端。分别 SSH 登录到机器上后，先在第一个终端中运行 cachetop 命令：

```python
# 每隔5秒刷新一次数据
$ cachetop 5 
```

接着，再到第二个终端，执行下面的命令运行案例：

```python
$ docker run --privileged --name=app -itd feisky/app:io-direct
```

案例运行后，我们还需要运行下面这个命令，来确认案例已经正常启动。如果一切正常，你应该可以看到类似下面的输出：

```python
$ docker logs app
Reading data from disk /dev/sdb1 with buffer size 33554432
Time used: 0.929935 s to read 33554432 bytes
Time used: 0.949625 s to read 33554432 bytes
```

从这里你可以看到，每读取 32 MB 的数据，就需要花 0.9 秒。这个时间合理吗？我想你第一反应就是，太慢了吧。那这是不是没用系统缓存导致的呢？

我们检查一下。回到第一个终端，先看看 cachetop 的输出，在这里，我们找到案例进程 app 的缓存使用情况：

```python
16:39:18 Buffers MB: 73 / Cached MB: 281 / Sort: HITS / Order: ascending
PID      UID      CMD              HITS     MISSES   DIRTIES  READ_HIT%  WRITE_HIT%
21881    root     app              1024        0        0     100.0%       0.0% 
```

这个输出似乎有点意思了。1024 次缓存全部命中，读的命中率是 100%，看起来全部的读请求都经过了系统缓存。但是问题来了，如果真的都是缓存 I/O，读取速度不应该这么慢。

不过，我们似乎忽略了另一个重要因素，**每秒实际读取的数据大小**。HITS 代表缓存的命中次数，那么每次命中能读取多少数据呢？答案是**一页**。

前面讲过，内存以页为单位进行管理，而**每个页的大小是 4KB**。所以，在 5 秒的时间间隔里，命中的缓存为 1024*4K/1024 = 4MB，再除以 5 秒，可以得到每秒读的缓存是 0.8MB，显然跟案例应用的 32 MB/s 相差太多。

这也进一步验证了我们的猜想，这个案例估计没有充分利用系统缓存。其实前面我们遇到过类似的问题，如果为系统调用设置直接 I/O 的标志，就可以绕过系统缓存。

那么，要判断应用程序是否用了直接 I/O，最简单的方法当然是观察它的系统调用，查找应用程序在调用它们时的选项。使用什么工具来观察系统调用呢？答案是 **strace**。

继续在终端二中运行下面的 strace 命令，观察案例应用的系统调用情况。注意，这里使用了 pgrep 命令来查找案例进程的 PID 号：

```python
# strace -p $(pgrep app)
strace: Process 4988 attached
restart_syscall(<... resuming interrupted nanosleep ...>) = 0
openat(AT_FDCWD, "/dev/sdb1", O_RDONLY|O_DIRECT) = 4
mmap(NULL, 33558528, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0x7f448d240000
read(4, "8vq\213\314\264u\373\4\336K\224\25@\371\1\252\2\262\252q\221\n0\30\225bD\252\266@J"..., 33554432) = 33554432
write(1, "Time used: 0.948897 s to read 33"..., 45) = 45
close(4) = 0
```

从 strace 的结果可以看到，案例应用调用了 openat 来打开磁盘分区 /dev/sdb1，并且传入的参数为 O_RDONLY|O_DIRECT（中间的竖线表示或）。

O_RDONLY 表示以只读方式打开，而 O_DIRECT 则表示以直接读取的方式打开，这会绕过系统的缓存。

验证了这一点，就很容易理解为什么读 32 MB 的数据就都要那么久了。直接从磁盘读写的速度，自然远慢于对缓存的读写。这也是缓存存在的最大意义了。

找出问题后，我们还可以在再看看案例应用的[源代码](https://github.com/feiskyer/linux-perf-examples/blob/master/io-cached/app.c)，再次验证一下：

```python
int flags = O_RDONLY | O_LARGEFILE | O_DIRECT; 
int fd = open(disk, flags, 0755);
```

上面的代码，很清楚地告诉我们：它果然用了直接 I/O。

找出了磁盘读取缓慢的原因后，就可以优化磁盘读的性能了。修改源代码，删除 O_DIRECT 选项，让应用程序使用缓存 I/O ，而不是直接 I/O，就可以加速磁盘读取速度。

[修复后的源码](https://github.com/feiskyer/linux-perf-examples/blob/master/io-cached/app-cached.c)，这里也把它打包成了一个容器镜像。在第二个终端中，按 Ctrl+C 停止刚才的 strace 命令，运行下面的命令，你就可以启动它：

```python
# 删除上述案例应用
$ docker rm -f app

# 运行修复后的应用
$ docker run --privileged --name=app -itd feisky/app:io-cached
```

还是第二个终端，再来运行下面的命令查看新应用的日志，你应该能看到下面这个输出：

```python
$ docker logs app
Reading data from disk /dev/sdb1 with buffer size 33554432
Time used: 0.037342 s s to read 33554432 bytes
Time used: 0.029676 s to read 33554432 bytes
```

现在，每次只需要 0.03 秒，就可以读取 32MB 数据，明显比之前的 0.9 秒快多了。所以，这次应该用了系统缓存。

再回到第一个终端，查看 cachetop 的输出来确认一下：

```python
16:40:08 Buffers MB: 73 / Cached MB: 281 / Sort: HITS / Order: ascending
PID      UID      CMD              HITS     MISSES   DIRTIES  READ_HIT%  WRITE_HIT%
22106    root     app              40960        0        0     100.0%       0.0%
```

果然，读的命中率还是 100%，HITS （即命中数）却变成了 40960，同样的方法计算一下，换算成每秒字节数正好是 32 MB（即 40960*4k/5/1024=32M）。

这个案例说明，在进行 I/O 操作时，充分利用系统缓存可以极大地提升性能。 但在观察缓存命中率时，还要注意结合应用程序实际的 I/O 大小，综合分析缓存的使用情况。

案例的最后，再回到开始的问题，为什么优化前，通过 cachetop 只能看到很少一部分数据的全部命中，而没有观察到大量数据的未命中情况呢？这是因为，cachetop 工具并不把直接 I/O 算进来。这也又一次说明了，了解工具原理的重要。

cachetop 的计算方法涉及到 I/O 的原理以及一些内核的知识，如果你想了解它的原理的话，可以查看它的[源代码](https://github.com/iovisor/bcc/blob/master/tools/cachetop.py)。



### 总结

Buffers 和 Cache 可以极大提升系统的 I/O 性能。通常，我们用缓存命中率，来衡量缓存的使用效率。命中率越高，表示缓存被利用得越充分，应用程序的性能也就越好。

可以用 cachestat 和 cachetop 这两个工具，观察系统和进程的缓存命中情况。其中

- cachestat 提供了整个系统缓存的读写命中情况。
- cachetop 提供了每个进程的缓存命中情况。

不过要注意，Buffers 和 Cache 都是操作系统来管理的，应用程序并不能直接控制这些缓存的内容和生命周期。所以，在应用程序开发中，一般要用专门的缓存组件，来进一步提升性能。

比如，程序内部可以使用堆或者栈明确声明内存空间，来存储需要缓存的数据。再或者，使用 Redis 这类外部缓存服务，优化数据的访问效率。



# 内存泄漏



##  一、内存的分配和回收

### 1、管理内存的过程中，也很容易发生各种各样的“事故”，

对应用程序来说，动态内存的分配和回收，是既核心又复杂的一的一个逻辑功能模块。管理内存的过程中，**也很容易发生各种各样的“事故”，**

比如，没正确回收分配后的内存，导致了泄漏。访问的是已分配内存边界外的地址，导致程序异常退出，等等。

你在程序中定义了一个局部变量，比如一个整数数组 int data[64] ，就定义了一个可以存储 64 个整数的内存段。由于这是一个局部变量，它会从内它会从内存空间的栈中分配内存

1、栈内存由系统自动分配和管理。一旦程序运行超出了这个局部变量的作用域，栈内存就会被系统自动回收，所以不会产生**内存泄漏的问题。** 

2、 堆内存由应用程序自己来分配和管理。 除非程序退出，这些堆内存并不会被系统自动释放，而是需要应用程序明确调用库函数 free() 来释放它们。如果应用程序没有正确释放堆内存，

   **就会造成内存泄漏。**

**这是两个栈和堆的例子，那么，其他内存段是否也会导致内存泄漏呢？经过我们前面的学习，这个问题并不难回答**

### 2、只读段

**只读段：**包括程序的代码和常量，由于是只读的，不会再去分配新的的内存，所以也不会产生内存泄漏。

数据段：包括全局变量和静态变量，这些变量在定义时就已经确定了大小，所以也不会产生内存泄漏。

最后一个内存映射段：包括动态链接库和共享内存，其中共享内存由程序动态分配和管理。所以，如果程序在分配后忘了回收，就会导致跟堆内存类似的泄漏问题。

**内存泄漏的危害非常大，这些忘记释放的内存，不仅应用程序自己不能访问，系统也不能把他们再次分配给其他应用，内存泄露不断累积，甚至耗尽系统内存**

虽然，系统最终可以通过 OOM （Out of Memory）机制杀死进程，但进程在 OOM 前，可能已经引发了一连串的反应，导致严重的性能问题

比如，其他需要内存的进程，可能无法分配新的内存；内存不足，又会触发系统的缓存回收以及SWAP 机制，从而进一步导致 I/O 的性能问题等等。

内存泄漏的危害这么大，那我们应该怎么检测这种问题呢？特别是，如果你已经发现了内存泄漏，该如何定位和处理呢。

接下来，我们就用一个计算斐波那契数列的案例，

斐波那契数列是一个这样的数列：0、1、1、2、3、5、8…，也就是除了前两个数是 0 和1，其他数都由前面两数相加得到，用数学公式来表示就是 F(n)=F(n-1)+F(n-2)，（n>=2），F(0)=0, F(1)=1

## 二、案例

### 1、环境准备

今天的案例基于 Ubuntu 18.04，当然，同样适用其他的 Linux 系统。
机器配置：2 CPU，8GB 内存
预先安装 sysstat、Docker 以及 bcc 软件包，比如：

```
# install sysstat docker
sudo apt-get install -y sysstat docker.io
 
# Install bcc
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 4052245BD4284CDD
echo "deb https://repo.iovisor.org/apt/bionic bionic main" | sudo tee /etc/apt/sources.list.d/iovisor.list
sudo apt-get update
sudo apt-get install -y bcc-tools libbcc-examples linux-headers-$(uname -r)
```

其中，sysstat 和 Docker 我们已经很熟悉了。sysstat 软件包中的 vmstat ，可以观察内存的变化情况；而 Docker 可以运行案例程序。
bcc 软件包前面也介绍过，它提供了一系列的 Linux 性能分析工具，常用来动态追踪进程和内核的行为。更多工作原理你先不用深究，后面学习我们会逐步接触。这里你只需要记
住，按照上面步骤安装完后，它提供的所有工具都位于 /usr/share/bcc/tools 这个目录中。

```
注意：bcc-tools 需要内核版本为 4.1 或者更高，如果你使用的是CentOS7，或者其他内核版本比较旧的系统，那么你需要手动升级内核版本后再安装。
```

### 2、服务运行环境

```
# docker run --name=app -itd feisky/app:mem-leak
Unable to find image 'feisky/app:mem-leak' locally
mem-leak: Pulling from feisky/app
473ede7ed136: Pull complete
c46b5fa4d940: Pull complete
93ae3df89c92: Pull complete
6b1eed27cade: Pull complete
22dd80cda054: Pull complete
f7c1129fca8d: Pull complete
Digest: sha256:a6806d6b0f33aedc31a6e6c9bd77fe80a086b5c97869a25859e4894dec7b8d4b
Status: Downloaded newer image for feisky/app:mem-leak
b316f0fb07945bd283ffa2d4768440515ffbb01f607a8051a31fce3f9c0fb297
```

案例成功运行后，你需要输入下面的命令，确认案例应用已经正常启动。如果一切正常，你应该可以看到下面这个界面：

```
# docker logs app
2th => 1
3th => 2
4th => 3
5th => 5
... ...
38th => 39088169
39th => 63245986
40th => 102334155
```

从输出中，我们可以发现，这个案例会输出斐波那契数列的一系列数值。实际上，这些数值每隔 1 秒输出一次。

知道了这些，我们应该怎么检查内存情况，判断有没有泄漏发生呢？你首先想到的可能是top 工具，不过，top 虽然能观察系统和进程的内存占用情况，但今天的案例并不适合。
内存泄漏问题，我们更应该关注内存使用的变化趋势。

### 3、发现问题

所以，开头我也提到了，今天推荐的是另一个老熟人， vmstat 工具。运行下面的 vmstat ，等待一段时间，观察内存的变化情况。如果忘了 vmstat 里各指标的含义，记得复习前面内容，或者执行 man vmstat 查询。

```
# vmstat 3
procs -----------memory---------- ---swap-- -----io---- -system-- ------cpu-----
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
 2  0      0 7177068   2072 576796    0    0   466   187  257  365  1  3 90  5  0
 0  0      0 7177068   2072 576796    0    0     0     0  132  231  0  0 100  0  0
 0  0      0 7177068   2072 576796    0    0     0     0  138  234  0  0 100  0  0
 0  0      0 7176908   2072 576796    0    0     0     0  128  228  0  0 100  0  0
 0  0      0 7176908   2072 576800    0    0     0     0  129  225  0  0 100  0  0
 0  0      0 7176908   2072 576800    0    0     0     0  136  241  0  0 100  0  0
 1  0      0 7176968   2072 576800    0    0     0     6  166  257  0  1 99  0  0
 0  0      0 7176968   2072 576800    0    0     0     0  137  246  0  0 100  0  0
 0  0      0 7176968   2072 576800    0    0     0     0  132  237  0  0 100  0  0
procs -----------memory---------- ---swap-- -----io---- -system-- ------cpu-----
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
 0  0      0 7176744   2072 576800    0    0     0     0  138  236  0  1 99  0  0
 0  0      0 7176744   2072 576800    0    0     0     0  129  233  0  0 100  0  0
 0  0      0 7176744   2072 576800    0    0     0     0  127  240  0  0 100  0  0
 0  0      0 7176744   2072 576800    0    0     0     0  122  229  0  0 100  0  0
 0  0      0 7176680   2072 576800    0    0     0     0  131  241  0  0 100  0  0
 0  0      0 7176680   2072 576800    0    0     0     0  131  233  0  0 100  0  0
 0  0      0 7176680   2072 576800    0    0     0     0  145  244  1  0 99  0  0
```

从输出中你可以看到，内存的 free 列在不停的变化，并且是下降趋势；而 buffer 和cache 基本保持不变。

未使用内存在逐渐减小，而 buffer 和 cache 基本不变，这说明，系统中使用的内存一直在升高。但这并不能说明有内存泄漏，因为应用程序运行中需要的内存也可能会增大。比如说，程序中如果用了一个动态增长的数组来缓存计算结果，占用内存自然会增长。

## 三、分析过程

那怎么确定是不是内存泄漏呢？或者换句话说，有没有简单方法找出让内存增长的进程，并定位增长内存用在哪儿呢？

根据前面内容，你应该想到了用 top 或 ps 来观察进程的内存使用情况，然后找出内存使用一直增长的进程，最后再通过 pmap 查看进程的内存分布。

但这种方法并不太好用，因为要判断内存的变化情况，还需要你写一个脚本，来处理 top或者 ps 的输出。

### 1、memleak分析工具

这里，我介绍一个专门用来检测内存泄漏的工具，memleak。memleak 可以跟踪系统或指定进程的内存分配、释放请求，然后定期输出一个未释放内存和相应调用栈的汇总情况（默认 5 秒）。
当然，memleak 是 bcc 软件包中的一个工具，我们一开始就装好了，执行/usr/share/bcc/tools/memleak 就可以运行它。比如，我们运行下面的命令：

```
# -a 表示显示每个内存分配请求的大小以及地址
# -p 指定案例应用的 PID 号
[root@luoahong ~]# /usr/share/bcc/tools/memleak -a -p $(pidof app)
WARNING: Couldn't find .text section in /app
WARNING: BCC can't handle sym look ups for /app
    addr = 7f8f704732b0 size = 8192
    addr = 7f8f704772d0 size = 8192
    addr = 7f8f704712a0 size = 8192
    addr = 7f8f704752c0 size = 8192
    32768 bytes in 4 allocations from stack
        [unknown] [app]
        [unknown] [app]
        start_thread+0xdb [libpthread-2.27.so]
```

**从 memleak 的输出可以看到，案例应用在不停地分配内存，并且这些分配的地址没有被回收。**

### 2、Couldn’t find .text section in /app问题解决

Couldn’t find .text section in /app，所以调用栈不能正常输出，最后的调用栈部分只能看到 [unknown] 的标志。
为什么会有这个错误呢？实际上，这是由于案例应用运行在容器中导致的。memleak 工具运行在容器之外，并不能直接访问进程路径 /app。
比方说，在终端中直接运行 ls 命令，你会发现，这个路径的确不存在：

```
ls /app
ls: cannot access '/app': No such file or directory
```

类似的问题，我在 CPU 模块中的 perf 使用方法中已经提到好几个解决思路。最简单的方法，就是在容器外部构建相同路径的文件以及依赖库。这个案例只有一个二进制文件，
所以只要把案例应用的二进制文件放到 /app 路径中，就可以修复这个问题。

比如，你可以运行下面的命令，把 app 二进制文件从容器中复制出来，然后重新运行memleak 工具：

```
docker cp app:/app /app
[root@luoahong ~]#  /usr/share/bcc/tools/memleak -p $(pidof app) -a
Attaching to pid 12512, Ctrl+C to quit.
[03:00:41] Top 10 stacks with outstanding allocations:
    addr = 7f8f70863220 size = 8192
    addr = 7f8f70861210 size = 8192
    addr = 7f8f7085b1e0 size = 8192
    addr = 7f8f7085f200 size = 8192
    addr = 7f8f7085d1f0 size = 8192
    40960 bytes in 5 allocations from stack
        fibonacci+0x1f [app]
        child+0x4f [app]
        start_thread+0xdb [libpthread-2.27.so]
```

### 3、fibonacci() 函数分配的内存没释放

这一次，我们终于看到了内存分配的调用栈，原来是 fibonacci() 函数分配的内存没释放。
定位了内存泄漏的来源，下一步自然就应该查看源码，想办法修复它。我们一起来看案例应用的源代码 app.c：

```
[root@luoahong ~]# docker exec app cat /app.c
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <unistd.h>
 
long long *fibonacci(long long *n0, long long *n1)
{
    long long *v = (long long *) calloc(1024, sizeof(long long));
    *v = *n0 + *n1;
    return v;
}
 
void *child(void *arg)
{
    long long n0 = 0;
    long long n1 = 1;
    long long *v = NULL;
    for (int n = 2; n > 0; n++) {
        v = fibonacci(&n0, &n1);
        n0 = n1;
        n1 = *v;
        printf("%dth => %lld\n", n, *v);
        sleep(1);
    }
}
 
 
int main(void)
{
    pthread_t tid;
    pthread_create(&tid, NULL, child, NULL);
    pthread_join(tid, NULL);
    printf("main thread exit\n");
    return 0;
```

你会发现， child() 调用了 fibonacci() 函数，但并没有释放 fibonacci() 返回的内存。所以，想要修复泄漏问题，在 child() 中加一个释放函数就可以了，比如：

```
void *child(void *arg)
{
    ...
    for (int n = 2; n > 0; n++) {
        v = fibonacci(&n0, &n1);
        n0 = n1;
        n1 = *v;
        printf("%dth => %lld\n", n, *v);
        free(v);    // 释放内存
        sleep(1);
    }
}
```

## 四、解决方案

我把修复后的代码放到了 app-fix.c，也打包成了一个 Docker 镜像。你可以运行下面的命令，验证一下内存泄漏是否修复：

```
# 清理原来的案例应用
[root@luoahong ~]# docker rm -f app
app
 
# 运行修复后的应用
[root@luoahong ~]# docker run --name=app -itd feisky/app:mem-leak-fix
Unable to find image 'feisky/app:mem-leak-fix' locally
mem-leak-fix: Pulling from feisky/app
473ede7ed136: Already exists
c46b5fa4d940: Already exists
93ae3df89c92: Already exists
6b1eed27cade: Already exists
4d87f2538251: Pull complete
f7c1129fca8d: Pull complete
Digest: sha256:61d1ce0944188fcddb0ee78a2db60365133009b23612f8048b79c0bbc85f7012
Status: Downloaded newer image for feisky/app:mem-leak-fix
c2071e234b83d078716d5d5aa664047a8afd2abf67d10ecc89f77db3d173fb16
 
# 重新执行 memleak 工具检查内存泄漏情况
[root@luoahong ~]#/usr/share/bcc/tools/memleak -a -p $(pidof app)
Attaching to pid 18808, Ctrl+C to quit.
[10:23:18] Top 10 stacks with outstanding allocations:
[10:23:23] Top 10 stacks with outstanding allocations:
```

现在，我们看到，案例应用已经没有遗留内存，证明我们的修复工作成功完成。

##  五、小结

应用程序可以访问的用户内存空间，由只读段、数据段、堆、栈以及文件映射段等组成。其中，堆内存和内存映射，需要应用程序来动态管理内存段，所以我们必须小心处理。不
仅要会用标准库函数 malloc() 来动态分配内存，还要记得在用完内存后，调用库函数_free() 来 _ 释放它们。

今天的案例比较简单，只用加一个 free() 调用就能修复内存泄漏。不过，实际应用程序就复杂多了。比如说，
malloc() 和 free() 通常并不是成对出现，而是需要你，在每个异常处理路径和成功路径上都释放内存 。

在多线程程序中，一个线程中分配的内存，可能会在另一个线程中访问和释放。更复杂的是，在第三方的库函数中，隐式分配的内存可能需要应用程序显式释放。

所以，为了避免内存泄漏，最重要的一点就是养成良好的编程习惯，比如分配内存后，一定要先写好内存释放的代码，再去开发其他逻辑。还是那句话，有借有还，才能高效运
转，再借不难。

当然，如果已经完成了开发任务，你还可以用 memleak 工具，检查应用程序的运行中，内存是否泄漏。如果发现了内存泄漏情况，再根据 memleak 输出的应用程序调用栈，定
位内存的分配位置，从而释放不再访问的内存。



# swap变高 (上)

## swap用来做什么

缓存和缓冲区属于可回收内存，它们在内存管理中，通常被叫做**文件页**（File- backed page）大部分文件页都可以直接回收，以后需要时，再从磁盘重新读取就可以了，那些被应用程序修改过，并且暂时没有写入磁盘的数据（脏页）就得先写入磁盘，然后才能进行内存释放

除了文件页外，应用程序动态分配的堆内存叫做**匿名页**（Anonymous Page）如堆，栈，数据段等，不是以文件形式存在，因此无法和磁盘文件交换，是通过swap机制把不常访问**匿名页**占用的内存写入到磁盘中，然后释放这些内存，再次方式这些内存时，重新冲磁盘写入内存就可以了

匿名页 和 文件页 的回收都是基于LRU算法，优先回收不常访问的内存，所以LRU维护了active和inactive两个双向链表

- active：记录活跃内存页
- inactive：记录不活跃内存页

活跃和非活跃的 匿名页 和 文件页 大小查看

```ruby
cat /proc/meminfo | grep -i active | sort
Active:           274616 kB
Active(anon):      38224 kB
Active(file):     236392 kB
Inactive:         320624 kB
Inactive(anon):      136 kB
Inactive(file):   320488 kB
```



## swap 原理

Swap就是把一块磁盘空间或者本地文件想做内存来使用，它包括换出和换入两个过程

- 换出：就是把进程暂时不用的内存数据存储到磁盘中，并且释放这些数据占用的内存
- 换入：进程再次访问这些内存的时候，把它们从磁盘读取到内存中



### 使用场景

> Swap其实就是把系统的可用内存变大了，即使服务器内存不足，页可用运行大内存的应用程序

- 内存不足时，有些程序并不想被OOM杀死，而是希望能缓一段时间，等待人工介入或者等系统自动释放其他进程的内容，再分配给它就会用到swap
- swap也是为了回收**匿名页**占用的内存

- **直接内存回收**：当有大块内存分配请求，但是内存不足，这时候系统就会回收一部分内存（比如缓存）尽可能的满足新内存的请求，这个过程叫做 **直接内存回收**
- **定时内存回收**：内核kswapd0线程用来定时回收内存，为了衡量内存的使用情况，kswapd0定义了三个内存阈值是页最小阈值（pages_min），页低阈值（pages_low）和页高阈值（pages_high），剩余内存则使用pages_free表示。

关系图如下:

![img](https://upload-images.jianshu.io/upload_images/4788204-727105f66575bec6.png?imageMogr2/auto-orient/strip|imageView2/2/w/350)

kswapd0 定期扫描内存的使用情况，并根据剩余内存落在这三个阈值的空间位置，进行内存的回收操作。

- 剩余内存 < 页最小阈值：说明内存可用内存都耗尽了，只有内核才可以分配内存
- 剩余内存落在**页最小阈值**和**页低阈值**中间：说明内存使用比较大，剩余内存不多了，kswapd0回执行内存回收，知道剩余内存大于高阈值为止
- 剩余内存落在**页低阈值**和**页高阈值**中间：说明内存有一定压力，但是还可以满足新内存请求。
- 剩余内存 > 页高阈值：说明剩余内存比较大，没有内存压力

页低赋值可以通过内核选项`vm.min_free_kbytes` 间接设置 /proc/sys/vm/min_free_kbytes，min_free_kbytes设置了页最小阈值，其他两个阈值根据页最小阈值计算生成的

```undefined
pages_low = pages_min*5/4
pages_high = pages_min*3/2
```



## NUMA与Swap

有时候系统内存剩余还很多，但是Swap还是升高了，是因为处理器NUMA架构导致的

在NUMA框架下，多个处理器被划分到不同Node上，且每个Node 都拥有自己的本地内存空间，并且进一步又分为内内参域（zone），不如 直接内存访问区（DMA），普通内存区（NORMAL），伪内存区（MOVABLE）等, 如下图所示：

![img](https://static001.geekbang.org/resource/image/be/d9/be6cabdecc2ec98893f67ebd5b9aead9.png)

因为NUMA框架下每个Node都有自己的本地内存空间，所以分析内存使用需要根据每个Node单独分析, 可以通过numactl 查看每个Node内存使用情况

```cpp
[root@master1 ~]# numactl --hardware
available: 1 nodes (0)
node 0 cpus: 0 1 2 3
node 0 size: 8191 MB
node 0 free: 1793 MB
node distances:
node   0
  0:  10
```

根据这个输出，我们系统中只有一个Node，就是Node0，编号为0 1 2 3的CPU都位于Node0上。另外Node0的内存大小为 8191 MB，剩余1793 MB

前面提到的页最小，页低，页高的三个阈值都可以在内存域/proc/zoneinfo来查看

```cpp
[root@master1 ~]# cat /proc/zoneinfo | grep -i -A 15 "Node 0"
Node 0, zone      DMA
  pages free     3975
        min      30
        low      37
        high     45
        scanned  0
        spanned  4095
        present  3998
        managed  3977
    nr_free_pages 3975
    nr_alloc_batch 8
    nr_inactive_anon 0
    nr_active_anon 0
    nr_inactive_file 0
    nr_active_file 0
    nr_unevictable 0
--
Node 0, zone    DMA32
  pages free     159434
        min      5530
        low      6912
        high     8295
        scanned  0
        spanned  1044480
        present  782327
        managed  721081
    nr_free_pages 159434
    nr_alloc_batch 1343
    nr_inactive_anon 14605
    nr_active_anon 95179
    nr_inactive_file 193717
    nr_active_file 206850
    nr_unevictable 0
--
Node 0, zone   Normal
  pages free     295068
        min      9798
        low      12247
        high     14697
        scanned  0
        spanned  1310720
        present  1310720
        managed  1277513
    nr_free_pages 295068
    nr_alloc_batch 127
    nr_inactive_anon 16505
    nr_active_anon 141332
    nr_inactive_file 335925
    nr_active_file 383442
    nr_unevictable 0
```

这个输出中有大量指标，来解释一下:

* pages 处的 min、low、high，就是上面提到的三个内存阈值，而 free 是剩余内存页数，它跟后面的 nr_free_pages 相同。
* nr_zone_active_anon 和 nr_zone_inactive_anon，分别是活跃和非活跃的匿名页数。
* nr_zone_active_file 和 nr_zone_inactive_file，分别是活跃和非活跃的文件页数。

**注意**： 这里单位是页，每一页是4kb，比如计算页最小阈值需要把 三个zone的min相加 * 4kb`（9798 + 5530 + 30）* 4`



根据输入内容发现pages free剩余内存远高于high，所以此时kswapd0不会回收内存，当某个Node内存不足时，系统可以从其他Node寻找空闲内容，页可以从本地内存中回收内存，需要选哪个模式，可以通过/proc/sys/vm/zone_reclaim_mode来调整

- 默认为0，也就是刚刚提到的模式，表示既可以从其他Node寻找空闲内，页可以从本地回收内存，这时候就会导致回收文件页和**匿名页**，**匿名页**的回收所以会触发swap
- 1，2，4，表示只回收本地内存，2表示可以回收写脏数据回收内存，4表示可以用Swap方式回收内存



## swappiness

到这里，我们就可以理解内存回收的机制了。这些回收的内存既包括了文件页，又包括了匿名页。

* 对文件页的回收，当然就是直接回收缓存，或者把脏页写回磁盘后再回收。
* 而对匿名页的回收，其实就是通过 Swap 机制，把它们写入磁盘后再释放内存。

既然有两种不同的内存回收机制，那么在实际回收内存时，选择哪一种呢？其实，Linux 提供了一个  /proc/sys/vm/swappiness 选项，用来调整使用 Swap 的积极程度。

swappiness 配置范围0-100，数字越大，越积极使用Swap，也就是更倾向于回收**匿名页**，数值越小，越消极使用Swap

即使你设置为0，当剩余内存文件页小于**高阈值**时，还是会发生Swap

```ruby
# 按VmSwap使用量对进程排序，输出进程名称、进程ID以及SWAP用量
$ for file in /proc/*/status ; do awk '/VmSwap|Name|^Pid/{printf $2 " " $3}END{ print ""}' $file; done | sort -k 3 -n -r | head
dockerd 2226 10728 kB
docker-containe 2251 8516 kB
snapd 936 4020 kB
networkd-dispat 911 836 kB
polkitd 1004 44 kB
```



## 总结

Linux通过直接内存回收和定时内存扫描回收方式来释放文件页和匿名页

- 文件页的回收：就是直接回收缓存，或者把脏数据写回磁盘后释放
- 匿名也的回收：需要通过Swap换出到磁盘中，下次访问时，在从磁盘换入到内存中

定时内存扫描回收方式的阈值可以通过内核选项`vm.min_free_kbytes`来设置

只要涉及到回收**匿名页**就会涉及触发Swap

假如没有开启swap的话，进程的**匿名页**就无法释放，需要在进程的重启或者杀掉释放

swap使用积极程度可以通过内核参数vm.swappiness 设置

在处理器NUMA框架下，每个Node都有自己的内存域，某个Node自己内存域下剩余内存不多情况下，导致内存回收也就有可能触发Swap



# swap变高（下）



在内存资源紧张时，Linux通过直接内存回收和定期扫描的方式，来释放文件页和匿名页，以便把内存分配给更需要的进程使用。

- 文件页的回收比较容易理解，直接清空缓存，或者把脏数据写回磁盘后，再释放缓存就可以了。
- 而对不常访问的匿名页，则需要通过Swap换出到磁盘中，这样在下次访问的时候，再次从磁盘换入到内存中就可以了。

开启 Swap 后，你可以设置 /proc/sys/vm/min_free_kbytes ，来调整系统定期回收内存的阈值，也可以设置 /proc/sys/vm/swappiness ，来调整文件页和匿名页的回收倾向。

那么，当 Swap 使用升高时，要如何定位和分析呢？下面，我们就来看一个磁盘I/O的案例，实战分析和演练。



## 案例

下面案例基于 Ubuntu 18.04，同样适用于其他的 Linux 系统。

- 机器配置：2 CPU，8GB 内存
- 你需要预先安装 sysstat 等工具，如 apt install sysstat

首先，我们打开两个终端，分别 SSH 登录到两台机器上，并安装上面提到的这些工具。

同以前的案例一样，接下来的所有命令都默认以 root 用户运行，如果你是用普通用户身份登陆系统，请运行 sudo su root 命令切换到 root 用户。

如果安装过程中有什么问题，同样鼓励你先自己搜索解决，解决不了的，可以在留言区向我提问。

然后，在终端中运行free命令，查看Swap的使用情况。比如，在我的机器中，输出如下：

```
$ free
             total        used        free      shared  buff/cache   available
Mem:        8169348      331668     6715972         696     1121708     7522896
Swap:             0           0           0
```

从这个free输出你可以看到，Swap的大小是0，这说明我的机器没有配置Swap。

为了继续Swap的案例， 就需要先配置、开启Swap。如果你的环境中已经开启了Swap，那你可以略过下面的开启步骤，继续往后走。

要开启Swap，我们首先要清楚，Linux本身支持两种类型的Swap，即Swap分区和Swap文件。以Swap文件为例，在第一个终端中运行下面的命令开启Swap，我这里配置Swap文件的大小为8GB：

```
# 创建Swap文件
$ fallocate -l 8G /mnt/swapfile
# 修改权限只有根用户可以访问
$ chmod 600 /mnt/swapfile
# 配置Swap文件
$ mkswap /mnt/swapfile
# 开启Swap
$ swapon /mnt/swapfile
```

然后，再执行free命令，确认Swap配置成功：

```
$ free
             total        used        free      shared  buff/cache   available
Mem:        8169348      331668     6715972         696     1121708     7522896
Swap:       8388604           0     8388604
```

现在，free 输出中，Swap 空间以及剩余空间都从 0 变成了8GB，说明Swap已经**正常开启**。

接下来，我们在第一个终端中，运行下面的 dd 命令，模拟大文件的读取：

```
# 写入空设备，实际上只有磁盘的读请求
$ dd if=/dev/sda1 of=/dev/null bs=1G count=2048
```

接着，在第二个终端中运行 sar 命令，查看内存各个指标的变化情况。多观察一会儿，查看这些指标的变化情况。

```
# 间隔1秒输出一组数据
# -r表示显示内存使用情况，-S表示显示Swap使用情况
$ sar -r -S 1
04:39:56    kbmemfree   kbavail kbmemused  %memused kbbuffers  kbcached  kbcommit   %commit  kbactive   kbinact   kbdirty
04:39:57      6249676   6839824   1919632     23.50    740512     67316   1691736     10.22    815156    841868         4

04:39:56    kbswpfree kbswpused  %swpused  kbswpcad   %swpcad
04:39:57      8388604         0      0.00         0      0.00

04:39:57    kbmemfree   kbavail kbmemused  %memused kbbuffers  kbcached  kbcommit   %commit  kbactive   kbinact   kbdirty
04:39:58      6184472   6807064   1984836     24.30    772768     67380   1691736     10.22    847932    874224        20

04:39:57    kbswpfree kbswpused  %swpused  kbswpcad   %swpcad
04:39:58      8388604         0      0.00         0      0.00

…


04:44:06    kbmemfree   kbavail kbmemused  %memused kbbuffers  kbcached  kbcommit   %commit  kbactive   kbinact   kbdirty
04:44:07       152780   6525716   8016528     98.13   6530440     51316   1691736     10.22    867124   6869332         0

04:44:06    kbswpfree kbswpused  %swpused  kbswpcad   %swpcad
04:44:07      8384508      4096      0.05        52      1.27
```

我们可以看到，sar的输出结果是两个表格，第一个表格表示内存的使用情况，第二个表格表示Swap的使用情况。其中，各个指标名称前面的kb前缀，表示这些指标的单位是KB。

去掉前缀后，你会发现，大部分指标都已经见过了，剩下的几个新出现的指标，我来简单介绍一下。

- kbcommit，表示当前系统负载需要的内存。它实际上是为了保证系统内存不溢出，对需要内存的估计值。%commit，就是这个值相对总内存的百分比。
- kbactive，表示活跃内存，也就是最近使用过的内存，一般不会被系统回收。
- kbinact，表示非活跃内存，也就是不常访问的内存，有可能会被系统回收。

清楚了界面指标的含义后，我们再结合具体数值，来分析相关的现象。你可以清楚地看到，总的内存使用率（%memused）在不断增长，从开始的23%一直长到了 98%，并且主要内存都被缓冲区（kbbuffers）占用。具体来说：

- 刚开始，剩余内存（kbmemfree）不断减少，而缓冲区（kbbuffers）则不断增大，由此可知，剩余内存不断分配给了缓冲区。
- 一段时间后，剩余内存已经很小，而缓冲区占用了大部分内存。这时候，Swap的使用开始逐渐增大，缓冲区和剩余内存则只在小范围内波动。

你可能困惑了，为什么缓冲区在不停增大？这又是哪些进程导致的呢？

显然，我们还得看看进程缓存的情况。在前面缓存的案例中我们学过， cachetop 正好能满足这一点。那我们就来 cachetop 一下。

在第二个终端中，按下Ctrl+C停止sar命令，然后运行下面的cachetop命令，观察缓存的使用情况：

```
$ cachetop 5
12:28:28 Buffers MB: 6349 / Cached MB: 87 / Sort: HITS / Order: ascending
PID      UID      CMD              HITS     MISSES   DIRTIES  READ_HIT%  WRITE_HIT%
   18280 root     python                 22        0        0     100.0%       0.0%
   18279 root     dd                  41088    41022        0      50.0%      50.0%
```

通过cachetop的输出，我们看到，dd进程的读写请求只有50%的命中率，并且未命中的缓存页数（MISSES）为41022（单位是页）。这说明，正是案例开始时运行的dd，导致了缓冲区使用升高。

你可能接着会问，为什么Swap也跟着升高了呢？直观来说，缓冲区占了系统绝大部分内存，还属于可回收内存，内存不够用时，不应该先回收缓冲区吗？

这种情况，我们还得进一步通过 /proc/zoneinfo ，观察剩余内存、内存阈值以及匿名页和文件页的活跃情况。

你可以在第二个终端中，按下Ctrl+C，停止cachetop命令。然后运行下面的命令，观察 /proc/zoneinfo 中这几个指标的变化情况：

```
# -d 表示高亮变化的字段
# -A 表示仅显示Normal行以及之后的15行输出
$ watch -d grep -A 15 'Normal' /proc/zoneinfo
Node 0, zone   Normal
  pages free     21328
        min      14896
        low      18620
        high     22344
        spanned  1835008
        present  1835008
        managed  1796710
        protection: (0, 0, 0, 0, 0)
      nr_free_pages 21328
      nr_zone_inactive_anon 79776
      nr_zone_active_anon 206854
      nr_zone_inactive_file 918561
      nr_zone_active_file 496695
      nr_zone_unevictable 2251
      nr_zone_write_pending 0
```

你可以发现，剩余内存（pages_free）在一个小范围内不停地波动。当它小于页低阈值（pages_low) 时，又会突然增大到一个大于页高阈值（pages_high）的值。

再结合刚刚用 sar 看到的剩余内存和缓冲区的变化情况，我们可以推导出，剩余内存和缓冲区的波动变化，正是由于内存回收和缓存再次分配的循环往复。

- 当剩余内存小于页低阈值时，系统会回收一些缓存和匿名内存，使剩余内存增大。其中，缓存的回收导致sar中的缓冲区减小，而匿名内存的回收导致了Swap的使用增大。
- 紧接着，由于dd还在继续，剩余内存又会重新分配给缓存，导致剩余内存减少，缓冲区增大。

其实还有一个有趣的现象，如果多次运行dd和sar，你可能会发现，在多次的循环重复中，有时候是Swap用得比较多，有时候Swap很少，反而缓冲区的波动更大。

换句话说，系统回收内存时，有时候会回收更多的文件页，有时候又回收了更多的匿名页。

显然，系统回收不同类型内存的倾向，似乎不那么明显。你应该想到了上节课提到的swappiness，正是调整不同类型内存回收的配置选项。

还是在第二个终端中，按下Ctrl+C停止watch命令，然后运行下面的命令，查看swappiness的配置：

```
$ cat /proc/sys/vm/swappiness
60
```

swappiness显示的是默认值60，这是一个相对中和的配置，所以系统会根据实际运行情况，选择合适的回收类型，比如回收不活跃的匿名页，或者不活跃的文件页。

到这里，我们已经找出了Swap发生的根源。另一个问题就是，刚才的Swap到底影响了哪些应用程序呢？换句话说，Swap换出的是哪些进程的内存？

这里我还是推荐 proc文件系统，用来查看进程Swap换出的虚拟内存大小，它保存在 /proc/pid/status中的VmSwap中（推荐你执行man proc来查询其他字段的含义）。

在第二个终端中运行下面的命令，就可以查看使用Swap最多的进程。注意for、awk、sort都是最常用的Linux命令，如果你还不熟悉，可以用man来查询它们的手册，或上网搜索教程来学习。

```
# 按VmSwap使用量对进程排序，输出进程名称、进程ID以及SWAP用量
$ for file in /proc/*/status ; do awk '/VmSwap|Name|^Pid/{printf $2 " " $3}END{ print ""}' $file; done | sort -k 3 -n -r | head
dockerd 2226 10728 kB
docker-containe 2251 8516 kB
snapd 936 4020 kB
networkd-dispat 911 836 kB
polkitd 1004 44 kB
```

从这里你可以看到，使用Swap比较多的是dockerd 和 docker-containe 进程，所以，当dockerd再次访问这些换出到磁盘的内存时，也会比较慢。

这也说明了一点，虽然缓存属于可回收内存，但在类似大文件拷贝这类场景下，系统还是会用Swap机制来回收匿名内存，而不仅仅是回收占用绝大部分内存的文件页。

你可以运行下面的命令，关闭Swap：

```
$ swapoff -a
```

实际上，关闭Swap后再重新打开，也是一种常用的Swap空间清理方法，比如：

```
$ swapoff -a && swapon -a 
```



## 小结

在内存资源紧张时，Linux 会通过 Swap ，把不常访问的匿名页换出到磁盘中，下次访问的时候再从磁盘换入到内存中来。你可以设置/proc/sys/vm/min_free_kbytes，来调整系统定期回收内存的阈值；也可以设置/proc/sys/vm/swappiness，来调整文件页和匿名页的回收倾向。

当Swap变高时，你可以用 sar、/proc/zoneinfo、/proc/pid/status等方法，查看系统和进程的内存使用情况，进而找出Swap升高的根源和受影响的进程。

反过来说，通常，降低Swap的使用，可以提高系统的整体性能。总结了几种常见的降低方法。

- 禁止Swap，现在服务器的内存足够大，所以除非有必要，禁用Swap就可以了。随着云计算的普及，大部分云平台中的虚拟机都默认禁止Swap。
- 如果实在需要用到Swap，可以尝试降低swappiness的值，减少内存回收时Swap的使用倾向。
- 响应延迟敏感的应用，如果它们可能在开启Swap的服务器中运行，你还可以用库函数 mlock() 或者 mlockall()锁定内存，阻止它们的内存换出。

