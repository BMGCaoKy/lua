local M = {}

function M:init()

end

function M:create(name, vnode, ...)
	local class = require(string.format("%s.object_%s", "we.view.scene.object", string.lower(name)))
	assert(class, string.format("class %s is not exist", name))

	local obj = Lib.derive(class)
	obj:init(vnode, ...)

	return obj
end

return M
