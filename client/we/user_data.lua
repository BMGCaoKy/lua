local cjson = require "cjson"
local ItemDataUtils = require "we.gamedata.item_data_utils"
local M = {}
local init_data = 
{
	map_pos = {
		map001 = {
			y = 68,
			z = 30,
			x = 30
		}
	},
	camera_move_speed = 0.3,
	camera_fov = 0.5
}

function M:init()
	self._path = ""
	self._json = {}

	local gamePath = Root.Instance():getGamePath()

	local gamePaths = Lib.splitString(gamePath,"/")
	local gameName = gamePaths[#gamePaths]
	local gameRootPath = ItemDataUtils:gameRootPath()
	self._path = gameRootPath .. gameName .. "/user_data.json"

	local tb = Lib.read_json_file(self._path)
	if type(tb) == "table" then
		self._json = tb
	end
end

function M:set_value(key,value)
	self._json[key] = value
end

function M:get_value(key)
	if self._json[key] == nil then
		if init_data[key] then
			return init_data[key]
		else
			return nil
		end
	end
	return self._json[key]
end

function M:save()
	local file = io.open(self._path,"w+b")
	file:write(cjson.encode(self._json or {}))
	file:close()
end

M:init()
return M