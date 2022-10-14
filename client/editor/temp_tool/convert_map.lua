local Lfs = require "lfs"
local Map = require "editor.map"
local Module = require "editor.gamedata.module.module"
local Lang = require "editor.gamedata.lang"
local UserData = require "editor.user_data"

local M = {}

local game_name = "RPG_model"
function M:run()
	local game_path = Lfs.currentdir() .. "/game/" .. game_name
	for map_name in Lfs.dir(game_path .. "/map") do
		if map_name ~= '.' and map_name ~= '..' then
			local map_path = game_path .. "/map/" .. map_name
			self:add_map(map_path, map_name)
		end
	end
end	

function M:add_map(map_path, map_name)
	local m = Module:module("map")
	local item = m:new_item()
	--设置名字
	local name_key = item:val().name.value
	Lang:set_text(name_key, map_name)
	--复制mca
	Map:clear_map_mca(item:id())
	Map:add_map_mca(item:id(), map_path)
	--设置相机
	local data = Lib.read_json_file(map_path .. "/setting.json")
	Map:update_by_name(item:id(), data.pos)
	UserData:save()
end

return M