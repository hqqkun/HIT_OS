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
