## cache的策略

### cache的分配策略

  cache的分配策略是指我们什么情况下应该为数据分配cache line。cache分配策略分为读和写两种情况。

| 类型           | 说明                                                         |
| -------------- | ------------------------------------------------------------ |
| read allocate  | 当CPU读数据时，发生cache缺失，这种情况下都会分配一个cache line缓存从主存读取的数据。默认情况下，cache都支持读分配。 |
| write allocate | 当CPU写数据发生cache缺失时，才会考虑写分配策略。当我们不支持写分配的情况下，写指令只会更新主存数据，然后就结束了。当支持写分配的时候，我们首先从主存中加载数据到cache line中（相当于先做个读分配动作），然后会更新cache line中的数据。 |

此外:

* Write-Back，write-through，Non-cacheable 主要讲的是回写的策略。
* Shareability主要讲的cache的共享属性和范围，比如后面讲到的inner share，outer share，POC和POU等概念。

通常，cache的相关策略是在MMU页表里进行配置的。还有一点很重要就是只有normal的内存才能被cacheable。

### cache的回写策略

  一般cache有三种回写策略，一个是Non-cacheable，一个是write back，另外一个是write throuhgt。(准确的讲应该是两种，因为第一种是Non-cacheable)

| 类型                    | 说明                                                         |
| ----------------------- | ------------------------------------------------------------ |
| Non-cacheable           | 不使用缓存，直接更新内存                                     |
| Write-Throuth Cacheable | 当CPU执行store指令并在cache命中时，我们更新cache中的数据并且更新主存中的数据。cache和主存的数据始终保持一致。 |
| Write-Back Cacheable    | 当CPU执行store指令并在cache命中时，我们只更新cache中的数据。并且每个cache line中会有一个bit位记录数据是否被修改过，称之为dirty bit（前面的图片，cache line旁边有一个D就是dirty bit）。我们会将dirty bit置位。主存中的数据只会在cache line被替换或者显式的clean操作时更新。因此，主存中的数据可能是未修改的数据，而修改的数据躺在cache中。cache和主存的数据可能不一致。 |

* 对于WT(Write-Throuth)写直通模式：进行写操作时，数据同时写入当前的高速缓存、下一级高速缓存或主存储器中。直写模式可以降低高速缓存一致性的实现难度，其最大的缺点是消耗比较多的总线带宽。对于arm处理器来说，把WT模式看成Non-cacheable。因为在内部实现来看，里面有一个write buffer的部件，WT模式相当于把write buffer部件给disable了。
* Write-Back 回写模式：在进行写操作时，数据直接写入当前高速缓存，而不会继续传递，当该高速缓存行被替换出去时，被改写的数据才会更新到下一级高速缓存或主存储器中。该策略增加了高速缓存一致性的实现难度，但是有效降低了总线带宽需求。



![img](https://img-blog.csdnimg.cn/20201221235505535.jpg?)