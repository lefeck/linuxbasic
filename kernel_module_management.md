Linux 的内核会在启动过程中自动检验和加载硬件与文件系统的驱动。一般这些驱动都是用模块的形式加载的，使用模块的形式保存驱动，可以不直接把驱动放入内核，有利于控制内核大小。



模块的全称是动态可加载内核模块，它是具有独立功能的程序，可以被单独编译，但不能独立运行。模块是为内核或其他模块提供功能的代码集合。这些模块可以是 Linux 源码中自带的，也可以是由硬件厂商开发的（可以想象成驱动）。不过内核因为发布时间较长，所以自带的模块可能版本较低，还有一些新硬件可能就不自带模块了，只能由硬件厂商在发布硬件的同时发布新模块。

一个内核模块的从创建到使用会经过如下过程

> 源代码-->Makefile文件-->编译模块-->加载模块-->卸载模块

从某种意义上来说，内核也是一个模块。模块可以理解为为内核或其他内核模块提供使用功能的代码块，是内核的动态扩展。

也就是说，安装模块一般有两种方法：

- 第一种方法在编译内核时，手工调整内核模块功能，加入所需的模块。这种方法有一个问题，就是内核必须支持这个硬件或功能才可以通过编译内核加入模块。如果硬件比内核新，内核本身并不支持硬件，就不能通过重新编译内核来加入新的硬件的支持。
- 第二种方法就是下载厂商发布的新硬件的驱动模块，或下载驱动程序，再编译成驱动模块，然后手工安装。


本节我们主要来学习第二种方法，也就是如果我已经得到了一个模块，该如何手工安装？这个模块该如何得到呢？

如果是新硬件的驱动，则可以到硬件官方网站下载内核驱动或内核模块。如果下载的是内核模块，则直接安装即可；如果下载的是内核驱动源码，则只需要编译源码包，就会生成模块（具体编译过程和源码包安装非常类似，可以查看驱动的说明）。如果需要加入的模块不是硬件的驱动，而只是内核中的某项功能，那么，只要部分重新编译内核，就可以生成新功能的模块（我们会通过 NTFS 文件系统支持来学习这种方法)，然后安装这个模块即可。

## 内核模块文件

内核模块文件位置在/lib/modules/$(uname -r)/kernel/ 目录中，在 CentOS 7.x 中这个目录就是：

```sh
[root@localhost ~]# cd /lib/modules/$(uname -r)
[root@localhost kernel]# ls
build   modules.alias      modules.builtin          modules.dep      modules.drm          modules.order    modules.symbols.bin  vdso
extra   modules.alias.bin  modules.builtin.bin      modules.dep.bin  modules.modesetting  modules.softdep  source               weak-updates
kernel  modules.block      modules.builtin.modinfo  modules.devname  modules.networking   modules.symbols  updates
[root@localhost ~]# cd /lib/modules/$(uname -r)/kernel/
[root@localhost kernel]# ls
arch
# 与硬件相关的模块
crypto
#内核支持的加密技术的相关模块
drivers
#硬件的驱动程序模块，如显卡、网卡等
fs
#文件系统模块，如 fat、vfat、nfs等
lib
#函数库
net
#网络协议相关模块
sound
#音效相关模块
```

Linux 中所有的模块都存放在 /lib/modules/5.5.7-1.el7.elrepo.x86_64/modules.dep 文件中，在安装模块时，依赖这个文件査找所有的模块，所以不需要指定模块所在位置的绝对路径，而且也依靠这个文件来解决模块的依赖性。如果这个文件丢失了，使用 depmod 命令会自动扫描系统中已有的模块，并生成 modules.dep 文件。命令格式如下：

```sh
[root@localhost ~]# depmod [选项]
```

* 不加选项，depmod命令会扫描系统中的内核模块，并写入modules.dep文件

**选项：**

- -a：扫描所有模块；
- -A：扫描新模块，只有有新模块时，才会更新modules.dep文件；
- -n：把扫描结果不写入modules.dep文件，而是输出到屏幕上；

我们把 modules.dep 文件删除，使用 depmod 命令查看是否可以重新生成这个文件。命令如下：

