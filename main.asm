INCLUDE "hardware.inc"
INCLUDE "data.inc"

DEF OBJCOUNT EQU 1
DEF END EQU 10
DEF BGWIN EQU 1
DEF BGLOSE EQU 2
DEF BGEND  EQU 3
DEF ORIGIN_y EQU 16
DEF ORIGIN_x EQU 8
DEF TILELENGTH EQU 8
DEF INTMAX EQU 255
DEF NEXTLINE EQU 32 
DEF DELAY EQU 50
DEF BUFFLENGTH EQU 3
DEF COUNTERPLACE EQU 520
DEF WINX EQU 8
DEF WINY EQU 9
DEF OBJECTID EQU 13
SECTION "Header", ROM0[$100]
  jp EntryPoint

  ds $150 - @, 0

EntryPoint:
  call WaitVBlank
  xor a
  ld [rLCDC], a

  ld a,%11111100 ; black and white palette
  ld [rOBP0], a
  ld a,%11100100 ; grey palettle
  ld [rBGP],  a

  call   CopyTileDataToVRAM
  ld a, LCDCF_ON | LCDCF_OBJON | LCDCF_BGON | LCDCF_BG8000
  ld [rLCDC], a
;______________________state_______________________________
FristCase:
;Innitialize
  ld a,0
  ld [stage],a
  call   WaitVBlank
  xor a
  ld [rLCDC], a
  call   CopyBGToVRAM
  call   ResetOAM
  ld a, LCDCF_ON | LCDCF_OBJON | LCDCF_BGON | LCDCF_BG8000
  ld [rLCDC], a
.loop:
;check if change state
  call readKeys
  ld hl, current
  bit 0,[hl]
  jr z, .loop
  ld a,1
  ld [stage],a
  jp MoveCase
;____________________________________________________________
MoveCase:
;Innitialize
  call   WaitVBlank
  xor a
  ld [rLCDC], a
  call   CopyBGToVRAM
  call   ResetOAM
  call   ResetCounter
  call   InitializeObjects
  call   CopyObjectToOAM

; LCD on, enable object layer (no background)
  ld a, LCDCF_ON | LCDCF_OBJON | LCDCF_BGON | LCDCF_BG8000
  ld [rLCDC], a
.move_loop:
;check if change state
  call readKeys
  call CheckResetAndFast
  call CheckPressChoise
  ld a,[object_type]
  or 0
  jr nz, .move
  call UpdateObjects
  jr .end
.move:
  call CheckMove
  ld a, [move_flag]
  cp 1
  call z, Count         ;increase counter and check lose

  ld a,[object_type]    ;Check Win
  cp 2
  jr nz, .end
  ld a,[Face_x]
  cp WINX
  jr nz, .end
  ld a,[Face_y]
  cp WINY
  jr nz, .end
  ld a,[stage]
  cp END
  jp z, EndCase
  jp WinCase
.end:
  call WaitVBlank
  call CopyObjectToOAM
  jr .move_loop
;__________________________________________________________
WinCase:
;Innitialize
  ld a,BGWIN
  ld [bg],a
  call   WaitVBlank
  xor a
  ld [rLCDC], a
  call   CopyBGToVRAM_W_L_E
  call   ResetOAM
  ld a, LCDCF_ON | LCDCF_OBJON | LCDCF_BGON | LCDCF_BG8000
  ld [rLCDC], a
.winloop:
;check if change state
  call readKeys
  ld hl,current
  bit 0,[hl]
  jp nz, MoveCase
  bit 1,[hl]
  jr z, .winloop
  ld a,[stage]
  cp END
  jp z, EndCase
  inc a
  ld [stage],a
  jp MoveCase 
;____________________________________________________________
LoseCase:
;Innitialize
  ld a,BGLOSE
  ld [bg],a
  call   WaitVBlank
  xor a
  ld [rLCDC], a
  call   CopyBGToVRAM_W_L_E
  call   ResetOAM
  ld a, LCDCF_ON | LCDCF_OBJON | LCDCF_BGON | LCDCF_BG8000
  ld [rLCDC], a
.loseloop:
;check if change state
  call readKeys
  ld hl,current
  bit 0,[hl]
  jp nz, MoveCase
  bit 1,[hl]
  jr z, .loseloop
  jp FristCase
