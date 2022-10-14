local cjson = require "cjson"
local engine = require "editor.engine"
local def = require "editor.def"

local M = {}

function M:init()
	
end

function M:getjson(jsonname)
	local path = def.REGIONDIR
	if jsonname == "region" then
		path = def.REGIONDIR
	end

	local file = io.open(path,"a+")
	local text = file:read("*all")
	file:close()
	return text
end

M:init()

return M;