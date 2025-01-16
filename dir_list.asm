    .assume adl=1                       ; ez80 ADL memory mode
    .org $40000                         ; load code here

    jp start_here                       ; jump to start of code

    .align 64                           ; MOS header
    .db "MOS",0,1     

    macro MOSCALL afunc
        ld a, afunc
        rst.lil $08
    endmacro

start_here:
            
    push af                             ; store all the registers
    push bc
    push de
    push ix
    push iy

; ------------------
                                        

    ld hl, directoryPath                ; where to store result
    ld bc, 255                          ; max length
    MOSCALL $9E                         ; MOS api get current working directory

    ld hl, printDirHeading              ; Sending initial text message
    call printString

    ld hl, directoryPath                ; get pointer to the path
    ld bc, 0
    ld a, 0                             ; it will be 0 terminated
    rst.lil $18                         ; print result to screen

    ld hl, printCR                      ; address of string
    call printString                    ; print lf/cr 


                                        ; now get dir info

    ld hl, DIR_struct                   ; define where to store directory info
    ld de, directoryPath                ; this is pointer to the path to the directory
    MOSCALL $91                         ; open dir


_readFileInfo:                          ; we will loop here until all files have been processed

    ld hl, DIR_struct                   ; HL is where to get directory info
    ld de, FILINFO_struct               ; define where to store current file info
    MOSCALL $93                         ; read from dir

    ld a, (fname)                       ; get first char of file name
    cp 0                                ; if 0 then we are at the end of the listing
    jr z, _allDone

    ld hl, fname                        ; this is pointer to the name of current file
    ld bc, 0
    ld a, 0                             ; name will end with a 0
    rst.lil $18                         ; print to screen

    ld hl, printCR                      ; now print a carriage retrun before the next entry
    call printString

    jr _readFileInfo                    ; loop around to check next entry

_allDone:


    ld hl, DIR_struct                   ; load H: with address of the DIR struct
    MOSCALL $92                         ; close dir


; ------------------
; This is where we exit the program

    pop iy                              ; Pop all registers back from the stack
    pop ix
    pop de
    pop bc
    pop af
    ld hl,0                             ; Load the MOS API return code (0) for no errors.
    ret                                 ; Return to MOS

; ------------------
; Some data stored here

printDirHeading:
    .db     "Our current directory is:\r\n",0       ; text to print

printCR:
    .db     "\r\n",0                                ; text to print

directoryPath:    .BLKB     256,0                     ; 256 x 0 bytes allocated for path name

; ------------------
; Routine to print zero terminated string

printString:                                    
    ld a,(hl)
    or a
    ret z
    RST.LIL 10h
    inc hl
    jr printString

; ------------------
; Structures used in the code above

DIR_struct:             
dptr:       .BLKB  4,0   ; Current read/write offset
clust:      .BLKB  4,0   ; Current cluster
sect:       .BLKB  4,0   ; Current sector (0:Read operation has terminated)
dir:        .BLKB  3,0   ; Pointer to the directory item in the win[]
fn:         .BLKB  12,0  ; SFN (in/out) {body[8],ext[3],status[1]}
blk_ofs:    .BLKB  4,0   ; Offset of current entry block being processed (0xFFFFFFFF:Invalid)
end_DIR_struct:


FILINFO_struct:               
fsize:      .BLKB  4,0   ; File size
fdate:      .BLKB  2,0   ; Modified date
ftime:      .BLKB  2,0   ; Modified time
fattrib:    .BLKB  1,0   ; File attribute
altname:    .BLKB  13,0  ; Alternative file name
fname:      .BLKB  256,0 ; Primary file name
end_FILINFO_struct:




