; AGON UART INTERRUPTS
; Richard Turnnidge 2025
; UART1 text receiver example

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
				
receiveBuffer:		EQU	$D0				; Receive buffer port ID

;	for UART1_Struct
UART1_BAUD: 		EQU 	31250;9600  	   	; baud_rate	(stored as three byte LONG) 31250 for midi
UART1_DATABITS: 	EQU 	8 			; data bits
UART1_STOPBITS:		EQU 	1 			; stop bits
UART1_PARITY: 		EQU 	0 			; parity bits
UART1_FLOW: 		EQU 	0			; flow control
UART1_INTERRUPT: 	EQU 	00000001b	; interrupt enabled (bit 1)		

;	interrupt bits:	    - Bit 0: Set to enable received data interrupt
;    					- Bit 1: Set to enable transmit data interrupt
;    					- Bit 2: Set to enable line status change interrupt
;    					- Bit 3: Set to enable modem status change interrupt
;    					- Bit 4: Set to enable transmit complete interrupt

; ---------------------------------------------
;
;	INITIALISE
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
	push af						; pop back when we return from code later
	push bc
	push de
	push ix
	push iy

	im 2

	ld a, 0
	ld (byte_count),a

	SETCURSOR 0
	call reset_buffer
	CLS
	call openUART1				; open serial port for comms

; ---------------------------------------------
;
;	MAIN LOOP
;
; ---------------------------------------------

MAIN_LOOP:	
	MOSCALL $08						; get IX pointer to sysvars
	ld a, (ix + 05h)				; ix+5h is 'last key pressed'
	cp 27							; is it ESC key?
	jp z, exit_here					; if so exit cleanly

	call display_buffer  			; print the buffer and char count

	jr MAIN_LOOP

; ---------------------------------------------

display_buffer:						; display the buffer contents

	TABTO 0, 0   					; set start position
	ld hl, msg_count 				; print "Count:"
	call printString

	ld a, (byte_count) 				; number of bytes received so far
 	call printDec   				; print count in decimal

	ld hl, LINEFEED					; address of newline char sequence
	call printString				; print a new line
	ld hl, LINEFEED					; address of newline char sequence
	call printString				; print a new line

	ld de, uart_buffer				; HL is start of received byte buffer
	ld b, 24						; will go through first 24 bytes only in this example

@loop:

	ld hl, clearLine
	call printString

	ld a, 00000010b
	call multiPurposeDelay

	ld a, (de)						; get buffer byte
	inc de   						; inc buffer offset for next time
	push bc  						; store B counter
	push de  						; store position into buffer
	push af  						; store our byte

	cp 31  							; compare with 31 (last of non-printing ascii codes)
	jr nc, @print_char  			; if <32 (non-printing), we just print an '?'
	ld a, '?'  						; replace with '?'

@print_char:
	rst.lil $10  					; just print the byte A

	ld a, ' '  						; put SPACE byte into A
	rst.lil $10  					; print a space for readability on screen

	pop af  						; get our original byte back
	call printDec 					; print decimal of byte

	ld hl, LINEFEED					; address of newline char sequence
	call printString				; print a new line

	pop de  						; get buffer offset position back
	pop bc  						; get B counter back
	djnz @loop						; go round again if not done all 24

	ret

; ---------------------------------------------
;
;	EXIT CODE CLEANLY
;
; ---------------------------------------------

exit_here:
	SETCURSOR 1
	call closeUART1
	CLS
	
	pop iy
	pop ix
	pop de
	pop bc
	pop af
	ld hl,0

	ret						; return to MOS here

; ---------------------------------------------
;
;	UART ROUTINES
;
; ---------------------------------------------

openUART1:
	ld ix, UART1_Struct  			; set IX to be the address of the STRUCT
	MOSCALL $15						; open uart1

   	ld hl, uart_isr_handler  		; address of interrupt service routine
	ld e, $1A        				; interrupt vector number (UART1)
	MOSCALL $14     				; mos_api_setintvector

	ld hl, uart_buffer
	ld (uart_buf_pos), hl			; set curent buffer write position

	ret 

; ---------------------------------------------

closeUART1:
	MOSCALL $16 					; close uart1
	ret 

; ---------------------------------------------

UART1_Struct:					; constants defined at start of program
	.dl 	UART1_BAUD 			; baud rate (stored as three byte LONG)
	.db 	UART1_DATABITS 		; data bits
	.db 	UART1_STOPBITS 		; stop bits
	.db 	UART1_PARITY 		; parity bits
	.db 	UART1_FLOW			; flow control
	.db 	UART1_INTERRUPT		; interrupt bits - bit 0 is enable received data interrupt

