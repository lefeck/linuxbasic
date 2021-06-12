# Linux系统启动流程

系统启动简述

​		Linux 操作系统的启动首先从 BIOS 开始，接下来进入 boot loader，由 bootloader 载入内核，进行内核初始化。内核初始化的最后一步就是启动 pid 为 1 的 init 进程。这个进程是系统的第一个进程。它负责产生其他所有用户进程。

​		init 以守护进程方式存在，是所有其它进程的祖先。init 进程非常独特，能够完成其他进程无法完成的任务。

​		先通过一张图来简单了解下整个系统启动的流程，整个过程基本可以分为POST-->BIOS-->MBR(GRUB)-->Kernel-->Init-->Runlevel-->login。下面会详细说明每个过程的作用。

![ospx5czrmc](https://github.com/wangjinh/picture/blob/master/ospx5czrmc.jpeg)



## 第一阶段：硬件引导启动



### 第一步：POST加电自检

​        当你打开计算机电源，计算机会首先加载BIOS(Basic Input/Output System)程序。这是因为BIOS中包含了CPU的相关信息、设备启动顺序信息、硬盘信息、内存信息、时钟信息、PnP特性等。

​		主要实现的功能是检测各个外围硬件设备是否存在而且能够正常运行起来，实现这一自检功能的是固化在主板上的ROM(主要代表为CMOS)芯片上的BIOS程序,；例如BIOS会检测CPU、Memory以及I/O设备是否能够正常运行，如果是个人计算机的话可能还会检测一下显示器。这样就会进入第二步。



### 第二步：引导MBR启动Bootloader

​        开机自检完成后，CPU首先读取位于CMOS中的BIOS程序，按照BIOS中设定的启动次序（Boot Sequence)逐一查找可启动设备,找到可启动的设备后，去该设备的第一个扇区 中读取MBR，那么MBR是什么哪？它又有什么作用哪？       

​		MBR存在于可启动磁盘的0磁道0扇区，也就是Master Boot Record，即主引导记录，占用512字节，它主要用来告诉计算机从选定的可启动设备的哪个分区来加载引导加载程序（Boot loader)，MBR中由三个部分组成：        

​     （1）主引导程序（ Boot Loader） 占用446字节，存储有操作系统（OS）相关信息，如操作系统名称，操作系统内核位置等，它主要功能是加载内核到内存中运行。      

​     （2）硬盘分区表DPT （Disk Partition Table ），占用64字节，每个主分区占用16字节（这就是为啥一块硬盘只能有4个主分区）         

​     （3）分区表有效性标记占用2字节

