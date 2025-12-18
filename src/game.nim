import kirpi
import math,std/random

#region Game Properties
var gameWidth:float=480
var gameHeight:float=480
var gridSize:float=32
var gameTickMS:float=0.20 # The interval between logic updates (game speed)
var smoothMotion:bool=true # Toggle between classic (grid-based) and smooth interpolation
#endregion

#Helper Values
var gameStarted=false
var score:int=0
var tickMSCounter:float=0
var isGameOver=false
var gridWidth:int
var gridHeight:int
var directionX:int=1
var directionY:int=0
var prevDirectionX:int=directionX
var prevDirectionY:int=directionY


#region GRID
var grid:seq[seq[int]] # 2D array to keep track of occupied cells
var emptyCells:seq[tuple[x:int,y:int]] # List of available cells for apple spawning

# Converts screen position to grid index
proc posToCell(pos:float) :int =
  result=ceil(pos/gridSize).int-1

# Converts grid index back to center-of-cell screen position
proc cellToPos(cellPos:int) :float =
  var halfGridSize=gridSize*0.5
  result=cellPos.float*gridSize+halfGridSize

#endregion

#region APPLE
type 
  Apple = object
    x:float
    y:float
    cellX:int
    cellY:int

var apples:seq[Apple]

# Spawns an apple at a random available grid location
proc addApple() =
  let randomCell=emptyCells[rand(emptyCells.len-1).int ]
  var posX=cellToPos(randomCell.x)
  var posY=cellToPos(randomCell.y)
  apples.add(Apple(x:posX,y:posY,cellX:randomCell.x,cellY:randomCell.y))

proc drawApples() =
  
  for i in 0..<apples.len :
    #apple cast shadow
    push()
    translate(5,5)
    setColor("#10232374")
    circle(DrawModes.Fill,apples[i].x,apples[i].y,gridSize*0.5)
    pop()
    #apple stroke
    setColor("#102323")
    circle(DrawModes.Fill,apples[i].x,apples[i].y,gridSize*0.5)
    #apple color
    setColor("#f41f1d")
    #apple high light
    circle(DrawModes.Fill,apples[i].x,apples[i].y,gridSize*0.5-5)
    setColor("#f6fda9ff")
    circle(DrawModes.Fill,apples[i].x+4.0,apples[i].y-4.0,4.0)
    
    #apple leaf stroke
    setColor("#102323")
    let leafBeginX=apples[i].x
    let leafBeginY=apples[i].y-8.0
    quad(DrawModes.Fill,leafBeginX,leafBeginY,leafBeginX-8,leafBeginY-10,leafBeginX,leafBeginY-20.0,leafBeginX+8,leafBeginY-10)
    #apple leaf fill
    setColor("#257526")
    quad(DrawModes.Fill,leafBeginX,leafBeginY-5.0,leafBeginX-3.0,leafBeginY-10.0,leafBeginX,leafBeginY-15.0,leafBeginX+3.0,leafBeginY-10.0)

    discard
  

#endregion

#region SNAKE
type 
  SnakePart = object 
    cellX:int=0
    cellY:int=0
    prevCellX:int= -1
    prevCellY:int= -1

var snakeParts:seq[SnakePart]
let snakeSpeed:float=3.0

# Adds a new part to the tail using the last part's movement history
proc addSnakePart() =
  var cellX=snakeParts[^1].prevCellX
  var cellY=snakeParts[^1].prevCellY
  var prevCellX=cellX - (snakeParts[^1].cellX-snakeParts[^1].prevCellX)
  var prevCellY=cellY - (snakeParts[^1].cellY-snakeParts[^1].prevCellY)
  snakeParts.add( SnakePart(cellX:cellX,cellY:cellY,prevCellX:prevCellX,prevCellY:prevCellY) )

