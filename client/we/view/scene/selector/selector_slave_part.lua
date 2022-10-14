local Def = require "we.def"
local Signal = require "we.signal"
local Map = require "we.view.scene.map"
local IScene = require "we.engine.engine_scene"
local Constraint = require "we.view.scene.logic.constraint"
local IInstance = require "we.engine.engine_instance"
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

	local slave = Map:query_instance(instance)
	if not slave then
		return
	end

	local constraint = Constraint:query_constraint_by_constraint_id(self._constraint_id)
	assert(constraint,string.format("data--%s",self._constraint_id))

	if slave == constraint:slave() or slave == constraint:master() then
		return
	end

	if constraint:slave() then
		constraint:slave():recover_translucence()
	end
	local id = tostring(IInstance:id(instance))
	constraint:constraint():set_slave_part_id(id)
	constraint:constraint():set_slave_part_name(slave:name())
	constraint:set_slave(slave)
	constraint:slave():set_translucence()
	Signal:publish(self, self.SIGNAL.SELECT_FINISH)
end

return M