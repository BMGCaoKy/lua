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
	color = function(item, val)
		item:modify("color", "b", val[1])
		item:modify("color", "g", val[2])
		item:modify("color", "r", val[3])
		item:modify("color", "a", val[4])
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
	return "./conf/asset/texture/block/" .. tex
	--[[for fileName in Lfs.dir(Lfs.currentdir() .. "/conf/asset/texture/block") do
		if fileName == tex then
			return "./conf/asset/texture/block/" .. tex
		end
	end
	print("has no Tex :", tex)
	return ret]]
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
				--local asset = Res.import(cur_path .. "/" .. val[i])
				--item:modify("textures/" .. texArray[i], "asset", asset)
				error("has no texture", val[i])
			end
		end
	end
end

function M:run()
	self:init_block_id()
	self:import_texture()

	for i = 1, 1511 do
		local filename = self.block_map_[i]
		--self:check_prop(filename)
		local ret, msg = pcall(M.addBlock, self, filename)
		assert(ret, msg)
		collectgarbage("collect")
	end
end

function M:import_texture()
	print("import_texture")
	local path = Lfs.currentdir() .. "/game/sample/plugin/myplugin/block/"
	for i = 1, 1511 do
		local block_name = self.block_map_[i]
		if block_name then
			for block_file in Lfs.dir(path .. block_name) do
				if block_file~= "." and block_file ~= ".." and string.find(block_file, ".png") then
					local file_path = Lfs.currentdir() .. "/conf/asset/texture/block/" .. block_file
					local f = io.open(file_path, "r")
					if not f then
						print(block_file)
						Lib.copyFile(path .. block_name .. "/" .. block_file, file_path)
					else
						f:close()
					end
				end
			end
		end
	end
end

function M:init_block_id()
	self.block_map_ = {}
	local path = Lfs.currentdir() .. "/game/sample/id_mappings.json"
	local file = io.open(path)
	local data = Cjson.decode(file:read("*a"))
	file:close()
	for k, v in pairs(data.block) do
		local i = tonumber(k)
		local block = string.sub(v, 10)
		self.block_map_[i] = block
		self.block_map_[block] = i
	end
end

--检察属性是否有处理方法
function M:check_prop(filename)
	if not filename then
		return
	end
	local path = Lfs.currentdir() .. "/game/sample/plugin/myplugin/block/" ..filename .. "/setting.json"
	local data = Lib.read_json_file(path)
	if not data then
		print("has no file", filename)
		return
	end

	for prop, v in pairs(data) do
		if not propFunc[prop] then
			print(filename, "has no prop ", prop)
		end
	end
end

function M:add_official_id(item, id)
	Mapping._mapping["block"] = self._mapping["block"] or {}
	Mapping._mapping["block"][id] = item
	Mapping._mapping["block"][item] = id
	Mapping._modified = true
end

function M:addBlock(filename)
	if not filename then
		return
	end
	--创建新item，获取item数据
	local m = Module:module("block")
	local item = m:new_item(filename)
	
	--老item数据
	print("-------filename--------", filename)
	local path = Lfs.currentdir() .. "/game/sample/plugin/myplugin/block/" ..filename
	local oldData = Lib.read_json_file(path .. "/setting.json")
	assert(oldData, filename)
	--setProp
	for prop, v in pairs(oldData) do
		if propFunc[prop] then
			propFunc[prop](item, v)
		else
			error("has no prop " .. prop)
		end
	end
	--setLang
	local key = item:obj().name.value
	item:modify("name", "value", "")
	item:modify("name", "value", key)
	Lang:set_text(key, filename)
	--setId
	add_official_id(filename, self.block_map_[filename])
end

return M