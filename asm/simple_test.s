use64

SYS_write equ 1
STDOUT equ 1

; expect buf, count
; rdi, rsi
mov rdx, rsi
mov rsi, rdi
mov rdi, STDOUT
mov rax, SYS_write
syscall
ret
