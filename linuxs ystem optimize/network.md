# Linux 网络(上)

同 CPU、内存以及 I/O 一样，网络也是 Linux 系统最核心的功能。网络是一种把不同计算机或网络设备连接到一起的技术，它本质上是一种进程间通信方式，特别是跨系统的进程
间通信，必须要通过网络才能进行。随着高并发、分布式、云计算、微服务等技术的普及，网络的性能也变得越来越重要。

接下来的两篇文章，我将带一起学习 Linux 网络的工作原理和性能指标。

## 二、网络模型

说到网络，我想肯定经常提起七层负载均衡、四层负载均衡，或者三层设备、二层设备等等。那么，这里说的二层、三层、四层、七层又都是什么意思呢？

### 1、OSI 网络模型

实际上，这些层都来自国际标准化组织制定的开放式系统互联通信参考模型（OpenSystem Interconnection Reference Model），简称为 **OSI 网络模型**。

为了解决网络互联中异构设备的兼容性问题，并解耦复杂的网络包处理流程，OSI 模型把网络互联的框架分为应用层、表示层、会话层、传输层、网络层、数据链路层以及物理层
等七层，每个层负责不同的功能。其中，

* 应用层，负责为应用程序提供统一的接口。
* 表示层，负责把数据转换成兼容接收系统的格式。
* 会话层，负责维护计算机之间的通信连接。
* 传输层，负责为数据加上传输表头，形成数据包。
* 网络层，负责数据的路由和转发。
* 数据链路层，负责 MAC 寻址、错误侦测和改错。

### **2、TCP/IP 模型**

**但是 OSI 模型还是太复杂了，也没能提供一个可实现的方法。所以，在 Linux 中，实际上使用的是另一个更实用的四层模型，即 TCP/IP 网络模型。**

TCP/IP 模型，把网络互联的框架分为应用层、传输层、网络层、网络接口层等四层，其中，

* 物理层，负责在物理网络中传输数据帧。
* 应用层，负责向用户提供一组应用程序，比如 HTTP、FTP、DNS 等。
* 传输层，负责端到端的通信，比如 TCP、UDP 等。
* 网络层，负责网络包的封装、寻址和路由，比如 IP、ICMP 等。
* 网络接口层，负责网络包在物理网络中的传输，比如 MAC 寻址、错误侦测以及通过网卡传输网络帧等。

为了帮更形象理解 TCP/IP 与 OSI 模型的关系，我画了一张图，如下所示：

