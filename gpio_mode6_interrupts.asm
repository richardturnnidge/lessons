; AGON GPIO INTERRUPTS
; Richard Turnnidge 2025
; Mode 6 example

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
	rst.lil $10					; VDU 23,1,value [0 off, 1 on]
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

; ---------------------------------------------
;
;	INITIALISE AGON
;
; ---------------------------------------------

	.assume adl=1				; big memory mode
	.org $40000					; load code here

	jp start_here				; jump to start of code

	.align 64					; MOS header
	.db "MOS",0,1

; ---------------------------------------------
;
;	INITIAL SETUP CODE HERE
;
; ---------------------------------------------

start_here:

	push af								; store everything as good practice
	push bc								; pop back when we return from code later
	push de
	push ix
	push iy

	im 2  								; make sure running in interrupt mode 2

	CLS  								; clear screen before we start
	SETCURSOR 0  						; hide the cursor

	TABTO 2,8  							; TAB to title position
	ld hl, msg_title  					; put address of message into HL
	call printString 					; print the demo title

	call setup_GPIO_ports  				; configure the GPIO pin settings

	call start_GPIO_interrupts			; start the interrupt listener

; ---------------------------------------------
;
;	MAIN LOOP
;
; ---------------------------------------------

MAIN_LOOP:

get_key_input:
	MOSCALL $08					; get IX pointer to sysvars
	ld a, (ix + 05h)			; ix+5h is 'last key pressed'

	cp 27						; is it ESC key?
	jp z, exit_here				; if so exit cleanly

	jp MAIN_LOOP  				; loop around until ESC is pressed


; ---------------------------------------------
;
;	EXIT CODE CLEANLY
;
; ---------------------------------------------

exit_here:

	call reset_GPIO				; reset GPIO port C to defaults

	CLS  						; clear the screen
	SETCURSOR 1  				; show cursor
			
	pop iy
	pop ix
	pop de
	pop bc
	pop af
	ld hl,0						; reset all values before returning to MOS

	ret							; return to MOS here

; ---------------------------------------------
;
;	IO PORT INIT
;
; ---------------------------------------------
;
;	This example uses GPIO Interrupt mode 6 - level-sensitive interrupts
;	
;	Data Register (DR)					1 
;	Data Direction Register (DDR) 		0
;	Alt1 register (ALT1)				0
;	Alt2 register (ALT2)				1
;
;	We are only working with interrupts on GPIO pin PC0 in this example
; 	It defines pins 0 & 1 as interrupt driven input, and pins 2-7 as outputs


setup_GPIO_ports:

	di 						; stop any interrupts whle we configure

	ld a, 00000011b 	
	out0 (PC_DR), a 		; set DR of PC0 to 0 as we are first waiting for a LOW interrupt

	ld a, 00000000b
	out0 (PC_DDR), a 		; set DDR of PC0 to 0 

	ld a, 00000000b 
	out0 (PC_ALT1), a  		; set ALT1 of PC0 to 1 

	ld a, 00000011b 
	out0 (PC_ALT2), a  		; set ALT2 of PC0 to 1

 	ei  					; re-enable the interrupts

	ret 

; ---------------------------------------------

start_GPIO_interrupts:	

   	ld hl, isr_gpio_PC0_event			; address of service routine to call
	ld e, $40       					; interrupt vector (GPIO Port PC0)
	MOSCALL $14     					; mos_api_setintvector

   	ld hl, isr_gpio_PC1_event			; address of service routine to call
	ld e, $42       					; interrupt vector (GPIO Port PC1)
	MOSCALL $14     					; mos_api_setintvector

	ret 

; ---------------------------------------------

; reset all of GPIO port C to default values
; ie. standard inputs

reset_GPIO:

	di 						; stop any interrupts whle we configure

	ld a, $00
	out0 (PC_DR), a 		; set DR of all port C to 0

	ld a, $FF
	out0 (PC_DDR), a 		; set DDR of all port C to 0

	ld a, $00
	out0 (PC_ALT1), a  		; set ALT1 of all port C to 0

	ld a, $00
	out0 (PC_ALT2), a  		; set ALT2 of all port C to 0

 	ei   					; re-enable the interrupts

	ret 

; ---------------------------------------------
;
;	INTERRUPT SERVICE ROUTINES
;
;   GPIO interrupt service routine for pins PC 0 & 1
;   Triggered when status changes from high to low, or vice versa
;
; ---------------------------------------------

