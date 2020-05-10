;Interrupt 10h is the graphics interrupt
;It allows for the plotting of pixels if ah=0ch
;It must first be configured with ax=0013h

ORG 100h ;This is a request for the OS to give up control
mov cx, 0

;The data portion of the program. Must be skipped.
;If not, it will be read as code.
jmp skipdata
GAME_WIDTH dw 30
GAME_HEIGHT dw 20

;The ball is an object stored in this array
;The format is: xPos, yPos, xVel, yVel, Size, newX, newY
;WARNING: If you change x/y, you must change newX/Y too
BALL dw 10,10,2,1,1,10,10

;The paddle is stored as an object in this array
;The format is: xPos, yPos, Speed, Length, newX, newY
PAD dw 5,8,3,4,5,8
skipdata:


;Set to graphics display mode
mov ax, 0013h
int 10h

;Plotting the boundaries
mov ax, 0
mov bx, 0
mov cx, GAME_WIDTH
call HORIZ_LINE_PLOT
mov cx, GAME_HEIGHT
call VERT_LINE_PLOT
add ax, GAME_WIDTH
call VERT_LINE_PLOT
mov ax, 0
mov bx, GAME_HEIGHT
mov cx, GAME_WIDTH
call HORIZ_LINE_PLOT


;The main loop. Uses LOOP so that it does not repeat forever
mov cx, 0
MAINLOOP:
call DRAW_PAD
call DRAW_BALL
call BALL_UPDATE
call PAD_UPDATE
call BALL_HIT_CHECK
loop MAINLOOP

ret ;ret is used instead of hlt, because of the 'ORG 100h'


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;FUNCTIONS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;Draws the pad on the screen
;In memory: PAD[xPos, yPos, Speed, Length, newX, newY]
DRAW_PAD:
push ax
push bx
push cx

mov ax, PAD[0]
mov bx, PAD[2]
mov cx, PAD[6]
call VERT_LINE_UNPLOT

mov ax, PAD[8]
mov bx, PAD[10]
call VERT_LINE_PLOT

pop cx
pop bx
pop ax
ret




;Draws the ball on the screen
;In memory: BALL[oldXPos, oldYPos, dx, dy, size, xPos, yPos]
DRAW_BALL:
push ax
push bx
push cx
push dx

;Setting up values for RECT_UNPLOT
mov ax, BALL[0]
mov cx, ax
mov bx, BALL[2]
mov dx, bx

add cx, BALL[8]
dec cx
add dx, BALL[8]
dec dx

call RECT_UNPLOT

mov ax, BALL[10]
mov cx, ax
mov bx, BALL[12]
mov dx, bx

add cx, BALL[8]
dec cx
add dx, BALL[8]
dec dx

call RECT_PLOT

pop dx
pop cx
pop bx
pop ax 
ret




;Updates the ball object's values.
;In memory: BALL[oldXPos, oldYPos, dx, dy, size, xPos, yPos]
BALL_UPDATE:
push ax
push bx
push cx

;Step 0: Update the old ball positions
mov ax, BALL[10]
lea bx, BALL[0]
mov [bx], ax
mov ax, BALL[12]
lea bx, BALL[2]
mov [bx], ax

;Step 1: find the ball's new x position
mov ax, BALL[0]
mov bx, BALL[4]
add ax, bx

;Step 2: check if velocity is positive or negative using MSb
and bx, 8000h
jz positiveX  

;Step 3: check for collision
cmp ax, 0    
jg doneX

;Step 4: correct the new position and negate velocity
neg ax
inc ax
mov cx, BALL[4]
neg cx
lea bx, BALL[4]
mov [bx], cx
jmp doneX

;Step 3: check for collision
positiveX:
mov cx, ax
add cx, BALL[8]
sub cx, GAME_WIDTH
cmp cx, 0
jle doneX

;Step 4: correct the new position and negate velocity
shl cx, 1
sub ax, cx
mov cx, BALL[4]
neg cx
lea bx, BALL[4]
mov [bx], cx 

;Step 5: update the new position
doneX:
lea bx, BALL[10]
mov [bx], ax

;AND AGAIN!!!

;Step 1: find the ball's new y position
mov ax, BALL[2]
mov bx, BALL[6]
add ax, bx

