local engine = require "editor.engine"
local cjson = require "cjson"
local def = require "editor.def"
local data_state = require "editor.dataState"
local map_setting = require "editor.map_setting"
local M = {}


function M:init()
	self.allBlockVector = {}
end

local function isInBlockVector(k,blockVector)
	for key, value in pairs(blockVector) do
		if k == key then
			return true
		end
	end
	return false
end

local function get_id(pos)

    return string.format("%d,%d,%d", pos.x, pos.y, pos.z)
end

local function get_pos_by_id(id)
	local posList = Lib.splitString(id, ",")
	
	return Lib.v3(tonumber(posList[1]), tonumber(posList[2]), tonumber(posList[3]))
end

local function clearAllHeadEntity(self)
	for k, v in pairs(self.entity or {}) do
		v:destroy()
	end
end

local function loadHeadText(self)
	clearAllHeadEntity(self)
	local allBlockVector = self.allBlockVector[data_state.now_map_name]
	for id, content in pairs(allBlockVector or {}) do
		local pos = get_pos_by_id(id)
		self:set_head_text(pos, id, content)
	end
end

local function loadBlockVector(self)
	if isInBlockVector(data_state.now_map_name,self.allBlockVector) == false or self.allBlockVector[data_state.now_map_name] == nil then
		local content = map_setting:get_block_vector()
		self.allBlockVector[data_state.now_map_name] =  content or {}
	end
	loadHeadText(self)
end

function M:load()
	loadBlockVector(self)
end

function M:save(path)
	map_setting:save_block_vector(self.allBlockVector)
end


function M:add_block_vector(pos)
	local obj = {
        icon_type_id = 1,
	}
	local id = get_id(pos)
	self.allBlockVector[data_state.now_map_name][id] = obj
	return id
end

function M:get_block_vector(pos)
	if not pos or type(pos) ~= "table" then
		return nil
	end
	local id = get_id(pos)

	return self.allBlockVector[data_state.now_map_name][id]
end

function M:set_head_text(pos, key, obj)
	local temp

	if not self.entity then
		self.entity = {}
	end
	if self.entity[key] then
		temp = self.entity[key]
	else
		pos.x = pos.x + 0.5
		pos.y = pos.y - 1.5
		pos.z = pos.z + 0.5
		temp = EntityClient.CreateClientEntity({cfgName="myplugin/door_entity", pos=pos, name = ""})
		self.entity[key] = temp
	end
	if obj.fullName then
		temp:setHeadText(-2, 0, "[P=plugin/myplugin/item/propGold/vectorBlockTip.png]")
	else
		temp:setHeadText(-2, 0, "[P=plugin/myplugin/entity/startpoint/wenhao_tip.png]")
	end
	temp:data("headText").svrAry = temp:data("headText").ary
	temp:updateShowName()
end

function M:set_block_vector_value(pos,obj)
	local id = get_id(pos)
	local obj2 = {}
	if not obj then
		self.allBlockVector[data_state.now_map_name][id] = nil
	end
	for k, v in pairs(obj or {}) do
		obj2[k] = v
	end
	
	self.allBlockVector[data_state.now_map_name][id] = obj2
	self:set_head_text(pos, id, obj2)
end

function M:del_block_vector(pos)

	if not pos or type(pos) ~= "table" then
		return
	end

	local id = get_id(pos)
	local blockVector = self.allBlockVector[data_state.now_map_name][id]
	if blockVector then
		self.allBlockVector[data_state.now_map_name][id] = nil
		self.entity[id]:destroy()
		self.entity[id] = nil
	end
end

function M:delete_map(map_name)
	if isInBlockVector(map_name,self.allBlockVector) then

		self.allBlockVector[map_name] = nil
	end
end

function M:rename_map(_oldname,_newname)
	if isInBlockVector(_oldname,self.allBlockVector) then
		self.allBlockVector[_newname] = Lib.copy(self.allBlockVector[_oldname])
		self.allBlockVector[_oldname] = nil
	end
end

M:init()

return M
