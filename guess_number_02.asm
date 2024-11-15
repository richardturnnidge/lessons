; ------------------------------------
;
; Number guessing game
; Richard Turnnidge 2024
;
; ------------------------------------

    .assume adl=1                       ; ez80 ADL memory mode
    .org $40000                         ; load code here

    jp start_here                       ; jump to start of code

    .align 64                           ; MOS header
    .db "MOS",0,1     

    macro MOSCALL arg1
    ld a, arg1
    rst.lil $08
    endmacro

debugging:  equ 0

start_here:
            
    push af                             ; store all the registers
    push bc
    push de
    push ix
    push iy

; ------------------
; This is our actual code

START:
    ld hl, msg_title                    ; print big title
    call printString

    MOSCALL $08                         ; get IX pointer to sysvars
    ld a, (ix + $00)                    ; second counter in string
    ld (seed), a
    call get_random_byte_v2             ; set seed of rndv2 with clock data
    ld (randSeed),a                     ; set seed of randv1 with first random number

GENERATING:
    ld a, 0
    ld (guesses), a
    call getRandom10                    ; get a random number 1-10
    ld (guessNumber), a                 ; store for later

    if debugging
        call spitA                          ; give answer while debugging
    endif

    ld hl, msg_genNumber                ; print msg
    call printString

    ld hl, msg_pressEnter
    call printString

    MOSCALL $1E                         ; get IX pointer to keyvals, currently pressed keys

ENTER_TO_START:

    ld a, (ix + $09)                    ; ENTER code code
    bit 1, a    
    jp nz, ENTER_NUMBER                 ; ENETR key to start
    jr ENTER_TO_START

ENTER_NUMBER:

    ld hl, msg_guessNumber
    call printString



GUESSHERE:

    ld a, (guesses)
    inc a 
    ld (guesses),a 

    ld hl, textBuffer                   ; HL needs to point to where text will be stored
    ld bc, 3                            ; BC is maximum nunber of chars
    ld e, 1                             ; 1 to clear buffer, 0 not to clear
    MOSCALL $09                         ; call $09 mos_editline

    ld hl, LINEFEED
    call printString

    ld a, (guessNumber)                 ; get the random number to guess
    ld b,a 
    ld hl, textBuffer
    call asc2int                        ; put decimal of input into A

    cp b  
    jr z, CORRECT                       ; they were the same
    jr nc, TOO_HIGH

TOO_LOW:

    ld hl, msg_tooLow
    call printString

    jr GUESS_AGAIN

TOO_HIGH:

    ld hl, msg_tooHigh
    call printString

GUESS_AGAIN:
    ld hl, msg_guessAgain
    call printString

    jp GUESSHERE

CORRECT:

    ld hl, msg_guessIn
    call printString
    ld a, (guesses)
    call printDec
    ld hl, msg_guesstries
    call printString

PLAY_AGAIN:

    ld hl, msg_again
    call printString
    MOSCALL $1E                         ; get IX pointer to keyvals, currently pressed keys

WAIT_YN:

    ld a, (ix + $08)                    ; Y code code
    bit 4, a    
    jp nz, PLAYAGAIN                 

    ld a, (ix + $0A)                    
    bit 5, a  
    jp nz, NOPLAY                       ; N code

    jr WAIT_YN

PLAYAGAIN:
    ld a, 'y'
    rst.lil $10                         ; print a 'y'
    jp GENERATING      

NOPLAY:

    ld hl, msg_OK
    call printString

; ------------------
; This is where we exit the program

EXIT_HERE:

    pop iy                              ; Pop all registers back from the stack
    pop ix
    pop de
    pop bc
    pop af
    ld hl,0                             ; Load the MOS API return code (0) for no errors.
    ret                                 ; Return to MOS

; ------------------


msg_pressEnter:     .asciz  "Press ENTER to start!\r\n\r\n"
msg_genNumber:      .asciz  "\r\nGenerating a new number!\r\n\r\n"
msg_guessNumber:    .asciz  "Guess a number between 1 and 10: "
msg_guessAgain:     .asciz  "Guess again: "
msg_tooLow:         .asciz  "too low!\r\n"
msg_tooHigh:        .asciz  "too high!\r\n"
msg_again:          .asciz  "Do you want to play again? (y/n): "
msg_OK:             .asciz  "n\r\n\r\nOkay\r\n", 17,15
msg_guessIn:        .asciz  "Congratulations!\r\n\r\nYou guessed the number in "
msg_guesstries:     .asciz  " tries!\r\n\r\n"

; title printing routine could be made more byte efficient
msg_title:          .db  17, 10
msg_title0:         .db  " #     #                                 ####                          ###\r\n"
msg_title1:         .db  " ##    # #   # #    # ####  ##### ####  #    # #   # #####  ###   ###  ###\r\n"
msg_title2:         .db  " # #   # #   # ##  ## #   # #     #   # #      #   # #     #     #     ###\r\n"
msg_title3:         .db  " #  #  # #   # # ## # ####  ####  #   # #  ### #   # ####   ###   ###   #\r\n"
msg_title4:         .db  " #   # # #   # #    # #   # #     ####  #    # #   # #         #     #\r\n"
msg_title5:         .db  " #    ## #   # #    # #   # #     #  #  #    # #   # #     #   # #   # ###\r\n"
msg_title6:         .db  " #     #  ###  #    # ####  ##### #   #  ####   ###  #####  ###   ###  ###\r\n",0