;Step 2: check if velocity is positive or negative using MSb
and bx, 8000h
jz positiveY  

;Step 3: check for collision
cmp ax, 0    
jg doneY

;Step 4: correct the new position and negate velocity
neg ax
inc ax
mov cx, BALL[6]
neg cx
lea bx, BALL[6]
mov [bx], cx
jmp doneY

;Step 3: check for collision
positiveY:
mov cx, ax
add cx, BALL[8]
sub cx, GAME_HEIGHT
cmp cx, 0
jle doneY

;Step 4: correct the new position and negate velocity
shl cx, 1
sub ax, cx
mov cx, BALL[6]
neg cx
lea bx, BALL[6]
mov [bx], cx 

;Step 5: update the new position
doneY:
lea bx, BALL[12]
mov [bx], ax                    

pop cx
pop bx
pop ax
ret




;Checks for input and updates the paddle's position accordingly
;In memory: PAD[xPos, yPos, Speed, Length, newX, newY]
PAD_UPDATE:
push ax
push bx

;Overwrite the old positions with the new ones
mov ax, PAD[8]
lea bx, PAD[0]
mov [bx], ax
mov ax, PAD[10]
lea bx, PAD[2]
mov [bx], ax

mov al, 0
mov ah, 1
int 16h    ;Check for character in keyboard buffer
jz donePU  ;Do nothing if no input

mov ax, 0
int 16h    ;Get character

;Target character list
;UP arrow:    4800h
;DOWN arrow:  5000h

cmp al, 00h
je donePU
cmp ah, 48h
je UP
cmp ah, 50h
jne donePU

;DOWN
mov ax, PAD[2]
add ax, PAD[4]

;Now, check for collision
mov bx, ax
add bx, PAD[6]
dec bx
cmp bx, GAME_HEIGHT
jl commit  ;If no collision, commit changes in yPos to the object

;If collision, set paddle to maximum possible yPos
mov bx, GAME_HEIGHT
dec bx
sub bx, PAD[6]
mov ax, bx
jmp commit ;Then commit the changes

UP:
mov ax, PAD[2]
sub ax, PAD[4]

;Here, the collision check is easy, since the game area always starts at 0
cmp ax, 0
jg commit
mov ax, 1 ;If there's a collision, simply set the yPos to 1

commit:
lea bx, PAD[10]
mov [bx], ax 

donePU:
pop bx
pop ax
ret




;Checks if the ball has made contact with the pad & acts accordingly
;In memory: BALL[oldXPos, oldYPos, dx, dy, size, xPos, yPos]
;In memory: PAD[xPos, yPos, Speed, Length, newX, newY]
BALL_HIT_CHECK:

;The logic of this function:
;If BALL[4] < 0, it's heading towards the pad
;If BALL[0] > PAD[0], and BALL[10] <= PAD[0], it passes through the pad's xPos

;Finally, we have two y-values to consider, the top and bottom of the ball
;For this part, we will consider the pad's & ball's new position, since the 
;player will be trying to move the pad to intercept the ball.

;If both are under the pad's yPos, or over the pad's yPos+Length, do nothing
;If this is not true, register a collision:
;Negate BALL[4], set BALL[10]=PAD[0]+1

push ax
push bx
push cx

cmp BALL[4], 0
jge doneP         ;Check that the ball is heading towards the pad
mov ax, PAD[0]
cmp BALL[10], ax
jg doneP          ;Check that the new position is behind the pad
cmp BALL[0], ax   
jle doneP         ;Check that the old ball position is in front of the pad

mov ax, BALL[12]
mov bx, ax
add bx, BALL[8]
dec bx ;Because the ball's size is absolute and includes the origin xPos
mov cx, PAD[2]
cmp ax, cx
jg nextC          ;Now, check for both y1 and y2 being under the pad's yPos
cmp bx, cx
jl doneP          ;If they both are, we're done
                  ;If not, go to nextC

nextC:
add cx, PAD[6]
dec cx ;Again, length/size include the origin
cmp ax, cx
jg doneP          ;Since the ball's y values only increase from it's yPos, we can just 
                  ;compare yPos to the pad's ending position
                  
;If after all of that, the ball did not make this function end, it means that it has
;made contact with the pad's new position (approximately)

