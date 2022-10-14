local misc = require "misc"
local setting = require "common.setting"
require "common.entity"
require "entity.entity_event"
require "entity.ai.ai_control"
local ai_control_mgr = require "entity.ai.ai_control_mgr" ---@type ai_control_mgr
local entity_camp = require "entity.entity_camp"
local math_random = math.random
local math_max = math.max

---@type Entity
local Entity = Entity

function Entity:isAlivePlayer()
    if not self:isValid() or not self.isPlayer then
        return false
    end
    if self.Logouting then
        return false
    end
    return true
end

function Entity.EntityProp:ownerBuff(value, add, buff)
	local owner = self:owner()
	if not owner or owner.objID==self.objID then
		return
	end
	if add then
		buff.ownerBuff = owner:addBuff(value)
	elseif buff.ownerBuff then
		owner:removeBuff(buff.ownerBuff)
		buff.ownerBuff = nil
	end
end

local function getSync(value)
	return (not value or value == true) and "all" or value
end

function Entity.EntityProp:skin(value, add, buff)
	local sync = getSync(buff.cfg.sync)
	local skinInfo = self:data("skin")
	local buffSkin = self:data("buffSkin")
	local realSkillInfo  = ActorManager:Instance():getActorDefaultBodyPart(self:data("main").actorName or self:cfg().actorName or "boy.actor") or {}
	if not self:CheckIsDefaultActor() then 
		for k , v in pairs(skinInfo) do 
			realSkillInfo[k] = v
		end
	end

	if add then
		for k , v in pairs(value) do 
			buffSkin[k] = buffSkin[k] or {}
			if #buffSkin[k] < 1 then 
				if realSkillInfo[k] then 
					table.insert(buffSkin[k],{name = "" , skin = realSkillInfo[k]})
				else 
					table.insert(buffSkin[k],{name = "", skin = ""})
				end
			end
			table.insert(buffSkin[k],{buffCfg = buff.cfg, skin = v})
		end 
		self:changeSkinPart(value, sync)
	else
		local reset = {}
		for k , v in pairs(value) do
			buffSkin[k] = buffSkin[k] or {}
			local skinName = nil
			local i
			for i = 1 , #buffSkin[k] do 
				if buffSkin[k][i].buffCfg == buff.cfg then
					table.remove(buffSkin[k] , i)
					skinName = buffSkin[k][#buffSkin[k]] and buffSkin[k][#buffSkin[k]].skin or nil
					break
				end
			end
			reset[k] = skinName 
		end
		self:changeSkinPart(reset, sync)
	end
end

function Entity.EntityProp:skill(value, add, buff)
	local buffSkill = self:data("buffSkill")
	if add then
		buffSkill[buff.id] = value
	else
		buffSkill[buff.id] = nil
	end
	self:syncSkillMap()
end

function Entity.EntityProp:continueHeal(value, add, buff)
	if value == 0 then
		return
	end
	local continueHeal = self:data("continueHeal")
	continueHeal.heal = (continueHeal.heal or 0) + (add and value or -value)
	if not continueHeal.timer then
		continueHeal.timer = self:timer(20, function()
			self:addHp(continueHeal.heal)
			if continueHeal.heal <= 0 then
				continueHeal.timer = nil
				return false
			end
			return true
		end)
	end
end

function Entity.EntityProp:continueDamage(value, add, buff)
	if value == 0 then
		return
	end
	local continueDamage = self:data("continueDamage")
	continueDamage.damage = (continueDamage.damage or 0) + (add and value or -value)
	if add then
		continueDamage.time = World.Now()
	elseif not buff.cfg.calPerSecond then
		local damage = value * ((continueDamage.time and (World.Now() - continueDamage.time) or 0) / 20)
		self:doDamage({
			damage = damage,
			cause = "ENGINE_PROP_DAMAGE",
			from = buff.from and not buff.from.removed and buff.from or nil
		})
	end
	if not continueDamage.timer then
		continueDamage.timer = self:timer(20, function()
			self:doDamage({
				damage = continueDamage.damage,
				cause = "ENGINE_PROP_CONTINUE_DAMAGE",
				from = buff.from and not buff.from.removed and buff.from or nil
			})
			continueDamage.time = World.Now()
			if continueDamage.damage <= 0 then
				continueDamage.timer = nil
				return false
			end
			return true
		end)
	end
	if add and buff.cfg.initDamage then
		self:doDamage({
			damage = buff.cfg.initDamage,
			cause = "ENGINE_PROP_INIT_CONTINUE_DAMAGE",
			from = buff.from and not buff.from.removed and buff.from or nil
		})
	end
end

function Entity.EntityProp:fly(value, add, buff)
	self:setFly(add, buff.endTime and buff.endTime - World.Now() or 0)
end

function Entity.EntityProp:trigger(value, add, buff)
	if add and type(value.add)=="string" then
		Trigger.CheckTriggers(buff.cfg, value.add, {obj1=self})
	elseif not add and type(value.remove)=="string" then
		Trigger.CheckTriggers(buff.cfg, value.remove, {obj1=self})
	end
end

function Entity:setFly(flag, time)
	local oldState = self.isFlying
	if flag then
		self.isFlying = true
		self.flyEnd = World.Now() + time
	else
		if self.isFlying and World.Now() >= self.flyEnd then
			self.isFlying = false
		end
	end

	if oldState ~= self.isFlying then
	    local packet = {
	        pid = "EntityFly",
	        objID = self.objID,
	        flyTime = self.flyEnd - World.Now(),
	        flag = flag
	    }
	    self:sendPacketToTracking(packet, true)

		-- if not self.isFlying then
		-- 	Trigger.CheckTriggers(self:cfg(), "FLY_END", {obj1 = self, pos = self:getPosition()})
		-- end
	end
end

function Entity.ValueFunc:level(level)
	local data = self:data("main")
	if data.levelBuff then
		self:removeBuff(data.levelBuff)
		data.levelBuff = nil
	end
	if self.isPlayer then
		self:addTarget("Level", level)
	end
	local levelBuffName = self:cfg().levelBuffName
	if not levelBuffName then
		return
	end
	local cfg
	for l = level, 0, -1 do
		cfg = Entity.TryBuffCfg(levelBuffName .."_"..l)
		if cfg then
			data.levelBuff = self:addBuff(cfg.fullName)
			break
		end
	end
end


local function _setError(tb, key)
	error("don't set prop: " .. key)
end

---@class EntityServer : Entity
local EntityServer = EntityServer

function EntityServer:initData()
	Entity.initData(self)
	self.vars = Vars.MakeVars("entity", self:cfg())
	self.vars.prop = {
		vars = setmetatable({}, {__index=self._prop, __newindex=_setError}),
	}
	self.spawnSyncVals = {}

	self:initSkill()
end

function EntityServer:spawnBuffList(buffList, isSameTeam)
	for id, buff in pairs(self:data("buff")) do
		local sync = buff.cfg.sync or "all"
		if sync=="all" or sync=="other" then
			buffList[id] = buff.cfg.fullName
		end
		if sync=="team" and isSameTeam then
			buffList[id] = buff.cfg.fullName
		end
	end
	return buffList
end

local baseSpawnInfo = {
	pid = "EntitySpawn",
	name = nil,
	cfgName = nil,
	cfgID = nil,
	objID = nil,
	pos = nil,
	rotationYaw = nil,
	rotationPitch = nil,
	rotationRoll = nil,
	uid = nil,
	movingStyle = nil,
	curHp = nil,
	curVp = nil,
	skin = nil,
	handItem =  nil,
	rideOnId = nil,
	rideOnIdx = nil,
	headText = nil,
	values = nil,
	buffList = {},
	actorName = nil,
	isPlayer = nil,
	entityToBlock = nil,
	passengers = nil,
	entityUI = nil,
	targetId = nil,
	mode = nil,
	flyMode = nil,
	props = nil,
	isDead = nil
}
function EntityServer:spawnInfo()
    local sloter
    if self.isPlayer then
        sloter = self:getHandItem()
    end
	
	local values = self.spawnSyncVals--{}
	-- for key, def in pairs(Entity.ValueDef) do
	-- 	if self:spawnNeedSync(key) then
	-- 		local value = self:getValue(key)
	-- 		values[key] = value
	-- 	end
	-- end

	local skin = self:data("skin")
	if not skin or not next(skin) then
		skin = self:cfg().skin
	end
	

	local mainValue = self:data("main")
    local info = Lib.copy(baseSpawnInfo)
	info.name = self.name
	info.cfgName = self:cfg().fullName
	info.cfgID = self:getCfgID()
    info.objID = self.objID
    info.pos = self:getPosition()
	info.scale = self:getEntityScale()
    info.rotationYaw = self:getRotationYaw()
	info.rotationPitch = self:getRotationPitch()
	info.rotationRoll = self:getRotationRoll()
    info.uid = self.platformUserId
    info.movingStyle = self.movingStyle
    info.curHp = self.curHp
    info.curVp = self.curVp
	info.skin = skin
    info.handItem =  sloter and not sloter:null() and sloter:seri()
    info.rideOnId = self.rideOnId
    info.rideOnIdx = self.rideOnIdx
	info.headText = self:data("headText").ary
	info.values = values
	--info.buffList = {}
	info.actorName = mainValue.actorName or (self:cfg().actorName and self:cfg().actorName  ~= "" and self:cfg().actorName) or "boy.actor"
	info.isPlayer = self.isPlayer
	info.entityToBlock = mainValue.entityToBlock
	info.passengers = self:data("passengers") or {}
	info.entityUI = self:data("entityUI")
	info.targetId = self:getTargetId()
	info.mode = self:getMode()
	info.flyMode = 0
	info.props = self:data("prop")
	info.isDead = self.curHp <= 0
	info.instanceId = self:getInstanceID()
	if self.isInsteance then
		info.isInsteance = true
		info.properties = self.properties
	end
	return info
end

function EntityServer:calcBuff(buff, add,from)
	local prop = self:prop()
	local maxHp = prop.maxHp
	local hpRatio = self.curHp / maxHp
	Entity.calcBuff(self, buff, add,from)
	if maxHp ~= prop.maxHp then
		self:setHp(hpRatio * prop.maxHp)
	end
end

local function calcSendPacket(self, packet, sync)
	if sync=="all" then
		self:sendPacketToTracking(packet, true)
	elseif sync=="self" then
		if self.isPlayer then
			self:sendPacket(packet)
		end
	elseif sync=="team" then
		local team = self:getTeam()
		if team then
			team:broadcastPacket(packet)
		end
	elseif sync=="other" then
		self:sendPacketToTracking(packet, false)
	end
end

local function sendBuffPacket(self, buff, packet)
	packet.id = buff.id
	packet.objID = self.objID
	local sync = buff.cfg.sync or "all"
	calcSendPacket(self, packet, sync)
end
local function passiveBuffsPick(self,name)
	if not self:cfg().passiveBuffs then
		return false
	end
	local isPick = false
	for _, buff in pairs(self:cfg().passiveBuffs) do
		if buff.name == name then
			isPick = true
			break
		end
	end
	return isPick
end
local function onlyBuffsPick(self,name)
	if not self:cfg().onlyBuffs then
		return false
	end
	local isPick = false
	for _, buffName in pairs(self:cfg().onlyBuffs) do
		if buffName == name then
			isPick = true
			break
		end
	end
	return isPick
end
function EntityServer:addBuff(name, time, from)
	--print("-------------addBuff-------------------------",name)
	local cfg = Entity.BuffCfg(name)
	local forPlayer = cfg.forPlayer
	if forPlayer~=nil and self.isPlayer~=forPlayer then
		return nil
	end

	if World.cfg.allEntityRejectBuff and
		not self.isPlayer and
	   not self:cfg().canBuffed and
	   not passiveBuffsPick(self,name) and
	   not onlyBuffsPick(self,name) then--未配置canBuffed的entity无法被上buff
		return nil
   end

	for _, nm in ipairs(cfg.avoidBuff or {}) do
		if not nm:find("/") then
			nm = cfg.plugin .. "/" .. nm
		end
		if self:getTypeBuff("fullName", nm) then
			return nil
		end
	end
	for _, nm in ipairs(cfg.removeBuff or {}) do
		if not nm:find("/") then
			nm = cfg.plugin .. "/" .. nm
		end
		self:removeTypeBuff("fullName", nm)
	end
	local fixTime = cfg.appendTime and "append" or cfg.fixTime
	local buff = fixTime and self:getTypeBuff("fullName", cfg.fullName)
	if buff then
		if buff.timer then
			buff.timer()
			buff.timer = nil
		end
		if buff.endTime or fixTime == "reset" then
			local restTime
			if not time then
				buff.endTime = nil
				restTime = nil
			elseif fixTime == "append" then
				buff.endTime = buff.endTime + time
				restTime = buff.endTime - World.Now()
			elseif fixTime == "reset" then
				buff.endTime = time and World.Now() + time
				restTime = time
			elseif fixTime == "max" then
				local leftTime = buff.endTime - World.Now()
				if leftTime >= time then
					restTime = leftTime
				else
					restTime = time
					buff.endTime = World.Now() + time
				end
			else
				assert(false, string.format("wrong value: %s, value range: append, reset, max", fixTime))
			end
			if restTime then
				buff.timer = self:lightTimer("resetBuff", restTime, EntityServer.removeBuff, self, buff)
			end
			sendBuffPacket(self, buff, {pid="ChangeBuffTime", restTime=restTime})
		end
	else
		local list = self:data("buff")
		buff = {
			cfg = cfg,
			id = #list + 1,
			owner = self,
			from = from
		}
		if time then
			buff.endTime = World.Now() + time
			buff.timer = self:lightTimer("removeBuff", time, EntityServer.removeBuff, self, buff)
		end
		list[buff.id] = buff
		sendBuffPacket(self, buff, {pid="AddBuff", fromID = from and from.isEntity and from:isValid() and from.objID, name=name, time=time})
		self:calcBuff(buff, true,from)
	end
	if not cfg.appendTime then
		return buff
	end
	buff.addTimes = (buff.addTimes or 0) + 1
	-- 返回一个看起来跟原buff相似的“子buff”，额外有一个独立的addTime�
	return setmetatable({addTime=time or false}, {__index=buff,__newindex=buff})
end

function EntityServer:removeBuff(buff)
	--print("-------------removeBuff1-------------------------",buff.cfg.fullName)
	if not buff then
		return
	end
	if buff.removed then	--可能被叠加规则、超时等情况清除掉了
		return
	end
	if buff.addTime~=nil then	-- 是一个加时用途的“子buff�
		rawset(buff, "removed", true)	-- “子buff”被清除
		buff.addTimes = buff.addTimes - 1
		if buff.endTime then	-- 有限时间
			buff.timer()
			buff.timer = nil
			buff.endTime = buff.endTime - assert(buff.addTime)
			local restTime = buff.endTime - World.Now()
			if restTime>0 then
				buff.timer = self:timer(restTime, EntityServer.removeBuff, self, buff)
				sendBuffPacket(self, buff, {pid="ChangeBuffTime", restTime=restTime})
				assert(buff.addTimes>0)
				return
			end
		elseif buff.addTimes>0 then	-- 无限时间，只考虑叠加�
			return
		end
	end
    if buff.timer then
        buff.timer()
        buff.timer = nil
    end

    --buff同步要先与buff属性计�
    --calcBuff可能会调用到TRIGGER,如果在其中addbuff,会破坏前后端buffid的一致�
    sendBuffPacket(self, buff, {pid="RemoveBuff"})
	self:data("buff")[buff.id] = nil
	self:calcBuff(buff, false)
    buff.id = nil
	buff.owner = nil
	buff.removed = true

    local legacyBuff = buff.cfg.legacyBuff
    if legacyBuff then
        self:addBuff(legacyBuff.cfg, legacyBuff.time)
    end
end

function EntityServer:getTypeBuff(key, value)
	for id, buff in pairs(self:data("buff")) do
		if buff.cfg[key] == value then
			return buff
		end
	end
end

function EntityServer:removeTypeBuff(key, value)--扩展�返回卸载buff的fullName 列表
	local reLoadNames = {}
	local reLoadTimes = {}
	local reloadFroms = {}
	local reloadExtraParams = {}
	local list = {}
	for id, buff in pairs(self:data("buff")) do
		if (value ==nil and buff.cfg[key]) or (value and buff.cfg[key] == value)  then--扩展�当value不传，则卸载所有包含key的buff
			list[#list + 1] = buff
		end
	end
	local now = World.Now()
	for _, buff in ipairs(list) do
		local lastTime = false
		if buff.endTime then
			lastTime = buff.endTime - now
		end
		local extraParams = buff.extraParams or {}
		local from = false
		if buff.from then
			from = buff.from
		end

		self:removeBuff(buff)
		table.insert(reLoadNames, buff.cfg.fullName)
		table.insert(reLoadTimes, lastTime)
		table.insert(reloadFroms, from)
		table.insert(reloadExtraParams, extraParams)
	end
	return reLoadNames,reLoadTimes, reloadFroms, reloadExtraParams
end

---@param packet PidPacket
function EntityServer:sendPacketToTracking(packet, includeSelf)
	local pid = packet.pid
	packet = Packet.Encode(packet)
	local data = misc.data_encode(packet)
    local count = self:sendScriptPacketToTracking(data, includeSelf)
	World.AddPacketCount(pid, #data, true, count)
end

function EntityServer:onDead(deathInfo)
	local from, skillName, related = deathInfo.from, deathInfo.skillName, deathInfo.related
	local deathCause = assert(deathInfo.cause, "must have a cause of death")
	self:stopAI()
	self:clearRide()
	self:setForceMove()
	local cfg = self:cfg()
    local owner = from and not from.removed and from:owner() or nil

	local packet = {
		pid = "EntityDead",
		objID = self.objID,
		fromID = from and from.objID,
		ownerID = owner and owner.objID,
	}
	self:sendPacketToTracking(packet, true)

    if owner and owner.isPlayer then
        Trigger.CheckTriggers(owner:cfg(), "KILL_ENTITY", {obj1 = owner, obj2 = self})
		owner:EmitEvent("OnKillEntity", self)
    end
	local weapon = (from and not from.removed) and (from:getSkillEquip(skillName) or from:getHandItem())
	local context = { obj1 = self, obj2 = from, dieDrop = true, weapon = weapon and weapon:cfg().fullName, skillName = skillName, cause = deathCause, dieRemove = true, map = self.map }
	Trigger.CheckTriggers(cfg, "ENTITY_DIE", context)
    self:EmitEvent("OnEntityDie", owner)
	self:removeTypeBuff("deadRemove", true)
	if context.dieDrop then
		self:dropOnDie(from)
	end
	if context.dieRemove then
		self:removeOnDie()
	end
	if from and not from.removed then
		local logDesc = string.format("%s kill %s by %s", from.name, self.name, skillName or "(unknown skill)")
		from:data("main").kills = (from:data("main").kills or 0) + 1
		if from.isPlayer then
			if self.isPlayer then
				from:addTarget("KillPlayer")
				related = related or {}
				from:bhvLog("kill_player", logDesc, self.platformUserId, related)
				self:bhvLog("killedby_player", logDesc, from.platformUserId, related)
			else
				from:addTarget("KillNpc", cfg.fullName)
				from:bhvLog("kill_npc", logDesc, cfg.fullName, related)
			end
		elseif self.isPlayer then
			self:bhvLog("killedby_npc", logDesc, from:cfg().fullName, related)
		end
		from:addExp(cfg.entityExp or 0, "kill_entity")
	elseif self.isPlayer then
		self:bhvLog("killed_self", string.format("%s dead", self.name), nil, related)
	end

	local reviveTime = cfg.reviveTime or -1
	local delay = cfg.destroyTime or 0
	if self.isPlayer then
		Game.checkGameOverWithPlayerDead({from = from, target = self})
	elseif cfg.deadDoNothing then
		-- do noting
	elseif reviveTime >= 0 then
		self:timer(reviveTime, EntityServer.serverRebirth, self)
	elseif self.isRevive then
	-- 	self:timer(1 + delay, EntityServer.serverRebirth, self)
	elseif reviveTime < 0 then
		self:timer(1 + delay, EntityServer.destroy, self)
	end
	self.isRevive = nil
end

function EntityServer:dropDropitem(params)
	local map, selfPos, imcV3, item, lifeTime, pitch, yaw, moveSpeed, moveTime, guardTime =
		params.map, params.selfPos, params.imcV3, params.item, params.lifeTime, params.pitch, params.yaw, params.moveSpeed, params.moveTime, params.guardTime 
	local dropitemMoveSpeed, dropitemMoveTime = moveSpeed, moveTime
	local dropitemSpreadOut = self:cfg().dropitemSpreadOut
	--[[ dropitemSpreadOut: {time, speed} ]]
	if dropitemSpreadOut then
		local speed = dropitemSpreadOut.speed
		if speed then
			imcV3 = {x = 0, y = 1, z = 0}
			dropitemMoveTime = math_max(5, dropitemSpreadOut.time)
			dropitemMoveSpeed = {
				x = speed/2 - math_random() * speed,
				y = math_max(0.25, (speed/2 - math_random() * speed) * 0.5),
				z = speed/2 - math_random() * speed
			}
		end
	end
	Trigger.CheckTriggers(self:cfg(), "ENTITY_DROP_ITEM", {obj1 = self, item = item})
	local item_pos = Lib.v3add(imcV3, selfPos)
	return DropItemServer.Create({
		map = map, pos = item_pos, item = item, lifeTime = lifeTime,
		pitch = pitch, yaw = yaw, moveSpeed = dropitemMoveSpeed, moveTime = dropitemMoveTime, guardTime = guardTime
	})
end

function EntityServer:dropOnDie(from)
	if self:isWatch() then
		return
	end
	if self.curHp > 0 then
		return
	end
	local dropItems = self:cfg().dropItem
	if not dropItems then
		return
	end
	local pos = self:getPosition()
	local random = math.random
	for _, val in pairs(dropItems) do
		if random() >= (val.probability or 1) then
			goto continue
		end
		local imcV3 = Lib.tov3({
			x = 0.5 + (random()-0.5) * #dropItems * (val.mulDiffx or 1),
			y = 0.8 * (val.mulDiffy or 1),
			z = 0.5 + (random()-0.5) * #dropItems * (val.mulDiffz or 1)
		})
		local item = Item.CreateItem(val.item, val.count)
		local cfg = item:cfg()
		local dropItem = self:dropDropitem({
			map = self.map, selfPos = pos, imcV3 = imcV3, item = item, 
			lifeTime = cfg.droplifetime, guardTime = val.guardTime 
		})
		if from and cfg.dropOwn then
			dropItem:setData("ownerId", from.objID)
		end

		::continue::
	end
end

function EntityServer:removeOnDie()
end

function EntityServer:RandomArea(commonTable,paramTable)
	if commonTable == nil then
		return paramTable[1]
	else
		for _,v in pairs(paramTable) do
			if commonTable.x < v.min.x or commonTable.x > v.max.x then
				return v
			end
		end
	end
end

function EntityServer:canAttack(target)
	if not Entity.canAttack(self, target) then
		return false
	end
	local context = {obj1=self, obj2=target, canAttack = true}
	Trigger.CheckTriggers(self:cfg(), "CHECK_CAN_ATTACK", context)
	if not context.canAttack then
		return false
	end
	return true
end

function EntityServer:getDamageProps(info)
	local skill = info.skill
	local target = assert(info.target, "need target")
	local attackProps = setmetatable({}, {
		__index = function(t, name)
			local value = assert(self:prop(name), string.format("Entity doesn't have prop named '%s'", tostring(name)))
			return value + (skill and skill[name] or 0)
		end,
		__newindex = function(...) error("not allowed set prop value") end
	})
	local defenseProps = setmetatable({}, {
		__index = function(t, name)
			return assert(target:prop(name), string.format("Entity doesn't have prop named '%s'", tostring(name)))
		end,
		__newindex = function(...) error("not allowed set prop value") end
	})
	return attackProps, defenseProps
end

local function getDamage(info)
	local attackProps, defenseProps, damageFrom, damageTarget, skill = info.attackProps, info.defenseProps, info.damageFrom, info.damageTarget, info.skill
	local skill_useExpressionPropMap, from_useExpressionPropMap = skill and skill.useExpressionPropMap or {}, damageFrom:cfg().useExpressionPropMap or {}
	local damageExpression = skill_useExpressionPropMap.damageExpression or from_useExpressionPropMap.damageExpression
	return damageExpression and Lib.getExpressionResult(damageExpression, {target = damageTarget, from = damageFrom, packet = {}}) or 
		math_max(attackProps.damage * (attackProps.dmgFactor - defenseProps.deDmgPct) - defenseProps.defense, 0) * attackProps.damagePct
end

function EntityServer:doAttack(info)
	local attackProps, defenseProps = self:getDamageProps(info)
	local damage = getDamage({attackProps = attackProps, defenseProps = defenseProps, damageFrom = self, damageTarget = info.target, skill = info.skill})

	return info.target:doDamage({
		from = self,
		damage = damage,
		skillName = info.originalSkillName,
		damageIsCrit = false,
		cause = info.cause or "NORMAL_ATTACK",
	})
end

function EntityServer:calcDamage(info)
	return info.damage
end

function EntityServer:takeDamage(damage, from, isFormula, cause)
	cause = cause or "takeDamage"
	if isFormula then
		local attackProps = from and from:getDamageProps({skill = {damage = damage}, target = self}) or {damage = damage, dmgFactor = 1, damagePct = 1}
		local defenseProps = self:prop()
		damage = getDamage({attackProps = attackProps, defenseProps = defenseProps, damageFrom = from, damageTarget = self})
	end
	self:doDamage({damage = damage, from = from, cause = cause})
end

function EntityServer:doDamage(info)
	if not self:isValid() then
		return 0
	end

	if self:isWatch() then
		return 0
	end
	local damage, from, isRebound = info.damage, info.from, info.isRebound
	damage = self:calcDamage(info)
	local damageCause = assert(info.cause, "must have a cause of doDamage")
	Trigger.CheckTriggers(self:cfg(), "ENTITY_PRE_DAMAGE", {obj1=self, obj2=from, damageIsCrit = info.damageIsCrit or false, damage=damage, skillName = info.skillName})
	local oriDamage = damage
	if self:prop("undamageable")>0 and not(damageCause == "ENGINE_TOUCHDOWN") then
		return 0
	elseif damage <= 0 then
		return 0
	elseif self.curHp <= 0 then
		return 0
	elseif isRebound then
		self:addHp(-damage)
		if self.curHp <= 0 then
			self:onDead({
				from = from and not from.removed and from or nil,
				cause = damageCause or "ENGINE_DO_DAMAGE_REBOUND",
			})
		end
		return damage
	end

    if self:prop("enableDamageProtection") > 0 and self.lastDamageTime and self.lastDamageTime + self:prop("damageProtectionTime") > World.Now() then
        return 0
    end
    
	local immue = self:data("immue")
    if immue.lastDamage == nil then
        immue.lastDamage = 0
		immue.hurtResistantTime = 0
    end
	-- 免疫伤害时间内，只承受最大的那一次伤�
	local isOpenImmue = World.cfg.isOpenImmue == nil and true or World.cfg.isOpenImmue -- 是否启用免疫，没配则默认启用
    if isOpenImmue and immue.hurtResistantTime >= World.Now() then
        if damage <= immue.lastDamage then
			return 0
        end
        damage = -self:addHp(-damage + immue.lastDamage)
		immue.lastDamage = immue.lastDamage + damage
    else
        immue.hurtResistantTime = World.Now() + (self:cfg().hurtResistantTime or 20)
        immue.lastDamage = damage
        damage = -self:addHp(-damage)
    end

    self.lastDamageTime = World.Now()

	Trigger.CheckTriggers(self:cfg(), "ENTITY_DAMAGE", {obj1=self, obj2=from, damageIsCrit = info.damageIsCrit or false, damage=damage, oriDamage = oriDamage, skillName = info.skillName, cause = damageCause})
	self:EmitEvent("OnEntityHurt", from, { damage=damage, skillName = info.skillName, cause = damageCause })
    if from then
        Trigger.CheckTriggers(from:cfg(), "ENTITY_DODAMAGE", {obj1 = from, obj2 = self, damageIsCrit = info.damageIsCrit or false, damage=damage, oriDamage = oriDamage, skillName = info.skillName})
		from:EmitEvent("OnDoDamage", self, { damage=damage, skillName = info.skillName, cause = damageCause })
    end
    if self.isPlayer and from then
        self:sendPacket({pid = "BeAttacked", fromId = from.objID})
    end
	if from and from ~= self then
		if damage > 0 then
			local lifeSteal = from:prop("lifeSteal") * damage
			if lifeSteal > 0 then
				from:addHp(lifeSteal)
			end
			local dmgRebound = self:prop("dmgRebound") * damage
			if dmgRebound > 0 then
				from:doDamage({
					damage = dmgRebound,
					from = self,
					isRebound = true,
					cause = "ENGINE_DO_DAMAGE_REBOUND",
				})
			end
		end
		if from and from:isValid() and from.curHp > 0 then
			self:handleAIEvent("onHurt", from, damage)
		end
	end

	local damageVpConsume = self:prop("damageVpConsume")
	self:addVp(-damageVpConsume)

	if not self.removed and self.curHp <= 0 then
        self:onDead({
			from = from and not from.removed and from or nil,
			skillName = info.skillName,
			cause = damageCause or "ENGINE_DODAMAGE",
		})
    end

	return damage
end

function EntityServer:kill(from, cause)
    if self.curHp <= 0 then
        return
    end
    self:setHp(0)
    self:onDead({
		from = from and not from.removed and from or nil,
		cause = cause or "ENGINE_KILL",
	})
end

function EntityServer:serverRebirth(map, pos, yaw, pitch)
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
	local rebPos = self:getRebirthPos()
    local targetPos = Lib.v3(rebPos.x, rebPos.y, rebPos.z)
	self:setMapPos(map or rebPos.map, pos or targetPos, yaw, pitch)
	-- WorldServer.SystemChat(0, "system.message.player.rebirth.server", self.name)
	if self:data("main").enableAI then
		self:startAI()
	end
	Trigger.CheckTriggers(self:cfg(), "ENTITY_REBIRTH", {obj1=self})
	self:EmitEventAsync("OnEntityRebirth")
end

---@return EntityServer
function EntityServer.Create(params, func)
    local cfg = Entity.GetCfg(params.cfgName)
	if cfg == nil then
		Lib.logError("EntityServer.Create cfg == nil", params.cfgName)
		return
	end
	assert(cfg.id, params.cfgName)	-- 没填id_mapping?
    local entity = EntityServer.CreateEntity(cfg.id)
	if func then
		func(entity)
	end
	entity.luaObjID = entity.objID
	if params.name then
        entity:setName(params.name)
    end
	entity:invokeCfgPropsCallback()
    entity:resetData()
	if params.pos then
		entity:setMapPos(params.map or params.pos.map, params.pos, params.ry, params.rp)
	end
	if params.scale and cfg.boundingScaleWithSize then
		local scaleV3 = params.scale
		if type(scaleV3) =="string" then
			scaleV3 = Lib.deserializerStrV3(scaleV3)
		end
		entity:setEntityScale(scaleV3)
	end
	local mainData = entity:data("main")
	if not entity.isPlayer or (cfg.reviveTime or -1) >= 0 then
		entity:setRebirthPos(params.pos)
	end
	if params.owner then
		entity:setValue("ownerId", params.owner.objID)
	end

	entity:setValue("level", params.level or 1, true)
	entity:setValue("camp", params.camp or cfg.clique or cfg.camp or 0, true)
	entity:setValue("mapEntityIndex", params.mapEntityIndex or 0)
	if params.enableAI or params.aiData or cfg.enableAI then
		mainData.enableAI = true
		local enableStateMachine = params.enableAIStateMachine
		if enableStateMachine == nil then
			enableStateMachine = cfg.enableAIStateMachine
		end
		for key, value in pairs(params.aiData or {}) do
			entity:setAiData(key, value)
		end
		for key, value in pairs(Lib.copy(cfg.aiData) or {}) do
			entity:setAiData(key, value)
		end
		entity:setAINavigateBlockIds()
		entity:data("aiData").enableStateMachine = enableStateMachine ~= false
		entity:startAI()
	end
    local entityData = params.entityData or {}
    for k, v in pairs(entityData.vars or params.vars or {}) do
        entity.vars[k] = v
    end
	for key, value in pairs(cfg.passiveBuffs or {}) do
		entity:addBuff(value.name, value.time)
	end
	entity:onCreate()
	if entityData.derive then
		entity.vars.editor_data = Lib.copy(entityData.derive)
	end
	Trigger.CheckTriggers(entity:cfg(), "ENTITY_ENTER", {obj1=entity, mapEntityIndex = params.mapEntityIndex})
	Event:EmitEvent("OnEntityAdded", entity)
	entity.createByMapIndex = params.createByMapIndex
	entity.objPatchKey = params.objPatchKey or (os.date("%Y%m%d%H%M%S",os.time())..entity.objID)
	if not params.notNotifyMapPatchMgr then
		MapPatchMgr.ObjectChange(params.map or (params.pos and params.pos.map), 
			{change = "create", objId = entity.objID, pos = params.pos, yaw = params.ry, pitch = params.rp, isEntity = true, 
				createByMapIndex = entity.createByMapIndex, objPatchKey = entity.objPatchKey, fullName = entity:cfg().fullName, notNeedSaveToPatch = entity:cfg().notNeedSaveToPatch})
	end
	MapPatchMgr.RegistCreateByMapEntityToTable(entity.objID, entity.createByMapIndex)
	ExecUserScript.chunk(cfg,entity,"_serverScript")
    return entity
end

function EntityServer:setAiData(key, value)
	self:enableAIControl(true)
	local control = self:getAIControl()
	control:setAiData(key, value)
end

function EntityServer:startAI()
	entity_camp.addAIEntity(self:getValue("camp"), self)
	ai_control_mgr:startAI(self)
end

function EntityServer:stopAI()
	entity_camp.delAIEntity(self:getValue("camp"), self)
	ai_control_mgr:stopAI(self)
end

function EntityServer:setAITargetPos(pos, enable)
	local control = self:getAIControl()
	if not control then
		return
	end
	control:setTargetPos(pos, enable)
end

function EntityServer:enableAITargetPos(enable)
	local control = self:getAIControl()
	if not control then
		return
	end
	self.isMoving = enable
    control.enableTargetPos = enable
end

function EntityServer:handleAIEvent(event, ...)
	local control = self:getAIControl()
	if control then
		control:handleEvent(event, ...)
	end
end

function EntityServer:rideOn(target, ctrl, targetIndex)
	if target and target.curHp <= 0 then
		target = nil
	end
	if not self:isValid() then
		return
	end
	if self.rideOnId > 0 then
		local old = self.world:getEntity(self.rideOnId)
		if old == target then
			return
		end
		if old and old:isValid() then
			local rps = old:cfg().ridePos or {}
			if not rps[self.rideOnIdx+1] then 
    			print("Invalid config of ridePos, entity:"..old:cfg().fullName..", index:"..(self.rideOnIdx+1))
				return
			end
			if (rps[self.rideOnIdx+1].ctrl) then
				old:setPlayerControl(old)
			end
			if rps[self.rideOnIdx+1].buff then
				self:removeTypeBuff("fullName", rps[self.rideOnIdx+1].buff)
			end
			old:data("passengers")[self.rideOnIdx+1] = nil
			Trigger.CheckTriggers(old:cfg(), "ENTITY_RIDE_OFF", {obj1=old, obj2=self, ctrl=rps[self.rideOnIdx+1].ctrl})
			self:sendPacketToTracking({
				pid = "EntityRideOff",
				objID = self.objID,
				rideOffId = old.objID,
			}, true)
		end
		self:setRideOn(0, 0)
	elseif not target then
		return
	end
	if target and target:isValid() then
		local rps = target:cfg().ridePos or {}
		local passengers = target:data("passengers")
		local idx = nil
		for i, tb in ipairs(rps) do
			if not passengers[i] and (ctrl == nil or tb.ctrl == ctrl) then
				if targetIndex == nil or i == targetIndex then
					idx = i
					break
				end
			end
		end
		if idx then
			passengers[idx] = self.objID
			self:setRideOn(target.objID, idx - 1)
			if rps[idx].ctrl then
				target:setPlayerControl(self)
			end
			if rps[idx].buff then
				self:addBuff(rps[idx].buff)
			end
		    Trigger.CheckTriggers(target:cfg(), "ENTITY_RIDE_ON", {obj1=target, obj2=self, ctrl=rps[idx].ctrl})
		else
			-- message to client
			return
		end
	end
    local packet = {
        pid = "EntityRideOn",
        objID = self.objID,
        rideOnId = self.rideOnId,
		rideOnIdx = self.rideOnIdx,
	}
	self:sendPacketToTracking(packet, true)
	self:incCtrlVer()
	self:syncSkillMap()
end

function EntityServer:setValue(key, value, noSync)
	local def = Entity.ValueDef[key]
	self:doSetValue(key, value)
	self.spawnSyncVals[key] = self:spawnNeedSync(key) and value or nil
	if noSync then
		return
	end
	
    local packet = {
        pid = "EntityValue",
        key = key,
		value = value,
		isBigInteger = type(value) == "table" and value.IsBigInteger,
        objID = self.objID,
	}
    local toSelf = def[3] and (self:isValid() and self.isPlayer)
	if self:isValid() then
		if def[4] then
			self:sendPacketToTracking(packet, toSelf)
		elseif toSelf then
			self:sendPacket(packet)
		end
	end
end

function EntityServer:getCtrlPlayer()
	if self.isPlayer then
		return self
	end
	local rps = self:cfg().ridePos
	if not rps then
		return nil
	end
	for idx, id in ipairs(self:data("passengers")) do
		if rps[idx].ctrl then
			return self.world:getEntity(id):getCtrlPlayer()
		end
	end
	return nil
end

function EntityServer:setPos(pos, yaw, pitch, canRide, cameraParam)
	if not canRide then
		self:rideOn(nil)
	end
	Entity.setPos(self, pos, yaw, pitch)
	self:sendPacketToTracking({
		pid = "EntityMove",
		objID = self.objID,
		map = self.map and self.map.id or 0,
		pos = pos and {x = pos.x, y = pos.y, z = pos.z},
		yaw = yaw,
		pitch = pitch,
		cameraParam = cameraParam,
	}, true)
	self:cancelSyncPos()
	self:incCtrlVer()
end

function EntityServer:setMapPos(map, pos, yaw, pitch, canRide, cameraParam)
	map = self.world:getMap(map)

	local allPlayer = Game.GetAllPlayers()
	for _, v in pairs(allPlayer) do
		if v:getTargetId() == self.objID and v:getMode() == self:getObserverMode() then
			v:setMapPos(map, pos, yaw, pitch, canRide)
		end
	end

    Trigger.CheckTriggers(self:cfg(), "ENTITY_TELEPORT", {obj1 = self, map = map})

	if not self:setMap(map) then
		self:setPos(pos, yaw, pitch, canRide, cameraParam)
		return
	end

	if self.isPlayer then
		assert(pos, map.name)
		local packet = {
			pid = "ChangeMap",
			id = map.id,
			objID = self.objID,
			name = map.name,
			static = map.static,
			pos = pos,
		}
		self:sendPacket(packet)
	end

	self:setPos(pos, yaw, pitch, canRide, cameraParam)

	for idx, objID in pairs(self:data("passengers")) do
		local entity = self.world:getEntity(objID)
		if entity then
			entity:setMapPos(map, pos, yaw, pitch, true, cameraParam)
		end
	end
end

function EntityServer:leaveMap()
	assert(not self.isPlayer)
	self:clearRide()
	self:setPos(Lib.v3(0,0,0))
	if not self:setMap(nil) then
		return
	end
end

function EntityServer:face2Pos(pos)
	local cur = self:getPosition()
	if cur then
		self:setRotationYaw(Lib.v3AngleXZ(Lib.v3cut(pos, cur)))
		self:syncPosDelay(1)
	end
end

function EntityServer:destroy()
	local team = self:getTeam()
	if team then
		team:leaveEntity(self)
	end
	local data = self:data("fishing")
	if data.state then
        Skill.Cast(data.skillName, {method="cancel",needPre = true}, self)
    end
	self:clearRide()
	self:stopAI()
	local packet = {
		pid = "ObjectRemoved",
		entityUI = self:data("entityUI"),
		objID = self.objID,
	}
	self:sendPacketToTracking(packet)
	if not self.isPlayer then
		Trigger.CheckTriggers(self:cfg(), "ENTITY_LEAVE", {obj1 = self})
		Event:EmitEvent("OnEntityRemoved", self)
	end

	if not self.notNotifyMapPatchMgr then
		MapPatchMgr.ObjectChange(self.map, {change = "destroy", objId = self.objID,
			createByMapIndex = self.createByMapIndex, objPatchKey = self.objPatchKey, isEntity = true, notNeedSaveToPatch = self:cfg().notNeedSaveToPatch})
	end
	
	Object.destroy(self)
end

function EntityServer:setHeadText(x, y, txt, isNeedTranslate)
	Entity.setHeadText(self, x, y, txt)
	local packet = {
		pid = "HeadText",
		objID = self.objID,
		isNeedTranslate = isNeedTranslate,
		ary = self:data("headText").ary,
	}
	self:sendPacketToTracking(packet, true)
end

function EntityServer:setDamageText(text)
	local packet = {
		pid = "DamageText",
		objID = self.objID,
		text = text,
	}
	self:sendPacketToTracking(packet, true)
end

function EntityServer:getSkillMap()
	local skillMap = {}
    for _, name in ipairs(self:cfg().skills or {}) do
        skillMap[name] = {objID = self.objID}
    end
    for _, cfg in ipairs(self:cfg().skillList or {}) do
        skillMap[cfg.fullName] = {objID = self.objID}
    end
    for name, index in pairs(self:data("skill").addSkill or {}) do
        skillMap[name] = {objID = self.objID, index = index}
    end
	for name, index in pairs(self:data("skill").leftSkill or {}) do
		skillMap[name] = {objID = self.objID, index = index}
	end
    for _, name in pairs(self:data("buffSkill")) do
        skillMap[name] = {objID = self.objID}
    end
	if self.isPlayer then
		local sloter = self:getHandItem()
		if sloter then
			for _, name in ipairs(sloter:skill_list()) do
				skillMap[name] = {objID = self.objID}
			end
		end
	end
	if self:cfg().triggerSet and self:cfg().triggerSet.ENTITY_JUMP then
		skillMap["/jump_trigger"] = {objID = self.objID}
	end

	-- 装备技�
	local trayArray = self:data("tray"):query_trays(function(tray)
		return tray:class() == Define.TRAY_CLASS_EQUIP
	end)

	for _, element in pairs(trayArray) do
		local tid, tray = element.tid, element.tray
		for slot, item in pairs(tray:query_items()) do
			local equip_skill = item:equip_skill()
			for _, name in ipairs(equip_skill or {}) do
				skillMap[name] = {objID = self.objID}
			end
		end
	end

	if self.rideOnId>0 then
		local entity = self.world:getEntity(self.rideOnId)
		if entity then
			local rp = (entity:cfg().ridePos or {})[self.rideOnIdx+1]
			if rp and rp.ctrl then
				for name, value in pairs(entity:getSkillMap()) do
					skillMap[name] = {objID = value.objID}
				end
			end
		end
	end
    return skillMap
end

function EntityServer:getSkillEquip(skillName)
	if not skillName then
		return
	end
	if self.isPlayer then
		local sloter = self:getHandItem()
		for _, name in ipairs(sloter and sloter:skill_list() or {}) do
			if name == skillName then
				return sloter	-- TODO
			end
		end
	end
	local trayArray = self:data("tray"):query_trays(function(tray)
		return tray:class() == Define.TRAY_CLASS_EQUIP
	end)
	for _, element in pairs(trayArray) do
		local tray = element.tray
		for _, item in pairs(tray:query_items()) do
			for _, name in ipairs(item:equip_skill() or {}) do
				if name == skillName then
					return item
				end
			end
		end
	end
	-- TODO
	return nil
end

function EntityServer:getStudySkillMap()
	-- 学习的技�
	local studySkillMap = self:data("skill").studySkillMap
	if not studySkillMap then
		return {studySkills = {}, equipSkills = {}}
	end

	-- TODO EX
	return studySkillMap
end

function EntityServer:initSkill()
	for _, name in ipairs(self:cfg().skillInfos or {}) do
		self:addSkill(name)
    end
    for _, cfg in ipairs(self:cfg().skillInfoList or {}) do
		self:addSkill(cfg.fullName)
	end
end

local _addSkillIndex = 1
function EntityServer:addSkill(name)
	if not Skill.Cfg(name) then
		return
	end
	local data = self:data("skill")
	local addSkill = data.addSkill
	if addSkill then
		addSkill[name] = _addSkillIndex
	else
		data.addSkill = {[name] = _addSkillIndex}
	end
    _addSkillIndex = _addSkillIndex + 1
	self:syncSkillMap()
end

function EntityServer:removeSkill(name)
	local addSkill = self:data("skill").addSkill
	if not addSkill then
		return
	end
	addSkill[name] = nil
	self:syncSkillMap()
end

function EntityServer:syncSkillMap()
	local ridePos = self:cfg().ridePos
	if not ridePos then
		return	-- npc自身不同步技能列表，player会覆盖此函数
	end
	-- npc需要通知“驾驶员”同步技�
	for idx, objID in pairs(self:data("passengers")) do
		local rp = ridePos[idx]
		if rp and rp.ctrl then
			local entity = self.world:getEntity(objID)
			if entity then
				entity:syncSkillMap()
			end
			break
		end
	end
end

local function applySkin(self, skinData)
	local mySkin = self:data("skin")
	for k, v in pairs(skinData) do
		mySkin[k] = v
	end
	return mySkin
end

function EntityServer:changeSkinPart(skinPartData, sync)
	applySkin(self, skinPartData)
	local packet = {
		pid = "SkinPartChange",
		objID = self.objID,
		skinPartData = skinPartData
	}
	calcSendPacket(self, packet, getSync(sync))
end

function EntityServer:changeSkin(skinData, sync)
	local mySkin = applySkin(self, skinData)
	local packet = {
		pid = "SkinChange",
		objID = self.objID,
		skinData = mySkin
	}
	calcSendPacket(self, packet, getSync(sync))
end

local function saveStudySkill(self)
	local vars = self.vars
	if not vars then
		self.vars = {}
		vars = self.vars
	end
	local entitySkill = vars.entitySkill
	entitySkill = {}
	entitySkill[1] = {}
	entitySkill[2] = {}
	vars.entitySkill = entitySkill
	local studySkillMap = self:data("skill").studySkillMap
	if not studySkillMap then
		return
	end

	local studySkills = studySkillMap.studySkills
	local varSkills = vars.entitySkill[1]
	for name,_ in pairs(studySkills or {}) do
		varSkills[#varSkills + 1] = name
	end

	local equipSkills = studySkillMap.equipSkills
	local varEquips = vars.entitySkill[2]
	for i,v in pairs(equipSkills) do
		varEquips[i] = v
	end
end

function EntityServer:saveData()
	local cfg = self:cfg()
	Trigger.CheckTriggers(cfg, "ENTITY_SAVE", {obj1=self})
	local buffList = {}
	for id, buff in pairs(self:data("buff")) do
		if buff.cfg.needSave then
			local time = nil
			if buff.endTime then
				time = buff.endTime - World.Now()
			end
			buffList[#buffList+1] = {
				name = buff.cfg.fullName,
				time = time,
			}
		end
	end
	local values = {}
	for key, def in pairs(Entity.ValueDef) do
		if def[6] then
			local value = self:getValue(key)
			if value~=def[5] then
				values[key] = value
			end
		end
	end
	saveStudySkill(self)
	local data = {
		curHp = self.curHp,
		curVp = self.curVp,
		tray = self:data("tray"):seri(true),
		vars = Vars.SaveVars(self.vars),
		buff = buffList,
		values = values,
		rankScoreRecord = self:data("rankScoreRecord"),
	}
	return data
end

local function loadStudySkill(self)
	local vars = self.vars
	if not vars then
		return
	end

	local entitySkill = vars.entitySkill
	if not entitySkill then
		return
	end

	self:data("skill").studySkillMap = {}
	local studySkillMap = self:data("skill").studySkillMap
	studySkillMap.studySkills = {}
	studySkillMap.equipSkills = {}

	local varSkills = entitySkill[1]
	local studySkills = studySkillMap.studySkills
	for i,name in pairs(varSkills or {}) do
		studySkills[name] = i or true
	end

	local varEquips = vars.entitySkill[2]
	local equipSkills = studySkillMap.equipSkills
	for i,v in pairs(varEquips or {}) do
		equipSkills[i] = v
	end
end

function EntityServer:loadValues(values)
	values = values or {}
	for key, def in pairs(Entity.ValueDef) do
		if def[6] then
			local value = values[key]
			if value==nil then
				value = def[5]
			end
			if type(value) == "table" and value["segments"] then
				value = BigInteger.Recover(value)
			end
			self:setValue(key, value)
		end
	end
end

function EntityServer:loadData(data)
	local cfg = self:cfg()
	local scoreRecord = self:data("rankScoreRecord")
	for k, v in pairs(data.rankScoreRecord or {}) do
		scoreRecord[k] = v
	end
	self:data("tray"):load(data.tray or {})
	Vars.LoadVars(self.vars, data.vars or {})
	for _, buff in pairs(data.buff or {}) do
		self:addBuff(buff.name, buff.time)
	end
	self:loadValues(data.values)
	local curHp = data.curHp
    if curHp and cfg.loadHp ~= false and not World.cfg.noLoadHp then
		self:setHp(curHp)
	end
	local curVp = data.curVp
	if curVp and cfg.loadVp ~= false and not World.cfg.noLoadVp then
		self:setVp(curVp)
	end
	loadStudySkill(self)
end

function EntityServer:Play3dSound(filename, isMain)
	local soundInfo = self:data("soundInfo")
	soundInfo.isMain = isMain or false
	soundInfo.isPlay = true
	self:stop3dSound()

	self:sendPacketToTracking({
		pid = "Play3dSound",
		objID = self.objID,
		filename = filename,
	}, true)
end

function EntityServer:Stop3dSound()
	self:sendPacketToTracking({
		pid = "Stop3dSound",
		objID = self.objID
	}, true)
end

function EntityServer:readValue(str)
	local i = str:find("%.")
	if not i then
		local func = self[str]
		if type(func)=="function" then
			return func(self)
		end
		return func
	end
	local typ = str:sub(1, i - 1)
	local val = str:sub(i + 1)
	if typ=="prop" then
		return self:prop(val)
	elseif typ=="vars" then
		return self.vars[val]
	elseif typ=="cfg" then
		return self:cfg()[val]
	elseif typ=="main" then
		return self:data("main")[val]
	end
end

function EntityServer:imprintsProps()
	local EMPTY = {}
	local props = {}
	local isProp = Entity.IsProp
	local function calcFunc(buff)
		for k, v in pairs(buff and buff.cfg or EMPTY) do
			if isProp(k) then
				props[k] = (props[k] or 0) + v
			end
		end
	end	
	local trayArray = self:tray():query_trays(function(tray)
		return tray:class() == Define.TRAY_CLASS_IMPRINT
	end)
	for _, element in pairs(trayArray) do
		local tray = element.tray
		for _, item in pairs(tray:query_items()) do
			calcFunc(item:buff_data())
			for _, buff in pairs(item:buff_datas()) do
				calcFunc(buff)
			end
		end
	end
	return props
end

function EntityServer:imprintsInfo()
	local cfg = self:cfg()
	local trayArray = self:tray():query_trays(function(tray)
		return tray:class() == Define.TRAY_CLASS_IMPRINT
	end)
	local trayInfos = {}
	for _, element in pairs(trayArray) do
		local tid, tray = element.tid, element.tray
		local imprints = {}
		for slot, item in pairs(tray:query_items()) do
			imprints[#imprints + 1] = {slot = slot, fullName = item:full_name()}
		end
		trayInfos[tray:type()] = {
			tid = tid,
			imprints = imprints,
			capacity = tray:capacity(),
		}
	end
	local props = self:imprintsProps()
	local values = {}
	for i, info in ipairs(cfg.imprintValues or {}) do
		local value = info.value
		if type(value) == "table" then
			local ary = {}
			values[i] = ary
			for j, v in ipairs(value) do
				ary[j] = props[v] or info.default[i]
			end
		else
			values[i] = props[value] or info.default
		end
	end
	return {trays = trayInfos, values = values}
end

function EntityServer:viewInfo()
	local type_list = {
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
	local equip_data = {}
	for _, type in pairs(type_list) do
		local trayArray = self:tray():query_trays(type)
		local tid = trayArray[1] and trayArray[1].tid
		local tray = trayArray[1] and trayArray[1].tray	-- 取第一�
		if tray then
			local items = tray:query_items()
			local slot, item = next(items)
			equip_data[type] = {tid = tid, slot = slot, fullName = item and item:full_name(), stack_count = item and item:stack_count()}
		end
	end
	local cfg = self:cfg()
	local values = {}
	local infoValues = cfg.infoValues or {
			{
			  ["name"] = "gui.info.name",
			  ["value"] = "name"
			},
			{
			  ["name"] = "gui.info.clanname",
			  ["value"] = "vars.clanName"
			},
			{
			  ["name"]= "gui.info.vip",
			  ["value"]= "vars.vip",
			  ["langKey"]= "{.vip.name}",
			  ["default"]= 0
			}
		}
	for i, info in ipairs(infoValues) do
		local value = info.value
		if type(value)=="table" then
			local ary = {}
			values[i] = ary
			for j, v in ipairs(value) do
				ary[j] = self:readValue(v)
			end
		else
			values[i] = self:readValue(value)
		end
	end
	return {
		cfg = cfg.fullName,
		actor = self:data("main").actorName or (self:cfg().actorName and self:cfg().actorName  ~= "" and self:cfg().actorName) or "boy.actor",
		skin = self:data("skin"),
		equip = equip_data,
		values = values,
		imprint = self:imprintsInfo(),
	}
end

function EntityServer:viewEntityInfo(cfgName)
	if not cfgName then
		return
	end
	local cfg = self:cfg()
	local values = {}
	for i, info in ipairs(cfg[cfgName] or {}) do
		local value = info.value
		if type(value)=="table" then
			local ary = {}
			values[i] = ary
			for j, v in ipairs(value) do
				ary[j] = self:readValue(v)
			end
		else
			values[i] = self:readValue(value)
		end
	end
	return {values = values, cfg = cfg.fullName, cfgName = cfgName}
end

function EntityServer:changeActor(name, clearSkin)
	self:data("main").actorName = name
	if clearSkin then
		self:setData("skin", {})
	end
	local packet = {
		pid = "ChangeActor",
		objID = self.objID,
		name = name,
        clearSkin = clearSkin
	}
	self:sendPacketToTracking(packet, true)
	self:changeSkin({})
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
				return item:cfg()[cfgKey] == val
			end)

			local slot, item = next(items)
			if slot then
				return Item.CreateSlotItem(self, tid, slot)
			end
		end
	end
end

function EntityServer:searchEquipItem(cfgKey, val)
	return self:searchItem(cfgKey, val, {
		Define.TRAY_TYPE.EQUIP_1,
		Define.TRAY_TYPE.EQUIP_2,
		Define.TRAY_TYPE.EQUIP_3,
		Define.TRAY_TYPE.EQUIP_4,
		Define.TRAY_TYPE.EQUIP_5,
		Define.TRAY_TYPE.EQUIP_6,
		Define.TRAY_TYPE.EQUIP_7,
		Define.TRAY_TYPE.EQUIP_8,
        Define.TRAY_TYPE.EQUIP_9
	})
end

function EntityServer:searchOneItem(cfgKey, val, filter)
	assert(type(cfgKey) == "string", tostring(cfgKey))

	filter = filter or function()
		return true
	end
	local trayArray = self:tray():query_trays(filter)
	for _, element in pairs(trayArray) do
		local tid, tray = element.tid, element.tray
		local items = tray:query_items(function(item)
			return item:cfg()[cfgKey] == val
		end)

		local slot, item = next(items)
		if slot then
			return Item.CreateSlotItem(self, tid, slot)
		end
	end
end

function EntityServer:searchTypeItemsFromBag(cfgKey, val)
	assert(type(cfgKey) == "string", tostring(cfgKey))
	local trayArray = self:tray():query_trays({Define.TRAY_TYPE.HAND_BAG, Define.TRAY_TYPE.BAG})
	local retItems = {}
	local total = 0
	for _, element in pairs(trayArray) do
		local tid, tray = element.tid, element.tray
		local items = tray:query_items(function(item)
			return item:cfg()[cfgKey] == val
		end)
		retItems[#retItems + 1] = {
			items = items,
			tid = tid
		}
		for _, item in pairs(items) do
			total = total + item._stack_count
		end
	end
	return total, retItems
end

function EntityServer:consumeBagItems(count, retItems, reason, related)
	related = related or {}
	local sequence = GameAnalytics.NewSequence()
	for _, element in pairs(retItems) do
		local tid = element.tid
		local items = element.items
		local tray = self:tray():fetch_tray(tid)
		for slot, item in pairs(items) do
			local stackCount = item._stack_count
			local fullName = item:full_name()
			local args = {
				type = "item",
				name = fullName,
				reason = reason,
			}
			if count <= 0 then
				break
			elseif count < stackCount then
				Item.CreateSlotItem(self, tid, slot):consume(count)
				args.count = count
				self:resLog(args, related)
				GameAnalytics.ItemFlow(self, "", fullName, args.count, false, reason, "", sequence)
				break
			else
				tray:remove_item(slot)
				count = count - stackCount
				args.count = stackCount
				self:resLog(args, related)
				GameAnalytics.ItemFlow(self, "", fullName, args.count, false, reason, "", sequence)
			end
		end
	end
end

function EntityServer:doDropDamage(speed)
	self:doDamage({
		damage = speed * self:prop("dropDamageRatio"),
		cause = "ENGINE_DO_DROP_DAMAGE",
	})
end

local function isSameItem(item, item2)
    if not item and not item2 then
        return true
    end
	if item and item2 and item._entity == item2._entity and item._slot == item2._slot and item._tid == item2._tid then
		return true
	else
		return false
	end
end

function EntityServer:saveHandItem(item, syncExcludeSelf, force)
	local mainData = self:data("main")
	if isSameItem(item, mainData.handItem) and not force then
		return
	end

	local oldItem = mainData.handItem
	--if oldItem and  item  then
	--	if oldItem._entity._cfg.name == item._entity._cfg.name then
	--		return
	--	end
	--end
	if oldItem and oldItem:null() then
		oldItem = nil
	end
	if item and item:null() then
		item = nil
	end
	Trigger.CheckTriggers(self:cfg(), "HAND_ITEM_CHANGED", {obj1 = self, item = item, oldItem = oldItem})
	self:EmitEvent("OnHandItemChanged", item)
	if oldItem then
		Trigger.CheckTriggers(oldItem:cfg(), "HAND_ITEM_CHANGED_UNHAND", {obj1 = self, item = oldItem})
	end
	if item then
		Trigger.CheckTriggers(item:cfg(), "HAND_ITEM_CHANGED_HAND", {obj1 = self, item = item})	
	end
	mainData.handItem = item
    local handBuff = mainData.handBuff
    if handBuff then
	    self:removeBuff(handBuff)
        mainData.handBuff = nil
    end
	self:removeTypeBuff("type", "HandBuff")
	if item and not item:null() then
		local buffName = item:cfg().handBuff
		if buffName then
			mainData.handBuff = self:addBuff(buffName)
		end
	end
	self:sendPacketToTracking({
		pid = "HandItem",
		objID = self.objID,
		itemData = item and item:seri()
	}, not syncExcludeSelf)
end

function EntityServer:getHandItem()
	local item = self:data("main").handItem
	if item and item:null() then
		item = nil
	end
	return item
end

function EntityServer:checkClearHandItem()
	local item = self:data("main").handItem
	if item and item:null() then
		self:saveHandItem(nil)
	end
	Trigger.CheckTriggers(self:cfg(), "CHECK_CLEAR_HAND_ITEM", {obj1 = self})
end

function EntityServer:checkClearIsHandItem(slot, item )
	local hand_item = self:data("main").handItem
	if hand_item and hand_item._slot == slot then
		Trigger.CheckTriggers(item:cfg(), "HAND_ITEM_CHANGED_UNHAND",  {obj1 = self, item = hand_item})
	end
end


function EntityServer:getTeam()
	local teamId = self:getValue("teamId")
	if teamId==0 then
		return nil
	end
	return Game.GetTeam(teamId)
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
	return team and team.rebirthPos or self:getStartPos()
end

function EntityServer:setRebirthPos(pos, map)
	if map then
	elseif pos and pos.map then
		map = pos.map
	elseif self.map then
		map = self.map
	else
		map = self:data("main").lastStaticMap
	end
	if pos then
		pos = Lib.tov3(pos):copy()
		pos.map = map
	end
	self:data("main").rebirthPos = pos
end

function EntityServer:onEnterMap(map)
	Object.onEnterMap(self, map)
    Trigger.CheckTriggers(self:cfg(), "ENTER_MAP", {map = map, obj1 = self})
	self:EmitEvent("OnEnterMap", map)
	if map.static then
		self:data("main").lastStaticMap = map
	end
end

function EntityServer:isSaveMapPos(map)
	return true
end

function EntityServer:onLeaveMap(map)
	Object.onLeaveMap(self, map)
    Trigger.CheckTriggers(self:cfg(), "LEAVE_MAP", {map = map, obj1 = self})
	self:EmitEvent("OnLeaveMap", map)
	if map.static and self:isSaveMapPos(map) then
		self.saveMapPos = self:getPosition()
		if self.saveMapPos then
			self.saveMapPos.map = map.name
		end
	end
end

local function randStartPos(startPos)
	return startPos and #startPos > 0 and startPos[math.random(1, #startPos)] or nil
end

local function getStartFlagPos(self)
	local map, cfg = self.map
	if not map then
		return
	end
	cfg = map.cfg or {}
	return cfg.birthPos
end

function EntityServer:getStartPos(ignorable)
	local worldCfg = World.cfg
	local team = self:getTeam()
	--local pos =  team and randStartPos(team.startPos) or randStartPos(worldCfg.startPos)
	local teamPos = team and randStartPos(team.startPos)
	local startPos = nil;
	if not ignorable then
		startPos = randStartPos(worldCfg.startPos)
	end

	local pos = teamPos or startPos
	if pos or ignorable then
		return pos
	end
	return team and team.initPos or getStartFlagPos(self) or worldCfg.initPos	-- （不是条件表达式�
end

function EntityServer:getInitPos()
	return (self:getTeam() and self:getTeam().initPos) or (self.map and self.map.cfg.initPos) or WorldServer.defaultMap.cfg.initPos or World.cfg.initPos
end

function EntityServer:addItem(fullName, count, proc, reason)
	reason = reason or "addItem"
	if not self:tray():add_item(fullName, count, proc, true) then
		return false
	end

	self:tray():add_item(fullName, count, proc, false, reason)

	return true
end

function EntityServer:addItemObj(item, reason, related)
	assert(item and not item:null())

	if not self:tray():add_item_data(item:data(), true) then
		return false
	end

	self:tray():add_item_data(item:data())
	if self.isPlayer then
		local fullName = item:full_name()
		local count = item:stack_count()
		local args = {
			type = "item",
			name = fullName,
			count = count,
			reason = reason,
		}
		self:resLog(args, related)
		GameAnalytics.ItemFlow(self, "", fullName, count, true, reason, "")
	end

	return true
end

function EntityServer:addExp(exp, reason, related)
	if exp <= 0 then
		return
	end
	local levelUpExp = self:prop("levelUpExp")
	if levelUpExp <= 0 then
		return
	end
	if self.isPlayer and reason ~= "" then
		local args = {
			type = "exp",
			name = "exp",
			count = exp,
			reason = reason
		}
		self:resLog(args, related)
	end
	exp = exp + self:getValue("exp")
	local level = self:getValue("level")
	local cfg = self:cfg()
	local delta = 0
	while (exp >= levelUpExp) do
		exp = exp - levelUpExp
		delta = delta + 1
		local buffCfg = Entity.TryBuffCfg(cfg.levelBuffName .. "_" .. level + delta)
		levelUpExp = buffCfg and tonumber(buffCfg.levelUpExp) or levelUpExp
		if (levelUpExp <= 0) then
			exp = 0
			break
		end
	end
	self:setValue("exp", exp)
	if (0 == delta) then
		return
	end
	local prop = self:prop()
	if (prop) then
		self.curHp = prop.maxHp or self.curHp
		self.curVp = prop.maxVp or self.curVp
	end
	local len = cfg.skipPerLevelTrigger and 1 or delta
	level = level + delta - len
	for i = 1, len, 1 do
		self:setValue("level", level + i)
		if self.isPlayer then
			self:bhvLog("levelup", string.format("+%d =%d", delta - len + 1, level + i), nil, related)
		end
		Trigger.CheckTriggers(self:cfg(), "ENTITY_LEVELUP", {obj1 = self})
	end
end

function EntityServer:getLevelInfo()
	return {
		level = self:getValue("level"),
		exp = self:getValue("exp"),
		levelUpExp = self:prop("levelUpExp")
	}
end

function EntityServer:moveStatusChange(newState, oldState)
	Trigger.CheckTriggers(self:cfg(), "ENTITY_STATUS_CHANGE", {obj1 = self, newState = Define.EntityMoveStatus[newState], oldState = Define.EntityMoveStatus[oldState]})
	self:tryStopAnimoji()
	self:handleMoveStateSwitchBuffs(oldState, newState, function(self, fullName)
		local buffCfg = Entity.BuffCfg(fullName)
		if not buffCfg.buffTime then
			return self:addBuff(fullName)
		end
		self:addBuff(fullName, buffCfg.buffTime)
		return nil
	end, self.removeBuff)
	self:handleMoveStateSwitchSkills(oldState, newState, function(self, fullName)
		Skill.Cast(fullName, {needPre = true}, self)
	end)
end

function EntityServer:tryStopAnimoji()
	if self.isPlayer then
		local state = self:data("IsPlayingAnimoji") or 0
		if state == 1 then
			local packet = {
				pid = "EntityPlayAction",
				objID = self.objID,
				action = "idle",
				time = 0,
			}
			self:sendPacketToTracking(packet, true)

			self:setData("IsPlayingAnimoji", 0)
			if self:data("main").AnimojiTimer then
				self:data("main").AnimojiTimer()
			end
		end
	end
end

local callRewardArray
local function callReward(reward, rewardTb)
	if not reward.countRange then
		reward.countRange = {
			min = 1,
			max = 1
		}
	end
	local rand = math.random(reward.countRange.min, reward.countRange.max)
	local count = reward.count or rand
	local icon = reward.icon or false
	if reward.type ~= "List" and rand > 0 then
		local save = {data = reward, count = count, icon = icon}
		table.insert(rewardTb, save)
		return
	else
		for i = 1, count do
			callRewardArray(reward.array, rewardTb)
		end
	end
end

--local
function callRewardArray(array,rewardTb)
    local weight = 0
    for i,v in ipairs(array)do
        if v.weight and v.weight>0 then
            weight = weight + v.weight
        else
            callReward(v,rewardTb)
        end
    end
    if weight>0 then
        local getReward = math.random(1,weight)
        for i,v in ipairs(array)do
            if v.weight and v.weight>0 then
                getReward = getReward - v.weight
                if getReward<=0 then
                    callReward(v,rewardTb)
                    break
                end
            end
        end
    end
end

function EntityServer:reward(rewardParams)
	local reward = rewardParams.reward
	local _reward
	local ret = true

	local typ = type(reward)
    if typ ~= "string" then
		assert(typ=="table", typ)
        _reward = reward
    elseif reward:find("/") then
        _reward = assert(setting:fetch("reward", reward), reward)
    else
		local cfg = assert(rewardParams.cfg, "cfg is nil ! ! ! ")
		local path = "plugin/" .. cfg.plugin .. "/" .. cfg.modName .. "/" .. cfg._name .. "/" .. reward .. ".json"
        _reward = assert(Lib.readGameJson(path), path)
    end
    local rewardTb = {}
    callRewardArray(_reward, rewardTb)
	if not next(rewardTb) then
		return false
	end

	local times = rewardParams.times or 1
	local check = rewardParams.check
	local related = rewardParams.related or {}
	local reason = rewardParams.reason or "reward"

    for _, v in pairs(rewardTb)do
		local type = v.data.type
		local name = v.data.name
		local subKey = v.data.subKey
		local count = v.count
		if type == "Coin"then
			if not check then
				self:addCurrency(name, count * times, reason, related)
			end
		elseif type == "Exp" then
			if not check then
				self:addExp(count, reason, related)
			end
		elseif type == "Event" then
			if not check then
				Trigger.CheckTriggers(self:cfg(), v.data.event, {obj1 = self, count = count, times = times, name = name, related = related, subKey = subKey, reason = reason})
			end
		elseif type == "Item" then
			ret = self:tray():add_item(name, count * times, name == "/block" and function(_item)
				_item:set_block(name)
			end, check, reason, related)
		elseif type == "Block" then
			ret = self:data("tray"):add_item("/block", count * times, function(item)
					item:set_block(name)
			end, check, reason, related)
		elseif type == "Privilege" then
			self:setAuthInfo(name, count * times)
            Trigger.CheckTriggers(self:cfg(), "ENTITY_GET_PRIVILEGE", {obj1 = self, name = name})
		end
    end

    if self.isPlayer and rewardParams.tipType and not check then
		self:showRewardTip(rewardParams.tipType, rewardTb)
    end
    return ret, rewardTb
end

function EntityServer:showTargetInfo(target,flag)
	local targetID = target and target.objID or nil
	local targetName = target and target.name or nil
	self.targetName = targetName
	if not self.isPlayer then
		return 
	end
	local packet = {
        pid = "ShowTargetInfo",
		objID = self.objID,
		targetInfo = {
			targetID = targetID,
			targetIsPlayer = target and target.isPlayer or false,
			flag = flag,
			tarTargetName = target and target.targetName or nil
		}
    }
	self:sendPacket(packet)
end

function EntityServer:SetEntityToBlock(data)
	if not data then
		return
	end
	self:changeActor("boytouming.actor")
	self:data("main").entityToBlock = data
	self:fillBlock(data.xSize, data.ySize, data.zSize)
end

function EntityServer:OpenTreasureBox(boxName)
	local cfg = setting:fetch("item", boxName)
    local lottery = cfg.lottery
	local _, rewatdTb = self:reward(lottery)
	local succed = self:tray():remove_item(boxName, 1, false, nil, nil, "treasureBoxSystem")
	if succed then
		if self:data("treasurebox")[boxName] then
			self:data("treasurebox")[boxName].isOpen = true
			self:data("treasurebox")[boxName].openCD = os.time() + lottery.openCD
		end
		self:UpdataTreasureBox(boxName, true, rewatdTb)
	end
end

function EntityServer:UpdataTreasureBox(boxName, updata, showRewardTb)
	--非开宝箱和刷新奖池操作则保持奖池物品排列
	if not updata and self:data("treasurebox")[boxName] then
		local packet = {
			pid = "ShowTreasureBox",
			boxName = boxName
		}
		self:sendPacket(packet)
		return
	end

	local curTrays = {}
	local currBox = 1
	local holdCurr = false
	local box_name = nil
	local lottery = nil
	local itemShow = {}
	local function rand_tab(tab)
		for len = #tab, 1, -1 do
			local n = math.random(len)
			tab[len], tab[n] = tab[n], tab[len]
		end
		return tab
	end
	local trayType = { Define.TRAY_TYPE.HAND_BAG, Define.TRAY_TYPE.BAG, Define.TRAY_TYPE.EXTRA_BAG, }
	local trayArray = self:tray():query_trays(trayType)
	for _, treasure in pairs(trayArray) do
        local tray = treasure.tray
        local items = tray and tray:query_items(function(item)
            if item:cfg()["lottery"] then
                return true
            end
            return false
        end)
		for _, item in pairs(items) do
            table.insert(curTrays, item)
        end
    end
	table.sort(curTrays, function(item1, item2)
	    local type1 = self:tray():fetch_tray(item1:tid()):type()
	    local type2 = self:tray():fetch_tray(item2:tid()):type()
	    if type1 ~= type2 then
	        if Define.TRAY_TYPE_CLASS[type1] ~= Define.TRAY_TYPE_CLASS[type2] then
	            return Define.TRAY_TYPE_CLASS[type1] == Define.TRAY_CLASS_EQUIP and Define.TRAY_TYPE_CLASS[type2] ~= Define.TRAY_CLASS_EQUIP
	        end
	    end
	    local gist_1, gist_2 = item1:cfg()["quality"], item2:cfg()["quality"]
	    if gist_1 and gist_2 then
	        return gist_1 > gist_2
	    end
	    return false
	end)

	if next(curTrays)then
		for i,v in pairs(curTrays) do
			--如果该宝箱有叠加继续显示该宝�
			if v:full_name() == boxName then
				box_name = v:full_name()
				currBox = i
				holdCurr = true
			end
		end
		if not holdCurr then
			box_name = curTrays[currBox]:full_name()
		end
		-----------------------------------------------
		local cfg = setting:fetch("item", box_name)
		lottery = cfg.lottery
		local reward = lottery.reward
		local show = lottery.show
		local _reward
		local _show
		_reward = assert(setting:fetch("reward", reward), reward)
		_show = assert(setting:fetch("reward", show), show)
		local rewardTb = {}
		callRewardArray(_reward, rewardTb)
		local showTb = {}
		callRewardArray(_show, showTb)
		-----------------------------------------------
		for i,showitem in pairs(showTb)do
			itemShow[#itemShow + 1] = showitem
		end
		for i,rewarditem in pairs(rewardTb)do
			itemShow[#itemShow + 1] = rewarditem
		end
		itemShow = rand_tab(itemShow)
		local currTreasureBox = {
			openCD = (self:data("treasurebox")[boxName] and self:data("treasurebox")[boxName].openCD) or (os.time() + lottery.openCD + lottery.openTime),
			pond = itemShow,
			lottery = lottery,
			isOpen = (self:data("treasurebox")[boxName] and self:data("treasurebox")[boxName].isOpen) or false
		}
		self:data("treasurebox")[box_name] = currTreasureBox
		self:syncTreasurebox()
	end

	local packet = {
		pid = "ShowTreasureBox",
		boxName = box_name,
		showRewardTb = showRewardTb or {}
	}
	self:sendPacket(packet)
end

function EntityServer:TreasureBoxResresh(resreshTyp, boxName)
	local cfg = setting:fetch("item", boxName)
    local lottery = cfg.lottery
	local resreshPondCoinName = lottery.resreshPondCoinName
	local resreshPondCoinNum = lottery.resreshPondCoinNum
	local resreshOpenCdCoinName = lottery.resreshOpenCdCoinName
	local resreshOpenCdCoinNum = lottery.resreshOpenCdCoinNum
	if resreshTyp==2 then
		self:data("treasurebox")[boxName].openCD = 0
		self:syncTreasurebox()
	end
	local context = {
		obj1 = self,
		boxName = boxName,
		resreshPondCoinName = resreshPondCoinName,
		resreshPondCoinNum = resreshPondCoinNum,
		resreshOpenCdCoinName = resreshOpenCdCoinName,
		resreshOpenCdCoinNum = resreshOpenCdCoinNum,
		resreshTyp = resreshTyp,
		updata = true
	}
	Trigger.CheckTriggers(self:cfg(), "TREASURE_BOX_RESRESH", context)
end

local function auraCheckEntity(self, aura, entity)
	if aura.toPlayer~=nil and aura.toPlayer~=entity.isPlayer then
		return false
	end
	if aura.toEnemy~=nil and self.isEntity and aura.toEnemy~=self:canAttack(entity) then
		return false
	end
	return true
end

-- 当自身条件变化时，刷新自己所在的别人的光�
function EntityServer:refreshOtherAura()
	if not self.map then
		return
	end
	for _, obj in pairs(self.map.objects) do
		-- �luaData而不�data()，避免过多的生成无用的table
		for _, aura in pairs(obj.luaData.aura or {}) do
			local buff = aura.entitylist[self]
			if buff then
				if not auraCheckEntity(obj, aura, self) then
					self:removeBuff(buff)
					aura.entitylist[self] = false
				end
			elseif buff==false then
				if auraCheckEntity(obj, aura, self) then
					aura.entitylist[self] = self:addBuff(aura.buffName,nil,aura.from)
				end
			end
		end
	end
end

function EntityServer:setEntityMode(mode, targetId)
	self:setMode(mode)
	self:setTargetId(targetId)
	if self.isPlayer then
		Game.UpdatePlayerInfo(self)
	end

	local packet = {pid = "SyncEntityMode", objID = self.objID, targetId = targetId, mode = mode }
	self:sendPacketToTracking(packet, true)

	local target = World.CurWorld:getEntity(targetId)
	if mode == self:getObserverMode() and target then
		self:setMapPos(target.map, target:getPosition())
		self:changeFlyMode(0.0)
	end

	if mode == self:getFreedomMode() then
		self:changeFlyMode(-1.0)
	end

end

function EntityServer:traySlotChange(tid, slot, item)
	-- print("  tid ", tid, slot)
	-- print(" item ", Lib.v2s(item))
	Game.checkGameOverWithItemChange({obj = self, item = item})
end

function EntityServer:setForceMoveToAll(pos, time)
	self:setForceMove(pos, time)
	self:sendPacket({pid = "ForceMoveToSelf", pos = pos, time = time})
end

--清空背包，适用于单局竞技游戏，道具都是临时资源，不走存储的
--在游戏重置的时候清一下
function EntityServer:removeAllItem()
	local trayArray = self:tray():query_trays(function() return true end)
	for _, element in pairs(trayArray) do
		local tray_obj = element.tray
		local items = tray_obj:query_items(function(item) return true end)
		for slot in pairs(items) do
			tray_obj:remove_item(slot)
		end
	end
end

function EntityServer:addBlock(blockName, count, proc, reason)
	reason = reason or "addBlock"
	return self:addItem("/block", count, function(item)
		item:set_block(blockName)
		if proc then
			proc(item)
		end
	end, reason)
end

function EntityServer:setProp(key, value, noSync)
	self:doSetProp(key, value)
	self:data("prop")[key] = value
	self:setHp(math.min(self.curHp, self:prop("maxHp")))
	self:setVp(math.min(self.curVp, self:prop("maxVp")))
	if noSync then
		return
	end
	local packet = {
		pid = "SetProp",
		key = key,
		value = value,
		isBigInteger = type(value) == "table" and value.IsBigInteger,
		objID = self.objID,
	}
	self:sendPacketToTracking(packet, true)
end

function EntityServer:onAIArrived()
	-- TODO
end