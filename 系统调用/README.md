













# 系统调用

## 1	前言

### 1.1	分析 *`include/unistd.h`* 

`Linux 0.11` 内的系统调用由宏及内嵌汇编实现：

```c
/* 在 include/unistd.h 内*/

/* 凡用到 unistd.h 及其内部的系统调用的 .c 文件都应包含:
 * #define __LIBRARY__
 * #include<unistd.h>	 
 */
#ifdef __LIBRARY__
	...
#endif

/* 仅展示三变量代码，其余详见源文件 */
#define _syscall0(type,name)
#define _syscall1(type,name,atype,a)
#define _syscall2(type,name,atype,a,btype,b)
#define _syscall3(type,name,atype,a,btype,b,ctype,c)

#define _syscall3(type,name,atype,a,btype,b,ctype,c) \
type name(atype a,btype b,ctype c) \
{ \
long __res; \
__asm__ volatile ("int $0x80" \
	: "=a" (__res) \
	: "0" (__NR_##name),"b" ((long)(a)),"c" ((long)(b)),"d" ((long)(c))); \
if (__res>=0) \
	return (type) __res; \
errno=-__res; \
return -1; \
}
```

  系统调用实则为 `int 0x80` 的中断。分析上文内嵌汇编 代码，可得下表，同时 `%eax` 也保存返回值：

| 寄存器 |                   值                    |
| :----: | :-------------------------------------: |
| *%eax* | <u>__</u>NR<u>_</u>##name（子程序编号） |
| *%ebx* |             a（第一个形参）             |
| *%ecx* |             b（第二个形参）             |
| *%edx* |             c（第三个形参）             |

### 1.2	分析 *`kernel/system_call.s`*

该文件为 `AT&T` 汇编格式<sup>[1]</sup>。

```assembly
/* 在 kernel/system_calls 内 */

system_call:
	cmpl $nr_system_calls-1,%eax
	ja bad_sys_call
	/* 保存用户段寄存器 ds, es, fs */
	push %ds
	push %es
	push %fs
	/* 向系统调用内核函数传递参数 a,b,c */
	pushl %edx
	pushl %ecx		
	pushl %ebx		
	/* 将 ds, es 指向内核数据空间 */
	movl $0x10,%edx	
	mov %dx,%ds
	mov %dx,%es
	/* 将 fs 指向用户数据空间 */
	movl $0x17,%edx
	mov %dx,%fs
	/* 执行 int 0x80 的子服务程序 */
	// sys_call_table + %eax * 4 
	call sys_call_table(,%eax,4)
```

由于 `system_call.s` 运行在保护模式下，所以 `mov %dx,%fs` 的含义<sup>[2]</sup>有非常大的不同。

## 2	实验内容

在 Linux 0.11 上添加两个系统调用，并编写两个简单的应用程序测试它们。

（1）`iam()`

```c
/* 将字符串 name 拷贝到内核进行保存。返回拷贝的字符数量，要求 name 长度小于 24 字符。
 * 若 name 长度超过 23，则返回 -1，并将 errno 置为 EINVAl。
 */
int iam(const char * name);
```

（2）`whoami()`

```c
/* 将 iam() 保存的字符串拷贝到 name 所指向的用户地址空间内，返回拷贝的字符数量。
 * 用户需设置 size 确保有足够大的缓冲区。
 * 若 size 小于实际所需空间，则返回 -1，并将 errno 置为 EINVAl。
 */
int whoami(char* name, unsigned int size);
```

均在 `kernel/who.c` 中实现。

### 2.1 编写 `who.c`

实现 `who.c` 功能所需的库函数：

```c
/* 在 linux/kernel.h */

/* 内核使用 printk，作用与 printf 一样 */
int printk(const char * fmt, ...)
  
/* 在 asm/segment.h */
/* 从用户空间 addr 位置取出字符放入内核 */
unsigned char get_fs_byte(const char* addr)
    
/* 从内核取出字符 val 放入用户空间 addr 的位置 */
void put_fs_byte(char val, char* addr)
    
/* 在 string.h */
/* 从 s 开始，将长度为 count 的内存单元设置为字符 c */
void * memset(void * s,char c,int count)
```

  

```c
/* 编写 kernel/who.c */

#include <linux/kernel.h>
#include <errno.h>
#include <string.h>
#include <asm/segment.h>

#define MaxNameLength 24

struct username {
    char name[MaxNameLength];
    unsigned int length; 	/*  不包含 '\0' */
};

struct username rootname;

/* 字符串 name 拷贝到内核进行保存，长度小于 24 */
int sys_iam(const char* name)
{
    unsigned int index = 0;
    char ch;
    /* 将 rootname.name 初始化为全 0，以后无需处理 '\0' */
    memset(rootname.name, 0, MaxNameLength);
    
    for (; (ch = get_fs_byte(&name[index])) != '\0' && index != MaxNameLength; ++index)
        /* 拷贝 */
        rootname.name[index] = ch;
    
    if (index == MaxNameLength) {
        /* 越界处理 */
        memset(rootname.name, 0, MaxNameLength);
        printk("User name is too long!\n");
        errno = EINVAL;
        return -1;
    }
    rootname.length = index;
    return index;	/* 返回拷贝字符数量 */
}

/* name 为用户态字符串位置，size 规定缓冲区的大小 */
int sys_whoami(char* name, unsigned int size)
{
    unsigned int name_edge = rootname.length;
    unsigned int index = 0;
    if (size <= name_edge) {
        /* 错误处理 */
        errno = EINVAL;
        return -1;
    }

    /* 要将字符串末尾的 '\0' 加上 */
    for (; index <= name_edge; ++index)
        put_fs_byte(rootname.name[index], &name[index]);
    return name_edge;
}
```

