local Seri = require "editor.gamedata.seri"
local Base = require "editor.gamedata.export.module.export_base"
local Converter = require "editor.gamedata.export.data_converter"

local M = Lib.derive(Base)

local MODULE_DIR = Lib.combinePath(Root.Instance():getGamePath(), "plugin/myplugin/frontsight/")

local item_class = {
	init = function(self, module, item)
		self._module = module
		self._item = module:item(item)
	end,

	seri = function(self, dump)
		local item = self._item:val()
		-- json
		do	
			local data = {
				["minDiffuse"] = item.minDiffuse,
				["maxDiffuse"] = item.maxDiffuse,
				["moveDiffuse"] = item.moveDiffuse,
				["showLevel"] = item.showLevel,
				["shrinkVal"] = item.shrinkVal,
				["List"] = {
					{
						["type"] = "Image",
						["Image"] = {
							{
								["path"] = "@"..item.vertical.asset,
								["initPos"] = {
									["x"] = 0,
									["y"] = -20
								}
							},
							{
								["path"] = "@"..item.vertical.asset,
								["initPos"] = {
									["x"] = 0,
									["y"] = 20
								}
							},
							{
								["path"] = "@"..item.horizontal.asset,
								["initPos"] = {
									["x"] = -20,
									["y"] = 0
								}
							},
							{
								["path"] = "@"..item.horizontal.asset,
								["initPos"] = {
									["x"] = 20,
									["y"] = 0
								}
							}
						}
					},
					{
						["type"] = "_Ccircle",
						["commonColor"] = {
							["r"] = 1,
							["g"] = 1,
							["b"] = 1,
							["a"] = 0
						},
						["hitColor"] = {
							["r"] = 1,
							["g"] = 0,
							["b"] = 0,
							["a"] = 0
						},
						["init_r"] = 100
					}
				}
			}
			local key, val = next(data)
			while(key) do
				if type(val) == "function" then
					data[key] = val()
				end
				key, val = next(data, key)
			end

			local path = Lib.combinePath(MODULE_DIR, self._item:id(), "setting.json")
			Seri("json", data, path, dump)
		end

		-- bts
		do
			local data = item.triggers
			local path = Lib.combinePath(MODULE_DIR, self._item:id(), "triggers.bts")
			Seri("bts", data, path, dump)
		end
	end,
}

function M:init(module)
	Base.init(self,module,item_class)
end

return M
