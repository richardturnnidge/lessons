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
	push af							; we will pop back when we return from code later
	push bc
	push de
	push ix
	push iy

	im 2  							; make sure running in interrupt mode 2

	CLS  							; clear screen
	SETCURSOR 0  					; huide cursor

	TABTO 2,8  						; TAB to position on screen
	ld hl, msg  					; get pointer to message to print
	call printString 				; print the demo title

	ld hl,0  						; put 0 into HL
	ld (prt_irq_counter),hl  		; reset the counter we display

	ld a, 10 						; freq of timer
	ld (prt_freq), a  				; store it
	call printHex  					; print the freq

	ld hl, msg2  					; get pointer to message to print
	call printString 				; print 'Hz'

;	the next calls set up the timer

	call stop_timer					; disable timer in case already running (by another program)

	call set_timer_freq  			; config timer frequency

	ld hl, timer_isr  				; HL = address of service routine to call
	call set_timer_ISR  			; define ISR address

	call start_timer  				; start the timer interrupt going

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

	; all we do here is wait until ESC key is pressed
	; all other updates are in the interrupt service routine

	jr MAIN_LOOP

; ---------------------------------------------
;
;	EXIT CODE CLEANLY
;
; ---------------------------------------------

exit_here:


	call stop_timer					; disable timer so it doesn't keep running after we exit!
	
	CLS
	SETCURSOR 1

	pop iy
	pop ix
	pop de
	pop bc
	pop af
	ld hl,0

	ret								; return to MOS here



; ---------------------------------------------
;
;	INTERRUPT TIMER ROUTINES - using timer id 1 (TMR1_CTL)
;
; ---------------------------------------------

; start the timer interrupt

start_timer:

	; enable timer, with interrupt and CONTINUOUS mode, clock divider 256
	ld a, PRT_IRQ_0 | IRQ_EN_1 | PRT_MODE_1 | CLK_DIV_256 | RST_EN_1 | PRT_EN_1 ; define settings
	out0 (TMR1_CTL),a  															; set the timer

	ret 

; ---------------------------------------------
; set the timer's interrupt service routine. 
; Arrive with HL = ISR address (timer_isr in this example)

set_timer_ISR:

	ld e, $0C       					; interrupt number (PRT 1)
	MOSCALL $14     					; mos_api_setintvector

	ret

; ---------------------------------------------
; set the timer's frequency

set_timer_freq:
	ld a, (prt_freq)  					; get frequency wanted
	ld c, a  							; put into C for division code

	; now work out the reload values, based on C being given as frequency/sec
	ld hl, prt_reload_default  			; this is the reload timer default value
	call HL_Div_C 						; C is freq we want to calulate
										; HL is returned with new value

	; set reload values into the PRT registers
	out0 (TMR1_RR_L),l  				; L is low byte of timer
	out0 (TMR1_RR_H),h  				; H is high byte of timer  

	ret

; ---------------------------------------------
; stop the timer interrupt

stop_timer:

	; disable timer
	ld a, PRT_IRQ_0 | IRQ_EN_0 | PRT_MODE_0 | CLK_DIV_256 | RST_EN_1 | PRT_EN_0 ; define settings
	out0 (TMR1_CTL),a  															; set the timer

	ret

; ---------------------------------------------
; Programmable Reload Timer - interrupt service routine gets called at pre-defined frequency

timer_isr:

	di								; stop any other interrupts while we do this
	push af
	push hl 						; store any registers we are going to use

	; do ISR code here
	in0 a,(TMR1_CTL)				; reset current interrupt. 

	ld hl, (prt_irq_counter)		; get current counter
	inc hl  						; inc clounter
	ld (prt_irq_counter),hl 		; store counter


	TABTO 2,10  					; TAB to screen position
	ld hl,(prt_irq_counter)  		; get current counter
	ld a, h  						; put high byte into A
	call printHex  					; print value

	TABTO 4,10  					; TAB to screen position
	ld hl,(prt_irq_counter)  		; get current counter
	ld a, l  						; put low byte into A  
	call printHex  					; print value

	pop hl
	pop af							; return register values

	ei								; enable interrupts again

	reti.l  						; return from interrupt routine

; ---------------------------------------------
;
;	OTHER FUNCTIONS
;
; ---------------------------------------------

; 24 bit division by 8 bit value
;Inputs:
;     HL is the numerator
;     C is the denominator
;Outputs:
;     A is the remainder
;     B is 0
;     C is not changed
;     DE is not changed
;     HL is the quotient

HL_Div_C:

	ld b,24 				; 16 for non ADL mode
	xor a
		add hl,hl
		rla
		cp c
		jr c,$+4
			inc l
			sub c
		djnz $-7
	ret

; ---------------------------------------------
; print hex value of 0 -> 255 to screen at current TAB position

printHex:				
	push af				; store A for later
	and 11110000b		; get higher nibble
	rra
	rra
	rra
	rra					; move across to lower nibble
	add a,48			; increase to ascii code range 0-9
	cp 58				; is A less than 10? (58+)
	jr c, @f			; carry on if less
	add a, 7			; add to get 'A' char if larger than 10
