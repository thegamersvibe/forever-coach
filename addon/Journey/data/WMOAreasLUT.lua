--[[ See license.txt for license and copyright information ]]
select(2, ...).SetupGlobalFacade()

WMOAreasLUT = { }

for k, v in pairs(WMOAreas) do
    WMOAreasLUT[v] = k
end