;_______________________________________________________________
EndCase:
;Innitialize
  ld a,BGEND
  ld [bg],a
  call   WaitVBlank
  ld a,0
  ld [rLCDC], a
  call   CopyBGToVRAM_W_L_E
  call   ResetOAM
  ld a, LCDCF_ON | LCDCF_OBJON | LCDCF_BGON | LCDCF_BG8000
  ld [rLCDC], a
.endloop:
;check if change state
  call readKeys
  ld hl,current
  bit 0,[hl]
  jr z, .endloop
  jp FristCase
;_________________________________________________________________
SECTION "Functions", ROM0

InitializeObjects:
  ld a,1
  ld [Paused],a
  xor a
  ld [object_type],a
  ld [move_flag], a
  ld hl,   Face_x   ; hl points to first object entry
  ld a, 8
  ld [hli], a
  ld [hl],3
  ret

CopyObjectToOAM:
  ld a,[Face_y]
  ld b,a
  ld a,[Face_x]
  ld c,a
  call ConvertCoord
  ld hl,_OAMRAM
  ld a,b
  ld [hli],a
  ld a,c
  ld [hli],a
  ld [hl], OBJECTID
  ret

CheckResetAndFast:
  ld a, [current]
  bit 0, a       ;press A to go select
  jp nz, MoveCase
  bit 3, a
  jp nz, WinCase
  ret

ResetCounter:
  xor a
  ld [counter], a
  ld [buffer+2], a
  ret

UpdatePaused:
; check if A key was pressed
; if yes, toggle the Paused variable between 0 and 1
  ld hl, current
  bit 2, [hl]      ;Press B to sselect
  jr z, .pause     ; If (0) A was not pressed, do nothig
  ld hl, Paused
  ld a,  [hl]
  xor 1
  ld [hl],a
.pause:
  ret

CheckPressChoise:
;check the value of Paused
;if Paused == 1, we are not in choose case
;if Paused == 0, we check if it is in the corner
  call UpdatePaused
  ld a, [Paused]
  and a
  jr nz, .nothing
  call  Check_corner
  ret
.nothing:
  xor a
  ld [object_type],a
  ret



Check_corner:
;check if it is in the corner 
;return which kind of pices it is
  ld a,[Face_x]
  ld c,a
  ld a,[Face_y]
  ld b,a
  call FromVariableToBG  
  ld a, [hl]

  cp 7
  jr nc, .nothing 
  ld hl, .jumptable
  ld e,a
  ld d,0
  add hl, de
  add hl, de
  ld a, [hli]
  ld h, [hl]
  ld l, a
  jp hl

.jumptable:
  dw .nothing
  dw .nothing
  dw .object2_4
  dw .object4_4
  dw .object4_2
  dw .object2_2

.nothing:
  ld a, 1
  ld [Paused], a
  ret

.object2_4:
  ld a,1
  ld [object_type], a
  ret
    
.object4_4:
  ld a,2
  ld [object_type], a
  ret
    
.object4_2:
  ld a,3
  ld [object_type], a
  ret
    
.object2_2:
  ld a,4
  ld [object_type], a
  ret

;---------------------------------------------------------------------
readKeys:
;---------------------------------------------------------------------
; Output:
; b : raw state:   pressing key triggers given action continuously
;                  as long as it is pressed
; c : rising edge: pressing key triggers given action only once,
;                  key must be released and pressed again
  ld    a,$20
  ldh   [rP1],a   
  ldh   a,[rP1]
  ldh   a,[rP1]
  cpl
  and   $0f         ; lower nibble has down, up, left, right
  swap	a           ; becomes high nibble
  ld	b,a
  ld    a,$10
  ldh   [rP1],a
  ldh   a,[rP1]
  ldh   a,[rP1]
  ldh   a,[rP1]
  ldh   a,[rP1]
  ldh   a,[rP1]
  ldh   a,[rP1]
  cpl
  and   $0f         ; lower nibble has start, select, B, A
  or    b
  ld    b,a

  ld    a,[previous]  ; load previous state
  xor   b	      ; result will be 0 if it's the same as current read
  and   b	      ; keep buttons that were pressed during this read only
  ld    [current],a   ; store result in "current" variable and c register
  ld    c,a
  ld    a,b           ; current state will be previous in next read
  ld    [previous],a

  ld    a,$30         ; reset rP1
  ldh   [rP1],a
  ret

