# Linux系统启动流程

系统启动简述

​		Linux 操作系统的启动首先从 BIOS 开始，接下来进入 boot loader，由 bootloader 载入内核，进行内核初始化。内核初始化的最后一步就是启动 pid 为 1 的 init 进程。这个进程是系统的第一个进程。它负责产生其他所有用户进程。

​		init 以守护进程方式存在，是所有其它进程的祖先。init 进程非常独特，能够完成其他进程无法完成的任务。

​		先通过一张图来简单了解下整个系统启动的流程，整个过程基本可以分为POST-->BIOS-->MBR(GRUB)-->Kernel-->Init-->Runlevel-->login。下面会详细说明每个过程的作用。

![ospx5czrmc](https://github.com/wangjinh/picture/blob/master/ospx5czrmc.jpeg)



## 第一阶段：硬件引导启动



### 第一步：POST加电自检，加载MBR

​   当你打开计算机电源，计算机会首先加载BIOS(Basic Input/Output System)程序。这是因为BIOS中包含了CPU的相关信息、设备启动顺序信息、硬盘信息、内存信息、时钟信息、PnP特性等。

​		主要实现的功能是检测各个外围硬件设备是否存在而且能够正常运行起来，实现这一自检功能的是固化在主板上的ROM(主要代表为CMOS)芯片上的BIOS程序,；例如BIOS会检测CPU、Memory以及I/O设备是否能够正常运行，如果是个人计算机的话可能还会检测一下显示器。这样就会进入第二步。



### 第二步：通过主引导记录（MBR)，加载GRUB

​     开机自检完成后，CPU首先读取位于CMOS中的BIOS程序，按照BIOS中设定的启动次序（Boot Sequence)逐一查找可启动设备,找到可启动的设备后，去该设备的第一个扇区中读取MBR，那么MBR是什么哪？它又有什么作用哪？       

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

## 第二阶段：通过GRUB，加载kernel到内存

GRUB 的作用有以下几个：

* 加载操作系统的内核；

- 拥有一个可以让用户选择的的菜单，来选择到底启动哪个系统；
- 可以调用其他的启动引导程序，来实现多系统引导。

​		为了打破在MBR中只有446Bytes用于存放bootloader这一限制， Linux 的解决办法是把 GRUB 的程序分成了三个阶段来实现加载内核到内存中运行执行这一功能的。三个阶段分别是：

    	**Stage 1：执行GRUB主程序**

​		第一阶段是加载GRUB程序，这个主程序必须放在启动区中（也就是 MBR 或者引导扇区中）。但是 MBR 太小了，所以只能安装 GRUB 的最小的主程序，而不能安装 GRUB 的相关配置文件。这个主程序主要是用来启动 Stage 1.5 和 Stage 2 的。

   	 **Stage 1.5：识别不同的文件系统**

​		为什么会有stage1.5的过程呢，由于stage1识别不了文件件系统，也就无法加载内核，stage1.5作为stage1和stage2中间的桥梁，stage1.5有识别文件系统的能力，此后grub才有能力去访问/boot分区/boot/grub目录下的 stage2文件，将stage2载入内存并执行。

    	**Stage 2：加载GRUB的配置文件**

Stage 2 阶段主要就是加载 GRUB 的配置文件 /boot/grub/grub.conf，然后根据配置文件中的定义，加载内核和虚拟文件系统。接下来内核就可以接管启动过程，继续自检与加载硬件模块。

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

**注意：**

​		kernel和initrd的文件路径均以grub的"根"作为起始目录，且存放于stage2所在分区上；需要注意的是，stage2、内核以及ramdisk文件通常放置于一个基本磁盘分区之上，因为grub无法驱动lvm、高级软raid等复杂逻辑设备，除非提供一个复杂的驱动接口，否则如果stage2及内核等文件都存放在lvm等复杂逻辑设备上将无法被stage1所识别。



## 第三阶段：**通过内核，完成initrd初始化**	

​		GRUB把内核加载到内存后展开并运行， 此时GRUB的任务已经完成，Kerenl在得到系统控制权之后，首先要进行自身初始化，而**初始化的主要作用**：

* **探测可识别到的所有硬件设备，GRUB将系统控制权移交给内核，它首先要检查一下有哪些是可用的等等。**

* **加载硬件驱动程序，即加载真正的根文件系统所在设备的驱动程序（可能会借助于ramdisk加载驱动）；**

* **以只读方式挂载根文件系统；**

* **切换至根文件系统（rootfs），有可能借助于ramdisk这个临时文件系统（虚根），则在这一步之后会执行根切换；否则不执行根切换。**

* **运行用户空间的第一个应用程序/sbin/init完成系统初始化**

仔细读上面的话，会有个问题，要访问根文件系统必须要加载根文件系统所在的设备，而这时根文件系统又没有挂载，要挂载根文件系统有需要根文件系统的驱动程序，也就说根文件系统是怎样挂载上去的呢？

这里就引入了ramdisk，ramdisk是用于实现系统初始化的、基于内存的磁盘设备，即加载至内存（的某一段空间）后把内存当磁盘使用，并在内存中作为临时根文件系统提供给内核使用，帮助内核挂载真正的根文件系统。而之所以能够帮助内核挂载根文件系统是因为在ramdisk这个临时文件系统的/lib/modules目录下有真正的根文件系统所在设备的驱动程序。除此之外，这个临时文件系统也遵循FHS，例如有这些固定目录结构：/bin, /sbin, /lib, /lib64, /etc, /mnt, /media, ...

