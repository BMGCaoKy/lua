local Receptor = require "we.view.scene.receptor.receptor"

local M = {}

function M:init(vnode)
	self._vnode = assert(vnode)
	self._code = assert(self._vnode["code"])
end

function M:set_enable(enable)
	self._vnode["enable"] = enable
end

function M:check(receptor, ...)
	if not receptor then
		return false
	end

	return receptor:check_op(self._code, ...)
end

function M:exec(receptor, ...)
	if not receptor then
		return
	end

	return receptor:exec_op(self._code, ...)	
end

return M