ConvertCoord:
;we convert coordinate from background coordinate to OAM coordinate
;when call this function,  x,y need in c,b
;return x,y are load in c,b
  ld a,b
multy:
  add a
  add a
  add a
  add ORIGIN_y
  ld b,a

  ld a,c
multx:
  add a
  add a
  add a
  add ORIGIN_x
  ld c,a
  ret

FromVariableToBG:
;when call this function, x,y need in c,b
;return x,y are load in l,h
;we don't change the value of b,c
  ld h,0
  ld l,b
  ld d,5
.multiple:
  add hl, hl
  dec d
  jr nz, .multiple
  ld e,c
  add hl,de
  ld de,_SCRN0
  add hl,de
  ret

UpdateObjects:
;in here we check which the objeck move
  ld a, [current]
  bit 5,a
  call nz, GoLeft
  ld a, [current]
  bit 6,a 
  call nz, GoUp
  ld a, [current]
  bit 4,a
  call nz, GoRight
  ld a, [current]
  bit 7,a
  call nz, GoDown
  ret

GoLeft:
  ld a,[Face_y]
  ld b,a
  ld a,[Face_x]
  ld c,a
  dec c
  call FromVariableToBG
  ld a,[hl] 
  cp 1
  ret z
  ld hl, Face_x
  dec [hl]
  dec [hl]
  ret

GoUp:
  ld a,[Face_y]
  ld b,a
  ld a,[Face_x]
  ld c,a
  dec b
  call FromVariableToBG
  ld a,[hl] 
  cp 1
  ret z
  ld hl, Face_y
  dec [hl]
  dec [hl]
  ret

GoRight:
  ld a,[Face_y]
  ld b,a
  ld a,[Face_x]
  ld c,a
  inc c
  inc c
  call FromVariableToBG
  ld a,[hl] 
  cp 1
  ret z
  ld hl, Face_x
  inc [hl]
  inc [hl]
  ret

GoDown:
  ld a,[Face_y]
  ld b,a
  ld a,[Face_x]
  ld c,a 
  inc b
  inc b
  call FromVariableToBG
  ld a,[hl] 
  cp 1
  ret z
  ld hl, Face_y
  inc [hl]
  inc [hl]
  ret

WaitVBlank:
  ld a, [rLY]
  cp 144
  jr nz, WaitVBlank
  ret

ResetOAM:
  ld     hl, _OAMRAM
  ld b,40*4
  xor a
.loop:
  ld [hl],a
  inc hl
  dec b
  jr nz,.loop
  ret

CopyMemory:
; input:
; de : source
; hl : destination
; bc : how many bytes
.copy:
  ld a,[de]
  inc de
  ld [hl],a
  inc hl
  dec bc
  ld a,b
  or c
  jr nz, .copy
  ret

CopyBGToVRAM:
  ld hl, FristPage
  ld bc, FristPageEnd - FristPage
  ld a,[stage]
  or 0
  jr z,.copy
.add:
  add hl,bc
  dec a
  jr nz, .add
.copy:
  ld d,h
  ld e,l
  ld hl,_SCRN0
  call CopyMemory
  ret

CopyBGToVRAM_W_L_E:
  ld hl, Background10
  ld bc, BackgroundEnd10 -  Background10
  ld a,[bg]
.add:
  add hl,bc
  dec a
  jr nz, .add
  ld d,h
  ld e,l
  ld hl,_SCRN0
  call CopyMemory
  ret

CopyTileDataToVRAM:
  ld de, Tiles
  ld hl, _VRAM
  ld bc, TilesEnd - Tiles
  call CopyMemory
  ret

CheckMove:
  ld a, [object_type]  ;at which object's corner
  dec a  
  ld hl, .jumptable2
  ld e,a
  ld d,0
  add hl, de
  add hl, de
  ld a, [hli]
  ld h, [hl]
  ld l, a
  jp hl