; ---------------------------------------------

uart_isr_handler:			; this is the interrupt service routine (ISR) that gets called
	di						; stop any other interrupts while we do this
	push af
	push hl 				; store any registers we are going to use

	; do ISR code here

	in0 a,(receiveBuffer)	; read byte from buffer

	ld hl,(uart_buf_pos)	; get curent buffer write position
	ld (hl), a 				; store byte received
	inc hl					; inc for next time
	ld (uart_buf_pos), hl  	; store pointer to buffer position

	ld a, (byte_count)
	inc a
	ld (byte_count),a  		; just counting the bytes coming in

	pop hl
	pop af					; return register values
	ei						; enable interrupts again

	reti.l  				; return from ISR

byte_count: 	.db 0		; count of bytes received, just for testing
uart_buf_pos:	.dl 0 		; current position into buffer memory


; ---------------------------------------------
;
;	OTHER ROUTINES
;
; ---------------------------------------------

; print decimal value of 0 -> 255 to screen at current TAB position

printDec:               ; debug A to screen as 3 char string pos

    ld (base),a         ; save

    cp 200              ; are we under 200 ?
    jr c,@under200      ; not 200+
    sub a, 200
    ld (base),a         ; sub 200 and save

    ld a, '2'           ; 2 in ascii
    rst.lil $10         ; print out a '200' digit

    jr @under100

@under200:
    cp 100              ; are we under 100 ?
    jr c,@under100      ; not 200+
    sub a, 100
    ld (base),a         ; sub 100 and save

    ld a, '1'           ; 1 in ascii
    rst.lil $10         ; print out a '100' digit

@under100:
    ld a, (base)        ; get last 2 digits as decimal
    ld c,a              ; store numerator in C
    ld d, 10            ; D will be denominator
    call C_Div_D        ; divide C by 10 to get two parts. 
                        ; A is the remainder, C is the int of C/D

    ld b, a             ; put remainder ascii into B

    ld a, c             ; get int div
    cp 0                ; if 0 (ie, number was <10)
    jr z, @lastBut1     ; just do last digit

    add a, 48           ; add 48 to make ascii of int C/D
    rst.lil $10         ; print out 10s digit
    jr @lastDigit

@lastBut1:
    add a, 48           ; add 48 to make ascii of int C/D
    rst.lil $10         ; print out 10s digit

@lastDigit:
    ld a,b              ; get remainder back
    add a, 48           ; add 48 to remainder to convert to ascii   
    rst.lil $10         ; print out last digit

    ret 

base:   .db     0       ; used in calculations

; ---------------------------------------------

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
    ld b,8              ; B is counter = 8
    xor a               ; [loop] clear flags
    sla c               ; C = C x 2
    rla                 ; A = A x 2 + Carry
    cp d                ; compare A with Denominator
    jr c,$+4            ; if bigger go to loop
    inc c               ; inc Numerator
    sub d               ; A = A - denominator
    djnz $-8            ; go round loop
    ret                 ; done 8 times, so return

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

reset_buffer:
	ld hl, blank
	ld de, uart_buffer
	ld bc, 24
	ldir
	ret 

; ---------------------------------------------
; routine waits a fixed time, then returns

multiPurposeDelay:	            		
	push bc 

				; arrive with A =  the delay byte. One bit to be set only.
	ld b, a 
	MOSCALL $08             ; get IX pointer to sysvars

waitLoop:

	ld a, (ix + 0)          ; ix+0h is lowest byte of clock timer

				; need to check if bit set is same as last time we checked.
				;   bit 0 - changes 128 times per second
				;   bit 1 - changes 64 times per second
				;   bit 2 - changes 32 times per second
				;   bit 3 - changes 16 times per second

				;   bit 4 - changes 8 times per second
				;   bit 5 - changes 4 times per second
				;   bit 6 - changes 2 times per second
				;   bit 7 - changes 1 times per second
				; eg. and 00000010b           ; check 1 bit only
	and b 
	ld c,a 
   	ld a, (oldTimeStamp)
  	cp c                    ; is A same as last value?
	jr z, waitLoop   	; loop here if it is
 	ld a, c 
 	ld (oldTimeStamp), a    ; set new value

 	pop bc
 	ret

oldTimeStamp:   .db 00h

; ---------------------------------------------
clearLine:  		.asciz "     ",8,8,8,8,8 		; 5 spaces then 5 backspaces
msg_count:    		.asciz "Count:"
LINEFEED:           .asciz "\r\n"
blank:  			.db ' '
uart_buffer:				
	.db	"                                                              "

; ---------------------------------------------
;
;	END
;
; ---------------------------------------------





