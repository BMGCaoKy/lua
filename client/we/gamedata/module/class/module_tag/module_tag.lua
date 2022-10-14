local Lfs = require "lfs"
local Def = require "we.def"
local ModuleBase = require "we.gamedata.module.class.module_base"

local M = Lib.derive(ModuleBase)

local MODULE_NAME = "tag"
local ITEM_TYPE = "TagCfg"

function M:init(name)
	assert(name == MODULE_NAME, 
		string.format("[ERROR] module name not match %s:%s", MODULE_NAME, name)
	)

	ModuleBase.init(self, MODULE_NAME, ITEM_TYPE)
end

function M:check_valid_items()
	return {
		"block",
		"entity"
	}
end

return M
