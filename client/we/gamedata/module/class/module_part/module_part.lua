local Def = require "we.def"
local Lfs = require "lfs"
local ModuleBase = require "we.gamedata.module.class.module_base"

local M = Lib.derive(ModuleBase)

local MODULE_NAME = "part"
local ITEM_TYPE = "PartCfg"

function M:init(name)
	assert(name == MODULE_NAME, 
		string.format("[ERROR] module name not match %s:%s", MODULE_NAME, name)
	)

	ModuleBase.init(self, MODULE_NAME, ITEM_TYPE)
end

function M:check_valid_items()
	local ret = {}

	local dir = Lib.combinePath(Def.PATH_GAME_META_DIR,"module","part","item")
	for item_name in Lfs.dir(dir) do
		if item_name ~= "." and item_name ~= ".." then
			local path = Lib.combinePath(dir,item_name)
			local attr = Lfs.attributes(path)
			if attr.mode == "directory" then
				table.insert(ret, item_name)
			end
 		end
	end

	return ret
end

-- copy item not need copy folder
function M:copy_item_folder(id, newId)
end

return M
