local setting = require "common.setting"

function Entity.EntityProp:openChestCount(value, add, buff)
    local openCount = self.openCount or 0
    local oldCount = openCount
    if add then
        openCount = openCount + 1
        if openCount == 1 then
            self.vars.canOpenNow = true
        end
    else
        openCount = openCount - 1
        if openCount == 0 then
            self.vars.canOpenNow = false
        end
    end
    self.openCount = openCount
end

local function updataGoldAppleHp(player, extraHp, extraHpLeft, time, flashBeforeMissing)
    player:sendPacket({pid = "SetGoldAppleHp", extraHp = extraHp, extraHpLeft = extraHpLeft, time = time, flashBeforeMissing = flashBeforeMissing})
end

function EntityServer:doAttack(info)
    local attackProps, defenseProps = self:getDamageProps(info)
    local oriDamage = attackProps.oriDamage or 0
    local sloter = self:getHandItem()
    local dodamage = attackProps.damage * attackProps.dmgFactor --道具和技能的伤害读取damage字段
    oriDamage = sloter and 0 or oriDamage --如果手上有道具则没有空手伤害
    dodamage = dodamage > 0 and dodamage or oriDamage --如果有道具或者技能加的伤害就不叠加本身空手伤害
    local damage = math.max(dodamage - math.max(defenseProps.defense - attackProps.deArmour, 0), 0) * attackProps.damagePct
    if damage <= 0 and dodamage > 0 then
        --如果攻击者的攻击力大于0，被攻击者无论entity护甲多高，被攻击了至少要扣1血，张颖说的
        damage = 1
    end
    local target = info.target
    local goldApple = target:data("goldApple")
    local hp = goldApple.hp
    --
    Trigger.CheckTriggers(self:cfg(), "ENTITY_DO_ATTACK", {obj1 = self, obj2 = target, damage=damage, skillName = info.originalSkillName})

    local attackVpConsume = self:prop("attackVpConsume")
    self:addVp(-attackVpConsume)

    if hp and hp > 0 and damage >0 then
        if damage <= hp then
            hp = hp - damage
            goldApple.hp = hp
            Trigger.CheckTriggers(self:cfg(), "ENTITY_DAMAGE", {obj1=target, obj2=self, damageIsCrit = false, damage=damage, skillName = info.originalSkillName})
            Trigger.CheckTriggers(self:cfg(), "ENTITY_DODAMAGE", {obj1 = self, obj2 = target, damageIsCrit = false, damage=damage, skillName = info.originalSkillName})
            updataGoldAppleHp(target, nil, hp, nil, nil)
            return
        end
        damage = damage - hp
        goldApple.hp = 0
        updataGoldAppleHp(target, nil, 0, nil, nil)
    end
	target:doDamage({
		from = self,
		damage = damage,
		skillName = info.originalSkillName,
		damageIsCrit = false,
		cause = info.cause or "NORMAL_ATTACK",
	})
end

function Entity.EntityProp:extraHp(value, add, buff)
    local hp = add and value.hp or 0
    local data = self:data("goldApple")
    data.hp = add and hp
    updataGoldAppleHp(self, hp, hp, buff.endTime - World.Now(), value.flashBeforeMissing)
end

function Entity.EntityProp:recoverHpStepByStep(value, add, buff)
    if add then
        local step = value.step or 1
        local times = value.times or 1
        local interval = value.interval or 20
        buff._times = times
        buff.recoverHpTimer = self:timer(interval, function()
            if self.curHp <= 0 then
                return
            end
            self:addHp(step)
            buff._times = buff._times - 1
            return buff._times > 0
        end)
    elseif buff.recoverHpTimer then
        buff.recoverHpTimer()
        buff.recoverHpTimer = nil
    end
end

function Entity.EntityProp:recoverVpStep(value)
    self:addVp(value)
end
function Entity.EntityProp:recoverHpStep(value)
    self:addHp(value)
end

local function randPos(positions)
	return positions and #positions > 0 and positions[math.random(1, #positions)] or nil
end

function EntityServer:getRebirthPos()
	local pos = self:data("main").rebirthPos
	if pos and type(pos.map) == "string" then
		pos.map = World.CurWorld:getOrCreateStaticMap(pos.map)
	end
	if pos then
		return pos
	end
	local team = self:getTeam()
    if team then
        pos = randPos(team.rebirthPos) or self:getStartPos()
    else
        pos = randPos(World.cfg.revivePos) or self:getStartPos()
    end
	return pos
end