.jumptable2:
  dw .move2_4     ;object_typr 1
  dw .move4_4
  dw .move4_2
  dw .move2_2

;which direction
.move2_4:
  ld a, [current]
  bit 6,a
  jp nz, .UP2_4
  bit 7,a
  jp nz, .Down2_4
  bit 5,a
  jp nz, .Left2_4
  bit 4,a
  jp nz, .Right2_4
  xor a
  ld [move_flag],a
  ret
.move4_4:
  ld a, [current]
  bit 6,a
  jp nz, .UP4_4
  bit 7,a
  jp nz, .Down4_4
  bit 5,a
  jp nz, .Left4_4
  bit 4,a
  jp nz, .Right4_4
  xor a
  ld [move_flag],a
  ret
.move4_2:
  ld a, [current]
  bit 6,a
  jp nz, .UP4_2
  bit 7,a
  jp nz, .Down4_2
  bit 5,a
  jp nz, .Left4_2
  bit 4,a
  jp nz, .Right4_2
  xor a
  ld [move_flag],a
  ret
.move2_2:
  ld a, [current]
  bit 6,a
  jp nz, .UP2_2
  bit 7,a
  jp nz, .Down2_2
  bit 5,a
  jp nz, .Left2_2
  bit 4,a
  jp nz, .Right2_2
  xor a
  ld [move_flag],a
  ret
.Right2_4:
  ld a,[Face_y]
  ld b,a
  ld a,[Face_x]
  ld c,a
  inc c
  inc c
  call FromVariableToBG
  ld a, [hl]
  or 0
  jp nz, CannotMove

  inc b
  inc b
  inc b
  call FromVariableToBG
  ld a,[hl]
  or 0
  jp nz, CannotMove
  ;the 2*4 can move to the right
  call WaitVBlank
  call MoveRight2_4
  jp CanMove

.Right4_4:
  ld a,[Face_y]
  ld b,a
  ld a,[Face_x]
  ld c,a
  inc c
  inc c
  inc c
  inc c
  call FromVariableToBG
  ld a, [hl]
  or 0
  jp nz, CannotMove

  inc b
  inc b
  inc b
  call FromVariableToBG
  ld a,[hl]
  or 0
  jp nz, CannotMove
  ;the 4*4 can move to the right
  call WaitVBlank
  call MoveRight4_4
  jp CanMove

.Right4_2:
  ld a,[Face_y]
  ld b,a
  ld a,[Face_x]
  ld c,a
  inc c
  inc c
  inc c
  inc c
  call FromVariableToBG
  ld a, [hl]
  or 0
  jp nz, CannotMove
; 4*2 can move to the right
  inc b
  call FromVariableToBG
  ld a,[hl]
  or 0
  jp nz, CannotMove
  call WaitVBlank
  call MoveRight4_2
  jp CanMove

.Right2_2:
  ld a,[Face_y]
  ld b,a
  ld a,[Face_x]
  ld c,a
  inc c
  inc c
  call FromVariableToBG
  ld a, [hl]
  or 0
  jp nz, CannotMove
  inc b
  call FromVariableToBG
  ld a,[hl]
  or 0
  jp nz, CannotMove
  ;the 2*2 can move to the right
  call WaitVBlank
  call MoveRight2_2
  jp CanMove

.Left2_4:
  ld a,[Face_y]
  ld b,a
  ld a,[Face_x]
  ld c,a
  dec c
  call FromVariableToBG
  ld a, [hl]
  or 0
  jp nz, CannotMove

  inc b
  inc b
  inc b
  call FromVariableToBG
  ld a,[hl]
  or 0
  jp nz, CannotMove
  ;the 2*4 can move to the left
  call WaitVBlank
  call MoveLeft2_4
  jp CanMove

.Left4_4:
  ld a,[Face_y]
  ld b,a
  ld a,[Face_x]
  ld c,a
  dec c
  call FromVariableToBG
  ld a, [hl]
  or 0
  jp nz, CannotMove

  inc b
  inc b
  inc b
  call FromVariableToBG
  ld a,[hl]
  or 0
  jp nz, CannotMove
  ;the 4*4can move to the left
  call WaitVBlank
  call MoveLeft4_4
  jp CanMove


