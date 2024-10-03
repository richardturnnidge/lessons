	; AGON LIGHT
	; Rotary Encoder test app
	; Richard Turnnidge 2024
	; State machine version

	; Assumumption that rotary encoder is attached to 
	; port C, bits 0 & 1
	; This could be improved for better efficiency, however
	; it has been written for better understanding of state order

	.assume adl=1		; big memory mode
	.org $40000		; load code here

	jp start_here		; jump to start of code

	.align 64		; MOS header
	.db "MOS",0,1

; ---------------------------------------------
;
;	INITIAL SETUP CODE HERE
;
; ---------------------------------------------
	macro MOSCALL afunc
	ld a, afunc
	rst.lil $08
	endmacro

	macro TAB_TO x,y
	ld a, 31					; move to...
	rst.lil $10
	ld a, x						; X position
	rst.lil $10
	ld a, y						; Y position
	rst.lil $10
	endmacro

	; constants for pin states
	; these are the binary values of the pins being used

CLK_pin:	equ 00000001b
DT_pin:		equ 00000010b
both_pins:	equ 00000011b

start_here:

	; store everything as good practice
	; pop back when we return from code later

	push af
	push bc
	push de
	push ix
	push iy

	call setupIO

showTitle:
	ld hl, title_str		; data to send
	ld bc, end_title - title_str	; length of data
	rst.lil $18

	ld a,0				; set A to 0
	or a 				; clear flags

	call updateValue

; ---------------------------------------------
;
;	MAIN LOOP
;
; ---------------------------------------------

MAIN_LOOP:

get_key_input:
	MOSCALL $08			; get IX pointer to sysvars
	ld a, (ix + 05h)		; ix+5h is 'last key pressed'

	cp 27				; is it ESC key?
	jp z, exit_here			; if so exit cleanly


check_encoder:
					; needed to clear flags, else it didn't seem to work
	ld a,0				; set A to 0
	or a 				; clear flags
	in a, ($9e)			; grab current io value of port C
	and 00000011b			; mask just last 2 bits, pins 0 and 1 are used for the encoder
	ld (pin_reading), a  		; store current reading

	and CLK_pin			; get CLK pin status
	ld (CLK_state), a  		; store it

	ld a, (pin_reading)
	and DT_pin			; get DT pin status
	ld (DT_state), a 		; store it

	or a 				; clear flags to be sure

	ld a, (state)			; get current 'machine state' and jump to section
	cp 0
	jp z, state_0

	cp 1
	jp z, state_1

	cp 2
	jp z, state_2

	cp 3
	jp z, state_3

	cp 4
	jp z, state_4

	cp 5
	jp z, state_5

	cp 6
	jp z, state_6

	jp MAIN_LOOP			; shoud not get here really, but just in case...


; ---------------------------------------------
; state machine - we will be in one of these phases

state_0:				; default start state

	ld a, (CLK_state)
	cp CLK_pin
	jr z, state_0_1			; if CLK goes low

	ld a, 1  			; else set state to 1
	ld (state),a 
	jp MAIN_LOOP

state_0_1:

	ld a, (DT_state)
	cp DT_pin
	jp z, MAIN_LOOP			; if DT goes low

	ld a, 4 			; then set state to 4
	ld (state),a 

	jp MAIN_LOOP


; ---------------------------------------------
state_1:

	ld a, (DT_state)		; CLK went low, now check DT
	cp DT_pin
	jp z, MAIN_LOOP			; if DT goes high

	ld a, 2 			; set state to 2 if DT goes low
	ld (state),a 

	jp MAIN_LOOP

; ---------------------------------------------
state_2:

	ld a, (CLK_state)		; check if CLK has now gone high
	cp CLK_pin
	jp nz, MAIN_LOOP		; if CLK is low

	ld a, 3 			; set state to 3 if CLK is high
	ld (state),a 

	jp MAIN_LOOP


; ---------------------------------------------
state_3:

	ld a, (pin_reading)
	cp both_pins			; are they both high?
	jp nz, MAIN_LOOP		; not both

	; completed one step in clockwise direction
	ld a, 0
	ld (state), a  			; reset state

	ld a, (encoder_value)
	inc a 
	ld (encoder_value), a 		; increase value

	call updateValue		; print out change in value

	jp MAIN_LOOP

; ---------------------------------------------
state_4:

	ld a, (CLK_state)		; DT went low, next check if CLK goes low
	cp CLK_pin
	jp z, MAIN_LOOP			; if CLK is high

	ld a, 5 			; set state to 5 if CLK is low
	ld (state),a 

	jp MAIN_LOOP



