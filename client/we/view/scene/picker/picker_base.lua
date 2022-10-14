local M = {}

function M:init(mode)
	self._mode = mode
end

function M:mode()
	return self._mode
end

function M:on_bind()

end

function M:on_unbind()

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

function M:on_lost_focus()

end

function M:reset()

end

function M:ephemerid()
	return false
end

return M
