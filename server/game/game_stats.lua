local misc = require "misc"
local cjson = require "cjson"

local log_file = Game.stats_log_file
local game_id = Server.CurServer:getGameId()
local game_name = World.GameName

local related_id = L("related_id", 0)

function Game.Stats(typ, data, related)
	if not log_file then
		return
	end
	data = data or {}
	data.type = typ
	data.gameId = game_id
	data.gameName = game_name
	data.engineVersion = EngineVersionSetting.getEngineVersion()
	data.time = os.time()
	if related then
		if not related.id then
			related_id = related_id + 1
			related.id = related_id
		end
		data.related = related.id
	end
	log_file:write(cjson.encode(data), "\n")
	log_file:flush()
end

function Game.GameId()
	return game_id
end

local function init()
	local server = Server.CurServer
	local path = server:getStatsDir()
	if not log_file and path and path~="" then
		local c = path:sub(-1)
		if c~="/" and c~="\\" then
			path = path .. "/"
		end
		path = string.format("%s%s_%s.log", path, os.date("%Y%m%d_%H%M%S"), game_id)
		log_file = io.open(path, "w")
		Game.stats_log_file = log_file
	end
end

init()

RETURN()
