local TreeSet = require "we.gamedata.vtree"
local VN = require "we.gamedata.vnode"

local M = {}

local function import_data()
	local data
	repeat
		local path = Lib.combinePath(Root.Instance():getGamePath(), "config.json")
		data = Lib.read_json_file(path)	
		if data then
			break
		end

		path = Lib.combinePath(Root.Instance():getGamePath(), ".meta/config.json")
		data = Lib.read_json_file(path)
	until(true)


	if not data then
		return {}
	end

	return {
		["disable_block"] = data.disable_block and true or false,
		["disable_storage"] = data.disable_storage and true or false,
		["template_id"] = data.template_id or "invalid",
	}
end

function M:init()
	local data = import_data()
	local tree = assert(TreeSet:create("GameConfig", data, "TREE_ID_GAME_CONFIG"))
	self._root = tree:root()
end

function M:disable_block()
	return self._root["disable_block"]
end

return M
