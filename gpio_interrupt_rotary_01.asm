	; AGON LIGHT
	; Interupt Driven Rotary Encoder
	; Richard Turnnidge 2025
	; State machine version

; ---------------------------------------------
;
;	MACROS
;
; ---------------------------------------------

	macro MOSCALL function
	ld a, function
	rst.lil $08
	endmacro

; ---------------------------------------------

	macro TABTO x, y
	ld a, 31  
	rst.lil $10    
	ld a, x  
	rst.lil $10   
	ld a, y  
	rst.lil $10    
	endmacro

; ---------------------------------------------

	macro CLS
	ld a, 12
	rst.lil $10
	endmacro

; ---------------------------------------------

	macro SETCURSOR value 		; to set cursor visible or not [0 or 1]
	push af
	ld a, 23
	rst.lil $10
	ld a, 1
	rst.lil $10
	ld a, value
	rst.lil $10			; VDU 23,1,value [0 off, 1 on]
	pop af
	endmacro

; ---------------------------------------------
;
;	CONSTANTS
;
; ---------------------------------------------

;			GPIO port IDs

PC_DR:		equ 	$9E
PC_DDR:		equ 	$9F
PC_ALT1:	equ 	$A0
PC_ALT2:	equ 	$A1

interruptPins: 	equ 10100000b

CLK_pin:	equ 10000000b
DT_pin:		equ 00100000b
both_pins:	equ 10100000b

; ---------------------------------------------
;
;	INITIALISE AGON
;
; ---------------------------------------------

	.assume adl=1				; big memory mode
	.org $40000				; load code here

	jp start_here				; jump to start of code

	.align 64				; MOS header
	.db "MOS",0,1

	include "debug_routines.asm"

; ---------------------------------------------
;
;	INITIAL SETUP CODE HERE
;
; ---------------------------------------------

start_here:

	push af						; store everything as good practice
	push bc						; pop back when we return from code later
	push de
	push ix
	push iy

	im 2  						; make sure running in interrupt mode 2

	CLS  						; clear screen before we start
	SETCURSOR 0  					; hide the cursor

	TABTO 0,0  					; TAB to title position
	ld hl, msg_title  				; put address of message into HL
	call printString 				; print the demo title

	TABTO 0,2  					; TAB to title position
	ld hl, msg_title2  				; put address of message into HL
	call printString 				; print the demo title

	call setup_GPIO_ports  				; configure the GPIO pin settings

	call start_GPIO_interrupts			; start the interrupt listener

	ld a,0
	ld (state), a
	ld (encoder_value), a  				; reset values

; ---------------------------------------------
;
;	MAIN LOOP
;
; ---------------------------------------------

MAIN_LOOP:

get_key_input:
	MOSCALL $08				; get IX pointer to sysvars
	ld a, (ix + 05h)			; ix+5h is 'last key pressed'

	cp 27					; is it ESC key?
	jp z, exit_here				; if so exit cleanly



	jp MAIN_LOOP  				; loop around until ESC is pressed


; ---------------------------------------------
;
;	EXIT CODE CLEANLY
;
; ---------------------------------------------

exit_here:

	call reset_GPIO				; reset GPIO port C to defaults

	CLS  					; clear the screen
	SETCURSOR 1  				; show cursor
			
	pop iy
	pop ix
	pop de
	pop bc
	pop af
	ld hl,0					; reset all values before returning to MOS

	ret					; return to MOS here

; ---------------------------------------------
;
;	IO PORT INIT
;
; ---------------------------------------------
;
;	This example uses GPIO Interrupt mode 6 - level-sensitive interrupts
;
;	For each pin used, we set:-
;		Data Register (DR)					1 
;		Data Direction Register (DDR) 		0
;		Alt1 register (ALT1)				0
;		Alt2 register (ALT2)				1
;
;	We are only working with interrupts on GPIO pins PC0 and PC1 in this example
; 	It defines pins 0 & 1 as interrupt driven input, and pins 2-7 as outputs


setup_GPIO_ports:

	di 				; stop any interrupts whle we configure

	ld a, interruptPins 	
	out0 (PC_DR), a 		; set DR of PC5 and PC7 to 1

	ld a, 00000000b
	out0 (PC_DDR), a 		; set DDR of register to 0 

	ld a, 00000000b 
	out0 (PC_ALT1), a  		; set ALT1 of register to 0

	ld a, interruptPins 
	out0 (PC_ALT2), a  		; set ALT2 of PC5 and PC7 to 1

 	ei  				; re-enable the interrupts

	ret 

; ---------------------------------------------

start_GPIO_interrupts:	

   	ld hl, isr_gpio_PC5_event			; address of service routine to call
	ld e, $4A       				; interrupt vector (GPIO Port PC0)
	MOSCALL $14     				; mos_api_setintvector

   	ld hl, isr_gpio_PC7_event			; address of service routine to call
	ld e, $4E       				; interrupt vector (GPIO Port PC1)
	MOSCALL $14     				; mos_api_setintvector

	ret 

; ---------------------------------------------

; reset all of GPIO port C to default values
; ie. standard inputs

