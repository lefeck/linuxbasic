### 解决umount: /home: device is busy

**原因:** 是因为有程序在使用/home目录

**解决方法:**
```
1.fuser -kvm /home 
option:
   -k  kill processes accessing the named file
   -m  show all processes using the named filesystems or block device

注意:确保fuser命令存在,如果没有执行yum -y install  psmisc

2.umount -l /home #强行解除挂载
option:
    -l  detach the filesystem now, and cleanup all later
```