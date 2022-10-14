local Cjson = require "cjson"
local Def = require "we.def"
local Seri = require "we.gamedata.seri"
local ItemDataUtils = require "we.gamedata.item_data_utils"
local Converter = require "we.gamedata.export.data_converter"
local ItemBase = require "we.gamedata.module.class.item_base"
local PropImport = require "we.gamedata.module.prop_import"
local Meta = require "we.gamedata.meta.meta"
local ModuleRequest = require "we.proto.request_module"

local M = Lib.derive(ItemBase)

local MODULE_NAME = "entity"
local ITEM_TYPE = "EntityCfg"
local PATH_DATA_DIR = Lib.combinePath(Def.PATH_GAME, string.format("plugin/%s/%s", Def.DEFAULT_PLUGIN, MODULE_NAME))

M.config = {
	{
		key = "setting.json",
	
		reader = function(item_name, raw)
			local path = Lib.combinePath(PATH_DATA_DIR, item_name, "setting.json")
			return Lib.read_file(path, raw)
		end,

		import = function(content, ref, item)
			local ok, setting = pcall(Cjson.decode, content)
			if not ok then
				ModuleRequest.request_item_error(Def.ERROR_CODE.TYPE_ERROR, item:game_dir())
				return ref
			end

			local props = {
				name				= PropImport.Text,
				headPic				= PropImport.asset,
				maxHp				= PropImport.original,
				clickDistance		= PropImport.original,
				reachDistance		= PropImport.original,
				canClick			= PropImport.original,
				
				hurtResistantTime	= PropImport.Time,
				stepHeight			= PropImport.original,
				destroyTime			= PropImport.Time,

				deadSound			= PropImport.CastSound,
				damage				= PropImport.original,
				canMove				= PropImport.original,
				moveAcc				= PropImport.original,
				moveFactor			= PropImport.original,

				followEntityDistanceWhenHasTarget	= PropImport.original,
				followEntityDistanceWhenNotTarget	= PropImport.original,

				canJump				= PropImport.original,
				jumpHeight			= PropImport.original,

				hideHp				= PropImport.num2bool,
				hpFaceCamera		= PropImport.num2bool,
				hpBarColor = function(v)
					local val = {}
					val.r = v % 256
					val.g = (v - val.r) / 256 % 256
					val.b = (v - val.r - val.g * 256) / 65536 % 256
					val.a = 255
					return val
				end,
				hpBarHeight			= PropImport.original,
				hpBarWidth			= PropImport.original,
				hideName			= PropImport.original,
				textHeight			= PropImport.original,

				skill				= PropImport.original,
				eyeHeight			= PropImport.original,
				canBoat				= PropImport.original,
				waterLine			= PropImport.original,
				collision			= PropImport.original,
				autoMove			= PropImport.original,
				enableAI            = PropImport.original
			}
			
			for k, v in pairs(setting) do
				if type(props[k]) == "function" then
					ref[k] = props[k](v, item)
				end
			end
			--[[上面遍历引擎数据一对一转成编辑器数据，避免写很多if，
			当引擎数据与编辑器数据的关系是一对多或多对一或多对多或名字不一致时，用下面的写法]]

			local isPlayer = item._id == "player1"
			ref.isPlayer = isPlayer
			local actorModel = {}
			if isPlayer then
				if not setting.actorName  and not setting.actorGirlName  then
					actorModel.modelType = "System"
					actorModel.actorName = { asset = "" }
					actorModel.girlactor = { asset = "" }
				elseif not setting.actorName then
					actorModel.modelType = "Customize"
					actorModel.girlactor = { asset = setting.actorGirlName }
					actorModel.actorName = { asset = "" }
				elseif not setting.actorGirlName then
					actorModel.modelType = "Customize"
					actorModel.actorName = { asset = setting.actorName }
					actorModel.girlactor = { asset = "" }
				else
					actorModel.modelType = "Customize"
					actorModel.actorName = { asset = setting.actorName }
					actorModel.girlactor = { asset = setting.actorGirlName }
				end
				ref.actorModel = actorModel
			else
				ref.actorName = { asset = setting.actorName }
				ref.girlactor = { asset = setting.actorGirlName }
			end

			ref.moveSpeed = setting.moveSpeed and setting.moveSpeed * 20
			ref.jumpSpeed = setting.jumpSpeed and setting.jumpSpeed * 20
			ref.gravity = setting.gravity and setting.gravity * 20
			ref.swimSpeed = setting.swimSpeed and setting.swimSpeed * 20

			ref.dropDamageStart	= setting.dropDamageStart and setting.dropDamageStart * 20
			ref.dropDamageRatio = setting.dropDamageRatio and setting.dropDamageRatio or 5

			ref.unAssailable = setting.unassailable and PropImport.num2bool(setting.unassailable)
			ref.unDamageable = setting.undamageable and PropImport.num2bool(setting.undamageable)

			ref.skill = setting.skillInfos
			ref.disableShadowAtFirstPRV	= setting.disableShadowAtFirstPRV
			ref.castRealShadowAtFirstPRV	= setting.castRealShadowAtFirstPRV
			ref.checkPartTouchEvent = setting.checkPartTouchEvent;
			ref.boundingScaleWithSize = setting.boundingScaleWithSize;

			ref.twist	= item.bodyTurnMin == 0 and item.bodyTurnMax == 0

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
			--AI
			do
				if setting.homeSize then
					ref.AI_home = {
						enable = true,
						homeSize = setting.homeSize/2,
						outOfHome = setting.isAIGoHomePos and "birthplace" or "random"
					}
				end
				if setting.autoAttack or setting.attackNpc or setting.chaseDistance ~= 0 or setting.skillList then
					ref.AI_attack = {
						enable = true,
						attackMode = setting.autoAttack and "autoAttack" or "hitBack",
						targetType = setting.attackNpc and "any" or "player",
						chaseDistance = setting.chaseDistance,
						maxVisualAngle = setting.maxVisualAngle,
						skillList = setting.skillInfoList
					}
				else
					ref.AI_attack = {
						enable = false
					}
				end
				ref.AI_patrol = {}
				if setting.patrolDistance ~= 0 then
					ref.AI_patrol.patrolMode = "randomPath"
					ref.AI_patrol.patrolDistance = setting.patrolDistance
				else
					ref.AI_patrol.patrolMode = "no"
				end
				ref.AI_patrol.idle = {}
				ref.AI_patrol.idle.prob = { value = setting.idleProb }
				if setting.idleTime then
					ref.AI_patrol.idle.idleTime = {
						min = PropImport.Time(setting.idleTime[1]),
						max = PropImport.Time(setting.idleTime[2])
					}
				end
				ref.AI_walkRules = {}
				if setting.avoidCliff or setting.meetCliffBackRun then
					ref.AI_walkRules.faceCliff = {
						avoidCliff = setting.avoidCliff,
						height = setting.avoidCliffHight
					}
				end
			end

			if setting.reviveTime then
				assert(setting.reviveTime >= 0)
				ref.canRevive = true
				ref.reviveTime = PropImport.Time(setting.reviveTime)
			end
			if setting.equipTrays then
				assert(type(setting.equipTrays) == "table")
				local ret = {}
				for _, v in ipairs(setting.equipTrays) do
					table.insert(ret, tostring(v))
				end
				ref.equip = ret
			end
			ref._clientScript = {}
			if setting._clientScript then
				ref._clientScript = ref._clientScript or {}
				for _, s in ipairs(setting._clientScript) do
					table.insert(ref._clientScript, {path = s})
				end
			end
			
			ref._serverScript ={}
			if setting._serverScript then
				ref._serverScript = ref._serverScript or {}
				for _, s in ipairs(setting._serverScript) do
					table.insert(ref._serverScript, {path = s})
				end
			end

			ref.deadAction={}
			if  setting.deathHideTime then
				ref.deadAction.deathHideTime = PropImport.Time(setting.deathHideTime)
			end
			if setting.randomPlayDeadActions and #setting.randomPlayDeadActions >=1  then
				ref.deadAction.playDeadAction = setting.randomPlayDeadActions[1]
			end	

			return ref
		end,

		export = function(rawval, content, save, val, dump)
			local meta = Meta:meta(ITEM_TYPE)
			local item = meta:ctor(rawval)

			local ret
			if content then
				ret = Cjson.decode(content)
			else
				ret = {}
			end

			local isPlayer = val._id == "player1"
			ret.isPlayer = isPlayer
			if ret.isPlayer then
				ret.modelType = item.actorModel.modelType
				if item.actorModel.modelType == "System" then
					if dump then
						ret.actorName = nil
						ret.actorGirlName =  nil 
					else
						ret.actorName =  "boy.actor" 
						ret.actorGirlName =  "girl.actor" 
					end
					ret.ignorePlayerSkin = false
				else
					ret.ignorePlayerSkin = true
					ret.actorName = item.actorModel.actorName.asset
					ret.actorGirlName = item.actorModel.girlactor.asset
				end
			else
				ret.actorName = item.actorName.asset
				ret.actorGirlName = item.girlactor.asset
			end

			if ret.actorName and ret.actorName == "" then
				ret.actorName = "empty.actor"
			end
			
			if ret.actorGirlName and ret.actorGirlName == "" then
				ret.actorGirlName = "empty.actor"
			end

			ret.headPic			= Converter(item.headPic, "add_asset")
			ret.name			= item.name.value
			ret.maxHp			= item.maxHp
			ret.clickDistance	= item.clickDistance
			ret.reachDistance	= item.reachDistance
			ret.canClick		= item.canClick
			ret.unassailable	= item.unAssailable and 1 or 0
			ret.hurtResistantTime = item.hurtResistantTime.value
			ret.undamageable	= item.unDamageable and 1 or 0
			ret.stepHeight		= item.stepHeight
			ret.reviveTime		= item.canRevive and item.reviveTime.value or nil
			ret.destroyTime		= item.destroyTime.value
			ret.deadSound		= Converter(item.deadSound)
			ret.damage			= item.damage
			ret.canMove			= item.canMove
			ret.moveAcc			= item.moveAcc
			ret.moveSpeed		= item.moveSpeed / 20
			ret.moveFactor		= item.moveFactor
			ret.followEntityDistanceWhenHasTarget	= item.followEntityDistanceWhenHasTarget
			ret.followEntityDistanceWhenNotTarget	= item.followEntityDistanceWhenNotTarget
			ret.canJump			= item.canJump
			ret.jumpSpeed		= item.jumpSpeed / 20
			ret.gravity			= item.gravity / 20
			ret.jumpHeight		= item.jumpHeight
			ret.hideHp			= item.hideHp and 1 or 0
			ret.hpBarColor		= item.hpBarColor.r + item.hpBarColor.g * 256 + item.hpBarColor.b * 256^2 + 256^4
			ret.hpBarHeight		= item.hpBarHeight
			ret.hpBarWidth		= item.hpBarWidth
			ret.hideName		= item.hideName
			ret.textHeight		= item.textHeight
			ret.hpFaceCamera	= item.hpFaceCamera and 1 or 0
			ret.dropDamageStart	= item.dropDamageStart / 20
			ret.dropDamageRatio	= item.dropDamageRatio
			ret.disableShadowAtFirstPRV	= item.disableShadowAtFirstPRV
			ret.castRealShadowAtFirstPRV	= item.castRealShadowAtFirstPRV
			ret.boundingScaleWithSize = item.boundingScaleWithSize
			ret.checkPartTouchEvent = item.checkPartTouchEvent

			ret.skillInfos = function()
				local skills = {}
				for _,v in pairs(item.skill) do
					if v and v ~= "" then
						table.insert(skills,v)
					end
				end
				return skills
			end
			ret.skills = nil

			ret.eyeHeight		= item.eyeHeight

			ret.collision		= item.collision
			ret.autoMove		= item.autoMove
			ret.autoRotateColliderBox = ret.autoRotateColliderBox == nil and true or ret.autoRotateColliderBox
			ret.equipTrays = function()
				local equip = {}
				for _,v in pairs(item.equip) do
					if v and v ~= "" then
						table.insert(equip,tonumber(v))
					end
				end
				return equip
			end

			ret.collider = Converter(item.boundingVolume)
			ret.boundingVolume = nil

			ret.canHurtMove = ret.canHurtMove == nil or ret.canHurtMove

			--AI
			ret.enableAI = item.enableAI
			
			ret.nextChaseInterval = item.enableAI and (ret.nextChaseInterval and ret.nextChaseInterval or 2) or nil
			if item.AI_home.enable then
				ret.homeSize = item.AI_home.homeSize * 2
				ret.isAIGoHomePos = item.AI_home.outOfHome == "birthplace"
			else
				ret.homeSize = nil
				ret.isAIGoHomePos = nil
			end
			if item.AI_attack.enable then
				ret.chaseInterval = ret.chaseInterval and ret.chaseInterval or 10
				ret.autoAttack = item.AI_attack.attackMode == "autoAttack"
				ret.attackNpc = item.AI_attack.targetType == "any"
				ret.chaseDistance = item.AI_attack.chaseDistance
				ret.maxVisualAngle = item.AI_attack.maxVisualAngle
				ret.skillInfoList = nil
				if #item.AI_attack.skillList > 0 then
					ret.skillInfoList = {}
					for _, v in ipairs(item.AI_attack.skillList) do
						if v and v.fullName ~= "" then
							table.insert(ret.skillInfoList, v)
						end
					end
				end
			else
				ret.chaseInterval = nil
				ret.autoAttack = nil
				ret.attackNpc = nil
				ret.chaseDistance = nil
				ret.maxVisualAngle = nil
				ret.skillInfoList = nil
			end
			ret.skillList = nil
			if item.AI_patrol.patrolMode == "randomPath" then
				ret.patrolDistance = item.AI_patrol.patrolDistance
				local idle = item.AI_patrol.idle
				ret.idleProb = idle.prob.value
				ret.idleTime = {
					idle.idleTime.min.value,
					idle.idleTime.max.value
				}
			else
				ret.patrolDistance = nil
				ret.idleProb = nil
				ret.idleTime = nil
			end
			ret.avoidCliff = item.AI_walkRules.faceCliff.avoidCliff
			if item.AI_walkRules.faceCliff.avoidCliff then
				ret.meetCliffBackRun = true
				ret.avoidCliffHight = item.AI_walkRules.faceCliff.height
			else
				ret.meetCliffBackRun = nil
				ret.avoidCliffHight = nil
			end

			ret.enableMeshNavigate = item.AI_walkRules.ai_navigation.enable
			if item.AI_walkRules.ai_navigation.enable then
				ret.enableMeshNavigate = true
			else
				ret.enableMeshNavigate = nil
			end

			if item._clientScript then
				ret._clientScript = {}
				for _, s in ipairs(item._clientScript) do
					table.insert(ret._clientScript, s.path)
				end
			end

			if item._serverScript then
				ret._serverScript = {}
				for _, s in ipairs(item._serverScript) do
					table.insert(ret._serverScript, s.path)
				end
			end

			if item.deadAction then 
				ret.randomPlayDeadActions={}
				table.insert(ret.randomPlayDeadActions,item.deadAction.playDeadAction)
				ret.deathHideTime = item.deadAction.deathHideTime.value 
			end 

			ret.disableShadow = ret.disableShadow ~= nil and ret.disableShadow or true
			ret.needCheckTouch = ret.needCheckTouch ~= nil and ret.needCheckTouch or true

			ret.canPickOnDie = ret.canPickOnDie ~= nil and ret.canPickOnDie or false

			local key, val = next(ret)
			while(key) do
				if type(val) == "function" then
					ret[key] = val()
				end
				key, val = next(ret, key)
			end
			ret.setFollowWhenCreate = true
			ret.hideHolder = false

			--单位转身配置
			ret.bodyTurnMin = item.twist and 0 or nil
			ret.bodyTurnMax = item.twist and 0 or nil

			-----------地形地图不导处游泳相关参数------------------------
			local GameConfig = require "we.gameconfig"
			local is_block = not GameConfig:disable_block()
			ret.canBoat			= is_block and item.canBoat or nil
			ret.waterline		= is_block and item.waterLine or nil
			ret.swimSpeed		= is_block and item.swimSpeed / 20 or nil
			--地形地图和方块地图区分处理参数的导出
			if is_block then
				ret.enableNavigate = ret.enableMeshNavigate --方块的
				ret.enableMeshNavigate = false --体素地形的
			end
			----------方块地图不导处虚空死亡配置-------------------------
			ret.touchdownTimeToDie = not is_block and true or nil
			ret.touchdownTimeToDieTick = not is_block and 5 or nil
			-------------------------------------------------------------

			--是否可以转头设置 false可，true不可，玩家的头部是跟随摄像机的(配置true)
			ret.canTurnHead		= isPlayer

			ret.aiFixSpeedRate = 2

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
