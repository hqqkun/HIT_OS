



# Linux 0.11 Labs

哈尔滨工业大学，李治军老师操作系统实验环境及相关 Lab 答案与解析。

## 课程平台

1）教学平台

[中国大学 MOOC ](https://www.icourse163.org/course/HIT-1002531008)

2）实验平台

[操作系统原理与实践 Linux](https://www.lanqiao.cn/courses/115)

## 实验进度

- [x] 操作系统的引导
- [x] 系统调用
- [x] 进程运行轨迹的跟踪与统计
- [ ] 基于内核栈切换的进程切换



## 实验环境搭建

### 平台

`ubuntu-18.04.5`

[Ubuntu 官网最新版](https://ubuntu.com/download/desktop)

[Ubuntu 镜像下载](https://launchpad.net/ubuntu/+cdmirrors)

### 安装编译环境

1）安装 `gcc 3.4` （在 `Resources` 文件夹内）

当前 `gcc` 版本过高，无法编译 `Linux 0.11` ，故只能使用 `gcc 3.4` 。

```shell
# '#' 为注释

tar -zxvf gcc-3.4.tar.gz
cd gcc-3.4
cd amd64                # 若系统为 64 位则进入 amd64，否则进入 i386
sudo dpkg -i *.deb      # 安装所有包
```

2）安装依赖库

```shell
sudo apt install bin86			# 用以下载 8086 编译器和链接器 as86 和 ld86 
sudo apt install libc6-dev-i386		# 下载 32 位兼容库
sudo apt install libsm6:i386		# 以下三项为 bochs 依赖库
sudo apt install libx11-6:i386
sudo apt install libxpm4:i386
```



### 解压、编译并运行 Linux 0.11

1）解压 `Linux 0.11` 包（在 `Resources`文件夹内）

```shell
tar -zxvf hit-oslab-linux-20110823.tar.gz
```

2）编译运行

假设已进入 `oslab` 文件夹。  

```shell
cd ./linux-0.11
make clean
make 
../run
```

### 加载或卸载虚拟磁盘 `hdc`

假设已进入 `oslab` 文件夹。

1）加载

```shell
sudo ./mount-hdc
```

2）卸载

```shell
sudo umount hdc
```



