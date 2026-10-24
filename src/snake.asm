[org 0x7c00]
bits 16

start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00

    mov si, msg
.print:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0e        ; BIOS teletype output
    int 0x10
    jmp .print

.done:
    cli
    hlt
    jmp .done

msg db "Snake boot OK", 0

times 510 - ($ - $$) db 0   ; pad to 510 bytes
dw 0xAA55                   ; boot signature