[bits 16]
org 0x0000

start:
    cli                         ; Disable interrupts
    mov ax, 0xF000              ; Point DS to our ROM segment
    mov ds, ax
    mov es, ax
    
    ; Setup a simple stack
    xor ax, ax
    mov ss, ax
    mov sp, 0x7C00

    call clear_screen           ; Initialize the display manually
    
    mov si, welcome_msg
    call print_string
    call main_menu
    
    cli
    hlt

; --- BARE METAL VIDEO (Replaces int 0x10) ---
print_string:
    push ax
    push bx
    push es
    mov ax, 0xb800              ; VGA text buffer segment
    mov es, ax
    mov bx, [cursor_pos]
.loop:
    lodsb
    test al, al
    jz .done
    cmp al, 10                  ; Newline
    je .newline
    cmp al, 13                  ; Carriage return
    je .loop
    
    mov [es:bx], al             ; Write character
    mov byte [es:bx+1], 0x07    ; Attribute: Grey on Black
    add bx, 2
    jmp .loop
.newline:
    add bx, 160                 ; 80 columns * 2 bytes
    jmp .loop
.done:
    mov [cursor_pos], bx
    pop es
    pop bx
    pop ax
    ret

clear_screen:
    mov ax, 0xb800
    mov es, ax
    xor di, di
    mov ax, 0x0720              ; Space character + Grey attribute
    mov cx, 2000
    rep stosw
    mov word [cursor_pos], 0
    ret

; --- BARE METAL KEYBOARD (Replaces int 0x16) ---
wait_key:
.loop:
    in al, 0x64                 ; Status port
    test al, 1                  ; Check if data is ready
    jz .loop
    in al, 0x60                 ; Read raw scancode
    ret

main_menu:
    mov si, menu_header
    call print_string
    mov si, menu_options
    call print_string
.menu_loop:
    call wait_key
    ; Scancodes: 1 = 0x02, Q = 0x10
    cmp al, 0x02
    je .show_info
    cmp al, 0x10
    je .exit
    jmp .menu_loop

.show_info:
    call clear_screen
    mov si, info_msg
    call print_string
    mov si, prompt
    call print_string
    call wait_key
    jmp main_menu

.exit:
    ret

; --- DATA ---
welcome_msg     db 'RBIOS v2.0 - BARE METAL ENGINE', 10, 0
menu_header     db '--- MAIN MENU ---', 10, 0
menu_options    db '1 - System Info', 10, 'q - Exit', 10, 0
info_msg        db 'Hardware Access: OK', 10, 0
prompt          db 'Press any key...', 10, 0
cursor_pos      dw 0

; --- THE PADDING (Keeps file at exactly 65,536 bytes) ---
times (65536 - 16) - ($ - $$) db 0

reset_vector:
    jmp 0xF000:start            ; The CPU entry point
    times 16 - ($ - reset_vector) db 0
