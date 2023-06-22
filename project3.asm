MyStack SEGMENT STACK
MyStack ENDS

;====================

MyData SEGMENT

msg DB "I do not know what a message could be so I put random stuff      "
msgLength EQU $ - msg
firstCharInBox DB 0
pause DB 0
ticks DW 0
scrollSpeed DB 18

double DB 0C9h, 0BBh, 0BCh, 0C8h, 0CDh, 0BAh
uLCorner EQU 0
uRCorner EQU 1
bRCorner EQU 2
bLCorner EQU 3
horizontal EQU 4
vertical EQU 5

location DW 160*7+40
fgColor DB 0111b
bgColor DB 0101b
boxWidth DB 16

MyData ENDS

;====================

MyCode SEGMENT

myMain PROC
    
    ASSUME DS:MyData, CS:MyCode

    MOV AX, MyData 
    MOV DS, AX          ; DS point to data segment
    MOV AX, 0B800h
    MOV ES, AX          ; ES points to screen memory segment

    CALL clearBox
    CALL userInput

    MOV AH, 4Ch     ; exit
    INT 21h         ;

myMain ENDP


;====================


userInput PROC

PUSH AX CX 


MOV CX, 1           ; while(true)
checkKeyLoop:

    MOV AH, 12h
    INT 16h

    TEST AX, 0001b
    JNZ growWiderJmp

    TEST AX, 0010b
    JNZ grownarrowerJmp

    MOV AH, 11h     ; check for key
    INT 16h         ;
    JZ nextLoop     ; next loop

    CALL clearBox   ; clear before next move

    MOV AH, 10h     ; get key
    INT 16h

    CMP AL, 1Bh     ; escape key
    JE escape       ; jump to exit program

    CMP AX, 1177h        ; W key because mac (should be ctrl/up)
    JE speedUpScrollJmp

    CMP AX, 1F73h        ; S key because mac (should be ctrl/down)
    JE slowDownScrollJmp

    CMP AX, 48E0h   ; up arrow key
    JE moveUpJmp

    CMP AX, 50E0h   ; down arrow key
    JE moveDownJmp

    CMP AX, 4BE0h   ; left arrow key
    JE moveLeftJmp

    CMP AX, 4DE0h   ; right arrow key
    JE moveRightJmp

    CMP AX, 2166h        ; f key
    JE changeFgColorJmp
    CMP AX, 2146h        ; F key
    JE changeFgColorJmp

    CMP AX, 3062h        ; b key
    JE changeBgColorJmp
    CMP AX, 3042h        ; B key
    JE changeBgColorJmp

    CMP AX, 3B00h        ; F1 key
    JE pauseJmp

    nextLoop:  
    CMP pause, 1
    JE skipScroll
    CALL scrollText
    skipScroll:
    CALL displayTime
    CALL drawBox    ; drawing the box

    CMP CX, 0       ; end of loop
    JA checkKeyLoop ;

    escape:
    MOV AH, 4Ch     ; exit
    INT 21h         ;

    speedUpScrollJmp:
    CALL speedUpScroll
    JMP nextLoop

    slowDownScrollJmp:
    CALL slowDownScroll
    JMP nextLoop

    growWiderJmp:
    CALL growWider
    JMP nextLoop

    growNarrowerJmp:
    CALL growNarrower
    JMP nextLoop

    moveUpJmp:
    CALL moveUp
    JMP nextLoop

    moveDownJmp:
    CALL moveDown
    JMP nextLoop

    moveLeftJmp:
    CALL moveLeft
    JMP nextLoop

    moveRightJmp:
    CALL moveRight
    JMP nextLoop

    changeFgColorJmp:
    CALL changeFgColor
    JMP nextLoop

    changeBgColorJmp:
    CALL changeBgColor
    JMP nextLoop

    pauseJmp:
    NEG pause      
    ADD pause, 1   
    CALL printText
    JMP nextLoop

    POP CX AX
    RET

userInput ENDP


;====================


scrollText PROC

PUSH AX CX DX

MOV AH, 0               ; get ticks
INT 1AH                 ; 

SUB DX, ticks           ; current ticks - last recorded ticks
CMP DL, scrollSpeed     ; compare with delay
JB dontUpdate           ; if the difference in times is bigger than delay
CALL printText          ; print the text
CALL updateFirstChar    ; update the first chatacter in the text
ADD ticks, DX           ; set current ticks
dontUpdate:

