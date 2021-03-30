# 操作系统的引导

## 1	前言

`x86 PC` 机刚开机时，CPU 处于 `8086` 实模式，`cs`、`ip` 寄存器被分别初始化为 *`0xFFFF`*，*`0x0000`*，为 `ROM BIOS` 映射区。该程序检查 RAM、键盘、显示器、软硬盘及其他设备，随后将磁盘的 `0` 磁道 `1` 扇区（操作系统引导扇区）读入内存 *`0x7C00`* <sup>[1]</sup>处。



## 2	实验内容

### 2.1	改写 Linux 引导程序 *`boot/bootsect.s`*

要求在屏幕上打印一段提示信息。

2.1 使用 `BIOS 0x10` 中断

|     功能     | 子程序编号 |                             参数                             |                          返回值                          |
| :----------: | :--------: | :----------------------------------------------------------: | :------------------------------------------------------: |
| 读取光标位置 | AH = 0x03  |                          BH = 页号                           | AX = 0，CH = 光标开始行，CL = 光标结束行，DH = 行，DL=列 |
|  显示字符串  |  AH= 0x13  | AL = 写模式，BH = 页号，BL = 显示颜色，CX = 串长度，DH = 行，DL = 列，ES:BP = 字符串起始地址 |                            无                            |

```assembly
! 修改 boot/bootsect.s

entry _start
_start:

! 打印信息
	mov	ah,#0x03		! 读取光标位置
	xor	bh,bh
	int	0x10
	
	mov	cx,#25			
	mov	bx,#0x0007		! 显示在第 0 页，字符显示亮灰色
	mov	ax,#0x07C0
	mov	es,ax		
	mov	bp,#msg1		! 获取字符串起始地址
	mov	ax,#0x1301		! 显示字符串，光标跟随移动
	int	0x10

inf_loop:
	jmp inf_loop		! for(;;)
	
msg1:
	.byte 13,10			! .byte 13,10 == '\r','\n',回车并换行
	.ascii "HanOS is loading now!"
	.byte 13,10
	
.org 510				! Bootsect.s 必须为 512B，在 510B 处放置魔数
boot_flag:
	.word 0xAA55		! 字，为 0xAA55
```

由于历史原因，磁盘扇区大小为 `512B`，最后两个字节为 `0x55`，`0xAA`，作为 `MBR`（Master Boot Record，主引导记录）的结束标志，因 `IA-32` 架构采用小端模式，所以程序内为 `0xAA55`。

***



### 2.2	改写启动程序

1）`bootsect.s` 能完成 `setup.s` 的载入，并跳转到 `setup.s` 开始地址执行。而 `setup.s` 向屏幕输出一行 `"Now we are in SETUP"`。

2）`setup.s` 读取基本的硬件参数（如内存参数、显卡参数、硬盘参数等），将其存放在内存的特定地址，并输出到屏幕上。

3）`setup.s` 无需加载 `Linux` 内核。

| 中断号 |       功能       | 子程序编号 |                             参数                             |                        返回值                        |
| :----: | :--------------: | :--------: | :----------------------------------------------------------: | :--------------------------------------------------: |
|  0x10  |   显示一个字符   | AH = 0x0E  |        AL = 字符的 ASCII 码，BH = 页号，BL = 显示颜色        |                          无                          |
|  0x13  |      读扇区      | AH = 0x02  | AL = 读取扇区数，CH = 柱面，CL = 起始扇区，DH= 磁头，DL = 驱动器，ES:BX = 内存缓冲区地址 | CF = 0 -> 操作成功，AH = 返回码，AL = 实际读入扇区数 |
|  0x13  |   磁盘系统复位   | AH = 0x00  |                         DL = 驱动器                          |           CF = 1 -> 复位错误，AH = 返回码            |
|  0x15  | 读取扩展内存容量 | AH = 0x88  |                              无                              |           AX = 扩展内存字节数（单位为 KB）           |

#### 2.2.1	再修改 *`boot/bootsect.s`*

```assembly
! 修改 boot/bootsect.s
SETUPLEN = 1
SETUPSEG = 0x07E0

entry _start
_start:
!------------------------------------------
! 与 2.1 相同
! 打印信息
	mov	ah,#0x03		
	xor	bh,bh
	int	0x10
	
	mov	cx,#25			
	mov	bx,#0x0007		
	mov	ax,#0x07C0
	mov	es,ax		
	mov	bp,#msg1		
	mov	ax,#0x1301		
	int	0x10
!------------------------------------------

! 加载 setup
load_SETUP:
	mov dx,#0x0000		! 从软盘 0 的磁头 0 读入
	mov cx,#0x0002		! 从 2 扇区开始读，1 扇区为 MBR 
	mov bx,#0x0200		! 写入 0x07E0 内存地址
	mov ax,#0x0200 + SETUPLEN	! 读入 SETUPLEN 个扇区
	int 0x13
	jnc ok_load_SETUP	! 若 CF 为 0，则跳转到 ok_load_SETUP
	
	mov dx,#0x0000
	mov ax,dx
	int 0x13			! 读入不成功则复位，并再一次读取 setup
	jmp load_SETUP

ok_load_SETUP:
	jmpi 0,SETUPSEG		! 因无指令直接操纵 cs 寄存器，需使用间接跳转指令 jmpi
						! ip <- 0,cs <- SETUPSEG，程序转入 0x07E0 继续执行
	
!------------------------------------------
! 与 2.1 相同
msg1:
	.byte 13,10			
	.ascii "HanOS is loading now!"
	.byte 13,10
	
.org 510				
boot_flag:
	.word 0xAA55		
!------------------------------------------  
```

