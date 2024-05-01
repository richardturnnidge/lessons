
    .assume adl=1                       ; ez80 ADL memory mode
    .org $40000                         ; load code here

    jp start_here                       ; jump to start of code

    .align 64                           ; MOS header
    .db "MOS",0,1     

start_here:
            
    push af                             ; store all the registers
    push bc
    push de
    push ix
    push iy

; ------------------
; This is our actual code

; Setup fonts 

    ld hl, loadData                     ; address of string to use
    ld bc, endData - loadData           ; length of string
    rst.lil $18                         ; Call the MOS API to send data to VDP 

 
; print 1st message with font 1

    ld hl, msg1                         ; address of string to use
    ld bc, endmsg1 - msg1               ; length of string
    rst.lil $18                         ; Call the MOS API to send data to VDP 

; print 2nd message with font 2

    ld hl, msg2                         ; address of string to use
    ld bc, endmsg2 - msg2               ; length of string
    rst.lil $18                         ; Call the MOS API to send data to VDP 

; reset to system font

    ld hl, reset                         ; address of string to use
    ld bc, endReset - reset              ; length of string
    rst.lil $18                          ; Call the MOS API to send data to VDP 


; ------------------
; This is where we exit the program

    pop iy                              ; Pop all registers back from the stack
    pop ix
    pop de
    pop bc
    pop af
    ld hl,0                             ; Load the MOS API return code (0) for no errors.
    ret                                 ; Return to MOS

; ------------------

loadData:

    .db     23,0, $C0, 0                ; set display to non-scaled coordinates

    .db     12                          ; CLS


    .db     23, 0, $A0                  ; buffer command
    .dw     -1                          ; ID (word): -1 in this case is ALL
    .db     2                           ; 2 = clear (all buffers)

    ; 1st font - load the buffer

    .db     23,0,$A0                    ; buffer command
    .dw     1000                        ; ID (word)
    .db     0                           ; 'write' command
    .dw     2048                        ; full 8x8 font is 16 bytes x 256 = 2048 

    incbin "DATA.F08"


    ; create 1st font from buffer (VDU 23, 0, &95, 1, bufferId; width, height, ascent, flags)

    .db     23,0,$95 , 1                ; create font
    .dw     1000                        ; ID (word)
    .db     8,8                         ; 8x8 font in this example
    .db     8,0                         ; ascent, flags



    ; 2nd font - load the buffer

    .db     23,0,$A0                    ; buffer command
    .dw     1001                        ; ID (word)
    .db     0                           ; 'write' command
    .dw     4096                        ; full 8x8 font is 16 bytes x 256 = 2048

    include "font-terminus.asm"

    ; create 2nd font from buffer(VDU 23, 0, &95, 1, bufferId; width, height, ascent, flags)

    .db     23,0,$95 , 1                ; create font
    .dw     1001                        ; ID (word)
    .db     8 ,16                       ; 8x8 font in this example
    .db     16,0                        ; ascent, flags


endData:

; ------------------
; Messaes which get sent to VDP

msg1:

    .db     4                           ; print at TAB position

    .db     23,0,$95 , 0                ; select font (VDU 23, 0, &95, 0, bufferId; flags)
    .dw     1000                        ; ID (word)
    .db     0                           ; flags

    .db     31,4,20                      ; TAB to 5, 5

    .db     "8x8 font printed at TAB position"     ; print this text
    .db     13,10                       ; CR, LF

endmsg1:

; ------------------

msg2:

    .db     5                           ; print at PIXEL PLOT position

    .db     23,0,$95 , 0                ; select font (VDU 23, 0, &95, 0, bufferId; flags)
    .dw     1001                        ; ID (word)
    .db     0                           ; flags

 
    .db     18, 0, 1                    ; set colour to red

    .db     25, $45
    .dw     20, 35                     ; PLOT a pixel (red just so we can see it)

    .db     18, 0, 15                   ; set colour to white

    .db     "Custom ", 255, " 8x16_font at PIXEL position"     ; print this text
    .db     13,10                       ; CR, LF

    .db     4                           ; print at TAB position

endmsg2:

; ------------------

reset:

    .db     23,0,$95 , 0                ; select font (VDU 23, 0, &95, 0, bufferId; flags)
    .dw     -1                          ; ID (word) -1 is revert to system font
    .db     1                           ; flags

endReset:









