.Left2_2:
  ld a,[Face_y]
  ld b,a
  ld a,[Face_x]
  ld c,a
  dec c
  call FromVariableToBG
  ld a, [hl]
  or 0
  jp nz, CannotMove

  inc b
  call FromVariableToBG
  ld a,[hl]
  or 0
  jp nz, CannotMove
  ;the 2*2 and 4*2 can move to the left
  call WaitVBlank
  call MoveLeft2_2
  jp CanMove
    
.Left4_2:
  ld a,[Face_y]
  ld b,a
  ld a,[Face_x]
  ld c,a
  dec c
  call FromVariableToBG
  ld a, [hl]
  or 0
  jp nz, CannotMove

  inc b
  call FromVariableToBG
  ld a,[hl]
  or 0
  jp nz, CannotMove
  ;the 4*2 can move to the left
  call WaitVBlank
  call MoveLeft4_2
  jp CanMove


.UP2_2:
  ld a,[Face_y]
  ld b,a
  ld a,[Face_x]
  ld c,a
  dec b
  call FromVariableToBG
  ld a, [hl]
  or 0
  jp nz, CannotMove

  inc c
  call FromVariableToBG
  ld a, [hl]
  or 0
  jp nz, CannotMove
  ;the 2*4 can move up
  call WaitVBlank
  call MoveUp2_2
  jp CanMove

.UP2_4:
  ld a,[Face_y]
  ld b,a
  ld a,[Face_x]
  ld c,a
  dec b
  call FromVariableToBG
  ld a, [hl]
  or 0
  jp nz, CannotMove

  inc c
  call FromVariableToBG
  ld a, [hl]
  or 0
  jp nz, CannotMove
  ;the 2*4 can move up
  call WaitVBlank
  call MoveUp2_4
  jp CanMove

.UP4_2:
  ld a,[Face_y]
  ld b,a
  ld a,[Face_x]
  ld c,a
  dec b
  call FromVariableToBG
  ld a, [hl]
  or 0
  jp nz, CannotMove
   
  inc c
  inc c
  inc c
  call FromVariableToBG
  ld a, [hl]
  or 0
  jp nz, CannotMove
  ;the 4*2 can move up
  call WaitVBlank
  call MoveUp4_2  
  jp CanMove

.UP4_4:
  ld a,[Face_y]
  ld b,a
  ld a,[Face_x]
  ld c,a
  dec b
  call FromVariableToBG
  ld a, [hl]
  or 0
  jp nz, CannotMove
    
  inc c
  inc c
  inc c
  call FromVariableToBG
  ld a, [hl]
  or 0
  jp nz, CannotMove
  ;the 4*2 or 4*4 can move up
  call WaitVBlank
  call MoveUp4_4
  jp CanMove

.Down2_4:
  ld a,[Face_y]
  ld b,a
  ld a,[Face_x]
  ld c,a
  inc b
  inc b
  inc b
  inc b
  call FromVariableToBG
  ld a, [hl]
  or 0
  jp nz, CannotMove

  inc c
  call FromVariableToBG
  ld a, [hl]
  or 0
  jp nz, CannotMove
  ;the 2*4 can move down
  call WaitVBlank
  call MoveDown2_4
  jp CanMove

.Down2_2:
  ld a,[Face_y]
  ld b,a
  ld a,[Face_x]
  ld c,a
  inc b
  inc b
  call FromVariableToBG
  ld a, [hl]
  or 0
  jp nz, CannotMove

  inc c
  call FromVariableToBG
  ld a, [hl]
  or 0
  jp nz, CannotMove
  ;the 2*2 can move down
  call WaitVBlank
  call MoveDown2_2
  jp CanMove

.Down4_2:
  ld a,[Face_y]
  ld b,a
  ld a,[Face_x]
  ld c,a
  inc b
  inc b
  call FromVariableToBG
  ld a, [hl]
  or 0
  jp nz, CannotMove

  inc c
  inc c
  inc c
  call FromVariableToBG
  ld a, [hl]
  or 0
  jp nz, CannotMove
  ;the 4*2 can move down
  call WaitVBlank
  call MoveDown4_2
  jp CanMove

