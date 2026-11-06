--[[ See license.txt for license and copyright information ]]
select(2, ...).SetupGlobalFacade()

AlertSounds = {
    { name = "Flute", id = 7734 },
    { name = "Fog Horn", id = 7197 },
    { name = "Bell Toll 1", id = 6674 },
    { name = "Bell Toll 2", id = 6595 },
    { name = "Thaddius", id = 8873 },
    { name = "Horn of Awakening", id = 7034 },
    { name = "Raspberry", id = 2837 },
}

AlertSoundsLUT = { }

for _, v in ipairs(AlertSounds) do
    AlertSoundsLUT[v.id] = v.name
end
