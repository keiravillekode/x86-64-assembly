;
; Apply a Caesar (rotational) cipher to text, preserving case and
; leaving non-letters unchanged.
;
; Parameters:
;   rdi - text (null-terminated)
;   esi - shift_key (int, any integer)
;   rdx - buffer (at least strlen(text)+1 bytes)
;
; Implementation note: AVX-512 mask registers serve as per-byte predicates.
;   (c - 'a') < 26 identifies lowercase positions (k_lower),
;   (c - 'A') < 26 identifies uppercase positions (k_upper).
;   The shift is added under the combined letter mask. For lowercase bytes
;   that overflowed past 'z' (and uppercase that overflowed past 'Z') we
;   subtract 26 under a narrower wrap mask. shift_key is normalized modulo
;   26 first, so shift values of 26, -1, etc. behave correctly.
;
section .text
global rotate
rotate:
    mov r8, rdx                    ; save output pointer before idiv clobbers rdx

    ; Normalize shift_key to [0, 25].
    mov eax, esi
    cdq
    mov ecx, 26
    idiv ecx                       ; edx = shift_key mod 26 (sign of dividend)
    test edx, edx
    jns .shift_ok
    add edx, 26
.shift_ok:
    vpbroadcastb zmm5, edx         ; shift
    mov eax, 'a'
    vpbroadcastb zmm6, eax
    mov eax, 'A'
    vpbroadcastb zmm7, eax
    mov eax, 26
    vpbroadcastb zmm8, eax
    mov eax, 'z'
    vpbroadcastb zmm9, eax
    mov eax, 'Z'
    vpbroadcastb zmm10, eax
    vpxord zmm11, zmm11, zmm11

.loop:
    vmovdqu8 zmm0, [rdi]

    vpsubb zmm2, zmm0, zmm6
    vpcmpub k1, zmm2, zmm8, 1      ; (c - 'a') < 26 → lowercase
    vpsubb zmm3, zmm0, zmm7
    vpcmpub k2, zmm3, zmm8, 1      ; (c - 'A') < 26 → uppercase
    korq k3, k1, k2                ; any letter

    vmovdqa64 zmm1, zmm0
    vpaddb zmm1 {k3}, zmm0, zmm5   ; add shift where the byte is a letter

    vpcmpub k4 {k1}, zmm1, zmm9, 6 ; lowercase and now > 'z' → wrapped
    vpsubb zmm1 {k4}, zmm1, zmm8
    vpcmpub k5 {k2}, zmm1, zmm10, 6; uppercase and now > 'Z' → wrapped
    vpsubb zmm1 {k5}, zmm1, zmm8

    vpcmpeqb k6, zmm0, zmm11       ; null terminator in input chunk?
    kortestq k6, k6
    jnz .final

    vmovdqu8 [r8], zmm1
    add rdi, 64
    add r8, 64
    jmp .loop

.final:
    kmovq rcx, k6
    tzcnt rcx, rcx
    inc rcx                        ; include the null position
    mov rax, -1
    bzhi rax, rax, rcx
    kmovq k7, rax
    vmovdqu8 [r8] {k7}, zmm1
    vzeroupper
    ret

%ifidn __OUTPUT_FORMAT__,elf64
section .note.GNU-stack noalloc noexec nowrite progbits
%endif
