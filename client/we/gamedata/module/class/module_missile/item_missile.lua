local Cjson = require "cjson"
local Def = require "we.def"
local Seri = require "we.gamedata.seri"
local ItemDataUtils = require "we.gamedata.item_data_utils"
local Converter = require "we.gamedata.export.data_converter"
local ItemBase = require "we.gamedata.module.class.item_base"
local Meta = require "we.gamedata.meta.meta"
local PropImport = require "we.gamedata.module.prop_import"

local M = Lib.derive(ItemBase)

local MODULE_NAME = "missile"
local ITEM_TYPE = "MissileCfg"
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

				followTarget				= PropImport.original,

				lifeTime					= PropImport.Time,
				vanishTime					= PropImport.Time,
				vanishShow					= PropImport.original,

				collideBlock				= tostring,

				startSound					= PropImport.CastSound,
				startEffect					= PropImport.MissileEffect,

				hitInterval					= PropImport.Time,
				hitEntitySkill				= PropImport.original,
				hitBlockSkill				= PropImport.original,
				hitEntitySound				= PropImport.CastSound,
				hitBlockSound				= PropImport.CastSound,
				hitEntityEffect				= PropImport.MissileEffect,
				hitBlockEffect				= PropImport.MissileEffect,
				reboundBlockSound			= PropImport.CastSound,

				vanishSkill					= PropImport.original,
				vanishEffect				= PropImport.MissileEffect,
				vanishSound					= PropImport.CastSound,
			}

			local setting = Cjson.decode(content)

			for k, v in pairs(setting) do
				if type(props[k]) == "function" then
					ref[k] = props[k](v, item)
				end
			end
			--[[上面遍历引擎数据一对一(名字要一致)转成编辑器数据，避免写很多if，
			当引擎数据与编辑器数据的关系是一对多或多对一或多对多或名字不一致时，用下面的写法]]
			ref.moveSpeed = setting.moveSpeed and setting.moveSpeed * 20
			ref.moveAcc = setting.moveAcc and setting.moveAcc * 20
			ref.gravity = setting.gravity and setting.gravity * 20
			ref.rotateSpeed = setting.rotateSpeed and setting.rotateSpeed * 20
			
			--抛射物目标导入,四个数据都存在才进行导入
			if setting.hitEntitysRole and #setting.hitEntitysRole == 3 and setting.hitTargetTeamIds and setting.hitTargetConfigRole then
				ref.target_team = setting.hitEntitysRole[1]
				ref.target_type = setting.hitEntitysRole[2]
				ref.target_cfg = setting.hitEntitysRole[3]
				local teams = {}
				for k,_ in pairs(setting.hitTargetTeamIds) do
					table.insert(teams,tonumber(k))
				end
				ref.teams = teams
				local entitys = {}
				for _,v in pairs(setting.hitTargetConfigRole) do
					table.insert(entitys,v["fullName"])
				end
				ref.entitys = entitys
			end

			local boundingVolume = nil
			--正常导入
			if setting.collider and setting.collider["type"] then
				boundingVolume = {}
				local params = setting.collider["extent"]
				boundingVolume["type"] = setting.collider["type"]
				boundingVolume["params"] = params
				boundingVolume["radius"] = setting.collider["radius"]
				boundingVolume["height"] = setting.collider["height"]
			end
			--旧数据导入
			if setting.boundingVolume and setting.boundingVolume["type"] then
				boundingVolume = {}
				boundingVolume["type"] = setting.boundingVolume["type"]
				local params = setting.boundingVolume["params"]
				if params then
					boundingVolume["params"] = { x = params[1], y = params[2], z = params[3] }
					boundingVolume["radius"] = params[4] and params[4] or nil
					boundingVolume["height"] = params[5] and params[5] * 2 or nil
				end
			end
			ref.boundingVolume = boundingVolume

			if setting.hitCount or setting.hitEntityCount or setting.hitBlockCount then
				ref.hitCount = {
					isValid = true,
					hitCount = setting.hitCount,
					hitEntityCount = setting.hitEntityCount,
					hitBlockCount = setting.hitBlockCount
				}
			end
			if setting.modelMesh then
				ref.missileModel = { type = "mesh", modelMesh = {asset = setting.modelMesh} }
			elseif setting.modelBlock then
				ref.missileModel = { type = "block", modelBlock = setting.modelBlock }
			end

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

			ret.collider		= Converter(item.boundingVolume)
			ret.modelSizeScale		= Converter(item.missileModel.modelSizeScale)
			ret.boundingVolume		= nil

			ret.autoRotateColliderBox = ret.autoRotateColliderBox == nil and true or ret.autoRotateColliderBox
			ret.lockRotateBodyYaw = 0
			ret.lockRotateBodyPitch = 0
			ret.lockRotateBodyRoll = 0
			ret.rotateFree = true
			ret.followTargetRotationOffset = {x = 0,y = 0,z = 0}
			ret.followTargetRotation = true
			
			ret.moveSpeed			= item.moveSpeed / 20
			ret.moveAcc				= item.moveAcc / 20
			ret.gravity				= item.gravity / 20
			ret.rotateSpeed			= item.rotateSpeed / 20

			ret.followTarget		= item.followTarget

			ret.lifeTime			= item.lifeTime.value
			ret.vanishTime			= item.vanishTime.value
			ret.vanishShow			= item.vanishShow

			ret.collideBlock		= tonumber(item.collideBlock)

			ret.startSound			= Converter(item.startSound)
			ret.startEffect			= Converter(item.startEffect)

			ret.hitInterval			= item.hitInterval.value
			ret.hitCount			= item.hitCount.isValid and item.hitCount.hitCount or nil
			ret.hitEntityCount		= item.hitCount.isValid and item.hitCount.hitEntityCount or nil
			ret.hitBlockCount		= item.hitCount.isValid and item.hitCount.hitBlockCount or nil
			ret.hitEntitySkill		= (item.hitEntitySkill ~= "") and item.hitEntitySkill or nil
			ret.hitBlockSkill		= (item.hitBlockSkill ~= "") and item.hitBlockSkill or nil
			ret.hitEntitySound		= Converter(item.hitEntitySound)
			ret.hitEntityEffect		= Converter(item.hitEntityEffect)

			ret.hitBlockSound		= Converter(item.hitBlockSound)
			ret.hitBlockEffect		= Converter(item.hitBlockEffect)
			ret.reboundBlockSound	= Converter(item.reboundBlockSound)

			ret.vanishSkill			= (item.vanishSkill ~= "") and item.vanishSkill or nil
			ret.vanishEffect		= Converter(item.vanishEffect)
			ret.vanishSound			= Converter(item.vanishSound)

			ret.collideEntity		= 6
			local hitEntitysRoles = {}
			table.insert(hitEntitysRoles, item.target_team)
			table.insert(hitEntitysRoles, item.target_type)
			table.insert(hitEntitysRoles, item.target_cfg)
			ret.hitEntitysRoles = hitEntitysRoles
			local hitTargetTeamIds = nil
			if item.target_team == "hitTargetTeam" then
				hitTargetTeamIds = {}
				for k,v in pairs(item.teams) do
					hitTargetTeamIds[tostring(v)] = true
				end
			end
			ret.hitTargetTeamIds = hitTargetTeamIds
			local hitTargetConfigRole = nil
			if item.target_cfg == "hitTargetConfigEntity" then
				hitTargetConfigRole = {}
				for k,v in pairs(item.entitys) do
					table.insert(hitTargetConfigRole, {fullName = v})
				end
			end
			ret.hitTargetConfigRole = hitTargetConfigRole

			ret.modelMesh = nil
			ret.modelBlock = nil
			if item.missileModel.type == "mesh" then
				ret.modelMesh = item.missileModel.modelMesh.asset
			elseif item.missileModel.type == "block" then
				ret.modelBlock = item.missileModel.modelBlock
			end

			ret.isPitch = ret.isPitch == nil and true or ret.isPitch
			ret.startWithMoveAcc = ret.startWithMoveAcc == nil or ret.startWithMoveAcc

			local key, val = next(ret)
			while(key) do
				if type(val) == "function" then
					ret[key] = val()
				end
				key, val = next(ret, key)
			end
			----------------地形地图特殊配置---------------
			local GameConfig = require "we.gameconfig"
			local is_terrain = GameConfig:disable_block()
			if  GameConfig:disable_block() then
				ret.hitBlockCount = nil
				ret.hitCount = nil
				ret.collideBlock = nil
				ret.hitBlockSkill = nil
				ret.hitBlockSound = nil
				ret.hitBlockEffect = nil
				ret.reboundBlockSound = nil
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
