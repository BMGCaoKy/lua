local Cjson = require "cjson"
local Def = require "we.def"
local Seri = require "we.gamedata.seri"
local ItemDataUtils = require "we.gamedata.item_data_utils"
local Converter = require "we.gamedata.export.data_converter"
local ItemBase = require "we.gamedata.module.class.item_base"
local Meta = require "we.gamedata.meta.meta"
local PropImport = require "we.gamedata.module.prop_import"

local M = Lib.derive(ItemBase)

local MODULE_NAME = "item"
local ITEM_TYPE = "ItemCfg"
local PATH_DATA_DIR = Lib.combinePath(Def.PATH_GAME, string.format("plugin/%s/%s", Def.DEFAULT_PLUGIN, MODULE_NAME))

M.config = {
	{
		key = "setting.json",
	
		reader = function(item_name, raw)
			local path = Lib.combinePath(PATH_DATA_DIR, item_name, "setting.json")
			return Lib.read_file(path, raw)
		end,

		import = function(content, ref, item)
			local props = {
				icon					= PropImport.asset,
				stack_count_max			= PropImport.original,
				canAbandon				= PropImport.original,
				candrop					= PropImport.original,
				dropSpeed				= PropImport.original,
				canUse					= PropImport.original,
				needSave				= PropImport.original,
				trap					= PropImport.original,
			}

			local setting = Cjson.decode(content)
			for k, v in pairs(setting) do
				if type(props[k]) == "function" then
					ref[k] = props[k](v, item)
				end
			end
			ref.mesh = setting.mesh and { asset = setting.mesh }
			if setting.itemname then
				ref.name = PropImport.Text(setting.itemname)
			end
			do	--道具类型
				local type, item
				if setting.tray or setting.equip_skin or setting.equip_skill or setting.equip_buff then
					type = "Equip"
					item = {
						[Def.OBJ_TYPE_MEMBER] = "ItemEquip",
						tray = setting.tray[1] and tostring(setting.tray[1]),
						equip_skill = setting.equip_skill,
						equip_buff = setting.equip_buff
					}
					if setting.equip_skin then
						for k, v in pairs(setting.equip_skin) do
							item.itemPosition = k
							item.itemGuise = v
						end
					end
				elseif setting.useBuff then
					type = "Use"
					item = {
						[Def.OBJ_TYPE_MEMBER] = "ItemUse",
						useBuff = setting.useBuff.cfg,
						time = PropImport.Time(setting.useBuff.time)
					}
				else
					type = "InHand"
					item = {
						[Def.OBJ_TYPE_MEMBER] = "ItemInHand",
						skill = setting.skill,
						handItemBoneName = setting.handItemBoneName,
						handBuff = setting.handBuff
					}
				end

				ref.item = {
					type = type,
					base = item
				}
			end
			if setting.container then
				ref.itemContainer = {
					isValid = true,
					initCapacity = setting.container.initCapacity,
					maxCapacity = setting.container.maxCapacity,
				}
				if setting.container.loadType == "Block" then
					ref.itemContainer.itemType = PropImport.ConsumeItemType("/block", setting.container.loadName)
				elseif setting.container.loadType == "Item" then
					ref.itemContainer.itemType = PropImport.ConsumeItemType(setting.container.loadName)
				end
			end

			return ref
		end,

		export = function(rawval, content)
			local meta = Meta:meta(ITEM_TYPE)
			local item = meta:ctor(rawval)

			local ret
			if content then
				ret = Cjson.decode(content)
			else
				ret = {}
			end

			ret.canEquipPlural = true
			ret.icon = Converter(item.icon, "add_asset")
			ret.mesh = item.mesh.asset ~= "" and item.mesh.asset or nil
			ret.stack_count_max = item.stack_count_max
			ret.canAbandon = item.canAbandon
			ret.candrop = item.candrop
			ret.dropSpeed = item.dropSpeed
			ret.canUse = item.canUse
			ret.needSave = item.needSave
			ret.itemname = item.name.value
			ret.trap = item.trap
			ret.syncGameData = {
				currentCapacity = true,
				extCapacity = true
			}

			ret.container = nil
			if item.itemContainer.isValid then
				ret.container = {}
				ret.container.initCapacity = item.itemContainer.initCapacity
				ret.container.maxCapacity = item.itemContainer.maxCapacity
				if item.itemContainer.itemType.block == "" and item.itemContainer.itemType.item == "" then
					ret.container.loadType = "Custom"
				elseif item.itemContainer.itemType.type == "Block" then
					ret.container.loadType = "Block"
					ret.container.loadName = item.itemContainer.itemType.block ~= "" and item.itemContainer.itemType.block
				else
					ret.container.loadType = "Item"
					ret.container.loadName = item.itemContainer.itemType.item ~= "" and item.itemContainer.itemType.item
				end
			end
			
			ret.tray = nil
			ret.equip_skin = nil
			ret.equip_skill = nil
			ret.equip_buff = nil
			ret.skill = nil
			ret.useBuff = nil
			ret.handItemBoneName = nil
			ret.handBuff = nil

			local item_base = item.item.base
			local item_type = item_base.__OBJ_TYPE
			if item_type == "ItemEquip" then
				ret.tray = {
					tonumber(item_base.tray)
				}
				ret.equip_skin = {
					[item_base.itemPosition] = 
					item_base.itemGuise
				}
				if item_base.equip_skill then
					ret.equip_skill = item_base.equip_skill
				end
				if item_base.equip_buff and item_base.equip_buff ~= "" then
					ret.equip_buff = item_base.equip_buff
				end
			elseif item_type == "ItemInHand" then
				ret.skill = function()
					local skills = {}
						for _,v in pairs(item_base.skill) do
							if v and v ~= "" then
								table.insert(skills,v)
							end
						end
					return skills
				end
				ret.handItemBoneName = item_base.handItemBoneName
				ret.handBuff = item_base.handBuff ~= "" and item_base.handBuff or nil
			elseif item_type == "ItemUse" and item_base.useBuff ~= "" and item_base.time.value > 0 then
				ret.useBuff = {
					cfg = item_base.useBuff,
					time = item_base.time.value
				}
			end

			local key, val = next(ret)
			while(key) do
				if type(val) == "function" then
					ret[key] = val()
				end
				key, val = next(ret, key)
			end

			return ret
		end,

		writer = function(item_name, data, dump)
			assert(type(data) == "table")
			local path = Lib.combinePath(PATH_DATA_DIR, item_name, "setting.json")
			return Seri("json", data, path, dump)
		end,

		discard = function(item_name)
			local path = Lib.combinePath(PATH_DATA_DIR, item_name, "setting.json")
			ItemDataUtils:del(path)
		end
	},

	{
		key = "triggers.bts",

		member = "triggers",

		reader = function(item_name, raw)
			local path = Lib.combinePath(PATH_DATA_DIR, item_name, "triggers.bts")
			return Lib.read_file(path, raw)
		end,

		import = function(content, ref)
			-- todo
			return {}
		end,

		export = function(item)
			return item.triggers or {}
		end,

		writer = function(item_name, data, dump)
			local path = Lib.combinePath(PATH_DATA_DIR, item_name, "triggers.bts")
			return Seri("bts", data, path, dump)
		end,

		discard = function(item_name)
			local path = Lib.combinePath(PATH_DATA_DIR, item_name, "triggers.bts")
			ItemDataUtils:del(path)
		end
	},

	discard = function(item_name)
		local path = Lib.combinePath(PATH_DATA_DIR, item_name)
		ItemDataUtils:delDir(path)
	end
}

return M
