local Def = require "we.def"
local Lang = require "we.gamedata.lang"
local lfs = require "lfs"
local Cjson = require "cjson"
local Engine = require "we.engine"

local meta = {
	{
		type = "EntityCfg",
		value = function(oval)
			local ret = Lib.copy(oval)
			--不需要升级内容，只需要触发导入就行了
			return ret
		end
	},
	{
		type = "ActionPlaybackSpeed",
		value = function(oval)
			local ret = Lib.copy(oval)

			ret.PlaySpeed = ctor("number")
			ret.PlaySpeed = tonumber(oval.PlaySpeed)

			return ret
		end
	},
	{
		type = "T_StorageEntry",
		value = function(oval)
			local ret = Lib.copy(oval)
			local value_node = ctor("StorageEntry")
			value_node.name = oval.rawval
			value_node.id = oval.rawval
			ret.rawval = value_node
			return ret
		end
	},
	{
		type = "GameCfg",
		value = function(oval)
			local ret = Lib.copy(oval)

			--modify filename by login server G/S
			do
				local json = Engine:get_login_server_type()
				local data = Cjson.decode(json)
				if data and data.ok then
					local old = Lib.combinePath(Def.PATH_GAME, "tools", "game_res_config.txt")
					local new = Lib.combinePath(Def.PATH_GAME, "tools", string.format("game_res_config_%s.txt", data.serverType))
					if not Lib.fileExists(new) and Lib.fileExists(old) then
						os.rename(old, new)
					end
				end
			end

			return ret
		end
	},
	{
		type = "Action_ArraySet",
		value = function(oval)
			local ret = Lib.copy(oval)
			local old = oval.components[1].params[5]
			ret.components[1].params[5] = {key = "rootInstance", value = ctor("T_Layout"), must = true}
			ret.components[1].params[6] = old
			return ret
		end
	},
	{
		type = "Action_ArrayAppend",
		value = function(oval)
			local ret = Lib.copy(oval)
			local old = oval.components[1].params[4]
			ret.components[1].params[4] = {key = "rootInstance", value = ctor("T_Layout"), must = true}
			ret.components[1].params[5] = old
			return ret
		end
	},
	{
		type = "Action_ArrayInsert",
		value = function(oval)
			local ret = Lib.copy(oval)
			local old = oval.components[1].params[5]
			ret.components[1].params[5] = {key = "rootInstance", value = ctor("T_Layout"), must = true}
			ret.components[1].params[6] = old
			return ret
		end
	},
	{
		type = "Action_ArrayRemove",
		value = function(oval)
			local ret = Lib.copy(oval)
			ret.components[1].params[5] = {key = "rootInstance", value = ctor("T_Layout"), must = true}
			return ret
		end
	},
	{
		type = "Action_NewArrayGet",
		value = function(oval)
			local ret = Lib.copy(oval)
			ret.components[1].params[5] = {key = "rootInstance", value = ctor("T_Layout"), must = true}
			return ret
		end
	},
	{
		type = "Action_NewArraySize",
		value = function(oval)
			local ret = Lib.copy(oval)
			ret.components[1].params[4] = {key = "rootInstance", value = ctor("T_Layout"), must = true}
			return ret
		end
	},
	{
		type = "Action_ArrayFind",
		value = function(oval)
			local ret = Lib.copy(oval)
			local old = oval.components[1].params[4]
			ret.components[1].params[4] = {key = "rootInstance", value = ctor("T_Layout"), must = true}
			ret.components[1].params[5] = old
			return ret
		end
	},
	{
		type = "Action_ArrayIsHasValue",
		value = function(oval)
			local ret = Lib.copy(oval)
			local old = oval.components[1].params[4]
			ret.components[1].params[4] = {key = "rootInstance", value = ctor("T_Layout"), must = true}
			ret.components[1].params[5] = old
			return ret
		end
	}
}
--ret.components[1].params[2] = {key = "left", value = ctor("T_Bool", {action = a1}), must = true}
return {
	meta = meta
}