proc drawSnake() =
  if snakeParts.len==0 : return
  setLine(gridSize,JoinTypes.Round,CapTypes.Round,CapTypes.Round)
  var linePath:seq[float]
  let lerpRate=tickMSCounter/gameTickMS # Progression factor between current and next tick
  for i in 0..<snakeParts.len :
    var posX,posY:float
    if smoothMotion :
      # Interpolate position between prevCell and cell for fluid animation
      posX=cellToPos(snakeParts[i].prevCellX)
      posY=cellToPos(snakeParts[i].prevCellY)
      
      if i==0 or i==snakeParts.len-1 :
        
        var diffX=(snakeParts[i].cellX-snakeParts[i].prevCellX).float*gridSize
        var diffY=(snakeParts[i].cellY-snakeParts[i].prevCellY).float*gridSize
        var lerpedPosX=posX+diffX*lerpRate
        var lerpedPosY=posY+diffY*lerpRate
        if i==0 :
          linePath.add(lerpedPosX)
          linePath.add(lerpedPosY)
        else :
          posX=lerpedPosX
          posY=lerpedPosY

      linePath.add(posX)
      linePath.add(posY)


    else :
      # Snap directly to grid cells (Classic mode)
      posX=cellToPos(snakeParts[i].cellX)
      posY=cellToPos(snakeParts[i].cellY)
      linePath.add(posX)
      linePath.add(posY)
  #snake cast shadow
  push()
  translate(5,5)
  setColor("#10232374")
  line(linePath)
  pop()
  #snake stroke 
  setColor("#102323")
  setLineWidth(gridSize)
  line(linePath)
  #snake body color    
  setColor("#fdae19")
  setLineWidth(gridSize-12)
  line(linePath)
  
  #snake highlight
  for i in countup(0,linePath.len-2,2) :
    linePath[i]-=4
    linePath[i+1]-=4
  setColor("#fbe559")
  setLineWidth(6.0)
  line(linePath)

# Scans the grid and identifies cells not occupied by the snake
proc updateEmptyCells() =
  #Define Empty Cells 
  emptyCells.setLen(0)
  for iy in 0..<grid.len :
    for ix in 0..<grid.len :
      grid[iy][ix]=0
  for part in snakeParts :
    grid[part.cellY.clamp(0,gridHeight-1)][part.cellX.clamp(0,gridWidth-1) ]=1
    grid[part.prevCellY.clamp(0,gridHeight-1) ][part.prevCellX.clamp(0,gridWidth-1)]=1
  for iy in 0..<grid.len :
    for ix in 0..<grid.len :
      if grid[iy][ix]!=1 : emptyCells.add((x:ix,y:iy))

#endregion

#region GAME-UI
proc drawWelcomePanel() =
  let panelWidth:float=350
  let panelHeight:float=150
  var beginX=(gameWidth-panelWidth)*0.5
  var beginY=(gameHeight-panelHeight)*0.5
  var centerX=beginX+panelWidth*0.5
  var centerY=beginY+panelHeight*0.5
  #Panel
  setColor("#102323")
  rectangle(DrawModes.Fill,beginX,beginY,panelWidth,panelHeight)
  setColor("#f6fda9")
  rectangle(DrawModes.Fill,beginX+8,beginY+8,panelWidth-16,panelHeight-16)
  #Title Bar
  setColor("#fdae19")
  rectangle(DrawModes.Fill,beginX,beginY,panelWidth,48)
  setColor("#102323")
  rectangle(DrawModes.Line,beginX,beginY,panelWidth,48)
  #Draw texts
  var curY=centerY-48
  setColor(Black)
  var text=newText("Kirpi Framework - Snake Game",getDefaultFont())
  var textSize=text.getSizeWith(24)
  draw(text,centerX-textSize.x*0.5,curY-textSize.y*0.5,24)
  curY+=68
  text=newText("Press [Enter] key to start game!",getDefaultFont())
  textSize=text.getSizeWith(24)
  draw(text,centerX-textSize.x*0.5,curY-textSize.y*0.5,24)
  discard

