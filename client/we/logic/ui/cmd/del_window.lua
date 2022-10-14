local Recorder = require "we.gamedata.recorder"

local M = {}

function M:init(item, item_id_list)
	Recorder:start()
	for _,id in ipairs(item_id_list) do
		item:delete_window(id)
	end
	Recorder:stop()
end

return M