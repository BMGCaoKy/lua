local Cjson = require "cjson"
local Core = require "editor.core"

return{
	request_sound_end_2d = function(id)
		Core.notify(Cjson.encode(
			{
				type = "SOUND_END_2D",
				params = {
					id = id
				}
			}
		))
	end
}