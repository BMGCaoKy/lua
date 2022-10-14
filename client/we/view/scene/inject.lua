local ins_cls = require "we.view.scene.object.object_instance"
local utils = require "we.view.scene.utils"


local M = {}

-- example
--[[
	local inject = require "we.view.scene.inject"
	local IInstance = require "we.engine.engine_instance"

	local function updater(self, event, oval)
		IInstance:set(self._node, "mass2", tostring(self._vnode["mass2"]))
	end

	local function export(properties, val)
		properties["mass2"] = tostring(val.mass2)
	end

	local function import(val, properties)
		val.mass2 = tonumber(properties["mass2"])
	end

	inject:reg_prop("CSGShape", "mass2", updater, export, import)
]]

function M:reg_prop(class, name, updater, export, import)
	ins_cls.inject(name, updater)
	utils.inject(class, export, import)
end


return M
