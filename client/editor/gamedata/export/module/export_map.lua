local Seri = require "editor.gamedata.seri"
local Base = require "editor.gamedata.export.module.export_base"
local Lfs = require "lfs"

local M = Lib.derive(Base)

local MODULE_DIR = Lib.combinePath(Root.Instance():getGamePath(), "map/")

local item_class = {
	init = function(self, module, item)
		self._module = module
		self._item = module:item(item)
	end,

	seri = function(self, dump)
		local item = self._item:val()

		-- json
		do	
			local entitys = {}
			for i = 1, #item.entitys do
				local entity = {
					cfg = item.entitys[i].cfg,
					pos = Lib.copy(item.entitys[i].pos),
					ry = item.entitys[i].ry
				}
				table.insert(entitys,entity)
			end
			local regions = {}
			for i = 1, #item.regions do
				local region = {
					box = {
						min = {
							x = item.regions[i].min.x,
							y = item.regions[i].min.y,
							z = item.regions[i].min.z
						},
						max = {
							x = item.regions[i].max.x,
							y = item.regions[i].max.y,
							z = item.regions[i].max.z
						}
					},
					name = item.regions[i].name
				}
				if item.regions[i].cfg ~= "" then
					region["regionCfg"] = "myplugin/"..item.regions[i].cfg
				else
					region["regionCfg"] = ""
				end
				regions[item.regions[i].id] = region
			end
			local data = {
				["canAttack"] = item.canAttack,
				["canBreak"] = item.canBreak,
				["entity"] = entitys,
				["region"] = regions
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

		-- µ¼³öµØÍ¼ mca
		if dump then
			os.execute(string.format([[xcopy /A/E/C/R/Y "%s" "%s/*"]], 
				Lib.combinePath(self._item:dir(), "mca"), 
				Lib.combinePath(MODULE_DIR, self._item:id())))
		end
	end,
}

function M:init(module)
	Base.init(self, module, item_class)
end

return M
