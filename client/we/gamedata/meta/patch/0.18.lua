local Def = require "we.def"
local Lang = require "we.gamedata.lang"
local lfs = require "lfs"

local meta = {
	{
		type = "Instance_Decal",
		value = function(oval)
			local ret = Lib.copy(oval)

			local core = require "editor.core"
			local id = core:gen_instance_id()

			ret.id = tostring(id)

			return ret
		end
	},
	{
		type = "Action_GetObjectDistance",
		value = function(oval)
			local ret = Lib.copy(oval)

			local value_node = ret.components[1].params[1].value
			local action = value_node.action
			value_node = ctor("T_Entity")
			value_node.action = action
			ret.components[1].params[1].value = value_node

			value_node = ret.components[1].params[2].value
			action = value_node.action
			value_node = ctor("T_Entity")
			value_node.action = action
			ret.components[1].params[2].value = value_node

			return ret
		end
	},
	{
		type = "Action_GetObjectID",
		value = function(oval)
			local ret = Lib.copy(oval)

			local value_node = ret.components[1].params[1].value
			local action = value_node.action
			value_node = ctor("T_Entity")
			value_node.action = action
			ret.components[1].params[1].value = value_node

			return ret
		end
	},
	{
		--改返回值
		type = "Action_GetObject",
		value = function(oval)
			local ret = Lib.copy(oval)

			ret.type = "T_Entity"

			return ret
		end
	},
	{
		type = "Action_IsValidObject",
		value = function(oval)
			local ret = Lib.copy(oval)

			local value_node = ret.components[1].params[1].value
			local action = value_node.action
			value_node = ctor("T_Entity")
			value_node.action = action
			ret.components[1].params[1].value = value_node

			return ret
		end
	},
	{
		type = "EntityCfg",
		value = function(oval)
			local ret = Lib.copy(oval)

			ret.actorModel = ctor("ActorModel",{modelType = "Customize"})
			ret.actorModel.actorName = ret.actorName
			ret.actorModel.girlactor = ret.girlactor

			return ret
		end
	}
}

return {
	meta = meta
}