```sh
# 进入模块目录
[root@localhost ~]# cd /lib/modules/5.5.7-1.el7.elrepo.x86_64/
# 删除 modules.dep文件
[root@localhost 5.5.7-1.el7.elrepo.x86_64]# rm -rf modules.dep
#重新扫描模块
[raot@localhost 5.5.7-1.el7.elrepo.x86_64]# depmod
#再查看一下，modules.dep文件又生成了
[root@localhost 5.5.7-1.el7.elrepo.x86_64]# ls -l modules.dep
-rw-r--r--. 1 root root 191899 5 月 23 07:09 modules.dep
```

depmod 命令会扫描系统中所有的内核模块，然后把扫描结果放入 modules.dep 文件。

## 内核模块查看

使用 lsmod 命令可以查看系统中到底安装了哪些内核模块。命令如下：

```shell
[root@localhost ~]# lsmod
Module                  Size  Used by
nls_utf8               16384  1 
isofs                  45056  1 
xt_conntrack           16384  2 
xt_mark                16384  4 
xt_addrtype            16384  1 
xt_set                 16384  3 
ip_set_hash_ipportnet    40960  1 
ip_set_hash_ipportip    36864  2 
…省略部分输出…
```

lsmod命令的指定结果共有三列。

- Module：模块名。
- Size：模块大小。
- Used by：模块是否被其他模块调用。

可以使用 modinfo 命令来查看这些模块的基本信息

```sh
[root@localhost ~]# modinfo 模块名
[root@k8s-node1 5.5.7-1.el7.elrepo.x86_64]# modinfo kernel/fs/ext4/ext4.ko 
filename:       /lib/modules/5.5.7-1.el7.elrepo.x86_64/kernel/fs/ext4/ext4.ko
softdep:        pre: crc32c
license:        GPL
description:    Fourth Extended Filesystem
author:         Remy Card, Stephen Tweedie, Andrew Morton, Andreas Dilger, Theodore Ts'o and others
alias:          fs-ext4
alias:          ext3
alias:          fs-ext3
alias:          ext2
alias:          fs-ext2
srcversion:     A63C2335C7B44AB67F39229
depends:        mbcache,jbd2
retpoline:      Y
intree:         Y
name:           ext4
vermagic:       5.5.7-1.el7.elrepo.x86_64 SMP mod_unload modversions 
```

\#能够看到模块名，来源和简易说明

## 内核模块添加与删除

modprobe：加载或卸载内核模块，需要根据modules.dep.bin文件进行加载操作，可以自动解决模块间的依赖关系表首先需要把模块复制到指定位置，一般复制到 /lib/modules/$(uname -r)/目录中，模块的扩展名一般是 *.ko;然后需要执行 depmod 命令扫描这些新模块，并写入 modules.dep 文件；最后就可以利用 modprobe 命令安装这些模块了。命令格式如下：

```sh
[root@localhost ~]# modprobe [选项] 模块名
```

选项：

- -I：列出所有模块的文件名，依赖 modules.dep 文件；
- -f：强制加载模块；
- -r：删除模块；

举例，我们安装 ext4 模块，执行如下命令：

```sh
[root@localhost ~]# lsmod|grep ext4     
[root@localhost ~]# modprobe ext4              #加载模块
[root@localhost ~]# lsmod|grep ext4
ext4                  528957  0 
mbcache                14958  1 ext4
jbd2                   98341  1 ext4
[root@localhost ~]# modprobe -r ext4           #卸载模块
[root@localhost ~]# lsmod|grep ext4
```

depmod：查找/lib/moduels/(uname -r)/中的所有模块并建立modules.dep.bin文件，该文件记录了模块位置及依赖关系

```sh
[root@localhost ~]# cd /lib/modules/$(uname -r)/
[root@localhost 5.5.7-1.el7.elrepo.x86_64]# ls|grep dep  
modules.dep
modules.dep.bin
modules.softdep
[root@localhost 5.5.7-1.el7.elrepo.x86_64]# rm -rf modules.dep.bin 
[root@localhost 5.5.7-1.el7.elrepo.x86_64]# modprobe ext4
modprobe: FATAL: Module ext4 not found.
[root@localhost 5.5.7-1.el7.elrepo.x86_64]# depmod -a         #生成文件
[root@localhost 5.5.7-1.el7.elrepo.x86_64]# modprobe ext4
[root@localhost 5.5.7-1.el7.elrepo.x86_64]# lsmod|grep ext4
ext4                  528957  0 
mbcache                14958  1 ext4
jbd2                   98341  1 ext4
[root@localhost 5.5.7-1.el7.elrepo.x86_64]# ls|grep dep            
modules.dep
modules.dep.bin
modules.softdep
```