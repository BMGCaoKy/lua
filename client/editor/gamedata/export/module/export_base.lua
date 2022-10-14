local Def = require "editor.def"
local Engine = require "editor.engine"
local Mapping = require "editor.gamedata.module.mapping"

local M = {}

function M:init(module, item_class)
	self._module = assert(module)
	self._item_class = item_class

	Lib.subscribeEvent(Event.EVENT_EDITOR_MODULE_LOADED, function(module)
		if self._module:name() ~= module then
			return
		end

		if not self._module:need_reload() then
			return
		end

		local list = self._module:list()
		for id, item in pairs(list) do
			local obj = Lib.derive(item_class)
			obj:init(self._module, item:id())
			obj:seri()
		end
	end)

	Lib.subscribeEvent(Event.EVENT_EDITOR_MODULE_DUMP, function(module, item)
		if self._module:name() ~= module then
			return
		end

		local list = self._module:list()
		for id, item in pairs(list) do
			local obj = Lib.derive(item_class)
			obj:init(self._module, item:id())
			obj:seri(true)
		end
	end)

	Lib.subscribeEvent(Event.EVENT_EDITOR_ITEM_NEW, function(module, item)
		if self._module:name() ~= module then
			return
		end

		if self._module:mapping() then
			Mapping:register(module, item)
		end

		local obj = Lib.derive(item_class)
		obj:init(self._module, item)
		obj:seri()

		if self._module:need_reload() then
			Engine:reload_item(Def.DEFAULT_PLUGIN, module, item)
		end
	end)

	Lib.subscribeEvent(Event.EVENT_EDITOR_ITEM_DEL, function(module, item)
		if self._module:name() ~= module then
			return
		end

		-- todo

		if self._module:mapping() then
			Mapping:remove(module, item)
		end
	end)

	Lib.subscribeEvent(Event.EVENT_EDITOR_ITEM_MODIFY, function(module, item, reload)
		if self._module:name() ~= module then
			return
		end

		if not self._module:need_reload() then
			return
		end

		if not reload then
			return
		end

		local obj = Lib.derive(item_class)
		obj:init(self._module, item)
		obj:seri()

		Engine:reload_item(Def.DEFAULT_PLUGIN, module, item)
	end)
end

function M:sync()
	local list = self._module:list()
	for id, item in pairs(list) do
		local obj = Lib.derive(self._item_class)
		obj:init(self._module, item:id())
		obj:seri()
	end
end

return M
