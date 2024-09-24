

```asm
section .text
global egg_count
egg_count:
    xor rax, rax
    test rdi, rdi
    jz .return

.repeat:
    inc rax
    mov r8, rdi
    neg r8
    and r8, rdi
    xor rdi, r8
    test rdi, rdi
    jnz .repeat

.return:
    ret

%ifidn __OUTPUT_FORMAT__,elf64
section .note.GNU-stack noalloc noexec nowrite progbits
%endif
```
