local Def = require "we.def"
local Signal = require "we.signal"
local Map = require "we.view.scene.map"
local Meta = require "we.gamedata.meta.meta"
local IScene = require "we.engine.engine_scene"
local Constraint = require "we.view.scene.logic.constraint"
local Base = require "we.view.scene.selector.selector_base"

local M = Lib.derive(Base)

function M:init()
	self._constraint_id = nil
end

function M:on_bind()

end

function M:on_unbind()

end

function M:select(constraint_id)
	self._constraint_id = constraint_id
end

function M:on_mouse_press(x, y, button)
	local instance = IScene:pick_point({ x = x, y = y }, Def.SCENE_NODE_TYPE.PART)
	if not instance then
		return
	end

	local master = Map:query_instance(instance)
	if not master then
		return
	end

	local constraint = Constraint:query_constraint_by_constraint_id(self._constraint_id)
	assert(constraint,string.format("data--%s",self._constraint_id))

	if master == constraint:slave() or master == constraint:master() then
		return
	end

	constraint:remove()

	local cons_vnode = Lib.copy(constraint:constraint():vnode())
	cons_vnode["selected"] = false
	cons_vnode["masterPartName"] = master:name()
	local cons = master:new_child(cons_vnode)
	local new_constraint = Constraint:new_constraint()
	new_constraint:set_master(master)
	new_constraint:set_constraint(cons)
	new_constraint:set_slave(constraint:slave())

	Signal:publish(self, self.SIGNAL.SELECT_FINISH)
end

function M:on_mouse_move(x, y)

end

function M:on_mouse_release(x, y, button, is_click)

end  

return M
