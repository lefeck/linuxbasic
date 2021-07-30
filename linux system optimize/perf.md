



perf

perf是Linux下的一款性能分析工具，能够进行函数级与指令级的热点查找。 

Perf List

> 利用perf剖析程序性能时，需要指定当前测试的性能时间。性能事件是指在处理器或操作系统中发生的，可能影响到程序性能的硬件事件或软件事件

Perf top

```
Perf top
实时显示系统/进程的性能统计信息
 
常用参数
 
-e：指定性能事件
 
-a：显示在所有CPU上的性能统计信息
 
-C：显示在指定CPU上的性能统计信息
 
-p：指定进程PID
 
-t：指定线程TID
 
-K：隐藏内核统计信息
 
-U：隐藏用户空间的统计信息
 
-s：指定待解析的符号信息
 
‘‐G’ or‘‐‐call‐graph’ <output_type,min_percent,call_order>
 
graph: 使用调用树，将每条调用路径进一步折叠。这种显示方式更加直观。
 
每条调用路径的采样率为绝对值。也就是该条路径占整个采样域的比率。
 
fractal
 
默认选项。类似与 graph，但是每条路径前的采样率为相对值。
 
flat
 
不折叠各条调用
 
选项 call_order 用以设定调用图谱的显示顺序，该选项有 2个取值，分别是
 
callee 与caller。
 
将该选项设为callee 时，perf按照被调用的顺序显示调用图谱，上层函数被下层函数所调用。
 
该选项被设为caller 时，按照调用顺序显示调用图谱，即上层函数调用了下层函数路径，也不显示每条调用路径的采样率
```

注： Perf top需要root权限



```
Perf stat
分析系统/进程的整体性能概况
 
task‐clock事件表示目标任务真正占用处理器的时间，单位是毫秒。也称任务执行时间
 
context-switches是系统发生上下文切换的次数
 
CPU-migrations是任务从一个处理器迁往另外一个处理器的次数
 
page-faults是内核发生缺页的次数
 
cycles是程序消耗的处理器周期数
 
instructions是指命令执行期间产生的处理器指令数
 
branches是指程序在执行期间遇到的分支指令数。
 
branch‐misses是预测错误的分支指令数。
 
XXX seconds time elapsed系程序持续时间
 
任务执行时间/任务持续时间大于1，那可以肯定是多核引起的
 
参数设置：
 
-e：选择性能事件
 
-i：禁止子任务继承父任务的性能计数器。
 
-r：重复执行 n 次目标程序，并给出性能指标在n 次执行中的变化范围。
 
-n：仅输出目标程序的执行时间，而不开启任何性能计数器。
 
-a：指定全部cpu
 
-C：指定某个cpu
 
-A：将给出每个处理器上相应的信息。
 
-p：指定待分析的进程id
 
-t：指定待分析的线程id
```





```
Perf record
记录一段时间内系统/进程的性能时间
 
参数：
 
 -e：选择性能事件
 
 -p：待分析进程的id
 
 -t：待分析线程的id
 
 -a：分析整个系统的性能
 
 -C：只采集指定CPU数据
 
 -c：事件的采样周期
 
 -o：指定输出文件，默认为perf.data
 
 -A：以append的方式写输出文件
 
 -f：以OverWrite的方式写输出文件
 
 -g：记录函数间的调用关系
```







```
Perf Report
读取perf record生成的数据文件，并显示分析数据
 
参数
 
-i：输入的数据文件
 
-v：显示每个符号的地址
 
-d <dos>：只显示指定dos的符号
 
-C：只显示指定comm的信息（Comm. 触发事件的进程名）
 
-S：只考虑指定符号
 
-U：只显示已解析的符号
 
-g[type,min,order]：显示调用关系，具体等同于perf top命令中的-g
 
-c：只显示指定cpu采样信息
 
-M：以指定汇编指令风格显示
 
–source：以汇编和source的形式进行显示
 
-p<regex>：用指定正则表达式过滤调用函数
```





 