.Down4_4:
  ld a,[Face_y]
  ld b,a
  ld a,[Face_x]
  ld c,a
  inc b
  inc b
  inc b
  inc b
  call FromVariableToBG
  ld a, [hl]
  or 0
  jp nz, CannotMove

  inc c
  inc c
  inc c
  call FromVariableToBG
  ld a, [hl]
  or 0
  jp nz, CannotMove
  ;the 4*4 can move down
  call WaitVBlank
  call MoveDown4_4
  jp CanMove

MoveRight4_4:
  call ResetShadowTile
  call ResetFace_xy
  call push4_4
  call ResetFace_xy
  inc c
  inc c
  call SetFace_xy
  jp pop4_4
MoveUp4_4:
  call ResetShadowTile
  call ResetFace_xy
  call push4_4
  call ResetFace_xy
  dec b
  dec b
  call SetFace_xy
  jp pop4_4
MoveLeft4_4:
  call ResetShadowTile
  call ResetFace_xy
  call push4_4
  call ResetFace_xy
  dec c
  dec c
  call SetFace_xy
  jp pop4_4


MoveDown4_4:
  call ResetShadowTile
  call ResetFace_xy
  call push4_4
  call ResetFace_xy
  inc b
  inc b
  call SetFace_xy
  jr pop4_4



push4_4:
  call FromVariableToBG
  ld de,ShadowTile
  ld a,[hl]
  ld [de],a
  ld [hl],0
  inc de
  inc hl
  ld a,[hl]
  ld [de],a
  ld [hl],0
  inc de
  inc hl
  ld a,[hl]
  ld [de],a
  ld [hl],0
  inc de
  inc hl
  ld a,[hl]
  ld [de],a
  ld [hl],0
  inc de
  ld b,0
  ld c,NEXTLINE
  add hl,bc
  ld a,[hl]
  ld [de],a
  ld [hl],0
  dec hl
  dec hl
  dec hl
  inc de
  ld a,[hl]
  ld [de],a
  ld [hl],0
  inc de
  ld b,0
  ld c,NEXTLINE
  add hl,bc
  ld a,[hl]
  ld [de],a
  ld [hl],0
  inc hl
  inc hl
  inc hl
  inc de
  ld a,[hl]
  ld [de],a
  ld [hl],0
  inc de
  ld b,0
  ld c,NEXTLINE
  add hl,bc
  ld a,[hl]
  ld [de],a
  ld [hl],0
  inc de
  dec hl
  ld a,[hl]
  ld [de],a
  ld [hl],0
  inc de
  dec hl
  ld a,[hl]
  ld [de],a
  ld [hl],0
  inc de
  dec hl
  ld a,[hl]
  ld [de],a
  ld [hl],0
  ret

pop4_4:
  call FromVariableToBG
  ld de,ShadowTile
  ld a,[de]
  ld [hl],a
  inc de
  inc hl
  ld a,[de]
  ld [hl],a
  inc de
  inc hl
  ld a,[de]
  ld [hl],a
  inc de
  inc hl
  ld a,[de]
  ld [hl],a
  inc de
  ld b,0
  ld c,NEXTLINE
  add hl,bc
  ld a,[de]
  ld [hl],a
  dec hl
  dec hl
  dec hl
  inc de
  ld a,[de]
  ld [hl],a
  inc de
  ld b,0
  ld c,NEXTLINE
  add hl,bc
  ld a,[de]
  ld [hl],a
  inc hl
  inc hl
  inc hl
  inc de
  ld a,[de]
  ld [hl],a
  inc de
  ld b,0
  ld c,NEXTLINE
  add hl,bc
  ld a,[de]
  ld [hl],a
  inc de
  dec hl
  ld a,[de]
  ld [hl],a
  inc de
  dec hl
  ld a,[de]
  ld [hl],a
  inc de
  dec hl
  ld a,[de]
  ld [hl],a
  ret  


MoveRight4_2:
  call ResetShadowTile
  call ResetFace_xy
  call push4_2
  call ResetFace_xy
  inc c
  inc c
  call SetFace_xy
  jr pop4_2
MoveUp4_2:
  call ResetShadowTile
  call ResetFace_xy
  call push4_2
  call ResetFace_xy
  dec b
  dec b
  call SetFace_xy
  jr pop4_2
