[org 0x7c00]
bits 16

body      equ 0x7e00        ; free memory right after the boot sector
START_LEN equ 2

BODY_CLR  equ 0x2020        ; green
HEAD_CLR  equ 0x3020        ; cyan
FOOD_CLR  equ 0x4020        ; red
EMPTY     equ 0x0020        ; black

start:
    xor ax, ax
    mov ds, ax
    mov ss, ax
    mov sp, 0x7c00
    cld

    ; 80x25 text mode, hide cursor
    mov ax, 0x0003
    int 0x10
    mov ah, 0x01
    mov cx, 0x2000
    int 0x10

    ; es points at video memory
    mov ax, 0xb800
    mov es, ax

    ; seed the random number generator from the BIOS timer
    mov ah, 0x00
    int 0x1a
    mov [seed], dx

    ; build the starting snake: head at x=20, y=12, body trailing left
    mov bx, 0x0c14          ; bh = y (12), bl = x (20)
    xor si, si
    mov dx, START_LEN
.init:
    mov [body + si], bx
    mov ax, BODY_CLR
    call plot
    dec bl
    add si, 2
    dec dx
    jnz .init

    ; recolor the head
    mov bx, [body]
    mov ax, HEAD_CLR
    call plot

    call place_food

game_loop:
    call read_keys

    ; commit this step's direction so the next key check can compare to it
    mov ax, [dir_x]
    mov [last_x], ax

    ; erase the tail and remember where it was
    mov si, [len]
    shl si, 1
    mov bx, [body + si - 2]
    mov [tail_pos], bx
    mov ax, EMPTY
    call plot

    ; shift every segment one slot toward the tail
    mov cx, [len]
    dec cx
.shift:
    mov ax, [body + si - 4]
    mov [body + si - 2], ax
    sub si, 2
    loop .shift

    ; new head = old head + direction
    mov bx, [body]
    add bl, [dir_x]
    add bh, [dir_y]

    ; wall check: a value below 0 wraps to 255, so one unsigned compare
    ; catches both sides of each axis
    cmp bl, 40
    jae game_over
    cmp bh, 25
    jae game_over

    ; self check: compare the new head with every other segment
    mov cx, [len]
    dec cx
    mov si, 2
.self:
    cmp bx, [body + si]
    je game_over
    add si, 2
    loop .self

    mov [body], bx          ; store the new head

    ; did the head land on the food?
    cmp bx, [food]
    jne .draw

    ; yes: grow by putting the old tail back
    mov si, [len]
    shl si, 1
    mov ax, [tail_pos]
    mov [body + si], ax
    inc word [len]
    push bx
    mov bx, ax
    mov ax, BODY_CLR
    call plot
    call place_food
    pop bx

.draw:
    ; old head becomes a body segment, new head gets the head color
    mov bx, [body + 2]
    mov ax, BODY_CLR
    call plot
    mov bx, [body]
    mov ax, HEAD_CLR
    call plot

    call delay
    jmp game_loop

game_over:
    ; turn the score into two digit characters
    call delay
    call delay
    call delay
    mov ax, [len]
    sub al, START_LEN
    aam                     ; ah = tens, al = units
    add ax, 0x3030
    xchg al, ah
    mov [score_txt], ax

    mov si, msg
    mov di, (12 * 80 + 30) * 2
    mov ah, 0x0f            ; white on black
.print:
    lodsb
    or al, al
    jz .wait
    stosw
    jmp .print

.wait:
    ; throw away keys pressed during play, then wait for a fresh one
    mov ah, 0x01
    int 0x16
    jz .fresh
    mov ah, 0x00
    int 0x16
    jmp .wait
.fresh:
    mov ah, 0x00
    int 0x16
    int 0x19                ; reload the boot sector = restart the game

; rand: returns a new pseudo-random number in ax
rand:
    mov ax, [seed]
    mov dx, 25173
    mul dx
    add ax, 13849
    mov [seed], ax
    ret

; place_food: picks a random free cell and draws the food there
place_food:
.retry:
    call rand
    xor dx, dx
    mov cx, 40
    div cx                  ; dx = random x (0 to 39)
    mov bl, dl
    push bx
    call rand
    xor dx, dx
    mov cx, 25
    div cx                  ; dx = random y (0 to 24)
    pop bx
    mov bh, dl

    mov cx, [len]
    xor si, si
.check:
    cmp bx, [body + si]
    je .retry
    add si, 2
    loop .check

    mov [food], bx
    mov ax, FOOD_CLR
    call plot
    ret

; read_keys: reads every waiting key press and updates the direction
; a turn is accepted only if (new direction AND last direction) is zero,
; which means it is a 90 degree turn and never a reverse
read_keys:
    mov ah, 0x01
    int 0x16
    jz .done
    mov ah, 0x00
    int 0x16                ; ah = scan code
    mov si, keys
    mov cx, 8
.find:
    cmp ah, [si]
    jne .next
    mov ax, [si + 1]        ; candidate direction (dx in al, dy in ah)
    test ax, [last_x]
    jnz read_keys           ; same axis as the last move, so ignore it
    mov [dir_x], ax
    jmp read_keys
.next:
    add si, 3
    loop .find
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

; key table: scan code, then direction word (dx low byte, dy high byte)
keys:
    db 0x48
    dw 0xff00               ; up arrow    (0, -1)
    db 0x11
    dw 0xff00               ; W
    db 0x50
    dw 0x0100               ; down arrow  (0, 1)
    db 0x1f
    dw 0x0100               ; S
    db 0x4b
    dw 0x00ff               ; left arrow  (-1, 0)
    db 0x1e
    dw 0x00ff               ; A
    db 0x4d
    dw 0x0001               ; right arrow (1, 0)
    db 0x20
    dw 0x0001               ; D

; game data
dir_x    db 1
dir_y    db 0
last_x   db 1
last_y   db 0
len      dw START_LEN
tail_pos dw 0
food     dw 0
seed     dw 0
msg      db "GAME OVER  Score: "
score_txt db "00", 0

times 510 - ($ - $$) db 0
dw 0xAA55