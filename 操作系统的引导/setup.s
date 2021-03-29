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