reset_GPIO:

	di 				; stop any interrupts whle we configure

	ld a, $00
	out0 (PC_DR), a 		; set DR of all port C to 0

	ld a, $FF
	out0 (PC_DDR), a 		; set DDR of all port C to 0

	ld a, $00
	out0 (PC_ALT1), a  		; set ALT1 of all port C to 0

	ld a, $00
	out0 (PC_ALT2), a  		; set ALT2 of all port C to 0

 	ei   				; re-enable the interrupts

	ret 

; ---------------------------------------------
;
;	INTERRUPT SERVICE ROUTINES
;
;   GPIO interrupt service routine for pins PC 5 & 7
;   Triggered when status changes from high to low, or vice versa
;
; ---------------------------------------------

isr_gpio_PC5_event:

	di						; stop any other interrupts while we do this
	push hl
	push bc  					; store any registers we are going to use
	push af  					; store any registers we are going to use

	in0 a, (PC_DR)  				; read the current status of the GPIO PC pins
	ld (lastPortC), a  				; store latest port data

	or interruptPins  				; only change relevant bits, leave others as they are
 	out0 (PC_DR), a 				; set DR of port C to acknowledge interrupt


	jp check_encoder

; ---------------------------------------------

isr_gpio_PC7_event:

	di						; stop any other interrupts while we do this
	push hl
	push bc
	push af  					; store any registers we are going to use

	in0 a, (PC_DR)  				; read the current status of the GPIO PC pins

	ld (lastPortC), a  				; store latest port data

	or interruptPins  				; only change  relevant bits0, leave others as they are
 	out0 (PC_DR), a 				; set DR of port C to acknowledge interrupt

	jp check_encoder

; ---------------------------------------------
;
;	ROTARY STATE MACHINE
;
;	Figure out if turning or we have completed a click
;
; ---------------------------------------------

check_encoder:

	ld a, (lastPortC)

	and CLK_pin			; get CLK pin status
	ld (CLK_state), a  		; store it

	ld a, (lastPortC)
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

	; shouldn't get here, but just in case
	jp escapeInterrupt



; ---------------------------------------------
; state machine - we will be in one of these phases

state_0:					; default start state

	ld a, (CLK_state)
	cp CLK_pin
	jr z, state_0_1				; if CLK goes low

	ld a, 1  				; else set state to 1
	ld (state),a 

	jp escapeInterrupt

state_0_1:

	ld a, (DT_state)
	cp DT_pin
	jp z, escapeInterrupt			; if DT goes low

	ld a, 4 				; then set state to 4
	ld (state),a 

	jp escapeInterrupt


; ---------------------------------------------
state_1:

	ld a, (DT_state)			; CLK went low, now check DT
	cp DT_pin
	jp z, escapeInterrupt			; if DT goes high

	ld a, 2 				; set state to 2 if DT goes low
	ld (state),a 

	jp escapeInterrupt

; ---------------------------------------------
state_2:

	ld a, (CLK_state)			; check if CLK has now gone high
	cp CLK_pin
	jp nz, escapeInterrupt			; if CLK is low

	ld a, 3 				; set state to 3 if CLK is high
	ld (state),a 

	jp escapeInterrupt


; ---------------------------------------------
state_3:

	ld a, (lastPortC)
	cp both_pins				; are they both high?
	jp nz, escapeInterrupt			; not both

	; completed one step in clockwise direction
	ld a, 0
	ld (state), a  				; reset state

	ld a, (encoder_value)
	inc a 
	ld (encoder_value), a 			; increase value

	call encoderChanged  			; notify of change

	jp escapeInterrupt

; ---------------------------------------------
state_4:

	ld a, (CLK_state)			; DT went low, next check if CLK goes low
	cp CLK_pin
	jp z, escapeInterrupt			; if CLK is high

	ld a, 5 				; set state to 5 if CLK is low
	ld (state),a 

	jp escapeInterrupt

; ---------------------------------------------
state_5:

	ld a, (DT_state)			; CLK went low, next check if DT goes high
	cp DT_pin
	jp nz, escapeInterrupt			; if DT goes low

	ld a, 6 				; set state to 6 if DT goes high
	ld (state),a 

	jp escapeInterrupt

; ---------------------------------------------
state_6:

	ld a, (lastPortC)
	cp both_pins
	jp nz, escapeInterrupt			; not both

	; completed one step in anticlockwise direction
	ld a, 0
	ld (state), a  				; reset state

	ld a, (encoder_value)
	dec a 
	ld (encoder_value), a 			; decrease value

	call encoderChanged  			; notify of change

	jp escapeInterrupt

; ---------------------------------------------
; finish all checks and end interrupt

escapeInterrupt:

	pop af 
	pop bc  						
	pop hl  				; retrieve registers we have used

	ei   					; re-enable interrupts for next time
	reti.l  				; return from interrupt routine 

; ---------------------------------------------
; this gets called if there is a chage to the encoder value

encoderChanged:
						; the encoder changed its value so we get alerted here
	ld b, 7
	ld c, 2
	ld a, (encoder_value)
	call debugA

	ret


; ---------------------------------------------
;
; text & data
;
; ---------------------------------------------

msg_title:	.asciz "Rotary Encoder Interrupt Handler "
msg_title2:	.asciz "Value:  "

state:		.db 0
pin_reading: 	.db 0
CLK_state: 	.db 0
DT_state: 	.db 0

encoder_value: 	.db 0

lastPortC:	.db 0

; ---------------------------------------------
;
;	END
;
; ---------------------------------------------
