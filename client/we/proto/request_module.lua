local Cjson = require "cjson"
local Core = require "editor.core"
local Def = require "we.def"

return {
	request_item_new = function(module, item)
		Core.notify(Cjson.encode(
			{
				type = Def.PROTO.ITEM_NEW,
				params = {
					module = module,
					item = item
				}
			}
		))
	end,

	request_item_del = function(module, item)
		Core.notify(Cjson.encode(
			{
				type = Def.PROTO.ITEM_DEL,
				params = {
					module = module,
					item = item
				}
			}
		))
	end,

	request_item_error = function(error_code, file_path)
		Core.notify(Cjson.encode(
			{
				type = "REQUEST_ITEM_ERROR",
				params = {
					error_code = error_code,
					file_path = file_path
				}
			}
		))
	end
}
