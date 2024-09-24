

```asm
section .text
global egg_count
egg_count:
    xor rax, rax
    jmp .while

.do:
    mov r8, rax
    inc r8
    test rdi, 1
    cmovnz rax, r8
    shr rdi, 1

.while:
    test rdi, rdi
    jnz .do

    ret

%ifidn __OUTPUT_FORMAT__,elf64
section .note.GNU-stack noalloc noexec nowrite progbits
%endif
```
