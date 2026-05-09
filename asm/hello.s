format ELF64 executable 3

entry _start

segment readable executable

_start:
    ; write(1, msg, msg_len)
    mov rax, 1          ; syscall: sys_write
    mov rdi, 1          ; file descriptor: stdout
    mov rsi, msg        ; buffer: address of msg
    mov rdx, msg_len    ; count: length of msg
    syscall

    ; exit(0)
    mov rax, 60         ; syscall: sys_exit
    xor rdi, rdi        ; status: 0
    syscall

segment readable writeable

msg db "Hello, World!", 10
msg_len = $ - msg