***



### 2.2	修改内核文件

#### 2.2.1	修改 *`include/unistd.h`* 

添加系统调用号及函数原型：

```c
/* 在 include/unistd.h 合适位置添加 */
...
#define __NR_iam	72
#define __NR_whoami	73

int iam(const char* name);
int whoami(char*name,unsigned int size);
```

#### 2.2.2	修改 *`include/linux/sys.h`* 

```c
/* 在 include/linux/sys.h 合适位置添加 */
...
extern int sys_iam();
extern int sys_whoami();

/* sys_call_table[] 中添加 sys_iam, sys_whoami 表项 */
fn_ptr sys_call_table[] = {/* ... */,sys_iam,sys_whoami};
```

 `sys_call_table` 为系统调用向量表，在 `kernel/system_call.s` 中使用，回忆上文 `call sys_call_table(,%eax,4) `。

#### 2.2.3	修改 *`kernel/system_call.s`*

因为添加了两个系统调用，所以将 `nr_system_calls` 由 72 变为 74。

```c
nr_system_calls = 74
```

#### 2.2.4	修改 *`kernel/makefile`* 

在 `OBJS` 内添加 `who.o`，及在`Dependencies` 内添加：

```makefile
OBJS  = who.o

### Dependencies:
who.s who.o:who.c ../include/linux/kernel.h ../include/unistd.h
```

***



### 2.3	编写 `iam.c` 和 `whoami.c`

这两个文件为给用户提供的系统调用，运行在用户态。

```c
/* iam.c */
#define __LIBRARY__
#include<unistd.h>

/* 将字符串 name 拷贝到内核中保存下来 */
_syscall1(int,iam,const char*,name)

int main(int argc,char* argv[])
{
    iam(argv[1]);
    return 0;
}
```

  

```c
/* whoami.c */
#include<stdio.h>
#define __LIBRARY__
#include<unistd.h>

/* 将内核中由 iam() 保存的名字拷贝到 name 指向的用户地址空间中，实际拷贝长度应不大于 size */
_syscall2(int,whoami,char*,name,unsigned int, size)

int main(int argv,char* argc[])
{
	char name[30];
	int re_value = whoami(name,30);
	if(re_value != -1 )
		printf("%s\n",name);
   	 return 0;
}
```

因为 `iam.c` 与 `whoami.c` 均运行在用户态，所以不能在内核编译。因此将写好的两个文件放入虚拟磁盘 `hdc` 中，路径为 `hdc/usr/root` 。因为要在 `Linux 0.11` 上编译该文件，所以需同时修改磁盘上的编译头文件库，使其与系统内核一致：

```c
hdc/usr/include/unistd.h
hdc/usr/include/linux/sys.h
```

最后在 `linux 0.11` 上执行以下命令以编译 `iam.c` 与 `whoami.c`：

```shell
gcc -o iam iam.c
gcc -o whoami whoami.c
sync
```

`sync` 的作用是将编译的可执行文件 `iam` 与 `whoami` 真正的保存在 `hdc` 上。

***



# 注解

[1]	`AT&T` 格式汇编代码，是 `GCC` 、`OBJDUMP` 和其他一些工具的默认格式。另一些编程工具，包括 `Microsoft` 的工具，以及来自 `Intel` 的文档，其汇编代码都是 `Intel`格式的。

```assembly
/* AT&T */
/* ebx <- eax */
movl %eax,%ebx
```

[2]	当 `x86` 计算机运行在保护模式时，寄存器 `CS`、`SS`、`DS`、`ES`、`FS`、`GS` 变为段选择字。寄存器因此被分为两部分：段选择器（16 比特）和描述符高速缓冲器。

`GDT` 表为全局描述表（Global Descriptor Table）,仅有一份，表项有许多，每项八字节，下面仅列出三项。其中 `NULL` 表示操作系统不适用该项：

| 表项 |      GDT 表       |
| :--: | :---------------: |
|  2   | 内核数据段 *Data* |
|  1   | 内核代码段 *Code* |
|  0   |      *NULL*       |

`LDT` 表为局部描述表（Local Descriptor Table），每个进程一份，每份三个表项，每项八字节，其中 `NULL` 同理 ：

| 表项 |      LDT 表       |
| :--: | :---------------: |
|  2   | 进程数据段 *Data* |
|  1   | 进程代码段 *Code* |
|  0   |      *NULL*       |

段描述符每比特结构：

| 15              3 |  2   | 1          0 |
| :---------------: | :--: | :----------: |
|    描述符索引     | *TI* |    *RPL*     |

`TI` 为表指示标志（Table Index），若 `TI = 0` ，则从 `GDT` 表查找表项，若 `TI = 1` ，则从 `IDT` 表查找表项。

`RPL` 为请求特权级（Requested Privilege Level），`0` 表示权限最高，`3` 表示权限最低。

所以 ：

```c
/* 查找 GDT 表，访问内核的数据段，权限最高 */
0x10 == 0b 0000000000010 0 00
    
/* 查找 IDT 表，访问进程的数据段，权限最低 */
0x17 == 0b 0000000000010 1 11
```