LINEFEED:           .asciz "\r\n"


textBuffer:     .blkb 3,0   ; buffer for input bar

guessNumber:    .db     0   ; the number to guess
guesses:        .db     0   ; the numnber of guesses made

; ---------------------------------------------

printString:                ; print zero terminated string
    ld a,(hl)
    or a
    ret z
    RST.LIL 10h
    inc hl
    jr printString


; ---------------------------------------------
; routine to get random number 1-10

getRandom10:

    call get_random_byte    ; get first byte
    and 00000111b           ; just 0-7

    ld b, a                 ; store first part in b
    call get_random_byte    ; get first byte
    rla
    rla
    and 00000001b           ; just 0-1

    add a, b                ; add first part to get nmber 0-9
    inc a                   ; inc so 1-10

    ret 

; ---------------------------------------------

get_random_byte:       ;returns A as random byte
     .db 3Eh            ;start of ld a,*
randSeed:
     .db 0
     push bc 

     ld c,a
     add a,a
     add a,c
     add a,a
     add a,a
     add a,c
     add a,83
     ld (randSeed),a
     pop bc
     ret

; ---------------------------------------------
; alternate random number generator

get_random_byte_v2:

 ld a, (seed)
 ld b, a 

 rrca ; multiply by 32
 rrca
 rrca
 xor 0x1f

 add a, b
 sbc a, 255 ; carry

 ld (seed), a
 ret

seed:
     .db 255

; ---------------------------------------------
; simple assumption value is 1-10
; take entry pointer as HL
; which will be 10z or Az

asc2int:
    inc hl 
    ld a, (hl)      ; this will be 0 or an ascii char
    cp 0  
    jr z, @under10   ; was terminated after 1 byte

@over 10:
    ld a, 10
    ret

@under10:
    dec hl
    ld a, (hl)      ; this will be 0 or an ascii char 
    sub 48          ; sub 48 fropm ascii to dec
    ret


; ---------------------------------------------
    if debugging
spitA:             ; debug A to screen as HEX byte pair at pos BC
    push af 
    ld (debug_char), a  ; store A
                ; first, print 'A=' at TAB 36,0
    ld hl, LINEFEED
    call printString

    ld a, (debug_char)  ; get A from store, then split into two nibbles
    and 11110000b       ; get higher nibble
    rra
    rra
    rra
    rra         ; move across to lower nibble
    add a,48        ; increase to ascii code range 0-9
    cp 58           ; is A less than 10? (58+)
    jr c, @next       ; carry on if less
    add a, 7        ; add to get 'A' char if larger than 10
@next:    
    rst.lil $10     ; print the A char

    ld a, (debug_char)  ; get A back again
    and 00001111b       ; now just get lower nibble
    add a,48        ; increase to ascii code range 0-9
    cp 58           ; is A less than 10 (58+)
    jp c, @next2       ; carry on if less
    add a, 7        ; add to get 'A' char if larger than 10 
@next2:    
    rst.lil $10     ; print the A char
    
    ld a, (debug_char)
    pop af 
    ret         ; head back

debug_char: .db 0
    endif
; ---------------------------------

printDec:               ; debug A to screen as 3 char string pos

    push af
    ld a, 48
    ld (answer),a 
    ld (answer+1),a 
    ld (answer+2),a     ; reset to default before starting

                        ; is it bigger than 200?
    pop af

    ld (base),a         ; save

    cp 200
    jr c,_under200      ; not 200+
    sub a, 200
    ld (base),a         ; sub 200 and save

    ld a, 50            ; 2 in ascii
    rst.lil $10         ; print out a '200' digit
    ld (answer),a
    jr _under100

_under200:
    cp 100
    jr c,_under100      ; not 200+
    sub a, 100
    ld (base),a         ; sub 200 and save

    ld a, 49            ; 1 in ascii
    ld (answer),a
 
    rst.lil $10         ; print out a '100' digit
    jr _under100


_under100:
    ld a, (base)
    ld c,a
    ld d, 10
    call C_Div_D

    add a, 48
    ld (answer + 2),a
    ld b, a 

    ld a, c
    cp 0
    jr z, _lastDigit

    add a, 48
    ld (answer + 1),a
    rst.lil $10         ; print out 10s digit
_lastDigit:
    ld a,b 
    rst.lil $10         ; print out last digit

    ret 


debugOut:
answer:         .db     "000"       ; string to output
endDebugOut:

base:           .db     0       ; used in calculations

; -----------------

C_Div_D:
;Inputs:
;     C is the numerator
;     D is the denominator
;Outputs:
;     A is the remainder
;     B is 0
;     C is the result of C/D
;     D,E,H,L are not changed
;
    ld b,8
    xor a
    sla c
    rla
    cp d
    jr c,$+4
    inc c
    sub d
    djnz $-8
    ret


; ---------------------------------














































