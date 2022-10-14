local VN = require "we.gamedata.vnode"

local M = {}

function M:init(type, vnode)
	self._type = assert(type)
	self._vnode = assert(vnode)
	self._node = nil
end

function M:dtor()
	self._node = nil
end

function M:vnode()
	return self._vnode
end

function M:node()
	return self._node
end

function M:type()
	return self._type
end

function M:val()
	return VN.value(self._vnode)
end

function M:set(name, ...)

end

function M:get(name)

end

-- node can regard as id
function M:check(id)
	return false
end

function M:on_drag()

end

function M:on_drop()

end

return M
