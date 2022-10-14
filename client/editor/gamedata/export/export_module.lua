local Module = require "editor.gamedata.module.module"

local M = {}

function M:init()
	self._modules = {}

	Lib.subscribeEvent(Event.EVENT_EDITOR_MODULE_NEW, function(mn)
		local ok, ret = pcall(require, string.format("%s.export_%s", "editor.gamedata.export.module", mn))
		assert(ok, ret)

		local module = Module:module(mn)
		assert(module, mn)

		local item = Lib.derive(ret)
		item:init(module)

		self._modules[mn] = item
	end)
end

function M:sync()
	for _, module in pairs(self._modules) do
		module:sync()
	end
end

return M
