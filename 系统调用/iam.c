#define __LIBRARY__
#include<unistd.h>

/*  将字符串 name 拷贝到内核中保存下来 */
_syscall1(int,iam,const char*,name)

int main(int argc,char* argv[])
{
    iam(argv[1]);
    return 0;
}
