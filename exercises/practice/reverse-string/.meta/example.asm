;
; Reverse a string in place.
;
; Parameters:
;   rdi - str (null-terminated, modified in place)
;
; Implementation note: for strings up to 64 bytes the whole reversal is
;   a single vpermb. The base index vector [63, 62, ..., 1, 0] is shifted
;   by (64 - len) so that position i takes src[len-1-i] for i < len.
;   A masked load/store safely handles the bytes beyond the string end.
;   Longer strings fall back to a scalar two-pointer swap.
;
default rel

section .rodata
rev_idx:
    db 63,62,61,60,59,58,57,56,55,54,53,52,51,50,49,48
    db 47,46,45,44,43,42,41,40,39,38,37,36,35,34,33,32
    db 31,30,29,28,27,26,25,24,23,22,21,20,19,18,17,16
    db 15,14,13,12,11,10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0

section .text
global reverse
reverse:
    mov rax, rdi
.strlen:
    cmp byte [rax], 0
    je .strlen_done
    inc rax
    jmp .strlen
.strlen_done:
    sub rax, rdi                   ; rax = string length

    cmp rax, 1
    jbe .ret                       ; length 0 or 1: nothing to do

    cmp rax, 64
    ja .scalar                     ; fall back for longer strings

    ; One-shot AVX-512 reversal.
    mov rcx, -1
    bzhi rcx, rcx, rax             ; mask of first `length` bits
    kmovq k1, rcx

    vmovdqu8 zmm0 {k1}{z}, [rdi]   ; masked load suppresses faults past the end

    mov rdx, 64
    sub rdx, rax                   ; 64 - length
    vpbroadcastb zmm2, edx
    vmovdqu8 zmm1, [rev_idx]
    vpsubb zmm1, zmm1, zmm2        ; idx[i] = length-1-i for i < length

    vpermb zmm0, zmm1, zmm0
    vmovdqu8 [rdi] {k1}, zmm0

    vzeroupper
.ret:
    ret

.scalar:
    lea rdx, [rdi + rax - 1]       ; end pointer
    mov rcx, rdi                   ; start pointer
.swap:
    cmp rcx, rdx
    jae .ret
    mov al, [rcx]
    mov r8b, [rdx]
    mov [rcx], r8b
    mov [rdx], al
    inc rcx
    dec rdx
    jmp .swap

%ifidn __OUTPUT_FORMAT__,elf64
section .note.GNU-stack noalloc noexec nowrite progbits
%endif
