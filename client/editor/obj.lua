local engine = require "editor.engine"
local cjson = require "cjson"
local def = require "editor.def"
local data_state = require "editor.dataState"
local map_setting = require "editor.map_setting"
local M = {}


function M:init()
	self.all_regions = {}
end

local function is_in_region(k,regions)
	for key, value in pairs(regions) do
		if k == key then
			return true
		end
	end
	return false
end

local function load_region(self)
	if is_in_region(data_state.now_map_name,self.all_regions) == false or self.all_regions[data_state.now_map_name] == nil then
		--local content = Lib.readGameJson("map/"..data_state.now_map_name.."/setting.json").region
		local content = map_setting:get_regions()
		self.all_regions[data_state.now_map_name] =  content
	end
end

function M:load()
	load_region(self)
end

function M:save(path)
	map_setting:save_regions(self.all_regions)
end

local function get_id(self)
	--用#self._region获取长度总为0
	local count = 1
	local _name = ""
	local isSame = false
	while(true)
	do
		isSame = false
		_name = string.format("region_%.3d", count)
		for k,v in pairs(self.all_regions[data_state.now_map_name]) do
			if v.name == _name or self.all_regions[data_state.now_map_name][tostring(count)] then
				isSame = true
			end
		end
		if isSame then
			count = count + 1
		else
			break;
		end
	end
	
	return count
end

function M:add_region(pos_min, pos_max, _name)
	assert(pos_min.x <= pos_max.x and pos_min.y <= pos_max.y and pos_min.z <= pos_max.z)
	local id = nil
	local count = nil
	if not _name then
		count = get_id(self)
		id = tostring(count)
		_name = string.format("region_%.3d", count)
	end
	local obj = {
		name = _name,
		regionCfg = "",
		box = {
			min = pos_min,
			max = pos_max
		}
	}
	
	assert(not self.all_regions[data_state.now_map_name][id], id)
	self.all_regions[data_state.now_map_name][id] = obj

	engine:on_new_region(id, obj)
	
	return id
end

function M:get_region(id)
	return self.all_regions[data_state.now_map_name][id]
end

function M:get_present_region()
	return self.all_regions[data_state.now_map_name]
end

function M:set_region_name(id,name)
	self.all_regions[data_state.now_map_name][id].name = name

	engine:on_update_region_name(id,name)
end

function M:get_id_by_name(name)
	for k,v in pairs(self.all_regions[data_state.now_map_name]) do
		if v.name == name then
			return k
		end
	end
end

function M:get_cfg_by_name(name)
	for k,v in pairs(self.all_regions[data_state.now_map_name]) do
		if v.name == name then
			return v.regionCfg
		end
	end
end

function M:set_region_value(id,obj,is_send_update)
	local obj2 = {
		name = self.all_regions[data_state.now_map_name][id].name,
		regionCfg = obj.regionCfg,
		box = obj.box
	}
	self.all_regions[data_state.now_map_name][id] = obj2
	if is_send_update then
		engine:on_update_region(id,obj2)
	end
end

function M:set_region_box(id,min,max)
	self.all_regions[data_state.now_map_name][id].box.min = min
	self.all_regions[data_state.now_map_name][id].box.max = max
	local obj = {
		name = self.all_regions[data_state.now_map_name][id].name,
		regionCfg = self.all_regions[data_state.now_map_name][id].regionCfg,
		box = {
			min = min,
			max = max
		}
	}
	engine:on_update_region(id,obj)
end

function M:del_region(id)
	local region = self.all_regions[data_state.now_map_name][id]
	if region then
		engine:on_del_region(id)
		self.all_regions[data_state.now_map_name][id] = nil
	end
end

function M:get_allname_bycfg(cfg)
	local list = {}
	for k,v in pairs(self.all_regions[data_state.now_map_name]) do
		if v.regionCfg == cfg then
			list[k] = v.name
		end
	end

	return list
end

function M:delete_map(map_name)
	if is_in_region(map_name,self.all_regions) then
		self.all_regions[map_name] = nil
	end
end

function M:rename_map(_oldname,_newname)
	if is_in_region(_oldname,self.all_regions) then
		self.all_regions[_newname] = Lib.copy(self.all_regions[_oldname])
		self.all_regions[_oldname] = nil
	end
end

M:init()

return M
