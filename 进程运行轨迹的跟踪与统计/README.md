# 进程运行轨迹的跟踪与统计

## 1	前言

### 1.1	进程运行状态

```c
/* 在 include/linux/sched.h 中定义 */
#define TASK_RUNNING		0
#define TASK_INTERRUPTIBLE	1
#define TASK_UNINTERRUPTIBLE	2
#define TASK_ZOMBIE		3
#define TASK_STOPPED		4
```

|        进程状态        |       含义       |                             注释                             |
| :--------------------: | :--------------: | :----------------------------------------------------------: |
|     *TASK_RUNNING*     | 正在执行或就绪态 |           进程可以在内核态运行，也可在用户态运行。           |
|  *TASK_INTERRUPTIBLE*  |  可中断睡眠状态  | 系统不会调度该进程，当系统产生中断或释放该进程所等待的资源，或进程收到信号，进程都可以被唤醒，进入就绪态 |
| *TASK_UNINTERRUPTIBLE* | 不可中断睡眠状态 | 与前者相似，但该状态的进程只有被 *wake_up()* 函数明确唤醒时，才能进入就绪态。 |
|     *TASK_ZOMBIE*      |     僵死状态     | 当进程已停止运行，但其父进程还没有询问其状态时，该进程处于僵死状态。 |
|     *TASK_STOPPED*     |     暂停状态     | 当进程收到信号 *SIGSTOP*、*SIGTSTP*、*SIGTTIN*、*SIGTTOU* 时会进入暂停状态。向其发送 *SIGCONT* 信号可让该进程转为就绪态。但在 *Linux 0.11* 上未实现该转换，因此处于该状态的进程被视为终止进程。 |

### 1.2	滴答 `jiffies`

`jiffies` 在 `kernel/sched.c` 文件中定义为一个全局变量：

```c
long volatile jiffies = 0;
```

它记录了从开机到当前时间的时钟中断发生次数。在 `kernel/sched.c` 文件中的 `sched_init()` 函数中，时钟中断处理函数被设置为：

```c
set_intr_gate(0x20,&timer_interrupt);
```

而在 `kernel/system_call.s` 文件中将 `timer_interrupt` 定义为：

```
timer_interrupt:
!    ……
! 增加 jiffies 计数值
    incl jiffies
!    ……
```

这说明 `jiffies` 表示从开机时到现在发生的时钟中断次数，这个数也被称为 “滴答数”。

另外，在 `kernel/sched.c` 中的 `sched_init()` 中有下面的代码：

```c
/* 设置 8253 模式 */
outb_p(0x36, 0x43);
outb_p(LATCH&0xff, 0x40);
outb_p(LATCH>>8, 0x40);
```

这三条语句用来设置每次时钟中断的间隔，即为 `LATCH`，而 `LATCH` 是定义在文件 `kernel/sched.c` 中的一个宏：

```c
/* 在 include/linux/sched.h */
#define HZ 100

/* 在 kernel/sched.c */
#define LATCH  (1193180/HZ)
```

再加上 PC 机 8253 定时芯片的输入时钟频率为 1.193180 MHz，即 1193180 / s，LATCH = 1193180/100，时钟每跳 11931.8 下产生一次时钟中断，即每 1/100 秒（10ms）产生一次时钟中断，所以 `jiffies` 实际上记录了从开机以来共经过了多少个 10ms。

***



## 2	实验内容

进程从创建（Linux 下调用 fork()）到结束的整个过程就是进程的生命期，进程在其生命期中的运行轨迹实际上就表现为进程状态的多次切换。本实验要求通过写入文件，记录各进程的状态切换。

### 2.1	修改 *`init/main.c`*

操作系统启动后先要打开 `/var/process.log`，然后在每个进程发生状态切换的时候向该文件写入一条记录。同时在内核态写入文件就不能使用系统调用了。

为了能尽早开始记录，应当在内核启动时就打开 log 文件。内核的入口是 `init/main.c` 中的 `main()`，其中一段代码是：

```c
/* 在 init/main.c */
/* 在 main() */

/* …… */
move_to_user_mode();
if (!fork()) {
    init();
}
/* …… */
```

`move_to_user_mode()` 切换到用户模式，该代码在进程 `0` 中运行，进程 `1` 执行 `init()` 。

