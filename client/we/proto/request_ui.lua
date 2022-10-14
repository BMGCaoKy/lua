local Cjson = require "cjson"
local Core = require "editor.core"

return {
	request_sync_widget_rect = function(id,pos,size)
		Core.notify(Cjson.encode(
			{
				type = "SYNC_WIDGET_RECT",
				params = {
					id = id,
					pos = pos,
					size = size
				}
			}
		))
	end,

	request_add_widgets = function(id_list)
		Core.notify(Cjson.encode(
			{
				type = "ADD_WIDGETS",
				params = {
					id_list = id_list
				}
			}
		))
	end,

	request_get_image_size = function(asset)
		local size_str = Core.notify(Cjson.encode(
			{
				type = "GET_IMAGE_SIZE",
				params = {
					path = asset
				}
			}
		))
		local size = Cjson.decode(size_str)
		return size
	end,

	request_get_uuid = function()
		local id_str = Core.notify(Cjson.encode(
			{
				type = "GET_UUID",
				params = {
				}
			}
		))
		local tb = Cjson.decode(id_str)
		return tb.id
	end
}