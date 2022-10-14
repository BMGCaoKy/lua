local engine = require "we.engine"
local base = require "we.cmds.cmd_base"
local def = require "we.def"
local state = require "we.state"
local Module = require "we.gamedata.module.module"
local data_state = require "we.data_state"
local Map = require "we.map"

local M = Lib.derive(base)

function M:init(min, max, cfg)
	base.init(self)

	self._min = min
	self._max = max
	self._index = nil
	self._cfg = cfg
	self._item_value = nil
end

function M:redo()
	base.redo(self)

	local module_region = Module:module("region")
	assert(module_region, "invalid value : module_region")
	module_region:new_item(self._cfg, self._item_value)

	local m = Module:module("map")
	assert(m,"map")
	local item = m:item(Map:curr_map_name())
	assert(item)
	local obj = {
		id = self._cfg,
		name = {value = "region_" .. self._cfg},
		cfg = self._cfg,
		min = self._min,
		max = self._max
	}

	self._index = item:data():insert("regions",nil,nil,obj)

	local obj = {
		id = self._cfg
	}
	state:set_focus(obj,def.TREGION)
	Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)
end

function M:undo()
	base.undo(self)

	--obj:del_region(self._name)
	local m = Module:module("map")
	assert(m,"map")
	local item = m:item(Map:curr_map_name())
	item:data():remove("regions",self._index)

	state:set_focus(nil)
	local obj = Lib.boxOne()
	state:set_brush(obj,def.TREGION)

	local module_region = Module:module("region")
	assert(module_region, "invalid value : module_region")
	local value_node = module_region:del_item(self._cfg)
	--记录被删除的信息，回推时以便复原.
	self._item_value = value_node:val()
	Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)
end

return M
