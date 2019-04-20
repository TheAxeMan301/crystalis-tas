--Crystalis lua script by TheAxeMan
--See note file for dev info

--Enemy data gui
require "crystalis_enemies_light";

--General items including player coords
require "crystalis_lib";

--This is used by various routines to adjust to dolphin.
dolphinMode = false

--Set up the list of registered gui functions
gui_registered_funcs = {}
all_ordered_registered_funcs = {}
local function register_func(fname, f)
  table.insert(all_ordered_registered_funcs, fname)
  gui_registered_funcs[fname] = f
end;

--Each of these functions controls a features. Comment or uncomment to control what is enabled.
register_func("showEnemyHp", showEnemyHp)
--register_func("showEnemyDefense", showEnemyDefense)  --Swap this in for showEnemyHp to see defense too
--register_func("updateEnemyGui", updateEnemyGui)
register_func("displayGlobalCounter", displayGlobalCounter)
register_func("displayRandSeed", displayRandSeed)
register_func("displaySwordCounter", displaySwordCounter)
register_func("displaySwordChargeCounter", displaySwordChargeCounter)
--register_func("displayFastDiagonalIndicator", displayFastDiagonalIndicator)
register_func("displayWaitToMoveIndicator", displayWaitToMoveIndicator)
register_func("showSpawnPoints", showSpawnPoints)
--register_func("showPotentialSwordHitbox", showPotentialSwordHitbox)
--register_func("showPlayerCoords", showPlayerCoords)
--register_func("displayRelCoords", displayRelCoords)
register_func("displaySlopeCounter", displaySlopeCounter)
register_func("showEnemyHitbox", showEnemyHitbox)
register_func("showPlayerHitbox", showPlayerHitbox)
register_func("showActualSwordHitbox", showActualSwordHitbox)
register_func("showShotHitbox", showShotHitbox)

--The actual registered function calls all non-nil items in the registration table.
gui.register( function()
  for i,fname in ipairs(all_ordered_registered_funcs) do
    f = gui_registered_funcs[fname]
    --can set value to nil to  turn off
    if f then f() end;
  end;
end)

--The main loop
while (true) do
  FCEU.frameadvance()
end;