proc drawGameOverPanel() =
  let panelWidth:float=350
  let panelHeight:float=150
  var beginX=(gameWidth-panelWidth)*0.5
  var beginY=(gameHeight-panelHeight)*0.5
  var centerX=beginX+panelWidth*0.5
  var centerY=beginY+panelHeight*0.5
  #Panel
  setColor("#102323")
  rectangle(DrawModes.Fill,beginX,beginY,panelWidth,panelHeight)
  setColor("#f6fda9")
  rectangle(DrawModes.Fill,beginX+8,beginY+8,panelWidth-16,panelHeight-16)
  #Title Bar
  setColor("#fdae19")
  rectangle(DrawModes.Fill,beginX,beginY,panelWidth,48)
  setColor("#102323")
  rectangle(DrawModes.Line,beginX,beginY,panelWidth,48)
  #Draw texts
  var curY=centerY-48
  setColor(Black)
  var text=newText("GAME OVER",getDefaultFont())
  var textSize=text.getSizeWith(24)
  draw(text,centerX-textSize.x*0.5,curY-textSize.y*0.5,24)
  curY+=48
  text=newText("Score:" & $score,getDefaultFont())
  textSize=text.getSizeWith(24)
  draw(text,centerX-textSize.x*0.5,curY-textSize.y*0.5,24)
  curY+=36
  text=newText("Press [Enter] to restart game!",getDefaultFont())
  textSize=text.getSizeWith(24)
  draw(text,centerX-textSize.x*0.5,curY-textSize.y*0.5,24)
  discard

#endregion

#region GAME

# Resets all game states for a new session
proc replayGame() =
  score=0
  directionX=1
  directionY=0
  prevDirectionX=directionX
  prevDirectionY=directionY

  snakeParts.setLen(0)

  # Add head part of the snake
  snakeParts.add(SnakePart())
  snakeParts[0].cellX=3
  snakeParts[0].cellY=floor(gridHeight.float*0.5).int

  snakeParts[0].prevCellX=snakeParts[0].cellX-directionX
  snakeParts[0].prevCellY=snakeParts[0].cellY+directionY

  # Add other parts of the snake 
  addSnakePart()
  addSnakePart()

  # Add an apple 
  apples.setLen(0)
  updateEmptyCells()
  addApple()


proc config(appSettings:var AppSettings) =
  appSettings.window.resizeable=true
  appSettings.printFPS=true



proc load() =
  
  gridWidth=(gameWidth/gridSize).int
  gridHeight=(gameHeight/gridSize).int
  for y in 0..<gridWidth.int :
    var cells:seq[int]
    for x in 0..<gridHeight.int :
      cells.add(0)
    grid.add(cells)
  




