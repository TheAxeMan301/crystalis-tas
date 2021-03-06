# Crystalis lua scripts for TAS and analysis
Lua scripts for FCEUX. Originally made for FCEUX 2.1.5 but seems to be working with 2.2.3.

## How to use
Load Crystalis in FCEUX. Go to File -> lua -> New Lua Script Window... Find this directory and pick [crystalis.lua](crystalis.lua)


## Light version for realtime play
This lua code was originally designed for TAS creation. So it was no concern if the lua script would slow down the emulator. For realtime play the [lighter version](crystalis_light.lua) is the way to go. Even a computer with modest processing power should be able to run in real time. To adjust the features in this version, edit the set of `register_func` lines, commenting out unwanted features and uncommenting ones to use.

The light version lua script is also suitable as a trainer for the [randomizer](http://crystalisrandomizer.com).

## Toggling features
The many features can be controlled from the iup window that pops open.

### Display
Toggle display of various hitboxes, counters, coordinates and other indicators.

### Other Options
The pause on last lag frame is very useful for TASing but annoying otherwise. Dolphin mode switches the fast movement indicators to be useful when riding the dolphin. Hiding zero hp hitboxes cuts text that is less useful for things like coins, npcs and explosions where just seeing the hitbox is the important thing. Turning off the enemy data table updates can speed up playback.

### Enemy Data Options
Displaying enemy data in the table can cause signficant slowdown. It can be extremely useful for a TAS though. Showing close enemies is useful for normal combat. Showing specific enemies is most useful when concerned with offscreen enemies.

