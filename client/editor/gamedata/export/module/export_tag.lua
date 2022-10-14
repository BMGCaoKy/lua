local Seri = require "editor.gamedata.seri"
local Base = require "editor.gamedata.export.module.export_base"

local M = Lib.derive(Base)

local MODULE_DIR = Lib.combinePath(Root.Instance():getGamePath(), "plugin/myplugin/tag/")

local item_class = {
	init = function(self, module, item)
		self._module = module
		self._item = module:item(item)
	end,

	seri = function(self, dump)
		
	end,
}

function M:init(module)
	Base.init(self, module, item_class)
end

return M
