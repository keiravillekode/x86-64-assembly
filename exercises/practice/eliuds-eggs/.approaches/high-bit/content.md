

```asm
section .text
global egg_count
egg_count:
    mov rax, 0
    mov rcx, 64
    mov r8, 0

.body:
    shl rdi, 1
    adc rax, r8
    loop .body

    ret

%ifidn __OUTPUT_FORMAT__,elf64
section .note.GNU-stack noalloc noexec nowrite progbits
%endif
```
