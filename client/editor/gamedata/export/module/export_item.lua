local Seri = require "editor.gamedata.seri"
local Base = require "editor.gamedata.export.module.export_base"

local M = Lib.derive(Base)

local MODULE_DIR = Lib.combinePath(Root.Instance():getGamePath(), "plugin/myplugin/item/")

local item_class = {
	init = function(self, module, item)
		self._module = module
		self._item = module:item(item)
	end,

	seri = function(self, dump)
		local item = self._item:val()
		local item_base = item.item.base
		-- json
		do	

			local data = {
				["itemintroduction"] = item.itemintroduction.value,
				["icon"] = function()
					if item.icon.asset == "" then
						return nil
					else
						return "@" .. item.icon.asset
					end
				end,
				["mesh"] = function()
					if item.mesh.asset == "" then
						return nil
					else
						return item.mesh.asset
					end
				end,
				["stack_count_max"] = item.stack_count_max,
				["candestroy"] = item.candestroy,
				["candrop"] = item.candrop,
				["canUse"] = item.canUse,
				["needSave"] = item.needSave,
				["itemname"] = item.name.value,
				["trap"] = item.trap,
				["container"] = {
					["initCapacity"] = item.itemContainer.initCapacity,
					["maxCapacity"] = item.itemContainer.maxCapacity,
				},
				["syncGameData"] = {
					currentCapacity = true,
					extCapacity = true
				}
			}
			if item.itemContainer.itemType.type == "Block" then
				data.container.loadType = "Block"
				data.container.loadName = item.itemContainer.itemType.block ~= "" and item.itemContainer.itemType.block
			else
				data.container.loadType = "Item"
				data.container.loadName = item.itemContainer.itemType.item ~= "" and item.itemContainer.itemType.item
			end

			if item_base.__OBJ_TYPE == "ItemEquip" then
				data.tray = {
					tonumber(item_base.tray)
				}
				data.equip_skin = {
					[item_base.itemPosition] = 
					item_base.itemGuise
				}
				if item_base.equip_skill then
					data.equip_skill = item_base.equip_skill
				end
				if item_base.equip_buff and item_base.equip_buff ~= "" then
					data.equip_buff = item_base.equip_buff
				end
			end
			if item_base.__OBJ_TYPE == "ItemInHand" then
				data.skill = function()
					local skills = {}
						for _,v in pairs(item_base.skill) do
							if v and v ~= "" then
								table.insert(skills,v)
							end
						end
					return skills
				end
			end
			if item_base.__OBJ_TYPE == "ItemUse" then
				data.useBuff = {
					cfg = item_base.useBuff,
					time = item_base.time.value
				}
			end

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