![分享图片](http://img.shangdixinxi.com/up/info/202002/20200216221831965214.png)

当然了，虽说 Linux 实际按照 TCP/IP 模型，实现了网络协议栈，但在平时的学习交流中，习惯上还是用 OSI 七层模型来描述。比如，说到七层和四层负载均衡，对应的分
别是 OSI 模型中的应用层和传输层（而它们对应到 TCP/IP 模型中，实际上是四层和三层）。

TCP/IP 模型包括了大量的网络协议，这些协议的原理，也是每个人必须掌握的核心基础知识。如果不太熟练，推荐去学《TCP/IP 详解》的卷一和卷二，或者学习极客时间
出品的《 趣谈网络协议》专栏。

## 三、Linux 网络栈

有了 TCP/IP 模型后，在进行网络传输时，数据包就会按照协议栈，对上一层发来的数据进行逐层处理；然后封装上该层的协议头，再发送给下一层。

当然，网络包在每一层的处理逻辑，都取决于各层采用的网络协议。比如在应用层，一个提供 REST API 的应用，可以使用 HTTP 协议，把它需要传输的 JSON 数据封装到 HTTP
协议中，然后向下传递给 TCP 层。

### 1、封装

而封装做的事情就很简单了，只是在原来的负载前后，增加固定格式的元数据，原始的负载数据并不会被修改。

比如，以通过 TCP 协议通信的网络包为例，通过下面这张图，可以看到，应用程序数据在每个层的封装格式

![分享图片](http://img.shangdixinxi.com/up/info/202002/20200216221832354859.png)

其中：

* 传输层在应用程序数据前面增加了 TCP 头；
* 网络层在 TCP 数据包前增加了 IP 头；
* 而网络接口层，又在 IP 数据包前后分别增加了帧头和帧尾。

这些新增的头部和尾部，都按照特定的协议格式填充，想了解具体格式，可以查看协议的文档。



### **2、什么是MTU？Linux MTU默认值是多少**

这些新增的头部和尾部，增加了网络包的大小，但都知道，**物理链路中并不能传输任意大小的数据包**。网络接口配置的最大传输单元（MTU），就规定了最大的 IP 包大小。
在最常用的以太网中，**MTU 默认值是 1500（这也是 Linux 的默认值）**。

**一旦网络包超过 MTU 的大小，就会在网络层分片，以保证分片后的 IP 包不大于 MTU值。**显然，MTU 越大，需要的分包也就越少，自然，网络吞吐能力就越好。

理解了 TCP/IP 网络模型和网络包的封装原理后，很容易能想到，Linux 内核中的网络栈，其实也类似于 TCP/IP 的四层结构。如下图所示，就是 Linux 通用 IP 网络栈的示意

图：

![分享图片](http://img.shangdixinxi.com/up/info/202002/20200216221832656610.png)



### 3、网卡设备

从上到下来看这个网络栈，可以发现，

* 最上层的应用程序，需要通过系统调用，来跟套接字接口进行交互；
* 套接字的下面，就是前面提到的传输层、网络层和网络接口层；
* 最底层，则是网卡驱动程序以及物理网卡设备。

#### 这里我简单说一下网卡：

* 网卡是发送和接收网络包的基本设备。
* 在系统启动过程中，网卡通过内核中的网卡驱动程序注册到系统中。
* 而在网络收发过程中，内核通过中断跟网卡进行交互。

再结合前面提到的 Linux 网络栈，可以看出，网络包的处理非常复杂。所以，**网卡硬中断只处理最核心的网卡数据读取或发送**，而协议栈中的大部分逻辑，**都会放到软中断中处理**。



## 四、Linux 网络收发流程

了解了 Linux 网络栈后，再来看看， Linux 到底是怎么收发网络包的。

注意，以下内容都以物理网卡为例。事实上，Linux 还支持众多的虚拟网络
设备，而它们的网络收发流程会有一些差别。

### 1、网络包的接收流程

先来看网络包的接收流程。

1、当一个网络帧到达网卡后，网卡会通过 DMA 方式，把这个网络包放到收包队列中；然后通过硬中断，告诉中断处理程序已经收到了网络包。

2、接着，网卡中断处理程序会为网络帧分配内核数据结构（sk_buff），并将其拷贝到sk_buff 缓冲区中；然后再通过软中断，通知内核收到了新的网络帧。

3、接下来，内核协议栈从缓冲区中取出网络帧，并通过网络协议栈，从下到上逐层处理这个网络帧。比如，

* 在链路层检查报文的合法性，找出上层协议的类型（比如 IPv4 还是 IPv6），再去掉帧头、帧尾，然后交给网络层。

* 网络层取出 IP 头，判断网络包下一步的走向，比如是交给上层处理还是转发。当网络层确认这个包是要发送到本机后，就会取出上层协议的类型（比如 TCP 还是 UDP），去掉 IP 头，再交给传输层处理。

* 传输层取出 TCP 头或者 UDP 头后，根据 < 源 IP、源端口、目的 IP、目的端口 > 四元组作为标识，找出对应的 Socket，并把数据拷贝到 Socket 的接收缓存中。

* 最后，应用程序就可以使用 Socket 接口，读取到新接收到的数据了。

为了更清晰表示这个流程，我画了一张图，这张图的左半部分表示接收流程，而图中的粉色箭头则表示网络包的处理路径。

### ![分享图片](http://img.shangdixinxi.com/up/info/202002/20200216221832988637.png)

 

 

### 2、网络包的发送流程

了解网络包的接收流程后，就很容易理解网络包的发送流程。网络包的发送流程就是上图的右半部分，很容易发现，网络包的发送方向，正好跟接收方向相反。

首先，应用程序调用 Socket API（比如 sendmsg）发送网络包。

由于这是一个系统调用，所以会陷入到内核态的套接字层中。套接字层会把数据包放到Socket 发送缓冲区中。

接下来，网络协议栈从 Socket 发送缓冲区中，

取出数据包；再按照 TCP/IP 栈，从上到下逐层处理。比如，

* 传输层和网络层，分别为其增加 TCP 头和 IP 头，执行路由查找确认下一跳的 IP，并按照 MTU 大小进行分片。

* 分片后的网络包，再送到网络接口层，进行物理地址寻址，以找到下一跳的 MAC 地址。然后添加帧头和帧尾，放到发包队列中。

* 完成后，会有软中断通知驱动程序：发包队列中有新的网络帧需要发送

最后，驱动程序通过 DMA ，从发包队列中读出网络帧，并通过物理网卡把它发送出去。



##  五、小结

在今天的文章中，我带一起梳理了 Linux 网络的工作原理。

多台服务器通过网卡、交换机、路由器等网络设备连接到一起，构成了相互连接的网络。由于网络设备的异构性和网络协议的复杂性，国际标准化组织定义了一个七层的 OSI 网络
模型，但是这个模型过于复杂，实际工作中的事实标准，是更为实用的 TCP/IP 模型。

TCP/IP 模型，把网络互联的框架，分为应用层、传输层、网络层、网络接口层等四层，这也是 Linux 网络栈最核心的构成部分。

1、应用程序通过套接字接口发送数据包，先要在网络协议栈中从上到下进行逐层处理，最终再送到网卡发送出去。

2、而接收时，同样先经过网络栈从下到上的逐层处理，最终才会送到应用程序。



#  Linux 网络(下)

上一节，我带学习了 Linux 网络的基础原理。简单回顾一下，Linux 网络根据 TCP/IP模型，构建其网络协议栈。TCP/IP 模型由应用层、传输层、网络层、网络接口层等四层组
成，这也是 Linux 网络栈最核心的构成部分。

应用程序通过套接字接口发送数据包时，先要在网络协议栈中从上到下逐层处理，然后才最终送到网卡发送出去；而接收数据包时，也要先经过网络栈从下到上的逐层处理，最后送到应用程序。

了解 Linux 网络的基本原理和收发流程后，如何去观察网络的性能情况。具体而言，哪些指标可以用来衡量 Linux 的网络性能呢？



## 二、性能指标

实际上，通常用带宽、吞吐量、延时、PPS（Packet Per Second）等指标衡量网络的性能。

**带宽:**表示链路的最大传输速率，单位通常为 b/s （比特 / 秒）。

**吞吐量:**表示单位时间内成功传输的数据量，单位通常为 b/s（比特 / 秒）或者B/s（字节 / 秒）。吞吐量受带宽限制，而吞吐量 / 带宽，也就是该网络的使用率。

**延时:**表示从网络请求发出后，一直到收到远端响应，所需要的时间延迟。在不同场景中，这一指标可能会有不同含义。比如，它可以表示，建立连接需要的时间（比如 TCP
握手延时），或一个数据包往返所需的时间（比如 RTT）。

**PPS:**是 Packet Per Second（包 / 秒）的缩写，表示以网络包为单位的传输速率。PPS 通常用来评估网络的转发能力，比如硬件交换机，通常可以达到线性转发（即 PPS
  可以达到或者接近理论最大值）。而基于 Linux 服务器的转发，则容易受网络包大小的影响。 

除了这些指标，网络的可用性（网络能否正常通信）、并发连接数（TCP 连接数量）、丢包率（丢包百分比）、重传率（重新传输的网络包比例）等也是常用的性能指标。
接下来，请打开一个终端，SSH 登录到服务器上，然后跟我一起来探索、观测这些性能指标。

## 三、网络配置

分析网络问题的第一步，通常是查看网络接口的配置和状态。可以使用 ifconfig 或者 ip命令，来查看网络的配置。我个人更推荐使用 ip 工具，因为它提供了更丰富的功能和更易
用的接口。

以网络接口 eth0 为例，可以运行下面的两个命令，查看它的配置和状态：

```
root@luoahong:~# ifconfig ens34
ens34: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 192.168.118.74  netmask 255.255.255.0  broadcast 192.168.118.255
        inet6 fe80::20c:29ff:fe03:d3a7  prefixlen 64  scopeid 0x20<link>
        ether 00:0c:29:03:d3:a7  txqueuelen 1000  (Ethernet)
        RX packets 460768  bytes 587423814 (587.4 MB)
        RX errors 0  dropped 100  overruns 0  frame 0
        TX packets 122590  bytes 29027840 (29.0 MB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

root@luoahong:~# ip -s addr show dev ens34
2: ens34: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 00:0c:29:03:d3:a7 brd ff:ff:ff:ff:ff:ff
    inet 192.168.118.74/24 brd 192.168.118.255 scope global dynamic ens34
       valid_lft 66745sec preferred_lft 66745sec
    inet6 fe80::20c:29ff:fe03:d3a7/64 scope link
       valid_lft forever preferred_lft forever
    RX: bytes  packets  errors  dropped overrun mcast
    587440742  460987   0       100     0       0
    TX: bytes  packets  errors  dropped carrier collsns
    29036492   122677   0       0       0       0
```

可以看到，ifconfig 和 ip 命令输出的指标基本相同，只是显示格式略微不同。比如，它们都包括了网络接口的状态标志、MTU 大小、IP、子网、MAC 地址以及网络包收发的统计信息。

这些具体指标的含义，在文档中都有详细的说明，不过，这里有几个跟网络性能密切相关的指标。
		第一，网络接口的状态标志。ifconfig 输出中的 RUNNING ，或 ip 输出中的LOWER_UP ，都表示物理网络是连通的，即网卡已经连接到了交换机或者路由器中。如
     果看不到它们，通常表示网线被拔掉了。
		第二，MTU 的大小。MTU 默认大小是 1500，根据网络架构的不同（比如是否使用了VXLAN 等叠加网络），可能需要调大或者调小 MTU 的数值。

第三，网络接口的 IP 地址、子网以及 MAC 地址。这些都是保障网络功能正常工作所必需的，需要确保配置正确。
		第四，网络收发的字节数、包数、错误数以及丢包情况，特别是 TX 和 RX 部分的errors、dropped、overruns、carrier 以及 collisions 等指标不为 0 时，通常表示出现
了网络 I/O 问题。其中：

* errors 表示发生错误的数据包数，比如校验错误、帧同步错误等；
* dropped 表示丢弃的数据包数，即数据包已经收到了 Ring Buffer，但因为内存不足等原因丢包；
* overruns 表示超限数据包数，即网络 I/O 速度过快，导致 Ring Buffer 中的数据包来不及处理（队列满）而导致的丢包；
* carrier 表示发生 carrirer 错误的数据包数，比如双工模式不匹配、物理电缆出现问题等；
* collisions 表示碰撞数据包数, 则表示由于 CSMA/CD 造成的传输中断,比如ip地址冲突造成的。

## 四、套接字信息

ifconfig 和 ip 只显示了网络接口收发数据包的统计信息，但在实际的性能问题中，网络协议栈中的统计信息，也必须关注。可以用 netstat 或者 ss ，来查看套接字、网络
栈、网络接口以及路由表的信息。

**个人推荐，使用 ss 来查询网络的连接信息，因为它比 netstat 提供了更好的性能（速度更快）**。比如，可以执行下面的命令，查询套接字信息：

```
root@luoahong:~# netstat -nlp|head -n 3
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Programname
tcp        0      0 127.0.0.53:53           0.0.0.0:*               LISTEN      840/systemd-resolve
root@luoahong:~# ss -ltnp|head -n 3
State    Recv-Q    Send-Q        Local Address:Port        Peer Address:Port
LISTEN   0         128           127.0.0.53%lo:53               0.0.0.0:*        users:(("systemd-resolve",pid=840,fd=13))
LISTEN   0         128                 0.0.0.0:22               0.0.0.0:*        users:(("sshd",pid=1215,fd=3))
```

netstat 和 ss 的输出也是类似的，都展示了套接字的状态、接收队列、发送队列、本地地址、远端地址、进程 PID 和进程名称等。

其中， **接收队列（Recv-Q）和发送队列（Send-Q）需要特别关注**，它们通常应该是0。 **当发现它们不是 0 时，说明有网络包的堆积发生**。当然还要注意，在不同套接字状态下，它们的含义不同。

**1、当套接字处于连接状态（Established）时，**

Recv-Q 表示套接字缓冲还没有被应用程序取走的字节数（即接收队列长度）。而 Send-Q 表示还没有被远端主机确认的字节数（即发送队列长度）。

**2、当套接字处于监听状态（Listening）时，**

Recv-Q 表示 syn backlog 的当前值。而 Send-Q 表示最大的 syn backlog 值。

而 syn backlog 是 TCP 协议栈中的半连接队列长度，相应的也有一个全连接队列（accept queue），它们都是维护 TCP 状态的重要机制。

**3、什么是半路连接？**

顾名思义，所谓半连接，就是还没有完成 TCP 三次握手的连接，连接只进行了一半，而服务器收到了客户端的 SYN 包后，就会把这个连接放到半连接队列中，然后再向客户端发送
SYN+ACK 包。

**4、什么是全路连接？**

而全连接，则是指服务器收到了客户端的 ACK，完成了 TCP 三次握手，然后就会把这个连接挪到全连接队列中。这些全连接中的套接字，还需要再被 accept() 系统调用取走，这
样，服务器就可以开始真正处理客户端的请求了。

## 五、协议栈统计信息

类似的，使用 netstat 或 ss ，也可以查看协议栈的信息：

```
root@luoahong:~# netstat -s
Ip:
    Forwarding: 1
    207047 total packets received
    2 with invalid addresses
    216 forwarded
    0 incoming packets discarded
    206829 incoming packets delivered
    119198 requests sent out
    20 outgoing packets dropped
Icmp:
    43 ICMP messages received
    0 input ICMP message failed
    ICMP input histogram:
        destination unreachable: 40
        echo requests: 1
        echo replies: 2
    117 ICMP messages sent
    0 ICMP messages failed
    ICMP output histogram:
        destination unreachable: 114
        echo requests: 2
        echo replies: 1
IcmpMsg:
        InType0: 2
        InType3: 40
        InType8: 1
        OutType0: 1
        OutType3: 114
        OutType8: 2
Tcp:
    415 active connection openings
    3 passive connection openings
    0 failed connection attempts
    7 connection resets received
    1 connections established
    196251 segments received
    124187 segments sent out
    52 segments retransmitted
    0 bad segments received
    226 resets sent
Udp:
    1042 packets received
    139 packets to unknown port received
    0 packet receive errors
    1084 packets sent
    0 receive buffer errors
    0 send buffer errors
    IgnoredMulti: 9264
UdpLite:
TcpExt:
    5 TCP sockets finished time wait in fast timer
    149 delayed acks sent
    9 delayed acks further delayed because of locked socket
    Quick ack mode was activated 3 times
    161413 packet headers predicted
    12736 acknowledgments not containing data payload received
    2975 predicted acknowledgments
    TCPTimeouts: 10
    TCPLossProbes: 13
    TCPLossProbeRecovery: 2
    TCPDSACKOldSent: 3
    TCPDSACKRecv: 9
    6 connections reset due to unexpected data
    7 connections reset due to early user close
    TCPDSACKIgnoredNoUndo: 2
    TCPRcvCoalesce: 91930
    TCPOFOQueue: 10697
    TCPAutoCorking: 1357
    TCPSynRetrans: 40
    TCPOrigDataSent: 27150
    TCPHystartTrainDetect: 1
    TCPHystartTrainCwnd: 16
    TCPKeepAlive: 4
IpExt:
    InBcastPkts: 9264
    InOctets: 580667049
    OutOctets: 23375191
    InBcastOctets: 1053751
    InNoECTPkts: 424052
root@luoahong:~# ss -s
Total: 556 (kernel 2442)
TCP:   4 (estab 1, closed 0, orphaned 0, synrecv 0, timewait 0/0), ports 0

Transport Total     IP        IPv6
*	  2442      -         -
RAW	  1         0         1
UDP	  2         2         0
TCP	  4         3         1
INET	  7         5         2
FRAG	  0         0         0
```

这些协议栈的统计信息都很直观。ss 只显示已经连接、关闭、孤儿套接字等简要统计，而netstat 则提供的是更详细的网络协议栈信息。

比如，上面 netstat 的输出示例，就展示了 TCP 协议的主动连接、被动连接、失败重试、发送和接收的分段数量等各种信息。



## 六、网络吞吐和 PPS

接下来，再来看看，如何查看系统当前的网络吞吐量和 PPS。在这里，我推荐使用的老朋友 sar，在前面的 CPU、内存和 I/O 模块中，已经多次用到它。
给 sar 增加 -n 参数就可以查看网络的统计信息，比如网络接口（DEV）、网络接口错误（EDEV）、TCP、UDP、ICMP 等等。执行下面的命令，就可以得到网络接口统计信息：

```
root@luoahong:~# sar -n DEV 1
Linux 4.15.0-48-generic (luoahong) 	09/03/2019 	_x86_64_	(2 CPU)
04:51:51 PM     IFACE   rxpck/s   txpck/s    rxkB/s    txkB/s   rxcmp/s   txcmp/s  rxmcst/s   %ifutil
04:51:52 PM     ens34      4.95      0.99      0.52      0.80      0.00      0.00      0.00      0.00
04:51:52 PM        lo      0.00      0.00      0.00      0.00      0.00      0.00      0.00      0.00
04:51:52 PM   docker0      0.00      0.00      0.00      0.00      0.00      0.00      0.00      0.00

04:51:52 PM     IFACE   rxpck/s   txpck/s    rxkB/s    txkB/s   rxcmp/s   txcmp/s  rxmcst/s   %ifutil
04:51:53 PM     ens34      3.00      1.00      0.18      0.81      0.00      0.00      0.00      0.00
04:51:53 PM        lo      0.00      0.00      0.00      0.00      0.00      0.00      0.00      0.00
04:51:53 PM   docker0      0.00      0.00      0.00      0.00      0.00      0.00      0.00      0.00
^C


Average:        IFACE   rxpck/s   txpck/s    rxkB/s    txkB/s   rxcmp/s   txcmp/s  rxmcst/s   %ifutil
Average:        ens34      3.66      1.26      0.31      0.79      0.00      0.00      0.00      0.00
Average:           lo      0.00      0.00      0.00      0.00      0.00      0.00      0.00      0.00
Average:      docker0      0.00      0.00      0.00      0.00      0.00      0.00      0.00      0.00
```

这输出的指标比较多，简单解释下它们的含义。

* rxpck/s 和 txpck/s 分别是接收和发送的 PPS，单位为包 / 秒。
* rxkB/s 和 txkB/s 分别是接收和发送的吞吐量，单位是 KB/ 秒。
* rxcmp/s 和 txcmp/s 分别是接收和发送的压缩数据包数，单位是包 / 秒。
* %ifutil 是网络接口的使用率，即半双工模式下为 (rxkB/s+txkB/s)/Bandwidth，而全双工模式下为 max(rxkB/s, txkB/s)/Bandwidth

其中，Bandwidth 可以用 ethtool 来查询，它的单位通常是 Gb/s 或者 Mb/s，不过注意这里小写字母 b ，表示比特而不是字节。通常提到的千兆网卡、万兆网卡等，单位也
都是比特。如下可以看到，eth0 网卡就是一个千兆网卡：

```
root@luoahong:~#ethtool eth0 | grep Speed
	Speed: 1000Mb/s
```



## 七、连通性和延时

最后，通常使用 ping ，来测试远程主机的连通性和延时，而这基于 ICMP 协议。比如，执行下面的命令，就可以测试本机到 114.114.114.114 这个 IP 地址的连通性和延时： 

```
root@luoahong:~# ping -c3 114.114.114.114
PING 114.114.114.114 (114.114.114.114) 56(84) bytes of data.
64 bytes from 114.114.114.114: icmp_seq=1 ttl=70 time=22.7 ms
64 bytes from 114.114.114.114: icmp_seq=2 ttl=76 time=25.1 ms
64 bytes from 114.114.114.114: icmp_seq=3 ttl=89 time=23.2 ms

--- 114.114.114.114 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2005ms
rtt min/avg/max/mdev = 22.724/23.722/25.186/1.057 ms
```

**ping 的输出，可以分为两部分。**

第一部分，是每个 ICMP 请求的信息，包括 ICMP 序列号（icmp_seq）、TTL（生存时间，或者跳数）以及往返延时。

第二部分，则是三次 ICMP 请求的汇总。

比如上面的示例显示，发送了 3 个网络包，并且接收到 3 个响应，没有丢包发生，这说明测试主机到 114.114.114.114 是连通的；平均往返延时（RTT）是 22.7ms，也就是从发
送 ICMP 开始，到接收到 114.114.114.114 回复的确认，总共经历 22.7ms。



# C10K和C1000K

C10K 问题最早由 Dan Kegel 在 1999 年提出。那时的服务器还只是 32 位系统，运行着 Linux 2.2 版本（后来又升级到了 2.4 和 2.6，而 2.6 才支持 x86_64），只配置了很少的内存（2GB）和千兆网卡。

从资源上来说，对 2GB 内存和千兆网卡的服务器来说，同时处理 10000 个请求，只要每个请求处理占用不到 200KB（2GB/10000）的内存和 100Kbit （1000Mbit/10000）的网络带宽就可以。所以，物理资源是足够的，接下来自然是软件的问题，特别是网络的 I/O 模型问题。

说到 I/O 的模型，我在文件系统的原理中，曾经介绍过文件 I/O，其实网络 I/O 模型也类似。在 C10K 以前，Linux 中网络处理都用同步阻塞的方式，也就是每个请求都分配一个进程或者线程。请求数只有 100 个时，这种方式自然没问题，但增加到 10000 个请求时，10000 个进程或线程的调度、上下文切换乃至它们占用的内存，都会成为瓶颈。

既然每个请求分配一个线程的方式不合适，那么，为了支持 10000 个并发请求，这里就有两个问题需要解决。

第一，怎样在一个线程内处理多个请求，也就是要在一个线程内响应多个网络 I/O。以前的同步阻塞方式下，一个线程只能处理一个请求，到这里不再适用，是不是可以用非阻塞 I/O 或者异步 I/O 来处理多个网络请求呢？

第二，怎么更节省资源地处理客户请求，也就是要用更少的线程来服务这些请求。是不是可以继续用原来的 100 个或者更少的线程，来服务现在的 10000 个请求呢？

当然，事实上，现在 C10K 的问题早就解决了，在继续学习下面的内容前，可以先自己思考一下这两个问题。结合前面学过的内容，是不是已经有了解决思路呢？

## I/O 模型优化

异步、非阻塞 I/O 的解决思路，应该听说过，其实就是在网络编程中经常用到的 I/O 多路复用（I/O Multiplexing）。I/O 多路复用是什么意思呢？

先来讲两种 I/O 事件通知的方式：水平触发和边缘触发，它们常用在套接字接口的文件描述符中。

- 水平触发：只要文件描述符可以非阻塞地执行 I/O ，就会触发通知。也就是说，应用程序可以随时检查文件描述符的状态，然后再根据状态，进行 I/O 操作。
- 边缘触发：只有在文件描述符的状态发生改变（也就是 I/O 请求达到）时，才发送一次通知。这时候，应用程序需要尽可能多地执行 I/O，直到无法继续读写，才可以停止。如果 I/O 没执行完，或者因为某种原因没来得及处理，那么这次通知也就丢失了。

接下来，再回过头来看 I/O 多路复用的方法。这里其实有很多实现方法，我带来逐个分析一下。



### 第一种，使用非阻塞 I/O 和水平触发通知，比如使用 select 或者 poll。

select 和 poll 需要从文件描述符列表中，找出哪些可以执行I/O ，然后进行真正的网络I/O读写。由于I/O是非阻塞的，**一个线程中就可以同时监控一批套接字的文件描述符，这样就达到了单线程处理多请求的目的**。【多路复用指的就是粗体部分】

所以，这种方式的最大优点，是对应用程序比较友好，它的 API 非常简单。

但是，应用软件使用 select 和 poll 时，需要对这些文件描述符列表进行轮询，这样，请求数多的时候就会比较耗时。并且，select 和 poll 还有一些其他的限制。

缺点：

- select采用标量位，32位系统默认只能支持1024个描述符，且select的fd的状态位是也是用标量位来表示的，获取每个fd的状态需要轮询这个标量位。时间复杂度是o(n^2)
- pool采用了个无界数组，没有了1024的限制，时间复杂度是o(n)，但是他俩都需要将能读写的fd，从用户态转移到内核态修改状态每次都要进行切换会造成损耗



### 第二种，使用非阻塞 I/O 和边缘触发通知，比如 epoll。



既然 select 和 poll 有那么多的问题，就需要继续对其进行优化，而 epoll 就很好地解决了这些问题。

* epoll 使用红黑树，在内核中管理文件描述符的集合，这样，就不需要应用程序在每次操作时都传入、传出这个集合。
* epoll 使用事件驱动的机制，只关注有 I/O 事件发生的文件描述符，不需要轮询扫描整个集合。

不过要注意，epoll 是在 Linux 2.6 中才新增的功能（2.4 虽然也有，但功能不完善）。由于边缘触发只在文件描述符可读或可写事件发生时才通知，那么应用程序就需要尽可能多地执行 I/O，并要处理更多的异常事件。



### 第三种，使用异步 I/O（Asynchronous I/O，简称为 AIO）。



在前面文件系统原理的内容中，我曾介绍过异步 I/O 与同步 I/O 的区别。异步 I/O 允许应用程序同时发起很多 I/O 操作，而不用等待这些操作完成。而在 I/O 完成后，系统会用事件通知（比如信号或者回调函数）的方式，告诉应用程序。这时，应用程序才会去查询 I/O 操作的结果。

异步 I/O 也是到了 Linux 2.6 才支持的功能，并且在很长时间里都处于不完善的状态，比如 glibc 提供的异步 I/O 库，就一直被社区诟病。同时，由于异步 I/O 跟的直观逻辑不太一样，想要使用的话，一定要小心设计，其使用难度比较高。



### 工作模型优化



#### 第一种, 主进程 + 多个 worker 子进程, 这也是最常用的一种模型。这种方法的一个通用工作模式：

(1) 主进程执行 bind() + listen() 后，创建多个子进程；

(2) 每个子进程都 accept() 或epoll_wait() ，来处理相同的套接字。

比如，最常用的反向代理服务器 Nginx 就是这么工作的。它也是由主进程和多个 worker 进程组成。主进程主要用来初始化套接字，并管理子进程的生命周期；而 worker 进程，则负责实际的请求处理。关系图如下。

[![img](https://img2018.cnblogs.com/i-beta/1414775/202002/1414775-20200216213711473-2128097231.png)](https://img2018.cnblogs.com/i-beta/1414775/202002/1414775-20200216213711473-2128097231.png)

 

 这里要注意，accept() 和 epoll_wait() 调用，还存在一个惊群的问题。换句话说，当网络 I/O 事件发生时，多个进程被同时唤醒，但实际上只有一个进程来响应这个事件，其他被唤醒的进程都会重新休眠。

其中，accept() 的惊群问题，已经在 Linux 2.6 中解决了；

而 epoll 的问题，到了 Linux 4.5 ，才通过 EPOLLEXCLUSIVE 解决。

**解决方案：**

为了避免惊群问题， Nginx 在每个 worker 进程中，都增加一个了全局锁（accept_mutex）。这些 worker 进程需要首先竞争到锁，只有竞争到锁的进程，才会加入到 epoll 中，这样就确保只有一个 worker 子进程被唤醒



那为什么使用多进程模式的 Nginx ，却具有非常好的性能呢？

最主要的一个原因就是，这些 worker 进程，实际上并不需要经常创建和销毁，而是在没任务时休眠，有任务时唤醒。只有在 worker 由于某些异常退出时，主进程才需要创建新的进程来代替它。

当然，也可以用线程代替进程：主线程负责套接字初始化和子线程状态的管理，而子线程则负责实际的请求处理。由于线程的调度和切换成本比较低，实际上可以进一步把 epoll_wait() 都放到主线程中，保证每次事件都只唤醒主线程，而子线程只需要负责后续的请求处理。



## 第二种，监听到相同端口的多进程模型。

在这种方式下，所有的进程都监听相同的接口，并且开启 SO_REUSEPORT 选项，由内核负责将请求负载均衡到这些监听进程中去。这一过程如下图所示

![avator](https://liuhao163.github.io/%E7%B3%BB%E7%BB%9F%E4%BC%98%E5%8C%96-%E7%BD%91%E7%BB%9C-C10K%E5%92%8CC1000K%E5%9B%9E%E9%A1%BE-%E7%B3%BB%E7%BB%9F%E8%B0%83%E4%BC%98%E6%96%B9%E6%A1%88/img0.png)

这由于内核确保了只有一个进程被唤醒，就不会出现惊群问题了。比如，Nginx在1.9.1中就已经支持了这种模式。

![avator](https://liuhao163.github.io/%E7%B3%BB%E7%BB%9F%E4%BC%98%E5%8C%96-%E7%BD%91%E7%BB%9C-C10K%E5%92%8CC1000K%E5%9B%9E%E9%A1%BE-%E7%B3%BB%E7%BB%9F%E8%B0%83%E4%BC%98%E6%96%B9%E6%A1%88/img1.png)

不过要注意，想要使用 SO_REUSEPORT 选项，需要用 Linux 3.9 以上的版本才可以。



### C1000K

基于 I/O 多路复用和请求处理的优化，C10K 问题很容易就可以解决。不过，随着摩尔定律带来的服务器性能提升，以及互联网的普及，并不难想到，新兴服务会对性能提出更高的要求。

很快，原来的 C10K 已经不能满足需求，所以又有了 C100K 和 C1000K，也就是并发从原来的 1 万增加到 10 万、乃至 100 万。从 1 万到 10 万，其实还是基于 C10K 的这些理论，epoll 配合线程池，再加上 CPU、内存和网络接口的性能和容量提升。大部分情况下，C100K 很自然就可以达到。



那么，再进一步，C1000K 是不是也可以很容易就实现呢？这其实没有那么简单了。

首先从物理资源使用上来说，100 万个请求需要大量的系统资源。比如，

* 假设每个请求需要 16KB 内存的话，那么总共就需要大约 15 GB 内存。
* 而从带宽上来说，假设只有 20% 活跃连接，即使每个连接只需要 1KB/s 的吞吐量，总共也需要 1.6 Gb/s 的吞吐量。千兆网卡显然满足不了这么大的吞吐量，所以还需要配置万兆网卡，或者基于多网卡 Bonding 承载更大的吞吐量。

其次，从软件资源上来说，大量的连接也会占用大量的软件资源，比如文件描述符的数量、连接状态的跟踪（CONNTRACK）、网络协议栈的缓存大小（比如套接字读写缓存、TCP 读写缓存）等等。

最后，大量请求带来的中断处理，也会带来非常高的处理成本。这样，就需要多队列网卡、中断负载均衡、CPU 绑定、RPS/RFS（软中断负载均衡到多个 CPU 核上），以及将网络包的处理卸载（Offload）到网络设备（如 TSO/GSO、LRO/GRO、VXLAN OFFLOAD）等各种硬件和软件的优化。

C1000K 的解决方法，本质上还是构建在 epoll 的非阻塞 I/O 模型上。只不过，除了 I/O 模型之外，还需要从应用程序到 Linux 内核、再到 CPU、内存和网络等各个层次的深度优化，特别是需要借助硬件，来卸载那些原来通过软件处理的大量功能。



### C10M

显然，人们对于性能的要求是无止境的。再进一步，有没有可能在单机中，同时处理 1000 万的请求呢？这也就是 C10M 问题。

实际上，在 C1000K 问题中，各种软件、硬件的优化很可能都已经做到头了。特别是当升级完硬件（比如足够多的内存、带宽足够大的网卡、更多的网络功能卸载等）后，可能会发现，无论怎么优化应用程序和内核中的各种网络参数，想实现 1000 万请求的并发，都是极其困难的。

究其根本，还是 Linux 内核协议栈做了太多太繁重的工作。从网卡中断带来的硬中断处理程序开始，到软中断中的各层网络协议处理，最后再到应用程序，这个路径实在是太长了，就会导致网络包的处理优化，到了一定程度后，就无法更进一步了。

要解决这个问题，最重要就是跳过内核协议栈的冗长路径，把网络包直接送到要处理的应用程序那里去。这里有两种常见的机制，DPDK 和 XDP。

#### 第一种机制，DPDK，是用户态网络的标准。

它跳过内核协议栈，直接由用户态进程通过轮询的方式，来处理网络接收。

[![img](https://img2018.cnblogs.com/i-beta/1414775/202002/1414775-20200216214612125-1549354085.png)](https://img2018.cnblogs.com/i-beta/1414775/202002/1414775-20200216214612125-1549354085.png)

 

####  第二种机制，XDP（eXpress Data Path）

则是 Linux 内核提供的一种高性能网络数据路径。它允许网络包，在进入内核协议栈之前，就进行处理，也可以带来更高的性能。XDP 底层跟之前用到的 bcc-tools 一样，都是基于 Linux 内核的 eBPF 机制实现的

[![img](https://img2018.cnblogs.com/i-beta/1414775/202002/1414775-20200216214656155-2021723330.png)](https://img2018.cnblogs.com/i-beta/1414775/202002/1414775-20200216214656155-2021723330.png)

 

 XDP 对内核的要求比较高，需要的是 Linux 4.8 以上版本，并且它也不提供缓存队列。基于 XDP 的应用程序通常是专用的网络应用，常见的有 IDS（入侵检测系统）、DDoS 防御、 cilium 容器网络插件等



允许在进入网络协议栈之前先处理网络包

![avator](https://liuhao163.github.io/%E7%B3%BB%E7%BB%9F%E4%BC%98%E5%8C%96-%E7%BD%91%E7%BB%9C-C10K%E5%92%8CC1000K%E5%9B%9E%E9%A1%BE-%E7%B3%BB%E7%BB%9F%E8%B0%83%E4%BC%98%E6%96%B9%E6%A1%88/XDP.png)

但是：其实C10K就几乎够用了因为还要考虑业务等因素，还是推荐拆分到不同的服务器中。



### 总结

C10K 问题的根源，一方面在于系统有限的资源；另一方面，也是更重要的因素，是同步阻塞的 I/O 模型以及轮询的套接字接口，限制了网络事件的处理效率。Linux 2.6 中引入的 epoll ，完美解决了 C10K 的问题，现在的高性能网络方案都基于 epoll。

从 C10K 到 C100K ，可能只需要增加系统的物理资源就可以满足；但从 C100K 到 C1000K ，就不仅仅是增加物理资源就能解决的问题了。这时，就需要多方面的优化工作了，从硬件的中断处理和网络功能卸载、到网络协议栈的文件描述符数量、连接状态跟踪、缓存队列等内核的优化，再到应用程序的工作模型优化，都是考虑的重点。

再进一步，要实现 C10M ，就不只是增加物理资源，或者优化内核和应用程序可以解决的问题了。这时候，就需要用 XDP 的方式，在内核协议栈之前处理网络包；或者用 DPDK 直接跳过网络协议栈，在用户空间通过轮询的方式直接处理网络包。

当然了，实际上，在大多数场景中，并不需要单机并发 1000 万的请求。通过调整系统架构，把这些请求分发到多台服务器中来处理，通常是更简单和更容易扩展的方案。



# 网络性能评估

https://www.shuzhiduo.com/A/kmzLQx0BJG/

上一节，回顾了经典的 C10K 和 C1000K 问题。简单回顾一下，C10K 是指如何单机同时处理 1 万个请求（并发连接 1 万）的问题，而 C1000K 则是单机支持处理 100 万个
请求（并发连接 100 万）的问题。

I/O 模型的优化，是解决 C10K 问题的最佳良方。Linux 2.6 中引入的 epoll，完美解决了C10K 的问题，并一直沿用至今。今天的很多高性能网络方案，仍都基于 epoll。

自然，随着互联网技术的普及，催生出更高的性能需求。从 C10K 到 C100K，只需要增加系统的物理资源，就可以满足要求；但从 C100K 到 C1000K ，光增加物理资源就不够了。

这时，就要对系统的软硬件进行统一优化，从硬件的中断处理，到网络协议栈的文件描述符数量、连接状态跟踪、缓存队列，再到应用程序的工作模型等的整个网络链路，都需要深入优化。

再进一步，要实现 C10M，就不是增加物理资源、调优内核和应用程序可以解决的问题了。这时内核中冗长的网络协议栈就成了最大的负担。

* 需要用 XDP 方式，在内核协议栈之前，先处理网络包。
* 或基于 DPDK ，直接跳过网络协议栈，在用户空间通过轮询的方式处理。

其中，DPDK 是目前最主流的高性能网络方案，不过，这需要能支持 DPDK 的网卡配合使用。

当然，实际上，在大多数场景中，并不需要单机并发 1000 万请求。通过调整系统架构，把请求分发到多台服务器中并行处理，才是更简单、扩展性更好的方案。

不过，这种情况下，就需要评估系统的网络性能，以便考察系统的处理能力，并为容量规划提供基准数据。

那么，到底该怎么评估网络的性能呢？今天，我就带一起来看看这个问题。



## 性能指标回顾

在评估网络性能前，先来回顾一下，衡量网络性能的指标。在 Linux 网络基础篇中，曾经说到，带宽、吞吐量、延时、PPS 等，都是最常用的网络性能指标。还记得它们
的具体含义吗？可以先思考一下，再继续下面的内容。

首先，**带宽**，表示链路的最大传输速率，单位是 b/s（比特 / 秒）。在为服务器选购网卡时，带宽就是最核心的参考指标。常用的带宽有 1000M、10G、40G、100G 等。

第二，**吞吐量**，表示没有丢包时的最大数据传输速率，单位通常为 b/s （比特 / 秒）或者B/s（字节 / 秒）。吞吐量受带宽的限制，吞吐量 / 带宽也就是该网络链路的使用率。

第三，**延时**，表示从网络请求发出后，一直到收到远端响应，所需要的时间延迟。这个指标在不同场景中可能会时），或者一个数据包往返所需时间（比如 RTT）。

最后，**PPS**，是 Packet Per Second（包 / 秒）的缩写，表示以网络包为单位的传输速率。PPS 通常用来评估网络的转发能力，而基于 Linux 服务器的转发，很容易受到网络包
大小的影响（交换机通常不会受到太大影响，即交换机可以线性转发）。

这四个指标中，带宽跟物理网卡配置是直接关联的。一般来说，网卡确定后，带宽也就确定了（当然，实际带宽会受限于整个网络链路中最小的那个模块）。

另外，可能在很多地方听说过“网络带宽测试”，这里测试的实际上不是带宽，而是网络吞吐量。Linux 服务器的网络吞吐量一般会比带宽小，而对交换机等专门的网络设备来
说，吞吐量一般会接近带宽。

最后的 PPS，则是以网络包为单位的网络传输速率，通常用在需要大量转发的场景中。而对 TCP 或者 Web 服务来说，更多会用并发连接数和每秒请求数（QPS，Query per
Second）等指标，它们更能反应实际应用程序的性能。



## 网络基准测试

熟悉了网络的性能指标后，接下来，再来看看，如何通过性能测试来确定这些指标的基准值。

可以先思考一个问题。已经知道，Linux 网络基于 TCP/IP 协议栈，而不同协议层的行为显然不同。那么，测试之前，应该弄清楚，要评估的网络性能，究竟属于协议栈
的哪一层？换句话说，的应用程序基于协议栈的哪一层呢？

根据前面学过的 TCP/IP 协议栈的原理，这个问题应该不难回答。比如：

1. 基于 HTTP 或者 HTTPS 的 Web 应用程序，显然属于应用层，需要测试HTTP/HTTPS 的性能；
2. 而对大多数游戏服务器来说，为了支持更大的同时在线人数，通常会基于 TCP 或 UDP，与客户端进行交互，这时就需要测试 TCP/UDP 的性能；
3. 当然，还有一些场景，是把 Linux 作为一个软交换机或者路由器来用的。这种情况下，更关注网络包的处理能力（即 PPS），重点关注网络层的转发性能。

接下来，我就带从下往上，了解不同协议层的网络性能测试方法。不过要注意，低层协议是其上的各层网络协议的基础。自然，低层协议的性能，也就决定了高层的网络性能。

注意，以下所有的测试方法，都需要两台 Linux 虚拟机。其中一台，可以当作待测试的目标机器；而另一台，则可以当作正在运行网络服务的客户端，用来运行测试工具。



## 各协议层的性能测试

### 转发性能

首先来看，网络接口层和网络层，它们主要负责网络包的封装、寻址、路由以及发送和接收。在这两个网络协议层中，每秒可处理的网络包数 PPS，就是最重要的性能指标。
特别是 64B 小包的处理能力，值得特别关注。那么，如何来测试网络包的处理能力呢？

说到网络包相关的测试，可能会觉得陌生。不过，其实在专栏开头的 CPU 性能篇中，就接触过一个相关工具，也就是软中断案例中的 hping3。

在那个案例中，hping3 作为一个 SYN 攻击的工具来使用。实际上， hping3 更多的用途，是作为一个测试网络包处理能力的性能工具。

介绍另一个更常用的工具，Linux 内核自带的高性能网络测试工具 pktgen。pktgen 支持丰富的自定义选项，方便根据实际需要构造所需网络包，从而更准确地测试出目标服务器的性能。

不过，在 Linux 系统中，并不能直接找到 pktgen 命令。因为 pktgen 作为一个内核线程来运行，需要加载 pktgen 内核模块后，再通过 /proc 文件系统来交互。下面就是pktgen 启动的两个内核线程和 /proc 文件系统的交互文件：

```
modprobe pktgen
$ ps -ef | grep pktgen | grep -v grep
root     26384     2  0 06:17 ?        00:00:00 [kpktgend_0]
root     26385     2  0 06:17 ?        00:00:00 [kpktgend_1]
$ ls /proc/net/pktgen/
kpktgend_0  kpktgend_1  pgctrl
```

pktgen 在每个 CPU 上启动一个内核线程，并可以通过 /proc/net/pktgen 下面的同名文件，跟这些线程交互；而 pgctrl 则主要用来控制这次测试的开启和停止。

```
如果 modprobe 命令执行失败，说明的内核没有配置
CONFIG_NET_PKTGEN 选项。这就需要配置 pktgen 内核模块（即
CONFIG_NET_PKTGEN=m）后，重新编译内核，才可以使用
```

在使用 pktgen 测试网络性能时，需要先给每个内核线程 kpktgend_X 以及测试网卡，配置 pktgen 选项，然后再通过 pgctrl 启动测试。

以发包测试为例，假设发包机器使用的网卡是 eth0，而目标机器的 IP 地址为192.168.0.30，MAC 地址为 11:11:11:11:11:11。
![img](https://bbsmax.ikafan.com/static/L3Byb3h5L2h0dHBzL2ltZzIwMTguY25ibG9ncy5jb20vYmxvZy8xMDc1NDM2LzIwMTkwOS8xMDc1NDM2LTIwMTkwOTE2MTExODAwNzA1LTE2NTQyODc4ODIucG5n.jpg)

接下来，就是一个发包测试的示例。

```
# 定义一个工具函数，方便后面配置各种测试选项
function pgset() {
    local result
    echo $1 > $PGDEV     result=`cat $PGDEV | fgrep "Result: OK:"`
    if [ "$result" = "" ]; then
         cat $PGDEV | fgrep Result:
    fi
} # 为 0 号线程绑定 eth0 网卡
PGDEV=/proc/net/pktgen/kpktgend_0
pgset "rem_device_all"   # 清空网卡绑定
pgset "add_device eth0"  # 添加 eth0 网卡 # 配置 eth0 网卡的测试选项
PGDEV=/proc/net/pktgen/eth0
pgset "count 1000000"    # 总发包数量
pgset "delay 5000"       # 不同包之间的发送延迟 (单位纳秒)
pgset "clone_skb 0"      # SKB 包复制
pgset "pkt_size 64"      # 网络包大小
pgset "dst 192.168.0.30" # 目的 IP
pgset "dst_mac 11:11:11:11:11:11"  # 目的 MAC # 启动测试
PGDEV=/proc/net/pktgen/pgctrl
pgset "start"
```

稍等一会儿，测试完成后，结果可以从 /proc 文件系统中获取。通过下面代码段中的内容，可以查看刚才的测试报告：

```
cat /proc/net/pktgen/eth0
Params: count 1000000  min_pkt_size: 64  max_pkt_size: 64
     frags: 0  delay: 0  clone_skb: 0  ifname: eth0
     flows: 0 flowlen: 0
...
Current:
     pkts-sofar: 1000000  errors: 0
     started: 1534853256071us  stopped: 1534861576098us idle: 70673us
...
Result: OK: 8320027(c8249354+d70673) usec, 1000000 (64byte,0frags)
  120191pps 61Mb/sec (61537792bps) errors: 0
```

可以看到，测试报告主要分为三个部分：

* 第一部分的 Params 是测试选项；
* 第二部分的 Current 是测试进度，其中， packts so far（pkts-sofar）表示已经发送了100 万个包，也就表明测试已完成。
* 第三部分的 Result 是测试结果，包含测试所用时间、网络包数量和分片、PPS、吞吐量以及错误数。

根据上面的结果，发现，PPS 为 12 万，吞吐量为 61 Mb/s，没有发生错误。那么，12 万的 PPS 好不好呢？

**实际测试代码如下：**

```
[root@69 ~]# modprobe pktgen
[root@69 ~]# ps -ef|grep pktgen |grep -v grep
root       1434      2  0 19:55 ?        00:00:00 [kpktgend_0]
root       1435      2  0 19:55 ?        00:00:00 [kpktgend_1]
[root@69 ~]# ls /proc/net/pktgen/
kpktgend_0  kpktgend_1  pgctrl
[root@69 ~]# function pgset() {
>     local result
>     echo $1 > $PGDEV
>
>     result=`cat $PGDEV | fgrep "Result: OK:"`
>     if [ "$result" = "" ]; then
>          cat $PGDEV | fgrep Result:
>     fi
> }
[root@69 ~]#  PGDEV=/proc/net/pktgen/kpktgend_0
[root@69 ~]# pgset "rem_device_all"   # 清空网卡绑定
[root@69 ~]# pgset "add_device eno1"  # 添加 eno1 网卡
[root@69 ~]# PGDEV=/proc/net/pktgen/eno1
[root@69 ~]# pgset "count 1000000"    # 总发包数量
 目的 IP
pgset "dst_mac 94:18:82:0a:70:b0"  # 目的 MAC
[root@69 ~]# pgset "delay 5000"       # 不同包之间的发送延迟 (单位纳秒)
[root@69 ~]# pgset "clone_skb 0"      # SKB 包复制
[root@69 ~]# pgset "pkt_size 64"      # 网络包大小
[root@69 ~]# pgset "dst 0.0.10.42" # 目的 IP
[root@69 ~]# pgset "dst_mac 94:18:82:0a:70:b0"  # 目的 MAC
[root@69 ~]# PGDEV=/proc/net/pktgen/pgctrl
[root@69 ~]# pgset "start" 
[root@69 ~]# cat /proc/net/pktgen/eno1
Params: count 1000000  min_pkt_size: 64  max_pkt_size: 64
     frags: 0  delay: 5000  clone_skb: 0  ifname: eno1
     flows: 0 flowlen: 0
     queue_map_min: 0  queue_map_max: 0
     dst_min: 192.168.118.77  dst_max:
        src_min:   src_max:
     src_mac: 00:0c:29:b2:f5:5b dst_mac: 00:0c:29:18:a9:e7
     udp_src_min: 9  udp_src_max: 9  udp_dst_min: 9  udp_dst_max: 9
     src_mac_count: 0  dst_mac_count: 0
     Flags:
Current:
     pkts-sofar: 1000000  errors: 0
     started: 157688456us  stopped: 252745896us idle: 81294us
     seq_num: 1000001  cur_dst_mac_offset: 0  cur_src_mac_offset: 0
     cur_saddr: 0x6d76a8c0  cur_daddr: 0x4d76a8c0
     cur_udp_dst: 9  cur_udp_src: 9
     cur_queue_map: 0
     flows: 0
Result: OK: 95057439(c94976145+d81294) nsec, 1000000 (64byte,0frags)
  10519pps 5Mb/sec (5385728bps) errors: 0
```

作为对比，可以计算一下千兆交换机的 PPS。交换机可以达到线速（满负载时，无差错转发），它的 PPS 就是 1000Mbit 除以以太网帧的大小，即 1000Mbps/((64+20)*8bit)= 1.5 Mpps
（其中 20B 为以太网帧的头部大小）。

即使是千兆交换机的 PPS，也可以达到 150 万 PPS，比测试得到的 12 万大多了。所以，看到这个数值并不用担心，现在的多核服务器和万兆网卡已经很普遍了，稍做优化就可以达到数百万的 PPS。而且，如果用了上节课讲到的 DPDK 或 XDP ，还能达到千万数量级。



### TCP/UDP 性能

掌握了 PPS 的测试方法，接下来，再来看 TCP 和 UDP 的性能测试方法。说到 TCP和 UDP 的测试，我想已经很熟悉了，甚至可能一下子就能想到相应的测试工具，比如iperf 或者 netperf。

特别是现在的云计算时代，在刚拿到一批虚拟机时，首先要做的，应该就是用 iperf ，测试一下网络性能是否符合预期。

**iperf 和 netperf 都是最常用的网络性能测试工具，测试 TCP 和 UDP 的吞吐量。它们都以客户端和服务器通信的方式，测试一段时间内的平均吞吐量。**

接下来，就以 iperf 为例，看一下 TCP 性能的测试方法。目前，iperf 的最新版本为iperf3，可以运行下面的命令来安装：

```
# Ubuntu
apt-get install iperf3
# CentOS
yum install iperf3
```

然后，在目标机器上启动 iperf 服务端：

```
# -s 表示启动服务端，-i 表示汇报间隔，-p 表示监听端口
$ iperf3 -s -i 1 -p 10000
```

接着，在另一台机器上运行 iperf 客户端，运行测试：

```
# -c 表示启动客户端，192.168.0.30 为目标服务器的 IP
# -b 表示目标带宽 (单位是 bits/s)
# -t 表示测试时间
# -P 表示并发数，-p 表示目标服务器监听端口
$ iperf3 -c 192.168.0.30 -b 1G -t 15 -P 2 -p 10000
```

**实际测试代码如下：**

```
root@luoahong:~# iperf3 -s -i 1 -p 10000
-----------------------------------------------------------
Server listening on 10000
-----------------------------------------------------------
Accepted connection from 192.168.118.109, port 45568
[  5] local 192.168.118.77 port 10000 connected to 192.168.118.109 port 45570
[  7] local 192.168.118.77 port 10000 connected to 192.168.118.109 port 45572
[ ID] Interval           Transfer     Bandwidth
[  5]   0.00-1.00   sec  42.1 MBytes   353 Mbits/sec
[  7]   0.00-1.00   sec  40.9 MBytes   343 Mbits/sec
[SUM]   0.00-1.00   sec  83.0 MBytes   696 Mbits/sec
- - - - - - - - - - - - - - - - - - - - - - - - -
......
- - - - - - - - - - - - - - - - - - - - - - - - -
[  5]  15.00-15.06  sec   643 KBytes  94.7 Mbits/sec
[  7]  15.00-15.06  sec  1.50 MBytes   226 Mbits/sec
[SUM]  15.00-15.06  sec  2.13 MBytes   321 Mbits/sec
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bandwidth
[  5]   0.00-15.06  sec  0.00 Bytes  0.00 bits/sec                  sender
[  5]   0.00-15.06  sec   550 MBytes   306 Mbits/sec                  receiver
[  7]   0.00-15.06  sec  0.00 Bytes  0.00 bits/sec                  sender
[  7]   0.00-15.06  sec   691 MBytes   385 Mbits/sec                  receiver
[SUM]   0.00-15.06  sec  0.00 Bytes  0.00 bits/sec                  sender
[SUM]   0.00-15.06  sec  1.21 GBytes   691 Mbits/sec                  receiver
-----------------------------------------------------------
Server listening on 10000
```

稍等一会儿（15 秒）测试结束后，回到目标服务器，查看 iperf 的报告：

```
[ ID] Interval           Transfer     Bandwidth
...
[SUM]   0.00-15.04  sec  0.00 Bytes  0.00 bits/sec                  sender
[SUM]   0.00-15.04  sec  1.51 GBytes   860 Mbits/sec                  receiver
```

最后的 SUM 行就是测试的汇总结果，包括测试时间、数据传输量以及带宽等。按照发送和接收，这一部分又分为了 sender 和 receiver 两行。

从测试结果可以看到，这台机器 TCP 接收的带宽（吞吐量）为 860 Mb/s， 跟目标的1Gb/s 相比，还是有些差距的。



### HTTP 性能

传输层再往上，到了应用层。有的应用程序，会直接基于 TCP 或 UDP 构建服务。当然，也有大量的应用，基于应用层的协议来构建服务，HTTP 就是最常用的一个应用层协议。比如，常用的 Apache、Nginx 等各种 Web 服务，都是基于 HTTP。

**要测试 HTTP 的性能，也有大量的工具可以使用，比如 ab、webbench 等，都是常用的HTTP 压力测试工具。其中，ab 是 Apache 自带的 HTTP 压测工具，主要测试 HTTP 服务的每秒请求数、请求延迟、吞吐量以及请求延迟的分布情况等。**

运行下面的命令，就可以安装 ab 工具：、

```
# Ubuntu
$ apt-get install -y apache2-utils
# CentOS
$ yum install -y httpd-tools
```

接下来，在目标机器上，使用 Docker 启动一个 Nginx 服务，然后用 ab 来测试它的性能。
首先，在目标机器上运行下面的命令：

```
docker run -p 80:80 -itd nginx
```

而在另一台机器上，运行 ab 命令，测试 Nginx 的性能：

```
# -c 表示并发请求数为 1000，-n 表示总的请求数为 10000
$ ab -c 1000 -n 10000 http://192.168.0.30/
...
Server Software:        nginx/1.15.8
Server Hostname:        192.168.0.30
Server Port:            80 
... 
Requests per second:    1078.54 [#/sec] (mean)
Time per request:       927.183 [ms] (mean)
Time per request:       0.927 [ms] (mean, across all concurrent requests)
Transfer rate:          890.00 [Kbytes/sec] received 
Connection Times (ms)
              min  mean[+/-sd] median   max
Connect:        0   27 152.1      1    1038
Processing:     9  207 843.0     22    9242
Waiting:        8  207 843.0     22    9242
Total:         15  233 857.7     23    9268 Percentage of the requests served within a certain time (ms)
  50%     23
  66%     24
  75%     24
  80%     26
  90%    274
  95%   1195
  98%   2335
  99%   4663
 100%   9268 (longest request)
```

可以看到，ab 的测试结果分为三个部分，分别是请求汇总、连接时间汇总还有请求延迟汇总。以上面的结果为例，具体来看。
在请求汇总部分，可以看到：

* Requests per second 为 1078；
* 每个请求的延迟（Time per request）分为两行，第一行的 927 ms 表示平均延迟，包括了线程运行的调度时间和网络请求响应时间，而下一行的 0.927ms ，则表示实际请求的响应时间；
* Transfer rate 表示吞吐量（BPS）为 890 KB/s。

连接时间汇总部分，则是分别展示了建立连接、请求、等待以及汇总等的各类时间，包括最小、最大、平均以及中值处理时间。

最后的请求延迟汇总部分，则给出了不同时间段内处理请求的百分比，比如， 90% 的请求，都可以在 274ms 内完成。



### 应用负载性能

当用 iperf 或者 ab 等测试工具，得到 TCP、HTTP 等的性能数据后，这些数据是否就能表示应用程序的实际性能呢？我想，的答案应该是否定的。

比如，的应用程序基于 HTTP 协议，为最终用户提供一个 Web 服务。这时，使用 ab工具，可以得到某个页面的访问性能，但这个结果跟用户的实际请求，很可能不一致。因为用户请求往往会附带着各种各种的负载（payload），而这些负载会影响 Web 应用程序内部的处理逻辑，从而影响最终性能。

**那么，为了得到应用程序的实际性能，就要求性能工具本身可以模拟用户的请求负载，而iperf、ab 这类工具就无能为力了。幸运的是，还可以用 wrk、TCPCopy、Jmeter 或者 LoadRunner 等实现这个目标。**

以 wrk 为例，它是一个 HTTP 性能测试工具，内置了 LuaJIT，方便根据实际需求，生成所需的请求负载，或者自定义响应的处理方法。

wrk 工具本身不提供 yum 或 apt 的安装方法，需要通过源码编译来安装。比如，可以运行下面的命令，来编译和安装 wrk：

```shell
# Ubuntu
$ apt-get install build-essential git -y
$ git clone https://github.com/wg/wrk
$ cd wrk
$ make
$ sudo cp wrk /usr/local/bin/

#Centos
$ yum -y install  git gcc gcc-c++
$ git clone https://github.com/wg/wrk
$ cd wrk
$ make
$ sudo cp wrk /usr/local/bin/
```

wrk 的命令行参数比较简单。比如，可以用 wrk ，来重新测一下前面已经启动的Nginx 的性能。

```
# -c 表示并发连接数 1000，-t 表示线程数为 2
$ wrk -c 1000 -t 2 http://192.168.0.30/
Running 10s test @ http://192.168.0.30/
  2 threads and 1000 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    65.83ms  174.06ms   1.99s    95.85%
    Req/Sec     4.87k   628.73     6.78k    69.00%
  96954 requests in 10.06s, 78.59MB read
  Socket errors: connect 0, read 0, write 0, timeout 179
Requests/sec:   9641.31
Transfer/sec:      7.82MB
```

这里使用 2 个线程、并发 1000 连接，重新测试了 Nginx 的性能。可以看到，每秒请求数为 9641，吞吐量为 7.82MB，平均延迟为 65ms，比前面 ab 的测试结果要好很多。

这也说明，性能工具本身的性能，对性能测试也是至关重要的。不合适的性能工具，并不能准确测出应用程序的最佳性能。

当然，wrk 最大的优势，是其内置的 LuaJIT，可以用来实现复杂场景的性能测试。wrk 在调用 Lua 脚本时，可以将 HTTP 请求分为三个阶段，即 setup、running、done，如下图所示：
![img](https://bbsmax.ikafan.com/static/L3Byb3h5L2h0dHBzL2ltZzIwMTguY25ibG9ncy5jb20vYmxvZy8xMDc1NDM2LzIwMTkwOS8xMDc1NDM2LTIwMTkwOTE2MTEyOTE1NzA1LTY4ODIzNzQ5My5wbmc=.jpg)

比如，可以在 setup 阶段，为请求设置认证参数（来自于 wrk 官方示例）：

```lua
-- example script that demonstrates response handling and
-- retrieving an authentication token to set on all future
-- requests token = nil
path  = "/authenticate" request = function()
   return wrk.format("GET", path)
end response = function(status, headers, body)
   if not token and status == 200 then
      token = headers["X-Token"]
      path  = "/resource"
      wrk.headers["X-Token"] = token
   end
end
```

而在执行测试时，通过 -s 选项，执行脚本的路径：

```
wrk -c 1000 -t 2 -s auth.lua http://192.168.0.30/
```

wrk 需要用 Lua 脚本，来构造请求负载。这对于大部分场景来说，可能已经足够了 。不过，它的缺点也正是，所有东西都需要代码来构造，并且工具本身不提供 GUI 环境。
像 Jmeter 或者 LoadRunner（商业产品），则针对复杂场景提供了脚本录制、回放、GUI 等更丰富的功能，使用起来也更加方便。



## 小结

今天，一起回顾了网络的性能指标，并学习了网络性能的评估方法

性能评估是优化网络性能的前提，只有在发现网络性能瓶颈时，才需要进行网络性能优化。根据TCP/IP协议栈的原理，不同协议层关注性能重点不完全一样，也就是对应不同的性能测试方法比如：

1. 在应用层，可以使用 wrk、Jmeter 等模拟用户的负载，测试应用程序的每秒请求数、处理延迟、错误数等；
2. 而在传输层，则可以使用 iperf 等工具，测试 TCP 的吞吐情况；
3. 再向下，还可以用 Linux 内核自带的 pktgen ，测试服务器的 PPS。

由于低层协议是高层协议的基础。所以，一般情况下，需要从上到下，对每个协议层进行性能测试，然后根据性能测试的结果，结合 Linux 网络协议栈的原理，找出导致性能。



# DNS 解析

上一节，我带一起学习了网络性能的评估方法。简单回顾一下，Linux 网络基于 TCP/IP协议栈构建，而在协议栈的不同层，所关注的网络性能也不尽相同。

在应用层，关注的是应用程序的并发连接数、每秒请求数、处理延迟、错误数等，可以使用 wrk、Jmeter 等工具，模拟用户的负载，得到想要的测试结果。

而在传输层，关注的是 TCP、UDP 等传输层协议的工作状况，比如 TCP 连接数、TCP 重传、TCP 错误数等。此时，可以使用 iperf、netperf 等，来测试 TCP 或 UDP的性能。

再向下到网络层，关注的则是网络包的处理能力，即 PPS。Linux 内核自带的pktgen，就可以帮测试这个指标。

由于低层协议是高层协议的基础，所以一般情况下，所说的网络优化，实际上包含了整个网络协议栈的所有层的优化。当然，性能要求不同，具体需要优化的位置和目标并不
完全相同。

前面在评估网络性能（比如 HTTP 性能）时，在测试工具中指定了网络服务的 IP 地址。IP 地址是 TCP/IP 协议中，用来确定通信双方的一个重要标识。每个 IP 地址又包括了
主机号和网络号两部分。相同网络号的主机组成一个子网；不同子网再通过路由器连接，组成一个庞大的网络。

然而，IP 地址虽然方便了机器的通信，却给访问这些服务的人们，带来了很重的记忆负担。我相信，没几个人能记得住 Github 所在的 IP 地址，因为这串字符，对人脑来说并没
有什么含义，不符合的记忆逻辑。

不过，这并不妨碍经常使用这个服务。为什么呢？当然是因为还有更简单、方便的方式。可以通过域名 github.com 访问，而不是必须依靠具体的 IP 地址，这其实正是域
名系统 DNS 的由来。

DNS（Domain Name System），即域名系统，是互联网中最基础的一项服务，主要提供域名和 IP 地址之间映射关系的查询服务。

DNS 不仅方便了人们访问不同的互联网服务，更为很多应用提供了，动态服务发现和全局负载均衡（Global Server Load Balance，GSLB）的机制。这样，DNS 就可以选择离用
户最近的 IP 来提供服务。即使后端服务的 IP 地址发生变化，用户依然可以用相同域名来访问。

DNS 显然是工作中基础而重要的一个环节。那么，DNS 出现问题时，又该如何分析和排查呢？今天，我就带一起来看看这个问题。



## 域名与 DNS 解析

域名本身都比较熟悉，由一串用点分割开的字符组成，被用作互联网中的某一台或某一组计算机的名称，目的就是为了方便识别，互联网中提供各种服务的主机位置。

要注意，域名是全球唯一的，需要通过专门的域名注册商才可以申请注册。为了组织全球互联网中的众多计算机，域名同样用点来分开，形成一个分层的结构。而每个被点分割开
的字符串，就构成了域名中的一个层级，并且位置越靠后，层级越高。

以极客时间的网站 time.geekbang.org 为例，来理解域名的含义。这个字符串中，最后面的 org 是顶级域名，中间的 geekbang 是二级域名，而最左边的 time 则是三级域名。

如下图所示，注意点（.）是所有域名的根，也就是说所有域名都以点作为后缀，也可以理解为，在域名解析的过程中，所有域名都以点结束。

![img](https://img2018.cnblogs.com/blog/1075436/201909/1075436-20190916183435919-450337988.png)

通过理解这几个概念，可以看出，域名主要是为了方便让人记住，而 IP 地址是机器间的通信的真正机制。把域名转换为 IP 地址的服务，也就是开头提到的，域名解析服务（DNS），而对应的服务器就是域名服务器，网络协议则是 DNS 协议。

这里注意，DNS 协议在 TCP/IP 栈中属于应用层，不过实际传输还是基于 UDP 或者 TCP协议（UDP 居多） ，并且域名服务器一般监听在端口 53 上。

既然域名以分层的结构进行管理，相对应的，域名解析其实也是用递归的方式（从顶级开始，以此类推），发送给每个层级的域名服务器，直到得到解析结果。

递归查询的过程操作，DNS 服务器会替完成，只是预先配置一个可用的 DNS 服务器就可以了。

通常来说，每级 DNS 服务器，都会有最近解析记录的缓存。当缓存命中时，直接用缓存中的记录应答就可以了。如果缓存过期或者不存在，才需要用刚刚提到的递归方式查询。

所以，系统管理员在配置 Linux 系统的网络时，除了需要配置 IP 地址，还需要给它配置DNS 服务器，这样它才可以通过域名来访问外部服务。

比如，我的系统配置的就是 114.114.114.114 这个域名服务器。可以执行下面的命令，来查询系统配置：

```
cat /etc/resolv.conf
nameserver 114.114.114.114
```

另外，DNS 服务通过资源记录的方式，来管理所有数据，它支持 A、CNAME、MX、NS、PTR 等多种类型的记录。比如：

```
A 记录，用来把域名转换成 IP 地址；
CNAME 记录，用来创建别名；
而 NS 记录，则表示该域名对应的域名服务器地址
```

简单来说，当访问某个网址时，就需要通过 DNS 的 A 记录，查询该域名对应的 IP 地址，然后再通过该 IP 来访问 Web 服务。

比如，还是以极客时间的网站 time.geekbang.org 为例，执行下面的 nslookup 命令，就可以查询到这个域名的 A 记录，可以看到，它的 IP 地址是 39.106.233.176：

```
nslookup time.geekbang.org
# 域名服务器及端口信息
Server:		114.114.114.114
Address:	114.114.114.114#53

# 非权威查询结果
Non-authoritative answer:
Name:	time.geekbang.org
Address: 39.106.233.17
```

**这里要注意，由于 114.114.114.114 并不是直接管理 time.geekbang.org 的域名服务器，所以查询结果是非权威的。使用上面的命令，只能得到 114.114.114.114 查询的结果。**

前面还提到了，如果没有命中缓存，DNS 查询实际上是一个递归过程，那有没有方法可以知道整个递归查询的执行呢？

其实除了 nslookup，另外一个常用的 DNS 解析工具 dig ，就提供了 trace 功能，可以展示递归查询的整个过程。比如可以执行下面的命令，得到查询结果：

```
# +trace 表示开启跟踪查询
# +nodnssec 表示禁止 DNS 安全扩展
$ dig +trace +nodnssec time.geekbang.org

; <<>> DiG 9.11.3-1ubuntu1.3-Ubuntu <<>> +trace +nodnssec time.geekbang.org
;; global options: +cmd
.			322086	IN	NS	m.root-servers.net.
.			322086	IN	NS	a.root-servers.net.
.			322086	IN	NS	i.root-servers.net.
.			322086	IN	NS	d.root-servers.net.
.			322086	IN	NS	g.root-servers.net.
.			322086	IN	NS	l.root-servers.net.
.			322086	IN	NS	c.root-servers.net.
.			322086	IN	NS	b.root-servers.net.
.			322086	IN	NS	h.root-servers.net.
.			322086	IN	NS	e.root-servers.net.
.			322086	IN	NS	k.root-servers.net.
.			322086	IN	NS	j.root-servers.net.
.			322086	IN	NS	f.root-servers.net.
;; Received 239 bytes from 114.114.114.114#53(114.114.114.114) in 1340 ms

org.			172800	IN	NS	a0.org.afilias-nst.info.
org.			172800	IN	NS	a2.org.afilias-nst.info.
org.			172800	IN	NS	b0.org.afilias-nst.org.
org.			172800	IN	NS	b2.org.afilias-nst.org.
org.			172800	IN	NS	c0.org.afilias-nst.info.
org.			172800	IN	NS	d0.org.afilias-nst.org.
;; Received 448 bytes from 198.97.190.53#53(h.root-servers.net) in 708 ms

geekbang.org.		86400	IN	NS	dns9.hichina.com.
geekbang.org.		86400	IN	NS	dns10.hichina.com.
;; Received 96 bytes from 199.19.54.1#53(b0.org.afilias-nst.org) in 1833 ms

time.geekbang.org.	600	IN	A	39.106.233.176
;; Received 62 bytes from 140.205.41.16#53(dns10.hichina.com) in 4 ms
```

dig trace 的输出，主要包括四部分。

```
第一部分，是从 114.114.114.114 查到的一些根域名服务器（.）的 NS 记录。
第二部分，是从 NS 记录结果中选一个（h.root-servers.net），并查询顶级域名 org.的 NS 记录。
第三部分，是从 org. 的 NS 记录中选择一个（b0.org.afilias-nst.org），并查询二级域名 geekbang.org. 的 NS 服务器。
最后一部分，就是从 geekbang.org. 的 NS 服务器（dns10.hichina.com）查询最终主机 time.geekbang.org. 的 A 记录
```

这个输出里展示的各级域名的 NS 记录，其实就是各级域名服务器的地址，可以更清楚 DNS 解析的过程。 为了更直观理解递归查询，流程图如下:

![img](https://img2018.cnblogs.com/blog/1075436/201909/1075436-20190916183939641-1602975921.png)

当然，不仅仅是发布到互联网的服务需要域名，很多时候，也希望能对局域网内部的主机进行域名解析（即内网域名，大多数情况下为主机名）。Linux 也支持这种行为。

所以，可以把主机名和 IP 地址的映射关系，写入本机的 /etc/hosts 文件中。这样，指定的主机名就可以在本地直接找到目标 IP。比如，可以执行下面的命令来操作：

```
cat /etc/hosts
127.0.0.1   localhost localhost.localdomain
::1         localhost6 localhost6.localdomain6
192.168.0.100 domain.com
```

或者，还可以在内网中，搭建自定义的 DNS 服务器，专门用来解析内网中的域名。而内网 DNS 服务器，一般还会设置一个或多个上游 DNS 服务器，用来解析外网的域名。

清楚域名与 DNS 解析的基本原理后，接下来，我就带一起来看几个案例，实战分析DNS 解析出现问题时，该如何定位。



## DNS 解析失败

### 1、环境准备

本次案例还是基于 Ubuntu 18.04，同样适用于其他的 Linux 系统。我使用的案例环境如下所示：

```
机器配置：2 CPU，8GB 内存。
预先安装 docker 等工具，如 apt install docker.io。
```

可以先打开一个终端，SSH 登录到 Ubuntu 机器中，然后执行下面的命令，拉取案例中使用的 Docker 镜像：

```
docker pull feisky/dnsutils
Using default tag: latest
...
Status: Downloaded newer image for feisky/dnsutils:latest
```

然后，运行下面的命令，查看主机当前配置的 DNS 服务器：

```
cat /etc/resolv.conf
nameserver 114.114.114.114
```

可以看到，这台主机配置的 DNS 服务器是 114.114.114.114。

到这里，准备工作就完成了。接下来，正式进入操作环节。



### 2、DNS 解析失败

首先，执行下面的命令，进入今天的第一个案例。如果一切正常，将可以看到下面这个输出：

```
# 进入案例环境的 SHELL 终端中
$ docker run -it --rm -v $(mktemp):/etc/resolv.conf feisky/dnsutils bash
root@7e9ed6ed4974:/#
```

注意，这儿 root 后面的 7e9ed6ed4974，是 Docker 生成容器的 ID 前缀，的环境中很可能是不同的 ID，所以直接忽略这一项就可以了。

```
注意：下面的代码段中， /# 开头的命令都表示在容器内部运行的命令。
```

接着，继续在容器终端中，执行 DNS 查询命令，还是查询 time.geekbang.org 的 IP地址：

```
/# nslookup time.geekbang.org
;; connection timed out; no servers could be reached
```

可以发现，这个命令阻塞很久后，还是失败了，报了 connection timed out 和 noservers could be reached 错误。

看到这里，估计的第一反应就是网络不通了，到底是不是这样呢？用 ping 工具检查试试。执行下面的命令，就可以测试本地到 114.114.114.114 的连通性：

```
/# ping -c3 114.114.114.114
PING 114.114.114.114 (114.114.114.114): 56 data bytes
64 bytes from 114.114.114.114: icmp_seq=0 ttl=56 time=31.116 ms
64 bytes from 114.114.114.114: icmp_seq=1 ttl=60 time=31.245 ms
64 bytes from 114.114.114.114: icmp_seq=2 ttl=68 time=31.128 ms
--- 114.114.114.114 ping statistics ---
3 packets transmitted, 3 packets received, 0% packet loss
round-trip min/avg/max/stddev = 31.116/31.163/31.245/0.058 ms
```

这个输出中，可以看到网络是通的。那要怎么知道 nslookup 命令失败的原因呢？这里其实有很多方法，最简单的一种，就是开启 nslookup 的调试输出，查看查询过程中的详细步骤，排查其中是否有异常。

比如，可以继续在容器终端中，执行下面的命令：

```
/# nslookup -debug time.geekbang.org
;; Connection to 127.0.0.1#53(127.0.0.1) for time.geekbang.org failed: connection refused.
;; Connection to ::1#53(::1) for time.geekbang.org failed: address not available.
```

从这次的输出可以看到，nslookup 连接环回地址（127.0.0.1 和 ::1）的 53 端口失败。这里就有问题了，为什么会去连接环回地址，而不是的先前看到的 114.114.114.114呢？

可能已经想到了症结所在——有可能是因为容器中没有配置 DNS 服务器。那就执行下面的命令确认一下：

```
/# cat /etc/resolv.conf
```

果然，这个命令没有任何输出，说明容器里的确没有配置 DNS 服务器。在 /etc/resolv.conf 文件中，配置DNS 服务器就可了。

可以执行下面的命令，在配置好 DNS 服务器后，重新执行 nslookup 命令。这次可以正常解析：

```
/# echo "nameserver 114.114.114.114" > /etc/resolv.conf
/# nslookup time.geekbang.org
Server:		114.114.114.114
Address:	114.114.114.114#53

Non-authoritative answer:
Name:	time.geekbang.org
Address: 39.106.233.176
```

到这里，第一个案例就轻松解决了。最后，在终端中执行 exit 命令退出容器，Docker 就会自动清理刚才运行的容器。



## DNS 解析不稳定

接下来，再来看第二个案例。执行下面的命令，启动一个新的容器，并进入它的终端中：

```
docker run -it --rm --cap-add=NET_ADMIN --dns 8.8.8.8 feisky/dnsutils bash
root@0cd3ee0c8ecb:/#
```

然后，跟上一个案例一样，还是运行 nslookup 命令，解析 time.geekbang.org 的 IP 地址。不过，这次要加一个 time 命令，输出解析所用时间。如果一切正常，可能会看到如下输出：

```
/# time nslookup time.geekbang.org
Server:		8.8.8.8
Address:	8.8.8.8#53

Non-authoritative answer:
Name:	time.geekbang.org
Address: 39.106.233.176

real	0m10.349s
user	0m0.004s
sys	0m0.0
```

可以看到，这次解析非常慢，居然用了 10 秒。如果多次运行上面的 nslookup 命令，可能偶尔还会碰到下面这种错误：

```
/# time nslookup time.geekbang.org
;; connection timed out; no servers could be reached

real	0m15.011s
user	0m0.006s
sys	0m0.006s
```

换句话说，跟上一个案例类似，也会出现解析失败的情况。综合来看，现在 DNS 解析的结果不但比较慢，而且还会发生超时失败的情况。

这种问题该怎么处理呢？

其实，根据前面的讲解，知道，DNS 解析，说白了就是客户端与服务器交互的过程，并且这个过程还使用了 UDP 协议。

那么，对于整个流程来说，解析结果不稳定，就有很多种可能的情况。比方说：

```
DNS 服务器本身有问题，响应慢并且不稳定；
或者是，客户端到 DNS 服务器的网络延迟比较大；
再或者，DNS 请求或者响应包，在某些情况下被链路中的网络设备弄丢了。
```

根据上面 nslookup 的输出，可以看到，现在客户端连接的 DNS 是 8.8.8.8，这是Google 提供的 DNS 服务。对 Google 还是比较放心的，DNS 服务器出问题的概率
应该比较小。基本排除了 DNS 服务器的问题，那是不是第二种可能，本机到 DNS 服务器的延迟比较大呢？

前面讲过，ping 可以用来测试服务器的延迟。比如，可以运行下面的命令：

```
/# ping -c3 8.8.8.8
PING 8.8.8.8 (8.8.8.8): 56 data bytes
64 bytes from 8.8.8.8: icmp_seq=0 ttl=31 time=137.637 ms
64 bytes from 8.8.8.8: icmp_seq=1 ttl=31 time=144.743 ms
64 bytes from 8.8.8.8: icmp_seq=2 ttl=31 time=138.576 ms
--- 8.8.8.8 ping statistics ---
3 packets transmitted, 3 packets received, 0% packet loss
round-trip min/avg/max/stddev = 137.637/140.319/144.743/3.152 ms
```

从 ping 的输出可以看到，这里的延迟已经达到了 140ms，这也就可以解释，为什么解析这么慢了。实际上，如果多次运行上面的 ping 测试，还会看到偶尔出现的丢包现象。

```
ping -c3 8.8.8.8
PING 8.8.8.8 (8.8.8.8): 56 data bytes
64 bytes from 8.8.8.8: icmp_seq=0 ttl=30 time=134.032 ms
64 bytes from 8.8.8.8: icmp_seq=1 ttl=30 time=431.458 ms
--- 8.8.8.8 ping statistics ---
3 packets transmitted, 2 packets received, 33% packet loss
round-trip min/avg/max/stddev = 134.032/282.745/431.458/148.713 ms
```

这也进一步解释了，为什么 nslookup 偶尔会失败，正是网络链路中的丢包导致的。碰到这种问题该怎么办呢？显然，既然延迟太大，那就换一个延迟更小的 DNS 服务器，
比如电信提供的 114.114.114.114。

配置之前，可以先用 ping 测试看看，它的延迟是不是真的比 8.8.8.8 快。执行下面的命令，就可以看到，它的延迟只有 31ms：

```
/# ping -c3 114.114.114.114
PING 114.114.114.114 (114.114.114.114): 56 data bytes
64 bytes from 114.114.114.114: icmp_seq=0 ttl=67 time=31.130 ms
64 bytes from 114.114.114.114: icmp_seq=1 ttl=56 time=31.302 ms
64 bytes from 114.114.114.114: icmp_seq=2 ttl=56 time=31.250 ms
--- 114.114.114.114 ping statistics ---
3 packets transmitted, 3 packets received, 0% packet loss
round-trip min/avg/max/stddev = 31.130/31.227/31.302/0.072 ms
```

这个结果表明，延迟的确小了很多。继续执行下面的命令，更换 DNS 服务器，然后，再次执行 nslookup 解析命令：

```
/# echo nameserver 114.114.114.114 > /etc/resolv.conf
/# time nslookup time.geekbang.org
Server:		114.114.114.114
Address:	114.114.114.114#53

Non-authoritative answer:
Name:	time.geekbang.org
Address: 39.106.233.176

real    0m0.064s
user    0m0.007s
sys     0m0.006s
```

可以发现，现在只需要 64ms 就可以完成解析，比刚才的 10s 要好很多。

到这里，问题看似就解决了。不过，如果多次运行 nslookup 命令，估计就不是每次都有好结果了。比如，在我的机器中，就经常需要 1s 甚至更多的时间。

```
/# time nslookup time.geekbang.org
Server:		114.114.114.114
Address:	114.114.114.114#53

Non-authoritative answer:
Name:	time.geekbang.org
Address: 39.106.233.176

real	0m1.045s
user	0m0.007s
sys	0m0.004s
```

1s 的 DNS 解析时间还是太长了，对很多应用来说也是不可接受的。那么，该怎么解决这个问题呢？那就是使用 DNS 缓存。这样，只有第一次查询时需要去 DNS 服务器请求，以后的查询，只要 DNS 记录不过期，使用缓存中的记录就可以了。

不过要注意，使用的主流 Linux 发行版，除了最新版本的 Ubuntu （如 18.04 或者更新版本）外，其他版本并没有自动配置 DNS 缓存。

所以，想要为系统开启 DNS 缓存，就需要做额外的配置。比如，最简单的方法，就是使用 dnsmasq。

dnsmasq 是最常用的 DNS 缓存服务之一，还经常作为 DHCP 服务来使用。它的安装和配置都比较简单，性能也可以满足绝大多数应用程序对 DNS 缓存的需求。

继续在刚才的容器终端中，执行下面的命令，就可以启动 dnsmasq：

```
/# /etc/init.d/dnsmasq start
 * Starting DNS forwarder and DHCP server dnsmasq                    [ OK ]
```

然后，修改 /etc/resolv.conf，将 DNS 服务器改为 dnsmasq 的监听地址，这儿是127.0.0.1。接着，重新执行多次 nslookup 命令：

```
/# echo nameserver 127.0.0.1 > /etc/resolv.conf
/# time nslookup time.geekbang.org
Server:		127.0.0.1
Address:	127.0.0.1#53

Non-authoritative answer:
Name:	time.geekbang.org
Address: 39.106.233.176

real	0m0.492s
user	0m0.007s
sys	0m0.006s

/# time nslookup time.geekbang.org
Server:		127.0.0.1
Address:	127.0.0.1#53

Non-authoritative answer:
Name:	time.geekbang.org
Address: 39.106.233.176

real	0m0.011s
user	0m0.008s
sys	0m0.003s
```

现在可以看到，只有第一次的解析很慢，需要 0.5s，以后的每次解析都很快，只需要11ms。并且，后面每次 DNS 解析需要的时间也都很稳定。

案例的最后，还是别忘了执行 exit，退出容器终端，Docker 会自动清理案例容器。

## 小结

今天，我带一起学习了 DNS 的基本原理，并通过几个案例，带一起掌握了，发现DNS 解析问题时的分析和解决思路。

DNS 是互联网中最基础的一项服务，提供了域名和 IP 地址间映射关系的查询服务。很多应用程序在最初开发时，并没考虑 DNS 解析的问题，后续出现问题后，排查好几天才能
发现，其实是 DNS 解析慢导致的。

假如一个 Web 服务的接口 ，每次都需要 1s 时间来等待 DNS 解析，那么，无论怎么优化应用程序的内在逻辑，对用户来说，这个接口的响应都太慢，因为响应时间总是会大于 1 秒的。

所以，在应用程序的开发过程中，必须考虑到 DNS 解析可能带来的性能问题，掌握常见的优化方法。这里，总结了几种常见的 DNS 优化方法。

1. 对 DNS 解析的结果进行缓存。缓存是最有效的方法，但要注意，一旦缓存过期，还是要去 DNS 服务器重新获取新记录。不过，这对大部分应用程序来说都是可接受的。
2. 对 DNS 解析的结果进行预取。这是浏览器等 Web 应用中最常用的方法，也就是说，不等用户点击页面上的超链接，浏览器就会在后台自动解析域名，并把结果缓存起来。
3. 使用 HTTPDNS 取代常规的 DNS 解析。这是很多移动应用会选择的方法，特别是如今域名劫持普遍存在，使用 HTTP 协议绕过链路中的 DNS 服务器，就可以避免域名劫持的问题。
4. 基于 DNS 的全局负载均衡（GSLB）。这不仅为服务提供了负载均衡和高可用的功能，还可以根据用户的位置，返回距离最近的 IP 地址



#  DDoS 攻击

上一节，我带学习了 tcpdump 和 Wireshark 的使用方法，并通过几个案例，带用这两个工具实际分析了网络的收发过程。碰到网络性能问题，不要忘记可以用 tcpdump 和
Wireshark 这两个大杀器，抓取实际传输的网络包，排查潜在的性能问题。

今天，一起来看另外一个问题，怎么缓解 DDoS（Distributed Denial of Service）带来的性能下降问题。



## DDoS 简介

DDoS 的前身是 DoS（Denail of Service），即拒绝服务攻击，指利用大量的合理请求，来占用过多的目标资源，从而使目标服务无法响应正常请求。

DDoS（Distributed Denial of Service） 则是在 DoS 的基础上，采用了分布式架构，利用多台主机同时攻击目标主机。这样，即使目标服务部署了网络防御设备，面对大量网络
请求时，还是无力应对。

比如，目前已知的最大流量攻击，正是去年 Github 遭受的 DDoS 攻击，其峰值流量已经达到了 1.35Tbps，PPS 更是超过了 1.2 亿（126.9 million）。

**从攻击的原理上来看，DDoS 可以分为下面几种类型。**

第一种，耗尽带宽。无论是服务器还是路由器、交换机等网络设备，带宽都有固定的上限。带宽耗尽后，就会发生网络拥堵，从而无法传输其他正常的网络报文。

第二种，耗尽操作系统的资源。网络服务的正常运行，都需要一定的系统资源，像是CPU、内存等物理资源，以及连接表等软件资源。一旦资源耗尽，系统就不能处理其他正常的网络连接。

第三种，消耗应用程序的运行资源。应用程序的运行，通常还需要跟其他的资源或系统交互。如果应用程序一直忙于处理无效请求，也会导致正常请求的处理变慢，甚至得不到响应。

比如，构造大量不同的域名来攻击 DNS 服务器，就会导致 DNS 服务器不停执行迭代查询，并更新缓存。这会极大地消耗 DNS 服务器的资源，使 DNS 的响应变慢。

无论是哪一种类型的 DDoS，危害都是巨大的。那么，如何可以发现系统遭受了 DDoS 攻击，又该如何应对这种攻击呢？接下来，就通过一个案例，一起来看看这些问题。



## 案例准备

下面的案例仍然基于 Ubuntu 18.04，同样适用于其他的 Linux 系统。我使用的案例环境是这样的：

* 机器配置：2 CPU，8GB 内存。
* 预先安装 docker、sar 、hping3、tcpdump、curl 等工具，比如 apt-get install docker.io hping3 tcpdump curl。

其中，hping3 在 系统的软中断 CPU 使用率升高案例 中曾经介绍过，它可以构造 TCP/IP 协议数据包，对系统进行安全审计、防火墙测试、DoS攻击测试等。

本次案例用到三台虚拟机，画了一张图来表示它们之间的关系。

![img](https://img2018.cnblogs.com/blog/1075436/201909/1075436-20190917103121536-1421980360.png)

可以看到，其中一台虚拟机运行 Nginx ，用来模拟待分析的 Web 服务器；而另外两台作为 Web 服务器的客户端，其中一台用作 DoS 攻击，而另一台则是正常的客户端。使用
多台虚拟机的目的，自然还是为了相互隔离，避免“交叉感染”。

**由于案例只使用了一台机器作为攻击源，所以这里的攻击，实际上还是传统的 DoS ，而非 DDoS。**

接下来，打开三个终端，分别 SSH 登录到三台机器上（下面的步骤，都假设终端编号与图示 VM 编号一致），并安装上面提到的这些工具。

同以前的案例一样，下面的所有命令，都默认以 root 用户运行。如果是用普通用户身份登陆系统，请运行 sudo su root 命令切换到 root 用户。
接下来，就进入到案例操作环节。



## 案例分析

首先，在终端一中，执行下面的命令运行案例，也就是启动一个最基本的 Nginx 应用：

```
# 运行 Nginx 服务并对外开放 80 端口
# --network=host 表示使用主机网络（这是为了方便后面排查问题）
$ docker run -itd --name=nginx --network=host nginx
```

然后，在终端二和终端三中，使用 curl 访问 Nginx 监听的端口，确认 Nginx 正常启动。假设 192.168.0.30 是 Nginx 所在虚拟机的 IP 地址，那么运行 curl 命令后，应该会看
到下面这个输出界面：

```
# -w 表示只输出 HTTP 状态码及总时间，-o 表示将响应重定向到 /dev/null
$ curl -s -w 'Http code: %{http_code}\nTotal time:%{time_total}s\n' -o /dev/null http://192.168.0.30/
...
Http code: 200
Total time:0.002s
```

从这里可以看到，正常情况下，访问 Nginx 只需要 2ms（0.002s）。

接着，在终端二中，运行 hping3 命令，来模拟 DoS 攻击：

```
# -S 参数表示设置 TCP 协议的 SYN（同步序列号），-p 表示目的端口为 80
# -i u10 表示每隔 10 微秒发送一个网络帧
$ hping3 -S -p 80 -i u10 192.168.0.30
```

现在，再回到终端一，就会发现，现在不管执行什么命令，都慢了很多。不过，在实践时要注意：

```
如果的现象不那么明显，那么请尝试把参数里面的 u10 调小（比如调成 u1），或者加上–flood 选项；
如果的终端一完全没有响应了，那么请适当调大 u10（比如调成 u30），否则后面就不能通过 SSH 操作 VM1
```

然后，到终端三中，执行下面的命令，模拟正常客户端的连接：

```
# --connect-timeout 表示连接超时时间
$ curl -w 'Http code: %{http_code}\nTotal time:%{time_total}s\n' -o /dev/null --connect-timeout 10 http://192.168.0.30
...
Http code: 000
Total time:10.001s
curl: (28) Connection timed out after 10000 milliseconds
```

可以发现，在终端三中，正常客户端的连接超时了，并没有收到 Nginx 服务的响应。这是发生了什么问题呢？再回到终端一中，检查网络状况。应该还记得多次用
过的 sar，它既可以观察 PPS（每秒收发的报文数），还可以观察 BPS（每秒收发的字节数）。

可以回到终端一中，执行下面的命令：

```
sar -n DEV 1
08:55:49        IFACE   rxpck/s   txpck/s    rxkB/s    txkB/s   rxcmp/s   txcmp/s  rxmcst/s   %ifutil
08:55:50      docker0      0.00      0.00      0.00      0.00      0.00      0.00      0.00      0.00
08:55:50         eth0  22274.00    629.00   1174.64     37.78      0.00      0.00      0.00      0.02
08:55:50           lo      0.00      0.00      0.00      0.00      0.00      0.00      0.00      0.00
```

关于 sar 输出中的各列含义，我在前面的 Linux 网络基础中已经介绍过，可以点击 这里查看，或者执行 man sar 查询手册。

从这次 sar 的输出中，可以看到，网络接收的 PPS 已经达到了 20000 多，但是 BPS 却只有 1174 kB，这样每个包的大小就只有 54B（1174*1024/22274=54）。

这明显就是个小包了，不过具体是个什么样的包呢？那就用 tcpdump 抓包看看吧。在终端一中，执行下面的 tcpdump 命令：

```
# -i eth0 只抓取 eth0 网卡，-n 不解析协议名和主机名
# tcp port 80 表示只抓取 tcp 协议并且端口号为 80 的网络帧
$ tcpdump -i eth0 -n tcp port 80
09:15:48.287047 IP 192.168.0.2.27095 > 192.168.0.30: Flags [S], seq 1288268370, win 512, length 0
09:15:48.287050 IP 192.168.0.2.27131 > 192.168.0.30: Flags [S], seq 2084255254, win 512, length 0
09:15:48.287052 IP 192.168.0.2.27116 > 192.168.0.30: Flags [S], seq 677393791, win 512, length 0
09:15:48.287055 IP 192.168.0.2.27141 > 192.168.0.30: Flags [S], seq 1276451587, win 512, length 0
09:15:48.287068 IP 192.168.0.2.27154 > 192.168.0.30: Flags [S], seq 1851495339, win 512, length 0
...
```

这个输出中，Flags [S] 表示这是一个 SYN 包。大量的 SYN 包表明，这是一个 SYNFlood 攻击。如果用上一节讲过的 Wireshark 来观察，则可以更直观地看到 SYNFlood 的过程：



![img](https://img2018.cnblogs.com/blog/1075436/201909/1075436-20190917103650307-2079790159.png)

 

 

实际上，SYN Flood 正是互联网中最经典的 DDoS 攻击方式。从上面这个图，也可以看到它的原理：

***\*即客户端构造大量的 SYN 包，请求建立 TCP 连接；\****
***\*而服务器收到包后，会向源 IP 发送 SYN+ACK 报文，并等待三次握手的最后一次 ACK报文，直到超时。\****

这种等待状态的 TCP 连接，通常也称为半开连接。由于连接表的大小有限，大量的半开连接就会导致连接表迅速占满，从而无法建立新的 TCP 连接。
参考下面这张 TCP 状态图，能看到，此时，服务器端的 TCP 连接，会处于SYN_RECEIVED 状态：

![img](https://img2018.cnblogs.com/blog/1075436/201909/1075436-20190917103751410-1862348665.png)

这其实提示了，查看 TCP 半开连接的方法，关键在于 SYN_RECEIVED 状态的连接。可以使用 netstat ，来查看所有连接的状态，不过要注意，SYN_REVEIVED 的状态，
通常被缩写为 SYN_RECV。

继续在终端一中，执行下面的 netstat 命令：

```
# -n 表示不解析名字，-p 表示显示连接所属进程
$ netstat -n -p | grep SYN_REC
tcp        0      0 192.168.0.30:80          192.168.0.2:12503      SYN_RECV    -
tcp        0      0 192.168.0.30:80          192.168.0.2:13502      SYN_RECV    -
tcp        0      0 192.168.0.30:80          192.168.0.2:15256      SYN_RECV    -
tcp        0      0 192.168.0.30:80          192.168.0.2:18117      SYN_RECV    -
...
```

从结果中，可以发现大量 SYN_RECV 状态的连接，并且源 IP 地址为 192.168.0.2。

进一步，还可以通过 wc 工具，来统计所有 SYN_RECV 状态的连接数：

```
netstat -n -p | grep SYN_REC | wc -l
193
```

找出源 IP 后，要解决 SYN 攻击的问题，只要丢掉相关的包就可以。这时，iptables 可以帮完成这个任务。可以在终端一中，执行下面的 iptables 命令：

```
iptables -I INPUT -s 192.168.0.2 -p tcp -j REJECT
```

然后回到终端三中，再次执行 curl 命令，查看正常用户访问 Nginx 的情况：

```
curl -w 'Http code: %{http_code}\nTotal time:%{time_total}s\n' -o /dev/null --connect-timeout 10 http://192.168.0.30
Http code: 200
Total time:1.572171s
```

现在，可以发现，正常用户也可以访问 Nginx 了，只是响应比较慢，从原来的 2ms 变成了现在的 1.5s。

不过，一般来说，SYN Flood 攻击中的源 IP 并不是固定的。比如，可以在 hping3 命令中，加入 --rand-source 选项，来随机化源 IP。不过，这时，刚才的方法就不适用了。
幸好，还有很多其他方法，实现类似的目标。比如，可以用以下两种方法，来限制syn 包的速率：

```
# 限制 syn 并发数为每秒 1 次
$ iptables -A INPUT -p tcp --syn -m limit --limit 1/s -j ACCEPT

# 限制单个 IP 在 60 秒新建立的连接数为 10
$ iptables -I INPUT -p tcp --dport 80 --syn -m recent --name SYN_FLOOD --update --seconds 60 --hitcount 10 -j REJECT
```

到这里，已经初步限制了 SYN Flood 攻击。不过这还不够，因为的案例还只是单个的攻击源。

如果是多台机器同时发送 SYN Flood，这种方法可能就直接无效了。因为很可能无法SSH 登录（SSH 也是基于 TCP 的）到机器上去，更别提执行上述所有的排查命令。
所以，这还需要事先对系统做一些 TCP 优化。

比如，SYN Flood 会导致 SYN_RECV 状态的连接急剧增大。在上面的 netstat 命令中，也可以看到 190 多个处于半开状态的连接。

不过，半开状态的连接数是有限制的，执行下面的命令，就可以看到，默认的半连接容量只有 256：

```
sysctl net.ipv4.tcp_max_syn_backlog
net.ipv4.tcp_max_syn_backlog = 256
```

换句话说， SYN 包数再稍微增大一些，就不能 SSH 登录机器了。 所以，还应该增大半连接的容量，比如，可以用下面的命令，将其增大为 1024：

```
sysctl -w net.ipv4.tcp_max_syn_backlog=1024
net.ipv4.tcp_max_syn_backlog = 1024
```

另外，连接每个 SYN_RECV 时，如果失败的话，内核还会自动重试，并且默认的重试次数是 5 次。可以执行下面的命令，将其减小为 1 次：

```
sysctl -w net.ipv4.tcp_synack_retries=1
net.ipv4.tcp_synack_retries = 1
```

除此之外，TCP SYN Cookies 也是一种专门防御 SYN Flood 攻击的方法。SYN Cookies基于连接信息（包括源地址、源端口、目的地址、目的端口等）以及一个加密种子（如系
统启动时间），计算出一个哈希值（SHA1），这个哈希值称为 cookie。

然后，这个 cookie 就被用作序列号，来应答 SYN+ACK 包，并释放连接状态。当客户端发送完三次握手的最后一次 ACK 后，服务器就会再次计算这个哈希值，确认是上次返回的
SYN+ACK 的返回包，才会进入 TCP 的连接状态。

因而，开启 SYN Cookies 后，就不需要维护半开连接状态了，进而也就没有了半连接数的限制。

**注意，开启 TCP syncookies 后，内核选项net.ipv4.tcp_max_syn_backlog 也就无效了。**

可以通过下面的命令，开启 TCP SYN Cookies：

注意，上述 sysctl 命令修改的配置都是临时的，重启后这些配置就会丢失。所以，为了保证配置持久化，还应该把这些配置，写入 /etc/sysctl.conf 文件中。比如：

```
cat /etc/sysctl.conf
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_synack_retries = 1
net.ipv4.tcp_max_syn_backlog = 1024
```

不过要记得，写入 /etc/sysctl.conf 的配置，需要执行 sysctl -p 命令后，才会动态生效。当然案例结束后，别忘了执行 docker rm -f nginx 命令，清理案例开始时启动的 Nginx应用。

### **实际测试代码如下：**

```
192.168.118.85:
[root@luoahong ~]# sar -n DEV 1
Linux 5.1.0-1.el7.elrepo.x86_64 (luoahong) 	09/17/2019 	_x86_64_	(2 CPU)

06:31:44 PM     IFACE   rxpck/s   txpck/s    rxkB/s    txkB/s   rxcmp/s   txcmp/s  rxmcst/s   %ifutil
06:31:45 PM      eth0   1369.00    685.00     80.21     40.26      0.00      0.00      0.00      0.07
06:31:45 PM   docker0      0.00      0.00      0.00      0.00      0.00      0.00      0.00      0.00
06:31:45 PM br-ad2616372f01      0.00      0.00      0.00      0.00      0.00      0.00      0.00      0.00
06:31:45 PM        lo      0.00      0.00      0.00      0.00      0.00      0.00      0.00      0.00
......
06:31:48 PM        lo      0.00      0.00      0.00      0.00      0.00      0.00      0.00      0.00
^C

Average:        IFACE   rxpck/s   txpck/s    rxkB/s    txkB/s   rxcmp/s   txcmp/s  rxmcst/s   %ifutil
Average:         eth0   1453.25    727.00     85.15     43.06      0.00      0.00      0.00      0.07
Average:      docker0      0.00      0.00      0.00      0.00      0.00      0.00      0.00      0.00
Average:    br-ad2616372f01      0.00      0.00      0.00      0.00      0.00      0.00      0.00      0.00
Average:           lo      0.00      0.00      0.00      0.00      0.00      0.00      0.00      0.00

192.168.118.85:
[root@luoahong ~]# netstat -n -p | grep SYN_REC
tcp        0      0 192.168.118.85:80       192.168.118.77:29723    SYN_RECV    -                   
tcp        0      0 192.168.118.85:80       192.168.118.77:29722    SYN_RECV    -                   
[root@luoahong ~]# netstat -n -p | grep SYN_REC
[root@luoahong ~]# netstat -n -p | grep SYN_REC
[root@luoahong ~]# netstat -n -p | grep SYN_REC | wc -l
1

192.168.118.109：
[root@69 ~]# curl -s -w 'Http code: %{http_code}\nTotal time:%{time_total}s\n' -o /dev/null http://192.168.118.85/
Http code: 200
Total time:0.024s

[root@69 ~]# curl -w 'Http code: %{http_code}\nTotal time:%{time_total}s\n' -o /dev/null --connect-timeout 10 http://192.168.118.85
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
102   612  102   612    0     0  46167      0 --:--:-- --:--:-- --:--:-- 68000
Http code: 200
Total time:0.013s

192.168.118.85：
[root@luoahong ~]# tcpdump -i eth0 -n tcp port 80
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), capture size 262144 bytes
18:36:45.485762 IP 192.168.118.77.33258 > 192.168.118.85.http: Flags [S], seq 654860237, win 512, length 0
18:36:45.485819 IP 192.168.118.85.http > 192.168.118.77.33258: Flags [S.], seq 3270815133, ack 654860238, win 64240, options [mss 1460], length 0
18:36:45.488677 IP 192.168.118.77.33258 > 192.168.118.85.http: Flags [R], seq 654860238, win 0, length 0
18:36:45.489600 IP 192.168.118.77.33259 > 192.168.118.85.http: Flags [S], seq 1979340837, win 512, length 0
18:36:45.489649 IP 192.168.118.85.http > 192.168.118.77.33259: Flags [S.], seq 903753158, ack 1979340838, win 64240, options [mss 1460], length 0
18:36:45.490384 IP 192.168.118.77.33259 > 192.168.118.85.http: Flags [R], seq 1979340838, win 0, length 0
18:36:45.490892 IP 192.168.118.77.33260 > 192.168.118.85.http: Flags [S], seq 1525245122, win 512, length 0
18:36:45.490920 IP 192.168.118.85.http > 192.168.118.77.33260: Flags [S.], seq 1880256039, ack 1525245123, win 64240, options [mss 1460], length 0
18:36:45.491789 IP 192.168.118.77.33260 > 192.168.118.85.http: Flags [R], seq 1525245123, win 0, length 0
18:36:45.491864 IP 192.168.118.77.33261 > 192.168.118.85.http: Flags [S], seq 1545646639, win 512, length 0
18:36:45.491890 IP 192.168.118.85.http > 192.168.118.77.33261: Flags [S.], seq 3645078853, ack 1545646640, win 64240, options [mss 1460], length 0
18:36:45.492769 IP 192.168.118.77.33261 > 192.168.118.85.http: Flags [R], seq 1545646640, win 0, length 0
18:36:45.493446 IP 192.168.118.77.33262 > 192.168.118.85.http: Flags [S], seq 1991815131, win 512, length 0
18:36:45.493478 IP 192.168.118.85.http > 192.168.118.77.33262: Flags [S.], seq 1541006520, ack 1991815132, win 64240, options [mss 1460], length 0
......
18:36:45.503180 IP 192.168.118.85.http > 192.168.118.77.33267: Flags [S.], seq 2597604106, ack 1299736667, win 64240, options [mss 1460], length 0
18:36:45.505689 IP 192.168.118.77.33268 > 192.168.118.85.http: Flags [S], seq 565857447, win 512, length 0
18:36:45.505865 IP 192.168.118.85.http > 192.168.118.77.33268: Flags [S.], seq 2577025015, ack 565857448, win 64240, options [mss 1460], length 0
18:36:45.507444 IP 192.168.118.77.33269 > 192.168.118.85.http: Flags [S], seq 2082323681, win 512, length 0
18:36:45.507518 IP 192.168.118.85.http > 192.168.118.77.33269: Flags [S.], seq 3200834539, ack 2082323682, win 64240, options [mss 1460], length 0
18:36:45.507618 IP 192.168.118.77.33268 > 192.168.118.85.http: Flags [R], seq 565857448, win 0, length 0

[root@luoahong ~]# iptables -I INPUT -s 192.168.118.77 -p tcp -j REJECT
192.168.118.77：
root@luoahong:~# hping3 -S -p 80 -i u1 192.168.118.85
HPING 192.168.118.85 (ens33 192.168.118.85): S set, 40 headers + 0 data bytes
ICMP Port Unreachable from ip=192.168.118.85 name=UNKNOWN   
ICMP Port Unreachable from ip=192.168.118.85 name=UNKNOWN   
ICMP Port Unreachable from ip=192.168.118.85 name=UNKNOWN   
ICMP Port Unreachable from ip=192.168.118.85 name=UNKNOWN   
ICMP Port Unreachable from ip=192.168.118.85 name=UNKNOWN   
ICMP Port Unreachable from ip=192.168.118.85 name=UNKNOWN   

192.168.118.109：
[root@69 ~]# curl -w 'Http code: %{http_code}\nTotal time:%{time_total}s\n' -o /dev/null --connect-timeout 10 http://192.168.118.85
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
102   612  102   612    0     0   185k      0 --:--:-- --:--:-- --:--:--  597k
Http code: 200
Total time:0.003s

[root@69 ~]# curl -w 'Http code: %{http_code}\nTotal time:%{time_total}s\n' -o /dev/null --connect-timeout 10 http://192.168.118.85
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
102   612  102   612    0     0  78562      0 --:--:-- --:--:-- --:--:--  149k
Http code: 200
Total time:0.008s
```

### 把攻击的值调整到u1被攻击的机器依然很快

```
root@luoahong:~# hping3 -S -p 80 -i u1 192.168.118.85
HPING 192.168.118.85 (ens33 192.168.118.85): S set, 40 headers + 0 data bytes
len=46 ip=192.168.118.85 ttl=64 DF id=0 sport=80 flags=SA seq=0 win=64240 rtt=0.0 ms
len=46 ip=192.168.118.85 ttl=64 DF id=0 sport=80 flags=SA seq=0 win=64240 rtt=0.0 ms
len=46 ip=192.168.118.85 ttl=64 DF id=0 sport=80 flags=SA seq=0 win=64240 rtt=0.0 ms
len=46 ip=192.168.118.85 ttl=64 DF id=0 sport=80 flags=SA seq=0 win=64240 rtt=0.0 ms
len=46 ip=192.168.118.85 ttl=64 DF id=0 sport=80 flags=SA seq=0 win=64240 rtt=0.0 ms
len=46 ip=192.168.118.85 ttl=64 DF id=0 sport=80 flags=SA seq=0 win=64240 rtt=0.0 ms
len=46 ip=192.168.118.85 ttl=64 DF id=0 sport=80 flags=SA seq=0 win=64240 rtt=0.0 ms
len=46 ip=192.168.118.85 ttl=64 DF id=0 sport=80 flags=SA seq=0 win=64240 rtt=0.0 ms
len=46 ip=192.168.118.85 ttl=64 DF id=0 sport=80 flags=SA seq=0 win=64240 rtt=0.0 ms
len=46 ip=192.168.118.85 ttl=64 DF id=0 sport=80 flags=SA seq=0 win=64240 rtt=0.0 ms
len=46 ip=192.168.118.85 ttl=64 DF id=0 sport=80 flags=SA seq=0 win=64240 rtt=0.0 ms
len=46 ip=192.168.118.85 ttl=64 DF id=0 sport=80 flags=SA seq=0 win=64240 rtt=0.0 ms
len=46 ip=192.168.118.85 ttl=64 DF id=0 sport=80 flags=SA seq=0 win=64240 rtt=0.0 ms
len=46 ip=192.168.118.85 ttl=64 DF id=0 sport=80 flags=SA seq=0 win=64240 rtt=0.0 ms
len=46 ip=192.168.118.85 ttl=64 DF id=0 sport=80 flags=SA seq=0 win=64240 rtt=0.0 ms
len=46 ip=192.168.118.85 ttl=64 DF id=0 sport=80 flags=SA seq=0 win=64240 rtt=0.0 ms
len=46 ip=192.168.118.85 ttl=64 DF id=0 sport=80 flags=SA seq=0 win=64240 rtt=0.0 ms
len=46 ip=192.168.118.85 ttl=64 DF id=0 sport=80 flags=SA seq=0 win=64240 rtt=0.0 ms
len=46 ip=192.168.118.85 ttl=64 DF id=0 sport=80 flags=SA seq=0 win=64240 rtt=0.0 ms
```



## DDoS 到底该怎么防御

到这里，今天的案例就结束了。不过，肯定还有疑问。应该注意到了，今天的主题是“缓解”，而不是“解决” DDoS 问题。

为什么不是解决 DDoS ，而只是缓解呢？而且今天案例中的方法，也只是让 Nginx 服务访问不再超时，但访问延迟还是比一开始时的 2ms 大得多。

实际上，当 DDoS 报文到达服务器后，Linux 提供的机制只能缓解，而无法彻底解决。即使像是 SYN Flood 这样的小包攻击，其巨大的 PPS ，也会导致 Linux 内核消耗大量资
源，进而导致其他网络报文的处理缓慢。

虽然可以调整内核参数，缓解 DDoS 带来的性能问题，却也会像案例这样，无法彻底解决它。

在之前的 C10K、C100K 文章 中，我也提到过，Linux 内核中冗长的协议栈，在 PPS 很大时，就是一个巨大的负担。对 DDoS 攻击来说，也是一样的道理。

所以，当时提到的 C10M 的方法，用到这里同样适合。比如，可以基于 XDP 或者DPDK，构建 DDoS 方案，在内核网络协议栈前，或者跳过内核协议栈，来识别并丢弃
DDoS 报文，避免 DDoS 对系统其他资源的消耗。

不过，对于流量型的 DDoS 来说，当服务器的带宽被耗尽后，在服务器内部处理就无能为力了。这时，只能在服务器外部的网络设备中，设法识别并阻断流量（当然前提是网络设
备要能扛住流量攻击）。比如，购置专业的入侵检测和防御设备，配置流量清洗设备阻断恶意流量等。

既然 DDoS 这么难防御，这是不是说明， Linux 服务器内部压根儿就不关注这一点，而是全部交给专业的网络设备来处理呢？

当然不是，因为 DDoS 并不一定是因为大流量或者大 PPS，有时候，慢速的请求也会带来巨大的性能下降（这种情况称为慢速 DDoS）。

比如，很多针对应用程序的攻击，都会伪装成正常用户来请求资源。这种情况下，请求流量可能本身并不大，但响应流量却可能很大，并且应用程序内部也很可能要耗费大量资源处理。

这时，就需要应用程序考虑识别，并尽早拒绝掉这些恶意流量，比如合理利用缓存、增加WAF（Web Application Firewall）、使用 CDN 等等



## 小结

今天，学习了分布式拒绝服务（DDoS）时的缓解方法。DDoS 利用大量的伪造请求，使目标服务耗费大量资源，来处理这些无效请求，进而无法正常响应正常的用户请求。

由于 DDoS 的分布式、大流量、难追踪等特点，目前还没有方法可以完全防御 DDoS 带来的问题，只能设法缓解这个影响。

比如，可以购买专业的流量清洗设备和网络防火墙，在网络入口处阻断恶意流量，只保留正常流量进入数据中心的服务器中。

在 Linux 服务器中，可以通过内核调优、DPDK、XDP 等多种方法，来增大服务器的抗攻击能力，降低 DDoS 对正常服务的影响。而在应用程序中，可以利用各级缓存、
WAF、CDN 等方式，缓解 DDoS 对应用程序的影响。



# 网络延迟变大

## 一、上节回顾

上一节，学习了碰到分布式拒绝服务（DDoS）的缓解方法。简单回顾一下，DDoS利用大量的伪造请求，导致目标服务要耗费大量资源，来处理这些无效请求，进而无法正
常响应正常用户的请求。

由于 DDoS 的分布式、大流量、难追踪等特点，目前确实还没有方法，能够完全防御DDoS 带来的问题，只能设法缓解 DDoS 带来的影响。

比如，可以购买专业的流量清洗设备和网络防火墙，在网络入口处阻断恶意流量，只保留正常流量进入数据中心的服务器。

在 Linux 服务器中，可以通过内核调优、DPDK、XDP 等多种方法，增大服务器的抗攻击能力，降低 DDoS 对正常服务的影响。而在应用程序中，可以利用各级缓存、WAF、CDN 等方式，缓解 DDoS 对应用程序的影响。

不过要注意，如果 DDoS 的流量，已经到了 Linux 服务器中，那么，即使应用层做了各种优化，网络服务的延迟一般还是会比正常情况大很多。

所以，在实际应用中，通常要让 Linux 服务器，配合专业的流量清洗以及网络防火墙设备，一起来缓解这一问题。

除了 DDoS 会带来网络延迟增大外，我想，肯定见到过不少其他原因导致的网络延迟，比如

1. 网络传输慢，导致延迟；
2. Linux 内核协议栈报文处理慢，导致延迟；
3. 应用程序数据处理慢，导致延迟等等。

那么，当碰到这些原因的延迟时，该怎么办呢？又该如何定位网络延迟的根源呢？今天，我就通过一个案例，带一起看看这些问题

## 二、网络延迟

我相信，提到网络延迟时，可能轻松想起它的含义——网络数据传输所用的时间。不过要注意，这个时间可能是单向的，指从源地址发送到目的地址的单程时间；也可能是双向
的，即从源地址发送到目的地址，然后又从目的地址发回响应，这个往返全程所用的时间。

通常，更常用的是双向的往返通信延迟，比如 ping 测试的结果，就是往返延时RTT（Round-Trip Time）。

除了网络延迟外，另一个常用的指标是应用程序延迟，它是指，从应用程序接收到请求，再到发回响应，全程所用的时间。通常，应用程序延迟也指的是往返延迟，是网络数据传输时间加上数据处理时间的和。

在 Linux 网络基础篇中，我曾经介绍到，可以用 ping 来测试网络延迟。ping 基于ICMP 协议，它通过计算 ICMP 回显响应报文与 ICMP 回显请求报文的时间差，来获得往返延时。这个过程并不需要特殊认证，常被很多网络攻击利用，比如端口扫描工具nmap、组包工具 hping3 等等。

所以，为了避免这些问题，很多网络服务会把 ICMP 禁止掉，这也就导致无法用 ping，来测试网络服务的可用性和往返延时。这时，可以用 traceroute 或 hping3 的 TCP和 UDP 模式，来获取网络延迟。

比如，以 baidu.com 为例，可以执行下面的 hping3 命令，测试的机器到百度搜索服务器的网络延迟：

```
# -c 表示发送 3 次请求，-S 表示设置 TCP SYN，-p 表示端口号为 80
$ hping3 -c 3 -S -p 80 baidu.com
HPING baidu.com (eth0 123.125.115.110): S set, 40 headers + 0 data bytes
len=46 ip=123.125.115.110 ttl=51 id=47908 sport=80 flags=SA seq=0 win=8192 rtt=20.9 ms
len=46 ip=123.125.115.110 ttl=51 id=6788  sport=80 flags=SA seq=1 win=8192 rtt=20.9 ms
len=46 ip=123.125.115.110 ttl=51 id=37699 sport=80 flags=SA seq=2 win=8192 rtt=20.9 ms

--- baidu.com hping statistic ---
3 packets transmitted, 3 packets received, 0% packet loss
round-trip min/avg/max = 20.9/20.9/20.9 ms
```

从 hping3 的结果中，可以看到，往返延迟 RTT 为 20.9ms。

当然，用 traceroute ，也可以得到类似结果：

```
# --tcp 表示使用 TCP 协议，-p 表示端口号，-n 表示不对结果中的 IP 地址执行反向域名解析
$ traceroute --tcp -p 80 -n baidu.com
traceroute to baidu.com (123.125.115.110), 30 hops max, 60 byte packets
 1  * * *
 2  * * *
 3  * * *
 4  * * *
 5  * * *
 6  * * *
 7  * * *
 8  * * *
 9  * * *
10  * * *
11  * * *
12  * * *
13  * * *
14  123.125.115.110  20.684 ms *  20.798 ms
```

traceroute 会在路由的每一跳发送三个包，并在收到响应后，输出往返延时。如果无响应或者响应超时（默认 5s），就会输出一个星号。

知道了基于 TCP 测试网络服务延迟的方法后，接下来，就通过一个案例，来学习网络延迟升高时的分析思路。



## 案例准备

下面的案例仍然基于 Ubuntu 18.04，同样适用于其他的 Linux 系统。使用的案例环境是这样的：

1. 机器配置：2 CPU，8GB 内存。
2. 预先安装 docker、hping3、tcpdump、curl、wrk、Wireshark 等工具，比如 apt-getinstall docker.io hping3 tcpdump curl。

这里的工具应该都比较熟悉了，其中 wrk 的安装和使用方法在 怎么评估系统的网络性能中曾经介绍过。如果还没有安装，请执行下面的命令来安装它：

```
$ apt-get install build-essential git -y
$ git clone https://github.com/wg/wrk
$ cd wrk
$ make
$ sudo cp wrk /usr/local/bin/
```

由于 Wireshark 需要图形界面，如果的虚拟机没有图形界面，就可以把 Wireshark 安装到其他的机器中（比如 Windows 笔记本）。
本次案例用到两台虚拟机，我画了一张图来表示它们的关系。

![img](https://img2018.cnblogs.com/blog/1075436/201909/1075436-20190918100130482-551776504.png)

接下来，打开两个终端，分别 SSH 登录到两台机器上（以下步骤，假设终端编号与图示 VM 编号一致），并安装上面提到的这些工具。注意， curl 和 wrk 只需要安装在客户
端 VM（即 VM2）中。

同以前的案例一样，下面的所有命令都默认以 root 用户运行，如果是用普通用户身份登陆系统，请运行 sudo su root 命令切换到 root 用户。

接下来，就进入到案例操作的环节。

## 四、案例分析

为了对比得出延迟增大的影响，首先，来运行一个最简单的 Nginx，也就是用官方的Nginx 镜像启动一个容器。在终端一中，执行下面的命令，运行官方 Nginx，它会在 80端口监听：

```
$ docker run --network=host --name=good -itd nginx
fb4ed7cb9177d10e270f8320a7fb64717eac3451114c9fab3c50e02be2e88ba2
```

继续在终端一中，执行下面的命令，运行案例应用，它会监听 8080 端口：

```
$ docker run --name nginx --network=host -itd feisky/nginx:latency
b99bd136dcfd907747d9c803fdc0255e578bad6d66f4e9c32b826d75b6812724
```

然后，在终端二中执行 curl 命令，验证两个容器已经正常启动。如果一切正常，将看到如下的输出：

```
# 80 端口正常
$ curl http://192.168.0.30
<!DOCTYPE html>
<html>
...
<p><em>Thank you for using nginx.</em></p>
</body>
</html>

# 8080 端口正常
$ curl http://192.168.0.30:8080
...
<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

接着，再用上面提到的 hping3 ，来测试它们的延迟，看看有什么区别。还是在终端二，执行下面的命令，分别测试案例机器 80 端口和 8080 端口的延迟：

```
# 测试 80 端口延迟
$ hping3 -c 3 -S -p 80 192.168.0.30
HPING 192.168.0.30 (eth0 192.168.0.30): S set, 40 headers + 0 data bytes
len=44 ip=192.168.0.30 ttl=64 DF id=0 sport=80 flags=SA seq=0 win=29200 rtt=7.8 ms
len=44 ip=192.168.0.30 ttl=64 DF id=0 sport=80 flags=SA seq=1 win=29200 rtt=7.7 ms
len=44 ip=192.168.0.30 ttl=64 DF id=0 sport=80 flags=SA seq=2 win=29200 rtt=7.6 ms

--- 192.168.0.30 hping statistic ---
3 packets transmitted, 3 packets received, 0% packet loss
round-trip min/avg/max = 7.6/7.7/7.8 ms
```

8080端口

```
# 测试 8080 端口延迟
$ hping3 -c 3 -S -p 8080 192.168.0.30
HPING 192.168.0.30 (eth0 192.168.0.30): S set, 40 headers + 0 data bytes
len=44 ip=192.168.0.30 ttl=64 DF id=0 sport=8080 flags=SA seq=0 win=29200 rtt=7.7 ms
len=44 ip=192.168.0.30 ttl=64 DF id=0 sport=8080 flags=SA seq=1 win=29200 rtt=7.6 ms
len=44 ip=192.168.0.30 ttl=64 DF id=0 sport=8080 flags=SA seq=2 win=29200 rtt=7.3 ms

--- 192.168.0.30 hping statistic ---
3 packets transmitted, 3 packets received, 0% packet loss
round-trip min/avg/max = 7.3/7.6/7.7 ms
```

从这个输出可以看到，两个端口的延迟差不多，都是 7ms。不过，这只是单个请求的情况。换成并发请求的话，又会怎么样呢？接下来，就用 wrk 试试。

这次在终端二中，执行下面的新命令，分别测试案例机器并发 100 时， 80 端口和 8080端口的性能：

```
# 测试 80 端口性能
$ # wrk --latency -c 100 -t 2 --timeout 2 http://192.168.0.30/
Running 10s test @ http://192.168.0.30/
  2 threads and 100 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     9.19ms   12.32ms 319.61ms   97.80%
    Req/Sec     6.20k   426.80     8.25k    85.50%
  Latency Distribution
     50%    7.78ms
     75%    8.22ms
     90%    9.14ms
     99%   50.53ms
  123558 requests in 10.01s, 100.15MB read
Requests/sec:  12340.91
Transfer/sec:     10.00MB
```

8080端口性能：

```
# 测试 8080 端口性能
$ wrk --latency -c 100 -t 2 --timeout 2 http://192.168.0.30:8080/
Running 10s test @ http://192.168.0.30:8080/
  2 threads and 100 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    43.60ms    6.41ms  56.58ms   97.06%
    Req/Sec     1.15k   120.29     1.92k    88.50%
  Latency Distribution
     50%   44.02ms
     75%   44.33ms
     90%   47.62ms
     99%   48.88ms
  22853 requests in 10.01s, 18.55MB read
Requests/sec:   2283.31
Transfer/sec:      1.85MB
```

从上面两个输出可以看到，官方 Nginx（监听在 80 端口）的平均延迟是 9.19ms，而案例 Nginx 的平均延迟（监听在 8080 端口）则是 43.6ms。从延迟的分布上来看，官方
Nginx 90% 的请求，都可以在 9ms 以内完成；而案例 Nginx 50% 的请求，就已经达到了 44 ms。

再结合上面 hping3 的输出，很容易发现，案例 Nginx 在并发请求下的延迟增大了很多，这是怎么回事呢？

分析方法我想已经想到了，上节课学过的，使用 tcpdump 抓取收发的网络包，分析网络的收发过程有没有问题。

接下来，在终端一中，执行下面的 tcpdump 命令，抓取 8080 端口上收发的网络包，并保存到 nginx.pcap 文件：

```
tcpdump -nn tcp port 8080 -w nginx.pcap
```

然后切换到终端二中，重新执行 wrk 命令：

```
# 测试 8080 端口性能
$ wrk --latency -c 100 -t 2 --timeout 2 http://192.168.0.30:8080/
```

当 wrk 命令结束后，再次切换回终端一，并按下 Ctrl+C 结束 tcpdump 命令。然后，再把抓取到的 nginx.pcap ，复制到装有 Wireshark 的机器中（如果 VM1 已经带有图形界
面，那么可以跳过复制步骤），并用 Wireshark 打开它。

由于网络包的数量比较多，可以先过滤一下。比如，在选择一个包后，可以单击右键并选择 “Follow” -> “TCP Stream”，如下图所示

![img](https://img2018.cnblogs.com/blog/1075436/201909/1075436-20190918100816380-148237234.png)

然后，关闭弹出来的对话框，回到 Wireshark 主窗口。这时候，会发现 Wireshark 已经自动帮设置了一个过滤表达式 tcp.stream eq 24。如下图所示（图中省去了源和目的 IP地址）：

![img](https://img2018.cnblogs.com/blog/1075436/201909/1075436-20190918100828734-1287444027.png)

**实际测试截图：**

**![img](https://img2018.cnblogs.com/blog/1075436/201909/1075436-20190920145842616-196277140.png)**

从这里，可以看到这个 TCP 连接从三次握手开始的每个请求和响应情况。当然，这可能还不够直观，可以继续点击菜单栏里的 Statics -> Flow Graph，选中 “Limit to
display filter” 并设置 Flow type 为 “TCP Flows”：

![img](https://img2018.cnblogs.com/blog/1075436/201909/1075436-20190918100839687-1547977593.png)

***\*实际测试截图：\****

![img](https://img2018.cnblogs.com/blog/1075436/201909/1075436-20190920145913698-202200211.png)

注意，这个图的左边是客户端，而右边是 Nginx 服务器。通过这个图就可以看出，前面三次握手，以及第一次 HTTP 请求和响应还是挺快的，但第二次 HTTP 请求就比较慢了，特
别是客户端在收到服务器第一个分组后，40ms 后才发出了 ACK 响应（图中蓝色行）。看到 40ms 这个值，有没有想起什么东西呢？实际上，这是 TCP 延迟确认（Delayed
ACK）的最小超时时间。

这里我解释一下延迟确认。这是针对 TCP ACK 的一种优化机制，也就是说，不用每次请求都发送一个 ACK，而是先等一会儿（比如 40ms），看看有没有“顺风车”。如果这段
时间内，正好有其他包需要发送，那就捎带着 ACK 一起发送过去。当然，如果一直等不到其他包，那就超时后单独发送 ACK。

因为案例中 40ms 发生在客户端上，有理由怀疑，是客户端开启了延迟确认机制。而这儿的客户端，实际上就是前面运行的 wrk。

查询 TCP 文档（执行 man tcp），就会发现，只有 TCP 套接字专门设置了TCP_QUICKACK ，才会开启快速确认模式；否则，默认情况下，采用的就是延迟确认机制：

```
TCP_QUICKACK (since Linux 2.4.4)
              Enable  quickack mode if set or disable quickack mode if cleared.  In quickack mode, acks are sent imme‐
              diately, rather than delayed if needed in accordance to normal TCP operation.  This flag is  not  perma‐
              nent,  it only enables a switch to or from quickack mode.  Subsequent operation of the TCP protocol will
              once again enter/leave quickack mode depending on internal  protocol  processing  and  factors  such  as
              delayed ack timeouts occurring and data transfer.  This option should not be used in code intended to be
              portable.
```

为了验证的猜想，确认 wrk 的行为，可以用 strace ，来观察 wrk 为套接字设置了哪些 TCP 选项。

比如，可以切换到终端二中，执行下面的命令：

```
strace -f wrk --latency -c 100 -t 2 --timeout 2 http://192.168.0.30:8080/
...
setsockopt(52, SOL_TCP, TCP_NODELAY, [1], 4) = 0
...
```

这样，可以看到，wrk 只设置了 TCP_NODELAY 选项，而没有设置 TCP_QUICKACK。这说明 wrk 采用的正是延迟确认，也就解释了上面这个 40ms 的问题。

不过，别忘了，这只是客户端的行为，按理来说，Nginx 服务器不应该受到这个行为的影响。那是不是分析网络包时，漏掉了什么线索呢？让回到 Wireshark 重新观察一下。

![img](https://img2018.cnblogs.com/blog/1075436/201909/1075436-20190918101015184-1090681429.png)

**实际测试截图：**

**![img](https://img2018.cnblogs.com/blog/1075436/201909/1075436-20190920150007310-115160191.png)**

仔细观察 Wireshark 的界面，其中， 1173 号包，就是刚才说到的延迟 ACK 包；下一行的 1175 ，则是 Nginx 发送的第二个分组包，它跟 697 号包组合起来，构成一个完整的
HTTP 响应（ACK 号都是 85）。

第二个分组没跟前一个分组（697 号）一起发送，而是等到客户端对第一个分组的 ACK后（1173 号）才发送，这看起来跟延迟确认有点像，只不过，这儿不再是 ACK，而是发
送数据。

看到这里，我估计想起了一个东西—— Nagle 算法（纳格算法）。进一步分析案例前，我先简单介绍一下这个算法。

Nagle 算法，是 TCP 协议中用于减少小包发送数量的一种优化算法，目的是为了提高实际带宽的利用率。

举个例子，当有效负载只有 1 字节时，再加上 TCP 头部和 IP 头部分别占用的 20 字节，整个网络包就是 41 字节，这样实际带宽的利用率只有 2.4%（1/41）。往大了说，如果整
个网络带宽都被这种小包占满，那整个网络的有效利用率就太低了。

Nagle 算法正是为了解决这个问题。它通过合并 TCP 小包，提高网络带宽的利用率。Nagle 算法规定，一个 TCP 连接上，最多只能有一个未被确认的未完成分组；在收到这个
分组的 ACK 前，不发送其他分组。这些小分组会被组合起来，并在收到 ACK 后，用同一个分组发送出去。

显然，Nagle 算法本身的想法还是挺好的，但是知道 Linux 默认的延迟确认机制后，应该就不这么想了。因为它们一起使用时，网络延迟会明显。如下图所示：

![img](https://img2018.cnblogs.com/blog/1075436/201909/1075436-20190918101045833-1306234385.png)

当 Sever 发送了第一个分组后，由于 Client 开启了延迟确认，就需要等待 40ms 后才会回复 ACK。

既然可能是 Nagle 的问题，那该怎么知道，案例 Nginx 有没有开启 Nagle 呢？查询 tcp 的文档，就会知道，只有设置了 TCP_NODELAY 后，Nagle 算法才会禁用。

所以，只需要查看 Nginx 的 tcp_nodelay 选项就可以了。

```
TCP_NODELAY
              If set, disable the Nagle algorithm.  This means that segments are always sent as soon as possible, even
              if there is only a small amount of data.  When not set, data is buffered until  there  is  a  sufficient
              amount  to  send out, thereby avoiding the frequent sending of small packets, which results in poor uti‐
              lization of the network.  This option is overridden by TCP_CORK; however, setting this option forces  an
              explicit flush of pending output, even if TCP_CORK is currently set.
```

回到终端一中，执行下面的命令，查看案例 Nginx 的配置:

```
docker exec nginx cat /etc/nginx/nginx.conf | grep tcp_nodelay
    tcp_nodelay    off;
```

果然，可以看到，案例 Nginx 的 tcp_nodelay 是关闭的，将其设置为 on ，应该就可以解决了。

```
# 删除案例应用
$ docker rm -f nginx

# 启动优化后的应用
$ docker run --name nginx --network=host -itd feisky/nginx:nodelay
```

改完后，问题是否就解决了呢？自然需要验证一下。修改后的应用，我已经打包到了Docker 镜像中，在终端一中执行下面的命令，就可以启动它：

接着，切换到终端二，重新执行 wrk 测试延迟：

```
wrk --latency -c 100 -t 2 --timeout 2 http://192.168.0.30:8080/
Running 10s test @ http://192.168.0.30:8080/
  2 threads and 100 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     9.58ms   14.98ms 350.08ms   97.91%
    Req/Sec     6.22k   282.13     6.93k    68.50%
  Latency Distribution
     50%    7.78ms
     75%    8.20ms
     90%    9.02ms
     99%   73.14ms
  123990 requests in 10.01s, 100.50MB read
Requests/sec:  12384.04
Transfer/sec:     10.04MB
```

果然，现在延迟已经缩短成了 9ms，跟测试的官方 Nginx 镜像是一样的（Nginx 默认就是开启 tcp_nodelay 的） 。
作为对比，用 tcpdump ，抓取优化后的网络包（这儿实际上抓取的是官方 Nginx 监听的 80 端口）。可以得到下面的结果：

![img](https://img2018.cnblogs.com/blog/1075436/201909/1075436-20190918101227195-1859888346.png)

从图中可以发现，由于 Nginx 不用再等 ACK，536 和 540 两个分组是连续发送的；而客户端呢，虽然仍开启了延迟确认，但这时收到了两个需要回复 ACK 的包，所以也不用等
40ms，可以直接合并回复 ACK。

案例最后，不要忘记停止这两个容器应用。在终端一中，执行下面的命令，就可以删除案例应用：

## 五、小结

今天，学习了网络延迟增大后的分析方法。网络延迟，是最核心的网络性能指标。由于网络传输、网络包处理等各种因素的影响，网络延迟不可避免。但过大的网络延迟，会
直接影响用户的体验。

所以，在发现网络延迟增大后，可以用 traceroute、hping3、tcpdump、Wireshark、strace 等多种工具，来定位网络中的潜在问题。比如，

1. 使用 hping3 以及 wrk 等工具，确认单次请求和并发请求情况的网络延迟是否正常。
2. 使用 traceroute，确认路由是否正确，并查看路由中每一跳网关的延迟。
3. 使用 tcpdump 和 Wireshark，确认网络包的收发是否正常。
4. 使用 strace 等，观察应用程序对网络套接字的调用情况是否正常。

这样，就可以依次从路由、网络包的收发、再到应用程序等，逐层排查，直到定位问题根源。