MoveLeft4_2:
  call ResetShadowTile
  call ResetFace_xy
  call push4_2
  call ResetFace_xy
  dec c
  dec c
  call SetFace_xy
  jr pop4_2


MoveDown4_2:
  call ResetShadowTile
  call ResetFace_xy
  call push4_2
  call ResetFace_xy
  inc b
  inc b
  call SetFace_xy
  jr pop4_2

push4_2:
  call FromVariableToBG
  ld de,ShadowTile
  ld a,[hl]
  ld [de],a
  ld [hl],0
  inc de
  inc hl
  ld a,[hl]
  ld [de],a
  ld [hl],0
  inc de
  inc hl
  ld a,[hl]
  ld [de],a
  ld [hl],0
  inc de
  inc hl
  ld a,[hl]
  ld [de],a
  ld [hl],0
  inc de
  ld b,0
  ld c,NEXTLINE
  add hl,bc
  ld a,[hl]
  ld [de],a
  ld [hl],0
  inc de
  dec hl
  ld a,[hl]
  ld [de],a
  ld [hl],0
  inc de
  dec hl
  ld a,[hl]
  ld [de],a
  ld [hl],0
  inc de
  dec hl
  ld a,[hl]
  ld [de],a
  ld [hl],0
  ret

pop4_2:
  call FromVariableToBG
  ld de,ShadowTile
  ld a, [de]
  ld [hl],a
  inc de
  inc hl
  ld a, [de]
  ld [hl],a
  inc de
  inc hl
  ld a,[de]
  ld [hl],a
  inc de
  inc hl
  ld a,[de]
  ld [hl],a
  inc de
  ld b,0
  ld c,NEXTLINE
  add hl,bc
  ld a,[de]
  ld [hl],a
  inc de
  dec hl
  ld a,[de]
  ld [hl],a
  inc de
  dec hl
  ld a,[de]
  ld [hl],a
  inc de
  dec hl
  ld a,[de]
  ld [hl],a
  ret

MoveUp2_4:
  call ResetShadowTile
  call ResetFace_xy
  call push2_4
  call ResetFace_xy
  dec b
  dec b
  call SetFace_xy
  jr pop2_4

MoveDown2_4:
  call ResetShadowTile
  call ResetFace_xy
  call push2_4
  call ResetFace_xy
  inc b
  inc b
  call SetFace_xy
  jr pop2_4

MoveRight2_4:
  call ResetShadowTile
  call ResetFace_xy
  call push2_4
  call ResetFace_xy
  inc c
  inc c
  call SetFace_xy
  jr pop2_4

MoveLeft2_4:
  call ResetShadowTile
  call ResetFace_xy
  call push2_4
  call ResetFace_xy
  dec c
  dec c
  call SetFace_xy
  jr pop2_4

push2_4:
  call FromVariableToBG
  ld de,ShadowTile
  ld a,[hl]
  ld [de],a
  ld [hl],0
  inc de
  inc hl
  ld a,[hl]
  ld [de],a
  ld [hl],0
  inc de
  ld b,0
  ld c,NEXTLINE
  add hl,bc
  ld a,[hl]
  ld [de],a
  ld [hl],0
  inc de
  dec hl
  ld a,[hl]
  ld [de],a
  ld [hl],0
  inc de
  ld b,0
  ld c,NEXTLINE
  add hl,bc
  ld a,[hl]
  ld [de],a
  ld [hl],0
  inc de
  inc hl
  ld a,[hl]
  ld [de],a
  ld [hl],0
  inc de
  ld b,0
  ld c,NEXTLINE
  add hl,bc
  ld a,[hl]
  ld [de],a
  ld [hl],0
  inc de
  dec hl
  ld a,[hl]
  ld [de],a
  ld [hl],0
  ret

