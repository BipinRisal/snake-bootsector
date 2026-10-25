[org 0x7c00]
bits 16

start:
    xor ax, ax
    mov ds, ax
    mov ss, ax
    mov sp, 0x7c00

    ; 80x25 text mode, hide cursor
    mov ax, 0x0003
    int 0x10
    mov ah, 0x01
    mov cx, 0x2000
    int 0x10

    ; es points at video memory
    mov ax, 0xb800
    mov es, ax

    ; head position on a 40x25 grid
    mov bl, 20              ; x (0 to 39)
    mov bh, 12              ; y (0 to 24)

game_loop:
    mov ax, 0x0020          ; black cell
    call plot               ; erase old position

    call read_keys          ; update direction if a key was pressed

    add bl, [dir_x]         ; move one step
    add bh, [dir_y]

    ; wrap x: valid range is 0 to 39
    cmp bl, 40
    jb .x_ok
    cmp bl, 0x80
    jae .x_under            ; went below 0 (value is now 255)
    xor bl, bl              ; went past 39, wrap to 0
    jmp .x_ok
.x_under:
    mov bl, 39
.x_ok:

    ; wrap y: valid range is 0 to 24
    cmp bh, 25
    jb .y_ok
    cmp bh, 0x80
    jae .y_under
    xor bh, bh
    jmp .y_ok
.y_under:
    mov bh, 24
.y_ok:

    mov ax, 0x2020          ; green cell
    call plot               ; draw new position

    call delay
    jmp game_loop

; read_keys: reads every waiting key press and sets the direction
; uses the scan code in ah, so arrows and WASD both work
read_keys:
    mov ah, 0x01
    int 0x16                ; check if a key is waiting 
    jz .done                ; zero flag set means no key
    mov ah, 0x00
    int 0x16                ; read the key, ah = scan code

    cmp ah, 0x48            ; up arrow
    je .up
    cmp ah, 0x11            ; W
    je .up
    cmp ah, 0x50            ; down arrow
    je .down
    cmp ah, 0x1f            ; S
    je .down
    cmp ah, 0x4b            ; left arrow
    je .left
    cmp ah, 0x1e            ; A
    je .left
    cmp ah, 0x4d            ; right arrow
    je .right
    cmp ah, 0x20            ; D
    je .right
    jmp read_keys           ; unknown key, check for more

.up:
    mov byte [dir_x], 0
    mov byte [dir_y], -1
    jmp read_keys
.down:
    mov byte [dir_x], 0
    mov byte [dir_y], 1
    jmp read_keys
.left:
    mov byte [dir_x], -1
    mov byte [dir_y], 0
    jmp read_keys
.right:
    mov byte [dir_x], 1
    mov byte [dir_y], 0
    jmp read_keys
.done:
    ret

; plot: draws one grid cell (2 screen cells wide)
; in: bl = x, bh = y, ax = cell value (color and character)
plot:
    push ax
    mov al, bh
    mov cl, 160
    mul cl                  ; ax = y * 160
    mov di, ax
    mov al, bl
    xor ah, ah
    shl ax, 2               ; x * 4
    add di, ax
    pop ax
    mov [es:di], ax
    mov [es:di + 2], ax
    ret

; delay: waits about 2 timer ticks (roughly 110 ms)
delay:
    mov ah, 0x00
    int 0x1a
    mov si, dx
.wait:
    mov ah, 0x00
    int 0x1a
    sub dx, si
    cmp dx, 2
    jb .wait
    ret

; game data
dir_x db 1                  ; starts moving right
dir_y db 0

times 510 - ($ - $$) db 0
dw 0xAA55