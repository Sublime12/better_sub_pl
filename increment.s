.intel_syntax noprefix
.global _start

.text
_start:
    push rbp
    mov rbp, rsp
    sub rsp, 16

    mov byte ptr [rbp - 1], 'a'
    mov byte ptr [rbp - 3], 5

    movzx eax, byte ptr [rbp - 1]
    movzx ecx, byte ptr [rbp - 3]

    add eax, ecx

    mov byte ptr [rbp - 1], al

    mov eax, 1
    mov edi, 1
    lea rsi, [rbp - 1]
    mov edx, 1
    syscall

    mov eax, 60
    xor edi, edi
    syscall