POP DX CX AX
RET

scrollText ENDP


;====================


printText PROC

PUSH AX BX CX DI SI

MOV SI, OFFSET msg          ; SI points to the string
MOV BL, firstCharInBox      
MOV BH, 0
ADD SI, BX                  ; SI set to first character to display after last call of this proc
MOV DI, location            ; set DI to location in box
ADD DI, 162                 ; 
MOV CL, boxWidth            ; set loop counter

LEA BX, msg                 ; points to last char in text (used for comparison later)
ADD BX, msgLength

printLoop:
    MOV AL, [SI]
    MOV ES:[DI], AL         ; print character
    INC SI                  ; load next character
    ADD DI, 2               ; next cell on screen
    CMP SI, BX              ; compare with last character to see if at end of text
    JNE continueLoop
    LEA SI, msg             ; wrap text
    continueLoop:
    LOOP printLoop

POP SI DI CX BX AX
RET

printText ENDP


;====================


updateFirstChar PROC

PUSH AX BX

; firstCharInBox := (firstCharInBox + 1) % msgLength
MOV AL, firstCharInBox
INC AX
MOV BL, msgLength
DIV BL
MOV firstCharInBox, AH

POP BX AX
RET

updateFirstChar ENDP


;====================


displayTime PROC

PUSH AX BX DX DI

MOV DI, 170

; 1000 x numSeconds = 55 * ticks
MOV AL, scrollSpeed
MOV BL, 55
MUL BL
; AX contains number of milliseconds

XOR DX, DX
MOV BX, 10
DIV BX
; AX contains a 2 or 3 digit number to convert to seconds

CMP DX, 5       ; compare remainder to round up
JL roundUp
INC AX          ; round up
roundUp:

; continue dividing by 10 and displaying the remainder

DIV BL              ; divide number by 10
ADD AH, '0'         ; add ascii 0 to display correctly
MOV ES:[DI], AH
SUB DI, 2           ; increment screen pointer

XOR AH, AH
DIV BL
ADD AH, '0'
MOV ES:[DI], AH
SUB DI, 2

MOV ES:[DI], BYTE PTR '.'   ; add decimal point
SUB DI, 2

XOR AH, AH
DIV BL
ADD AH, '0'
MOV ES:[DI], AH
SUB DI, 2

POP DI DX BX AX
RET

displayTime ENDP


;====================


speedUpScroll PROC

PUSH AX

CMP scrollSpeed, 51         ; compare with max delay
JGE dontSpeedUp
XOR AX, AX
MOV AL, scrollSpeed         ; divide delay by 5
MOV BL, 5                   ;
DIV BL                      ; 
ADD scrollSpeed, AL         ; add back for 120%
dontSpeedUp:

POP AX
RET

speedUpScroll ENDP


;====================


slowDownScroll PROC

PUSH AX

CMP scrollSpeed, 5          ; compare with min delay
JLE dontSlowDown
XOR AX, AX
MOV AL, scrollSpeed         ; divide delay by 5
MOV BL, 5                   ;
DIV BL                      ; 
SUB scrollSpeed, AL         ; sub back for 80%
dontSlowDown:

POP AX
RET

slowDownScroll ENDP


;====================


moveUp PROC

CMP location, 160     ; check upper bound
JL moveUpReturn    
SUB location, 160     ; move up
moveUpReturn:

RET

moveUp ENDP


;====================


moveDown PROC

PUSH AX BX CX

MOV AL, 10            ; height including sides
MOV BL, 160           
MUL BL                ; multiply 160 by height
MOV BX, 4000          
SUB BX, AX            ; get bottom left corner location
CMP location, BX      ; check lower bound
JGE moveDownReturn
ADD location, 160     ; move down
moveDownReturn:

POP CX BX AX
RET

moveDown ENDP


;====================


moveLeft PROC

PUSH AX BX DX

MOV AX, [location]
MOV BX, 160          
XOR DX, DX           ; clear DX
DIV BX               ; mod location by 160 to get column of top left corner
CMP DX, 2            ; check left bound
JL moveLeftReturn
SUB location, 2      ; move left
moveLeftReturn:

POP DX BX AX
RET

moveLeft ENDP


;====================


moveRight PROC

PUSH AX BX DX

