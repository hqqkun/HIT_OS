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