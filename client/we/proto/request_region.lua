local Engine = require "we.engine"
local Cjson = require "cjson"

return {
	request_new_region = function()
		local paramsjson = Cjson.encode({
			type = "REQUEST_NEW_REGION"
		})
		local ok, id = Engine:request(paramsjson)
		return ok, id
	end
}
