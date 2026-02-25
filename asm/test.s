use64

SYS_write equ 1
STDOUT equ 1

puts:
    mov r8, rdi ; save pointer to string
    call strlen
    mov rdx, rax ; length of string
    mov rsi, r8 ; restore pointer to string
    mov rdi, STDOUT
    mov rax, SYS_write
    syscall
ret

; strlen
; in:
;   rdi: pointer to string
;
; out:
;   rax: length of string (not including null terminator)
strlen:
    xor rax, rax
.loop:
    cmp byte [rdi], 0
    je .done
    inc rax
    inc rdi
    jmp .loop
.done:
ret
