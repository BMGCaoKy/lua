local Module = require "we.gamedata.module.module"

local M = {}

function M:check_cfg()
	if not self._cfg then
		self._cfg = Module:module("game"):item("0"):obj()
	end
	return assert(self._cfg)
end

function M:get_batchType()
	return self:check_cfg().batchType
end

function M:get_useAnchor()
	return "Static" == self:get_batchType() or nil
end

return M
