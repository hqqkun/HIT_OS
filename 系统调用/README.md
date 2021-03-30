# 系统调用

## 1	前言

## 2	实验内容

在 Linux 0.11 上添加两个系统调用，并编写两个简单的应用程序测试它们。

#### （1）`iam()`

第一个系统调用是 iam()，其原型为：

```c
int iam(const char * name);
```

完成的功能是将字符串参数 `name` 的内容拷贝到内核中保存下来。要求 `name` 的长度不能超过 23 个字符。返回值是拷贝的字符数。如果 `name` 的字符个数超过了 23，则返回 “-1”，并置 errno 为 EINVAL。

在 `kernal/who.c` 中实现此系统调用。

#### （2）`whoami()`

第二个系统调用是 whoami()，其原型为：

```c
int whoami(char* name, unsigned int size);
```

它将内核中由 `iam()` 保存的名字拷贝到 name 指向的用户地址空间中，同时确保不会对 `name` 越界访存（`name` 的大小由 `size` 说明）。返回值是拷贝的字符数。如果 `size` 小于需要的空间，则返回“-1”，并置 errno 为 EINVAL。

也是在 `kernal/who.c` 中实现。