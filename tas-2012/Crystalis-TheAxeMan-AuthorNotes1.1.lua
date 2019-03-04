--[[
Crystalis TAS lua scripts by TheAxeMan

Copyright notice for this file:
 Copyright (C) 2011 TheAxeMan

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
--]]

--I normally keep a few files but they are combined to get a one-file script

require 'auxlib';

--Global value to track whether we are on dolphin or not.
dolphinMode = false

--Returns true if hitting diagonal this frame will result in 2 pixel movement.
function fastDiagonalThisFrame()
  local counter = memory.readbyte(0x0480)
  if counter % 2 == 1 then return true end;
  return false
end;

--Returns true if the "wait to move" counter is keepng you from moving
function mustWaitToMove()
  local counter = memory.readbyte(0x0DA0)
  if counter > 1 then return true end;
  return false
end;

--No input for some number of frames
function skipFrame(num)
  if num==nil then num=1 end;
  for i=1,num do
    joypad.set(1, {})
    frameAdvanceWithRewind()
  end
end

function getPlayerCoords()
  local pdata = {}
  pdata.px = 256*memory.readbyte(0x0090) + memory.readbyte(0x0070)
  --for some reason the y coord rolls over at 240...
  pdata.py = 240*memory.readbyte(0x00d0) + memory.readbyte(0x00b0)
  pdata.relx = memory.readbyte(0x05c0)
  pdata.rely = memory.readbyte(0x05e0)
  return pdata
end;

--displays player coords onscreen
function showPlayerCoords()
  local pdata = getPlayerCoords()
  if pdata.relx > 0 and pdata.relx < 255 and
     pdata.rely > 0 and pdata.rely < 240 then
    safetext(math.max(0,pdata.relx-20),pdata.rely,pdata.px..","..pdata.py)
  end;
end;

function showPlayerHitbox()
  local pdata = getPlayerCoords()
  --Draw hitbox. Offsets are stored in the same table as the
  --enemies, but I'll just hardcode here.
  --When hitboxes exactly touch the hit happens when player is
  --on the right or bottom. So player hitbox has been expanded
  --a pixel to account for this.
  local x1 = pdata.relx - 7
  local x2 = pdata.relx + 6
  local y1 = pdata.rely - 1
  local y2 = pdata.rely - 22
  safebox(x1,y1,x2,y2,"green")
  --gui.text(50,50,x1..","..y1.." "..x2..","..y2);
end;

--Get the hitbox for a sword shot. The offset tells what shot it is.
--For a simple shot, offset is 4.
function getShotHitbox(offset)
  local mem1 = memory.readbyte(0x03a0+offset)
  local mem2 = memory.readbyte(0x0420+offset)
  local hbtableOffset = OR(4*AND(mem1, 0x0F), AND(mem2, 0x40))
  --get rel coords of shot
  local relx = memory.readbyte(0x05c0+offset)
  local rely = memory.readbyte(0x05e0+offset)

  local hitbox = {}
  hitbox.x1 = relx + memory.readbyte(0x9691+hbtableOffset) - 256
  hitbox.x2 = hitbox.x1 + memory.readbyte(0x9692+hbtableOffset)
  hitbox.y1 = rely + memory.readbyte(0x9693+hbtableOffset) - 256
  hitbox.y2 = hitbox.y1 + memory.readbyte(0x9694+hbtableOffset)

  --Adjust left and top sides to account for touching hitbox behavior.
  hitbox.x1 = hitbox.x1-1
  hitbox.y1 = hitbox.y1-1

  return hitbox
end;

function showShotHitbox()
  --For now, only simple shots are supported.
  local offset
  for offset=4,12 do
    if memory.readbyte(0x04a0+offset) ~= 0 then 
      local hitbox = getShotHitbox(offset)
      safebox(hitbox.x1, hitbox.y1, hitbox.x2, hitbox.y2,"green")
    end;
  end;
end;

--Shows actual sword hitbox based on coords that pop up when swinging.
function showActualSwordHitbox()
  --When hitboxes exactly touch the hit happens when sword is
  --on the right or bottom. So sword hitbox has been expanded
  --a pixel to account for this.
  --Note that hit detection only happens every other frame, so
  --overlapping hitboxes won't necessarily result in a hit.
  local relx = memory.readbyte(0x05c2)
  local rely = memory.readbyte(0x05e2)
  safebox(relx-6, rely-14, relx+5, rely-3 ,"green")
end;

--Helper function to draw each box at offset from player coords
local function drawSwordBox(dir, x, y)
  if     dir == "l" then x=x-14; y=y-3
  elseif dir == "r" then x=x+14; y=y-3
  elseif dir == "u" then         y=y-19
  elseif dir == "d" then         y=y+14
  end;
  if dolphinMode then
    y = y + 2
    safebox(x-6, y-14, x+5, y-3 ,"#e69c2d")
  else
    safebox(x-6, y-14, x+5, y-3 ,"blue")
  end;
end;

function showPotentialSwordHitbox(showDiag)
  --Shows all possible sword hitbox locations on the next frame.
  --When hitboxes exactly touch the hit happens when sword is
  --on the right or bottom. So sword hitbox has been expanded
  --a pixel to account for this.
  --Note that hit detection only happens every other frame, so
  --overlapping hitboxes won't necessarily result in a hit.
  local pdata = getPlayerCoords()
  --One step in each dir
  drawSwordBox("l", pdata.relx-2, pdata.rely)
  drawSwordBox("r", pdata.relx+2, pdata.rely)
  drawSwordBox("u", pdata.relx, pdata.rely-2)
  drawSwordBox("d", pdata.relx, pdata.rely+2)

  if showDiag then
    --One step in each diag dir
    local diagStep
    if fastDiagonalThisFrame() then
      diagStep = 2
    else
      diagStep = 1
    end;
    drawSwordBox("u", pdata.relx-diagStep, pdata.rely-diagStep)
    drawSwordBox("u", pdata.relx+diagStep, pdata.rely-diagStep)
    drawSwordBox("r", pdata.relx+diagStep, pdata.rely+diagStep)
    drawSwordBox("d", pdata.relx-diagStep, pdata.rely+diagStep)
  end;

  --Now account for the funky extension, but only for manhattan dirs
  drawSwordBox("l", pdata.relx-5, pdata.rely)
  drawSwordBox("r", pdata.relx+5, pdata.rely)
  drawSwordBox("u", pdata.relx, pdata.rely-5)
  drawSwordBox("d", pdata.relx, pdata.rely+5)

end;

local function coordsAreSafe(x,y)
  return x > 0 and x < 255 and y > 0 and y < 240
end;

-- draw a box and take care of coordinate checking
function safebox(x1,y1,x2,y2,color,style)
	if coordsAreSafe(x1,y1) and coordsAreSafe(x2,y2) then
    --The nil here specifies an open box instead of filled.
		gui.drawbox(x1,y1,x2,y2,nil,color);
    if style == "x" then
      gui.drawline(x1,y1,x2,y2,color)
      gui.drawline(x1,y2,x2,y1,color)
    end;
	end;
end;
-- safety wrapper around gui.text
function safetext(x, y, t)
	if coordsAreSafe(x,y) then gui.text(x, y, t) end;
end;

function displayGlobalCounter()
  local counter = memory.readbyte(0x0008)
  gui.text(80,10,toHexStr(counter))
end;
function displaySwordCounter()
  local counter = memory.readbyte(0x0600)
  if counter > 0 then gui.text(80,20,counter) end;
end;
function displaySwordChargeCounter()
  local counter = memory.readbyte(0x0EC0)
  if counter > 0 then gui.text(80,30,counter) end;
end;
function displayRandSeed()
  local seed = memory.readbyte(0x000E)
  gui.text(200,10,seed)
end;
function displayRelCoords()
  local pdata = getPlayerCoords()
  gui.text(190,20,pdata.relx..","..pdata.rely)
end;
function displaySlopeCounter()
  local slopeCounter = memory.readbyte(0x0660)
  --iup.Message("debug", "slope counter is "..slopeCounter)
  if slopeCounter > 0 then
    --iup.Message("debug", "nonzero slope counter")
    gui.text(200,30,slopeCounter)
  end;
end;
function displayFastDiagonalIndicator()
  if dolphinMode then
    local counter = memory.readbyte(0x0480)
    if (counter % 4) == 0 then
      gui.text(120,20,"")
    else
      gui.text(120,20,"D")
    end;
    if (counter % 2) == 0 then
      gui.text(130,20,"M")
    else
      gui.text(130,20,"")
    end;
  else
    if fastDiagonalThisFrame() then
      gui.text(120,20,"D")
    else
      gui.text(120,20,"")
    end;
  end;
end;
function displayWaitToMoveIndicator()
  if mustWaitToMove() then
    gui.text(130,20,"W")
  else
    gui.text(120,20,"")
  end;
end;


--for convenience in toggling menu items
function toggleMenuItem(i)
  if i.value == "ON" then
    i.value = "OFF"
  else
    i.value = "ON"
  end
end;

--Radio button function. Give it a list of items to act as radio with.
function toggleRadioItem(ritem, rlist)
  --Nothing to do if item is already on
  if ritem.value == "OFF" then
    for i,h in ipairs(rlist) do h.value="OFF" end;
    ritem.value = "ON"
    rlist.value = ritem.title
  end;
end;

function toHexStr(n)
	return string.format("%X",n);
end;


local function toHexStr(n)
	return string.format("%X",n);
end;

--[[
Set up the table as far as what columns and how many enemies
are displayed. Closest enemies get in table. Available items:
index - identifier for each enemy
dist - total distance from player to enemy
dx - x distance to enemy. + is right, - is left
dy - y distance to enemy. + is up, - is down
ex - x coords of enemy
ey - y coords of enemy
relx - screen-relative x coords of enemy
rely - screen-relative y coords of enemy
hp - enemy hp remaining
state - number describing life or death of enemy.
--]]

--The columns will always appear in this order. Also, this is the main list
--that all other lists are based on.
local allOrderedEnemyDataHeaders = {
        "index",
        "dx",
        "dy",
        "hp",
        "state",
        "living",
        "dist",
	"angle",
        "ex",
        "ey",
        "dir",
        "count",
        "relx",
        "rely",
        "spawnx",
        "spawny",
        "spawndx",
        "spawndy",
        "spawnCountdown",
        "spawnOk"}

--Initialize the matrix
local enemyDataMatrix = iup.matrix {resizematrix = "YES"}
--Create a frame with the matrix in it
enemyDataFrame = iup.frame{
        iup.vbox{
          testBtn,
          iup.fill{size="5"},
          enemyDataMatrix,
          iup.fill{},
        },
        title="Enemy Data",
        margin="10x10"
};

