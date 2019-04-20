--[[
Crystalis enemy analysis code - iup gui code removed
--]]

require 'crystalis_lib';

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
  edata.def = memory.readbyte(0x040c+offset)
  local mem1 = memory.readbyte(0x03ac+offset)
  local mem2 = memory.readbyte(0x042c+offset)
  edata.hbtableOffset = OR(4*AND(mem1, 0x0F), AND(mem2, 0x40))

  return edata
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
    edata.spawnx, edata.spawny = getEnemySpawnPoint(edata.index)
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

--Copied some memory because it is usually paged out.
require "crystalis_memdump";

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

--displays onscreen text with enemy hp
function showEnemyDefense()
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
      --Can count number of hits like this. More work needed to get the actual
      --stab attack because of how the stab bonus only shows up when sword is out.
      local hit = memory.readbyte(0x03E1) + memory.readbyte(0x03E2) - (edata.def/2)
      local count = math.floor(edata.hp / hit) + 1
      --safetext(edata.relx, edata.rely, edata.hp..'-'..(edata.def/2)..' ('..count..')')
      safetext(edata.relx, edata.rely, edata.hp..'-'..(edata.def/2))
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


--while (true) do
--  FCEU.frameadvance()
--end;

