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

