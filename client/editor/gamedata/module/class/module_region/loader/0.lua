local Lfs = require "lfs"
local Def = require "editor.def"

local MODULE_PATH = Lib.combinePath(Def.PATH_GAME_META_DIR, "module", "region/item")

-- loader
return function()
	local items = {}

	-- ¶ÁÈ¡Êý¾Ý
	for item_name in Lfs.dir(MODULE_PATH) do
		if item_name ~= "." and item_name ~= ".." then
			local item_path = Lib.combinePath(MODULE_PATH, item_name, "setting.json")
			local data = Lib.read_json_file(item_path)
			items[item_name] = {data = data, path = item_path}
		end
	end

	return {
		items = items
	}
end
