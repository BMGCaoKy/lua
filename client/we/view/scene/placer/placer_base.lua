local M = {}

function M:init(mode)
	self._mode = mode
end

function M:mode()
	return self._mode
end

function M:select(...)

end

function M:on_bind()

end

function M:on_unbind()

end

function M:reset()

end

function M:on_mouse_move(x, y)

end

function M:on_mouse_press(x, y, button)
	
end

function M:on_mouse_release(x, y, button, is_click)

end  

function M:on_key_press(key)

end

function M:on_key_release(key)

end

function M:on_Terrain(x, y)
	local Def = require "we.def"
	local IScene = require "we.engine.engine_scene"
	local node, type = IScene:pick_point({x = x, y = y}, Def.SCENE_NODE_TYPE.OBJECT)
	if type == nil then
		return false
	end
	return true
end

return M