```C
/* 在 init/main.c */
/* 在 init() */

/* …… */
/* 加载文件系统 */
setup((void *) &drive_info);

/* 打开 /dev/tty0，建立文件描述符 0 和 /dev/tty0 的关联 */
(void) open("/dev/tty0",O_RDWR,0);

/* 让文件描述符 1 也和 /dev/tty0 关联 */
(void) dup(0);

/* 让文件描述符 2 也和 /dev/tty0 关联 */
(void) dup(0);
/* …… */
       
```

文件描述符 `0` 、`1` 、`2` 分别对应 `stdin` 、`stdout` 、`stderr` ，这三者为系统标准，不可修改。上段代码用到的系统调用：

1）`open`

```C
/* pathname = 要打开的文件路径， flag = 打开文件动作， mode = 文件访问权限 */
int open(const char *pathname, int flag, mode_t mode);
```

2）`dup`

```C
/* 返回一个进程可使用的最小文件描述符，其与 fd 指向同一文件，若有错误，则返回 -1 */
int dup(int fd);
```

关于 `open` 具体参数信息<sup>[1]</sup>详见注解。

我们可以把 `log` 文件的描述符关联到 `3` 。在文件系统初始化，描述符 `0` 、`1` 和 `2` 关联之后，才能打开 `log` 文件，开始记录进程的运行轨迹。为了能尽早访问 `log` 文件，要让上述工作在进程 `0` 中就完成。所以把这一段代码从 `init()` 移动到 `main()` 中，放在 `move_to_user_mode()` 之后（系统调用必须在用户态执行，不能再靠前），同时加上打开 `log` 文件的代码。

修改后的 `main()` 如下：

```c
/* 在 init/main.c */
/* 在 main() */

/* …… */
move_to_user_mode();

/***************添加开始***************/
setup((void *) &drive_info);
(void) open("/dev/tty0",O_RDWR,0);
(void) dup(0);
(void) dup(0);
(void) open("/var/process.log",O_CREAT|O_TRUNC|O_WRONLY,0666);
/***************添加结束***************/

if (!fork()) {
    init();
}
/* …… */
```

`0666`<sup>[1]</sup> 详见注解。

***



### 2.2	内核程序如何向 *`log`* 写入

`log` 文件将被用来记录进程的状态转移轨迹。所有的状态转移都是在内核进行的。

在内核状态下，`write()` 功能失效，其原理等同于不能在内核状态调用 `printf()`，只能调用 `printk()`。编写可在内核调用的 `write()` 的难度较大，所以李老师直接给出源码。它主要参考了 `printk()` 和 `sys_write()` 而写成：

```c
/* 在 kernel/printk.c */

#include "linux/sched.h"
#include "sys/stat.h"

static char logbuf[1024];
int fprintk(int fd, const char *fmt, ...)
{
    va_list args;
    int count;
    struct file * file;
    struct m_inode * inode;

    va_start(args, fmt);
    count=vsprintf(logbuf, fmt, args);
    va_end(args);
/* 如果输出到 stdout 或 stderr，直接调用 sys_write 即可。 */
    if (fd < 3)
    {
        __asm__("push %%fs\n\t"
            "push %%ds\n\t"
            "pop %%fs\n\t"
            "pushl %0\n\t"
        /* 注意对于 Windows 环境来说，是 _logbuf,下同。 */
            "pushl $logbuf\n\t"
            "pushl %1\n\t"
        /* 注意对于 Windows 环境来说，是 _sys_write,下同。 */
            "call sys_write\n\t"
            "addl $8,%%esp\n\t"
            "popl %0\n\t"
            "pop %%fs"
            ::"r" (count),"r" (fd):"ax","cx","dx");
    }
    else
/* 假定 >= 3 的描述符都与文件关联。事实上，还存在很多其它情况，这里并没有考虑。 */
    {
    /* 从进程 0 的文件描述符表中得到文件句柄。 */
        if (!(file=task[0]->filp[fd]))
            return 0;
        inode=file->f_inode;

        __asm__("push %%fs\n\t"
            "push %%ds\n\t"
            "pop %%fs\n\t"
            "pushl %0\n\t"
            "pushl $logbuf\n\t"
            "pushl %1\n\t"
            "pushl %2\n\t"
            "call file_write\n\t"
            "addl $12,%%esp\n\t"
            "popl %0\n\t"
            "pop %%fs"
            ::"r" (count),"r" (file),"r" (inode):"ax","cx","dx");
    }
    return count;
}
```

