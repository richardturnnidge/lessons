	; AGON LIGHT
	; Keyboard Interrupt Example
	; Richard Turnnidge 2025

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

	macro MODE mode
	ld a, 22
	rst.lil $10
	ld a, mode
	rst.lil $10
	endmacro

; ---------------------------------------------

	macro SETCOLOUR col
	ld a, 17
	rst.lil $10
	ld a, col
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

colour: 	equ 17
white: 		equ 15
grey: 		equ 7
green: 		equ 10
red: 		equ 1

; ---------------------------------------------
;
;	GET READY
;
; ---------------------------------------------

	.assume adl=1		; big memory mode
	.org $40000		; load code here

	jp start_here		; jump to start of code

	.align 64		; MOS header
	.db "MOS",0,1

; ---------------------------------------------
;
;	START
;
; ---------------------------------------------

start_here:

	push af
	push bc
	push de
	push ix	 			; store everything as good practice
	push iy	 			; pop back when we return from code later

	MODE 8  			; set display to mode 8
	CLS  				; clear screen
	SETCURSOR 0  			; hide cursor
        SETCOLOUR white			; reset text colour to white

	ld hl, title_str		; data to send
	ld bc, end_title - title_str	; length of data
	rst.lil $18  			; print screen info text

	call setup_kb_handler 		; initiate keyboard intercepter

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

	jp MAIN_LOOP

; ---------------------------------------------
;
;	EXIT CODE CLEANLY
;
; ---------------------------------------------

exit_here:

        call reset_kb_handler  		; clear event handler

        SETCURSOR 1  			; make cursor visible again
        SETCOLOUR white			; reset text colour to white

	CLS  				; clear screen
		
	pop iy
	pop ix
	pop de
	pop bc
	pop af
	ld hl,0				; reset all values before returning to MOS

	ret				; return to MOS here

; ---------------------------------------------

setup_kb_handler:
        ld hl, on_keyboard_event  	; address of the routine to call
        ld c, 0  			; address length. 0 = 24bit, 1 = 16 bit
        moscall $1D        		; mos_setkbvector
        ret

; ---------------------------------------------

reset_kb_handler:
        ld hl, 0  			; nil address = clear event
        ld c, 0  			; address length. 0 = 24bit, 1 = 16 bit
        moscall $1D        		; mos_setkbvector
        ret

; ---------------------------------------------

; with each event, DE points to a structure of keyboard info
;        DE + 0        ; ascii code
;        DE + 1        ; modifier keys
;        DE + 2        ; fabgl vkey code
;        DE + 3        ; is key down?

on_keyboard_event:
        push bc
        push hl
        push ix  			; backup any registers we might use

        push de
        pop ix  			; put DE into IX for easier reading

        SETCOLOUR green			; reset text colour to white

	TABTO 17,6
	ld a, (ix+0)        		; ascii code
	call debugHex

	TABTO 17, 8
 	ld a, (ix+1)        		; modifier keys 
	call debugHex

 	TABTO 17, 10
 	ld a, (ix+2)        		; fabgl vkey code 
 	call debugHex

 	TABTO 17, 12
 	ld a, (ix+3)        		; is key down? 
 	call debugHex

        SETCOLOUR white			; reset text colour to white

        pop ix
        pop hl
        pop bc  			; restore registers

        ret

; ---------------------------------------------
;
;	TEXT AND DATA
;
; ---------------------------------------------

title_str:

	.db 31, 0,0,"Keyboard Interrupt example"	; text to show
	.db 31, 0,2,"VDP packet data"			; text to show

	.db 31, 0,6, colour, grey, "ASCII code:"	; text to show
	.db 31, 0,8, "Modifier code:"			; text to show
	.db 31, 0,10, "FabGL vKey code:"			; text to show
	.db 31, 0,12, "Up (0) Down (1):"		; text to show

	.db 31, 0,16, "Press ", colour, red, "ESC", colour, grey," to exit"	; text to show

end_title:

; ---------------------------------------------
;
;	OTHER ROUTINES
;
; ---------------------------------------------

; debug A to screen as HEX byte pair at current position

debugHex:			
	push af 
	push af  		; store A twice

	push af
	ld a, '$'
	rst.lil $10		; print the $ char
	pop af

	and 11110000b		; get higher nibble
	rra
	rra
	rra
	rra			; move across to lower nibble
	add a,48		; increase to ascii code range 0-9
	cp 58			; is A less than 10? (58+)
	jr c, @f		; carry on if less
	add a, 7		; add to get 'A' char if larger than 10
@@:	
	rst.lil $10		; print the A char

	pop af  		; get A back 
	and 00001111b		; now just get lower nibble
	add a,48		; increase to ascii code range 0-9
	cp 58			; is A less than 10 (58+)
	jp c, @f		; carry on if less
	add a, 7		; add to get 'A' char if larger than 10	
@@:	
	rst.lil $10		; print the A char
	
	pop af  		; get initial A back in case needed
	ret			; head back



; ---------------------------------------------
;
;	END
;
; ---------------------------------------------
