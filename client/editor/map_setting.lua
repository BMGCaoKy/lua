local data_state = require "editor.dataState"
local cjson = require "cjson"
local engine = require "editor.engine"
local M = {}

function M:init()
	local function getAllMapName()
		local ret = {}
		local rootPath = Root.Instance():getGamePath().. "map/"
		for fileName in lfs.dir(Root.Instance():getGamePath().. "map/") do
			if fileName ~= "." and fileName ~= ".." and fileName ~= "patchDir" then
				local fileattr = lfs.attributes(rootPath .. fileName, "mode", true)
				if fileattr == "directory" then
					ret[#ret + 1] = fileName
				end
			end
		end
		return ret
	end
	self.allSetting = {}
	local allMapName = getAllMapName()
	for _, mapName in pairs(allMapName) do
		local obj = Lib.readGameJson("map/" .. mapName .. "/setting.json")
		obj.dirty = false
		self.allSetting[mapName] = obj
	end
end

function M:load()
	local mapName = data_state.now_map_name
	local obj = self.allSetting[mapName]
	if obj then
		obj.dirty = true
	else
		obj = Lib.readGameJson("map/" .. mapName .. "/setting.json")
		obj.dirty = true
		self.allSetting[mapName] = obj
	end
end

function M:save(path)
	for mapName, contentObj in pairs(self.allSetting) do
		local saveFilePath = string.format("%s%s%s", path, "map/" .. mapName, "/setting.json")
		self:saveJson(saveFilePath, contentObj)
	end
end

function M:getEntitysByMapName(mapName)
	return self.allSetting[mapName].entity
end

function M:save_entitys(all_entitys)
	for mapName, value in pairs(all_entitys) do
		local obj = {}
		for k,v in pairs(value.datas) do
			table.insert(obj,v)
		end
		self.allSetting[mapName].entity = obj
	end
end

function M:setBirthPos(pos)
	local mapName = data_state.now_map_name
	self.allSetting[mapName].birthPos = pos
	self.allSetting[mapName].pos = pos
end

function M:get_items()
	local mapName = data_state.now_map_name
	return self.allSetting[mapName].item or {}
end

function M:save_items(all_items)
	for mapName, value in pairs(all_items) do
		local obj = {}
		for k, v in pairs(value._items_data) do
			table.insert(obj, v)
		end
        if #obj > 0 then
		    if not self.allSetting[mapName] then
			    self.allSetting[mapName] = {}
		    end
		    self.allSetting[mapName].item = obj
        end
	end
end

function M:get_regions()
	local mapName = data_state.now_map_name
	return self.allSetting[mapName].region
end

function M:save_regions(all_regions)
	for key, value in pairs(all_regions) do
		if value ~= nil then
			self.allSetting[key].region = value
		end
	end
end

function M:get_block_vector()
	return self.allSetting[data_state.now_map_name].block_vector
end

function M:save_block_vector(all_vector)
	for key, value in pairs(all_vector) do
		if value ~= nil then
			self.allSetting[key].block_vector = value
		end
	end
end

function M:save_pos(map_name,obj)
	if not obj then
		perror("save pos error ! the obj is nil ! map_name : ", map_name)
		return 
	end
	self.allSetting[map_name].pos = obj.pos
	self.allSetting[map_name].yaw = obj.yaw
	self.allSetting[map_name].pitch = obj.pitch
end

function M:delete_map(map_name)
	self.allSetting[map_name] = nil
end

function M:get_pos(map_name)
	local setting = self.allSetting[map_name]
	if not setting then
		return false
	end
	local obj = {
		pos = setting.pos,
		yaw = setting.yaw,
		pitch = setting.pitch
	}
	return obj
end

function M:set_pos()
	--Player.CurPlayer:setPosition(self.all_setting[data_state.now_map_name].pos)
	local map_name = data_state.now_map_name
    local curMapSetting = self.allSetting[map_name] 
	Player.CurPlayer:setMove(0, curMapSetting.editorPos or curMapSetting.birthPos or curMapSetting.pos or World.cfg.initPos, self.allSetting[map_name].yaw, self.allSetting[map_name].pitch, 5,1)
end

function M:saveJson(path_item, content)
	Lib.saveGameJson(path_item, content)
end

function M:saveSkyBox(skyBox)
    for _, cfg in pairs(self.allSetting) do
        cfg.skyBox = skyBox
    end
end

function M:saveDynamicBrightness(brightness)
    for _, cfg in pairs(self.allSetting) do
        cfg.dynamicBrightness = brightness
    end
end

M:init()
return M