pop2_4:
  call FromVariableToBG
  ld de,ShadowTile
  ld a,[de]
  ld [hl],a
  inc de
  inc hl
  ld a,[de]
  ld [hl],a
  inc de
  ld b,0
  ld c,NEXTLINE
  add hl,bc
  ld a,[de]
  ld [hl],a
  inc de
  dec hl
  ld a,[de]
  ld [hl],a
  inc de
  ld b,0
  ld c,NEXTLINE
  add hl,bc
  ld a,[de]
  ld [hl],a
  inc de
  inc hl
  ld a,[de]
  ld [hl],a
  inc de
  ld b,0
  ld c,NEXTLINE
  add hl,bc
  ld a,[de]
  ld [hl],a
  inc de
  dec hl
  ld a,[de]
  ld [hl],a
  ret  

MoveUp2_2:
  call ResetShadowTile
  call ResetFace_xy
  call push2_2
  call ResetFace_xy
  dec b
  dec b
  call SetFace_xy
  jr pop2_2


MoveDown2_2:
  call ResetShadowTile
  call ResetFace_xy
  call push2_2
  call ResetFace_xy
  inc b
  inc b
  call SetFace_xy
  jr pop2_2


MoveRight2_2:
  call ResetShadowTile
  call ResetFace_xy
  call push2_2
  call ResetFace_xy
  inc c
  inc c
  call SetFace_xy
  jr pop2_2

MoveLeft2_2:
  call ResetShadowTile
  call ResetFace_xy
  call push2_2
  call ResetFace_xy
  dec c
  dec c
  call SetFace_xy
  jr pop2_2

push2_2:
  call FromVariableToBG
  ld de,ShadowTile
  ld a,[hl]
  ld [de],a
  ld [hl],0
  inc de
  inc hl
  ld a,[hl]
  ld [de],a
  ld [hl],0
  inc de
  ld b,0
  ld c,NEXTLINE
  add hl,bc
  ld a,[hl]
  ld [de],a
  ld [hl],0
  inc de
  dec hl
  ld a,[hl]
  ld [de],a
  ld [hl],0
  ret

pop2_2:
  call FromVariableToBG
  ld de,ShadowTile
  ld a,[de]
  ld [hl],a
  inc c
  inc de
  inc hl
  ld a,[de]
  ld [hl],a
  inc b
  inc de
  ld b,0
  ld c,NEXTLINE
  add hl,bc
  ld a,[de]
  ld [hl],a
  dec c
  inc de
  dec hl
  ld a,[de]
  ld [hl],a
  ret

ResetShadowTile:
  ld hl, ShadowTile
  ld b,NEXTLINE
  xor a
.loop:
  ld [hl+],a
  dec b
  jr nz,.loop
  ret  

ResetFace_xy:
  ld a,[Face_y]
  ld b,a
  ld a,[Face_x]
  ld c,a
  ret
SetFace_xy:
  ld a,b
  ld [Face_y],a
  ld a,c
  ld [Face_x],a
  ret

CannotMove:
    xor a
    ld [move_flag], a
    ret

CanMove:
    ld a,1
    ld [move_flag], a
    ret

Count:
  call IncrementCounter
  call binToDec
  call copyDigitsRev
  ret
IncrementCounter:
  ld a, [counter]
  cp INTMAX
  jp z, LoseCase
  inc a
  ld [counter], a
  ret

binToDec:
  ld a, [counter]      
  ld hl, buffer         

binToDec_loop:
  call DividedBy10      
  ld [hl], a           
  inc hl
  ld a, b              
  or a                 
  jr nz, binToDec_loop
  ld [hl], 0           
  ret

DividedBy10:
  ld b, 0
.loop:
  cp 10
  jr c, .done
  sub 10
  inc b
  jr .loop
.done:
  ret

copyDigitsRev:
  ld hl, buffer+2         
  ld de, _SCRN0 + COUNTERPLACE

  ld c, BUFFLENGTH              
  call WaitVBlank
copy_loop:
  ld a, [hl]       
  add 14 ;tile_id of "0"
  ld [de], a        
  ld [hl],0
  inc de
  dec hl
  dec c
  jr nz, copy_loop    
  ret
;-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
SECTION "Variables", WRAM0
ShadowTile: DS 32
previous: DS 1
current: DS 1
Face_x: DS 1
Face_y: DS 1
Paused: DS 1
object_type: DS 1
reset: DS 1
move_flag: DS 1
counter: DS 1
buffer: DS 4
stage: DS 1
bg: DS 1