function EntityServer:searchItem(cfgKey, val, type_list)
	assert(type(cfgKey) == "string", tostring(cfgKey))

	type_list = type_list or {
		Define.TRAY_TYPE.BAG,
		Define.TRAY_TYPE.HAND_BAG,
		Define.TRAY_TYPE.EQUIP_1,
		Define.TRAY_TYPE.EQUIP_2,
		Define.TRAY_TYPE.EQUIP_3,
		Define.TRAY_TYPE.EQUIP_4,
		Define.TRAY_TYPE.EQUIP_5,
		Define.TRAY_TYPE.EQUIP_6,
		Define.TRAY_TYPE.EQUIP_7,
		Define.TRAY_TYPE.EQUIP_8,
        Define.TRAY_TYPE.EQUIP_9
	}

	local my_tray = self:tray()
	for _, type in ipairs(type_list) do
		local trayArray = my_tray:query_trays(type)
		for _, element in pairs(trayArray) do
			local tid, tray = element.tid, element.tray
            local items = tray:query_items(function(item)
                local key = item:cfg()[cfgKey]
                if key and next(key)then
                    return true
                else
				    return item:cfg()[cfgKey] == val
                end
			end)

			local slot, item = next(items)
			if slot then
				return Item.CreateSlotItem(self, tid, slot)
			end
		end
	end
end

function EntityServer.Create(params)
    local cfg = Entity.GetCfg(params.cfgName)
	if cfg == nil then return end
    assert(cfg.id, params.cfgName)	-- 没填id_mapping�?
    local entity = EntityServer.CreateEntity(cfg.id)
    if params.name then
        entity.name = params.name
    end
	entity:invokeCfgPropsCallback()
    entity:resetData()
	if params.pos then
		entity:setMapPos(params.map or params.pos.map, params.pos, params.ry, params.rp)
	end
	local mainData = entity:data("main")
	if not entity.isPlayer or (cfg.reviveTime or -1) >= 0 then
		entity:setRebirthPos(params.pos)
	end
    if params.enableAI or params.aiData or cfg.enableAI then
        local p_aiData = params.aiData or {}
        if p_aiData.stand then
            entity:addBuff("myplugin/monster_ai_stand_buff")
        end
        mainData.enableAI = true
        local enableStateMachine = params.enableAIStateMachine
        if enableStateMachine == nil then
            enableStateMachine = cfg.enableAIStateMachine
        end
        for key, value in pairs(p_aiData) do
            entity:setAiData(key, value)
        end
        entity:data("aiData").enableStateMachine = enableStateMachine ~= false
        entity:startAI()	
	end
	if params.owner then
		entity:setValue("ownerId", params.owner.objID)
	end
	entity:setValue("level", params.level or 1, true)
	entity:setValue("camp", params.camp or cfg.clique or cfg.camp or 0, true)
    local entityData = params.entityData or {}
    for k, v in pairs(entityData.vars or params.vars or {}) do
        entity.vars[k] = v
    end
	for key, value in pairs(cfg.passiveBuffs or {}) do
		entity:addBuff(value.name, value.time)
    end

    if entityData.derive then
        entity.vars.editor_data = Lib.copy(entityData.derive)
    end

    Trigger.CheckTriggers(entity:cfg(), "ENTITY_ENTER", {obj1=entity, mapEntityIndex = params.mapEntityIndex})
    entity.createByMapIndex = params.createByMapIndex
	entity.objPatchKey = params.objPatchKey or (os.date("%Y%m%d%H%M%S",os.time())..entity.objID)
	if not params.notNotifyMapPatchMgr then
		MapPatchMgr.ObjectChange(params.map or (params.pos and params.pos.map), 
			{change = "create", objId = entity.objID, pos = params.pos, yaw = params.ry, pitch = params.rp, isEntity = true, 
				createByMapIndex = entity.createByMapIndex, objPatchKey = entity.objPatchKey, fullName = entity:cfg().fullName, notNeedSaveToPatch = entity:cfg().notNeedSaveToPatch})
	end
	MapPatchMgr.RegistCreateByMapEntityToTable(entity.objID, entity.createByMapIndex)
    return entity
end

function EntityServer:doDropDamage(speed)
	if not self:cfg().dropDamageEnable then
        return
    end
	self:doDamage({
		damage = speed * self:prop("dropDamageRatio"),
		cause = "ENGINE_DO_DROP_DAMAGE",
	})
end

function EntityServer:AttackDamage()
    local sloter = self:getHandItem()
    local oriDamage = self:prop("oriDamage") or 0
    local dodamage = self:prop("damage") --道具和技能的伤害读取damage字段
    oriDamage = sloter and 0 or oriDamage --如果手上有道具则没有空手伤害
    dodamage = dodamage > 0 and dodamage or oriDamage --如果有道具或者技能加的伤害就不叠加本身空手伤害
    return dodamage
end

