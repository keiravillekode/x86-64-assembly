;
; Count the occurrences of each nucleotide in a DNA strand.
;
; Parameters:
;   rdi - strand
;   rsi - counts array ([A, C, G, T] as int64_t x 4)
; On invalid input (a character that isn't A, C, G or T) all four counts
; are set to -1.
;
; Implementation note: AVX-512 processes 64 bytes per iteration.
;   Each chunk is compared against four broadcast nucleotide values plus
;   zero, yielding five 64-bit mask registers. popcnt of each of the four
;   nucleotide masks — restricted to bits below the null terminator —
;   accumulates per-letter totals. If any byte before the null belongs to
;   none of the five categories, the strand is invalid.
;
section .text
global nucleotide_counts
nucleotide_counts:
    xor r8d, r8d                   ; A count
    xor r9d, r9d                   ; C count
    xor r10d, r10d                 ; G count
    xor r11d, r11d                 ; T count

    vpxord zmm5, zmm5, zmm5        ; zero, for null detection
    mov eax, 'A'
    vpbroadcastb zmm1, eax
    mov eax, 'C'
    vpbroadcastb zmm2, eax
    mov eax, 'G'
    vpbroadcastb zmm3, eax
    mov eax, 'T'
    vpbroadcastb zmm4, eax

.loop:
    vmovdqu8 zmm0, [rdi]
    vpcmpeqb k6, zmm0, zmm5        ; nulls
    vpcmpeqb k1, zmm0, zmm1        ; A
    vpcmpeqb k2, zmm0, zmm2        ; C
    vpcmpeqb k3, zmm0, zmm3        ; G
    vpcmpeqb k4, zmm0, zmm4        ; T

    kmovq rcx, k6
    tzcnt rcx, rcx                 ; first null position (64 if none)

    ; Detect any byte that's neither a nucleotide nor a null, before the null.
    korq k7, k1, k2
    korq k7, k7, k3
    korq k7, k7, k4
    korq k7, k7, k6
    kmovq rax, k7
    not rax                        ; 1 where byte is "other"
    bzhi rax, rax, rcx             ; restrict to bits below the null
    test rax, rax
    jnz .invalid

    kmovq rdx, k1
    bzhi rdx, rdx, rcx
    popcnt rdx, rdx
    add r8, rdx

    kmovq rdx, k2
    bzhi rdx, rdx, rcx
    popcnt rdx, rdx
    add r9, rdx

    kmovq rdx, k3
    bzhi rdx, rdx, rcx
    popcnt rdx, rdx
    add r10, rdx

    kmovq rdx, k4
    bzhi rdx, rdx, rcx
    popcnt rdx, rdx
    add r11, rdx

    cmp rcx, 64
    je .advance
    jmp .report

.advance:
    add rdi, 64
    jmp .loop

.invalid:
    mov r8, -1
    mov r9, -1
    mov r10, -1
    mov r11, -1

.report:
    mov [rsi], r8
    mov [rsi+8], r9
    mov [rsi+16], r10
    mov [rsi+24], r11
    vzeroupper
    ret

%ifidn __OUTPUT_FORMAT__,elf64
section .note.GNU-stack noalloc noexec nowrite progbits
%endif
