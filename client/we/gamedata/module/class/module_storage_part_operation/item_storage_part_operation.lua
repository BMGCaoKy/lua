local Def = require "we.def"
local Lfs = require "lfs"
local Seri = require "we.gamedata.seri"
local ItemDataUtils = require "we.gamedata.item_data_utils"
local ItemBase = require "we.gamedata.module.class.item_base"

local M = Lib.derive(ItemBase)

--数据目录，引擎
local FOLDER_NAME = "part_storage"
local PATH_DATA_DIR = Lib.combinePath(Def.PATH_GAME, FOLDER_NAME, "events")

M.config = {
	{
		key = "triggers.bts",

		member = "triggers",

		reader = function(item_name, raw)
			local file_name = string.format("%s.bts",item_name)
			local path = Lib.combinePath(PATH_DATA_DIR, file_name)
			return Lib.read_file(path, raw)
		end,

		import = function(content, ref)
			return {}
		end,

		export = function(item)
			return item.triggers or {}
		end,

		writer = function(item_name, data, dump)
			local file_name = string.format("%s.bts",item_name)
			local path = Lib.combinePath(PATH_DATA_DIR, file_name)
			return Seri("bts", data, path, dump)
		end,

		discard = function(item_name)
			local file_name = string.format("%s.bts",item_name)
			local path = Lib.combinePath(PATH_DATA_DIR, file_name)
			ItemDataUtils:delFile(path)
		end
	},

	discard = function(item_name)
		--不需要删除目录
	end
}

return M
