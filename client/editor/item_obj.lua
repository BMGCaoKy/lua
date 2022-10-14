require "common.world"
require "item.dropitem"
local cjson = require "cjson"
local engine = require "editor.engine"
local data_state = require "editor.dataState"
local map_setting = require "editor.map_setting"
local M = {}

function M:init()
	self.all_items = {}
	self.now_map_name = nil
end

local function is_in_items(k, items)
	for key, value in pairs(items) do
		if k == key then
			return true
		end
	end
	return false
end

local function destroy_all_item(self)
	if is_in_items(self.now_map_name,self.all_items) and self.now_map_name ~= nil then
		if next(self.all_items[self.now_map_name]._items) ~= nil then
			for _, item_obj in pairs(self.all_items[self.now_map_name]._items) do
				item_obj:destroy()
			end
			self.all_items[self.now_map_name]._items = {}
		end
	end
end

local function create_all_item(self)
	local world = World.CurWorld
	local item_data = self.all_items[data_state.now_map_name]._items_data
	local world = World.CurWorld
	for key, obj in pairs(item_data) do
		local item = Item.CreateItem(obj.cfg, 1, obj.cfg == "/block" and function(itemData)
			itemData:set_block_id(tonumber(obj.blockID))
		end)
		self.all_items[data_state.now_map_name]._items[key] = DropItemClient.Create(world:nextLocalID(), obj.pos, item)
	end
end

local function load_item(self)
	local world = World.CurWorld
	destroy_all_item(self)
	self.now_map_name = data_state.now_map_name
	if is_in_items(data_state.now_map_name,self.all_items) == false or self.all_items[data_state.now_map_name] == nil then
		local _items = {}
		local _items_data = {}
		local len = 0

		local content = map_setting:get_items()

		for i=1,#content do
			local blockID = content[i]["blockID"]
			local obj = {
				pos = content[i]["pos"],
				cfg = content[i]["cfg"],
				ry = content[i]["ry"],
				blockID = blockID,
			}
			_items_data[tostring(i)] = obj
			local item
			if blockID then
				item = Item.CreateItem(obj.cfg, 1, function(item_data)
					item_data:set_block_id(tonumber(blockID))
				end)
			else
				item = Item.CreateItem(obj.cfg, 1)
			end
			_items[tostring(i)] = DropItemClient.Create(world:nextLocalID(), obj.pos, item)
			local itemCfg
			if item:is_block() then
				itemCfg = item:block_cfg()
			else
				itemCfg = item:cfg()
			end
            if itemCfg.showBoundBox then
                _items[tostring(i)]:setRenderBox(true)
                local color = itemCfg.boundBoxColor
                _items[tostring(i)]:setRenderBoxColor(color and {color[1], color[2], color[3], color[4]} or {1, 1, 1, 1})
            end
		end
	
		len = #content
		local item_table = {
			_items = _items,
			_items_data = _items_data,
			len = len
		}
		self.all_items[data_state.now_map_name] = item_table
	else
		create_all_item(self)
	end
end

function M:load()
    World.Timer(15, load_item, self)
end

function M:save(path)
	if self.all_items then
		map_setting:save_items(self.all_items)
	end
end

function M:add_item(pos, cfg, blockID)
	local item 
	if blockID then
		item = Item.CreateItem(cfg, 1, function(item_data)
			item_data:set_block_id(tonumber(blockID))
		end)
	else
		item = Item.CreateItem(cfg, 1)
	end
	local world = World.CurWorld
	pos.y = pos.y
	local item_object = DropItemClient.Create(world:nextLocalID(), pos, item)
	local len = self.all_items[data_state.now_map_name].len
	len = len + 1
	self.all_items[data_state.now_map_name].len = len
	local obj = {
		pos = pos,
		ry = 0,
		pitch = 0,
		cfg = cfg,
		blockID = blockID
	}
	self.all_items[data_state.now_map_name]._items_data[tostring(len)] = obj
	self.all_items[data_state.now_map_name]._items[tostring(len)] = item_object
	local itemCfg
	if item:is_block() then
		itemCfg = item:block_cfg()
	else
		itemCfg = item:cfg()
	end

    if itemCfg.showBoundBox then
        item_object:setRenderBox(true)
        local color = itemCfg.boundBoxColor
        item_object:setRenderBoxColor(color and {color[1], color[2], color[3], color[4]} or {1, 1, 1, 1})
    end
	return self.all_items[data_state.now_map_name].len
end

function M:delete_item(id)
	if self.all_items[data_state.now_map_name]._items_data[tostring(id)] and self.all_items[data_state.now_map_name]._items_data[tostring(id)] then
		self.all_items[data_state.now_map_name]._items[tostring(id)]:destroy()
		self.all_items[data_state.now_map_name]._items_data[tostring(id)] = nil
		self.all_items[data_state.now_map_name]._items[tostring(id)] = nil
	end
end

function M:get_cfg_byid(id)
	local cfg = self.all_items[data_state.now_map_name]._items_data[id].cfg
	return cfg
end

function M:get_pos_byid(id)
	local pos = nil
	if is_in_items(id,self.all_items[data_state.now_map_name]._items_data) then
		pos = self.all_items[data_state.now_map_name]._items_data[id].pos
	end
	return pos
end

function M:get_present_item()
	return self.all_items[data_state.now_map_name]._items_data
end

function M:get_item_by_id(id)
	return self.all_items[data_state.now_map_name]._items[id]
end

function M:set_pos_byid(id,data,is_send_update)
	self.all_items[data_state.now_map_name]._items[id]:setPos(data.pos,data.ry)
	
	self.all_items[data_state.now_map_name]._items[id]:setBodyYaw(data.ry)

	self.all_items[data_state.now_map_name]._items_data[id].pos = data.pos
	self.all_items[data_state.now_map_name]._items_data[id].ry = self.all_items[data_state.now_map_name]._items[id]:getRotationYaw()


	if is_send_update then
		--engine:on_update_item(id,data.pos,data.ry,data.pitch)
	end
	
end

function M:get_id_by_itemobj(item)
	for k,v in pairs(self.all_items[data_state.now_map_name]._items) do
		if item.objID == v.objID then
			return k
		end
	end
	return nil
end

function M:get_yaw_byid(id)
	local ry = self.all_items[data_state.now_map_name]._items_data[id].ry
	return ry
end

function M:get_pitch_byid(id)
	local pitch = self.all_items[data_state.now_map_name]._items_data[id].pitch
	return pitch
end

function M:delete_map(map_name)
	local allItems = self.all_items
	if not allItems then
		return
	end
	local items = allItems[data_state.now_map_name]
	if items then
		items = nil
	end
end

function M:rename_map(_oldname,_newname)
	if is_in_items(_oldname,self.all_items) then
		self.all_items[_newname] = Lib.copy(self.all_items[_oldname])
		self.all_items[_oldname] = nil
	end
end

M:init()

return M