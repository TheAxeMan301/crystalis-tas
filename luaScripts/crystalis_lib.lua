--[[
Code library for Crystalis lua scripts
--]]

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

