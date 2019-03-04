--[[
--Crystalis lua script for fastwarding the grind sections of my run. By TheAxeMan.
--]]

emu.speedmode("normal")

grindSections = {
    {23000, 25700},
    {30450, 32800},
    {41550, 46300},
    {75300, 76600},
    {76800, 80100},
    {90050, 91450},
    {91650, 92600},
    {112100, 113420},
}

--[[
--lengths:
--2700 (goombas)
--2350 (ice zombies)
--4750 (Sabre N guards)
--1300 (Evil Island before lvlup)
--3300 (Evil Island after lvlup)
--1400 (Styx before lvlup)
--950  (Styx after lvlup)
--1320 (spiders)
--18070 frames total, about 5 minutes
--]]

startGrind = {}
endGrind = {}
for i,subt in ipairs(grindSections) do
    --print(subt[1], subt[2])
    startGrind[subt[1]] = true
    endGrind[subt[2]] = true
end


while true do
   framecount = emu.framecount()
   if startGrind[framecount] ~= nil then
      emu.speedmode("turbo")
      --emu.pause()
   elseif endGrind[framecount] ~= nil then
      emu.speedmode("normal")
      --emu.pause()
   end;
   emu.frameadvance()
end


