local lfs = require "lfs"
local cjson = require "cjson"
local M = {}
function M:init()
	self._path = ""
	self._json = {}

	local gamePath = Root.Instance():getGamePath()

	local gamePaths = Lib.splitString(gamePath,"/")
	local gameName = gamePaths[#gamePaths]
	self._path = "./editor/"..gameName.."/user_data.json"

	local file = io.open(self._path,"r")
	if file then
		local data = file:read("*a")

		self._json = cjson.decode(data)
		file:close()
	end
	
end

function M:set_value(key,value)
	self._json[key] = value
end

function M:get_value(key)
	return self._json[key]
end

function M:save()
	local file = io.open(self._path,"w+")
	file:write(cjson.encode(self._json))
	file:close()
end

M:init()
return M