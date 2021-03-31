#include <stdio.h>
#include <unistd.h>
#include <time.h>
#include <sys/times.h>
#include <sys/types.h>

#define HZ	100
#define MAXSIZE 10
#define TIME    10
void cpuio_bound(int last, int cpu_time, int io_time);

int main(int argc, char * argv[])
{
    pid_t child_process[MAXSIZE];
    pid_t temp;
    int i = 0;

    /* 生成 10 个子进程 */
    for(;i != MAXSIZE;++i){
        temp = fork();
        if(!temp){
	    /* 进行 I/O 操作后，进程退出 */
            cpuio_bound(TIME,i,TIME-i);
            exit(0);
        }
        else if(temp < 0 ){
            printf("Failed to fork child process %d \n",i+1);
            exit(-1);
        }
        child_process[i] = temp;
    }
    for(i = 0;i != MAXSIZE;++i)
        printf("Child PID: %d\n",child_process[i]);

    /* 父进程等待所有子进程退出 */
    wait(NULL);

    return 0;
}

/*
 * 此函数按照参数占用CPU和I/O时间
 * last: 函数实际占用CPU和I/O的总时间，不含在就绪队列中的时间，>=0是必须的
 * cpu_time: 一次连续占用CPU的时间，>=0是必须的
 * io_time: 一次I/O消耗的时间，>=0是必须的
 * 如果last > cpu_time + io_time，则往复多次占用CPU和I/O
 * 所有时间的单位为秒
 */
void cpuio_bound(int last, int cpu_time, int io_time)
{
	struct tms start_time, current_time;
	clock_t utime, stime;
	int sleep_time;

	while (last > 0)
	{
		/* CPU Burst */
		times(&start_time);
		/* 其实只有t.tms_utime才是真正的CPU时间。但我们是在模拟一个
		 * 只在用户状态运行的CPU大户，就像“for(;;);”。所以把t.tms_stime
		 * 加上很合理。*/
		do
		{
			times(&current_time);
			utime = current_time.tms_utime - start_time.tms_utime;
			stime = current_time.tms_stime - start_time.tms_stime;
		} while ( ( (utime + stime) / HZ )  < cpu_time );
		last -= cpu_time;

		if (last <= 0 )
			break;

		/* IO Burst */
		/* 用sleep(1)模拟1秒钟的I/O操作 */
		sleep_time=0;
		while (sleep_time < io_time)
		{
			sleep(1);
			sleep_time++;
		}
		last -= sleep_time;
	}
}