--Build the menu to be added to the main console
--First, submenus for number of enemies and enemy indexes
local numEnemiesToDisplayMenu = iup.menu{}
local numEnemiesToDisplayList = {}
local enemyIndexesToDisplayMenu = iup.menu{}
local enemyIndexesToDisplay = {}
for i = 1,16 do
  table.insert(numEnemiesToDisplayList, iup.item{
          title = i,
          value = "OFF",
          action = function(self)
                  toggleRadioItem(self, numEnemiesToDisplayList)
                  updateEnemyDataMatrixHeaders()
          end;
  })
  iup.Append(numEnemiesToDisplayMenu, numEnemiesToDisplayList[#numEnemiesToDisplayList])

  table.insert(enemyIndexesToDisplay, false)
  iup.Append(enemyIndexesToDisplayMenu, iup.item{
          title = i,
          value = "OFF",
          action = function(self)
                  toggleMenuItem(self)
                  enemyIndexesToDisplay[tonumber(self.title)] = not enemyIndexesToDisplay[tonumber(self.title)]
                  updateEnemyDataMatrixHeaders()
          end;
    }
  )
end;
--Set default num enemies
numEnemiesToDisplayList.value = 5
numEnemiesToDisplayList[numEnemiesToDisplayList.value].value = "ON"

--Set up the list of enabled headers
local enemyDataHeaders = {}
for i,h in ipairs(allOrderedEnemyDataHeaders) do
  enemyDataHeaders[h] = false
end;
--Enable some of them
enemyDataHeaders.index = true
enemyDataHeaders.living = true
enemyDataHeaders.spawnCountdown = true
enemyDataHeaders.hp = true
enemyDataHeaders.state = true
enemyDataHeaders.dir = true
enemyDataHeaders.count = true
enemyDataHeaders.ex = true
enemyDataHeaders.ey = true
enemyDataHeaders.spawndx = true
enemyDataHeaders.spawndy = true
enemyDataHeaders.spawnOk = true

--Submenu for header fields to display
local enemyDataHeadersToDisplayMenu = iup.menu{}
for i,h in ipairs(allOrderedEnemyDataHeaders) do
  local headerDisplayItem = iup.item{
          title = h,
          action = function(self)
                  toggleMenuItem(self)
                  enemyDataHeaders[self.title] = not enemyDataHeaders[self.title]
                  updateEnemyDataMatrixHeaders()
          end;
    }
  if enemyDataHeaders[h] then
          headerDisplayItem.value = "ON"
  else
          headerDisplayItem.value = "OFF"
  end;
  iup.Append(enemyDataHeadersToDisplayMenu, headerDisplayItem)
end;

--Ordered table of enabled data headers
local orderedEnemyDataHeaders = {}
--Table mapping data header names to cell column number
local enemyDataHeaderOrderMap = {}
--Tracks option of showing only closest enemies
local showClosestEnemiesOnly = false

--Set all the header cells in the matrix and fix the size.
--Also updates mapping tables.
function updateEnemyDataMatrixHeaders()
  --First take care of columns
  local col = 0
  orderedEnemyDataHeaders = {}
  enemyDataHeaderOrderMap = {}
  for i,h in ipairs(allOrderedEnemyDataHeaders) do
    if enemyDataHeaders[h] then
      col = col+1
      enemyDataMatrix["width"..col]="30"
      enemyDataMatrix:setcell(0,col,h)
      table.insert(orderedEnemyDataHeaders, h)
      enemyDataHeaderOrderMap[h] = col
    end;
  end;
  enemyDataMatrix.numcol = col
  enemyDataMatrix.numcol_visible = col

  --Now set number of lines
  local lines = 0
  if showClosestEnemiesOnly then
    lines = tonumber(numEnemiesToDisplayList.value)
  else
    for i = 1,16 do
      if enemyIndexesToDisplay[i] then lines = lines + 1 end;
    end;
  end;
  enemyDataMatrix.numlin = lines
  enemyDataMatrix.numlin_visible = lines

end;

--Initial setup of table
updateEnemyDataMatrixHeaders()

-- *** Interface ***
--Check showClosestEnemiesOnly to see whether sorting by distance or index
--Use enemyIndexesToDisplay to see if an index is selected
--To get number of enemies to display, access numEnemiesToDisplayList.value
--Use enemyDataHeaders to see if a header is enabled
--orderedEnemyDataHeaders is a list of just the enabled columns
--enemyDataHeaderOrderMap is a table mapping header name to column number

--Set up the menu
enemyDataOptions = iup.submenu{
      iup.menu{
        iup.submenu{
                enemyDataHeadersToDisplayMenu,
                title = "Columns to Display"
        },
        iup.separator{},
        iup.item{
          title = "Display Closest Enemies Only",
          value = "OFF",
          action = function(self)
                  toggleMenuItem(self)
                  showClosestEnemiesOnly = not showClosestEnemiesOnly
                  updateEnemyDataMatrixHeaders()
          end;
        },
        iup.submenu{
                numEnemiesToDisplayMenu,
                title = "Number of Enemies to Display"
        },
        iup.separator{},
        iup.submenu{
                enemyIndexesToDisplayMenu,
                title = "Enemy Indexes to Display"
        }
      }; title = "Enemy Data Options"
}

function getEnemyData(offset)
  local edata = {}
  local x0 = memory.readbyte(0x007c+offset)
  local x1 = memory.readbyte(0x009c+offset)
  local y0 = memory.readbyte(0x00bc+offset)
  local y1 = memory.readbyte(0x00dc+offset)
  edata.ex = x1 * 256 + x0
  edata.ey = y1 * 240 + y0
  edata.hp = memory.readbyte(0x03cc+offset)
  edata.relx = memory.readbyte(0x05cc+offset)
  edata.rely = memory.readbyte(0x05ec+offset)
  edata.state = memory.readbyte(0x04ac+offset)
  edata.dir = memory.readbyte(0x036c+offset)
  edata.count = memory.readbyte(0x048c+offset)
  local mem1 = memory.readbyte(0x03ac+offset)
  local mem2 = memory.readbyte(0x042c+offset)
  edata.hbtableOffset = OR(4*AND(mem1, 0x0F), AND(mem2, 0x40))

  return edata
end;

local function esorter(a,b)
  return a.dist < b.dist
end;

--Builds up a table with information on all 16 enemies
function getAllEnemyData()
  --need player data to calculate dx and dy
  local pdata = getPlayerCoords()
  local counter = memory.readbyte(0x0008)
  local all_edata = {}
  local screenx = memory.readbyte(0x0002) + 256 * memory.readbyte(0x0003)
  local screeny = memory.readbyte(0x0004) + 240 * memory.readbyte(0x0005)
  local rightScreenEdge = 255
  --local bottomScreenEdge = 175   --Original thought, but seems to be wrong...
  local bottomScreenEdge = 239
  for i=1,16 do
    local edata = getEnemyData(i)
    edata.index = i
    if edata.state == 0 or edata.state == 125 then
      edata.living = "dead"
    elseif edata.state == 123 then
      edata.living = "coin"
    else
      edata.living = "alive"
    end;
    if edata.dir == 0 then
      edata.dir = "up"
    elseif edata.dir == 2 then
      edata.dir = "right"
    elseif edata.dir == 4 then
      edata.dir = "down"
    elseif edata.dir == 6 then
      edata.dir = "left"
    end;
    
    edata.spawnCountdown = (counter - 16*(i-1)) % 256
    --edata.spawnx, edata.spawny = getEnemySpawnPoint(edata.index)
    edata.spawnx, edata.spawny = 0, 0
    edata.spawndx = edata.spawnx - screenx
    edata.spawndy = edata.spawny - screeny
    if edata.spawndx < 0 or edata.spawndx > rightScreenEdge or 
       edata.spawndy < 0 or edata.spawndy > bottomScreenEdge then
      edata.spawnOk = "yes"
    else
      edata.spawnOk = "no"
    end;
    edata.dx = edata.ex - pdata.px
    edata.dy = pdata.py - edata.ey
    edata.dist = math.floor(math.sqrt(edata.dx*edata.dx + edata.dy*edata.dy))

    edata.angle = -math.floor(180/math.pi * math.atan2(edata.dy, -edata.dx))

    table.insert(all_edata, edata)
  end;
  return all_edata
end;

--Determines spawn point of enemy
function getEnemySpawnPoint(eIndex)
  --Spawn table is indexed using an area id and enemy index
  local areaId = memory.readbyte(0x006c)  --This isn't paged out
  local offset = (areaId * 2) % 256
  local areaSpawnTable = 256 * readDump9200(0x9202+offset) + readDump9200(0x9201+offset)

  --Correction for some areas
  if areaId * 2 >= 256 then
    areaSpawnTable = 256 * readDump9200(0x9302+offset) + readDump9200(0x9301+offset)
  end;

  local spawnTableOffset = eIndex * 4 + 1

  --Some values read from the table
  local tempc = readDump9200(areaSpawnTable + spawnTableOffset)
  local tempd = readDump9200(areaSpawnTable + spawnTableOffset + 1)
  local tempe = readDump9200(areaSpawnTable + spawnTableOffset + 2)
  if tempc == nil then tempc = 0 end;
  if tempd == nil then tempd = 0 end;
  if tempe == nil then tempe = 0 end;
  local temp0 = math.floor(AND(tempe, 0x40) / 8)

  --x and y are calculated
  local xh = AND(0x07, math.floor(tempd / 16))
  local xl = ((tempd * 2) % 256) + 1
  xl = ((xl * 8) % 256) + temp0

  local yh = AND(0x0F, math.floor(tempc / 16))
  local yl = OR(0x0C, (tempc * 16) % 256)
  --Actually, it is an ASL so carry could matter.

  --Still need to look at logic for y
  return xl + xh*256, yl + yh*240
end;

--update table with enemy data
function updateEnemyGui()
  --grab the data we need
  local all_edata = getAllEnemyData()

  --sort by distance if necessary
  if showClosestEnemiesOnly then table.sort(all_edata, esorter) end;

-- *** Interface ***
--Check showClosestEnemiesOnly to see whether sorting by distance or index
--Use enemyIndexesToDisplay to see if an index is selected
--To get number of enemies to display, access numEnemiesToDisplayList.value
--Use enemyDataHeaders to see if a header is enabled
--orderedEnemyDataHeaders is a list of just the enabled columns
--enemyDataHeaderOrderMap is a table mapping header name to column number

  local redraw = false
  local line = 0
  local processLine = false
  --update table
  for i=1,16 do
    if showClosestEnemiesOnly then
      if i > tonumber(numEnemiesToDisplayList.value) then break end;
      line = i
      processLine = true
    elseif enemyIndexesToDisplay[i] then
      line = line + 1
      processLine = true
    else
      processLine = false
    end

    if processLine then
      for colName,colIndex in pairs(enemyDataHeaderOrderMap) do
        if enemyDataMatrix:getcell(line,colIndex) ~= all_edata[i][colName] then redraw = true end;
        enemyDataMatrix:setcell(line,colIndex,all_edata[i][colName])
      end;
    end; --processLine
  end;
  if redraw then enemyDataMatrix.redraw = "ALL" end;
end;

function getEnemyHitBox(edata)
  local mem1 = memory.readbyte(0x03ac+edata.index)
  local mem2 = memory.readbyte(0x042c+edata.index)
  local hbtableOffset = OR(4*AND(mem1, 0x0F), AND(mem2, 0x40))

  local hitbox = {}
  hitbox.x1 = edata.relx + memory.readbyte(0x9691+hbtableOffset) - 256
  hitbox.x2 = hitbox.x1 + memory.readbyte(0x9692+hbtableOffset)
  hitbox.y1 = edata.rely + memory.readbyte(0x9693+hbtableOffset) - 256
  hitbox.y2 = hitbox.y1 + memory.readbyte(0x9694+hbtableOffset)
  return hitbox
end;

hideZeroHpEnemies = true

--displays onscreen text with enemy hp
function showEnemyHp()
  local edata = {}

  --grab the data we need
  local all_edata = getAllEnemyData()

  --display hp and hitbox
  for i=1,#all_edata do
    edata = all_edata[i]
    if not hideZeroHpEnemies or edata.hp > 0 then
    if edata.relx > 1 and edata.rely > 17 and 
       edata.relx < 255 and edata.rely < 231 and 
       edata.dist < 200 and edata.state ~= 0 then
      --Now we've ensured enemy is alive and onscreen.
      safetext(edata.relx, edata.rely, edata.hp)
      safetext(edata.relx, edata.rely+10, "E"..edata.index)
    end;
    end;
  end;
end;

function showEnemyHitbox()
  local edata = {}

  --grab the data we need
  local all_edata = getAllEnemyData()

  --display hp and hitbox
  for i=1,#all_edata do
    edata = all_edata[i]
    if edata.relx > 1 and edata.rely > 17 and 
       edata.relx < 255 and edata.rely < 231 and 
       edata.dist < 200 and edata.state ~= 0 then
      --Now we've ensured enemy is alive and onscreen.
      local hitbox = getEnemyHitBox(edata)
      safebox(hitbox.x1,hitbox.y1,hitbox.x2,hitbox.y2,"red")
    end;
  end;
end;

function showSpawnPoints()
  local all_edata = getAllEnemyData()
  local screenx = memory.readbyte(0x0002) + 256 * memory.readbyte(0x0003)
  local screeny = memory.readbyte(0x0004) + 240 * memory.readbyte(0x0005)

  for i=1,#all_edata do
    edata = all_edata[i]
    if edata.state == 0 then
      local spawnx, spawny = getEnemySpawnPoint(edata.index)
      local spawnrelx = spawnx - screenx
      local spawnrely = spawny - screeny
      safebox(spawnrelx-10, spawnrely-10, spawnrelx+10, spawnrely+10, "red", "x")
    end; --edata.state==0
  end;

end;

--This function is used to detect rewind. Can use input.get to
--read keyboard or check some joypad button. 
local function readRewindButton()
  keysPressed = input.get()
  --return keysPressed["R"] or joypad.read(rewindController)[rewindButton];
  --Check flag and r key.
  return keysPressed["R"];
end;


rewindBuffer = {}
rewindBufferJoypad = {}
--This is the buffer length in frames
rewindBufferLength = 1000
--current position in buffer
rewindBufferDepth = 0
--flag for displaying messages
rewindShowMessages = true
rewindExpectedNextFramecount = movie.framecount()
rewindLastFrameCount = rewindExpectedNextFramecount-1

--Fill up buffer with empty savestates
for i=0,rewindBufferLength-1 do
  rewindBuffer[i] = savestate.create()
  rewindBufferJoypad[i] = {}
end;

--gui.text(10,30,rewindExpectedNextFramecount)
--FCEU.pause()

local function manageRewind()
  local currentFrame = movie.framecount()
  local framesBack = 0
  local bufferIndex = 0
  local joypadBufferIndex = 0
  if currentFrame ~= rewindExpectedNextFramecount then
    --FCEU.message("Unexpected framecount. Reset or loaded state?")
    --handle a reset or state load
    framesBack = rewindExpectedNextFramecount - currentFrame
    if framesBack > 0 and framesBack < rewindBufferDepth then
      --Part of the buffer is salvagable, assuming that this
      --save rewinded along the same timestream.
      rewindBufferDepth=rewindBufferDepth - framesBack
    else
      if rewindShowMessages then FCEU.message("Rewind buffer flushed"); end
      rewindBufferDepth=0
    end;
    --compute new buffer depth based on framecount
    --FCEU.pause()
    rewindExpectedNextFramecount = currentFrame + 1
  elseif readRewindButton() then
    --rewind
    --Note that we need to read the input from the frame before last.
    --That means 2 frames of buffer is minimal.
    if rewindBufferDepth <= 2 then
      if rewindShowMessages then gui.text(70,10,"End of rewind buffer"); end
      --nothing left in buffer
      --FCEU.message("At beginning of buffer")
      bufferIndex = math.fmod(currentFrame-framesBack, rewindBufferLength)
      savestate.load(rewindBuffer[bufferIndex])
      rewindExpectedNextFramecount = currentFrame
    else
      --rewind
      if rewindShowMessages then gui.text(70,10,"Rewinding"); end
      framesBack = 2
      bufferIndex = math.fmod(currentFrame-framesBack, rewindBufferLength)
      savestate.load(rewindBuffer[bufferIndex])
      joypadBufferIndex = math.fmod(currentFrame-framesBack+1, rewindBufferLength)
      --joypadBufferIndex = bufferIndex
      joypad.set(1, rewindBufferJoypad[joypadBufferIndex])
      rewindBufferDepth = rewindBufferDepth - framesBack + 1
      rewindExpectedNextFramecount = currentFrame - framesBack + 1
      --gui.text(10,50,"loaded slot "..bufferIndex)
      --FCEU.pause()
    end;
  else
    if rewindShowMessages then gui.text(70,10,""); end
    --add current frame state to buffer
    bufferIndex = math.fmod(currentFrame, rewindBufferLength)
    savestate.save(rewindBuffer[bufferIndex])
    rewindBufferJoypad[bufferIndex] = joypad.read(1)
    --gui.text(10,50,"saved slot "..bufferIndex)
    if rewindBufferDepth < rewindBufferLength then
      rewindBufferDepth = rewindBufferDepth + 1
    end;
    rewindExpectedNextFramecount = currentFrame + 1
  end;
  rewindLastFrameCount = currentFrame
  
  --gui.text(10,10,"buffer depth is "..rewindBufferDepth)
  --gui.text(10,20,"framecount is "..currentFrame)
  --gui.text(10,30,"next frame should be "..rewindExpectedNextFramecount)
end;

-- So in order to get rewinding, just replace the normal frameadvance call with this.
function frameAdvanceWithRewind()
  FCEU.frameadvance()
  manageRewind();
end;
function pauseWithRewind()
  FCEU.pause()
  manageRewind();
end;

--For programmatic rewind, reverse the forward order of advance then manage.
function frameRewind(num)
  --rewind
  --if rewindShowMessages then gui.text(70,10,"Rewinding"); end
  local framesBack = num+1
  currentFrame = movie.framecount()
  local bufferIndex = math.fmod(currentFrame-framesBack, rewindBufferLength)
  savestate.load(rewindBuffer[bufferIndex])
  joypadBufferIndex = math.fmod(currentFrame-framesBack+1, rewindBufferLength)
  --joypadBufferIndex = bufferIndex
  joypad.set(1, rewindBufferJoypad[joypadBufferIndex])
  rewindBufferDepth = rewindBufferDepth - framesBack + 1
  rewindExpectedNextFramecount = currentFrame - framesBack + 1
  frameAdvanceWithRewind()
end;

--count consecutive lag frames
pauseOnLagLagCount = 0
--pause after this many consecutive lag frames
pauseOnLagMinLagFrames = 3
--Reset count if anything besides a simple frame advance happened since the last call.
pauseOnLagLastFramecount = movie.framecount()
function pauseOnLastLagFrame()
  if movie.framecount() ~= pauseOnLagLastFramecount+1 then
    pauseOnLagLastFramecount = movie.framecount()
    pauseOnLagLagCount = 0
    return;
  end;
  pauseOnLagLastFramecount = movie.framecount()
  if FCEU.lagged() then
    --increment counter
    pauseOnLagLagCount = pauseOnLagLagCount + 1
  elseif pauseOnLagLagCount >= pauseOnLagMinLagFrames then
    --pause and reset counter
    frameRewind(2)
    pauseOnLagLagCount = 0
    --now forward a frame to let it rewind
    --Normally this would be bad but here it's ok because it's just lag
    joypad.set(1, {})
    pauseWithRewind()
  else
    --just reset counter
    pauseOnLagLagCount = 0
  end;
end;

--[[
--  Example usage.
--
while true do
  pauseOnLastLagFrame()
  frameAdvanceWithRewind()
end;
--]]




--Set up the list of registered gui functions
gui_registered_funcs = {}
all_ordered_registered_funcs = {}
local function register_func(fname, f)
  table.insert(all_ordered_registered_funcs, fname)
  gui_registered_funcs[fname] = f
end;

--Draw a pixel that just copies the one it replaces to refresh screen.
local function refreshScreen()
  color = emu.getscreenpixel(0, 0)
  gui.setpixel(0, 0, color)
end;

--Add all the functions. They will be ordered this way.
register_func("showEnemyHp", showEnemyHp)
register_func("displayGlobalCounter", displayGlobalCounter)
register_func("displayRandSeed", displayRandSeed)
register_func("displaySwordCounter", displaySwordCounter)
register_func("displaySwordChargeCounter", displaySwordChargeCounter)
register_func("displayFastDiagonalIndicator", displayFastDiagonalIndicator)
register_func("showPotentialSwordHitbox", showPotentialSwordHitbox)
register_func("showPlayerCoords", showPlayerCoords)
register_func("displayRelCoords", displayRelCoords)
register_func("displaySlopeCounter", displaySlopeCounter)
register_func("showEnemyHitbox", showEnemyHitbox)
register_func("showPlayerHitbox", showPlayerHitbox)
register_func("showActualSwordHitbox", showActualSwordHitbox)
register_func("showShotHitbox", showShotHitbox)
register_func("refreshScreen", refreshScreen)

--The actual registered function calls all non-nil items in the registration table.
gui.register( function()
  for i,fname in ipairs(all_ordered_registered_funcs) do
    f = gui_registered_funcs[fname]
    --can set value to nil to  turn off
    if f then f() end;
  end;
end)

--To toggle a feature, swap function pointer into a disabled function table.
disabled_funcs = {}
local function toggleFeature(fname)
  disabled_funcs[fname], gui_registered_funcs[fname] = 
              gui_registered_funcs[fname], disabled_funcs[fname]
end;

--Disable all the features
for i,fname in ipairs(all_ordered_registered_funcs) do
  toggleFeature(fname)
end;

--Always refresh screen
toggleFeature("refreshScreen")

featureItems = {}
local function makeFeatureItem(title, fname)
  item = iup.item{
               title=title,
               value="OFF",
               fname=fname,
               action=function(self) 
                       toggleFeature(self.fname) 
                       toggleMenuItem(self)
               end}
  featureItems[fname] = item
  return item
end;

local function showAllFeatures(showNotHide)
  for i,fname in ipairs(all_ordered_registered_funcs) do
    if fname ~= "refreshScreen" then
      if (showNotHide and gui_registered_funcs[fname] == nil) or
         (not showNotHide and gui_registered_funcs[fname] ~= nil) then
        toggleFeature(fname)
        toggleMenuItem(featureItems[fname])
      end
    end
  end
end;

--This is used by various routines to adjust to dolphin.
dolphinMode = false
--Toggle rewind enable
enableRewind = false
--Fast-forward grind
turboOnGrind = false
--Show tricks when enabled
showTricks = true
--Show 0 hp for enemies
hideZeroHpEnemies = false

local showTricksItem = iup.item{
          title = "Show Tricks",
          value="ON",
          action = function(self)
                  showTricks = not showTricks
                  toggleMenuItem(self)
          end}

local mainMenu=iup.menu{
    iup.submenu{
      iup.menu{
        makeFeatureItem("Player Coords", "showPlayerCoords"),
        makeFeatureItem("Player Screen-Relative Coords", "displayRelCoords"),
        makeFeatureItem("Player Hitbox", "showPlayerHitbox"),
        makeFeatureItem("Actual Sword Hitbox", "showActualSwordHitbox"),
        makeFeatureItem("Potential Sword Hitboxes", "showPotentialSwordHitbox"),
        makeFeatureItem("Enemy Hp", "showEnemyHp"),
        makeFeatureItem("Enemy Hitbox", "showEnemyHitbox"),
        makeFeatureItem("Global Counter", "displayGlobalCounter"),
        makeFeatureItem("RNG Seed", "displayRandSeed"),
        makeFeatureItem("Slope Counter", "displaySlopeCounter"),
        makeFeatureItem("Sword Counter", "displaySwordCounter"),
        makeFeatureItem("Sword Charge Counter", "displaySwordChargeCounter"),
        makeFeatureItem("Sword Shot Hitbox", "showShotHitbox"),
        makeFeatureItem("Fast Diagonal Indicator", "displayFastDiagonalIndicator"),
        iup.separator{},
        iup.item{
          title = "Show All",
          action = function(self)
                  showAllFeatures(true)
		  if showTricks then
                    showTricks = not showTricks
                    toggleMenuItem(showTricksItem)
		  end;
	  end},
        iup.item{
          title = "Hide All",
          action = function(self)
                  showAllFeatures(false)
          end}
      }; title="Display",
    },
    iup.submenu{
      iup.menu{
        iup.item{
          title = "Enable Rewind",
          value="OFF",
          action = function(self)
                  enableRewind = not enableRewind
                  toggleMenuItem(self)
          end},
	showTricksItem,
        iup.item{
          title = "Fast-forward Grinding",
          value="OFF",
          action = function(self)
                  turboOnGrind = not turboOnGrind
                  toggleMenuItem(self)
          end},
      }; title="Options",
    },
  };

maintext = iup.text{multiline="YES", readonly="YES", expand="YES", wordwrap="YES"}
maintextNoteList = {}

local function showTrickFunc(fname, showNotHide)
  if (featureItems[fname].value == "OFF" and showNotHide) or 
     (featureItems[fname].value == "ON" and not showNotHide) then
    toggleFeature(fname)
    toggleMenuItem(featureItems[fname])
  end
end;

local function makeShowTrickFunc(fname, showNotHide)
  return function()
      showTrickFunc(fname, showNotHide)
  end
end;

local function showOrHideAllHitboxes(showNotHide)
  showTrickFunc('showActualSwordHitbox', showNotHide)
  showTrickFunc('showShotHitbox', showNotHide)
  showTrickFunc('showPlayerHitbox', showNotHide)
  showTrickFunc('showEnemyHitbox', showNotHide)
end;

local function showAllHitboxes() showOrHideAllHitboxes(true) end
local function hideAllHitboxes() showOrHideAllHitboxes(false) end


eventList = {
        {time=10,    msg="Welcome to the TheAxeMan's Crystalis run!"},
        {time=240,   msg="Picking continue skips naming character"},
        {time=300,   msg="You can move freely before landing but you can only bounce in one direction. Bouncing diagonally saves a few frames on the next screen."},
        {time=1100,  msg="Using the shopping glitch I pay $30 for alarm flute (normally $50) and $50 for warp boots (normally $60). I can't get anything for free here because there is no blank in the list."},
        {time=1960,  msg="Equip my sword"},
        {time=2300,  msg="Meandering through the valley like this gets xp faster than grinding"},
        {time=2650,  msg="There is a blob down there. Underneath the status bar still counts as onscreen, so you can hit enemies there. You can also go there yourself if the screen scrolling is locked."},
        {time=3000,  msg="Let me introduce the Global Counter (GC). It's displayed at the top center of the screen. This is at RAM address 0008. It increments every non-lag frame and controls enemy spawning and many other things. Display is in hex because many things happen when lower nibble (or hex digit) is 0.", showtrick=makeShowTrickFunc('displayGlobalCounter', true)},
        {time=3300,  msg="Since it is one byte and increments every frame, that means one cycle takes 256 frames or a little over 4 seconds. So in the worst case that's how long you might have to wait for something to spawn."},
        {time=3800,  showtrick=makeShowTrickFunc('displayGlobalCounter', false)},
        {time=4000,  msg="Some enemies spawn immediately on entering an area. Others spawn at a certain GC value. Most of the enemies here spawn immediately on entering the area."},
        {time=4200,  msg="I'll describe the spawning process in more detail when the grinding begins"},
        {time=4850,  msg="Taking out two blobs at a time is about 5% more efficient. Makes for a grind rate of about 0.6 xp/sec."},
        {time=5000,  msg="Equip alarm flute"},
        {time=6000,  msg="Equip windmill key"},
        {time=6200,  msg="Somehow starting the windmill causes an explosion..."},
        {time=6600,  msg="Now let me introduce the seed for the RNG. Look at the upper right corner. This is at RAM address 000E. It increments when a random number is used. Any enemy that has a shot or attack uses this and some enemies use it for movement.", showtrick=makeShowTrickFunc('displayRandSeed', true)},
        {time=7200,  msg="Turning and shooting like this can give an enemy time to use another random number. One way to manipulate luck."},
        {time=7500,  showtrick=makeShowTrickFunc('displayRandSeed', false)},
        {time=7680,  msg="The blob down there moved right for me"},
        {time=8200,  msg="Refresh is the basic healing spell. I won't need it for this run."},
        {time=8700,  msg="I really wanted to spawn another slug here but couldn't make it on time"},
        {time=8850,  msg="Need to wait a little for a spawn here"},
        {time=9400,  msg="Seeing enemy hp onscreen is nice. Zero hp is still alive because the game kills off an enemy when hp-damage underflows. Below the hp is the enemy slot index. More on that later.", showtrick=makeShowTrickFunc('showEnemyHp', true)},
        {time=9730,  msg="Slugs and blobs are 2xp each. Dragons are 3xp.", showtrick=makeShowTrickFunc('showEnemyHp', false)},
        {time=10050,  msg="This golem is worth 4xp. Seems out of the way, but the timing worked out well."},
        {time=10300,  msg="The bats are only worth 1xp each, but they practically fly right into my sword"},
        {time=10500,  msg="Equip my new ball. Going to the menu advances the global counter so I do it during wait times if I can."},
        {time=11500,  msg="I tried a few different ways to handle this wall and this turned out best. Often saves time to lure an enemy near a wall and multitask by killing it while wall explodes"},
        {time=11600,  showtrick=makeShowTrickFunc('showEnemyHp', true)},
        {time=11800,  msg="Shots do more damage than stabs. Lvl2 shots do more than lvl1 shots. Takes 5 stabs to kill one of these dragons but a shot and 3 stabs will also work. Or a lvl2 shot, a lvl1 shot and a stab."},
        {time=12000,  showtrick=makeShowTrickFunc('showEnemyHp', false)},
        {time=12400,  msg="Don't blink"},
        {time=12600,  msg="Leading off with a lvl2 shot saves a hit. He sends two bats at me but they appear right on top of my sword."},
        {time=12700,  msg="Moving during the early part of the explosion causes lag. But once the screen stops shaking it's all right to dance."},
        {time=12800,  msg="By the way, that is one of the slower boss fights :)"},
        {time=13350,  msg="Welcome to Cordel Plains!", showtrick=makeShowTrickFunc('showEnemyHp', false)},
        {time=13500,  msg="That shot hits twice. Difficult to do with wind sword lvl2 but possible if the enemy is big enough."},
        {time=13800,  msg="Once again, these pigmen take 5 stabs, but 3 stabs and a lvl1 shot also works. Or two hits from a lvl2 shot and one lvl1 shot. 5xp each."},
        {time=14300,  msg="In the short term, it's slightly faster to visit Brynmaer first and then warp back after getting the statue. But there's a spot up ahead where we have to wait for a precise spot on the counter and the timing and xp worked better this way."},
        {time=14750,  msg="Equip the statue. As long as we're in the menu, equip those rabbit boots too."},
        {time=15200,  msg="With the blank in this item shop's list I can fill out my inventory with warp boots. This is also the best time to get a medical herb for later."},
        {time=15700,  msg="Now to show off the most important feature: hitboxes", showtrick=showAllHitboxes},
        {time=16250,  msg="Jumping over the swamp doesn't save as much time as you might think. It's usually not worth extra effort to equip the boots, but luckily we have them on now."},
        {time=16700,  showtrick=hideAllHitboxes},
        {time=16800,  msg="Equip gas mask and warp boots"},
        {time=17000,  msg="It is possible to get through here without the gas mask, but it takes too long. Options include pausing a lot, buying and using medical herbs and using all mp on refresh. Not worth it."},
        {time=17400,  msg="In order to warp back to Oak, you need to touch the hitbox just below the pond. This is a trigger for the next event.", showtrick=makeShowTrickFunc('showEnemyHitbox', true)},
        {time=17600,  msg="We saved a menu trip by already having warp boots equipped", showtrick=makeShowTrickFunc('showEnemyHitbox', false)},
        {time=18000,  msg="Taking out this enemy with shots like this is very efficient"},
        {time=18650,  msg="All right Stom, I'm coming for you!", showtrick=showAllHitboxes},
        {time=18959,  msg="You can beat Stom on the first try if you use a little finesse. Your sword is wider than his, so from the right position you can hit him while dodging his attack."},
        {time=19300,  showtrick=hideAllHitboxes},
        {time=19450,  msg="Equip warp boots. Note that I never unequipped gas mask."},
        {time=20350,  msg="The enemies in the swamp can be hurt by wind sword but not until level 4. It would be nice to get some xp here, but it saves time to wait until later when I can get xp faster."},
        {time=20750,  msg="Equip rabbit boots and warp boots. I guess he can wear one boot on top of the other?"},
        {time=21700,  msg="Equip my new fire sword and another warp boots. Then save the game and reset to execute the charge glitch."},
        {time=22000,  msg="Charge glitch: I can use lvl2 fire sword attacks despite not having the ball. This lets me skip the big bug fight in the swamp."},
        {time=22250,  msg="lvl2 fire shots may not lag much if well tweaked. Controlling screen scrolling and holding B button help."},
        {time=22500,  msg="An ideal spot to grind. Three enemy spawn points are close by and it is possible to kill them all every cycle. Each blob is worth 8xp, so 3*8xp / 256 frames comes out to 5.6 xp/sec. That will do for the next two levels, though it will still take a while."},
        {time=22800,  msg="On level 3 I need to use a shot to kill in one hit. On level 4 a stab is enough."},
        {time=23000,  turboOnGrind=true},
        {time=23100,  msg="As promised, I'll explain how spawning works now", showtrick=makeShowTrickFunc('displayGlobalCounter', true)},
        {time=23101,  showtrick=makeShowTrickFunc('showEnemyHp', true)},
        {time=23300,  msg="All data on enemies and other objects are stored in a table. The index that I show below hp tells me which slot the enemy or object is in."},
        {time=23700,  msg="Each area has a set of spawn points defined. Each of those spawn points is linked to an index in the enemy table."},
        {time=24000,  msg="Spawning is triggered for a spawn point at a certain point on the global counter. At that time the spawn point needs to be offscreen and its slot needs to be empty. These enemies spawn at A0, 90 and 80."},
        {time=24300,  msg="Of course the slot is not empty if the previously spawned enemy is still alive. But the slot can be occupied for other reasons."},
        {time=24600,  msg="Enemies spawn in a particular slot, but projectiles and coins can pop into any slot that is available at the time. Spawning will be blocked if they are still in that slot when spawn time hits."},
        {time=24900,  msg="That's why picking up coins can be important. Killing an enemy later or otherwise getting a coin to use a different slot can also work."},
        {time=25100,  msg="This can also make it important to manipulate enemy projectile attacks."},
        {time=25300,  msg="Dying enemies take some time to vacate their slot, so it's necessary to take out the previous enemy about 50 frames before the next one spawns."},
        {time=25600,  msg="These tricks can also be used to prevent enemies from spawning when I don't want them. So if I don't need their xp I can avoid some lag."},
        {time=25700,  turboOnGrind=false, showtrick=makeShowTrickFunc('displayGlobalCounter', false)},
        {time=25701,  showtrick=makeShowTrickFunc('showEnemyHp', false)},
        {time=26000,  msg="Another big result is that there are breakpoints where I need to reach a certain area by a certain counter value"},
        {time=26200,  msg="There are also breakpoints where I need to wait for something to spawn. In that case I can use the extra time to reduce lag. That speeds things up overall because the counter does not count on lag."},
        {time=26700,  msg="Now it's time to kill a whole bunch of ice zombies. They take 8 stabs or 6 stabs and a shot and give 12xp."},
        {time=26900,  msg="Sliding down here makes things work out efficiently."},
        {time=27409,  msg="You can only hit one enemy at a time. You only need to wait two frames to hit the other one but this can still be annoying at times. Lower enemy index gets priority."},
        {time=27740,  msg="lvl2 fire attack can hit an enemy 4 times for lots of damage. Usually lags at least a little but depends on the situation."},
        {time=28000,  msg="The explosion animation can also interfere with spawning. In this case it conveniently removes an enemy that would cause some lag."},
        {time=28400,  msg="Those dragons can't be hit with fire sword and I can't switch without cancelling the charging glitch."},
        {time=28850,  msg="The lvl2 shot is so convenient on these spiders that it is almost always worth the lag. The lag is sometimes bad but often I can reduce it quite a bit. Turn on the lag counter if you are curious."},
        {time=29300,  msg="These ball enemies are also immune to fire sword"},
        {time=30400,  msg="Delaying the shot like this helps to spawn one of the zombies and also cuts lag"},
        {time=30450,  turboOnGrind=true},
        {time=30803,  msg="Look for the slope counter ($0660 in memory) when I slide down. The higher it is, the more the slope affects you. In this case we want it to be high to slide down faster.", showtrick=makeShowTrickFunc('displaySlopeCounter', true)},
        {time=31100,  msg="Every 16 frames when the lower hex digit of the counter is 0 the game checks to see if you are on a slope. If so, the counter increases."},
        {time=31400,  msg="If you are moving down at that point, it jumps to 7. Otherwise it increases by 1."},
        {time=31700,  msg="The counter does not go up if you are jumping at the check. But as soon as you land it goes up by one."},
        {time=32000,  msg="In each loop I kill 8 zombies for 12 xp each. The overall rate is 7.2 xp/sec. A little better than the 5.6 xp/sec I was getting before but not by much."},
        {time=32800,  turboOnGrind=false, showtrick=makeShowTrickFunc('displaySlopeCounter', false)},
        {time=33300,  msg="I'll get the rest of the xp on the way to the next area"},
        {time=33950,  msg="I could have gotten all three spiders but I only need two of them"},
        {time=34200,  msg="That chest has a medical herb, but it was still faster to buy it in the shop earlier."},
        {time=34600,  msg="Walking under the status bar is perfectly all right."},
        {time=35700,  msg="That's the last wall so now I can switch to wind sword and bracelet. Going to the menu during the explosion also helps cut lag."},
        {time=36000,  msg="All of the lvl 3 sword attacks are fun. I can spare some mp and it saves a little time."},
        {time=36350,  msg="Equip teleport and gas mask"},
        {time=36400,  msg="Magic ring restores all of your mp. That will be useful later on."},
        {time=36900,  msg="Now I can take out these enemies. Fire sword also works but is laggier and switching would be a waste of time."},
        {time=37650,  msg="Better to wade through the swamp than spend time equipping rabbit boots."},
        {time=37850,  msg="lvl3 tornado attack is less laggy here and also very stylish."},
        {time=37965,  msg="Just walk through the middle here to skip Leaf kidnapping event.", showtrick=makeShowTrickFunc('showEnemyHitbox', true)},
        {time=37901,  showtrick=makeShowTrickFunc('showPlayerHitbox', true)},
        {time=38050,  showtrick=makeShowTrickFunc('showEnemyHitbox', false)},
        {time=38051,  showtrick=makeShowTrickFunc('showPlayerHitbox', false)},
        {time=38100,  msg="That is why there was no need to go into Zebu's cave or Leaf again."},
        {time=38300,  msg="On the previous screen there is a trigger box that prevents entering the mountain before getting teleport. No way around that one."},
        {time=38500,  msg="No need to stop here at Nadare's inn. That will leave a blank in the teleport list."},
        {time=38750,  msg="Unequip magic by equipping and unequipping refresh, and also equip rabbit boots.", showtrick=makeShowTrickFunc('displayGlobalCounter', true)},
        {time=39000,  msg="Earlier I mentioned that the slope counter increases every 16 frames. But you can prevent that by pausing at the right time."},
        {time=39300,  msg="The result is that you can keep climbing up without the slope pushing you down."},
        {time=39600,  msg="The increment that happens when you land after a jump can't be cancelled this way. "},
        {time=39750,  msg="Later on I discovered that teleport and telepathy can have the same effect. This would be nice because I could use the charge glitch. But I was too far ahead and didn't want to go back to this point.", showtrick=makeShowTrickFunc('displayGlobalCounter', false)},
        {time=40100,  msg="You can jump up this slope without the pause glitch, but you do need good timing with respect to when the counter increments."},
        {time=40100,  msg="You can jump up this slope without the pause glitch, but you do need good timing with respect to when the counter increments."},
        {time=40400,  msg="The guards take 12 stabs or 10 stabs and a shot. Or two hits from a lvl2 shot, 1 lvl1 shot and 6 stabs."},
        {time=40700,  msg="Rabbit boots help tighten this grind loop. Neither the guards nor their swords can touch the airborne hero."},
        {time=41000,  msg="I need 1200 xp and the guards give 25, so I'll be taking out 48 of them. One of the longest grind sequences in the run. Rate is about 10 xp/sec."},
        {time=41150,  msg="The way it works out with their sword attacks is similar to Stom. I can avoid their attacks and fight back from the right position. But it can get tricky when there are many of them stabbing at me.", showtrick=showAllHitboxes},
        {time=41500,  msg="Although it is long, this was one of the more interesting sequences to optimize. There are a lot of factors to consider.", showtrick=hideAllHitboxes},
        {time=41550,  turboOnGrind=true},
        {time=41800,  msg="Of course the first consideration was making the loop as tight as possible. But the next most important optimization involves the second enemy from the top of the passage."},
        {time=42100,  msg="The other three spawn immediately on entering the room. That one is subject to the timer. Since he's so convenient I adjust the timing of things around spawning him. I can use the wait time to cut lag."},
        {time=42400,  msg="Another consideration is landing on the right amount of xp in the least time."},
        {time=42700,  msg="The number of enemies to kill on this platform is another factor. Both, one or none? They all take different amounts of time, affecting the spawn inside the passage."},
        {time=43000,  msg="I wrote a little optimization program to check all the combinations of outside kills and whether or not to wait for the enemy inside to spawn."},
        {time=43300,  msg="The script didn't actually play it out. It just analyzed the counter values, experience and overall time."},
        {time=43600,  msg="The result is what you see here. I always spawn the enemy in the passage and usually get just one kill outside."},
        {time=43900,  msg="Sometimes I need to wait a little for the spawn. That time is used to cut lag."},
        {time=44200,  msg="How can extra time cut lag? Basically, lag happens because the processor has more work than it can do in a frame. Sometimes you can avoid that by moving slower."},
        {time=44500,  msg="Often, just waiting a frame will prevent it. In other words, don't move for a frame and then the lag frame doesn't happen."},
        {time=44800,  msg="In the short term this means the same amount of time passes. But the counter doesn't count on lag. So that motionless frame counts toward the time for the next spawn while the lag does not."},
        {time=45100,  msg="In some cases I can use the extra time to switch to a completely different and less laggy method. Or manipulate enemies to behave differently."},
        {time=45774,  msg="There is a trick to using the rabbit boots to push enemies around. On hitting the A button you can take two steps before you start jumping and can't change direction. But during those two steps you are considered airborne. Two steps is enough to move left or right into position so that I can push them down.", showtrick=showAllHitboxes},
        {time=46273,  msg="There is another way to walk through an enemy. They can't hit you when they are being pushed back from a hit. This really only comes up when you push them against a wall but it's often useful to abuse."},
        {time=46300,  turboOnGrind=false, showtrick=hideAllHitboxes},
        {time=46571,  msg="Yay, level 7 at last! Now we can take down the boss."},
        {time=47000,  msg="The tornado shot hits three times. Kelbesque's movement is manipulated by the position of the hero. So I set him up to end the fight on top of the chest."},
        {time=47300,  msg="I need to go back for the key. There is an ice wall in the way and I couldn't execute the sword charge glitch because I needed to pause for the slope climb glitch. But with the flame bracelet I can now legitimately charge fire sword to lvl2."},
        {time=47750,  msg="Equip fire sword and unequip wind bracelet"},
        {time=48000,  msg="The jail is empty because of the Leaf kidnapping skip."},
        {time=48700,  msg="I am now selective about which guards to kill because I can get xp much faster up ahead."},
        {time=49000,  msg="Switch to wind sword. This was timed to use the slope glitch for a little boost up the hill."},
        {time=49350,  msg="Equip fire sword and the key"},
        {time=49600,  msg="The Leaf elder is not here because of the Leaf kidnapping skip"},
        {time=50416,  msg="The voice in the hero's head mentions that paralysis will be useful in the next town. It won't be, but there will be other uses for it."},
        {time=50700,  msg="Welcome to Portoa. This visit is to set up warping so we'll be back later."},
        {time=51000,  msg="These green masked guys can be hit with wind sword. But they take too many hits and only give 25xp. They aren't worth taking out just yet."},
        {time=51180,  msg="On the other hand, the flying tentacle monsters can be taken out easily for 40 xp. I'll be getting more of them later."},
        {time=51300,  msg="Switch to wind sword"},
        {time=51600,  msg="These crawlies go down easy enough for 30 xp, so I switch to wind sword for them."},
        {time=51920,  msg="Back to fire sword"},
        {time=52500,  msg="Walk though persons glitch: By moving diagonal you can get through guard NPCs. This works because they push you back with respect to the direction you are facing. The hero faces south when walking southwest, so it is possible to progress west and be ejected north."},
        {time=52800,  msg="This avoids a lengthy sequence in Portoa where you need to talk to the queen and fortuneteller repeatedly to get the flute of lime to unstone them."},
        {time=53300,  msg="These medusas are the next enemy I'll be killing a lot of. But not just yet because neither of the swords I have right now can hurt them."},
        {time=53600,  msg="I probably put more work into this room than any other spot in the run. The result is well worth it though."},
        {time=53900,  msg="Rounding these enemies up for later slaughter"},
        {time=54370,  msg="One reason this room is difficult is because I needed to manipulate the enemies' random movements. The enemies need to move into a good position for me to kill them."},
        {time=54500,  msg="Scrolling the screen to the right before blowing the wall saves time because I don't need to wait for the screen to scroll again before getting the chest."},
        {time=54750,  msg="Equip my new water sword and teleport. This means I can't jump. It would be convenient up ahead, but doing it this way saves a menu trip."},
        {time=54900,  msg="Now it's time to slaughter the enemies that I so carefully manipulated. Some of them will respawn and be killed again."},
        {time=55200,  msg="The other reason this room took so much work was lag. These medusas are very laggy. That's why I manipulate them to spread out and try to keep them from shooting much. I also have some wait time available because of how the spawning works out."},
        {time=55500,  msg="There is a grind loop here, but I won't need to spend much time in it. The ranching strategy helps out a lot."},
        {time=55700,  msg="Getting this enemy in the right position is a big manipulation issue. It can run away to the south if you aren't careful."},
        {time=56100,  msg="My loop takes two counter cycles and takes out six enemies for 50xp each. That works out to 34.6 xp/sec. Nice!"},
        {time=56450,  msg="This damage boost helped work out the luck a bit."},
        {time=56650,  msg="A good place to end the loop because the next enemy is down the corridor a bit. I'll get the rest of the xp in the valley."},
        {time=57200,  msg="With water sword I can now take out those green hoods easily."},
        {time=57800,  msg="These tentacle fliers are great. They are worth 40xp and they fly right to me. Their movement is based on position relative to the hero. They move offscreen, but faster onscreen."},
        {time=58600,  msg="Equip the ball the Rage gave me and unequip teleport so I can jump."},
        {time=58850,  msg="We were supposed to meet Mesia, the heroine back there. But it's not necessary to trigger anything. Getting the ball of water is an important trigger. Even if we used the charge glitch, we need the ball to trigger something up ahead."},
        {time=59400,  msg="I've manipulated the slugs' random movements to be convenient for me."},
        {time=59900,  msg="Spiders are worth 120xp and vulnerable to water and fire. Plants are worth 100xp and vulnerable to fire and wind"},
        {time=60000,  msg="More herding. In this case it saves a menu trip."},
        {time=60140,  msg="Equip wind sword and unequip water ball. For the wall."},
        {time=60230,  msg="Now equip fire sword. It's the best for fighting here because it can hurt most enemies and the lvl2 attack is very useful."},
        {time=60700,  msg="The dragons are only worth 10xp! They are only vulnerable to water."},
        {time=60900,  msg="The goombas are worth 80xp and vulnerable to fire"},
        {time=61200,  msg="Switched to wind sword for the wall, then back to fire."},
        {time=61600,  msg="Throughout this cave I am using some frames for lag reduction. This is coordinated with the counter values I need at certain points to spawn enemies."},
        {time=61980,  msg="Wind sword"},
        {time=62490,  msg="Water sword, ball and teleport"},
        {time=62900,  msg="One cave down, one to go"},
        {time=63200,  msg="Lvl2 water shots are very useful. Big hitbox, good damage, easy to land two hits."},
        {time=63480,  msg="Equip wind sword, unequip water ball and unequip teleport for jumping."},
        {time=63850,  msg="Fire sword"},
        {time=64050,  msg="A lot of counter management went into spawning this spider. It's easy for the explosion of that wall to block him from spawning."},
        {time=64400,  msg="The spiders have a paralysis shot, but I generally manipulate luck to avoid them ever shooting. All the enemies here move based on relative positions and are straightforward to handle."},
        {time=64850,  msg="Lvl2 fire shot with no lag. It is possible."},
        {time=65150,  msg="Wind sword"},
        {time=65350,  msg="Killing this goomba would require switching swords two more times. I considered herding him towards the wall but even that was more bother than it was worth. So he got lucky and gets to live."},
        {time=65600,  msg="Fire sword. Under the status bar again. Only problem with this trick is that it can be really laggy if you aren't careful."},
        {time=66180,  msg="Wind sword"},
        {time=66650,  msg="Two goombas could spawn here but taking them out would require two more sword switches. Best to keep them from spawning to cut lag."},
        {time=67000,  msg="Fire sword. Finally, after three walls in one room!"},
        {time=67500,  msg="I had to hurry to get all these spiders to spawn"},
        {time=67800,  msg="Wind sword"},
        {time=67980,  msg="Water sword and teleport"},
        {time=68200,  msg="These dragons are only worth 10xp, but now I have the right sword equipped."},
        {time=68550,  msg="A little wait here to spawn the last spider"},
        {time=68725,  msg="Wind sword"},
        {time=68890,  msg="Water sword and ball"},
        {time=69220,  msg="We'll finally do a little more in Portoa"},
        {time=70350,  msg="'The queen and fortuneteller were really me' says Asina. 'Sorry, I glitched past that part', replies the hero."},
        {time=70500,  msg="Recovery is another spell we don't need. But again, getting it is a necessary trigger."},
        {time=70720,  msg="Equip flame bracelet, medical herb and fog lamp. Some inventory changes are done in a funny order to save a few frames."},
        {time=70980,  msg="That was why we had to carry a medical herb all this way. Warping immediately after giving the herb lets us skip watching the dolphin swim out to sea."},
        {time=71600,  msg="Equip fire sword. The only reason for the menu here is because of an inconvenient glitch. Fog lamp is equipped, but not usable because we used the medical herb. Going to the menu fixes this, even if we don't do anything. But it saved a few frames to equip the fire sword on this menu trip, so I do. This glitch happens anytime you equip two consumables."},
        {time=72350,  msg="Talking to Kensu here is another necessary trigger"},
        {time=72470,  msg="Equip refresh and shell flute"},
        {time=72700,  showtrick=function() dolphinMode=true end},
        {time=72712,  msg="The dolphin gets an extra speed boost when skirting the shore"},
        {time=73000,  msg="Getting Joel on the warp list is necessary to enter the Evil Island cave"},
        {time=73360,  msg="Unequip refresh, unequip shell flute and equip magic ring. Any attacks with the B button lag when shell flute is equipped. The magic ring that we got back on Mt Sabre South will give us enough mp to reach a plot-based healing spot."},
        {time=73750,  msg="Lvl3 fire attack is very convenient on these octopus enemies. They take a long time to kill with stabs."},
        {time=74000,  msg="Mermen are worth 144 xp, octopus is 176 xp"},
        {time=74300,  showtrick=showAllHitboxes},
        {time=74400,  msg="The trick to cutting lag with this attack is to get as much of it as possible offscreen as soon as possible. It's also important to make sure the octopus doesn't shoot."},
        {time=74450,  showtrick=hideAllHitboxes},
        {time=74580,  msg="This octopus lives because I don't have time to charge a lvl3 attack (can't afford the mp either) and it takes too long to stab him."},
        {time=74850,  msg="These enemies are supposed to be turtles. They are worth 160 xp and there are six of them in this room. They spawn on entering the room, barely move and are easy to kill. Seems like it was designed to be a grinding spot."},
        {time=75200,  msg="That's good because I need a lot of xp. We'll be using a glitch to skip a good chunk of the game. To keep up we need to gain two levels. So even at 114 xp/sec this is going to be the longest grind in the run."},
        {time=75300,  turboOnGrind=true},
        {time=75500,  msg="Clearing out all six enemies is about 5% more efficient than just taking out the first two. Those first two were the leftovers."},
        {time=75800,  msg="The turtles do move a little bit randomly within a certain box"},
        {time=76000,  msg="I am doing some light manipulation to get the last enemy to be in a more favorable position. This saves a few frames each trip."},
        {time=76300,  msg="The enemies take four hits on level 9, but only three on level 10"},
        {time=76600,  msg="That will speed up my rate to 117 xp/sec", turboOnGrind=false},
        {time=76800,  turboOnGrind=true},
        {time=76900,  msg="While this grinding goes on I'll explain how to abuse the movement system", showtrick=makeShowTrickFunc('showPlayerCoords', true)},
        {time=77100,  msg="The game engine does not track subpixel position. Yet the per-frame movement is not the same each frame. Use frame advance and check the coordinates to see what I mean."},
        {time=77400,  msg="The variation is managed by a counter at $0480 that counts up every step you take. The distance you move each frame is determined by the low bits of that counter as well as the direction and terrain.", showtrick=makeShowTrickFunc('displayFastDiagonalIndicator', true)},
        {time=77800,  msg="On dry land the hero always moves 2 pixels/frame in manhattan directions (up, down, left or right). But diagonal movement alternates between one and two pixels/frame."},
        {time=78200,  msg="The dolphin is faster than the hero on dry land, so it follows different rules. Moving in a manhattan direction alternates between 2 and 3 pixels/frame. The diagonal pattern is 2, 2, 2, 1."},
        {time=78500,  msg="There is another pattern when going over rough terrain that slows you down"},
        {time=78800,  msg="The way to abuse this is to switch between manhattan and diagonal movement. On dry land, only move diagonal on the 'fast diagonal' steps when the hero moves 2 pixels instead of just one."},
        {time=79100,  msg="Of course it depends on where you want to go. But this trick is useful just about everywhere. To make it easier I have my script show a really clear indicator."},
        {time=79400,  msg="This is one reason why I wade through rough terrain more often than you might think. The slowdown is not as bad with tweaked movement."},
        {time=79700,  msg="Those three-pixel frames are why the dolphin moves so fast. Tweaking to get those with two-pixel diagonals lets the dolphin get anywhere really fast.", showtrick=makeShowTrickFunc('showPlayerCoords', false)},
        {time=80100,  msg="Anyway, those movement optimizations are a big reason why this game is interesting, but difficult to TAS.", turboOnGrind=false, showtrick=makeShowTrickFunc('displayFastDiagonalIndicator', false)},
        {time=80520,  msg="This shot is to manipulate luck, avoiding shots from the last octopus"},
        {time=80900,  msg="Ghetto flight: Jumping at the right time while dismounting the dolphin can confuse the game into letting you fly over the ocean. The effect is similar to the flight spell learned later. Note that the dolphin disappears."},
        {time=81200,  msg="Dolphin is back! I call this dolphin warp. Getting back on the dolphin will save a few seconds because he moves so much faster."},
        {time=81400,  msg="Barrier is one of the more useful spells. You'll be seeing it later."},
        {time=81749,  showtrick=function() dolphinMode=false end},
        {time=81765,  msg="Another shore boost. Also, I reach the next screen before the dolphin can stop me to say goodbye."},
        {time=81870,  msg="Equip love pendant and paralysis"},
        {time=82700,  msg="Change is necessary for a few things. We could do the Amazones trip now, but it saves time to do it later."},
        {time=82900,  msg="Equip water sword and ball and our new change spell"},
        {time=83418,  msg="When walking northwest in changed form you face west. In normal form you face north."},
        {time=83600,  msg="Normally you want to spend as little time as possible in changed form because movement is slower. But here there's a short wait for the gate to open so there's no need to change right away."},
        {time=83970,  msg="Get Goa on our warp list"},
        {time=84300,  msg="This gargoyle enemy is worth 288 xp and continually bangs on the RNG when onscreen. I'll use him to make my luck better up ahead.", showtrick=makeShowTrickFunc('displayRandSeed', true)},
        {time=84600,  msg="Mt Hydra is another mountain we'll be spending a lot of time on to get a couple of important items", showtrick=makeShowTrickFunc('displayRandSeed', false)},
        {time=85000,  msg="The level designer forgot to put enemies in this part of the mountain"},
        {time=85750,  msg="You can sneak in with the walk-through-NPC glitch. But using change is faster and we still have it equipped from the gate by Swan."},
        {time=86000,  msg="Rebel base Shyron. Don't get too attached."},
        {time=86280,  msg="Equip teleport"},
        {time=86500,  msg="Teleporting to the entrance saves a couple seconds even though we had to pause specifically to equip teleport"},
        {time=87000,  msg="We needed the key to get into the next dungeon. The entrance is up the mountain a bit."},
        {time=87500,  msg="Finally, something to kill! This might have been the longest stretch with no enemies in this otherwise violent run."},
        {time=87800,  msg="The flail lizard is worth 320 xp and the little crawlie is 30 xp"},
        {time=87950,  showtrick=makeShowTrickFunc('displayRandSeed', true)},
        {time=88030,  msg="This is what I was setting up the RNG for. These morph blobs are going to be showing up a lot. They are worth 320 xp. They are easy to take out when they take form."},
        {time=88300,  msg="The problem is that they take form randomly. Every 32 counts when invulnerable they pick a random number. They take form on 8 RNG seeds: 9, 23, 29, 35, 45, 58, 59, 60. Note that these are not at all evenly distributed through the 0-63 range of the RNG seed."},
        {time=88600,  msg="There are limits to how well I can manipulate this. But a lot of them are going to conveniently congeal right in front of me. That is going to cut down on grinding quite a bit."},
        {time=88800,  showtrick=makeShowTrickFunc('displayRandSeed', false)},
        {time=88970,  msg="Equip the key and barrier magic"},
        {time=89200,  msg="Barrier creates a hitbox around the hero. Any projectile gets vaporized on contact with it. Very nice, but there are a few quirks.", showtrick=showAllHitboxes},
        {time=89400,  msg="First, if a projectile contacts the hero's hitbox for even one frame it will still hurt him. Second, the barrier flickers off every eighth frame. Third, you can see that the north side of the barrier is a bit thin. Putting these all together, you need to watch out for fast-moving projectiles coming from the north."},
        {time=89530,  showtrick=hideAllHitboxes},
        {time=89900,  msg="Unequip magic so I can jump"},
        {time=90050,  msg="An unexpected spot to grind! This is much faster than the standard speedrun hunting ground outside of Goa.", turboOnGrind=true},
        {time=90400,  msg="This might seem slow compared to the crossbow guards outside Goa. But this enemy is worth 672 xp while those guards are only 256 xp. At 154 frames per kill I am getting 262 xp/sec."},
        {time=90800,  msg="The next boss only requires level 12. But there's no better grinding spot until the boss after him who requires level 13. So that's what I am aiming to set up here."},
        {time=91100,  msg="Let me explain what goes into figuring out how long I need to grind. It involves a spreadsheet and several rough drafts."},
        {time=91450,  msg="I play through the area up to the point where I need to reach a certain level. I'll experiment and take notes on how many enemies of what type I can take out.", turboOnGrind=false},
        {time=91650,  turboOnGrind=true},
        {time=91700,  msg="I'll also be trying to figure out which enemies might be difficult to spawn. This is generally because they are near the entrance to a room, so I would either have to enter the room at the right time or wait."},
        {time=92000,  msg="The spreadsheet helps me quickly calculate how many grind loops I'll need. I'll also see how close I am to cutting out another loop."},
        {time=92300,  msg="This helps me narrow down to a few routes that look good. I'll investigate those further and maybe play them out."},
        {time=92600,  msg="That process worked really well, helping me get the xp I need efficiently throughout the run.", turboOnGrind=false},
        {time=92800,  msg="So that's how I decided to stop grinding at this point and get the rest of the xp on my way."},
        {time=93220,  msg="Wind sword"},
        {time=93400,  msg="This lizard is worth 608 xp. Enough to be worth switching swords just for him."},
        {time=93520,  msg="Water sword"},
        {time=94200,  msg="RNG seed 58 is special. The next three morph blobs will congeal immediately.", showtrick=makeShowTrickFunc('displayRandSeed', true)},
        {time=94600,  showtrick=makeShowTrickFunc('displayRandSeed', false)},
        {time=94880,  msg="Fire sword. We need it for the enemies here. This menu trip prevents one of them from spawning to cut lag."},
        {time=95100,  msg="These enemies are very similar to the medusas. They move randomly and shoot stone shots. They are also very laggy so I am cashing in some upcoming wait time to manage lag."},
        {time=95350,  msg="They are also worth 272 xp each. Well worth killing with good manipulation and lag management."},
        {time=95500,  msg="The butterfly is worth 204 xp and is annoyingly laggy. On death he releases a laggy cloud of poison. So this one gets to fly right on by."},
        {time=96000,  msg="Equip warp boots and barrier. Then warp out before getting into a long conversation with the wise men."},
        {time=96100,  msg="'Sorry, no time to talk', says the hero. 'I'm in the middle of a TAS!'"},
        {time=96500,  msg="Using warp boots instead of teleport can sometimes save a menu trip. If I had used teleport I would have needed to switch to barrier here. Each of the boots left over from the initial supply is used this way."},
        {time=96750,  msg="Water sword and teleport"},
        {time=97200,  msg="Time to fight Mado. How will I manage without a level 3 attack?"},
        {time=97480,  msg="Unfortunately, I can't take care of Mado without clearing that plot hitbox. So we get the wise men's lecture after all."},
        {time=97900,  msg="With good luck I was able to beat Mado very quickly without even taking damage. Back in the Styx cave I was grooming the RNG for this in addition to manipulating the eye enemies."},
        {time=98280,  msg="Equip thunder sword and unequip teleport"},
        {time=98400,  msg="The wait time I used on the eyes was done to get the counter on the right spot to spawn these guys. There's more waiting up ahead so I use some extra time to jump around and take them out with no lag."},
        {time=98900,  msg="Usually wading through rough terrain is all right, but the desert is big enough to make me want to jump."},
        {time=99050,  msg="The zombies are worth 208 xp. I have extra time to go a little out of the way and take this extra one out."},
        {time=99560,  msg="Water sword"},
        {time=100000, msg="The reason I needed to be at a certain counter value was so that insect would spawn at the right time and fly to me here. Then it will conveniently respawn a few times for more xp."},
        {time=100300, msg="At 592 xp it is well worth a little time to keep respawning it. Like other fliers, its movement is based on relative position. So I use my position to get it to come in faster."},
        {time=100600, msg="They have a poison gas attack which I manipulate away"},
        {time=100800, msg="That's the fourth one. This is one reason I was able to stop grinding so soon."},
        {time=101000, msg="It's also convenient that they are vulnerable to water sword which I need for the bridges here"},
        {time=101250, msg="Hey, he's getting away!"},
        {time=101520, msg="Isn't that nice, he came back to play"},
        {time=101650, msg="Thunder sword, ball and teleport"},
        {time=102240, msg="Equip my nice new power ring and barrier"},
        {time=102500, msg="Power ring is necessary for one of the last bosses. I get it as soon as I have thunder ball to blow the wall because it's always nice to hit twice as hard."},
        {time=103000, msg="Welcome to Goa fortress, the hugest dungeon in the game"},
        {time=103450, msg="These guards are worth 560 xp. The fliers are worth 672. Well worth killing, even if I need to use laggy thunder sword shots to do it."},
        {time=103600, msg="The reason for the funny behavior here is to manipulate another flier to follow me"},
        {time=103750, msg="You can't see him right now because he's under the status bar"},
        {time=104500, msg="Each flier lets me cut a loop from the last round of grinding, so I spawn and draw in as many of them as possible"},
        {time=104600, msg="Even this guard won't be spared"},
        {time=105200, msg="Landed exactly on 20,000 xp for my levelup"},
        {time=105275, msg="Wind sword and bracelet"},
        {time=105700, msg="None of the bosses here lasts long when you have power ring equipped"},
        {time=105932, msg="The prizes from these bosses are all useless. In a TAS at least."},
        {time=106080, msg="Hp and mp restored. Thank you, Zebu! This is also the only room in the fortress where you can save."},
        {time=106600, msg="I use two menu trips to equip water sword and ball so I can prevent two enemies from spawning"},
        {time=106900, msg="Those two enemies wield flails that take up an object slot, even when they are offscreen"},
        {time=107320, msg="That would prevent this insect from spawning"},
        {time=107600, msg="There's plenty of time for the flail enemies to spawn again and plenty of other slots for their flails. But they want to pick that slot if they can."},
        {time=108530, msg="So I get to take out that insect three times, picking up useful xp"},
        {time=108945, msg="Thunder sword and ball"},
        {time=109150, msg="Here's one of the flail enemies I was talking about"},
        {time=109235, msg="Fire sword"},
        {time=109700, msg="The ghetto flight trick skipped the first fight with Sabera"},
        {time=109950, msg="I use my barrier to block all her shots, cutting lag"},
        {time=110208, msg="Another useless item"},
        {time=110700, msg="Another hp/mp restore. It might have been more useful if this area was more difficult."},
        {time=111000, msg="Thunder sword. Ball was still equipped."},
        {time=111070, msg="These medusas are still just worth 50 xp. It just happens to be useful though."},
        {time=111440, msg="You can see another flier going by here. I don't have time for him because I need to make a breakpoint up ahead."},
        {time=111800, msg="I'm right on time to start the grind loop here"},
        {time=112100, msg="I can take out both spiders in one cycle. It's well worth taking a little lag from the shots to do it.", turboOnGrind=true},
        {time=112400, msg="The lvl2 shot is necessary because it takes three hits from lvl1 shots. That means two shots if I get one to hit twice."},
        {time=112700, msg="Funny thing about the lvl1 thunder shots is that they actually do less damage than a stab. The spiders die to two stabs of the thunder sword."},
        {time=113000, msg="Luckily it was possible to tweak down the lag quite a bit. Two lvl1 shots lag less than one lvl2. But I need a lvl2 on one of them to stabilize the loop."},
        {time=113420, msg="Each spider is worth 1280 xp. Two per cycle with a little lag comes out to 548 xp/sec.", turboOnGrind=false},
        {time=113750, msg="Ball of water, rabbit boots and unequip barrier"},
        {time=113860, msg="The moonjump glitch: If you time the A button right, you can jump again instead of falling into the pit. Here I use it to take out some more spiders on my way to the next area."},
        {time=114600, msg="Luckily I can still one-shot these fliers without power ring"},
        {time=114804, msg="The timing and position also worked out well to let me respawn the flier quickly"},
        {time=115095, msg="Walking on the moving platform lets me move a little faster"},
        {time=115400, msg="Moonjumping saves a huge amount of time here"},
        {time=115700, msg="The many enemies and moving platforms can be laggy. Took some effort to tweak down this far."},
        {time=115980, msg="Damage boosting lets me tweak even more time"},
        {time=116255, msg="Water sword, paralysis and power ring"},
        {time=116500, msg="Mado again, and I still don't have blizzard attack. How will I manage?"},
        {time=116955, msg="Thunder sword and ball"},
        {time=117500, msg="Free healing means I can throw in some damage boosts. I would blow off some mp if it helped."},
        {time=118136, msg="Paralysis can be useful in combat. You'll see the real reason I have it equipped in just a bit."},
        {time=118450, msg="These skeletons normally collapse after each hit and would take too long to kill. But when paralyzed they just stand there and die. At 1280 xp each, they will cut out quite a bit of grinding."},
        {time=118730, msg="Paralysis is also useful for luck manipulation. I can paralyze the spider while he is still moving up so the damage boost pushes me that way."},
        {time=119150, msg="More paralysis for luck manipulation. I am grooming the RNG by using the fact that paralyzed enemies don't take actions that use the RNG."},
        {time=119390, msg="Have you ever seen a paralyzed butterfly stuck in midair?"},
        {time=119820, msg="This is what I was manipulating. These blobs are worth a juicy 1920 xp."},
        {time=120100, msg="Equip barrier"},
        {time=120700, msg="The last of the finest four goes down. Again, vaporizing his shots on my barrier cuts lag."},
        {time=121000, msg="We actually do need the Ivory Statue. The thunder bracelet is not far up that passage, but I won't be needing it."},
        {time=121720, msg="Equip ivory statue and teleport"},
        {time=122000, msg="Finally we have flight, the most fun and useful spell"},
        {time=122500, msg="We need the Bows of Sun and Moon to enter the final dungeon. Each requires a side trip."},
        {time=123000, msg="Bow of Sun is here on Mt Hydra. We need flight to reach it."},
        {time=123600, msg="Lucky 58 on the RNG again", showtrick=makeShowTrickFunc('displayRandSeed', true)},
        {time=123900, msg="These blobs are still just worth 304 xp. But when they pop up right in front of me like this they're still worth killing."},
        {time=124200, showtrick=makeShowTrickFunc('displayRandSeed', false)},
        {time=124800, msg="The eyes are 272 xp. It's not much, so they only get killed when convenient."},
        {time=125090, msg="Wind sword. I need it for a wall, but it doesn't hurt any of the enemies here."},
        {time=125300, msg="There is another wall coming up and I can't be bothered to switch my swords back and forth for these small fry"},
        {time=125600, msg="There is a big counter breakpoint coming up. I have a small amount of extra time I can use to cut lag until then. That is nice because this room can be really laggy."},
        {time=125800, msg="Thunder sword, water ball, warp boots and flight"},
        {time=125860, msg="Normally hitting the B button with warp boots equipped will use them. But the exploding wall blocks them and lets me do a normal attack. I use that fact to take out another enemy here."},
        {time=126170, msg="Damage boosting is difficult to line up here. The push is always in the direction the enemy is facing. These enemies also randomly poison you, bringing up a dialog that would take too long to display. So I need to manipulate no poison in addition to making them face the right way."},
        {time=126800, msg="Now for the Bow of Moon in Amazones. This side trip can be done much earlier, as soon as you get the change spell. There is a reason for putting it off until now."},
        {time=127150, msg="The reason is that I can fly over the river, saving a few seconds over building the bridge with the water sword"},
        {time=127470, msg="Equip Kirisa plant and change"},
        {time=127500, showtrick=showAllHitboxes},
        {time=127670, msg="Those are all trigger boxes for the guard"},
        {time=127700, showtrick=hideAllHitboxes},
        {time=127800, msg="You can sneak past the guard with paralysis or the glitch, but you must be in changed form to make the trade with Aryllis"},
        {time=127905, msg="Equip warp boots and flight. This is another case where warp boots saves a menu trip."},
        {time=128150, msg="The blizzard bracelet is in the basement behind the queen's throne. But there's no need for it now. Actually, there was never a need, stabbing Mado is faster and doesn't lag."},
        {time=128500, msg="I can buzz through these enemies without slowing down at all now"},
        {time=129200, msg="Here's the counter breakpoint I mentioned earlier. I needed to get here in time to spawn all the enemies in this passage."},
        {time=129540, msg="Perfect timing to respawn this enemy."},
        {time=129740, msg="Flight is very useful in combat. The fake 3D effect can be abused thoroughly."},
        {time=130400, msg="I'm right on time to spawn all the enemies in this room too"},
        {time=130700, msg="The scorpions are worth 1440 xp. This room is packed with six of them, a great place to grind."},
        {time=131000, msg="I can set up a loop where I take out 7 every two cycles, a rate of 1160 xp/sec."},
        {time=131450, msg="One loop is enough. Spawning and killing everything in my path almost completely cuts out this session of grinding."},
        {time=131600, msg="Getting this blob to spawn and congeal was very helpful"},
        {time=132100, msg="Once again I have some extra time to cut lag and I cash some of it in on this very laggy room. The fake 3D effect of flight means I don't have to scroll the screen so far up."},
        {time=132325, msg="Equip water sword. Ball was already equipped."},
        {time=132700, msg="Need water sword to hurt these mummies"},
        {time=133600, msg="Draygon can be taken down with any sword. Thunder sword does more damage, but it's not worth switching swords."},
        {time=133800, msg="Unlike every other enemy, he has no invulnerability time in between hits. So it adds very little time to use a weaker sword."},
        {time=134000, msg="I thought equipping psycho armor would be good for more damage boosts. Extra defense and a healing factor. But the healing factor adds lag, costing time instead."},
        {time=134470, msg="By now you know it's not a coincidence when these morph blobs pop up in front of me"},
        {time=134900, msg="The last dungeon. It's almost over."},
        {time=135780, msg="Wind sword and Bow of Moon"},
        {time=135965, msg="Bow of Sun"},
        {time=136400, msg="These warlocks are worth 1920 xp and can only be hurt by the puny wind sword. They take 10 stabs or 8 stabs and a lvl1 shot."},
        {time=136600, msg="I skip this enemy to avoid lag"},
        {time=136900, msg="Cashing in some wait time lets me clear this normally laggy room with no lag at all"},
        {time=137400, msg="There's time for one more game mechanics lecture on hit detection", showtrick=makeShowTrickFunc('displaySwordCounter', true)},
        {time=137600, msg="Hit detection between your sword and the enemies only happens every other frame, when the global counter is odd. But enemies can hit you every frame."},
        {time=137900, msg="When you hit B, the sword counter starts at 17 if you are standing still, 18 if you are moving. It only hurts enemies from 15 to 3.", showtrick=makeShowTrickFunc('displaySwordCounter', false)},
        {time=138200, msg="On the last frame, the sword hitbox extends 3 pixels. It also extends out from the position in the last frame, so you can start moving away a frame early. The extension can also be triggered early by hitting B to interrupt with another stab."},
        {time=138400, msg="An attack can't be interrupted until the counter reaches 11. Doing so often cuts lag. I've been abusing this the whole game to save some frames here and there. That's why I spend a lot of time holding the B button."},
        {time=138776, msg="Finally, no more levels to worry about"},
        {time=139210, msg="Thunder sword, Bow of Truth and barrier. This will be the last time in the menu."},
        {time=139600, msg="Taking a hit before using the Bow of Truth is the key to making the big dragon form use its lasers right away. It also requires the global counter to be under 80 (hex). That was why I had some wait time in this dungeon."},
        {time=139900, msg="Blocking the lasers like this requires standing in a very particular spot and timing when barrier is used. Otherwise the beams get through the one-frame opening in the barrier."},
        {time=140300, msg="If there was some way to beat the human form without the Bow of Truth, the first pyramid could be skipped. Draygon's human form takes damage, but his hp gets reset every frame. So it is impossible to kill him in that form without hacking the game."},
        {time=141000, msg="In the tower there are two main considerations. First, I want to get the blue robots to spawn as soon as possible. That means taking out the brown robots quickly."},
        {time=141200, msg="The other consideration is that the tower can be very laggy. There are many sources of lag but the worst is the cannon that slides back and forth above the door."},
        {time=141500, msg="I need to make sure that cannon doesn't shoot while I am fighting the robots. A lot of work went into this."},
        {time=141800, msg="The combination of fighting the robots and that cannon fire lags badly. Once the robots are gone there is no problem."},
        {time=142600, msg="Blue robots spawn one or two at a time every 16 counts. The counter value determines which ones spawn. So just like the rest of the game I am aiming for certain cutoffs on that counter and using extra time to cut lag."},
        {time=142900, msg="Scrolling the screen down puts that sliding cannon offscreen and prevents it from firing."},
        {time=142900, msg="The flying robot is another annoyance. It can be prevented from spawning if the robots shoot at the right time. But those shots would cause more lag. So I let it spawn and deal with it."},
        {time=143600, msg="The cannon checks the RNG every 32 counts and may fire. For most enemies the chance is 1 in 8 but for the cannon it is 1 in 2. So manipulating it to not fire can be very difficult."},
        {time=144050, msg="Moving down here manipulates the flier to move diagonally. That lets me outrun him, cutting lag on the last set of robots."},
        {time=144400, msg="So after needing to kill enemies the whole game to levelup I needed to kill a few more to get through the tower. What a violent game!"},
        {time=144700, msg="Mesia is the heroine, but this is the first time we see her in this run. She shows up in the Evil Island dungeon we skipped with ghetto flight. So even if you fully explore the game you won't see much of her."},
        {time=145000, msg="'Crystalis' was called 'God Slayer' in the Japanese version of this game. This game predates ESRB ratings but localization of the time was very thorough about removing religious references."},
        {time=145600, msg="The last message can be skipped. The hero is tired of people talking in his head."},
        {time=145900, msg="DYNA is pretty easy with Crystalis and barrier. However, a few tricks are used to cut lag. Timing hits properly can avoid a laggy crescent beam counter attack. It is also less laggy to stand in a blind spot and not use barrier."},
        {time=146500, msg="Thank you for watching and I hope you enjoyed my run. Please visit tasvideos.org for more tool-assisted speedrun action."},
}
eventTimes = {}
lastEventTime = 0
for i,event in ipairs(eventList) do
  if event.time > lastEventTime then lastEventTime = event.time end;
  eventTimes[event.time] = i
end;

local function getPreviousEventIndex()
  frames = emu.framecount()
  while frames >= 0 do
    frames = frames - 1
    if eventTimes[frames] ~= nil then return eventTimes[frames] end;
  end;
  return -1
end;

local function getNextEventIndex()
  frames = emu.framecount()
  while frames <= lastEventTime do
    frames = frames + 1
    if eventTimes[frames] ~= nil then return eventTimes[frames] end;
  end;
  return #eventList+1
end;

local function getTimestamp()
  frames = emu.framecount()
  minutes = math.floor(frames / 3600)
  seconds = math.floor( (frames-minutes*3600) / 60)
  if seconds < 10 then seconds = "0"..seconds end;
  return frames.." ("..minutes..":"..seconds..")"
end;

local function addNote(text)
  maintext.value = maintext.value..getTimestamp().."  "..text.."\n\n"
  maintext.caretpos = string.len(maintext.value)
end;

processedEvents = {}
local function processEvents()
  framecount = emu.framecount()
  eventIndex = eventTimes[framecount]
  if eventIndex ~= nil then
    if processedEvents[eventIndex] == nil then
      --Process an event for the first time. If it has already 
      --been processed the else branch runs.
      event = eventList[eventTimes[framecount]]
      if event.msg ~= nil then
        event.caretpos = maintext.caretpos
        addNote(event.msg)
        event.aftercaretpos = maintext.caretpos
        processedEvents[eventIndex] = event
      end
      event.state = savestate.create()
      savestate.save(event.state)
      if showTricks and event.showtrick ~= nil then event.showtrick() end;
      if turboOnGrind and event.turboOnGrind ~= nil then
        if event.turboOnGrind then emu.speedmode("turbo") else emu.speedmode("normal") end;
      end;
    else
      --Event has already happened and user used rewind or loaded a savestate.
      --Scroll the text box to it.
      --iup.Message('debug', "event index is "..eventIndex)
      event = processedEvents[eventIndex]
      maintext.caretpos = event.caretpos
      maintext.caretpos = event.aftercaretpos
      if showTricks and event.showtrick ~= nil then event.showtrick() end;
      if turboOnGrind and event.turboOnGrind ~= nil then
        if event.turboOnGrind then emu.speedmode("turbo") else emu.speedmode("normal") end;
      end;
    end;
  end;
end;

local function loopFunction()
  if enableRewind then
    frameAdvanceWithRewind()
  else
    FCEU.frameadvance()
  end;
  processEvents()
end;

local function onPauseButton()
    pauseWithRewind()
    processEvents()
end;

local function onPlayButton()
    emu.unpause()
end;

local function onBackButton()
  prevEventIndex = getPreviousEventIndex()
  while prevEventIndex > 0 do
    --Get the latest event with text that has been processed
    event = eventList[prevEventIndex]
    if event.msg ~= nil and processedEvents[prevEventIndex] then
      savestate.load(event.state)
      maintext.caretpos = event.caretpos
      maintext.caretpos = event.aftercaretpos
      return
    end;
    prevEventIndex = prevEventIndex - 1
  end;
  iup.Message('Beginning', "This is as far back as you can go")
end;
local function onForwardButton()
  nextEventIndex = getNextEventIndex()
  while nextEventIndex <= #eventList do
    --Get the next event with text that has been processed
    event = eventList[nextEventIndex]
    if event.msg ~= nil and processedEvents[nextEventIndex] then
      savestate.load(event.state)
      maintext.caretpos = event.caretpos
      maintext.caretpos = event.aftercaretpos
      return
    end;
    nextEventIndex = nextEventIndex + 1
  end;
  iup.Message('The End', "This is as far forward as you can go")
end;

dialogs = dialogs + 1
handles[dialogs] = iup.dialog{
  menu=mainMenu,
  iup.vbox{
    maintext,
    iup.hbox{
	    iup.button{title="Back", padding="10x0", action=onBackButton},
      iup.fill{expand="YES"},
	    iup.button{title="Pause", padding="10x0", action=onPauseButton},
	    iup.button{title="Play", padding="10x0", action=onPlayButton},
      iup.fill{expand="YES"},
	    iup.button{title="Forward", padding="10x0", action=onForwardButton},
    },
  };
  title="Crystalis TAS by TheAxeMan",
  margin="10x10",
  size="400x200",
}

handles[dialogs]:show()

--Start out paused.
--FCEU.pause()
iup.Message("Welcome", [[Author's Notes Lua Script by TheAxeMan (v1.1)

About this script
I made this to give TAS fans a look at some of the tools and tricks that went into making this run. You should start this script at the start of the run. My notes will appear in the iup textbox. At certain points I'll show hitboxes, hp and other points of interest. I also recommend looking at the lag counter and all the resources on tasvideos.

Rewind
By default this script adds rewind capabilities through the 'r' button. To rewind with frame advance you'll need to hold 'r' and hit the frame advance button. You can disable this on the options menu if your computer can't handle it or you want turbo to run faster. Back and forward buttons will still work if rewind is disabled.

Turbo Grind
I've also added an option to fast-forward grinding. You can turn that on if you like, but there are only about 5 minutes of grinding and I'll be throwing out notes you can read then. You'll probably want to disable rewinding to make turbo run faster.

Options
In the display menu you can turn hitboxes, hp and other displays on and off. 'Show Tricks' toggles the scripted display of hitboxes and counters. Uncheck this if you just want those stay on. It will get unchecked automatically on picking 'Show All'.

Back and Forward Buttons
These navigate between notes that have been displayed. It might help to pause first and then hit these buttons. In some cases the comment is pointing out something that might only visible for a frame or two.]])

--The main loop
while (true) do
  loopFunction()
end;

