local ModuleBase = require "we.gamedata.module.class.module_base"
local ModuleRequest = require "we.proto.request_module"
local Def = require "we.def"
local Lfs = require "lfs"

local M = Lib.derive(ModuleBase)

local MODULE_NAME = "layout"
local ITEM_TYPE = "LayoutCfg"

function M:init(name)
	assert(name == MODULE_NAME, 
		string.format("[ERROR] module name not match %s:%s", MODULE_NAME, name)
	)

	ModuleBase.init(self, MODULE_NAME, ITEM_TYPE)
end

function M:load_layout(path, id)
	--对比MD5来判断文件是否被外部修改，是则重新加载这个layout
	if self:list()[id] and self:list()[id]:MD5Compare(path) then
		return true
	elseif self:list()[id] then
		self:del_item(id)
	end
	local index = string.find(path,"asset")
	if not index then
		index = string.find(path,"gui/layout_presets/")
	end
	assert(index,"path error")
	local item = self:new_item(id,{path = string.sub(path, index)})
	item:save()
end

function M:check_valid_items()
	local ret = {}

	local dir = Lib.combinePath(Def.PATH_GAME_META_DIR, "module", self:name(),"item")

	for item_name in Lfs.dir(dir) do
		if item_name ~= "." and item_name ~= ".."  and item_name ~= ".sheets" then
			--检查json是否存在
			local json_path = Lib.combinePath(dir, item_name, "setting.json")
			local json_attr = Lfs.attributes(json_path)
			if json_attr and json_attr.mode == "file" then
				local tb = Lib.read_json_file(json_path)
				--是否是旧数据,旧数据中没有路径、MD5信息
				if tb and tb["data"]["path"] then
					local layout_path = Lib.combinePath(Def.PATH_GAME, tb["data"]["path"])
					local layout_attr = Lfs.attributes(layout_path)
					--layout文件是否存在
					if layout_attr and layout_attr.mode == "file" then
						table.insert(ret, item_name)
					end
				end
			end
		end
	end

	return ret
end

return M