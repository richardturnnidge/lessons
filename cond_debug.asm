    .assume adl=1       ; ez80 ADL memory mode
    .org $40000         ; load code here

    jp start_here       ; jump to start of code

    .align 64           ; MOS header
    .db "MOS",0,1     


DEBUGGING:  EQU 1

    macro DEBUGMSG  whichMsg
        if DEBUGGING            ; only gets assembled if DEBUGGING is true, else assembles nothing
            push af
            push hl             ; HL and A are used, so save for when we are done

            ld a, 2
            rst.lil $10         ; enable 'printer'
            ld a, 21
            rst.lil $10         ; disable screen

            ld hl, whichMsg
            call printString

            ld a, 6
            rst.lil $10         ; re-enable screen
            ld a, 3
            rst.lil $10         ; disable printer

            pop hl  
            pop af
        endif
    endmacro

start_here:
            
    push af             ; store all the registers
    push bc
    push de
    push ix
    push iy

; ------------------
; This is our main program, just going to print hello World

    DEBUGMSG msg_started


    ld hl, msg_hello    ; address of string to use
    ld bc,0             ; length of string, or 0 if a delimiter is used
    ld a,0              ; A is the delimiter 
    rst.lil $18         ; Call the MOS API to send data to VDP 


    DEBUGMSG msg_completed

; ------------------
; This is where we exit the program

    pop iy              ; Pop all registers back from the stack
    pop ix
    pop de
    pop bc
    pop af
    ld hl,0             ; Load the MOS API return code (0) for no errors.    
    ret                 ; Return to MOS

; ------------------

printString:            ; print zero terminated string
    ld a,(hl)
    or a
    ret z
    RST.LIL 10h
    inc hl
    jr printString

; ------------------

msg_hello:              .db "Hello Agon World !\r\n",0 

msg_started:            .db "We have started...\r\n",0
msg_completed:          .db "We completed the task...\r\n",0





























