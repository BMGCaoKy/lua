local M = {}

M.SIGNAL = {
	BOUND_BOX_CHANGED		= "BOUND_BOX_CHANGED",
	ABILITY_CHANGE			= "ABILITY_CHANGE",	-- ability maybe change, need check
	ANCHOR_CHANGE			= "ANCHOR_CHANGE",
}

function M:init(type)
	self._type = type
end

function M:type()
	return self._type
end

function M:ephemerid()
	return false
end

function M:accept(type)
	return false
end

function M:attach(...)

end

function M:detach(...)

end

function M:clear()

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

function M:check_op(op, ...)
	return false
end

function M:exec_op(op, ...)

end

function M:rotation()

end

function M:bound()

end

function M:update()

end

-- 中点
function M:center()
	local bound = self:bound()
	if not bound then
		return
	end

	return {
		x = (bound.max.x + bound.min.x) / 2,
		y = (bound.max.y + bound.min.y) / 2,
		z = (bound.max.z + bound.min.z) / 2,
	}
end

function M:gizmo_center()
	return self:center()
end


function M:need_upright()
	return false
end

function M:on_drag()

end

function M:on_drop()

end

return M
