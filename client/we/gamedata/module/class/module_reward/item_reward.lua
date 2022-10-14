local Cjson = require "cjson"
local Def = require "we.def"
local Seri = require "we.gamedata.seri"
local ItemDataUtils = require "we.gamedata.item_data_utils"
local Converter = require "we.gamedata.export.data_converter"
local ItemBase = require "we.gamedata.module.class.item_base"
local Meta = require "we.gamedata.meta.meta"
local PropImport = require "we.gamedata.module.prop_import"
local M = Lib.derive(ItemBase)

local MODULE_NAME = "reward"
local ITEM_TYPE = "RewardCfg"
local PATH_DATA_DIR = Lib.combinePath(Def.PATH_GAME, string.format("plugin/%s/%s", Def.DEFAULT_PLUGIN, MODULE_NAME))

M.config = {
	{
		key = "setting.json",
	
		reader = function(item_name, raw)
			local path = Lib.combinePath(PATH_DATA_DIR, item_name, "setting.json")
			return Lib.read_file(path, raw)
		end,

		import = function(content, ref, item)
			local function get_reward(v)
				if v.type == "Block" then
					local ret = {
						type = v.type,
						base = v
					}
					ret.base[Def.OBJ_TYPE_MEMBER] = "RewardBlock"
					return ret
				elseif v.type == "Item" then
					local ret = {
						type = v.type,
						base = v
					}
					ret.base[Def.OBJ_TYPE_MEMBER] = "RewardItem"
					return ret
				elseif v.type == "Coin" then
					local ret = {
						type = v.type,
						base = v
					}
					ret.base[Def.OBJ_TYPE_MEMBER] = "RewardCoin"
					return ret
				elseif v.type == "List" then
					local ret = {
						type = v.type,
						base = {
							[Def.OBJ_TYPE_MEMBER] = "RewardList",
							countRange = v.countRange,
							array = {}
						}
					}
					for _, reward in ipairs(v.array or {}) do
						table.insert(ret.base.array, {
							weight = v.weight,
							reward = get_reward(reward)
						})
					end
					return ret
				end
			end

			local setting = Cjson.decode(content)
			local ret = {
				name = {value = "reward_" .. item:id()},
				rewardArray = {}
			}
			for i, v in ipairs(setting) do
				table.insert(ret.rewardArray, get_reward(v))
			end

			if not ref.name then
				local trans_key = item:module_name() .. "_" .. item:id()
				ret.name = PropImport.Text(trans_key)
			end
			return ret
		end,

		export = function(rawval)
			local meta = Meta:meta(ITEM_TYPE)
			local item = meta:ctor(rawval)

			local get_reward
			get_reward = function(reward)
				local ret
				if reward.type == "List" then
					ret = {}
					ret.type = "List"
					ret.countRange = Converter(reward.base.countRange, "remove_obj_type")
					ret.array = {}
					for _, v in ipairs(reward.base.array) do
						local rewardItem = get_reward(v.reward)
						rewardItem.weight = v.weight
						table.insert(ret.array, rewardItem)
					end
				else
					ret = Converter(reward.base, "remove_obj_type")
					ret.type = reward.type
				end
				return ret
			end

			local data = {}

			for _, it in ipairs(item.rewardArray) do
				local reward = get_reward(it)
				table.insert(data, reward)
			end

			local key, val = next(data)
			while(key) do
				if type(val) == "function" then
					data[key] = val()
				end
				key, val = next(data, key)
			end

			return data
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

	discard = function(item_name)
		local path = Lib.combinePath(PATH_DATA_DIR, item_name)
		ItemDataUtils:delDir(path)
	end
}

return M
