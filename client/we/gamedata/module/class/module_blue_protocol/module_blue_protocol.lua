local ModuleBase = require "we.gamedata.module.class.module_base"
local Meta = require "we.gamedata.meta.meta"
local Def = require "we.def"
local Lfs = require "lfs"

local M = Lib.derive(ModuleBase)

local MODULE_NAME = "blue_protocol"
local ITEM_TYPE = "BlueProtocolCfg"

function M:init(name)
	assert(name == MODULE_NAME, 
		string.format("[ERROR] module name not match %s:%s", MODULE_NAME, name)
	)

	ModuleBase.init(self, MODULE_NAME, ITEM_TYPE)
	self._names_dirty = true
	self._names = {}
end

function M:get_unrepeatable_name(name)
	if self._names_dirty then
		self._names = {}
		for _,v in pairs(self._items) do
			self._names[v:obj().name] = true
		end
	end

	local count = 1
	local name_orign = name
	while self._names[name] do
		name = name_orign.."_"..tostring(count)
		count = count + 1
	end
	self._names[name] = true
	return name
end

function M:copy_item(id, newId)
	local item = self:item(id)
	assert(item)
	local rawval = item:val()  --item:obj()
	rawval.id.value = newId
	rawval.name = self:get_unrepeatable_name(rawval.name)
	rawval.save = false

	do
		Meta:meta("Text"):set_processor(function(val)
			local key = Lang:copy_text(val.value)
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

function M:set_name_dirty(flag)
	-- body
	self._names_dirty = flag
end

function M:check_valid_items()
	local ret = {}

	local dir = Lib.combinePath(Def.PATH_GAME_META_DIR, "module", self:name(),"item")

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

return M