​		CPU将MBR读取至内存，运行GRUB(Boot Loader常用的有GRUB和LILO两种，现在常用的是GRUB），GRUB会把内核加载到内存去执行。MBR的结构示意图如下：

![c4oxqdvlvr](https://github.com/wangjinh/picture/blob/master/c4oxqdvlvr.jpeg)

​    磁盘分区表包含以下三部分：

​    1）、Partition ID （5：延申 82：Swap  83：Linux  8e：LVM   fd：RAID）

​    2）、Partition起始磁柱

​    3）、Partition的磁柱数量

[![wKioL1iuvUHQga9wAABUcYixWnk723.png](https://www.linuxidc.com/upload/2017_03/170320141986451.png)](https://www.linuxidc.com/upload/2017_03/170320141986451.png)



## 第二阶段：grub启动引导

GRUB 的作用有以下几个：

* 加载操作系统的内核；

- 拥有一个可以让用户选择的的菜单，来选择到底启动哪个系统；
- 可以调用其他的启动引导程序，来实现多系统引导。

​		GRUB`(系统引导程序)`是bootloader中的一种，就grub来说，为了打破在MBR中只有446Bytes用于存放bootloader这一限制， Linux 的解决办法是把 GRUB 的程序分成了三个阶段来实现加载内核到内存中运行执行这一功能的。三个阶段分别是：

    	**Stage 1：执行GRUB主程序**

​		第一阶段是加载GRUB程序，这个主程序必须放在启动区中（也就是 MBR 或者引导扇区中）。但是 MBR 太小了，所以只能安装 GRUB 的最小的主程序，而不能安装 GRUB 的相关配置文件。这个主程序主要是用来启动 Stage 1.5 和 Stage 2 的。

   	 **Stage 1.5：识别不同的文件系统**

​		为什么会有stage1.5的过程呢，由于stage1识别不了文件件系统，也就无法加载内核，stage1.5作为stage1和stage2中间的桥梁，stage1.5有识别文件系统的能力，此后grub才有能力去访问/boot分区/boot/grub目录下的 stage2文件，将stage2载入内存并执行。

    	**Stage 2：加载GRUB的配置文件**

​		当stage2被载入内存执行时，它首先会去解析GRUB的配置文件/boot/grub/grub.conf中的Kernel信息，然后将Kernel加载到内存中运行，当Kernel程序被检测并在加载到内存中，GRUB就将控制权交接给了Kernel程序。存放于磁盘分区之上，具体存放于/boot/grub目录之下，主要用于加载内核文件(vmlinuz-VERSION-RELEASE)以及ramdisk这个临时根文件系统(initrd-VERSION-RELEASE.img或initramfs-VERSION-RELEASE.img)。作用是操作系统启动以后，把它当做一个磁盘使用，从而把它识别成（临时）根文件系统，借助于ramdisk把真正的根文件系统挂载，临时根文件系统自动退出，真正的根将接替工作，临时根不是必须的。

​		其中，与 GRUB（启动引导程序）相关的配置文件，都放置在 /boot/grub 目录中。我们来看看这个目录下到底有哪些文件。

```
[root@localhost ~]# cd /boot/grub/
[root@localhost grub]# ll -h
总用量274K
-rw-r--r--. 1 root root 63 4月 10 21:49 device.map
# GRUB中硬盘的设备文件名与系统的设备文件名的对应文件
-rw-r--r--. 1 root root 14K 4月 10 21:49 e2fs_stage1_5 #ext2/ext3文件系统的Stage 1.5文件
-rw-r--r--. 1 root root 13K 4月 10 21:49 fat_stage1_5
# FAT文件系统的Stage 1文件
-rw-r--r--. 1 root root 12K 4月 10 21:49 ffs_stage1_5
# FFS文件系统的Stage 1.5文件
-rw-------.1 root root 737 4月 10 21:49 grub.conf
# GRUB的配置文件
-rw-r--r--. 1 root root 12K 4 月 10 21:49 iso9660_stage1_5
# iso9660文件系统的Stage 1.5文件
-rw-r--r--. 1 root root 13K 4月 10 21:49 jfs_stage1_5
# JFS文件系统的Stage 1.5文件
Irwxrwxrwx. 1 root root 11 4月 10 21:49 menu.lst ->./grub.conf
# GRUB的配置文件。和grub.conf是软链接，所以两个文件修改哪一个都可以
-rw-r--r--. 1 root root 12K 4 月 10 21:49 minix_stage1_5
# MINIX文件系统的Stage 1.5文件
-rw-r--r--. 1 root root 15K 4 月 10 21:49 reiserfs_stage1_5
# ReiserFS文件系统的Stage 1.5文件
-rw-r--r--. 1 root root 1.4K 11 月 15 2010 splash.xpm.gz
# 系统启动时，GRUB程序的背景图像
-rw-r--r--. 1 root root 512 4月 10 21:49 stage1
# 安装到引导扇区中的Stage 1的备份文件
-rw-r--r--. 1 raot root 124K 4月 10 21:49 stage2 #Stage2的备份文件
-rw-r--r--. 1 root root 12K 4月 10 21:49 ufs2_stage1_5
# UFS文件系统的Stage 1.
-rw-r--r--. 1 root root 12K 4 月 10 21:49 vstafs_stage1_5
# vstafs文件系统的Stage 1.5文件
-rw-r--r--. 1 root root 14K 4月 10 21:49 xfs_stage1_5
# XFS文件系统的Stage 1.5文件
```

可以看到stage1, 各种文件系统对应的stage1.5及stage2这几个阶段的文件都存放于此目录下；



演示：

```
[root@localhost ~]# ls -1F /boot/
config-2.6.32-642.el6.x86_64    //此版本内核被编译时选择的功能与模块配置文件；
efi/
grub/    //就是引导装载程序grub相关配置文件的目录；
initramfs-2.6.32-642.el6.x86_64.img    //临时根文件系统，提供根文件系统所在分区的驱动；
initrd-2.6.32-642.el6.x86_64kdump.img
lost+found/
symvers-2.6.32-642.el6.x86_64.gz
System.map-2.6.32-642.el6.x86_64    //内核功能放置到内存地址的映射表；
vmlinuz-2.6.32-642.el6.x86_64*    //就是内核文件；
[root@localhost ~]# 
[root@localhost ~]# 
[root@localhost ~]# 
[root@localhost ~]# ls -1F /boot/grub/
device.map
e2fs_stage1_5
fat_stage1_5
ffs_stage1_5
grub.conf
iso9660_stage1_5
jfs_stage1_5
menu.lst@
minix_stage1_5
reiserfs_stage1_5
splash.xpm.gz
stage1
stage2
ufs2_stage1_5
vstafs_stage1_5
xfs_stage1_5

```

查看grub的配置文件内容：

```sh
[root@localhost ~]# cat /boot/grub/grub.conf
default=0
timeout=5
splashimage=(hd0,0)/grub/splash.xpm.gz
hiddenmenu
title CentOS (2.6.32-279.el6.i686)
    root (hd0,0)
    kernel /vmlinuz-2.6.32-279.el6.i686 ro root=UUID=b9a7a1a8-767f-4a87-8a2b-a535edb362c9 rd_NO_LUKS KEYBOARDTYPE=pc KEYTABLE=us rd_NO_MD crashkernel=auto LANG=zh_CN.UTF-8 rd_NO_LVM rd_NO_DM rhgb quie
    initrd /initramfs-2.6.32-279.el6.i686.img
```

参数说明：

* default=0    默认启动第一个系统。也就是说，如果在等待时间结束后，用户没有选择进入哪个系统，那么系统会默认进入第一个系统。
* timeout=5   等待时间，默认是 5 秒。也就是在进入系统时，如果 5 秒内用户没有按下任意键，那么系统会进入 default 字段定义的系统。
* splashimage=(hd0,0)/grub/splash.xpm.gz    //hd(0,0) 代表第一块硬盘的第一个分区，用来指定 GRUB 启动时的背景图片的文件路径；
* hiddenmenu：隐藏菜单。启动时默认只能看到读秒，而不能看到菜单。如果想要看到菜单，则需要按任意键。如果增加注释，启动时就能直接看到菜单了。
* title CentOS (2.6.32-279.el6.i686)：菜单项的标题；
* root（hd0,0）：是指启动程序的保存分区。这里要注意，这个 root 并不是管理员。在我的系统中，/boot 分区是独立划分的，而且设备文件名为 /dev/sda1，所以在 GRUB 中就被描述为 hd(0,0)。
* kernel /vmlinuz-2.6.32-279.el6.i686 ro root=UUID=b9a7a1a8-767f-4a87-8a2b-a535edb362c9 rd_NO_LUKS KEYBOARDTYPE=pc KEYTABLE=us rd_NO_MD crashkernel=auto LANG=zh_CN.UTF-8 rd_NO_LVM rd_NO_DM rhgb quiet。其中：
  - /vmlinuz-2.6.32-279.el6.i686：内核文件的位置，这里的 / 是指 boot 分区。
  - ro：启动时以只读方式挂载根文件系统，这是为了不让启动过程影响磁盘内的文件系统。
  - root=UUID=b9a7a1 a8-767f-4a87-8a2b-a535edb362c9：指定根文件系统的所在位置。不再通过分区的设备文件名或卷标号来指定，而是通过分区的 UUID 来指定的。

那么，如何査询分区 UUID 和设备文件名之间的对应关系？通过如下命令查看：

```sh
[root@localhost ~]# cat /etc/fetab | grep "/ "
UUID=b9a7a1a8-767f-4a87-8a2b-a535edb362c9 / ext4 defaults 1 1
```

可以看到"/"分区的 UUID 和 kernel 行中的 UUID 是匹配的。

以下禁用都只是在启动过程中禁用，是为了加速系统启动：

* rd_NO_LUKS：禁用 LUKS，LUKS 用于给磁盘加密。
* rd_NO_MD：禁用软 RAID。
* rd_NO_DM：禁用硬 RAID。
* rd_NO_LVM：禁用 LVM。

除了以上这样，命令输出信息中还包含以下内容：

* KEYBOARDTYPE=pc KEYTABLE=us：键盘类型。
* crashkernel=auto：自动为crashkernel预留内存。
* LANG=zh_CN.UTF-8：语言环境。
* rhgb：(redhatgraphics boot)用图片来代替启动过程中的文字信息。启动完成之后可以使用dmesg命令来查看这些文字信息。
* quiet：隐藏启动信息，只显示重要信息。
* initrd/initramfs-2.6.32-279.el6.i686.img：指定了initramfs虚拟文件系统镜像文件的所在位置。

**注意：**kernel和initrd的文件路径均以grub的"根"作为起始目录，且存放于stage2所在分区上；需要注意的是，stage2、内核以及ramdisk文件通常放置于一个基本磁盘分区之上，因为grub无法驱动lvm、高级软raid等复杂逻辑设备，除非提供一个复杂的驱动接口，否则如果stage2及内核等文件都存放在lvm等复杂逻辑设备上将无法被stage1所识别。



## 第三阶段：内核引导

​		Kernel`(内核)`，是linux系统中最主要的程序，当GRUB将内核加载到内存后，内核开始解压缩内核文件将内核启动。　Kernel会以只读方式挂载根文件系统，当根文件系统被挂载后，开始装载第一个进程(用户空间的进程)，执行/sbin/init，之后就将控制权交接给了init程序。

**注意：**

    	ramdisk和内核是由bootloader一同加载到内存当中的，ramdisk是用于实现系统初始化的、基于内存的磁盘设备，即加载至内存（的某一段空间）后把内存当磁盘使用，并在内存中作为临时根文件系统提供给内核使用，帮助内核挂载真正的根文件系统。而之所以能够帮助内核挂载根文件系统是因为在ramdisk这个临时文件系统的/lib/modules目录下有真正的根文件系统所在设备的驱动程序；除此之外，这个临时文件系统也遵循FHS，例如有这些固定目录结构：/bin, /sbin, /lib, /lib64, /etc, /mnt, /media, ...

   	因为Linux内核有一个特性就是通过使用缓冲/缓存来达到加 速对磁盘上文件的访问的目的，而ramdisk是加载到内存并模拟成磁盘来使用的，所以Linux就会为内存中的“磁盘”再使用一层缓冲/缓存，但是我们的ramdisk本来就是内存，它只不过被当成硬盘来使用罢了，这就造成双缓冲/缓存了，而且不会起到提速效果，甚至影响了访问性能；CentOS 5系列以及之前版本的ramdisk文件为initrd-VERSION-RELEASE.img，就会出现上述所说到的问题；而为了解决一问题，CentOS 6/7系列版本就将其改为initramfs-VERSION-RELEASE.img，使用文件系统的方式就可以避免双缓冲/缓存了，我们可以说这是一种提速机制。

    	需要注意的是，系统发行商为了适应于各个不同的硬件接口，因此将各个不同的硬件接口的驱动组装打包起来，例如在用户第一次使用光盘安装完系统之后，会动态探测当前主机上的硬件设备并调用与之对应的设备驱动再做成ramdisk文件的。所以，ramdisk文件并非必须的，如果只是为了将Linux安装于特定硬件平台上，就可以直接把对应的驱动编译进内核即可，而不需要去使用ramdisk文件了。



## 第四阶段：init初始化

​		init是系统所有进程的父进程，pid为1，当init接管了系统的控制权后，init进程首先读取/etc/inittab文件来执行脚本进行相应系统初始化,要注意的是：/etc/inittab文件只定义系统默认运行级别，真正进行系统初始化工作的是/etc/rc.sysinit脚本，这是第一个被执行的脚本。

### 1.启动初始化进程

Linux的init程序经过了好几个版本，以CentOS为例

| 系统版本       | init程序                                                     |
| -------------- | ------------------------------------------------------------ |
| CentOS 5及以前 | SysV，配置文件： /etc/inittab                                |
| CentOS 6       | Upstart，配置文件： /etc/inittab, /etc/init/*.conf           |
| CentOS 7       | Systemd，配置文件： /usr/lib/systemd/system、 /etc/systemd/system |

在使用SysV的系统上,内核文件加载之后，就开始运行第一个程序/sbin/init，它负责初始化系统环境，他的pid为1，其他所有进程都由它衍生，都是他的子进程。
在采用systemd的系统上，运行的第一个程序为/usr/lib/systemd/systemd，它的的pid同样为1，也是所有进程的父进程。



### 2.设置运行级别

运行级别用于设定Linux操作系统不同的运行模式，运行级别控制Linux系统通过init程序为不同场合分配不同的开机启动程序。

Linux系统有7个运行级别(runlevel)：

| 运行级别   | 说明                                                         |
| ---------- | ------------------------------------------------------------ |
| runlevel 0 | 系统停机、关机，系统默认运行级别不能设为0，否则不能正常启动  |
| runlevel 1 | 单用户状态，root权限，用于系统维护，禁止远程登陆，无网络连接 |
| runlevel 2 | 多用户状态，无网络连接，不运行守护进程，无NFS                |
| runlevel 3 | 完全的多用户状态，有NFS，登陆后进入控制台命令行模式          |
| runlevel 4 | 系统未使用，保留                                             |
| runlevel 5 | 多用户，X11控制台，登陆后进入图形GUI模式                     |
| runlevel 6 | 系统正常关闭并重启，默认运行级别不能设为6，否则不能正常启动  |

init程序读取/etc/inittab定义的运行级别来进行系统初始化。

在systemd中runlevel已被target取代，systemd会读取/etc/systemd/system/default.target来决定启动到什么样的target(sysv中称为runlevel)，这是一个符号链接，指向/usr/lib/systemd/system/下相应的target，由于可以实现并行启动，systemd没有严格的启动顺序。在CLI环境default.target指向/lib/systemd/system/multi-user.target，systemd通过读取target文件进行下一步操作，比如运行/usr/lib/systemd/system/sysinit.target开始系统初始化，这些都依赖于相应的target文件中的配置。



### 3.系统初始化

当设置好了runlevel之后，init程序会首先执行/etc/rc.d/rc.sysinit脚本，它是每个runlevel都要执行的重要脚本，它主要进行以下操作：

```
1.设置主机名称；
2.设置启动的欢迎信息；
3.激活udev和SELinux
4.挂载/etc/fstab文件中定义的所有有效文件系统；
5.激活各个swap设备；
6.检测rootfs，并且以读写的方式重新挂载rootfs；
7.设置系统时间；
8.根据/etc/sysctl.conf文件设置内核参数；
9.激活lvm和软RAID等高级逻辑设备；
10.加载额外的设备的驱动程序；
11.完成清理工作；
```

然后init程序根据相应的级别加载对应配置的程序，所有由rc脚本关闭或启动的链接文件的源文件都存在于/etc/rc.d/init.d，通过链接的方式放入不同的runlevel文件夹。比如当引导至运行级别 5 时，init 程序会在 /etc/rc.d/rc5.d/ 目录中查看并确定要启动和停止的进程。当init程序启动完对应的程序与守护进程后，这是系统环境基本已经搭建好了。

在systemd中，/usr/lib/systemd/system/sysinit.target、/usr/lib/systemd/system/basic.target等target会根据对应的依赖关系启动，执行相应的系统初始化任务。



### 4.用户登陆

用户可以通过三种方式登陆Linux

- CLI登陆
- SSH登陆
- GUI登陆



**在整个启动过程中要读取执行的脚本流程大致如下：**

![6oo653g360](/Users/jinhuaiwang/Desktop/linux system kernel/picture/6oo653g360.jpeg)

### 总结

简化的Linux系统启动流程

BIOS + MBR

```
POST --> BIOS --> MBR --> Bootloader --> kernel + ramdisk --> rootfs(read-only) --> /sbin/init(systemd) --> login
```



UEFI + GPT

```
POST --> UEFI --> EFI Application(Bootloader) --> kernel + ramdisk --> rootfs(read-only) --> /sbin/init(systemd) --> login
```



https://jaydenz.github.io/2018/05/05/4.Linux系统启动流程/#总结