;  _ _ ___ ____ _ _ ___
; | | | _ [_[] ] | | _ |
; | ,,|   / |_|| | | _ |
; \_@@|_|_\_(_)\___|___|      
;  (.)\  /ES\  /FF\    ~
;   |\A\/L/\n\/U/\.\/\~
;   ^ \PP/  \ST/  \../
;      ``    ``


; Change direction: W A S D

define appleL         $00 ; screen location of apple, low byte
define appleH         $01 ; screen location of apple, high byte
define snakeHeadL     $10 ; screen location of snake head, low byte
define snakeHeadH     $11 ; screen location of snake head, high byte
define snakeBodyStart $12 ; start of snake body byte pairs
define snakeDirection $02 ; direction (possible values are below)
define snakeLength    $03 ; snake length, in bytes
define appleColor     $04 ;
define snakeColors    $0900 ;
define spinCycles     $05 ;

; page 0 (@ 0000) used for snake locations
; page 1 (@ 0100) used for stack
; page 2-5 screen
; page 6-? program opcodes.
; thus, use page @0900 -> page 9 for storing snake colors. Not using zero page incurs many cycles for drawing the snake at every loop.

; set snake body colors
lda #$00 
sta snakeColors ; trail color 
lda #$05
ldx #$02
sta snakeColors,x ; tail color

ldx #$20 ; set game speed. 
stx spinCycles ; 
; note: When spinCycles reaches 0, game cannot run any faster. Game starts to slow down at this point.

; Directions (each using a separate bit)
define movingUp      1
define movingRight   2
define movingDown    4
define movingLeft    8

; ASCII values of keys controlling the snake
define ASCII_w      $77
define ASCII_a      $61
define ASCII_s      $73
define ASCII_d      $64

; System variables
define sysRandom    $fe
define sysLastKey   $ff

  jsr init
  jsr loop

init:
  jsr initSnake
  jsr generateApplePosition
  rts

initSnake:
  lda #movingRight  ;start direction
  sta snakeDirection

  lda #4  ;start length (2 segments)
  sta snakeLength
  
  lda #$11
  sta snakeHeadL
  
  lda #$10
  sta snakeBodyStart
  
  lda #$0f
  sta $14 ; body segment 1
  
  lda #$04
  sta snakeHeadH
  sta $13 ; body segment 1
  sta $15 ; body segment 2
  rts

generateApplePosition:
  ;load a new random byte into $00
  
  lda sysRandom
  and #$0f ; discard high bit
  cmp #$00 ; dissallow black
  beq addOne 
  cmp #$05 ; dissallow green
  beq addOne
  bne storeColor
  addOne:
    adc #$01
  storeColor:
  sta appleColor

  lda sysRandom
  sta appleL

  ;load a new random number from 2 to 5 into $01
  lda sysRandom
  and #$03 ;mask out lowest 2 bits
  clc
  adc #2
  sta appleH
 
  rts

loop:
  jsr readKeys
  jsr checkCollision
  jsr updateSnake 
  jsr drawApple  
  jsr drawSnake
  jsr spinWheels
  jmp loop

readKeys:
  lda sysLastKey
  cmp #ASCII_w
  beq upKey
  cmp #ASCII_d
  beq rightKey
  cmp #ASCII_s
  beq downKey
  cmp #ASCII_a
  beq leftKey
  rts
upKey:
  lda #movingDown
  bit snakeDirection
  bne illegalMove

  lda #movingUp
  sta snakeDirection
  rts
rightKey:
  lda #movingLeft
  bit snakeDirection
  bne illegalMove

  lda #movingRight
  sta snakeDirection
  rts
downKey:
  lda #movingUp
  bit snakeDirection
  bne illegalMove

  lda #movingDown
  sta snakeDirection
  rts
leftKey:
  lda #movingRight
  bit snakeDirection
  bne illegalMove

  lda #movingLeft
  sta snakeDirection
  rts
illegalMove:
  rts

checkCollision:
  jsr checkAppleCollision
  jsr checkSnakeCollision
  rts

checkAppleCollision:
  lda appleL
  cmp snakeHeadL
  bne doneCheckingAppleCollision
  lda appleH
  cmp snakeHeadH
  bne doneCheckingAppleCollision

  ;eat apple
  lda spinCycles
  cmp #$00
  beq maxPerfReached
  dec spinCycles ; remove ~24 wasted cycles
  maxPerfReached: ; cannot decrease beyond 0
  ldy snakeLength
  lda appleColor
  sta snakeColors,Y
  inc snakeLength
  inc snakeLength ;increase length
  jsr generateApplePosition
doneCheckingAppleCollision:
  rts

checkSnakeCollision:
  ldx #2 ;start with second segment
snakeCollisionLoop:
  lda snakeHeadL,x
  cmp snakeHeadL
  bne continueCollisionLoop

maybeCollided:
  lda snakeHeadH,x
  cmp snakeHeadH
  beq didCollide

continueCollisionLoop:
  inx
  inx
  cpx snakeLength          ;got to last section with no collision
  beq didntCollide
  jmp snakeCollisionLoop

didCollide:
  jmp gameOver
didntCollide:
  rts

updateSnake:
  ldx snakeLength
  dex
  txa
updateloop:
  lda snakeHeadL,x
  sta snakeBodyStart,x
  dex
  bpl updateloop

  lda snakeDirection
  lsr
  bcs up
  lsr
  bcs right
  lsr
  bcs down
  lsr
  bcs left
up:
  lda snakeHeadL
  sec
  sbc #$20
  sta snakeHeadL
  bcc upup
  rts
upup:
  dec snakeHeadH
  lda #$1
  cmp snakeHeadH
  beq collision
  rts
right:
  inc snakeHeadL
  lda #$1f
  bit snakeHeadL
  beq collision
  rts
down:
  lda snakeHeadL
  clc
  adc #$20
  sta snakeHeadL
  bcs downdown
  rts
downdown:
  inc snakeHeadH
  lda #$6
  cmp snakeHeadH
  beq collision
  rts
left:
  dec snakeHeadL
  lda snakeHeadL
  and #$1f
  cmp #$1f
  beq collision
  rts
collision:
  jmp gameOver

drawApple:
  ldy #0
  lda appleColor ; sysRandom
  sta (appleL),y
  sta appleColor
  rts

drawSnake:
  ldx #0
  lda #5 ; green
  sta (snakeHeadL,x) ; paint head
	
  ;paint body and trail. 
  ldx snakeLength  
  ldy #$00
  drawBelly:
   lda snakeColors,y ; 5 cycles
   sta (snakeHeadL,x) ; 6 cycles
   dex ; 2 cycles
   dex ; ...
   iny ; ...
   iny ; ...
   cpx #$00 ; 2 cycles
   bne drawBelly ; 3 cycles
   ; -1 if branch fails
   ; $0766    d0 f3     BNE $075b -> no page crossing
   ; total ~24 cycles per segment   
  rts

spinWheels:
  ldx spinCycles
  beq noSpin ; don't spin if spinCycles = 0.
  spinCycle:
    ldy #$02 
    spinloop:
      nop ; 
      nop ; 
      nop ;
      nop ; 2*4
      dey ; 2
      bne spinloop ; 3 first time , 2 on exit
      ;2*4*2+2*2+3+2 = 25 cycles.
  dex
  bne spinCycle
  noSpin:
  rts

gameOver:
