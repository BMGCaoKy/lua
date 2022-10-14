local Cjson = require "cjson"
local Def = require "we.def"
local Seri = require "we.gamedata.seri"
local ItemDataUtils = require "we.gamedata.item_data_utils"
local Converter = require "we.gamedata.export.data_converter"
local ItemBase = require "we.gamedata.module.class.item_base"
local Meta = require "we.gamedata.meta.meta"
local PropImport = require "we.gamedata.module.prop_import"

local M = Lib.derive(ItemBase)

local MODULE_NAME = "skill_system"
local ITEM_TYPE = "SkillSystemCfg"
local PATH_DATA_DIR = Lib.combinePath(Def.PATH_GAME, string.format("plugin/%s/%s", Def.DEFAULT_PLUGIN, MODULE_NAME))
local PATH_SKILL_DATA_DIR =  Lib.combinePath(Def.PATH_GAME, string.format("plugin/%s/%s", Def.DEFAULT_PLUGIN, "skill"))
local PATH_MISSILE_DATA_DIR =  Lib.combinePath(Def.PATH_GAME, string.format("plugin/%s/%s", Def.DEFAULT_PLUGIN, "missile"))


--近战攻击 技能1(抛射物类型_发射方向_镜头方向) + 抛射物 + 技能2(伤害)
--射击技能 技能1(抛射物类型_发射方向_自己) + 抛射物 + 技能2(伤害)
local function reader_to_table(id)
	local path = Lib.combinePath(PATH_DATA_DIR, id, "setting.json")
	local content = Lib.read_file(path)
	if content then
		return Cjson.decode(content)
	else
		return nil
	end
		
end

--抛射物技能数据
local function skill1_data(item)
	local ret = {}
	--技能释放方式
	ret.icon = "@asset/Texture/Skill/common/icon_子弹_act.png"
	--item.skillReleaseWay.isClickIcon and Converter(item.skillReleaseWay.icon, "add_asset") or nil
	------------------------------
	local area_number  = 7
	--item.skillReleaseWay.iconPos.area_number
	ret.area_number = area_number 
	local pos_tab = {
		{-220, 66, 80},
		{-90, 66, 80},
		{60, 66, 80},
		{200, 66, 80},
		{-126, -366, 70},
		{-20, -366, 70},
		{-228, -68, 88},
		{-190, -200, 88},
		{-58, -238, 88}
	}
	if area_number < 5 then
		ret.horizontalAlignment = 1
		ret.verticalAlignment = nil
	else
		ret.horizontalAlignment = 2
		ret.verticalAlignment = 2
	end
	ret.hurtDistance =0.1
	local tab = pos_tab[area_number]
	ret.area = tab and {{0, tab[1]}, {0, tab[2]}, {0, tab[3]}, {0, tab[3]}} or {{0, 0},{0, 0}, {0, 0}, {0, 0}}
	ret.customizeSkill = true;
	------------------------------
	ret.draggingEnabled = false --item.skillReleaseWay.draggingEnabled
	ret.sensitivityFactor = 1 --item.skillReleaseWay.sensitivityFactor
	ret.isClick = false --item.skillReleaseWay.isClick
	ret.isTouch = false --item.skillReleaseWay.isTouch
	ret.cdTime = 0 --item.cdTime.value

	ret.consumeItem = function()
		--[[
		if #item.consumeItem == 0 then
			return
		end
		local consumeItem_array = {}
		for _, it in ipairs(item.consumeItem) do
			local newItem = {}
			if it.itemType.type == "Block" then
				newItem.consumeName = "/block"
				newItem.consumeBlock = it.itemType.block ~= "" and it.itemType.block
			else
				newItem.consumeName = it.itemType.item ~= "" and it.itemType.item
			end
			newItem.count = it.count
			table.insert(consumeItem_array, newItem)
		end
		return consumeItem_array
		--]]
	end
	ret.consumeVp = 0 --item.consumeVp
	ret.container = function()
		--[[
		if (item.container.isValid) then
			return {
				takeNum = item.container.takeNum,
				autoReloadSkill = item.container.autoReloadSkill ~= "" and item.container.autoReloadSkill or nil
			}
		end
		--]]
	end

	ret.frontSight = "" --item.frontSight
	ret.castAction = "" --item.castAction
	ret.castActionTime = -1
	--ret.castSound = Converter(item.castSound)
	--ret.castEffect = Converter(item.castEffect)
	ret.startAction = ""--item.startAction
	ret.startActionTime = 0--Converter(item.startActionTime)
	--ret.startEffect = Converter(item.startEffect)
	ret.sustainAction = ""--item.sustainAction
	--ret.sustainEffect = Converter(item.sustainEffect)
	--ret.stopEffect = Converter(item.stopEffect)
	ret.targetType = "Self"
	ret.type = "Missile"-- item.skill.type

	ret.missileCount = 1-- #item_base.missile
	ret.missileCfg = {}
	ret.startPos = {}
	ret.startYaw = {}
	ret.startPitch = {}
	ret.bodyYawOffset = {}
	ret.bodyPitchOffset = {}
	ret.startWait = {}

	local i = 1
	ret.startFrom = "foot"
	ret.missileCfg[i] = "myplugin/"..item.missile --0c1218ec-8263-4000-a8f8-436f9b7ca3a2"
	--missile.missileCfg
	ret.startPos[i] = {
		x = 0,--missile.startPos.x,
		y = 0,--missile.startPos.y,
		z = 0--missile.startPos.z
	}
	ret.startYaw[i] = 0--missile.startYaw
	ret.startPitch[i] = 0-- missile.startPitch
	ret.bodyYawOffset[i] = 0-- missile.bodyYawOffset
	ret.bodyPitchOffset[i] = 0--missile.bodyPitchOffset
	ret.startWait[i] = 0--missile.startWait.value
	
	local key, val = next(ret)
		while(key) do
			if type(val) == "function" then
				ret[key] = val()
			end
			key, val = next(ret, key)
	end
	
	--以上为抛射物技能的默认属性，以下为组合技能的可编辑属性导出到抛射物技能属性
	ret.cdTime = item.cdTime.value
	if ret.cdTime % 20 == 0 then
		item.isShowCdPoint = false
	else
		item.isShowCdPoint = true
	end
	ret.isShowCdPoint = item.isShowCdPoint
	ret.enableCdTip = item.enableCdTip
	ret.enableCdMask = item.enableCdMask
	ret.cdMaskConfig = {
				horizontalAlignment = 1,
				verticalAlignment = 1,
				FillPosition = item.FillPosition, 
				FillType = item.FillType,
				AntiClockwise = item.AntiClockwise
			}

	ret.chargeCdTime = item.chargeCdTime.value
	if ret.chargeCdTime % 20 == 0 then
		item.chargeIsShowCdPoint = false
	else
		item.chargeIsShowCdPoint = true
	end

	if item.beginCoolDown == "RunOutOfAllTimes" then
		ret.beginCoolDown = 1
	elseif item.beginCoolDown == "AfterUse" then
		ret.beginCoolDown = 2
	end

	if item.recoveryTimes == "AllTimes" then
		ret.recoveryTimes = 1
	elseif item.recoveryTimes == "SingleTime" then
		ret.recoveryTimes = 2
	end
	ret.enableChargeTime = item.enableChargeTime
	ret.chargeTimes = item.chargeTimes
	ret.chargeIsShowCdPoint = item.chargeIsShowCdPoint
	ret.chargeEnableCdMask = item.chargeEnableCdMask
	ret.chargeCdMaskConfig = {
				horizontalAlignment = 1,
				verticalAlignment = 1,
				FillPosition = item.chargeFillPosition, 
				FillType = item.chargeFillType,
				AntiClockwise = item.chargeAntiClockwise
			}

	ret.icon = Converter(item.skillIcon, "add_asset")
	ret.icon_pushed = Converter(item.skillIconPushed, "add_asset")
	--技能位置编号(area_number、horizontalAlignment、verticalAlignment、area)
	local area_number  = item.skillIconPos.area_number
	ret.area_number = area_number
	if area_number < 5 then
		ret.horizontalAlignment = 1
		ret.verticalAlignment = nil
	else
		ret.horizontalAlignment = 2
		ret.verticalAlignment = 2
	end
	local tab = pos_tab[area_number]
	--图标位置
	ret.area					= tab and {{0, tab[1]}, {0, tab[2]}, {0, tab[3]}, {0, tab[3]}} or {{0, 0},{0, 0}, {0, 0}, {0, 0}}
	--长按连发
	ret.castInterval = nil
	if item.isTouch then
		ret.castInterval		= item.castInterval.value
	end
	--技能释放动作、时间
	ret.castAction				= item.castAction.castAction
	--技能释放时间
	ret.castActionTime			= ret.castAction.custom_time and item.castAction.castActionTime.value or -1
	--释放特效
	ret.castEffect				= Converter(item.castEffect)
	--释放音效
	ret.castSound				= Converter(item.castSound)
	--前摇配置
	ret.preSwingTime			= item.preKillTime.value
	--前摇时忽略技能释放,默认值为true
	ret.ignoreCastSkillPreS		= true
	return ret
end

--抛射物数据
local function missile_data(item)
	local ret = {}
	local boundingVolume ={
	extent ={x = 1,y=1,z=1},
	offset ={x = 0,y=0,z=0},
	rotation ={x = 0,y=0,z=0},
	type ="Box"
	}
	ret.collider		= boundingVolume -- Converter(item.boundingVolume)
	ret.boundingVolume		= nil

	ret.autoRotateColliderBox = true--ret.autoRotateColliderBox == nil and true or ret.autoRotateColliderBox
	ret.lockRotateBodyYaw = 0
	ret.lockRotateBodyPitch = 0
	ret.lockRotateBodyRoll = 0
	ret.rotateFree = true
	ret.followTargetRotationOffset = {x = 0,y = 0,z = 0}
	ret.followTargetRotation = true
			
	ret.moveSpeed			= 0.0--item.moveSpeed / 20
	ret.moveAcc				= 0.0--item.moveAcc / 20
	ret.gravity				= 0.0--item.gravity / 20
	ret.rotateSpeed			= 0.0--item.rotateSpeed / 20

	ret.followTarget		= false --item.followTarget

	ret.lifeTime			= 100--item.lifeTime.value
	ret.vanishTime			= 10 --item.vanishTime.value
	ret.vanishShow			=  false--item.vanishShow

	ret.collideBlock		= 4--tonumber(item.collideBlock)

	ret.startSound			= Converter(item.startSound)
	ret.startEffect			= Converter(item.startEffect)

	ret.hitInterval			= 10--item.hitInterval.value
	--[[
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
	--]]
	ret.collideEntity		= 6
	local hitEntitysRoles = {}
	table.insert(hitEntitysRoles, "hitAllTeam")--item.target_team)
	table.insert(hitEntitysRoles, "hitAllEntitys")--item.target_type)
	table.insert(hitEntitysRoles, "hitAllConfigEntity")--item.target_cfg)
	ret.hitEntitysRoles = hitEntitysRoles
	ret.hitEntitySkill = "myplugin/"..item.skill2
	--[[
	if item.target_team == "hitTargetTeam" then
		local hitTargetTeamIds = {}
		for k,v in pairs(item.teams) do
			hitTargetTeamIds[tostring(v)] = true
		end
		ret.hitTargetTeamIds = hitTargetTeamIds
	end
	if item.target_cfg == "hitTargetConfigEntity" then
		local hitTargetConfigRole = {}
		for k,v in pairs(item.entitys) do
			table.insert(hitTargetConfigRole, {fullName = v})
		end
		ret.hitTargetConfigRole = hitTargetConfigRole
	end
	--]]

	ret.modelMesh = nil
	--ret.modelBlock = "myplugin/acacia_wood_slab"-- nil
	--[[
	if item.missileModel.type == "mesh" then
		ret.modelMesh = item.missileModel.modelMesh.asset
	elseif item.missileModel.type == "block" then
		ret.modelBlock = item.missileModel.modelBlock
	end
	--]]

	ret.isPitch = true--ret.isPitch == nil and true or ret.isPitch
	ret.startWithMoveAcc = true--ret.startWithMoveAcc == nil or ret.startWithMoveAcc

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

	--以上为抛射物的默认属性，以下为组合技能的可编辑属性导出到抛射物属性
	--碰撞体
	ret.collider			= Converter(item.attackBound)
	--可攻击目标类型配置
	local hitEntitysRoles = {}
	table.insert(hitEntitysRoles, item.attackTarget.attackTeam)
	table.insert(hitEntitysRoles, item.attackTarget.targetType)
	table.insert(hitEntitysRoles, item.attackTarget.attackEntity)
	ret.hitEntitysRoles		= hitEntitysRoles
	--可攻击目标队伍id配置
	local hitTargetTeamIds = nil
	if item.attackTarget.attackTeam == "hitTargetTeam" then
		hitTargetTeamIds = {}
		for k,v in pairs(item.attackTarget.teamList) do
			hitTargetTeamIds[tostring(v)] = true
		end
	end
	ret.hitTargetTeamIds	= hitTargetTeamIds
	--可攻击目标模板配置
	local hitTargetConfigRole = nil
	if item.attackTarget.attackEntity == "hitTargetConfigEntity" then
		hitTargetConfigRole = {}
		for k,v in pairs(item.attackTarget.entityList) do
			table.insert(hitTargetConfigRole, {fullName = v})
		end
	end
	ret.hitTargetConfigRole = hitTargetConfigRole

	--命中次数
	--ret.hitCount			= item.hitCount.isValid and item.hitCount.hitCount or nil
	ret.hitEntityCount		= item.isLimit and item.maxAttackNumber or nil

	--存活时间=命中间隔
	ret.lifeTime			= item.lifeTime.value
	ret.hitInterval			= item.lifeTime.value

	--命中音效
	ret.hitEntitySound		= Converter(item.hitEntitySound)

	return ret
end

--伤害技能数据
local function skill2_data(item)
	local ret = {}
	--技能释放方式
	ret.icon = ""
	--item.skillReleaseWay.isClickIcon and Converter(item.skillReleaseWay.icon, "add_asset") or nil
	------------------------------
	local area_number  = 0
	--item.skillReleaseWay.iconPos.area_number
	ret.area_number = area_number 
	ret.backSwingTime = 0
	local pos_tab = {
		{-220, 66, 80},
		{-90, 66, 80},
		{60, 66, 80},
		{200, 66, 80},
		{-126, -366, 70},
		{-20, -366, 70},
		{-228, -68, 88},
		{-190, -200, 88},
		{-58, -238, 88}
	}
	if area_number < 5 then
		ret.horizontalAlignment = 1
		ret.verticalAlignment = nil
	else
		ret.horizontalAlignment = 2
		ret.verticalAlignment = 2
	end
	ret.hurtDistance = 0.1
	ret.area =  {{0, 0},{0, 0}, {0, 0}, {0, 0}}
	ret.customizeSkill = true;
	ret.damage = 1
	ret.dmgFactor = 0
	ret.enableBackSwing = false
	ret.enablePreSwing = false
	------------------------------
	ret.draggingEnabled = false --item.skillReleaseWay.draggingEnabled
	ret.sensitivityFactor = 1 --item.skillReleaseWay.sensitivityFactor
	ret.isClick = false --item.skillReleaseWay.isClick
	ret.isTouch = false --item.skillReleaseWay.isTouch
	ret.cdTime = 0 --item.cdTime.value

	ret.consumeItem = function()
		--[[
		if #item.consumeItem == 0 then
			return
		end
		local consumeItem_array = {}
		for _, it in ipairs(item.consumeItem) do
			local newItem = {}
			if it.itemType.type == "Block" then
				newItem.consumeName = "/block"
				newItem.consumeBlock = it.itemType.block ~= "" and it.itemType.block
			else
				newItem.consumeName = it.itemType.item ~= "" and it.itemType.item
			end
			newItem.count = it.count
			table.insert(consumeItem_array, newItem)
		end
		return consumeItem_array
		--]]
	end
	ret.consumeVp = 0 --item.consumeVp
	ret.container = function()
		--[[
		if (item.container.isValid) then
			return {
				takeNum = item.container.takeNum,
				autoReloadSkill = item.container.autoReloadSkill ~= "" and item.container.autoReloadSkill or nil
			}
		end
		--]]
	end

	ret.frontSight = "" --item.frontSight
	ret.castAction = "" --item.castAction
	ret.castActionTime = -1
	--ret.castSound = Converter(item.castSound)
	--ret.castEffect = Converter(item.castEffect)
	ret.startAction = ""--item.startAction
	ret.startActionTime = 0--Converter(item.startActionTime)
	--ret.startEffect = Converter(item.startEffect)
	ret.sustainAction = ""--item.sustainAction
	--ret.sustainEffect = Converter(item.sustainEffect)
	--ret.stopEffect = Converter(item.stopEffect)
	--ret.targetType = "Self"
	ret.type = "MeleeAttack"-- item.skill.type

	--[[
	ret.missileCount = 1-- #item_base.missile
	ret.missileCfg = {}
	ret.startPos = {}
	ret.startYaw = {}
	ret.startPitch = {}
	ret.bodyYawOffset = {}
	ret.bodyPitchOffset = {}
	ret.startWait = {}

	local i = 1
	ret.startFrom = "foot"
	ret.missileCfg[i] = "myplugin/0c1218ec-8263-4000-a8f8-436f9b7ca3a2"
	--missile.missileCfg
	ret.startPos[i] = {
		x = 0,--missile.startPos.x,
		y = 1.6,--missile.startPos.y,
		z = 0--missile.startPos.z
	}
	ret.startYaw[i] = 0--missile.startYaw
	ret.startPitch[i] = 0-- missile.startPitch
	ret.bodyYawOffset[i] = 0-- missile.bodyYawOffset
	ret.bodyPitchOffset[i] = 0--missile.bodyPitchOffset
	ret.startWait[i] = 0--missile.startWait.value
	]]
	local key, val = next(ret)
		while(key) do
			if type(val) == "function" then
				ret[key] = val()
			end
			key, val = next(ret, key)
	end

	--以上为伤害技能的默认属性，以下为组合技能的可编辑属性导出到伤害技能属性
	--击退距离
	ret.hurtDistance = item.hurtDistance
	--技能伤害
	ret.damage = item.damage

	return ret