GRUB在加载内核同时，也把initrd加载到内存中并运行，那么initr又起到了什么作用呢？

kernel 2.6 以来都是 initramfs ，initramfs 的工作方式更加简单直接一些，启动的时候加载内核和 initramfs 到内存执行，内核初始化之后，切换到用户态执行 initramfs 的程序/脚本，加载需要的驱动模块、必要配置等，然后加载 rootfs 切换到真正的 rootfs 上去执行后续的 init 过程。我们来看一下initrd展开后的文件

```
[root@localhost ~]# ls /boot/
config-2.6.32-642.el6.x86_64    //此版本内核被编译时选择的功能与模块配置文件；
efi/
grub/    //就是引导装载程序grub相关配置文件的目录；
initramfs-2.6.32-642.el6.x86_64.img    //临时根文件系统，提供根文件系统所在分区的驱动；
initrd-2.6.32-642.el6.x86_64kdump.img
lost+found/
symvers-2.6.32-642.el6.x86_64.gz
System.map-2.6.32-642.el6.x86_64    //内核功能放置到内存地址的映射表；
vmlinuz-2.6.32-642.el6.x86_64    //就是内核文件；
[root@localhost initrd]# mkdir /tmp/initrd
[root@localhost initrd]# cd /tmp/initrd
[root@localhost initrd]# cp /boot/initramfs-2.6.32-642.el6.x86_64.img ./
[root@localhost initrd]# zcat initramfs-2.6.32-642.el6.x86_64.img | copi -id
[root@localhost initrd]# ls

```

 linux中/下的文件 

```
[root@localhost ~]# ls /
bin  boot  data  dev  etc  home  lib  lib64  media  mnt  opt  proc  root  run  sbin  srv  sys  tmp  usr  var
[root@localhost ~]# 
```

​		我们可以看到，其实initrd文件其实是一个虚拟的根文件系统，里面有bin、lib、lib64、sys、var、etc、sysroot、 dev、proc、tmp等根目录，它的功能就是将内核与真正的根建立联系，内核通过它加载根文件系统的驱动程序，然后以读写方式挂载根文件系统，至此， 内核加载完成。

**注意：**

    	系统发行商为了适应于各个不同的硬件接口，因此将各个不同的硬件接口的驱动组装打包起来，例如在用户第一次使用光盘安装完系统之后，会动态探测当前主机上的硬件设备并调用与之对应的设备驱动再做成ramdisk文件的。所以，ramdisk文件并非必须的，如果只是为了将Linux安装于特定硬件平台上，就可以直接把对应的驱动编译进内核即可，而不需要去使用ramdisk文件了。



## 第四阶段：运行/sbin/init，进行系统初始化 

​		内核并加载进内存运行并以读写方式挂载完根文件系统后，执行第一个用户进程init，init首先运行/etc/init/rcS.conf脚本，如下图：

![img](https://github.com/wangjinh/picture/blob/master/gc4n7wsbjz.jpg)

可以看到，init进程通过执行/etc/rc.d/rcS.conf首先调用了/etc/rc.d/rc.sysinit，对系统做初始化设置，我们来看看这个脚本都是做了哪些操作？ 

![img](https://github.com/wangjinh/picture/blob/master/u0ff6nufxe.jpg)

事实上init程序会首先执行/etc/rc.d/rc.sysinit脚本，它主要进行以下操作：

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

init执行完/etc/rc.d/rc.sysinit后，将会执行/etc/inittab来设定系统运行的默认级别，init程序读取/etc/inittab定义的运行级别来进行系统初始化。 

![img](https://github.com/wangjinh/picture/blob/master/vsj3n7e8ol.jpg)

如上图，linux中共有[0-6]七个运行级别，而系统默认的运行级别是3级。运行级别用于设定Linux操作系统不同的运行模式。设定完系统默认运行级别以后，接着调用/etc/rc.d/rc脚本，这个脚本接收默认运行级别参数后，依脚本设置启用或停止/etc/rc.d/rc[0-6].d/中相应的程序。

**注意：**

```
在systemd中runlevel已被target取代，systemd会读取/etc/systemd/system/default.target来决定启动到什么样的target(sysv中称为runlevel)，这是一个符号链接，指向/usr/lib/systemd/system/下相应的target，由于可以实现并行启动，systemd没有严格的启动顺序。在CLI环境default.target指向/lib/systemd/system/multi-user.target，systemd通过读取target文件进行下一步操作，比如运行/usr/lib/systemd/system/sysinit.target开始系统初始化，这些都依赖于相应的target文件中的配置。
```

## 第五阶段：打印登录提示符

系统初始化完成后，init给出用户登 录提示符（login）或者图形化登录界面，用户输入用户和密码登陆后，系统会为用户分配一个用户ID（uid）和组ID（gid），这两个ID是用户的 身份标识，用于检测用户运行程序时的身份验证。登录成功后，整个系统启动流程运行完毕！ 



**在整个启动过程中要读取执行的脚本流程大致如下：**

![6oo653g360](https://github.com/wangjinh/picture/blob/master/6oo653g360.jpeg)

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
