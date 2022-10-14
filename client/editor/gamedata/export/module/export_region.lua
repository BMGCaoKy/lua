local Seri = require "editor.gamedata.seri"
local Base = require "editor.gamedata.export.module.export_base"

local M = Lib.derive(Base)

local MODULE_DIR = Lib.combinePath(Root.Instance():getGamePath(), "plugin/myplugin/region/")

local item_class = {
	init = function(self, module, item)
		self._module = module
		self._item = module:item(item)
	end,

	seri = function(self, dump)
		local item = self._item:val()
		-- json
		do	
			local data = {}

			local path = Lib.combinePath(MODULE_DIR, self._item:id(), "setting.json")
			Seri("json", data, path, dump)
		end
		-- bts
		do
			local data = item.triggers
			local path = Lib.combinePath(MODULE_DIR, self._item:id(), "triggers.bts")
			Seri("bts", data, path, dump)
		end
	end,
}

function M:init(module)
	Base.init(self, module, item_class)
end

return M
