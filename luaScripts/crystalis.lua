--Crystalis lua script by TheAxeMan
--See note file for dev info

--Enemy data gui
require "crystalis_enemies";

--General items including player coords
require "crystalis_lib";

--My rewind module
require "myrewind";

--Macro module
require "crystalis_macros";


--Set up the list of registered gui functions
gui_registered_funcs = {}
all_ordered_registered_funcs = {}
local function register_func(fname, f)
  table.insert(all_ordered_registered_funcs, fname)
  gui_registered_funcs[fname] = f
end;

--Add all the functions. They will be ordered this way.
register_func("showEnemyHp", showEnemyHp)
register_func("updateEnemyGui", updateEnemyGui)
register_func("displayGlobalCounter", displayGlobalCounter)
register_func("displayRandSeed", displayRandSeed)
register_func("displaySwordCounter", displaySwordCounter)
register_func("displaySwordChargeCounter", displaySwordChargeCounter)
register_func("displayFastDiagonalIndicator", displayFastDiagonalIndicator)
register_func("displayWaitToMoveIndicator", displayWaitToMoveIndicator)
register_func("showSpawnPoints", showSpawnPoints)
register_func("showPotentialSwordHitbox", showPotentialSwordHitbox)
register_func("showPlayerCoords", showPlayerCoords)
register_func("displayRelCoords", displayRelCoords)
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

--Pause on last lag frame using rewind
pauseOnLastLagFrameEnable = true

require 'auxlib';


--To toggle a feature, swap function pointer into a disabled function table.
disabled_funcs = {}
local function toggleFeature(fname)
  disabled_funcs[fname], gui_registered_funcs[fname] = 
              gui_registered_funcs[fname], disabled_funcs[fname]
end;

local function makeFeatureItem(title, fname)
  return iup.item{
               title=title,
               value="ON",
               fname=fname,
               action=function(self) 
                       toggleFeature(self.fname) 
                       toggleMenuItem(self)
               end}
end;

--This is used by various routines to adjust to dolphin.
dolphinMode = false

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
        makeFeatureItem("Enemy Spawn Points", "showSpawnPoints"),
        makeFeatureItem("Global Counter", "displayGlobalCounter"),
        makeFeatureItem("RNG Seed", "displayRandSeed"),
        makeFeatureItem("Slope Counter", "displaySlopeCounter"),
        makeFeatureItem("Sword Counter", "displaySwordCounter"),
        makeFeatureItem("Sword Charge Counter", "displaySwordChargeCounter"),
        makeFeatureItem("Sword Shot Hitbox", "showShotHitbox"),
        makeFeatureItem("Fast Diagonal Indicator", "displayFastDiagonalIndicator")
      }; title="Display",
    },
    iup.submenu{
      iup.menu{
        iup.item{title="Pause on Last Lag Frame",
               value="ON",
               action=function(self)
                       pauseOnLastLagFrameEnable = not pauseOnLastLagFrameEnable
                       toggleMenuItem(self)
               end},
        iup.item{title="Dolphin Mode",
               value="OFF",
               action=function(self)
                       dolphinMode = not dolphinMode
                       toggleMenuItem(self)
               end},
        iup.item{title="Hide Zero-hp Enemy Text",
               value="ON",
               action=function(self)
                       hideZeroHpEnemies = not hideZeroHpEnemies
                       toggleMenuItem(self)
               end},
        makeFeatureItem("Update Enemy Data Table", "updateEnemyGui") 
      }; title="Other Options",
    },
    enemyDataOptions
  };

dialogs = dialogs + 1
handles[dialogs] = iup.dialog{
  menu=mainMenu,
  iup.hbox{
    enemyDataFrame,
    macroFrame
  };
  title="Crystalis TAS Console",
  margin="10x10"
}

handles[dialogs]:show()

--Start out paused.
FCEU.pause()

--The main loop
while (true) do
  if pauseOnLastLagFrameEnable then
    pauseOnLastLagFrame()
  end;
  doMacros()
  --e9x0 = memory.readbyte(0x0085)
  --e9y0 = memory.readbyte(0x00C5)
  --e10x0 = memory.readbyte(0x0086)
  --e10y0 = memory.readbyte(0x00C6)
  frameAdvanceWithRewind()
  --memory.writebyte(0x0085, e9x0)
  --memory.writebyte(0x00C5, e9y0)
  --memory.writebyte(0x0085, 0x08)
  --memory.writebyte(0x00C5, e9y0)
  --memory.writebyte(0x00A5, 0x01)
  --memory.writebyte(0x0086, e10x0)
  --memory.writebyte(0x00C6, e10y0)
end;

