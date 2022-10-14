local Def = require "we.def"
local Signal = require "we.signal"
local Map = require "we.view.scene.map"
local State = require "we.view.scene.state"
local IScene = require "we.engine.engine_scene"
local IInstance = require "we.engine.engine_instance"
local SceneRegion = require "we.view.scene.logic.scene_region"

local Base = require "we.view.scene.receptor.receptor_base"
local M = Lib.derive(Base)

function M:init(type)
	Base.init(self, "scene_region")
	self._region = nil
	self._scaling = false
end

function M:ephemerid()
	return true
end

function M:accept(type)
	return type == Def.SCENE_NODE_TYPE.INSTANCE
end

function M:on_unbind()
	SceneRegion:delete()
	SceneRegion:cancel()
	self._region = nil
	Signal:publish(self, M.SIGNAL.BOUND_BOX_CHANGED)
end

function M:center()
	if self._region then
		return IScene:parts_center({self._region})
	end
end

local op_checker = {
	SCALE = function(self)
		return self._region ~= nil
	end,

	CONFIRM = function(self)
		return self._scaling
	end
}

local op_executer = {
	SCALE = function(self, aix, offset, stretch)
		if not self._region then
			return
		end

		local box = IScene:parts_aabb({self._region})
		if not box then
			return
		end

		local aix = aix == 1 and "x" or aix == 2 and "y" or "z"
		local dist = (offset.x ^ 2 + offset.y ^ 2 + offset.z ^ 2) ^ 0.5
		local diff = stretch and (2 * dist) or (- 2 * dist)

		local size = IInstance:size(self._region)[aix] + diff
		if size <= 0.1 then
			return
		end

		if aix == "x" then
			IInstance:set_size_x(self._region, size)
		elseif aix == "y" then
			IInstance:set_size_y(self._region, size)
		else
			IInstance:set_size_z(self._region, size)
		end
		IScene:move_parts({self._region}, offset)

		self._scaling = true
	end,

	CONFIRM = function(self, ok)
		if ok then
			local pos = IInstance:position(self._region)
			local size = IInstance:size(self._region)

			local min = {
				x = math.ceil (pos.x - (size.x / 2)),
				y = math.ceil (pos.y - (size.y / 2)),
				z = math.ceil (pos.z - (size.z / 2))
			}

			local max = {
				x = math.ceil (pos.x + (size.x / 2)),
				y = math.ceil (pos.y + (size.y / 2)),
				z = math.ceil (pos.z + (size.z / 2))
			}
			SceneRegion:change_data(min, max)
		end
		self:detach()
		self._scaling = false
	end
}

function M:check_op(op, ...)
	local proc = op_checker[string.upper(op)]
	if proc then
		return proc(self, op, ...)
	end

	return op_executer[string.upper(op)] ~= nil
end

function M:exec_op(op, ...)
	local proc = op_executer[string.upper(op)]
	assert(proc, string.format("op [%s] is not support", op))

	return proc(self, ...)
end

function M:attach(region, xor)
	self._region = region
	Signal:publish(self, M.SIGNAL.BOUND_BOX_CHANGED)
end

function M:detach(region)
	SceneRegion:delete()
	SceneRegion:finish()
	self._region = nil
	Signal:publish(self, M.SIGNAL.BOUND_BOX_CHANGED)
end

return M