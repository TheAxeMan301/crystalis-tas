--[[
Crystalis macro support
Add doMacros to main event loop. Gui sets macro_func, otherwise
it is nil. Macro functions do some action and use rewindable
frame advance. Macro func ends by setting input. Macro loop
then resets macro_func and pauses.
--]]

--[[
TODO:
Add tons of options
Set up calls to allow arguments !done!
Buttons should be disabled while macro is running
Add direct input terminal

--]]

--My rewind module
require "myrewind";
require "crystalis_lib";
require 'auxlib';

macro_func = nil

--Add this to main loop
function doMacros()
  while macro_func do
    disableMacroButtons()
    macro_func.func(macro_func.args)
    macro_func = nil
    enableMacroButtons()
    pauseWithRewind()
  end;
end;

--Do the specified control for the specified number of frames or until
--the function returns true. One frame if not specified.
--If numFrames is 0, then the control is set without a frameadvance. But lag
--frames are skipped.
--I don't see any reason _not_ to ignore lag. But make a global switch anyway.
macroPressButtonsIgnoreLag = true
local function pressButtons(inputTable, numFrames, stopFunc)
  if numFrames then
    if numFrames == 0 then
      repeat
        joypad.set(1, inputTable)
        frameAdvanceWithRewind()
      until not FCEU.lagged()
      frameRewind(1)
      joypad.set(1, inputTable)
    else
      for i=1,numFrames do
        if macroPressButtonsIgnoreLag then
          repeat
            joypad.set(1, inputTable)
            frameAdvanceWithRewind()
          until not FCEU.lagged()
        else
          joypad.set(1, inputTable)
          frameAdvanceWithRewind()
        end;
        if stopFunc and stopFunc() then break end;
      end;
    end;
  else
    joypad.set(1, inputTable)
    frameAdvanceWithRewind()
  end;
end;


--test movement function
local function moveUp(args)
  local frames = args[1]
  local ctrlinput = {}
  ctrlinput["up"] = 1
  for i = 1,frames-1 do
    gui.text(10,10,"Macro executing")
    joypad.set(1, ctrlinput)
    frameAdvanceWithRewind()
  end;
  gui.text(10,10,"")
  joypad.set(1, ctrlinput)
end;

--skip to last lag frame
local function skipToLastLagFrame()
  if not FCEU.lagged then return 0 end;
  while FCEU.lagged() do skipFrame() end;
  frameRewind(2)
  --now forward a frame to let it rewind
  --Normally this would be bad but here it's ok because it's just lag
  joypad.set(1, {})
  frameAdvanceWithRewind()
end;

--Record a reference state that can be used by various macros
macroReferenceState = savestate.create()
local function setReferenceState()
  savestate.save(macroReferenceState)
end;