isr_gpio_PC0_event:

	di								; stop any other interrupts while we do this
	push hl
	push af  						; store any registers we are going to use

	in0 a, (PC_DR)  				; read the current status of the GPIO PC pins
	ld (lastPortC), a  				; store latest port data

	bit 0, a 						; check status of the the GPIO pin we want (pin PC0)
	jr nz, @released   				; decide if pressed or released

@pressed:

	ld hl, msg_PC0_pressed 			; put address of message into HL
	jr @end  						; jump ahead

@released:

	ld hl, msg_PC0_released 		; put address of message into HL

@end:
	or 00000011b  					; only change bits 1 & 0, leave others as they are
 	out0 (PC_DR), a 				; set DR of port C to acknowledge interrupt

	TABTO 2,12  					; TAB to print text
	call printString  				; print the message

	call displayPortC  				; display purely for info, in binary format

	pop af 
	pop hl  						; retrieve registers we have used

	ei   							; re-enable interrupts for next time
	reti.l  						; return from interrupt routine  


; ---------------------------------------------

isr_gpio_PC1_event:

	di								; stop any other interrupts while we do this
	push hl
	push af  						; store any registers we are going to use

	in0 a, (PC_DR)  				; read the current status of the GPIO PC pins

	ld (lastPortC), a  				; store latest port data
	bit 1, a 						; check status of the the GPIO pin we want (pin PC1)
	jr nz, @released   				; decide if pressed or released

@pressed:

	ld hl, msg_PC1_pressed 			; put address of message into HL
	jr @end  						; jump ahead

@released:
									
	ld hl, msg_PC1_released 		; put address of message into HL

@end:

	or 00000011b  					; only change bits 1 & 0, leave others as they are
 	out0 (PC_DR), a 				; set DR of port C to acknowledge interrupt

	TABTO 2,14  					; TAB to print text
	call printString  				; print the message

	call displayPortC				; display purely for info, in binary format

	pop af 
	pop hl  						; retrieve registers we have used

	ei   							; re-enable interrupts for next time
	reti.l  						; return from interrupt routine  


; ---------------------------------------------

displayPortC:

	TABTO 2,17  					; TAB to print text

	ld a, (lastPortC) 				; retrieve the latest port value (need original value)
	call printBin  					; display purely for info, in binary format

	ret

lastPortC:	.db 0

; ---------------------------------------------
;
;	OTHER ROUTINES
;
; ---------------------------------------------

; print zero terminated string
; Any char apart from zero will be sent to VDP

printString:                
    ld a,(hl)						; put char byte into A
    or a  							; check if zero
    ret z  							; return if it is, as we are at the end of the zero terminated string
    rst.lil $10 					; send byte A to VDP
    inc hl 							; move to next byte in the string
    jr printString  				; loop around and test next byte

; ---------------------------------------------

; take A as number and print out as binary
; will destroy HL, BC

printBin:
	push bc  				; store BC for later
    ld b, 8 				; number of bits to do
    ld hl, binString
@rpt:
    ld (hl), 48     		; set our byte to '0' as default

    bit 7, a  				; check if bit is set
    jr z, @nxt  			; if not, move on to next bit
    ld (hl), 49  			; set our byte to '1'
@nxt:    
    inc hl  				; set next position in output 'binString'
    rla  					; rotate byte A so that bit 7 is next bit
    djnz @rpt   			; loop round until done 8 times

    ld hl, binString  		; HL is address of the 'binary' string of 8 bytes
    call printString 		; print the string at HL
    pop bc  				; restore BC
    ret

binString:  .asciz     "00000000" 	; 8 chars plus a zero

; ---------------------------------------------
;
; text data
;
; ---------------------------------------------

						; the title printed first
msg_title:				.asciz "GPIO Interrupt Handler "

						; some messages with coloured text
msg_PC0_pressed:		.asciz 17, 15, "Pin PC0 ", 17, 13, "LOW  (PRESSED)  ", 17, 15
msg_PC0_released:		.asciz 17, 15, "Pin PC0 ", 17, 9,  "HIGH (RELEASED) ", 17, 15
msg_PC1_pressed:		.asciz 17, 15, "Pin PC1 ", 17, 14, "LOW  (PRESSED)  ", 17, 15
msg_PC1_released:		.asciz 17, 15, "Pin PC1 ", 17, 12, "HIGH (RELEASED) ", 17, 15

; ---------------------------------------------
;
;	END
;
; ---------------------------------------------
