local Seri = require "editor.gamedata.seri"
local Base = require "editor.gamedata.export.module.export_base"
local Converter = require "editor.gamedata.export.data_converter"

local M = Lib.derive(Base)

local MODULE_DIR = Lib.combinePath(Root.Instance():getGamePath(), "plugin/myplugin/buff/")

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
				["sound"] = Converter(item.sound),
				["effect"] = Converter(item.castEffect),
				["needSave"] = item.needSave,
				["maxHp"] = item.maxHp,
				["damage"] = item.damage,
				["continueDamage"] = item.continueDamage,
				["continueHeal"] = item.continueHeal,
				["moveSpeed"] = item.moveSpeed,
				["moveFactor"] = item.moveFactor,
				["jumpSpeed"] = item.jumpSpeed,
				["reachDistance"] = item.reachDistance,
				["canClick"] = item.canClick,
				["moveAcc"] = item.moveAcc,
				["gravity"] = item.gravity,
				["unassailable"] = function()
					if item.unassailable then
						return 1
					else
						return 0
					end
				end,
				["undamageable"] = function()
					if item.undamageable then
						return 1
					else
						return 0
					end
				end,
				["dropDamageStart"] = item.dropDamageStart,
				["dropDamageRatio"] = item.dropDamageRatio,
				["hide"] = item.hide,
				["sync"] = item.sync
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
