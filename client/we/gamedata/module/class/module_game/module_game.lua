local ModuleBase = require "we.gamedata.module.class.module_base"

local M = Lib.derive(ModuleBase)

local MODULE_NAME = "game"
local ITEM_TYPE = "GameCfg"

function M:init(name)
	assert(name == MODULE_NAME, 
		string.format("[ERROR] module name not match %s:%s", MODULE_NAME, name)
	)

	ModuleBase.init(self, MODULE_NAME, ITEM_TYPE)
end

function M:del_item(id)
	assert(false)
end

function M:need_reload()
	return true
end

function M:check_valid_items()
	return {"0"}
end

return M