--Component function to wait until a coin has been collected.
--If a coin pops out then wait until that coin is collected.
--But if player is standing right on spawn point then this is
--not possible. Instead, look for a dead enemy to move.
--Return true if successful in 100 frames, false otherwise.
local function waitUntilCoinCollected()
  local coinIndex = -1
  local coinCollected = false
  local lastframe_edata = getAllEnemyData()
  local framecount = 0
  repeat
    pressButtons({})
    framecount = framecount + 1
    if framecount > 100 then
      iup.Message("Problem", "Failed to figure out coin drop")
      return false
    end;
    local edata = getAllEnemyData()
    if coinIndex == -1 then
      for i=1,16 do
        local lastState = lastframe_edata[i].state
        local currentState = edata[i].state
        --if i==5 then
        --  iup.Message("debug", "For index 5, last state was "..lastState
        --0 or 125 means dead enemy or empty slot
        if lastState == 0 or lastState == 125 then
          --state 123 means coin
          if currentState == 123 then
            coinIndex = i
            --iup.Message("Figured out coin index", "Coin index is "..coinIndex)
            break;
          elseif currentState == 0 or currentState == 125 then
            --Check to see if a dead slot moved. Assume that means a coin
            --spawned and was collected. Only consider ey because ex moves
            --with an enemy's death throes.
            if lastframe_edata[i].ey ~= edata[i].ey then
              --iup.Message("Figured out coin index", "Coin index is "..i)
              return true
            end;
          end;
        end;
      end;
      lastframe_edata = edata
    elseif edata[coinIndex].state == 0 then
      --This means coin has been collected
      coinCollected = true
    end;
  until coinCollected
  return true
end;

--general movement function. Arguments are
--  dir: n,nne,ne,ene,e,ese,se,sse,s,ssw,sw,wsw,w,wnw,nw,nnw
--  stopframes: stop after this many frames
--  stopatwall: stop on hitting a wall in one dir
--  chargesword: 0,1,2,3 - will charge sword while moving
--  holdB: hold B button to keep sword charge
--  lag: ignore, reduce, fail - How to handle lag. ignore, fail or try to reduce it
function simpleMove(args)
  --First set up two input combinations. One for manhattan movement
  --and another for 45. But depending on dir, one may be blank.
  local mainCtrl = {}
  local diagCtrl = {}
  if args.dir == "n" then
    mainCtrl.up = 1
    diagCtrl = mainCtrl
  elseif args.dir == "nne" then
    mainCtrl.up = 1
    diagCtrl.up = 1
    diagCtrl.right = 1
  elseif args.dir == "ne" then
    diagCtrl.up = 1
    diagCtrl.right = 1
    mainCtrl = diagCtrl
  elseif args.dir == "ene" then
    mainCtrl.right = 1
    diagCtrl.up = 1
    diagCtrl.right = 1
  elseif args.dir == "e" then
    mainCtrl.right = 1
    diagCtrl = mainCtrl
  elseif args.dir == "ese" then
    mainCtrl.right = 1
    diagCtrl.down = 1
    diagCtrl.right = 1
  elseif args.dir == "se" then
    diagCtrl.down = 1
    diagCtrl.right = 1
    mainCtrl = diagCtrl
  elseif args.dir == "sse" then
    mainCtrl.down = 1
    diagCtrl.down = 1
    diagCtrl.right = 1
  elseif args.dir == "s" then
    mainCtrl.down = 1
    diagCtrl = mainCtrl
  elseif args.dir == "ssw" then
    mainCtrl.down = 1
    diagCtrl.down = 1
    diagCtrl.left = 1
  elseif args.dir == "sw" then
    diagCtrl.down = 1
    diagCtrl.left = 1
    mainCtrl = diagCtrl
  elseif args.dir == "wsw" then
    mainCtrl.left = 1
    diagCtrl.down = 1
    diagCtrl.left = 1
  elseif args.dir == "w" then
    mainCtrl.left = 1
    diagCtrl = mainCtrl
  elseif args.dir == "wnw" then
    mainCtrl.left = 1
    diagCtrl.up = 1
    diagCtrl.left = 1
  elseif args.dir == "nw" then
    diagCtrl.up = 1
    diagCtrl.left = 1
    mainCtrl = diagCtrl
  elseif args.dir == "nnw" then
    mainCtrl.up = 1
    diagCtrl.up = 1
    diagCtrl.left = 1
  else
    iup.Message("Error","Invalid or missing dir!")
    joypad.set(1, {})
    return nil
  end;

  --Skip past initial lag and wait counter. This allows macro
  --to run from entrance to a new area.
  if FCEU.lagged() then skipToLastLagFrame() end;
  while mustWaitToMove() do skipFrame() end;

  --if no max framecount is given, limit anyway
  local stopFrames = args.stopframes
  if not stopFrames or stopFrames <= 0 then stopFrames = 200 end;

  --if stopatwall isn't specified, do it anyway
  if args.stopatwall == nil then args.stopatwall = true end;
  local lastFrameCtrl = joypad.read(1)

  --iup.Message("debug", "chargesword is "..tostring(args.chargesword))
  if args.chargesword == 0 then args.chargesword = false end;

  --now start moving
  local frames = 0
  while(true) do
    gui.text(10,10,"Macro Executing")
    gui.text(10,20,"Moved "..frames)
    gui.text(10,30,"moving "..args.dir)

    --Move diagonal on fast diag frames, manhattan otherwise
    local fastDiag = fastDiagonalThisFrame()
    if fastDiag then
      thisFrameCtrl = diagCtrl
    else
      thisFrameCtrl = mainCtrl
    end;

    --To charge sword, hit B when global counter is odd
    if args.chargesword then
      local counter = memory.readbyte(0x0008)
      local chargemeter = memory.readbyte(0x0EC0)
      if counter % 2 == 1 or (args.holdB and chargemeter >= 8 * args.chargesword) then
        thisFrameCtrl.B = 1
      else
        thisFrameCtrl.B = nil
      end;
    elseif args.holdB then
      thisFrameCtrl.B = 1
    end;

    --set up the joypad
    joypad.set(1, thisFrameCtrl)

    --increment frame count and check limit
    frames = frames + 1
    if frames >= stopFrames then break end;

    --store location before and after moving
    local pdata1 = getPlayerCoords()
    frameAdvanceWithRewind()
    local pdata2 = getPlayerCoords()

    --stop if sword is fully charged
    if args.chargesword and not args.holdB then
      --iup.Message("Debug", "Checking to see if sword is fully charged")
      local chargemeter = memory.readbyte(0x0EC0)
      if chargemeter >= 8 * args.chargesword then
        frameRewind(1)
        joypad.set(1, thisFrameCtrl)
        break;
      end;
    end;

    if args.stopfunc and args.stopfunc() then 
      frameRewind(1)
      joypad.set(1, thisFrameCtrl)
      break;
    elseif args.stopx ~= nil and pdata2.px == args.stopx then
      frameRewind(1)
      joypad.set(1, thisFrameCtrl)
      break;
    elseif args.stopy ~= nil and pdata2.py == args.stopy then
      frameRewind(1)
      joypad.set(1, thisFrameCtrl)
      break;
    end;

    --check for wall, but only if this isn't a lag frame.
    if args.stopatwall and not FCEU.lagged() then
      --Compare how much we thought we'd move by how far we actually did.
      --If it doesn't match assume we hit a wall.
      local expected_dx = 0
      local expected_dy = 0
      if thisFrameCtrl.up then expected_dy = -2 end;
      if thisFrameCtrl.down then expected_dy = 2 end;
      if thisFrameCtrl.left then expected_dx = -2 end;
      if thisFrameCtrl.right then expected_dx = 2 end;
      if expected_dy ~= 0 and expected_dx ~= 0 and not fastDiag then
        expected_dy = 0.5 * expected_dy
        expected_dx = 0.5 * expected_dx
      end;
      local actual_dx = pdata2.px-pdata1.px
      local actual_dy = pdata2.py-pdata1.py
      --gui.text(10,10,"expected: "..expected_dx..","..expected_dy)
      --gui.text(10,10,"actual: "..actual_dx..","..actual_dy)
      if actual_dx ~= expected_dx or actual_dy ~= expected_dy then
        --hit a wall. Back out a frame by rewinding, then set up control again.
        frameRewind(2)
        --Set up control again as there will be a frameadvance
        --before user regains control.
        joypad.set(1, lastFrameCtrl)
        break
      end; -- handle wall hit
    end; -- wall check
    lastFrameCtrl = thisFrameCtrl
  end; --while loop
  --if frames then iup.message("Moved "..frames.." frames") end;
  gui.text(10,10,"")
  if not args.dontDoLastFrameAdvance then frameAdvanceWithRewind() end;
end;


--  The directions actually travelled are translated to go up then left:
--
--           corner
--  --------+
--          |
--          |
--          |
--

--Translate one dir to left and the other to up.
local function cornerRoundGetControls(dir1, dir2)
  local leftCtrl = {}
  local upCtrl = {}
  local diagCtrl = {}
  local cornerFindDiagCtrl = {}
  if dir1 == "n" then
    leftCtrl.up = 1
    cornerFindDiagCtrl.up = 1
    diagCtrl.up = 1
  elseif dir1 == "s" then
    leftCtrl.down = 1
    cornerFindDiagCtrl.down = 1
    diagCtrl.down = 1
  elseif dir1 == "e" then
    leftCtrl.right = 1
    cornerFindDiagCtrl.right = 1
    diagCtrl.right = 1
  elseif dir1 == "w" then
    leftCtrl.left = 1
    cornerFindDiagCtrl.left = 1
    diagCtrl.left = 1
  end;
  if dir2 == "n" then
    upCtrl.up = 1
    cornerFindDiagCtrl.down = 1
    diagCtrl.up = 1
  elseif dir2 == "s" then
    upCtrl.down = 1
    cornerFindDiagCtrl.up = 1
    diagCtrl.down = 1
  elseif dir2 == "e" then
    upCtrl.right = 1
    cornerFindDiagCtrl.left = 1
    diagCtrl.right = 1
  elseif dir2 == "w" then
    upCtrl.left = 1
    cornerFindDiagCtrl.right = 1
    diagCtrl.left = 1
  end;
    
  return leftCtrl, upCtrl, diagCtrl, cornerFindDiagCtrl
end;

local function cornerRoundTranslateCoords(dir1, dir2, actual_dx, actual_dy)
  local dx, dy
  if dir1 == "n" then
    dx = actual_dy
  elseif dir1 == "s" then
    dx = -actual_dy
  elseif dir1 == "e" then
    dx = -actual_dx
  elseif dir1 == "w" then
    dx = actual_dx
  end;
  if dir2 == "n" then
    dy = actual_dy
  elseif dir2 == "s" then
    dy = -actual_dy
  elseif dir2 == "e" then
    dy = -actual_dx
  elseif dir2 == "w" then
    dy = actual_dx
  end;
  return dx, dy
end;

function cornerRound(args)
  local dir1 = args.dir1
  local dir2 = args.dir2
  local searchFrames = args.searchFrames or 200
  --start out by saving state and remembering start coords
  local startState = savestate.create(9)
  savestate.save(startState)
  local startCoords = getPlayerCoords()
  --iup.Message("debug", "checkpoint 1")

  --A helper function translates directions into a reference system
  --where the wall is to the west and the corner is north.
  local leftCtrl, upCtrl, diagCtrl, cornerFindDiagCtrl = cornerRoundGetControls(dir1, dir2)

  --If using the reference point, load that state and find the corner from there.
  if args.use_reference then
    savestate.load(macroReferenceState)
  end;

  --find the wall
  simpleMove{dir=dir1, stopframes=searchFrames}
  pressButtons(diagCtrl, 3)
  local wallCoords = getPlayerCoords()
  --At this point we should be right next to the wall

  local corner_x, corner_y, cornerDetectFunc
  if dir1 == "n" or dir1 == "s" then
    corner_y = wallCoords.py
    cornerDetectFunc = function() return getPlayerCoords().py ~= corner_y end
  else
    corner_x = wallCoords.px
    cornerDetectFunc = function() return getPlayerCoords().px ~= corner_x end
  end;
  --Now press diagonal until we're just past the corner
  pressButtons(diagCtrl, searchFrames, cornerDetectFunc)

  --Move a couple steps to be flush with this new wall
  pressButtons(cornerFindDiagCtrl, 3)

  if dir1 == "n" or dir1 == "s" then
    corner_x = getPlayerCoords().px
  else
    corner_y = getPlayerCoords().py
  end;

  --At this point it doesn't matter if we loaded the reference state earlier or not.
  savestate.load(startState)
  --iup.Message("Corner coords", "Corner coords are "..corner_x..", "..corner_y)
  local actual_dx = corner_x - startCoords.px
  local actual_dy = corner_y - startCoords.py
  local dx, dy = cornerRoundTranslateCoords(dir1, dir2, actual_dx, actual_dy)

  --It's actually best to aim for a pixel before the corner
  local dy = dy+1
  local startTangent = math.abs(dx) / math.abs(dy)
  --iup.Message("Tangent", "Start tangent is "..startTangent)

  --This loop goes until within 2 steps.
  --Note that there's no wall above, so dy could become > 0
  while math.abs(dx) > 3 or math.abs(dy) > 3 do
    --iup.Message("Corner dist", "Actual relative corner location is "..actual_dx..", "..actual_dy)
    --iup.Message("Corner dist", "Translated relative corner location is "..dx..", "..dy)
    if math.abs(dx) <= 1 then
      pressButtons(upCtrl)
    elseif dy >= 0 then
      pressButtons(leftCtrl)
    elseif math.abs(math.abs(dx) - math.abs(dy)) <= 1 then
      --this case covers tangent close to 1
      pressButtons(diagCtrl)
    else
      local tangent = math.abs(dx) / math.abs(dy)
      gui.text(10,10,tangent)
      --iup.Message("Tangent", "Current tangent is "..tangent)
      local fastDiag = fastDiagonalThisFrame()
      if tangent <= 0.7 then
        if fastDiag and tangent >= startTangent then
          pressButtons(diagCtrl)
        else
          pressButtons(upCtrl)
        end;
      elseif tangent < 1 then
        if fastDiag or tangent >= startTangent then
          pressButtons(diagCtrl)
        else
          pressButtons(upCtrl)
        end;
      elseif tangent >= 1.4 then
        if fastDiag and tangent <= startTangent then
          pressButtons(diagCtrl)
        else
          pressButtons(leftCtrl)
        end;
      elseif tangent > 1 then
        if fastDiag or tangent <= startTangent then
          pressButtons(diagCtrl)
        else
          pressButtons(leftCtrl)
        end;
      end;
    end;
    
    local playerCoords = getPlayerCoords()
    actual_dx = corner_x - playerCoords.px
    actual_dy = corner_y - playerCoords.py
    dx, dy = cornerRoundTranslateCoords(dir1, dir2, actual_dx, actual_dy)
    dy = dy + 1
  end;  --while loop

  local playerCoords = getPlayerCoords()
  --iup.Message("End of loop", "Player coords are "..playerCoords.px..", "..playerCoords.py)
  --iup.Message("End of loop", "Relative corner location is "..dx..", "..dy)

  --Now we are within 3 pixels of corner. Things get a little tricker so handle
  --each case individually.
  --Also, this is where the tight option comes into play.
  --Don't forget, I am checking this memory once here. It doesn't get updated
  --after taking any steps.
  local fastDiag = fastDiagonalThisFrame()

  if dy > 0 then
    pressButtons(leftCtrl, 5, function()
        return getPlayerCoords().px <= corner_x+2
    end)
    pressButtons(leftCtrl, 0)
  elseif math.abs(dy) == 0 then
    if math.abs(dx) == 0 then
      pressButtons(diagCtrl, 0)
    elseif math.abs(dx) == 1 then
      if fastDiag then
        pressButtons(diagCtrl, 0)
      else
        pressButtons(diagCtrl)
        pressButtons(leftCtrl, 0)
      end;
    elseif math.abs(dx) >= 2 then
      if fastDiag then
        pressButtons(diagCtrl)
        pressButtons(leftCtrl, 0)
      else
        pressButtons(leftCtrl)
        pressButtons(diagCtrl, 0)
      end;
    end;

  elseif math.abs(dy) == 1 then
    if math.abs(dx) == 0 then
      if fastDiag then
        pressButtons(diagCtrl, 0)
      else
        pressButtons(upCtrl, 0)
      end;
    elseif math.abs(dx) == 1 then
      if fastDiag then
        pressButtons(diagCtrl, 0)
      else
        pressButtons(diagCtrl)
        pressButtons(diagCtrl, 0)
      end;
    elseif math.abs(dx) >= 2 then
      if fastDiag then
        pressButtons(diagCtrl)
        pressButtons(leftCtrl, 0)
      else
        pressButtons(leftCtrl)
        pressButtons(diagCtrl, 0)
      end;
    end;

  elseif math.abs(dy) == 2 then
    if math.abs(dx) == 0 then
      if fastDiag and not args.tight then
        pressButtons(upCtrl)
        pressButtons(upCtrl, 0)
      else
        pressButtons(upCtrl)
        pressButtons(diagCtrl, 0)
      end;
    elseif math.abs(dx) == 1 then
      if args.tight then
        if fastDiag then
          pressButtons(upCtrl)
          pressButtons(diagCtrl, 0)
        else
          pressButtons(diagCtrl)
          pressButtons(diagCtrl, 0)
        end;
      else
        if fastDiag then
          pressButtons(upCtrl)
          pressButtons(upCtrl, 0)
        else
          pressButtons(upCtrl)
          pressButtons(diagCtrl, 0)
        end;
      end;
    elseif math.abs(dx) >= 2 then
      if args.tight then
        pressButtons(diagCtrl)
        pressButtons(diagCtrl, 0)
      else
        if fastDiag then
          pressButtons(diagCtrl)
          pressButtons(upCtrl, 0)
        else
          pressButtons(upCtrl)
          pressButtons(diagCtrl, 0)
        end;
      end;
    end;

  elseif math.abs(dy) == 3 then
    if math.abs(dx) == 0 then
      pressButtons(upCtrl)
      pressButtons(upCtrl, 0)
    elseif math.abs(dx) == 1 then
      if fastDiag then
        if args.tight then
          pressButtons(upCtrl)
          pressButtons(diagCtrl)
          pressButtons(diagCtrl, 0)
        else
          pressButtons(upCtrl)
          pressButtons(upCtrl, 0)
        end;
      else
        pressButtons(upCtrl)
        pressButtons(diagCtrl, 0)
      end;
    elseif math.abs(dx) == 2 then
      if fastDiag then
        pressButtons(diagCtrl)
        pressButtons(upCtrl, 0)
      else
        pressButtons(upCtrl)
        pressButtons(diagCtrl, 0)
      end;
    elseif math.abs(dx) == 3 then
      if args.tight then
        pressButtons(diagCtrl)
        pressButtons(diagCtrl)
        pressButtons(diagCtrl, 0)
      else
        if fastDiag then
          pressButtons(diagCtrl)
          pressButtons(upCtrl, 0)
        else
          pressButtons(upCtrl)
          pressButtons(diagCtrl, 0)
        end;
      end;
    end;

  end;
      
end;

function pauseAndUnpause()
  local temp = macroPressButtonsIgnoreLag
  macroPressButtonsIgnoreLag = false
  --Press select to pause
  pressButtons({select=1})
  --Wait a couple frames
  pressButtons({}, 2)
  --It should lag for a bit while menu comes up. Wait for lag to end.
  while FCEU.lagged() do
    pressButtons({})
  end;
  --Press select again to unpause
  pressButtons({select=1})
  --Wait a couple more frames
  pressButtons({}, 2)
  macroPressButtonsIgnoreLag = temp
  --Ending the macro skips a frame of lag.
end;

--Walk up the slope until low four bits of counter are 1.
--Then pause and unpause to skip increment.
function slopeGlitchClimb()
  local globalCounter = memory.readbyte(0x0008)
  while AND(globalCounter, 0xF) > 1 do
    pressButtons({up=1})
    globalCounter = memory.readbyte(0x0008)
  end;
  pauseAndUnpause()
end;

--Wait some frames until enemy takes damage, holding some buttons if specified.
local function waitForHit(enemyIndex, buttonsToPress)
  if buttonsToPress == nil then buttonsToPress = {} end;
  local edata = getEnemyData(enemyIndex)
  local lasthp = edata.hp
  for i=1,20 do
    pressButtons(buttonsToPress)
    edata = getEnemyData(enemyIndex)
    if edata.hp < lasthp then break; end;
  end;
end;

--Grind bot for styx point using rabbit boots.
--Assumes setup already done and beginning at top screen.
function styxGrind()
  --Wait to move
  if FCEU.lagged() then skipToLastLagFrame() end;
  while mustWaitToMove() do skipFrame() end;
  local temp = macroPressButtonsIgnoreLag
  macroPressButtonsIgnoreLag = true
  --On first frame begin sword swing
  pressButtons({up=1,A=1,B=1})
  --Move up one more frame
  pressButtons({up=1})
  --Now down to other screen
  pressButtons({down=1}, 2)
  pressButtons({}, 2)
  --On next screen wait until full control returns
  skipToLastLagFrame()
  while mustWaitToMove() do skipFrame() end;
  --One hit happens right away
  pressButtons({}, 2)
  --Get a second hit in
  waitForHit(1)
  --Swing again
  pressButtons({B=1}, 1)
  waitForHit(1)
  --Need to press up for next hit
  waitForHit(1, {up=1})
  --Swing again
  pressButtons({B=1}, 1)
  --Now need to wait until we land
  while getPlayerCoords().py < 98 do
    skipFrame()
  end;
  while getPlayerCoords().py == 98 do
    pressButtons({up=1})
  end;
  --Should be a fast diagonal
  pressButtons({up=1,left=1}, 1)
  --Should be a fast diagonal
  pressButtons({up=1}, 1)
  --At this point he should take another hit.
  pressButtons({up=1,left=1}, 5)
  pressButtons({left=1}, 1)
  pressButtons({up=1,left=1}, 1)
  --Here we are in position for the next hit.
  pressButtons({left=1}, 1)
  pressButtons({up=1,left=1,B=1}, 1)
  pressButtons({up=1}, 6)
  --Another hit
  pressButtons({right=1}, 1)
  pressButtons({up=1,left=1}, 1)
  pressButtons({up=1}, 5)
  --Last hit
  pressButtons({right=1}, 1)
  pressButtons({up=1}, 1)
  --Exit
  pressButtons({up=1,right=1}, 3)
  pressButtons({up=1}, 2)

  macroPressButtonsIgnoreLag = temp
end;

--Grind bot for goombas south of Brynmaer. Begin at 464,1580 with charged sword.
--Level 4 required so that they die with one stab.
function goombaGrind()
  --Need to wait until enemy11 spawns. Don't forget to hold down B.
  local globalCounter = memory.readbyte(0x0008)
  while globalCounter > 0xA0 do
    pressButtons({B=1})
    globalCounter = memory.readbyte(0x0008)
  end;
  --Move south, approaching #11
  simpleMove{dir="s", holdB=1, stopy=1628}
  --Turn and shoot #10
  pressButtons({left=1})
  --Wait until we can start charging again
  while memory.readbyte(0x0600) > 11 do
    pressButtons({})
  end;
  --Charge up another shot
  while memory.readbyte(0x0EC0) < 8 do
    pressButtons({B=1})
  end;
  --Turn and shoot #11
  pressButtons({down=1})
  --Now wait until the coin pops into my hands. First examine enemy data
  --to figure out what index the coin spawns as. Then wait until it is
  --collected.
  local success = waitUntilCoinCollected()
  if not success then return end;

  --Proceed nne to attack enemy 9
  simpleMove{dir="nne", stopx=494}
  --Move to within 50 of enemy 9
  local stopfunc = function()
    local edata = getAllEnemyData()
    return (edata[9].dy <= 50)
  end;
  simpleMove{dir="n", stopfunc=stopfunc}
  --Press B to stab
  pressButtons({up=1, B=1})
  --Continue far enough to collect his coin
  stopfunc = function()
    local edata = getAllEnemyData()
    return (edata[9].dy <= 13)
  end;
  simpleMove{dir="n", stopfunc=stopfunc}
  simpleMove{dir="e", stopx=500}
  success = waitUntilCoinCollected()
  if not success then return end;

  --Move ese to scroll screen.
  simpleMove{dir="ese", stopx=512}
  simpleMove{dir="s", stopy=1490}

  --Charge up and return to starting point
  simpleMove{dir="ssw", stopx=484, chargesword=1, holdB=1}
  simpleMove{dir="s", stopy=1580, chargesword=1, holdB=1}
  simpleMove{dir="w", stopx=464, chargesword=1, holdB=1}

  --Press B before returning control
  pressButtons({B=1}, 0)

end;

--Grind bot for blobs just outside the windmill cave.
--Begin on leaving the cave. Bot will kill the two blobs that
--appear immediately. Then goes back into cave and back out.
function blobGrind()
  --For now the plan is to walk straight down and turn to kill closest blob.
  --Then charge sword while walking down further. Shoot and continue down.
  --Experiment on when to turn to get best results

  --Skip past initial lag and wait counter. This allows macro
  --to run from entrance to a new area.
  if FCEU.lagged() then skipToLastLagFrame() end;
  while mustWaitToMove() do skipFrame() end;

  --iup.Message("Info", "Beginning at frame "..movie.framecount())

  --Start stabbing and walk down
  pressButtons({down=1, B=1})
  --Go down until ready to turn and kill the blob.
  pressButtons({down=1}, 20, function() return getPlayerCoords().py >= 134 end)
  --Global counter needs to be odd on the one frame that we turn.
  --Move down one more frame if it's even.
  if memory.readbyte(0x0008) % 2 == 1 then
    pressButtons({down=1})
  end;
  --Now turn left for one frame to hit the blob.
  pressButtons({left=1})
  --That should have killed enemy #9. If not, report the problem.
  --This could be because he moved left immediately.
  local enemy9state = memory.readbyte(0x04b5)
  if enemy9state ~= 0 and enemy9state ~= 125 then
    iup.Message("Bot Encountered a Problem", "Failed to kill enemy #9")
    return
  end;

  --Use simpleMove to go down and charge sword
  simpleMove{dir="s", stopframes=100, chargesword=1}

  --It's best to shoot right away.
  --Release B and walk down until Y coord is past 206
  pressButtons({down=1}, 100, function() return getPlayerCoords().py >= 204 end)

  --Experiment to figure out how far down we need to go 
  local testState = savestate.create(9)
  savestate.save(testState)
  local enemy11state = memory.readbyte(0x04b7)

  for moreSteps=1,10 do
    savestate.load(testState)
    --Move down a bit to scroll the screen. Then go back up.
    pressButtons({down=1}, moreSteps)
    pressButtons({up=1}, 40)
    --Check to see if enemy is dead. If so, move on. Otherwise try again.
    local enemy11state = memory.readbyte(0x04b7)
    if enemy11state == 0 or enemy11state == 125 then break end;
    --Start over. This time wait a frame before moving back up.
    savestate.load(testState)
    pressButtons({down=1}, moreSteps)
    pressButtons({})
    pressButtons({up=1}, 40)
    enemy11state = memory.readbyte(0x04b7)
    if enemy11state == 0 or enemy11state == 125 then break end;
  end;
  --Just in case, check to make sure #11 is dead
  enemy11state = memory.readbyte(0x04b7)
  if enemy11state ~= 0 and enemy11state ~= 125 then
    iup.Message("Bot Encountered a Problem", "Failed to kill enemy #11")
    return
  end;

  --Continue up to cave
  pressButtons({up=1}, 100, function() return getPlayerCoords().py <= 111 end)
  --The bot wastes a frame on exit but it doesn't matter since we
  --just entered the cave and it's lagging.

end;


local function stomTest(args)
  local testState = savestate.create(8)
  savestate.save(testState)

  local stomCounter = memory.readbyte(0x657f)
  local globalCounter = memory.readbyte(0x0008)
  local randSeed = memory.readbyte(0x000e)

  local winningSeeds = {}
  
  FCEU.speedmode("turbo")

  for seed = 0,63 do
    savestate.load(testState)
    memory.writebyte(0x000e, seed)
    while movie.framecount() < 20198 do
      pressButtons({})
    end;
    while not FCEU.lagged() do
      pressButtons({B=1})
      pressButtons({}, 6)
    end;
    local py = getPlayerCoords().py
    if py ~= 158 then
      winningSeeds[seed] = movie.framecount()
    end;
  end;

  local msg = "Results:"
  for seed, fc in pairs(winningSeeds) do
    msg = msg.." "..seed..":"..fc-20198
  end;

  --iup.Message("Results", "With Stom counter "..stomCounter.." there were "..#winningSeeds.." winning seeds")
  iup.Message("Results", msg)
  FCEU.speedmode("turbo")

end;

--Set up the gui

--First, set up options. First option is general movement macro.
macroDirList = iup.list{"n","nne","ne","ene","e","ese","se","sse","s","ssw","sw","wsw","w","wnw","nw","nnw"; editbox="YES", size="x100", expand="HORIZONTAL", value="n"}
chargeList = iup.list{
        "No Charge", "Level 1", "Level 2", "Level 3"; 
        dropdown="YES",
        expand="YES",
        value=1
}
macroFrameSpin = iup.text{value=100, expand="YES"}
holdBToggle = iup.toggle{title="Hold B", value="OFF"}

local moveMacroOptionsBox = 
      iup.vbox{
        iup.frame{
          macroDirList,
          title="Direction"
        },
        iup.frame{
          chargeList,
          title="Charge Sword"
        },
        iup.frame{
          macroFrameSpin;
          title="Max Frames"
        },
        holdBToggle
      }

cornerRoundDir1List = iup.list{
        "n", "s", "e", "w"; 
        dropdown="YES",
        expand="HORIZONTAL",
        value=1
}
cornerRoundDir2List = iup.list{
        "n", "s", "e", "w"; 
        dropdown="YES",
        expand="HORIZONTAL",
        value=1
}
cornerRoundTightToggle = iup.toggle{title="Tight", value="ON"}
cornerRoundReferenceToggle = iup.toggle{title="Use Reference State", value="OFF"}
local cornerRoundMacroOptionsBox = 
      iup.vbox{
        iup.frame{
          cornerRoundDir1List,
          title="Dir to Wall"
        },
        iup.frame{
          cornerRoundDir2List,
          title="Dir to Corner"
        },
        cornerRoundTightToggle,
        cornerRoundReferenceToggle
      }
local noOptionsBox = 
      iup.vbox{
        iup.label{title="No options", expand="YES"}
      }

--Set up action for general move macro
local function moveAction()
  macro_func = {}
  macro_func.func = simpleMove
  macro_func.args = {}
  macro_func.args.dir = macroDirList.value
  macro_func.args.chargesword = tonumber(chargeList.value)-1
  --iup.Message("debug","frames is '"..macroFrameSpin.value.."'")
  macro_func.args.stopframes = tonumber(macroFrameSpin.value)
  macro_func.args.holdB = (holdBToggle.value == "ON")
  macro_func.args.dontDoLastFrameAdvance = true
end;

local function makeNoArgAction(funcToRun)
return function()
          macro_func = {}
          macro_func.func = funcToRun
          macro_func.args = {}
       end;
end;

--Set up macro controls for corner round
local function cornerRoundAction()
  macro_func = {}
  macro_func.func = cornerRound
  macro_func.args = {}
  macro_func.args.dir1 = cornerRoundDir1List[cornerRoundDir1List.value]
  macro_func.args.dir2 = cornerRoundDir2List[cornerRoundDir2List.value]
  macro_func.args.tight = (cornerRoundTightToggle.value == "ON")
  macro_func.args.use_reference = (cornerRoundReferenceToggle.value == "ON")
end;

local macroInfoTable = {
        {name="Move",         action=moveAction,        options=moveMacroOptionsBox},
        {name="Corner Round", action=cornerRoundAction, options=cornerRoundMacroOptionsBox},
        {name="Blob Bot",     action=makeNoArgAction(blobGrind)},
        {name="Goomba Bot",     action=makeNoArgAction(goombaGrind)},
        {name="Styx Bot",     action=makeNoArgAction(styxGrind)},
        {name="Pause&Unpause",     action=makeNoArgAction(pauseAndUnpause)},
        {name="Slope Glitch Climb",     action=makeNoArgAction(slopeGlitchClimb)},
        {name="Set Reference Point",     action=makeNoArgAction(setReferenceState)}
}

local actionSelect = iup.list{
        dropdown="YES",
        expand="YES",
        value=1
}
--Map macro index to action function and options gui.
--Options gui may be nil in which case an empty option box is displayed.
local macroActionTable = {}
local macroOptionsTable = {}
local macroOptionsZbox = iup.zbox{}
for i,t in ipairs(macroInfoTable) do
  macroActionTable[i] = t.action
  macroOptionsTable[i] = t.options
  actionSelect[i] = t.name
  --iup.Message("Debug", "Adding item '"..t.name.."' with action of type "..type(t.action).." and options of type "..type(t.options))
  if t.options then
    iup.Append(macroOptionsZbox, t.options)
  end
end;
--Add blank options box to zbox
iup.Append(macroOptionsZbox, noOptionsBox)
--Initialize zbox to first option
if macroOptionsTable[1] then
  macroOptionsZbox.value = macroOptionsTable[1]
else
  macroOptionsZbox.value = noOptionsBox
end;

--Set up a callback on the action pulldown list so that the option box
--changes to match the selected action.
actionSelect.action=function()
  local optionBox = macroOptionsTable[tonumber(actionSelect.value)]
  if optionBox then
    macroOptionsZbox.value = optionBox
  else
    macroOptionsZbox.value = noOptionsBox
  end;
end;

--Set up the go button. The action defers to the function corresponding
--to the selected action.
local function goButtonAction()
  local actionFunc = macroActionTable[tonumber(actionSelect.value)]
  if not actionFunc then 
    iup.Message("Problem", "Nil function in lookup. select value is "..actionSelect.value .." name is "..actionSelect[actionSelect.value])
  end;

  actionFunc()
  --unpause the emulator but don't advance yet
  FCEU.unpause()
end;
goButton = iup.button{title="Go", action=goButtonAction, expand="YES"}

function disableMacroButtons()
  goButton.active = "OFF"
end;
function enableMacroButtons()
  goButton.active = "ON"
end;


--This is the frame that gets added to the main console.
macroFrame = iup.frame{
  iup.vbox{
    actionSelect,
    iup.fill{size=5},
    goButton,
    iup.fill{size=10},
    macroOptionsZbox
  };
  title="Macro",
  margin="10x10"
}

--debugging functions
function macro_gui_debug()
  gui.text(10,10,"macro gui debug")
  gui.text(10,20,"dirList.value is "..macroDirList.value)
  --if macro_func.args.dir then gui.text(10,30,"dir is "..macro_func.args.dir) end;
end;

--gui.register(macro_gui_debug)


