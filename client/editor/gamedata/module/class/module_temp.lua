local ModuleBase = require "editor.gamedata.module.class.module_base"
local Proto = require "editor.gamedata.proto"
local Def = require "editor.def"

local M = Lib.derive(ModuleBase)

function M:init()
	self._name = "temp"
	self._items = {}
end

function M:set_item_type(type)
	self._item_type = type
end

function M:on_new_item(id)
	Proto:notify(Def.PROTO_ITEM_NEW, self:name(), id)
	--Lib.emitEvent(Event.EVENT_EDITOR_ITEM_NEW, self:name(), id)
end

function M:on_del_item(id)
	Proto:notify(Def.PROTO_ITEM_DEL, self:name(), id)
	--Lib.emitEvent(Event.EVENT_EDITOR_ITEM_DEL, self:name(), id)
end

function M:load()
	assert(false)
end

function M:save()
	return
end

function M:copy_item()
	assert(false)
end


M:init()

return M