#### 2.2.2	改写 *`boot/setup.s`*

 `BIOS` 中断向量表中 `int 0x41` 的中断向量位置 （`4 * 0x41 = 0x0000:0x0104`） 存放的不是中断程序的入口地址，而是第一个硬盘的基本参数表。其长度为 `16B`，具体信息如下：

| 位移 | 大小 |     说明     |
| :--: | :--: | :----------: |
| 0x00 |  字  |    柱面数    |
| 0x02 | 字节 |    磁头数    |
| ...  | ...  |     ...      |
| 0x0E | 字节 | 每磁道扇区数 |
| 0x0F | 字节 |     保留     |


```assembly
! 修改 boot/setup.s

INITSEG = 0x9000
entry _start
_start:

! 初始化 ss:sp，即栈
	mov ax,#INITSEG
	mov ss,ax
	mov sp,#0xff00
	
! 向用户打印信息
	mov cx,#23
	mov bp,#msg_to_user
	call print_message
!-----------------------------------
! 从内存读取信息
! 将光标读入 0x90000
	mov ax,#INITSEG
	mov ds,ax
	xor bh,bh
	mov ah,#0x03
	int 0x10
	mov [0],dx

! 将扩展内存大小读入 0x90002
	mov ah,#0x88
	int 0x15
	mov [2],ax

! 将硬盘参数表读入 0x90004
! 硬件参数表放在 int 0x41 入口地址处
	mov ax,#0x0000
	mov ds,ax
	mov ax,#INITSEG
	mov es,ax
	mov di,#0x0004
	lds si,[0x41 << 2]
	mov cx,#0x10	! 拷贝 16B
	rep
	movsb			! 从 ds:si 拷贝到 es:di
!-------------------------------------

!-------------------------------------
! 准备打印数据
	mov ax,cs
	mov es,ax		! es = 0x07E0
	mov ax,#INITSEG
	mov ds,ax		! ds = 0x9000
	
! 打印光标位置
	mov cx,#18
	mov bp,#msg_cursor
	call print_message
	mov dx,[0]
	call print_hex

! 打印内存大小
	mov cx,#14
	mov bp,#msg_memory
	call print_message
	mov dx,[2]
	call print_hex

! 在内存大小之后添加 "KB"
	mov cx,#2
	mov bp,#msg_kB
	call print_message

! 打印柱面数
	mov cx,#8
	mov bp,#msg_cyles
	call print_message
	mov dx,[4]
	call print_hex

! 打印磁头数
	mov cx,#8
	mov bp,#msg_heads
	call print_message
	mov dx,[6]
	call print_hex

! 打印每磁道扇区数
	mov cx,#10
	mov bp,#msg_sectors
	call print_message
	mov dx,[0x12]
	call print_hex


inf_loop:
	jmp inf_loop

!---------------------------------------------------
! setup.s 所用函数
print_message:
! 在屏幕上显示字符串，（在函数内实现读取光标）
! 参数：cx = 长度, bp = 地址 
	push cx
	mov	ah,#0x03		! 读取光标位置
	xor	bh,bh
	int	0x10
	pop cx
	mov	bx,#0x0007		! 显示在第 0 页，字符显示亮灰色
	mov	ax,#0x07E0
	mov	es,ax			! 字符显示地址为 es:bp
	mov	ax,#0x1301		! 显示字符串，光标跟随移动
	int	0x10
	ret

print_hex:
! 将 16 位数据打印为十六进制数
! 参数：dx = 数据
	mov cx,#0x4			! 16 位数据，每次 4 位，则循环 4 次
print_digit:
	rol dx,#0x4			! 循环右移 4 位
	mov ax,#0x0e0f		! AH = 0x0E，AL 为掩码
	and al,dl
	add al,#0x30
	cmp al,#0x3a		
	jl out_char			! 若数字为 0 ~ 9，则打印 
	add al,#0x07		! 若数字为 A ~ F，则加 7 转化为字符 A ~ F 

out_char:
	int 0x10			! 打印字符
	loop print_digit
	ret
!---------------------------------------------------
! 字符串常量
msg_to_user:
	.byte 13,10
	.ascii "Now we are in SETUP"
	.byte 13,10
msg_cursor:
	.byte 13,10
	.ascii "Cursor Position:"
msg_memory:
	.byte 13,10
	.ascii "Memory Size:"
msg_cyles:
	.byte 13,10
	.ascii "Cyles:"
msg_heads:
	.byte 13,10
	.ascii "Heads:"
msg_sectors:
	.byte 13,10
	.ascii "Sectors:"
msg_kB:
	.ascii "KB"
!---------------------------------------------------------
```

***



# 注解

[1]	`IBM PC 5150 BIOS` 的开发团队决定使用 `0x7C00`，并不是 `8086` 的制造商 `Intel` 或者微软。该团队成员 Dr. David Bradley 曾说：

> ”DOS 1.0 要求最小 32KB 内存，所以我们不打算尝试在 16KB 内存上的启动。“

该团队决定将 `MBR`（引导扇区） 放置在 `0x7C00` 处的原因为：

	1）他们需要在 32KiB 的内存里，留出足够大的空间用以加载操作系统。
	
	2）8086/8088 的中断向量使用 0x000 ~ 0x3FF，随后是 BIOS 数据。
	
	3）MBR 为 512B，启动程序的栈需要大概 512B 空间。

所以他们选择了 `0x7C00`，也就是 `32KiB` 最后的 `1024B`。虽然时至今日内存容量早已远超 `32KB`，但 `0x7C00` 的传统保留了下来。
