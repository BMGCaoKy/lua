local meta = {
	{
		type = "Action_RemoveTeamBuff",
		value = function(oval)
			local ret = Lib.copy(oval)

			local old_param = ret.components[1].params[2]
			old_param.value = ctor("T_BuffEntry")
			ret.components[1].params[2] = old_param

			return ret
		end
	},
	{
		type = "Action_AddEntityBuff",
		value = function(oval)
			local ret = Lib.copy(oval)

			local new_param = ctor("ActionParam", {key = "from", value = ctor("T_Entity"), must = false})
			table.insert(ret.components[1].params, 3, new_param)

			return ret
		end
	},
	{
		type = "BoundingVolume",
		value = function(oval)
			local ret = Lib.copy(oval)
			ret.size = { x = ret.params.x, y = ret.params.y, z = ret.params.z}
			ret.radius_c = ret.radius
			ret.height_c = ret.height
			return ret
		end
	},
	{
		type = "Instance_EffectPart",
		value = function(oval)
			local ret = Lib.copy(oval)
			ret.transform =  ctor("Transform3")
			ret.transform.pos = oval.transform.pos
			ret.transform.rotate = oval.transform.rotate
			return ret
		end
	},
	{
		type = "Instance_Spatial",
		value = function(oval)
			local ret = Lib.copy(oval)
			return ret
		end
	},
	{
		type = "GameCfg",
		value = function(oval)
			local ret = Lib.copy(oval)
			if ret.enableNewLighting == true then
				ret.glesMinorVersion = 0
				ret.glesVersion = 3
			end
			return ret
		end
	}
}

return {
	meta = meta
}