因为和 `printk` 的功能近似，建议将此函数放入到 `kernel/printk.c` 中。`fprintk` 的使用方式类同与 C 标准库函数 `fprintf`，唯一的区别是第一个参数是文件描述符，而不是文件指针。

示例：

```c
/* 向 stdout 打印正在运行的进程的 ID */
fprintk(1, "The ID of running process is %ld", current->pid);

/* 向log文件输出跟踪进程运行轨迹。 */
fprintk(3, "%ld\t%c\t%ld\n", current->pid, 'R', jiffies);
```

***

### 2.3	修改内核文件以跟踪进程状态

进程五状态

| 状态 |        含义        |
| :--: | :----------------: |
| *N*  |   新建（*New*）    |
| *J*  | 就绪（*Jiuxu* ? ） |
| *R*  | 运行（*Running*）  |
| *W*  |   阻塞（*Wait*）   |
| *E*  |   退出（*Exit*）   |

#### 2.3.1	修改 *`kernel/fork.c`*

`fork.c` 创建新进程，所以这个文件可以记录 `N` 和 `J` 。真正实现创建进程的函数是 `copy_process()` 。 

首先在获得一个 `task_struct` 结构体空间，也就是新建进程，并在初始化 `PCB` 之后操作：

```C
/* 在 kernel/fork.c */

/* 在 copy_process() */
/* …… */
p->start_time = jiffies;
/* NULL => 新建 */
fprintk(3, "%ld\t%c\t%ld\n", p->pid, 'N', jiffies);
/* 下面为初始化 tss 为寄存器映像*/
p->tss.back_link = 0;
/* …… */
```

然后，在 `copy_process()` 的结尾，将子进程的状态设置为就绪，此时应该输出：

```C
/* 在 kernel/fork.c */

/* 在 copy_process() */
/* …… */
p->state = TASK_RUNNING;
/* 新建 => 就绪 */
fprintk(3, "%ld\t%c\t%ld\n", p->pid, 'J', jiffies);
return last_pid;
```

  注意 `copy_process()` 内部，`p->tss.eax = 0;` 因为系统调的返回值在 `%eax` 寄存器内，所以子进程 `fork()` 返回 `0` 。

***

#### 2.3.2	修改 *`kernel/sched.c`*

`kernel/sched.c` 为进程调度及睡眠唤醒的相关操作。

##### 2.3.2.1	`schedule()`

选择调度优先级最大的进程，并切换进程：

```C
/* 在 kernel/sched.c */

void schedule(void)
{
	int i, next, c;
	struct task_struct** p;

	for (p = &LAST_TASK; p > & FIRST_TASK; --p)
		if (*p) {
			/* …… */
			if (((*p)->signal & ~(_BLOCKABLE & (*p)->blocked)) &&
				(*p)->state == TASK_INTERRUPTIBLE){
                (*p)->state = TASK_RUNNING;
                /* 可中断睡眠 => 就绪 */
                fprintk(3,"%d\t%c\t%d\n",(*p)->pid,'J',jiffies);
            }	
		}
    
    /* 选择 next 作为被调度的进程 */
	while (1) {
		/* 调度算法 */
	}
    
    /* 编号为 next 的进程将运行 */
    /* 若本次调度的进程与进入 schedule() 的进程一致，则无需向 log 记录 */
	if (current->pid != task[next]->pid)
	{
		/* current 进程时间片到时 => 就绪 */
        /* 此时无需记录阻塞情况，因为该情况在进入 schedule() 前已处理 */
		if (current->state == TASK_RUNNING)
			fprintk(3, "%d\t%c\t%d\n", current->pid, 'J', jiffies);
		fprintk(3, "%d\t%c\t%d\n", task[next]->pid, 'R', jiffies);
	}
	switch_to(next);
}
```

***



##### 2.3.2.2	`sys_pause()`