function EntityServer:TemporaryShield()
    local equipTrays = {}
    for _, tpy in pairs(self:cfg().equipTrays or {}) do
        local trays = self:tray():query_trays(tpy)
        for _, trayTb in pairs(trays or {}) do
            equipTrays[#equipTrays + 1] = {tray = trayTb.tray, tid = trayTb.tid}
        end
    end
    local equips = {}
    for _, trayTb in pairs(equipTrays) do
        local item = self:tray():fetch_tray(trayTb.tid):fetch_item_generator(1)
        if item then
            equips[#equips + 1] = item
        end
    end
    local handItem = self:getHandItem()
    if handItem and not handItem:null() then
        equips[#equips + 1] = handItem
    end
    local maxTS = 0
    local curTs = 0
    for i, item in pairs(equips) do
        local iets = item and not item:null() and item:cfg().equipTemporaryShield or -1
        if iets and iets > 0 then
            maxTS = maxTS + iets
            curTs = curTs + math.max(item:getVar("equipTemporaryShield") or 0, 0)
        end
    end
    if maxTS == 0 or curTs == 0 then
        return 0
    end
    curTs = math.ceil(curTs)
    maxTS = math.ceil(maxTS)
    return curTs .. "/" .. maxTS
end

function EntityServer:ValHurtDistance()
    local handItem = self:getHandItem()
    if not handItem or handItem:null() then
        return 0
    end
    local val = 0
    local skills = handItem:cfg().skill
    for _, skill in pairs(skills or {}) do
        local cfg = setting:fetch("skill", skill)
        val = val + (cfg.hurtDistance or 0)
    end
    return val
end

function EntityServer:ValEfficient()
    local handItem = self:getHandItem()
    local handVal = 0
    if handItem and not handItem:null() then
        local cfg = handItem:cfg()
        handVal = cfg.effAllBlock and cfg.effAllBlock or 0
    end
    return handVal
end

function EntityServer:hpPercent()
    local hp = self.curHp
    local mxHp = self:prop("maxHp")
    if hp <= 0 or mxHp == 0 then
        return 0
    end
    hp = math.ceil(hp)
    return hp .. "/" .. mxHp
end

function EntityServer:addItem2(fullName, count, proc, reason)
    if not self:tray():add_item2(fullName, count, proc, true) then
        return false
    end
    self:tray():add_item2(fullName, count, proc, false, reason)
    return true
end

function EntityServer:serverRebirth(map, pos, yaw, pitch)
    local context = {obj1=self, canRebirth = true}
    Trigger.CheckTriggers(nil, "ENTITY_CAN_REBIRTH", context)
    if not context.canRebirth then
        return
    end
    local packet = {
        pid = "EntityRebirth",
        objID = self.objID,
    }
    self:sendPacketToTracking(packet, true)
	self:resetData()
	if pos and pos.map then
		map = pos.map
	end
	if map and type(map) == "string" then
		map = World.CurWorld:getOrCreateStaticMap(map)
	end
    local rebPos
    if Game.GetState() == "GAME_INIT" or Game.GetState() == "GAME_REWAIT" then
        rebPos = self:getInitPos()
    else
        rebPos = self:getRebirthPos()
    end
    local targetPos = Lib.v3(rebPos.x, rebPos.y, rebPos.z)
	self:setMapPos(map or rebPos.map, pos or targetPos, yaw, pitch)
	-- WorldServer.SystemChat(0, "system.message.player.rebirth.server", self.name)
	if self:data("main").enableAI then
		self:startAI()
	end
	Trigger.CheckTriggers(self:cfg(), "ENTITY_REBIRTH", {obj1=self})
    --to trigger in block buff
    local tm = map or rebPos.map or self.map
    local tp = pos or targetPos
    tp.x = math.floor(tp.x)
    tp.y = math.floor(tp.y)
    tp.z = math.floor(tp.z)
    tm = World.CurWorld:getMap(tm)
	Trigger.CheckTriggers(self:cfg(), "IN_BLOCK_CHANGED", {obj1 = self, oldId = 0, newId = tm:getBlockConfigId(tp)})
end

function EntityServer:getInitPos()
	local worldCfg = World.cfg
	local team = self:getTeam()
	local pos = self:data("main").initPos
	if pos then
		return pos
	end
	return team and team.initPos or worldCfg.initPos
end

function EntityServer:monsterDisappear()
    self:addBuff("myplugin/hide_entity")
    self:addBuff("myplugin/smoke_buff", 30)
    self:setHp(0)
    self:stopAI()
end

function EntityServer:monsterAppear()
    if self.curHp <= 0 then
        self:serverRebirth()
        self:removeTypeBuff("fullName", "myplugin/hide_entity")
        self:addBuff("myplugin/smoke_buff", 30)
    else
        self:setHp(self:prop("maxHp"))
    end
end


function EntityServer:checkPlayerDistance(player,monstersCheckInterval,monstersOutRange,monstersDieRange)
    monstersCheckInterval = monstersCheckInterval or 10
    monstersOutRange = monstersOutRange or 24
    monstersDieRange = monstersDieRange or 108
    self.checkPlayerDistanceTimer = self:lightTimer( "checkPlayerDistance" ,20 * monstersCheckInterval, function() 
        if not (player and player:isValid()) then
            return false
        end
        local dis = Lib.getPosDistance(self:getPosition(), player:getPosition())
        if dis > monstersDieRange then
            self:destroy()
            return
        end
        return true
    end)
end

function EntityServer:onEntityDie()
    if self.checkPlayerDistanceTimer then
        self.checkPlayerDistanceTimer()
        self.checkPlayerDistanceTimer = nil
    end
end