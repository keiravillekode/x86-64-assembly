;
; Calculate the Hamming difference between two DNA strands.
;
; Parameters:
;   rdi - strand1
;   rsi - strand2
; Returns:
;   rax - count of mismatches, or -1 if the strands are different lengths.
;
; Implementation note: AVX-512 processes 64 bytes per iteration.
;   vpcmpeqb against zero locates the null terminator in each strand.
;   vpcmpneqb yields a 64-bit mask of byte mismatches; popcnt counts them.
;   If only one strand terminates inside a chunk (or both terminate at
;   different positions) the strands have different lengths and we return -1.
;
section .text
global distance
distance:
    xor eax, eax                   ; running mismatch count
    vpxord zmm2, zmm2, zmm2        ; zero vector for null detection

.loop:
    vmovdqu8 zmm0, [rdi]           ; 64 bytes of strand1
    vmovdqu8 zmm1, [rsi]           ; 64 bytes of strand2
    vpcmpeqb k1, zmm0, zmm2        ; k1[i] = 1 where strand1[i] == 0
    vpcmpeqb k2, zmm1, zmm2        ; k2[i] = 1 where strand2[i] == 0
    kortestq k1, k2                ; any null in either chunk?
    jnz .tail                      ; yes → this is the last chunk

    vpcmpneqb k3, zmm0, zmm1       ; 64-bit mismatch mask
    kmovq rdx, k3
    popcnt rdx, rdx
    add rax, rdx
    add rdi, 64
    add rsi, 64
    jmp .loop

.tail:
    kmovq r8, k1
    kmovq r9, k2
    tzcnt r8, r8                   ; first null position in strand1 (64 if none)
    tzcnt r9, r9                   ; first null position in strand2
    cmp r8, r9
    jne .unequal_length            ; lengths differ → report error

    vpcmpneqb k3, zmm0, zmm1
    kmovq rdx, k3
    bzhi rdx, rdx, r8              ; keep only bits below the null position
    popcnt rdx, rdx
    add rax, rdx
    vzeroupper
    ret

.unequal_length:
    mov eax, -1
    vzeroupper
    ret

%ifidn __OUTPUT_FORMAT__,elf64
section .note.GNU-stack noalloc noexec nowrite progbits
%endif
