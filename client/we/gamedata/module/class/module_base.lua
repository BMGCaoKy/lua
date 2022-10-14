local Lfs = require "lfs"
local Core = require "editor.core"
local Def = require "we.def"
local Meta = require "we.gamedata.meta.meta"
local Lang = require "we.gamedata.lang"
local Mapping = require "we.gamedata.module.mapping"
local Engine = require "we.engine"
local Attr = require "we.gamedata.attr"
local Signal = require "we.signal"
local ModuleRequest = require "we.proto.request_module"
local Module = require "we.gamedata.module.module"

local M = {}

function M:init(name, item_type)
	self._name = name
	self._item_type = item_type
	self._items = {}
	assert(Meta:meta(item_type), item_type)
end

function M:create_item(id, rawval)
	assert(not self._items[id], id)

	local item_class = require(string.format("%s.module_%s.item_%s", "we.gamedata.module.class", self._name, self._name))
	local item = Lib.derive(item_class)
	item:init(id, self, rawval)

	local mt_item = getmetatable(item)
	assert(not mt_item.__gc)
	mt_item.__gc = function(item)
		item:release()
	end
	setmetatable(item, mt_item)
	self._items[id] = item
	return item
end

function M:preprocess()
	local list = self:check_valid_items()
	for _, id in ipairs(list) do
		local item = self:create_item(id)
		local ok, errmsg = xpcall(item.preprocess, debug.traceback, item)
		if not ok then
			print(string.format("load item error [%s]:%s\n%s", self:name(), id, errmsg))
			self._items[id] = nil
		end
	end
end

function M:list()
	return self._items
end

function M:name()
	return self._name
end

function M:item_type()
	return self._item_type
end

function M:item(id)
	return assert(self._items[id], string.format("item %s is not exist in module %s", id, self:name()))
end

-- 是否生成 mapping
function M:mapping()
	return false
end

-- 是否需要同步到引擎
function M:need_reload()
	return false
end

function M:check_valid_items()
	local ret = {}

	local dir = Lib.combinePath(Def.PATH_GAME, "plugin", Def.DEFAULT_PLUGIN, self:name())

	for item_name in Lfs.dir(dir) do
		if item_name ~= "." and item_name ~= ".."  and item_name ~= ".sheets" then
			local path = Lib.combinePath(dir, item_name)
			local attr = Lfs.attributes(path)
			if attr.mode == "directory" and not Def.filter[item_name] then
				table.insert(ret, item_name)
			end
		end
	end

	return ret
end

function M:copy_item_folder(id, newId)
	Lib.full_copy_folder(
		Lib.combinePath(Def.PATH_GAME, "plugin", Def.DEFAULT_PLUGIN, self:name(), id), 
		Lib.combinePath(Def.PATH_GAME, "plugin", Def.DEFAULT_PLUGIN, self:name(), newId))
end

function M:load()
	for _, item in pairs(self._items) do
		item:load()
	end
	for _, item in pairs(self._items) do
		item:obj()
	end
end

function M:save()
	for id, item in pairs(self._items) do
		if item:modified() then
			item:save()
			Lib.emitEvent(Event.EVENT_EDITOR_ITEM_SAVE, self:name(), id)
		end
	end
end

function M:modified()
	for id, item in pairs(self._items) do
		local _modified = item:modified()
		if _modified then
			return true
		end
	end
	return false
end

function M:new_item(id, rawval)
	local id = id or GenUuid()
	if self:mapping() then
		Mapping:register(self:name(), id)
	end

	local meta = Meta:meta(self._item_type)
	local val = meta:ctor(rawval)
	rawval = meta:diff(val) or {}
	
	local item = self:create_item(id, rawval)
	item:set_modified(true)

	item:save()
	self:on_item_new(id)

	Lib.emitEvent(Event.EVENT_EDITOR_ITEM_NEW, self:name(), id)
	ModuleRequest.request_item_new(self:name(), id)
	Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED, self:name(), id)
	
	item:reload()

	return item
end

function M:del_item_no_notice(id)
	local item = self._items[id]
	assert(item, string.format("delete invalid item %s: %s", self:name(), id))

	if self:mapping() then
		Mapping:unregister(self:name(), id)
	end
	self:on_item_del(id)
	item:discard()

	ModuleRequest.request_item_del(self:name(), id)
	Lib.emitEvent(Event.EVENT_EDITOR_ITEM_DEL, self:name(), id)
	--Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)

	self._items[id] = nil

	return item
end

function M:del_item(id)
	local item = self._items[id]
	assert(item, string.format("delete invalid item %s: %s", self:name(), id))

	if self:mapping() then
		Mapping:unregister(self:name(), id)
	end
	self:on_item_del(id)
	item:discard()

	ModuleRequest.request_item_del(self:name(), id)
	Lib.emitEvent(Event.EVENT_EDITOR_ITEM_DEL, self:name(), id)
	Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)

	self._items[id] = nil

	return item
end

function M:unload_item(id)
	ModuleRequest.request_item_del(self:name(), id)
	self._items[id] = nil
end

function M:copy_item(id, newId)
	local item = self:item(id)
	assert(item)
	local rawval = item:val()  --item:obj()

	--[
	-- trigger like Trigger_RegisterClientProto and Trigger_RegisterServerProto need new its item
	-- 大量复制时如果影响场景效率,考虑将blue_protocol优化成不作为moudle处理或者不复制blue_protocol了
	local register_obj_trigger_proto
	register_obj_trigger_proto = function(obj)
		if obj["triggers"] then
			local triggers = obj["triggers"]["list"]
			for key,v in pairs(triggers) do
				if v.type == "Trigger_RegisterClientProto" or v.type == "Trigger_RegisterServerProto"  then
					local id = v.proto_uuid
					local module = Module:module("blue_protocol")
					local id_new = GenUuid()
					local item_new = module:copy_item(id,id_new)
					item_new:obj().save = true
					obj["triggers"]["list"][key].proto_uuid = id_new
					obj["triggers"]["list"][key].func_name = item_new:obj().name
				end
			end
		end
    end

	register_obj_trigger_proto(rawval)
	--]]
	do
		Meta:meta("Text"):set_processor(function(val)
			local key = self:name() .. '_' .. newId
			Lang:copy_text(val.value, key)
			return { value = key }
		end)
		local meta = Meta:meta(self._item_type)
		rawval = meta:process(rawval)
		Meta:meta("Text"):set_processor(nil)
	end
	--Component item and region need copy folder
	self:copy_item_folder(id, newId)

	return self:new_item(newId, rawval)
end

function M:on_item_new(id)

end

function M:on_item_del(id)

end

return M
