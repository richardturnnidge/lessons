    ; extra MACRO files need to go here
    include "myMacros.inc"

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

    CLS              
    call loadSample

    ld hl, message
    call printString
     
WAIT_HERE:                              

    MOSCALL $1E                         ; get IX pointer to keyvals
    ld a, (ix + $0E)  
    bit 0, a                            ; ESC key
    jp nz, EXIT_HERE                    ; if pressed, jump to EXIT_HERE

    MOSCALL $1E                         ; get IX pointer to keyvals
    ld a, (ix + $08)  
    bit 1, a                            ; A key
    call nz, playNote

    MOSCALL $1E                         ; get IX pointer to keyvals
    ld a, (ix + $0C)  
    bit 4, a                            ; B key
    call nz, playMainJet                ; if pressed, start sound

    MOSCALL $1E                         ; get IX pointer to keyvals
    ld a, (ix + $0C)  
    bit 4, a                            ; B key
    call z, stopMainJet                 ; if not pressed stop sound

    MOSCALL $1E                         ; get IX pointer to keyvals
    ld a, (ix + $0A)  
    bit 2, a                            ; C key
    call nz, playSample

    jr WAIT_HERE

; ------------------
; This is where we exit the program

EXIT_HERE:

    ld a, 23                            ; SHOW CURSOR
    rst.lil $10
    ld a, 1
    rst.lil $10
    ld a,1                              ; VDU 23,1,0 = hide the text cursor
    rst.lil $10                         ; VDU 23,1,1 = show the text cursor 

    CLS  
    pop iy                              ; Pop all registers back from the stack
    pop ix
    pop de
    pop bc
    pop af
    ld hl,0                             ; Load the MOS API return code (0) for no errors.
    ret                                 ; Return to MOS


; ------------------
; DATA
; ------------------

message:
    .db "Sound example, press A, B, or C\r\n",0

; ------------------
; SOUND ROUTINES
; ------------------

playNote:
    ld hl, note
    ld bc, endNote - note
    rst.lil $18
    call wait_for_keyup
    ret 

note:  
    .db 23,0,$85                        ; do sound
    .db 0                               ; channel
    .db 4,0                             ; set waveform, waveform type

    .db 23,0,$85                        ; do sound
    .db 0                               ; channel
    .db 0,63                           ; code, volume
    .dw 800                             ; freq
    .dw 1000                             ; duration (milliseconds WORD)
endNote:

; ------------------

playMainJet:
    ld a, (jetPlaying)
    cp 1 
    ret z 

    ld hl, mainJetPlay
    ld bc, endMainJet - mainJetPlay
    rst.lil $18

    ld a, 1
    ld (jetPlaying),a
    ret  

mainJetPlay:
    .db     23,0,$85,1,4,5              ; set waveform to VIC noise
    .db     23,0,$85,1,0,127
    .dw     $40, -1                     ; frq, duration
endMainJet:


stopMainJet:
    ld hl, stopMainSnd
    ld bc, endMainSnd - stopMainSnd
    rst.lil $18

    ld a, 0
    ld (jetPlaying),a
    ret  

stopMainSnd:
    .db     23,0,$85,1,2,0              ; set vol to 0
endMainSnd:

jetPlaying:
    .db 0

; ------------------

playSample:                         
    ld hl, startSample
    ld bc, endSample - startSample
    rst.lil $18
    call wait_for_keyup
    ret 

startSample: 
    .db 23,0,$85                        ; do sound
    .db 2,4,-1                          ; channel

    .db 23,0,$85                        ; do sound
    .db 2,0, 127                        ; channel, volume
    .dw 125                             ; freq (ignored for samples)
    .dw 1000                            ; duration (ignored for samples)
endSample:

; ------------------

loadSample:                             ; for loading audio samples
    ld hl, sampleStr                    ; start of data to send
    ld bc, endSampleStr - sampleStr     ; length of data to send
    rst.lil $18                         ; send data
    ret 

sampleStr:
    .db     23,0,85h                    ; audio command
    .db     -1, 5                       ; sample number, sample management
    .db     0                           ; load
    .dl     15279                       ; length in bytes (LONG)
    incbin "letsgo.raw"
endSampleStr:

; ------------------
; OTHER FUNCTIONS
; ------------------

wait_for_keyup:                         ; wait for key up state so we only do it once
    MOSCALL $08                         ; get IX pointer to sysvars
    ld a, (ix + 18h)                    ; get key state
    cp 0                                ; are keys up, none currently pressed?
    jr nz, wait_for_keyup               ; loop if there is a key still pressed
    ret

; ------------------

printString:                            ; print zero terminated string
    ld a,(hl)
    or a
    ret z
    RST.LIL 10h
    inc hl
    jr printString

; ------------------

















