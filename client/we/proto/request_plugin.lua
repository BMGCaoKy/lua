local Cjson = require "cjson"
local Core = require "editor.core"

return {
	request_insert = function(type, params)
		local ret = Core.notify(Cjson.encode(
			{
				type = "PLUGIN_INSERT",
				params = {
					type = type,
					params = params
				}
			}
		))
		ret = Cjson.decode(ret)
		return ret.ok and ret.id
	end,

	request_remove = function(id)
		local ret = Core.notify(Cjson.encode(
			{
				type = "PLUGIN_REMOVE",
				params = {
					id = id
				}
			}
		))
		ret = Cjson.decode(ret)
		return ret.ok
	end
}
