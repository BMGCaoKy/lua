local base = require "we.cmds.cmd_base"
local def = require "we.def"
local state = require "we.state"
local engine = require "we.engine"
local Module = require "we.gamedata.module.module"
local data_state = require "we.data_state"
local Map = require "we.map"
local VN = require "we.gamedata.vnode"

local M = Lib.derive(base)

function M:init(id)
	base.init(self)

	self._id = id
	self._obj = {}
end

function M:redo()
	base.redo(self)
	
	local m = Module:module("map")
	assert(m,"map")
	local item = m:item(Map:curr_map_name())
	local regions = item:obj().regions

	for i = 1, #regions do
		if regions[i].id == self._id then
			self._obj.region = regions[i]
			self._obj.index = i
			break
		end
	end

	--删除region对象
	item:data():remove("regions", self._obj.index)

	--删除region区域模板
	local module_region = Module:module("region")
	assert(module_region, "invalid value : module_region")
	local item = module_region:item(self._obj.region.cfg)
	self._obj.item_val = item:val()
	module_region:del_item(self._obj.region.cfg)

	state:set_focus(nil)
	engine:editor_obj_type("common")
	state:set_editmode(def.EMOVE)
	Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)

end

function M:undo()
	base.undo(self)

	local module_region = Module:module("region")
	assert(module_region, "invalid value : module_region")
	module_region:new_item(self._obj.region.cfg, self._obj.item_val)

	local m = Module:module("map")
	assert(m,"map")
	local item = m:item(Map:curr_map_name())

	local index = item:data():insert("regions", self._obj.index, nil, self._obj.region)

	local regions = item:obj().regions
	self._id = regions[index].id

	state:set_focus({id = self._id},def.TREGION)
	state:set_editmode(def.ESCALE)
	Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)
end

return M
