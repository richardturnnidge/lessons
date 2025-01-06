	; AGON & CONSOLE8
	; Joystick test app - interrupt driven mode 6 dual edge interrupt
	; Richard Turnnidge 2025

; ---------------------------------------------
;
;	MACROS
;
; ---------------------------------------------

	macro MOSCALL afunc
	ld a, afunc
	rst.lil $08
	endmacro

; ---------------------------------------------

	macro TABTO x,y
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


PD_DR:		equ 	$A2
PD_DDR:		equ 	$A3
PD_ALT1:	equ 	$A4
PD_ALT2:	equ 	$A5

joy1: 	equ 10101010b
btn1: 	equ 10100000b

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
	; store everything as good practice
	; pop back when we return from code later

	push af
	push bc
	push de
	push ix
	push iy

	im 2  								; make sure running in interrupt mode 2

	CLS
	SETCURSOR 0

	TABTO 2,8
	ld hl, msg_title
	call printString 					; print the demo title

	TABTO 2,15
	ld hl, msg_portC
	call printString 					; print the demo title

	TABTO 2,19
	ld hl, msg_portD
	call printString 					; print the demo title

	call setupIOinterruptPins

	call init_initerrupts

; ---------------------------------------------
;
;	MAIN LOOP
;
; ---------------------------------------------

MAIN_LOOP:

get_key_input:
	MOSCALL $08							; get IX pointer to sysvars
	ld a, (ix + 05h)					; ix+5h is 'last key pressed'

	cp 27								; is it ESC key?
	jp z, exit_here						; if so exit cleanly

	jp MAIN_LOOP

; ---------------------------------------------
;
;	EXIT CODE CLEANLY
;
; ---------------------------------------------

exit_here:

	call resetPins
	CLS
	SETCURSOR 1
										; reset all values before returning to MOS
	pop iy
	pop ix
	pop de
	pop bc
	pop af
	ld hl,0

	ret									; return to MOS here

; ---------------------------------------------
;
;	IO PORT INIT
;
; ---------------------------------------------

setupIOinterruptPins:

	di

	ld a, joy1
	out0 (PC_DR), a 					; set DR of all port C to 0

	ld a, $00
	out0 (PC_DDR), a 					; set DDR of all port C to 255

	ld a, $00
	out0 (PC_ALT1), a  					; set ALT1 of all port C to 255

	ld a, joy1
	out0 (PC_ALT2), a  					; set ALT2 of all port C to 255

	; port D - only need bits 4-7
	; as port is shared with other Agon tasks, we need to grab current 
	; value so we don't upset bits 0-3

	in0 a, (PD_DR)
	or 10100000b
	out0 ($a2), a 						; set DR of port D bits 4-7 to 255

	in0 a, (PD_DDR)
	and 00001111b
  	out0 (PD_DDR), a 					; set DDR of port D bits 4-7 to 0

	in0 a, (PD_ALT1)
	and 00001111b
  	out0 (PD_ALT1), a  					; set ALT1 of port D bits 4-7 to 0

	in0 a, (PD_ALT2)
	or 10100000b
 	out0 (PD_ALT2), a  					; set ALT2 of port D bits 4-7 to 255

 	ei

	ret 

; ---------------------------------------------

resetPins:

	di 

; clear port C
	ld a, $00
	out0 (PC_DR), a 					; set DR of all port C to 0 default - 158

	ld a, $00
	out0 (PC_DDR), a 					; set DDR of all port C to 0 - 159

	ld a, $00
	out0 (PC_ALT1), a  					; set ALT1 of all port C to 0 - 160

	ld a, $00
	out0 (PC_ALT2), a  					; set ALT2 of all port C to 0 - 161


; clear port D
	in0 a, (PD_DR)
	and 00001111b
	out0 ($a2), a 						; set DR of port D bits 4-7 to 0

	in0 a, (PD_DDR)
	and 00001111b
	out0 ($a3), a 						; set DDR of port D bits 4-7 to 0

	in0 a, (PD_ALT1)
	and 00001111b
	out0 ($a4), a 						; set ALT1 of port D bits 4-7 to 0

	in0 a, (PD_ALT2)
	and 00001111b
	out0 ($a5), a 						; set ALT2 of port D bits 4-7 to 0

 	ei 

	ret 

; ---------------------------------------------
;
;	INTERRUPT ROUTINES
;
; ---------------------------------------------

init_initerrupts:	

   	ld hl, isr_up_event  				; address of service routine to call
	ld e, $42       					; interrupt number (PC1)
	MOSCALL $14     					; mos_api_setintvector

   	ld hl, isr_down_event  				; address of service routine to call
	ld e, $46       					; interrupt number (PC3)
	MOSCALL $14     					; mos_api_setintvector

   	ld hl, isr_left_event  				; address of service routine to call
	ld e, $4A       					; interrupt number (PC5)
	MOSCALL $14     					; mos_api_setintvector

   	ld hl, isr_right_event  			; address of service routine to call
	ld e, $4E       					; interrupt number (PC7)
	MOSCALL $14     					; mos_api_setintvector

   	ld hl, isr_fire_event  				; address of service routine to call
	ld e, $5A       					; interrupt number (PD5)
	MOSCALL $14     					; mos_api_setintvector

   	ld hl, isr_fire2_event  			; address of service routine to call
	ld e, $5E       					; interrupt number (PD7)
	MOSCALL $14     					; mos_api_setintvector

	ret 