例1

```
# perf top -e cycles:k     #显示内核和模块中，消耗最多CPU周期的函数 # perf top -e kmem:kmem_cache_alloc     #显示分配高速缓存最多的函数 # perf top Samples: 1M of event 'cycles', Event count (approx.): 73891391490
     5.44%  perf              [.] 0x0000000000023256
     4.86%  [kernel]          [k] _spin_lock
     2.43%  [kernel]          [k] _spin_lock_bh
     2.29%  [kernel]          [k] _spin_lock_irqsave
     1.77%  [kernel]          [k] __d_lookup
     1.55%  libc-2.12.so      [.] __strcmp_sse42
     1.43%  nginx             [.] ngx_vslprintf
     1.37%  [kernel]          [k] tcp_poll
第一列：符号引发的性能事件的比例，默认指占用的cpu周期比例。
第二列：符号所在的DSO(Dynamic Shared Object)，可以是应用程序、内核、动态链接库、模块。
第三列：DSO的类型。[.]表示此符号属于用户态的ELF文件，包括可执行文件与动态链接库)。[k]表述此符号属于内核或模块。
第四列：符号名。有些符号不能解析为函数名，只能用地址表示。
```



例2

```
# perf top -G         #得到调用关系图 # perf top -e cycles         #指定性能事件 # perf top -p 23015,32476         #查看这两个进程的cpu cycles使用情况 # perf top -s comm,pid,symbol         #显示调用symbol的进程名和进程号 # perf top --comms nginx,top         #仅显示属于指定进程的符号 # perf top --symbols kfree         #仅显示指定的符号
```



 

例3

```
#  perf stat ls   Performance counter stats for 'ls':           0.653782 task-clock                #    0.691 CPUs utilized
                 0 context-switches          #    0.000 K/sec
                 0 CPU-migrations            #    0.000 K/sec
               247 page-faults               #    0.378 M/sec
         1,625,426 cycles                    #    2.486 GHz
         1,050,293 stalled-cycles-frontend   #   64.62% frontend cycles idle
           838,781 stalled-cycles-backend    #   51.60% backend  cycles idle
         1,055,735 instructions              #    0.65  insns per cycle
                                             #    0.99  stalled cycles per insn
           210,587 branches                  #  322.106 M/sec
            10,809 branch-misses             #    5.13% of all branches                0.000945883 seconds time elapsed 	输出包括ls的执行时间，以及10个性能事件的统计。 	task-clock：任务真正占用的处理器时间，单位为ms。CPUs utilized = task-clock / time elapsed，CPU的占用率。 	context-switches：上下文的切换次数。 	CPU-migrations：处理器迁移次数。Linux为了维持多个处理器的负载均衡，在特定条件下会将某个任务从一个CPU 	迁移到另一个CPU。 	page-faults：缺页异常的次数。当应用程序请求的页面尚未建立、请求的页面不在内存中，或者请求的页面虽然在内 	存中，但物理地址和虚拟地址的映射关系尚未建立时，都会触发一次缺页异常。另外TLB不命中，页面访问权限不匹配 	等情况也会触发缺页异常。 	cycles：消耗的处理器周期数。如果把被ls使用的cpu cycles看成是一个处理器的，那么它的主频为2.486GHz。 	可以用cycles / task-clock算出。 	stalled-cycles-frontend：略过。 	stalled-cycles-backend：略过。 	instructions：执行了多少条指令。IPC为平均每个cpu cycle执行了多少条指令。 	branches：遇到的分支指令数。branch-misses是预测错误的分支指令数。 #  perf stat -r 10 ls > /dev/null         #执行10次程序，给出标准偏差与期望的比值 #  perf stat -v ls > /dev/null         #显示更详细的信息 #  perf stat -n ls > /dev/null         #只显示任务执行时间，不显示性能计数器 #  perf stat -a -A ls > /dev/null         #单独给出每个CPU上的信息 #  perf stat -e syscalls:sys_enter ls          #ls命令执行了多少次系统调用
```



 

