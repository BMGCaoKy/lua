local Cjson = require "cjson"
local Def = require "we.def"
local Seri = require "we.gamedata.seri"
local ItemDataUtils = require "we.gamedata.item_data_utils"
local Converter = require "we.gamedata.export.data_converter"
local ItemBase = require "we.gamedata.module.class.item_base"
local Meta = require "we.gamedata.meta.meta"
local PropImport = require "we.gamedata.module.prop_import"

local M = Lib.derive(ItemBase)

local MODULE_NAME = "buff"
local ITEM_TYPE = "BuffCfg"
local PATH_DATA_DIR = Lib.combinePath(Def.PATH_GAME, string.format("plugin/%s/%s", Def.DEFAULT_PLUGIN, MODULE_NAME))

M.config = {
	{
		key = "setting.json",
	
		reader = function(item_name, raw)
			local path = Lib.combinePath(PATH_DATA_DIR, item_name, "setting.json")
			return Lib.read_file(path, raw)
		end,

		import = function(content, ref, item)
			local setting = Cjson.decode(content)

			local props = {
				sound				= PropImport.CastSound,
				needSave			= PropImport.original,
				deadRemove			= PropImport.original,
				maxHp				= PropImport.original,
				damage				= PropImport.original,
				damagePct			= PropImport.original,
				deDmgPct			= PropImport.original,
				continueDamage		= PropImport.original,
				continueHeal		= PropImport.original,
				moveFactor			= PropImport.original,
				reachDistance		= PropImport.original,
				undamageable		= PropImport.num2bool,
				unassailable		= PropImport.num2bool,
				dropDamageStart		= PropImport.original,
				dropDamageRatio		= PropImport.original,
				hide				= PropImport.num2bool,
				sync				= PropImport.original,
			}

			ref.fixTime = setting.fixTime and setting.fixTime or "superposition"

			ref.moveSpeed = setting.moveSpeed and setting.moveSpeed * 20
			ref.jumpSpeed = setting.jumpSpeed and setting.jumpSpeed * 20
			ref.moveAcc = setting.moveAcc and setting.moveAcc * 20
			ref.gravity = setting.gravity and setting.gravity * 20
			ref.antiGravity = setting.antiGravity and setting.antiGravity * 20

			ref.addCollision = item.addCollision == 1 and true or false

			ref.skin = {}
			for k, v in pairs(setting.skin or {}) do
				table.insert(ref.skin, { masterName = k, slaveName = v })
			end

			ref.replaceAction = {}
			for k, v in pairs(setting.actionMap or {}) do
				table.insert(ref.replaceAction, {
					beReplacedAction = k,
					replaceAction = v
				})
			end

			ref.actionPlaybackSpeed = {}
			for k, v in pairs(setting.actionTimeScaleMap or {})do
				table.insert(ref.actionPlaybackSpeed,{
					Action = k,
					PlaySpeed = v
				})
			end

			for k, v in pairs(setting) do
				if type(props[k]) == "function" then
					ref[k] = props[k](v, item)
				end
			end

			ref.castEffect = setting.effect and PropImport.EntityEffect(setting.effect, item)

			if not ref.name then
				local trans_key = item:module_name() .. "_" .. item:id()
				ref.name = PropImport.Text(trans_key)
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

			ret.sound			= Converter(item.sound)
			ret.effect			= Converter(item.castEffect)
			ret.needSave		= item.needSave
			ret.deadRemove		= item.deadRemove
			ret.maxHp			= item.maxHp
			ret.damage			= item.damage
			ret.damagePct		= item.damagePct
			ret.deDmgPct		= item.deDmgPct
			ret.continueDamage	= item.continueDamage
			ret.continueHeal	= item.continueHeal
			ret.moveSpeed		= item.moveSpeed / 20
			ret.moveFactor		= item.moveFactor
			ret.jumpSpeed		= item.jumpSpeed / 20
			ret.reachDistance	= item.reachDistance
			ret.canClick		= item.canClick
			ret.moveAcc			= item.moveAcc / 20
			ret.gravity			= item.gravity / 20
			ret.antiGravity		= item.antiGravity / 20
			ret.unassailable	= item.unassailable and 1 or 0
			ret.undamageable	= item.undamageable and 1 or 0
			ret.dropDamageStart	= item.dropDamageStart
			ret.dropDamageRatio	= item.dropDamageRatio
			ret.hide			= item.hide and 1 or 0
			ret.sync			= item.sync
			ret.addCollision    = item.addCollision and 1 or 0

			ret.fixTime = item.fixTime ~= "superposition" and item.fixTime or nil
			
			ret.actionMap = {}
			for _, v in ipairs(item.replaceAction or {}) do
				ret.actionMap[v.beReplacedAction] = v.replaceAction
			end
			if Lib.table_is_empty(ret.actionMap) then
				ret.actionMap = nil
			end

			ret.actionTimeScaleMap = {}
			for _, v in ipairs(item.actionPlaybackSpeed or {}) do
				ret.actionTimeScaleMap[v.Action] = v.PlaySpeed
			end
			if Lib.table_is_empty(ret.actionTimeScaleMap) then
				ret.actionTimeScaleMap = nil
			end

			ret.skin = {}
			for _, v in ipairs(item.skin or {}) do
				ret.skin[v.masterName] = v.slaveName
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

	discard = function(item_name)
		local path = Lib.combinePath(PATH_DATA_DIR, item_name)
		ItemDataUtils:delDir(path)
	end
}

return M