proc update( dt:float) =
  if isGameOver :
    if isKeyPressed(KeyboardKey.Enter) :
      replayGame()
      isGameOver=false
    return

  if not gameStarted :
    if isKeyPressed(KeyboardKey.Enter) :
      replayGame()
      gameStarted=true
    return

  if isKeyPressed(KeyboardKey.Space) :
    smoothMotion=if smoothMotion==true : false else : true
  
  tickMSCounter+=dt
  
  # Handle Input
  var newDirectionX,newDirectionY:int
  if isKeyPressed(KeyboardKey.Up) or isKeyPressed(KeyboardKey.W) :
    newDirectionX=0
    newDirectionY= -1
  elif isKeyPressed(KeyboardKey.Down) or isKeyPressed(KeyboardKey.S) :
    newDirectionX=0
    newDirectionY= 1
  elif isKeyPressed(KeyboardKey.Left) or isKeyPressed(KeyboardKey.A) :
    newDirectionX= -1
    newDirectionY= 0
  elif isKeyPressed(KeyboardKey.Right) or isKeyPressed(KeyboardKey.D) :
    newDirectionX= 1
    newDirectionY= 0

  # Preventing 180-degree turns
  if prevDirectionX-newDirectionX!=0 and prevDirectionY-newDirectionY!=0 :
    directionX=newDirectionX
    directionY=newDirectionY

  # Wait for the next logic tick
  if tickMSCounter<gameTickMS :
    return
  tickMSCounter=0

  


  prevDirectionX=directionX
  prevDirectionY=directionY

  # Define the next cell of the snake's head
  let nextCellX=snakeParts[0].cellX+directionX
  let nextCellY=snakeParts[0].cellY+directionY
  
  # Logic: Self-collision check (next cell)
  for i in 1..<snakeParts.len :
    if snakeParts[i].cellX==nextCellX and snakeParts[i].cellY==nextCellY :
      isGameOver=true
      
  # Logic: Wall-collision check (next cell)
  if nextCellX<0 or  nextCellX>gridWidth-1 :
    isGameOver=true
    
  if nextCellY<0 or  nextCellY>gridHeight-1 :
    isGameOver=true

  if not smoothMotion and isGameOver :
    return 
    

  # Update Positions: Head follows direction
  snakeParts[0].prevCellX=snakeParts[0].cellX
  snakeParts[0].prevCellY=snakeParts[0].cellY
  snakeParts[0].cellX=nextCellX
  snakeParts[0].cellY=nextCellY

  # Update Positions: Each tail part follows the previous part's old position
  for i in 1..<snakeParts.len :
    snakeParts[i].prevCellX=snakeParts[i].cellX
    snakeParts[i].prevCellY=snakeParts[i].cellY
    snakeParts[i].cellX=snakeParts[i-1].prevCellX
    snakeParts[i].cellY=snakeParts[i-1].prevCellY

  # Logic: Eating an apple 
  for i in 0..<apples.len :
    if snakeParts[0].cellX == apples[i].cellX :
      if snakeParts[0].cellY == apples[i].cellY :
        addSnakePart()
        apples.del(i)
        score+=1
        updateEmptyCells()
        addApple()
        break

  


proc draw() =
  clear("#f6fda9")
  # Draw Grid
  var gamebeginX=(window.getWidth().float-gameWidth)*0.5
  var gamebeginY=(window.getHeight().float-gameHeight)*0.5
  # Game Area
  push()
  setColor(DarkGray)
  setLine(1)
  translate(gamebeginX,gamebeginY)
  
  # Render checkerboard grid background
  var colorCounter:int=0
  for cy in 0..<grid.len :
    let posY:float=cellToPos(cy)
    #line(0.0,posY,gameWidth,posY)
    for cx in 0..<grid[cy].len :
      let posX:float=cellToPos(cx)
      var tileColor= if (colorCounter mod 2) == 0 : Color("#45b805") else : Color("#96df00")
      setColor(tileColor)
      rectangle(DrawModes.Fill,posX-gridSize*0.5,posY-gridSize*0.5,gridSize,gridSize)
      colorCounter+=1
      #line(posX,0.0,posX,gameHeight)
    
  # Draw frame
  setColor("#102323")
  setLine(8.0,JoinTypes.Round)
  rectangle(DrawModes.Line,-4,-4,gameWidth+4,gameHeight+4)

  drawSnake()
  drawApples()

  #Drawing Game UI Panels
  if not gameStarted :
    drawWelcomePanel()

  if isGameOver :
    drawGameOverPanel()

  pop()
  
  # HUD - Score and Instructions
  setColor("#102323")
  var scoreStr="SCORE:" & $score
  var scoreText=newText(scoreStr, getDefaultFont() )
  var scoreTextWidth=scoreText.getSizeWith(32.float).x
  draw(scoreText,(window.getWidth().float*0.5)-(scoreTextWidth*0.5),16,32.0 )

  #Drawing Information
  var infoStr="Use WASD or Arrow Keys to Move Snake. | Press [Space] Key to Toggle Smooth Mode "
  var infoText=newText(infoStr, getDefaultFont() )
  var infoTextWidth=infoText.getSizeWith(16.float).x
  draw(infoText,(window.getWidth().float*0.5)-(infoTextWidth*0.5),window.getHeight().float-32,16.0 )


  
  discard

run("Snake Game",load,update,draw,config)

#endregion