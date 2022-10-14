local Cjson = require "cjson"
local Def = require "we.def"
local Lfs = require "lfs"
local Seri = require "we.gamedata.seri"
local ItemDataUtils = require "we.gamedata.item_data_utils"
local ItemBase = require "we.gamedata.module.class.item_base"
local Meta = require "we.gamedata.meta.meta"
local Utils = require "we.view.scene.utils"
local EngineFile = require "we.view.scene.create_engine_file"
local IWorld = require "we.engine.engine_world"

local M = Lib.derive(ItemBase)

local MODULE_NAME = "storage"
local ITEM_TYPE = "StorageCfg"

--数据目录，引擎
local FOLDER_NAME = "part_storage"
local PATH_DATA_DIR = Lib.combinePath(Def.PATH_GAME, FOLDER_NAME)

local function get_storage_merge_shapes_path(merge_file_name)
	return Lib.combinePath(PATH_DATA_DIR, "mergeShapesData", merge_file_name .. ".json")
end

local function get_storage_collision_file( collision_file_name)
	return Lib.combinePath(PATH_DATA_DIR, "part_collision", collision_file_name)
end


M.config = {
	--引擎文件
	{
		key = "setting.json",
	
		reader = function(item_name, raw)
			local path = Lib.combinePath(PATH_DATA_DIR, "setting.json")
			return Lib.read_file(path, raw)
		end,

		import = function(content, ref, item)
			return ref
		end,

		export = function(rawval, content, save, item_self)
			local meta = Meta:meta(ITEM_TYPE)
			local item = meta:ctor(rawval)
			local ret = {}
			for _, val in ipairs(item.instances) do
				table.insert(ret, Utils.export_inst(val))
			end
			return ret
		end,

		writer = function(item_name, data, dump)
			assert(type(data) == "table")
			local path = Lib.combinePath(PATH_DATA_DIR, "setting.json")
			return Seri("json", data, path, dump)
		end,

		discard = function(item_name)
			local path = Lib.combinePath(PATH_DATA_DIR, "setting.json")
			ItemDataUtils:del(path)
		end
	},

	discard = function(item_name)
		local path = Lib.combinePath(PATH_DATA_DIR)
		ItemDataUtils:delDir(path)
	end
}

function M:storage_copy_files(mergeKeys, collisionKeys)
	--create folder
	Lib.mkPath(Lib.combinePath(PATH_DATA_DIR, "mergeShapesData"))
	Lib.mkPath(Lib.combinePath(PATH_DATA_DIR, "part_collision"))
	--copy merge files
	for new, old in pairs(mergeKeys) do
		local oldFile = Lib.combinePath(Def.PATH_MERGESHAPESDATA, old .. ".json")
		if Lib.fileExists(oldFile) then -- only copy exist
			Lib.copyFile(oldFile, Lib.combinePath(PATH_DATA_DIR, "mergeShapesData", new .. ".json"))
		end
	end
	--copy collision files
	for new, old in pairs(collisionKeys) do
		local oldFile = Lib.combinePath(Def.PATH_GAME, "part_collision", old)
		if Lib.fileExists(oldFile) then -- only copy exist
			Lib.copyFile(oldFile, Lib.combinePath(PATH_DATA_DIR, "part_collision", new))
		end
	end
end

function M:repeat_merge_shapes_files( merge_keys_new_to_old )
	--create folder
	Lib.mkPath(Def.PATH_MERGESHAPESDATA)
	--copy merge files
	for new, old in pairs(merge_keys_new_to_old) do
		local oldFile = get_storage_merge_shapes_path(old)
		if Lib.fileExists(oldFile) then -- only copy exist
			Lib.copyFile(oldFile, get_storage_merge_shapes_path(new))
		end
	end
end

function M:place_scene_copy_files(mergeKeys, collisionKeys)
	--create folder
	Lib.mkPath(Def.PATH_MERGESHAPESDATA)
	Lib.mkPath(Lib.combinePath(Def.PATH_GAME, "part_collision"))
	--copy merge files
	for new, old in pairs(mergeKeys) do
		local oldFile = Lib.combinePath(PATH_DATA_DIR, "mergeShapesData", old .. ".json")
		if Lib.fileExists(oldFile) then -- only copy exist
			Lib.copyFile(oldFile, Lib.combinePath(Def.PATH_MERGESHAPESDATA, new .. ".json"))
		end
	end
	--copy collision files
	for new, old in pairs(collisionKeys) do
		local oldFile = Lib.combinePath(PATH_DATA_DIR, "part_collision", old)
		if Lib.fileExists(oldFile) then -- only copy exist
			Lib.copyFile(oldFile, Lib.combinePath(Def.PATH_GAME, "part_collision", new))
		end
	end
end

function M:del_storage_merge_shapes_files(rawval)
	assert(rawval)
	if rawval.mergeShapesDataKey then
		os.remove(get_storage_merge_shapes_path(rawval.mergeShapesDataKey))
	end
	for _,child in ipairs(rawval.children) do
		self:del_storage_merge_shapes_files(child)
	end
	if rawval.componentList then
		for _,component in ipairs(rawval.componentList) do
			self:del_storage_merge_shapes_files(component)
		end
	end
end

function M:del_storage_collision_files(collision_key)
	assert(collision_key)
	os.remove(get_storage_collision_file(collision_key))
end

return M
