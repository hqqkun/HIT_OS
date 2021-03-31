



## Linux 0.11 Labs

哈尔滨工业大学，李治军老师操作系统实验环境及相关 Lab 答案与解析。

## 课程实验平台

[操作系统原理与实践_Linux - 蓝桥云课 (lanqiao.cn)](https://www.lanqiao.cn/courses/115)

## 实验进度

- [x] 操作系统的引导
- [x] 系统调用
- [x] 进程运行轨迹的跟踪与统计
- [ ] 基于内核栈切换的进程切换



## 编译并运行 Linux 0.11

假设已进入 `oslab` 文件夹。  
以下均为 shell 命令行。

```shell
cd ./linux-0.11
make clean
make 
../run
```

## 载入或卸载虚拟磁盘 `hdc`

假设已进入 `oslab` 文件夹。

1）载入

```shell
sudo ./mount-hdc
```

2）卸载

```shell
sudo umount hdc
```