end

local function mix_writer(data_dir,id, data, dump)
	assert(type(data) == "table")
	local path = Lib.combinePath(data_dir, id, "setting.json")
	return Seri("json", data, path, dump)
end

local function mix_item_export(ret)
	if ret then
		if ret.skill1 then --技能1的目录
			mix_writer(PATH_SKILL_DATA_DIR,ret.skill1,skill1_data(ret),true)
		end
		if ret.missile then -- 抛射物的目录
			mix_writer(PATH_MISSILE_DATA_DIR,ret.missile,missile_data(ret),true)
		end
		if ret.skill2 then --技能2的目录
			mix_writer(PATH_SKILL_DATA_DIR,ret.skill2,skill2_data(ret),true)
		end
	end
end

local function del_dir_memoryfile(data_dir,id)
	local path = Lib.combinePath(data_dir, id, "setting.json")
	local dir = Lib.combinePath(data_dir, id)
	ItemDataUtils:del(path)
	ItemDataUtils:delDir(dir)
end

local function mix_item_del(id)
	local ret = reader_to_table(id)
	if ret then
		if ret.skill1 then --技能1的目录
			del_dir_memoryfile(PATH_SKILL_DATA_DIR,ret.skill1)
		end

		if ret.missile then -- 抛射物的目录
			del_dir_memoryfile(PATH_MISSILE_DATA_DIR,ret.missile)
		end

		if ret.skill2 then --技能2的目录
			del_dir_memoryfile(PATH_SKILL_DATA_DIR,ret.skill2)
		end
	end
end 

M.config = {
	{
		key = "setting.json",
	
		reader = function(item_name, raw)
			local ret = reader_to_table(item_name)
			if ret then
				Def.filter[ret.skill1] = true
				Def.filter[ret.skill2] = true
				Def.filter[ret.missile] = true
			end
			local path = Lib.combinePath(PATH_DATA_DIR, item_name, "setting.json")
			return Lib.read_file(path, raw)
		end,

		import = function(content, ref, item)
			return ref
		end,

		export = function(rawval, content, save, self)
			local meta = Meta:meta(ITEM_TYPE)
			local item = meta:ctor(rawval)

			local ret
			if content then
				ret = Cjson.decode(content)
			else
				ret = {}
			end

			for k,v in pairs(item) do
				if v ~= nil then
					ret[k] = v
				end
			end
			
			if item.attackBound.type == "Capsule" then
				ret.attackBound.height = item.attackBound.height_c
				ret.attackBound.radius = item.attackBound.radius_c
			end

			if not ret.skill1 then
				ret.skill1 = self:id() --这里表示引用的第一个skill_id  == skill_system_id 
			else 
				if ret.skill1 then --复制粘贴的 
					if self:id() ~= ret.skill1 then
						ret.skill1 = self:id()
						ret.skill2 =  nil
						ret.missile = nil
					end
				end
			end

			if not ret.missile then
				ret.missile = GenUuid()
			end
			if not ret.skill2 then
				ret.skill2 = GenUuid()
			end

			--new_item("skill")
			--new_item("missile")
			--new_item("skill")

			--[[
			local   module = "skill"
			local id = GenUuid()
			local Module = require "we.gamedata.module.module"
			local m = Module:module(module)
			assert(m, module)
			local val =  {name ={ value = "skill_"..id}}
			local id = (id ~= "") and id
			local item = m:new_item(id, val)
			]]
			return ret
		end,

		writer = function(item_name, data, dump)
			--三个文件夹
			assert(type(data) == "table")
			local path = Lib.combinePath(PATH_DATA_DIR, item_name, "setting.json")
			--Lib.pv(data,10,"skill_system")
			local  r = Seri("json", data, path, dump)
			if r then
				mix_item_export(data)
			end
			return r
		end,

		discard = function(item_name)
			local path = Lib.combinePath(PATH_DATA_DIR, item_name, "setting.json")
			mix_item_del(item_name)
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

 M.get_config  =function()
	return M.config
 end

return M
