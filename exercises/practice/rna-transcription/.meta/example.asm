;
; Transcribe a DNA strand to its RNA complement (A→U, C→G, G→C, T→A).
;
; Parameters:
;   rdi - strand (null-terminated)
;   rsi - buffer (at least strlen(strand)+1 bytes)
;
; Implementation note: the ASCII low nibbles of A, C, T, G are 1, 3, 4, 7
;   and are all distinct. This lets us perform the whole transcription
;   as a 16-entry lookup: vpshufb maps each byte through a per-lane LUT
;   indexed by (byte & 0x0F). Broadcasting the same 16-byte table across
;   all four 128-bit lanes of a zmm register gives us 64 parallel lookups
;   per iteration. Bytes up to and including the null terminator are
;   written to the buffer via a masked store.
;
default rel

section .rodata
rna_lut_64:
    ; Low-nibble-indexed table: A→'U', C→'G', T→'A', G→'C'. Other indices
    ; (including 0 from a null byte) produce 0. The same 16 bytes are
    ; repeated across the four 128-bit lanes so a single vpshufb handles
    ; every byte in the zmm register.
    db 0,'U',0,'G','A',0,0,'C',0,0,0,0,0,0,0,0
    db 0,'U',0,'G','A',0,0,'C',0,0,0,0,0,0,0,0
    db 0,'U',0,'G','A',0,0,'C',0,0,0,0,0,0,0,0
    db 0,'U',0,'G','A',0,0,'C',0,0,0,0,0,0,0,0

section .text
global to_rna
to_rna:
    vpxord zmm3, zmm3, zmm3
    vmovdqu8 zmm2, [rna_lut_64]

.loop:
    vmovdqu8 zmm0, [rdi]
    vpshufb zmm1, zmm2, zmm0       ; per-byte lookup via low nibble
    vpcmpeqb k1, zmm0, zmm3        ; null positions in input
    kortestq k1, k1
    jnz .final                     ; chunk contains the terminator

    vmovdqu8 [rsi], zmm1
    add rdi, 64
    add rsi, 64
    jmp .loop

.final:
    kmovq rcx, k1
    tzcnt rcx, rcx
    inc rcx                        ; include the null position
    mov rax, -1
    bzhi rax, rax, rcx
    kmovq k2, rax
    vmovdqu8 [rsi] {k2}, zmm1      ; writes zmm1[rcx] = 0 as the terminator
    vzeroupper
    ret

%ifidn __OUTPUT_FORMAT__,elf64
section .note.GNU-stack noalloc noexec nowrite progbits
%endif