mov ax, BALL[4]
lea bx, BALL[4]
neg ax
mov [bx], ax     ;Negate the x velocity

mov ax, PAD[0]
inc ax
lea bx, BALL[10]
mov [bx], ax     ;Set the ball's new xPos to in front of the pad

inc dx           ;Increment the score

doneP:
pop cx
pop bx
pop ax 
ret




;Plot a rectangle function
;ax - Origin X
;bx - Origin Y
;cx - Destination X
;dx - Destination Y
RECT_PLOT:
push ax
push bx
push cx
push dx
push di
push si

push ax ;Store the Origin X in the stack

mov di, cx ;DI stores the X
mov si, dx ;SI stores the Y
 
mov cx, ax
mov dx, bx
mov ax, 0c0fh ;The right-most hex char is the color of the rectangle

rect_loop:
int 10h ;Draw a pixel

inc cx ;Increment x value
cmp cx, di ;Check if xPos > Destination X
jng rect_loop

pop cx ;Reset the xPos to the Origin X
push cx

inc dx
cmp dx, si ;Check if yPos > Destination Y
jng rect_loop

pop si
pop si
pop di
pop dx
pop cx
pop bx
pop ax

ret




;Plot a black rectangle function
;ax - Origin X
;bx - Origin Y
;cx - Destination X
;dx - Destination Y
RECT_UNPLOT:
push ax
push bx
push cx
push dx
push di
push si

push ax ;Store the Origin X in the stack

mov di, cx ;DI stores the X
mov si, dx ;SI stores the Y
 
mov cx, ax
mov dx, bx
mov ax, 0c00h ;The right-most hex char is the color of the rectangle

rect_loop2:
int 10h ;Draw a pixel

inc cx ;Increment x value
cmp cx, di ;Check if xPos > Destination X
jng rect_loop2

pop cx ;Reset the xPos to the Origin X
push cx

inc dx
cmp dx, si ;Check if yPos > Destination Y
jng rect_loop2

pop si
pop si
pop di
pop dx
pop cx
pop bx
pop ax

ret




;Plot a vertical line function 
;ax - Start x-value
;bx - Start y-value
;cx - Length
VERT_LINE_PLOT:
push ax
push bx
push cx
push dx

;Moving values around for pixel plotting
mov dx, bx
mov bx, cx
mov cx, ax
mov ax, 0c0fh

vert_loop:
int 10h
inc dx
dec bx
jns vert_loop

pop dx
pop cx
pop bx
pop ax

ret




;Unlot a vertical line function 
;ax - Start x-value
;bx - Start y-value
;cx - Length
VERT_LINE_UNPLOT:
push ax
push bx
push cx
push dx

;Moving values around for pixel plotting
mov dx, bx
mov bx, cx
mov cx, ax
mov ax, 0c00h

vert_loopu:
int 10h
inc dx
dec bx
jns vert_loopu

pop dx
pop cx
pop bx
pop ax

ret




;Plot a horizontal line function
;ax - Start x-value
;bx - Start y-value
;cx - Length
HORIZ_LINE_PLOT:
push ax
push bx
push cx
push dx

;Moving values around for pixel plotting
mov dx, bx
mov bx, cx
mov cx, ax
mov ax, 0c0fh

horiz_loop:
int 10h
inc cx
dec bx
jns horiz_loop

pop dx
pop cx
pop bx
pop ax 

ret




;Plot a black pixel at old location, and re-plot at the new location
;ax - Old X
;bx - Old Y
;cx - New X
;dx - New Y
MOVE_PIXEL:
push bx
push ax

;cx and dx are popped within the function
push dx
push cx

;Set cx, dx, to old x and y
mov cx, ax
mov dx, bx

;Store the old color in bl
mov ax, 0d00h
int 10h
mov bl, al

;Un-plot the old pixel
mov ax, 0c00h
int 10h

;Plot the new pixel
mov al, bl
mov ah, 0ch
pop cx
pop dx
int 10h

;Exit
pop ax
pop bx
ret




;Plot a pixel function
;ax - x position
;bx - y position
PLOT_PIXEL:
push ax
push cx
push dx

mov cx, ax
mov dx, bx
mov ax, 0c0fh
int 10h

pop dx
pop cx
pop ax
ret        