--[[
Rewind lua support for FCEUX by TheAxeMan
Binds a controller key to rewind.

The built-in framecounter is used to track the buffer. When a
state is loaded, it is assumed to be part of the same timestream.
With no movie, framecounter resets on game reset. So the buffer
is flushed.

Memory usage is proportional to the savestate buffer length.
--]]


--This is the button used for rewind
rewindController = 2
rewindButton = "select"

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