@@:	
	rst.lil $10			; print the A char

	pop af  			; get original A back again
	and 00001111b		; now just get lower nibble
	add a,48			; increase to ascii code range 0-9
	cp 58				; is A less than 10 (58+)
	jp c, @f			; carry on if less
	add a, 7			; add to get 'A' char if larger than 10	
@@:	
	rst.lil $10			; print the A char
	
	ret					; head back

; ---------------------------------------------
; print zero terminated string. Arrive with HL pointer to string.

printString:                
    ld a,(hl)
    or a
    ret z
    RST.LIL 10h
    inc hl
    jr printString

; ---------------------------------------------
; 
; 	TEXT and VARIABLES
;
; ---------------------------------------------

msg:				.asciz 17,13,"Programmable Reload Timer "
msg2:				.asciz " Hz.", 17, 15

prt_irq_counter:	.dl 0  			; what we update on screen
prt_freq: 			.db 0  			; how often the timer runs


; ---------------------------------------------
;
;	TIMER CONSTANTS
;
; ---------------------------------------------

prt_reload_default: equ $FFFF 			; default value of reload timer

TMR1_CTL:      equ $83 					; timer 1 control setup port ID
TMR1_RR_L:     equ $84 					; timer 1 reload counter Low byte port ID
TMR1_RR_H:     equ $85					; timer 1 reload counter High byte port ID

; Timer Control Register Bit Definitions
; Only some used in this demo, but others for reference

TMR_CTL:       equ 80h  				; base address of timer controls

PRT_IRQ_0:    equ %00000000 ; The timer does not reach its end-of-count value. 
                            ; This bit is reset to 0 every time the TMRx_CTL register is read.
PRT_IRQ_1:    equ %10000000 ; The timer reaches its end-of-count value. If IRQ_EN is set to 1,
                            ; an interrupt signal is sent to the CPU. This bit remains 1 until 
                            ; the TMRx_CTL register is read.

IRQ_EN_0:     equ %00000000 ; Timer interrupt requests are disabled.
IRQ_EN_1:     equ %01000000 ; Timer interrupt requests are enabled.

PRT_MODE_0:   equ %00000000 ; The timer operates in SINGLE PASS mode. PRT_EN (bit 0) is reset to
                            ;  0,and counting stops when the end-of-count value is reached.
PRT_MODE_1:   equ %00010000 ; The timer operates in CONTINUOUS mode. The timer reload value is
                            ; written to the counter when the end-of-count value is reached.

; CLK_DIV is a 2-bit mask that sets the timer input source clock divider
CLK_DIV_256:  equ %00001100 ; 
CLK_DIV_64:   equ %00001000 ; 
CLK_DIV_16:   equ %00000100 ;
CLK_DIV_4:    equ %00000000 ;

RST_EN_0:     equ %00000000 ; The reload and restart function is disabled. 
RST_EN_1:     equ %00000010 ; The reload and restart function is enabled. 
                            ; When a 1 is written to this bit,the values in the reload registers
                            ;  are loaded into the downcounter when the timer restarts. The 
                            ; programmer must ensure that this bit is set to 1 each time 
                            ; SINGLE-PASS mode is used.

; disable/enable the programmable reload timer
PRT_EN_0:     equ %00000000 ;
PRT_EN_1:     equ %00000001 ;

; Table 37. Timer Input Source Select Register
; Each of the 4 timers are allocated two bits of the 8-bit register
; in little-endian order,with TMR0 using bits 0 and 1,TMR1 using bits 2 and 3,etc.
;   00: System clock / CLK_DIV
;   01: RTC / CLK_DIV
;   NOTE: these are the values given in the manual,but it may be a typo
;   10: GPIO port B pin 1.
;   11: GPIO port B pin 1.
TMR_ISS:   equ 92h ; register address

; Table 51. Real-Time Clock Control Register
RTC_CTRL: equ EDh ; register address

; alarm interrupt disable/enable
RTC_ALARM_0:    equ %00000000
RTC_ALARM_1:    equ %10000000

; interrupt on alarm disable/enable
RTC_INT_ENT_0:  equ %00000000
RTC_INT_ENT_1:  equ %01000000

RTC_BCD_EN_0:   equ %00000000   ; RTC count and alarm registers are binary
RTC_BCD_EN_1:   equ %00100000   ; RTC count and alarm registers are BCD

RTC_CLK_SEL_0:  equ %00000000   ; RTC clock source is crystal oscillator output (32768 Hz). 
                                ; On-chip 32768 Hz oscillator is enabled.
RTC_CLK_SEL_1:  equ %00010000   ; RTC clock source is power line frequency input as set by FREQ_SEL.
                                ; On-chip 32768 Hz oscillator is disabled.

RTC_FREQ_SEL_0: equ %00000000   ; 60 Hz power line frequency.
RTC_FREQ_SEL_1: equ %00001000   ; 50 Hz power line frequency.

RTC_SLP_WAKE_0: equ %00000000   ; RTC does not generate a sleep-mode recovery reset.
RTC_SLP_WAKE_1: equ %00000010   ; RTC generates a sleep-mode recovery reset.

RTC_UNLOCK_0:   equ %00000000   ; RTC count registers are locked to prevent Write access.
                                ; RTC counter is enabled.
RTC_UNLOCK_1:   equ %00000001   ; RTC count registers are unlocked to allow Write access. 
                                ; RTC counter is disabled.