分析 `init/main.c` 中的 `main()` ，在最后一行，若系统无任何额外的进程工作，则进程 `0` 会不断的调用 `pause()` 阻塞自己，也就是内核执行 `sys_pause()` 。所以当这种情况发生时，无需向 `log` 记录。

```C
/* 在 init/main.c */

void main(void)
{
    /* …… */
    move_to_user_mode();
	if (!fork()) {
		init();
	}
    for(;;) pause();
}
```

修改 `sys_pause()`

```C
/* 在 kernel/sched.c */

int sys_pause(void)
{
    current->state = TASK_INTERRUPTIBLE;
    /* 当前进程运行 => 可中断睡眠 */
    if(current->pid != 0)
        fprintk(3,"%d\t%c\t%d\n",current->pid,'W',jiffies);
    schedule();
    return 0;
}
```

***



##### 2.3.2.3	`sleep_on()`

`sleep_on` 执行非常隐蔽的队列，详细分析请见李治军老师课程 `18 信号量的代码实现` 。

```C
/* 在 kernel/sched.c */

void sleep_on(struct task_struct** p)
{
	struct task_struct* tmp;
	/* …… */
	tmp = *p;
	*p = current;
    /* 上面两句是很隐蔽的队列 */
	current->state = TASK_UNINTERRUPTIBLE;
    /* 当前进程运行 => 不可中断睡眠 */
    fprintk(3,"%d\t%c\t%d\n",current->pid,'W',jiffies);
	schedule();
	if (tmp){
        /* 将 tmp 所指的进程唤醒 */
        /* 原等待队列链的下一个睡眠进程 => 唤醒（就绪）*/
        tmp->state = TASK_RUNNING;
        fprintk(3,"%d\t%c\t%d\n",current->pid,'J',jiffies);
    }
}
```

***



##### 2.3.2.4	`interruptible_sleep_on()`

`interruptible_sleep_on()` 与 `sleep_on()` 类似。不同之处在于<u>只有在被唤醒进程与阻塞队列队首进程恰好相同时</u>，才可以将该进程变为就绪态。

```C 
/* 在 kernel/sched.c */

void interruptible_sleep_on(struct task_struct** p)
{
	struct task_struct* tmp;
	/* …… */
	tmp = *p;
	*p = current;

repeat:
	current->state = TASK_INTERRUPTIBLE;
   	/* 当前进程运行 => 可中断睡眠 */
    fprintk(3,"%d\t%c\t%d\n",current->pid,'W',jiffies);
	schedule();
	if (*p && *p != current) {
		(**p).state = TASK_RUNNING;
        /* 若被唤醒的进程不是阻塞队列队首进程，则将队首唤醒，并继续将当前进程阻塞 */
        fprintk(3,"%d\t%c\t%d\n",(*p)->pid,'J',jiffies);
		goto repeat;
	}

	*p = NULL;
	if (tmp){
        /* 作用与 sleep_on() 中一致 */
        tmp->state = TASK_RUNNING;
        fprintk(3,"%d\t%c\t%d\n",tmp->pid,'J',jiffies);
    }	
}
```

***



##### 2.3.2.5	`wake_up()`

`wake_up()` 负责将阻塞队列的队首进程唤醒，其余链上的阻塞进程由 `sleep_on()` 中程序唤醒。

```C
/* 在 kernel/sched.c */

void wake_up(struct task_struct** p)
{
    if (p && *p) {
        (**p).state = TASK_RUNNING;
        /* 将阻塞队列队首进程唤醒，变为就绪态 */
        fprintk(3, "%d\t%c\t%d\n", (*p)->pid, 'J', jiffies);
        *p = NULL;
    }
}
```

***

#### 2.3.3	修改 *`kernel/exit.c`*

`kernel/exit.c` 主要是进程退出及父进程等待的代码。文件内部函数的实现细节不用探究，只在进程状态发生转换的时候向 `log` 写入就好了。

##### 2.3.3.1	`do_exit()`

```C
/* 在 kernel/exit.c */

int do_exit(long code)
{
    /* …… */
	current->state = TASK_ZOMBIE;
    /* => 退出 */
	fprintk(3, "%ld\t%c\t%ld\n", current->pid, 'E', jiffies);
	
    current->exit_code = code;
	tell_father(current->father);
	schedule();
	return (-1);
}
```

