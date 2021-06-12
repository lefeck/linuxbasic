# Linux系统启动流程

系统启动简述

​		Linux 操作系统的启动首先从 BIOS 开始，接下来进入 boot loader，由 bootloader 载入内核，进行内核初始化。内核初始化的最后一步就是启动 pid 为 1 的 init 进程。这个进程是系统的第一个进程。它负责产生其他所有用户进程。

​		init 以守护进程方式存在，是所有其他进程的祖先。init 进程非常独特，能够完成其他进程无法完成的任务。

​		先通过一张图来简单了解下整个系统启动的流程，整个过程基本可以分为POST-->BIOS-->MBR(GRUB)-->Kernel-->Init-->Runlevel-->login。下面会详细说明每个过程的作用。

![ospx5czrmc](https://github.com/wangjinh/picture/blob/master/ospx5czrmc.jpeg)



## 第一阶段：硬件引导启动



### 第一步：POST加电自检

​		主要实现的功能是检测各个外围硬件设备是否存在而且能够正常运行起来，实现这一自检功能的是固化在主板上的ROM(主要代表为CMOS)芯片上的BIOS(Basic Input/Output System)程序；例如BIOS会检测CPU、Memory以及I/O设备是否能够正常运行，如果是个人计算机的话可能还会检测一下显示器。只要一通电，CPU就会自动去加载ROM芯片上的BIOS程序，是这样来实现的。而检测完成之后就进行硬件设备的初始化。

 

### 第二步：引导MBR启动Bootloader

​		在加电自检完成后BIOS会加载MBR并且运行grub（Bootloader程序）；MBR主引导分区信息在硬盘的0柱面，0磁头，第一个扇区，它由三个部分组成，主引导程序（bootloader），硬盘分区表DPT（Disk Partition table），和硬盘有效标志（55AA），它的结构图示如下：

![c4oxqdvlvr](https://github.com/wangjinh/picture/blob/master/c4oxqdvlvr.jpeg)

​    磁盘分区表包含以下三部分：

​    1）、Partition ID （5：延申 82：Swap  83：Linux  8e：LVM   fd：RAID）

​    2）、Partition起始磁柱

​    3）、Partition的磁柱数量

​		主要实现的功能是选择要启动的硬件设备，选择可以读取这个设备上位于MBR里头的bootloader了。这一步的实现是这样的：根据BIOS中对启动顺序的设定，BIOS自己会依次扫描各个引导设备，然后第一个被扫描到具有引导程序(bootloader)的设备就被作为要启动的引导设备。

[![wKioL1iuvUHQga9wAABUcYixWnk723.png](https://www.linuxidc.com/upload/2017_03/170320141986451.png)](https://www.linuxidc.com/upload/2017_03/170320141986451.png)



## 第二阶段：grub启动引导

    	**而bootloader要实现的功能就是提供一个菜单给用户，让用户去选择要启动的系统或不同的内核版本，然后把用户选择的内核版本加载至RAM中的特定空间，接着在RAM中解压、展开，而后把系统控制权移交给内核。**

​		GRUB`(系统引导程序)`是bootloader中的一种，就grub来说，为了打破在MBR中只有446Bytes用于存放bootloader这一限制，所以这一步的实现是这样的：grub是通过分成三个阶段来实现加载内核到内存中运行这一功能的，这三个阶段分别是：stage1, stage1.5以及stage2。其中：

    	**stage1：**第一阶段是加载Bootloader程序，stage1是直接被写到MBR的前446Bytes，用于加载stage1.5阶段，此时系统在没有启动时stage1是识别不到文件系统的。
   	 **stage1.5: **为什么会有stage1.5的过程呢，由于stage1识别不了文件件系统，也就无法加载内核，stage1_5作为stage1和stage2中间的桥梁，stage1_5有识别文件系统的能力，此后grub才有能力去访问/boot分区/boot/grub目录下的 stage2文件，将stage2载入内存并执行。
    	**stage2：**当stage2被载入内存执行时，它首先会去解析grub的配置文件/boot/grub/grub.conf中的Kernel的信息，然后将Kernel加载到内存中运行，当Kernel程序被检测并在加载到内存中，GRUB就将控制权交接给了Kernel程序。存放于磁盘分区之上，具体存放于/boot/grub目录之下，主要用于加载内核文件(vmlinuz-VERSION-RELEASE)以及ramdisk这个临时根文件系统(initrd-VERSION-RELEASE.img或initramfs-VERSION-RELEASE.img)。作用是操作系统启动以后，把它当做一个磁盘使用，从而把它识别成（临时）根文件系统，借助于ramdisk把真正的根文件系统挂载，临时根文件系统自动退出，真正的根将接替工作，临时根不是必须的，

​		概述：假如要启动的是硬盘设备，首先我们的硬件平台主板BIOS必须能够识别硬盘，然后BIOS才能加载硬盘中的bootloader，而bootloader自身加载后就能够直接识别当前主机上的硬盘设备了；不过，能够识别硬盘设备不代表能够识别硬盘设备中的文件系统，因为文件系统是额外附加的一层软件组织的文件结构，所以要对接一种文件系统，就必须要有对应的能够识别和理解这种文件系统的驱动，这种驱动就称为文件系统驱动。而stage1.5就是向grub提供文件系统驱动的，这样stage1就能访问stage2及内核所在的分区(/boot)了。
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
//可以看到stage1, 各种文件系统对应的stage1.5及stage2这几个阶段的文件都存放于此目录下；
```

查看grub的配置：

```
[root@localhost ~]# vim /boot/grub/grub.conf
default=0    //设定默认启动第一个菜单项(title)；
timeout=5    //等待用户选择菜单项的时长；
splashimage=(hd0,0)/grub/splash.xpm.gz    //指明菜单项的背景图片的文件路径；
hiddenmenu    //是否隐藏菜单的具体内容；
title CentOS (2.6.18-398.el5)    //此处为菜单项的标题；
    root (hd0,0)   //指定grub查找stage2及Kernel文件所在设备的分区；可理解为grub的"根"，对grub而言，所有类型硬盘都是hd，格式为(hd#,N)；hd#, #表示第几个磁盘；N表示对应磁盘的分区；修复硬盘使用；
    kernel /vmlinuz-2.6.18-398.el5 ro root=/dev/VolGroup00/LogVol00    //启动的内核；
    initrd /initrd-2.6.18-398.el5.img    //与内核匹配的ramdisk文件；
```

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