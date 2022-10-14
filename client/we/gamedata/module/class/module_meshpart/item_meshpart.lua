local Cjson = require "cjson"
local Def = require "we.def"
local Seri = require "we.gamedata.seri"
local ItemDataUtils = require "we.gamedata.item_data_utils"
local ItemBase = require "we.gamedata.module.class.item_base"

local M = Lib.derive(ItemBase)

local MODULE_NAME = "meshpart"
local ITEM_TYPE = "MeshPartCfg"

M.config = {
	{
		key = "triggers.bts",

		member = "triggers",

		reader = function(item_name, raw)
			local file_name = string.format("%s.bts",item_name)
			local path = Lib.combinePath(Def.PATH_EVENTS, file_name)
			return Lib.read_file(path, raw)
		end,

		import = function(content, ref)
			-- todo
			return {}
		end,

		export = function(item)
			return item.triggers or {}
		end,

		writer = function(item_name, data, dump)
			local file_name = string.format("%s.bts",item_name)
			local path = Lib.combinePath(Def.PATH_EVENTS, file_name)
			return Seri("bts", data, path, dump)
		end,

		discard = function(item_name)
			local file_name = string.format("%s.bts",item_name)
			local path = Lib.combinePath(Def.PATH_EVENTS, file_name)
			ItemDataUtils:del(path)
		end
	},

	discard = function(item_name)
		--不需要删除目录
	end
}

return M
