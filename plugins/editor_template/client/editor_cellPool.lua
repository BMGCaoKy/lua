local M = {}
local cell_pool = L("CellPool", {})
local cellCount = 0
local setting = require "common.setting"
function M:getCellPool()
	local ret = table.remove(cell_pool)
	if ret then
		cellCount = cellCount - 1
	end
	return ret
end


local function init()
	if CGame.instance:getEditorType() == 1 then
		return
	end
	local uiExist = {}
	for _, data in pairs(World.cfg.bagMainUi or {}) do
        uiExist[data.openWindow] = true
	end
	if not uiExist["unlimitedResources"] then
		return
	end
	local maxCreate = 1
	World.Timer(2, function()
		for i=1, 2 do 
			local ret = UIMgr:new_widget("cell","widget_cell_3.json","widget_cell_3")
			cell_pool[cellCount] = ret
		end
		cellCount = cellCount + 2
		maxCreate = maxCreate + 2
		return maxCreate < 400
	end)

	local loadBlockAltasList = {
		"myplugin/glass_0_2",
		"myplugin/lava_0",
		"myplugin/lava_0_0",
		"myplugin/lava_0_1",
		"myplugin/lava_0_2",
		"myplugin/lava_0_3",
		"myplugin/lava_0_4",
		"myplugin/lava_0_5",
		"myplugin/lava_0_6",
		"myplugin/lava_0_7",
		"myplugin/lava_0_8",
		"myplugin/lava_1",
		"myplugin/lava_10",
		"myplugin/lava_11",
		"myplugin/lava_12",
		"myplugin/lava_13",
		"myplugin/lava_14",
		"myplugin/lava_15",
		"myplugin/lava_16",
		"myplugin/lava_1_0",
		"myplugin/lava_1_1",
		"myplugin/lava_1_2",
		"myplugin/lava_1_3",
		"myplugin/lava_1_4",
		"myplugin/lava_1_5",
		"myplugin/lava_1_6",
		"myplugin/lava_1_7",
		"myplugin/lava_1_8",
		"myplugin/lava_2",
		"myplugin/lava_2_0",
		"myplugin/lava_2_1",
		"myplugin/lava_2_2",
		"myplugin/lava_2_3",
		"myplugin/lava_2_4",
		"myplugin/lava_2_5",
		"myplugin/lava_2_6",
		"myplugin/lava_2_7",
		"myplugin/lava_2_8",
		"myplugin/lava_3",
		"myplugin/lava_3_0",
		"myplugin/lava_3_1",
		"myplugin/lava_3_2",
		"myplugin/lava_3_3",
		"myplugin/lava_3_4",
		"myplugin/lava_3_5",
		"myplugin/lava_3_6",
		"myplugin/lava_3_7",
		"myplugin/lava_3_8",
		"myplugin/lava_4",
		"myplugin/lava_4_0",
		"myplugin/lava_4_1",
		"myplugin/lava_4_2",
		"myplugin/lava_4_3",
		"myplugin/lava_4_4",
		"myplugin/lava_4_5",
		"myplugin/lava_4_6",
		"myplugin/lava_4_7",
		"myplugin/lava_4_8",
		"myplugin/lava_5",
		"myplugin/lava_5_0",
		"myplugin/lava_5_1",
		"myplugin/lava_5_2",
		"myplugin/lava_5_3",
		"myplugin/lava_5_4",
		"myplugin/lava_5_5",
		"myplugin/lava_5_6",
		"myplugin/lava_5_7",
		"myplugin/lava_5_8",
		"myplugin/lava_6",
		"myplugin/lava_6_0",
		"myplugin/lava_6_1",
		"myplugin/lava_6_2",
		"myplugin/lava_6_3",
		"myplugin/lava_6_4",
		"myplugin/lava_6_5",
		"myplugin/lava_6_6",
		"myplugin/lava_6_7",
		"myplugin/lava_6_8",
		"myplugin/lava_7",
		"myplugin/lava_7_0",
		"myplugin/lava_7_1",
		"myplugin/lava_7_2",
		"myplugin/lava_7_3",
		"myplugin/lava_7_4",
		"myplugin/lava_7_5",
		"myplugin/lava_7_6",
		"myplugin/lava_7_7",
		"myplugin/lava_7_8",
		"myplugin/lava_8",
		"myplugin/lava_9",
	}

	for _, fullName in pairs(loadBlockAltasList) do
		local id = setting:name2id("block", fullName)
		World.CurWorld:loadBlockAltas(id)
	end

end

init()

RETURN(M)