MOV AX, [location]  ; top left location
MOV BX, 160         ; setup 160 for division
XOR DX, DX          ; clear dx
DIV BX              ; mod location by 160 to get column of top left corner
ADD DL, [boxWidth]  ; 2 * width + corners to get to top right corner
ADD DL, [boxWidth]  ; 
ADD DL, 4           ; add 4 for corners
CMP DX, 160         ; check right bound
JG moveRightReturn
ADD location, 2     ; move right
moveRightReturn:

POP DX BX AX
RET

moveRight ENDP


;====================


growWider PROC

PUSH AX CX DX

MOV AH, 0
INT 1AH

SUB DX, ticks
CMP DX, 3               ; 3 is the delay for resizing
JL growWiderReturn      ; if it hasn't been enough time don't resize
ADD ticks, DX           

CMP boxWidth, 40        ; max width
JG growWiderReturn
ADD boxWidth, 1         ; grow wider
CALL moveLeft           ; move left
CALL clearBox
growWiderReturn:

POP DX CX AX
RET

growWider ENDP


;====================


growNarrower PROC

PUSH AX CX DX

MOV AH, 0
INT 1AH

SUB DX, ticks 
CMP DX, 3               ; 3 is the delay for resizing
JL growNarrowerReturn   ; if it hasn't been enough time don't resize
ADD ticks, DX

CMP boxWidth, 4         ; min width
JL growNarrowerReturn
SUB boxWidth, 1         ; grow narrower
CALL clearBox
growNarrowerReturn:

POP DX CX AX
RET

growNarrower ENDP


;====================


changeFgColor PROC

PUSH AX

MOV AL, fgColor
INC AL          ; increment fgColor
AND AL, 0111b   ; stop overflow
MOV fgColor, AL

POP AX
RET

changeFgColor ENDP


;====================


changeBgColor PROC

PUSH AX

MOV AL, bgColor
INC AL          ; increment bgColor
AND AL, 0111b   ; stop overflow
MOV bgColor, AL

POP AX
RET

changeBgColor ENDP


;====================


clearBox PROC

PUSH AX CX DI

MOV DI, 0
MOV AX, 0720h   ; blank character
MOV CX, 2000    ; loop 2000 times

clearLoop:
    MOV ES:[DI], AX
    ADD DI, 2
    LOOP clearLoop

POP DI CX AX
RET

clearBox ENDP


;====================


drawBox PROC

PUSH AX BX CX SI DI

LEA SI, double              ; set SI to double line "array"

MOV AH, [bgColor]           ; set background color
SHL AH, 4                   ; 
ADD AH, [fgColor]           ; set foreground color

MOV DI, location            ; set DI to upper left corner location on screen
MOV AL, [SI+uLCorner]       ; move upper left corner into AL
MOV ES:[DI], AX             ; print colored upper left corner
                
MOV BL, [boxWidth]          ; add to DI to get right column location
SHL BL, 1                   ; multiply by 2 

MOV AL, [SI+uRCorner]       ; move upper right corner into AL
MOV ES:[DI + BX], AX        ; print colored upper right corner

MOV DI, location            ; set DI to upper left corner location on screen
MOV AL, [SI+vertical]       ; move vertical piece into AL
MOV CL, 8         ; set counter to inner height

leftRightLoop:
    ADD DI, 160             ; go to next row
    MOV ES:[DI], AX         ; print left
    MOV ES:[DI + BX], AX    ; print right

    LOOP leftRightLoop


ADD DI, 160                 ; go to next row
MOV AL, [SI+bLCorner]       ; move bottom left corner into AL
MOV ES:[DI], AX             ; print colored bottom left corner


MOV AL, [SI+bRCorner]       ; move bottom right corner into AL
MOV ES:[DI + BX], AX        ; print colored bottom right corner


MOV AL, [SI+horizontal]     ; move horizontal piece into AL
MOV CL, [boxWidth]          ; set counter to inner width
SUB CX, 1

bottomLoop:
    ADD DI, 2               ; go to next column
    MOV ES:[DI], AX         ; print 

    LOOP bottomLoop      


MOV DI, location            ; set DI to upper left corner
MOV CL, [boxWidth]          ; set counter to inner width (16)
SUB CX, 1

topLoop:
    ADD DI, 2               ; go to next column
    MOV ES:[DI], AX         ; print 

    LOOP topLoop   

POP DI SI CX BX AX
RET

drawBox ENDP


;====================


MyCode ENDS

;====================

end myMain