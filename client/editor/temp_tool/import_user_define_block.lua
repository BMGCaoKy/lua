local Lfs = require "lfs"
local Cjson = require "cjson"
local Mapping = require "editor.gamedata.module.mapping"
local Module = require "editor.gamedata.module.module"
local Lang = require "editor.gamedata.lang"
local Res = require "editor.gamedata.res"

local cur_path

local M = {}
local propFunc = {
	breakBlockSound = function() end,
	fall = function(item, val) 
		item:modify("", "fall", val)
	end,
	spring = function(item, val)
		item:modify("", "spring", val)
	end,
	climbSpeed = function(item, val) 
		item:modify("", "climbSpeed", val)
	end,
	lightOpacity = function(item, val) 
		item:modify("", "lightOpacity", val)
	end,
	lightEmitted = function(item, val) 
		item:modify("", "lightEmitted", val)
	end,
	renderPass = function(item, val) 
		item:modify("", "renderPass", val)
	end,
	isOpaqueFullCube = function(item, val) 
		item:modify("", "isOpaqueFullCube", val)
		item:modify("", "emitLightInMaxLightMode", not val)
	end,
	blockObjectOnCollision = function(item, val) 
		item:modify("", "blockObjectOnCollision", val)
	end,
	canSwim = function(item, val) 
		item:modify("", "canSwim", val)
	end,
	maxSpeed = function(item, val) 
		item:modify("", "maxSpeed", val)
	end,
	renderable = function(item, val) 
		item:modify("", "renderable", val)
	end,
	emitLightInMaxLightMode = function(item, val) 
		item:modify("", "emitLightInMaxLightMode", val)
	end,
	focusable = function() end,
	triggers = function() end,
	reward = function() end,
	blockHp = function() end,
	base = function() end,
	effect = function() end,
	dropItem = function() end,
	dropCount = function() end,
	needSave = function() end,
}

local function hasTex(tex)
	if not tex then
		return nil
	end
	local ret
	if string.find(tex, "/", 1, 2) then
		tex = string.sub(tex, 2)
	end

	local f = io.open(Lfs.currentdir() .. "/conf/asset/texture/block/" .. tex, "r")
	if not f then
		return nil
	else
		f:close()
		return "./conf/asset/texture/block/" .. tex
	end
end

propFunc.collisionBoxes = function(item, val)
	if #val == 0 then
		item:remove("collisionBoxes", 1)
	end
	if #val > 1 then
		for i = 1, #val - 1 do
			item:insert("collisionBoxes")
		end
	end
	for i, v in ipairs(val) do
		item:modify("collisionBoxes/".. i .. "/min", "x", v.min.x)
		item:modify("collisionBoxes/".. i .. "/min", "y", v.min.x)
		item:modify("collisionBoxes/".. i .. "/min", "z", v.min.x)
		item:modify("collisionBoxes/".. i .. "/max", "x", v.min.x)
		item:modify("collisionBoxes/".. i .. "/max", "y", v.min.x)
		item:modify("collisionBoxes/".. i .. "/max", "z", v.min.x)
	end
end

propFunc.quads = function(item, val)
	if #val > 0 then
		for i = 1, #val do
			item:insert("quads")
		end
	end
	for i, v in ipairs(val) do
		local ret = hasTex(v.texture)
		if ret then
			item:modify("quads/".. i .. "/texture", "selector", ret)
		end
		for j = 1, 4 do
			item:modify("quads/".. i .. "/pos/" .. j, "x", v.pos[j].x)
			item:modify("quads/".. i .. "/pos/" .. j, "y", v.pos[j].y)
			item:modify("quads/".. i .. "/pos/" .. j, "z", v.pos[j].z)
		end
	end
end

propFunc.breakTime = function(item, val)
	if type(val) == "number" and val > 0 then
		item:modify("", "canBreak", true)
		item:modify("breakTime", "value", val)
	else
		item:modify("", "canBreak", false)
	end
end

propFunc.texture = function(item, val)
	local texArray = {"down", "up", "front", "back", "left", "right"}
	for i = 1, 6 do
		local ret = hasTex(val[i])
		if val[i] then 
			if ret then
				item:modify("textures/" .. texArray[i], "selector", ret)
			else
				local asset = Res.import(cur_path .. "/" .. val[i])
				item:modify("textures/" .. texArray[i], "asset", asset)
			end
		end
	end
end

local game_name = "RPG_model"


local cn
local en
local function init_lang()
	local target_game_path = Lfs.currentdir() .. "/game/" .. game_name
	local path = target_game_path .. "/lang/Language/"
	cn = Lib.read_json_file(path .. "zh.json")
	en = Lib.read_json_file(path .. "en.json")
end


function M:run()
	init_lang()
	self:import_user_defined_block()
end

function M:import_user_defined_block()
	print("import_user_defined_block")
	local target_game_path = Lfs.currentdir() .. "/game/" .. game_name

	local path = target_game_path .. "/plugin/myplugin/block"
	for block_name in Lfs.dir(path) do
		if tonumber(block_name) then
			self:addBlock(block_name)
		end
	end
end

function M:addBlock(filename)
	--创建新item，获取item数据
	local m = Module:module("block")
	local item = m:new_item()
	
	--老item数据
	print("-------filename--------", filename)
	local path = Lfs.currentdir() .. "/game/" ..game_name .. "/plugin/myplugin/block/" ..filename
	cur_path = path
	local oldData = Lib.read_json_file(path .. "/setting.json")
	--setProp
	for prop, v in pairs(oldData) do
		if propFunc[prop] then
			propFunc[prop](item, v)
		--else
			--error("has no prop " .. prop)
		end
	end
	--setLang
	local key = item:obj().name.value
	item:modify("name", "value", "")
	item:modify("name", "value", key)
	local lang_key = oldData["Editor_NameKey"]
	Lang:set_text(key, cn[lang_key], "zh")
	Lang:set_text(key, en[lang_key], "en")
end

return M