; ---------------------------------------------

isr_up_event:

	di
	push hl
	push af  
	push bc 

	call showPins

	in0 a, (PC_DR)
	ld b, a
	bit 1, b
	jr nz, @nope

	TABTO 2,10
	ld hl, msg_up_hit
	call printString
	jr @end

@nope:
	TABTO 2,10
	ld hl, msg_up_release
	call printString

@end:
	
	in0 a, (PC_DR)
	or joy1
	out0 (PC_DR), a 				; set DR of all port C to 255 default - 158

	pop bc
	pop af 
	pop hl

	ei  
	reti.l  						; return from interrupt routine  

; ---------------------------------------------

isr_down_event:

	di
	push hl
	push af  
	push bc 

	call showPins

	in0 a, (PC_DR)
	ld b,a

	bit 3, b
	jr nz, @nope

	TABTO 2,10
	ld hl, msg_down_hit
	call printString
	jr @end

@nope:
	TABTO 2,10
	ld hl, msg_down_release
	call printString

@end:

	in0 a, (PC_DR)
	or joy1
	out0 (PC_DR), a 				; set DR of all port C to 255 default - 158

	pop bc
	pop af 
	pop hl
	ei  
	reti.l  						; return from interrupt routine  

; ---------------------------------------------

isr_left_event:

	di
	push hl
	push af  
	push bc 

	call showPins

	in0 a, (PC_DR)
	ld b,a

	bit 5, b
	jr nz, @nope

	TABTO 2,10
	ld hl, msg_left_hit
	call printString
	jr @end

@nope:
	TABTO 2,10
	ld hl, msg_left_release
	call printString

@end:

	in0 a, (PC_DR)
	or joy1
	out0 (PC_DR), a 				; set DR of all port C to 255 default - 158

	pop bc
	pop af 
	pop hl
	ei  
	reti.l  						; return from interrupt routine  

; ---------------------------------------------

isr_right_event:

	di
	push hl
	push af  
	push bc 

	call showPins

	in0 a, (PC_DR)
	ld b,a

	bit 7, b
	jr nz, @nope

	TABTO 2,10
	ld hl, msg_right_hit
	call printString
	jr @end

@nope:
	TABTO 2,10
	ld hl, msg_right_release
	call printString

@end:

	in0 a, (PC_DR)
	or joy1
	out0 (PC_DR), a 				; set DR of all port C to 255 default - 158

	pop bc
	pop af 
	pop hl
	ei  
	reti.l  						; return from interrupt routine  

; ---------------------------------------------
; bit 5
isr_fire_event:

	di
	push hl
	push af  

	push bc 

	call showPins

	in0 a, (PD_DR)
	ld b,a

	bit 5, b
	jr nz, @nope

	TABTO 2,10
	ld hl, msg_fire_hit
	call printString
	jr @end

@nope:
	TABTO 2,10
	ld hl, msg_fire_release
	call printString

@end:

	in0 a, (PD_DR)
	or btn1
	out0 (PD_DR), a 				; set DR of all port C to 255 default - 158

	pop bc
	pop af 
	pop hl
	ei  
	reti.l  						; return from interrupt routine  

; ---------------------------------------------
; bit 7
isr_fire2_event:

	di
	push hl
	push af  
	push bc 

	call showPins

	in0 a, (PD_DR)
	ld b,a

	bit 7, b
	jr nz, @nope

	TABTO 2,10
	ld hl, msg_fire2_hit
	call printString
	jr @end

@nope:
	TABTO 2,10
	ld hl, msg_fire2_release
	call printString

@end:

	in0 a, (PD_DR)
	or btn1
	out0 (PD_DR), a 				; set DR of all port C to 255 default - 158

	pop bc
	pop af 
	pop hl
	ei  
	reti.l  						; return from interrupt routine  

; ---------------------------------------------


showPins:

	TABTO 2,16

	in0 a, (PC_DR)
	call printBin

	TABTO 2,20

	in0 a, (PD_DR)
	call printBin

	ret 

; ---------------------------------------------
;
;	OTHER ROUTINES
;
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

; ---------------------------------
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
;
;	TEXT DATA
;
; ---------------------------------------------

msg_title:			.asciz "Joystick Interrupt Handler "

msg_portC:			.asciz "Port C "
msg_portD:			.asciz "Port D "

msg_up_hit:			.asciz "UP Pressed       "
msg_up_release:		.asciz "UP Released      "

msg_down_hit:		.asciz "DOWN Pressed     "
msg_down_release:	.asciz "DOWN Released    "

msg_left_hit:		.asciz "LEFT Pressed     "
msg_left_release:	.asciz "LEFT Released    "

msg_right_hit:		.asciz "RIGHT Pressed    "
msg_right_release:	.asciz "RIGHT Released   "

msg_fire_hit:		.asciz "FIRE Pressed     "
msg_fire_release:	.asciz "FIRE Released    "

msg_fire2_hit:		.asciz "BLASTER Pressed  "
msg_fire2_release:	.asciz "BLASTER Released "


; ---------------------------------------------
;
;	END
;
; ---------------------------------------------
