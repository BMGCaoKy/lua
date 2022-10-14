local Cjson = require "cjson"
local Def = require "we.def"
local Seri = require "we.gamedata.seri"
local Converter = require "we.gamedata.export.data_converter"
local ItemBase = require "we.gamedata.module.class.item_base"
local Meta = require "we.gamedata.meta.meta"

local M = Lib.derive(ItemBase)

local MODULE_NAME = "frontsight"
local ITEM_TYPE = "FrontSightCfg"

local PATH_DATA_DIR = Lib.combinePath(Def.PATH_GAME, string.format("plugin/%s/%s", Def.DEFAULT_PLUGIN, MODULE_NAME))

M.config = {
	discard = function(item_name)
		local path = Lib.combinePath(PATH_DATA_DIR, item_name)
		os.execute(string.format([[RD /S/Q "%s"]], path))
	end
}

return M