; ---------------------------------------------
state_5:

	ld a, (DT_state)		; CLK went low, next check if DT goes high
	cp DT_pin
	jp nz, MAIN_LOOP		; if DT goes low

	ld a, 6 			; set state to 6 if DT goes high
	ld (state),a 

	jp MAIN_LOOP



; ---------------------------------------------
state_6:

	ld a, (pin_reading)
	cp both_pins
	jp nz, MAIN_LOOP		; not both

	; completed one step in anticlockwise direction
	ld a, 0
	ld (state), a  			; reset state

	ld a, (encoder_value)
	dec a 
	ld (encoder_value), a 		; decrease value

	call updateValue		; print out change in value

	jp MAIN_LOOP



; ---------------------------------------------

updateValue:

	TAB_TO 15,3			; set cursor position
	ld a, (encoder_value)		; get current value of the encoder
	call debugDec			; print out current reading in decimal

	ret

; ---------------------------------------------
;
;	EXIT CODE CLEANLY
;
; ---------------------------------------------

exit_here:

	ld a, 12
	rst.lil $10		; CLS
				; reset all values before returning to MOS
	pop iy
	pop ix
	pop de
	pop bc
	pop af
	ld hl,0

	ret			; return to MOS here

; ---------------------------------------------
;
;	IO PORT INIT
;
; ---------------------------------------------

setupIO:
	; This is all based on my reading of the eZ80 user manual. It might not all be needed.
	; The default should be that all pins are treated as inputs. However, there may 
	; be other applications which have used the io ports before us.

	; port C confugration for inputs

	ld a, 0
	out0 ($9e), a 		; set DR of all port C to 0 default - 158
	ld a, $FF
	out0 ($9f), a 		; set DDR of all port C to 255 - 159
	ld a, 0
	out0 ($a0), a  		; set ALT1 of all port C to 0 - 160
	ld a, 0
	out0 ($a1), a  		; set ALT2 of all port C to 0 - 161

	ret 

; ---------------------------------------------
;
;	DATA & STRINGS
;
; ---------------------------------------------

state:			.db 0
pin_reading: 		.db 0
CLK_state: 		.db 0
DT_state: 		.db 0

encoder_value: 		.db 0

title_str:
	.db	12 			; CLS
	.db	31,0,0			; TAB to 0,0
	.db "Rotary Encoder - state machine"		; text to show

	.db	31,0,3			; TAB to 0,0
	.db "Encoder value:"		; text to show

	.db	31,0,13			; TAB to 0,0
	.db "Hit ESC to exit"		; text to show

	.db	31,0,15			; TAB to 0,0
	.db "Richard Turnnidge 2024"	; text to show
	.db	31,0,17			; TAB to 0,0
	.db "No warranty provided!"	; text to show

end_title:


; ---------------------------------------------
;
;	DEBUG IN DECIMAL
;
; ---------------------------------------------

debugDec:			; debug A to screen as 3 char string pos

	push af
	ld a, 48		; ascii for '0'
	ld (answer),a 
	ld (answer+1),a 
	ld (answer+2),a 	; reset to default before starting
	pop af

	ld (base),a         	; base char set to '0'

	cp 200
	jr c,_under200      	; not 200+

	sub a, 200		; is over 200
	ld (base),a         	; sub 200 and save

	ld a, 50            	; 2 in ascii
	ld (answer),a
	jr _under100

_under200:
	cp 100
	jr c,_under100      	; not 100+
	sub a, 100
	ld (base),a         	; sub 100 and save

	ld a, 49            	; 1 in ascii
	ld (answer),a
	jr _under100


_under100:
	ld a, (base)
	ld c,a
	ld d, 10
	call C_Div_D

	add a, 48
	ld (answer + 2),a

	ld a, c
	add a, 48
	ld (answer + 1),a


	ld hl, debugOut                      ; address of string to use
	ld bc, endDebugOut - debugOut         ; length of string
	rst.lil $18
	ret 


debugOut:
answer:         .db     "000"		; string to output
endDebugOut:

base:       	.db     0		; used in calculations


; ---------------------------------------------
;
;	MATHS ROUTINES
;
; ---------------------------------------------

; C divided by D

;Inputs:
;     C is the numerator
;     D is the denominator
;Outputs:
;     A is the remainder
;     B is 0
;     C is the result of C/D
;     D,E,H,L are not changed
;

C_Div_D:

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

; ---------------------------------------------
;
;	END
;
; ---------------------------------------------