***



##### 2.3.3.2	`sys_waitpid()`

```C
int sys_waitpid(pid_t pid, unsigned long* stat_addr, int options)
{
	int flag, code;
	struct task_struct** p;

	verify_area(stat_addr, 4);
repeat:
	flag = 0;
	for (p = &LAST_TASK; p > & FIRST_TASK; --p) {
        /* …… */
		switch ((*p)->state) {
		/* …… */
		default:
			flag = 1;
			continue;
		}
	}
	if (flag) {
        /* …… */
		current->state = TASK_INTERRUPTIBLE;
        /* 运行 => 可中断睡眠 */
		fprintk(3, "%ld\t%c\t%ld\n", current->pid, 'W', jiffies);
		schedule();
        /* …… */
	}
	/* …… */
}
```

***

### 2.4	编写 *`process.c`*

由于 `process.c` 运行在用户态，所以放在虚拟磁盘上。路径为 `hdc/usr/root/process.c` 。

`cpuio_bound()` 函数参数可以自己进行设置。

```c
/* 在 hdc/usr/root/process.c */

#include <stdio.h>
#include <unistd.h>
#include <time.h>
#include <sys/times.h>
#include <sys/types.h>

#define HZ	100
#define MAXSIZE 10
#define TIME    10
void cpuio_bound(int last, int cpu_time, int io_time);

int main(int argc, char* argv[])
{
	pid_t child_process[MAXSIZE];
	pid_t temp;
	int i = 0;

	/* 生成 10 个子进程 */
	for (; i != MAXSIZE; ++i) {
		temp = fork();
		if (!temp) {
            /* 进行 I/O 操作后，进程退出 */
			cpuio_bound(TIME, i, TIME - i);
			exit(0);
		}
		else if (temp < 0) {
			printf("Failed to fork child process %d \n", i + 1);
			exit(-1);
		}
		child_process[i] = temp;
	}
	for (i = 0; i != MAXSIZE; ++i)
		printf("Child PID: %d\n", child_process[i]);

	/* 父进程等待所有子进程退出 */
	wait(NULL);
	return 0;
}

void cpuio_bound(int last, int cpu_time, int io_time)
{
    /* 直接使用指导代码就可以，这里省略不再给出 */
}
```

在 `Linux 0.11` 的 `Shell` 中执行如下命令即可：

```shell
gcc -o process process.c 
sync
./process
```

***



## 注解

[1]	`open` 

|   *flag*   |              含义              |
| :--------: | :----------------------------: |
| *O_RDONLY* |          只读方式打开          |
| *O_WRONLY* |          只写方式打开          |
|  *O_RDWR*  |          读写方式打开          |
| *O_APPEND* |       追加内容至文件结尾       |
| *O_CREAT*  | 若指定文件不存在，则创建该文件 |
| *O_TRUNC*  | 若文件存在，则将其长度截断为 0 |

​     其他 `flag` 参见《UNIX 环境高级编程》。

|  *mode*   | 八进制值 |          含义          |
| :-------: | :------: | :--------------------: |
| *S_IRWXU* |   700    |   用户可读可写可执行   |
| *S_IRUSR* |   400    |        用户可读        |
| *S_IWUSR* |   200    |        用户可写        |
| *S_IXUSR* |   100    |       用户可执行       |
| *S_IRWXG* |   070    |  用户组可读可写可执行  |
| *S_IRGRP* |   040    |       用户组可读       |
| *S_IWGRP* |   020    |       用户组可写       |
| *S_IXGRP* |   010    |      用户组可执行      |
| *S_IRWXO* |   007    | 其他用户可读可写可执行 |
| *S_IROTH* |   004    |      其他用户可读      |
| *S_IWOTH* |   002    |      其他用户可写      |
| *S_IXOTH* |   001    |     其他用户可执行     |

所以：

```c
/* 在 init/main.c */

/* 
 * 表示以只写方式创建 /var/process.log，若文件已存在，则长度截断为 0
 * 当数字为八进制数时，需加前导 0 
 * 0666，表示文件权限为用户可读可写、用户组可读可写、其他用户可读可写 
 */
(void) open("/var/process.log",O_CREAT|O_TRUNC|O_WRONLY,0666);
```



