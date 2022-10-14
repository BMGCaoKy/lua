local Lfs = require "lfs"
local Def = require "we.def"
local Map = require "we.map"
local ModuleBase = require "we.gamedata.module.class.module_base"
local GameConfig = require "we.gameconfig"

local M = Lib.derive(ModuleBase)

local MODULE_NAME = "map"
local ITEM_TYPE = "MapCfg"

function M:init(name)
	assert(name == MODULE_NAME, 
		string.format("[ERROR] module name not match %s:%s", MODULE_NAME, name)
	)

	ModuleBase.init(self, MODULE_NAME, ITEM_TYPE)
end

local function copy_mca(id)
	local SOURCE_MAP_RES_DIR = string.gsub(Lib.combinePath(Def.PATH_ASSET_MAP_DIR, "plane"), "/", "\\")
	local DEST_MAP_RES_DIR = string.gsub(Lib.combinePath(Root.Instance():getGamePath(), "map/", id), "/", "\\")

	for item_name in Lfs.dir(SOURCE_MAP_RES_DIR) do
		if string.find(item_name, ".mca") then
			-- read
			local path = Lib.combinePath(SOURCE_MAP_RES_DIR, item_name)
			local file = io.open(path, "rb")
			local data = file:read("a")
			file:close()
			
			local dest = Lib.combinePath(DEST_MAP_RES_DIR, item_name)
			file = io.open(dest, "wb")
			file:write(data)
			file:close()
		end
	end
end

local function copy_terrain(id)
	local SOURCE_MAP_RES_DIR = string.gsub(Lib.combinePath(Def.PATH_ASSET_MAP_DIR, "terrain"), "/", "\\")
	local DEST_MAP_RES_DIR = string.gsub(Lib.combinePath(Root.Instance():getGamePath(), "terrain/", id), "/", "\\")

	CGame.instance:copyDir(SOURCE_MAP_RES_DIR, DEST_MAP_RES_DIR)
end

function M:on_item_new(id)
--[==[
	local SOURCE_MAP_RES_DIR = string.gsub(Lib.combinePath(Def.PATH_ASSET_MAP_DIR, "plane"), "/", "\\")
	local DEST_MAP_RES_DIR = string.gsub(Lib.combinePath(Root.Instance():getGamePath(), "map/", id), "/", "\\")

	print("copy mca files!\n src: %s, dest: %s, cd: %s", SOURCE_MAP_RES_DIR, DEST_MAP_RES_DIR, Lfs.currentdir())

	local ret, msg, statu = os.execute(string.format([[XCOPY "%s" "%s" /Y/C]],
		string.format("%s\\*.mca", SOURCE_MAP_RES_DIR), 
		DEST_MAP_RES_DIR
	))

	assert(ret, string.format("%s: %s", msg, statu))
]==]
	if not GameConfig:disable_block() then
		copy_mca(id)
	end
end

function M:check_valid_items()
	local ret = {}

	local dir = Lib.combinePath(Def.PATH_GAME, "map")

	for item_name in Lfs.dir(dir) do
		if item_name ~= "." and item_name ~= ".." then
			local path = Lib.combinePath(dir, item_name)
			local attr = Lfs.attributes(path)
			if attr.mode == "directory" then
				table.insert(ret, item_name)
			end
		end
	end

	return ret
end

function M:reload_item(id)
	Map:reload_map(id)
end

return M