例4

```
#  perf record -p `pgrep -d ',' nginx`      #记录nginx进程的性能数据 #  perf record ls -g    #记录执行ls时的性能数据 # perf record -e syscalls:sys_enter ls      #记录执行ls时的系统调用，可以知道哪些系统调用最频繁
```



 

例5

```
#   perf lock record ls      #记录 #   perf lock report      #报告                 Name   acquired  contended total wait (ns)   max wait (ns)   min wait (ns)   &mm->page_table_...        382          0               0               0               0
 &mm->page_table_...         72          0               0               0               0
           &fs->lock         64          0               0               0               0
         dcache_lock         62          0               0               0               0
       vfsmount_lock         43          0               0               0               0
 &newf->file_lock...         41          0               0               0               0  Name：内核锁的名字。
aquired：该锁被直接获得的次数，因为没有其它内核路径占用该锁，此时不用等待。
contended：该锁等待后获得的次数，此时被其它内核路径占用，需要等待。
total wait：为了获得该锁，总共的等待时间。
max wait：为了获得该锁，最大的等待时间。
min wait：为了获得该锁，最小的等待时间。
```



 

例6

```
#  perf kmem record ls      #记录 #  perf kmem stat --caller --alloc -l 20      #报告 ------------------------------------------------------------------------------------------------------
 Callsite                           | Total_alloc/Per | Total_req/Per   | Hit      | Ping-pong | Frag
------------------------------------------------------------------------------------------------------
 perf_event_mmap+ec                 |    311296/8192  |    155952/4104  |       38 |        0 | 49.902%
 proc_reg_open+41                   |        64/64    |        40/40    |        1 |        0 | 37.500%
 __kmalloc_node+4d                  |      1024/1024  |       664/664   |        1 |        0 | 35.156%
 ext3_readdir+5bd                   |        64/64    |        48/48    |        1 |        0 | 25.000%
 load_elf_binary+8ec                |       512/512   |       392/392   |        1 |        0 | 23.438% Callsite：内核代码中调用kmalloc和kfree的地方。
Total_alloc/Per：总共分配的内存大小，平均每次分配的内存大小。
Total_req/Per：总共请求的内存大小，平均每次请求的内存大小。
Hit：调用的次数。
Ping-pong：kmalloc和kfree不被同一个CPU执行时的次数，这会导致cache效率降低。
Frag：碎片所占的百分比，碎片 = 分配的内存 - 请求的内存，这部分是浪费的。
有使用--alloc选项，还会看到Alloc Ptr，即所分配内存的地址。
```

 

例7

```
#  perf sched record sleep 10     #  perf report latency --sort max      ---------------------------------------------------------------------------------------------------------------
  Task                  |   Runtime ms  | Switches | Average delay ms | Maximum delay ms | Maximum delay at     |
 ---------------------------------------------------------------------------------------------------------------
  events/10:61          |      0.655 ms |       10 | avg:    0.045 ms | max:    0.161 ms | max at: 9804.958730 s
  sleep:11156           |      2.263 ms |        4 | avg:    0.052 ms | max:    0.118 ms | max at: 9804.865552 s
  edac-poller:1125      |      0.598 ms |       10 | avg:    0.042 ms | max:    0.113 ms | max at: 9804.958698 s
  events/2:53           |      0.676 ms |       10 | avg:    0.037 ms | max:    0.102 ms | max at: 9814.751605 s
  perf:11155            |      2.109 ms |        1 | avg:    0.068 ms | max:    0.068 ms | max at: 9814.867918 s TASK：进程名和pid。
Runtime：实际的运行时间。
Switches：进程切换的次数。
Average delay：平均的调度延迟。
Maximum delay：最大的调度延迟。
Maximum delay at：最大调度延迟发生的时刻。
```

 

例8

```
#  perf probe --line schedule    #前面有行号的可以探测，没有行号的就不行了 #  perf report latency --sort max    #在schedule函数的12处增加一个探测点
```