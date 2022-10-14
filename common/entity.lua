local setting = require "common.setting"

local min = math.min
local max = math.max
local rand = math.random

---@class Entity : Object
---@field world World
local Entity = Entity

local EntityProp = T(Entity, "EntityProp")
local ClickProp = T(Entity, "ClickProp")
-- 脚本定义属性�
-- （C++ 内的属性值无需在这里重复填写，会被读取过来�
EntityProp.maxMp = 100
EntityProp.damage = 0
EntityProp.prefixIcon = {}
EntityProp.designationIcon = {}
EntityProp.suffixIcon = {}
EntityProp.headStar = 0
EntityProp.subfishtime = 0
EntityProp.dropDamageRatio = 5
EntityProp.unassailable = 0
EntityProp.undamageable = 0
EntityProp.enableDamageProtection = 0
EntityProp.damageProtectionTime = 40
EntityProp.bgmSound = ""
EntityProp.bgmVolume = 0
EntityProp.canInteract = 1
EntityProp.dmgFactor = 1    -- 伤害系数
EntityProp.damagePct = 1    -- 伤害百分比
EntityProp.armor = 0        -- 护甲
EntityProp.armorPct = 0        -- 护甲提升百分比
EntityProp.deDmgPct = 0        -- 减伤百分比
EntityProp.lifeSteal = 0    -- 吸血
EntityProp.dmgRebound = 0    -- 反伤
EntityProp.levelUpExp = 0    -- 升级所需经验值
EntityProp.ignoreBlocks = {}-- 可特别忽视碰撞的方块
EntityProp.defense = 0        -- 防御值
EntityProp.critDmgProb = 0    -- 暴击概率
EntityProp.critDmgPct = 0    -- 暴击伤害提升
EntityProp.dodgeDmgProb = 0    -- 闪避概率
EntityProp.dodgeDmgPct = 0    -- 闪避伤害系数
EntityProp.sprintSpeed = 0  -- 加速度
EntityProp.attachPointIndex = 0  -- 挂点目标的挂点的index
EntityProp.disableSkillsStatus = 0   --  不可释放技状态
EntityProp.forbidForwardControl = 0
EntityProp.breakBlock = 1        --是否可以破坏方块（大于0即可破坏方块）
EntityProp.breakTime = 0        --破坏方块时间叠加
EntityProp.breakTimeFactor = 1    --破坏方块时间系数

-- 自动同步属性定�
local ValueDef = T(Entity, "ValueDef")
-- key		= {isCpp,	client,	toSelf,	toOther,	init,	saveDB}
ValueDef.teamId = { false, false, true, true, 0, false }
ValueDef.joinTeamTime = { false, false, true, true, 0, false }
ValueDef.camp = { false, false, true, true, 0, false }
ValueDef.sinValue = { false, true, false, true, 0, false }
ValueDef.mode = { false, false, true, true, "team", false }
ValueDef.movingStyle = { true, true, false, true, 0, false }
ValueDef.ownerId = { true, false, false, true, 0, false }
ValueDef.petIndex = { false, false, true, false, nil, false }
ValueDef.guideStep = { false, false, true, false, nil, true }
ValueDef.exp = { false, false, true, false, 0, true }
ValueDef.level = { false, false, true, true, 1, true }
ValueDef.isKeepAhead = { false, true, true, false, false, false }
ValueDef.canSlide = { false, true, true, false, true, false }
ValueDef.playTime = { false, false, false, false, 0, false }
ValueDef.reqNextGame = { false, false, true, false, false, false }
ValueDef.mapEntityIndex = { false, true, true, true, 0, false }

-- 以上属性的回调函数（C/S可分别实现）
local ValueFunc = T(Entity, "ValueFunc")

local cfgMT = T(Entity, "cfgMT")
local EntityCfg = setting:mod("entity")

local BuffCfg = setting:mod("buff")

local init = nil

Entity.isEntity = true

function Entity.addValueDef(key, initVal, toSelf, toOther, saveDB, client)
    ValueDef[key] = { false, client, toSelf, toOther, initVal, saveDB }
end

function Entity.addValueFunc(key, func)
    ValueFunc[key] = func
end

local checkFuncs = {}
checkFuncs.checkProp = function(entity, checkCond)
    local key = checkCond.p1
    local value = tonumber(checkCond.p2)
    local propVal = entity:prop(key) or 0
    return value == propVal
end

checkFuncs.checkTargetProp = function(_, checkCond, targetObjID)
    local target = World.CurWorld:getObject(targetObjID)
    if not target then
        return false
    end
    local key = checkCond.key
    if not key then
        return false
    end
    return target:prop(key) == checkCond.value
end

checkFuncs.checkRideOnIndex = function(entity, checkCond, targetObjID)
    local target = World.CurWorld:getObject(targetObjID)
    if not target then
        return false
    end
    return target:data("passengers")[checkCond.index]
end

checkFuncs.checkTeamID = function(entity, checkCond)
    local targetID = tonumber(checkCond.p1)
    local teamID = entity:getValue("teamId")
    return targetID == teamID
end

local function checkInSameTeam(entity1, entity2)
    local id1 = entity1:getValue("teamId")
    local id2 = entity2:getValue("teamId")
    if id1 == 0 or id2 == 0 then
        return false
    end
    return id1 == id2
end

checkFuncs.checkInSameTeam = function(entity, checkCond, targetObjID)
    local target = World.CurWorld:getObject(targetObjID)
    if not target then
        return false
    end
    if entity == target then
        return true
    end
    return checkInSameTeam(entity, target)
end

local function getTargetOwner(targetObjID)
    local object = World.CurWorld:getObject(targetObjID)
    if not object then
        return false
    end
    local target = World.CurWorld:getObject(object:getValue("ownerId"))
    if not target then
        return false
    end
    return target
end

checkFuncs.checkOwnerInSameTeam = function(entity, checkCond, targetObjID)
    local target = getTargetOwner(targetObjID)
    if not target then
        return false
    end
    if entity == target then
        return true
    end
    return checkInSameTeam(entity, target)
end

checkFuncs.checkOwnership = function(entity, checkCond, targetObjID)
    local target = getTargetOwner(targetObjID)
    if not target then
        return false
    end
    return entity == target
end

checkFuncs.checkTypeHandItem = function(entity, checkCond)
    local item = entity:getHandItem()
    if not item then
        return false
    end
    local cfg = item:cfg()
    local value = cfg[checkCond.key]
    if not value then
        return false
    end
    return value == checkCond.value
end

checkFuncs.checkIsFriend = function(_, checkCond, targetObjID)
    if not World.isClient then
        return false
    end
    local target = World.CurWorld:getObject(targetObjID)
    if not target then
        return false
    end
    return FriendManager.friendsMap[target.platformUserId]
end

checkFuncs.checkInSelfParty = function(entity, checkCond)
    if not World.isClient then
        return false
    end
    return not not entity:data("main").inSelfParty
end

function Entity:checkCond(checkCond, ...)
    local func = checkFuncs[checkCond.funcName]
    if not func then
        print("not definded function! ", checkCond.funcName)
        return false
    end
    return func(self, checkCond, ...)
end

function Entity:initData()
    Object.initData(self)
    local cfgName = self:getCfgName()
    local cfg = assert(EntityCfg:get(cfgName), cfgName)
    self._cfg = cfg
    self._prop = setmetatable({}, cfg.propMT)

    do
        local entity_tray = require "entity.entity_tray"
        local my_tray = Lib.derive(entity_tray)
        my_tray:init(self)
        self:setData("tray", my_tray)
    end

    if cfg.calcYawBySpeedDir ~= nil then
        self:doSetProp("calcYawBySpeedDir", cfg.calcYawBySpeedDir)
    end
end

function Entity:clearRide()
    for _, id in pairs(self:data("passengers")) do
        local re = self.world:getEntity(id)
        if re and not re.removed then
            re:rideOn(nil)
        end
    end
    self:rideOn(nil)
end

function Entity.GetCfg(cfgName)
    local cfg = EntityCfg:get(cfgName)
    if cfg then
        return cfg
    end
    print("[Error]EntityCfg[", cfgName, "] is nil")
    return nil
end

function Entity:prop(key)
    if not key then
        return self._prop
    end
    return self._prop[key]
end

function Entity:invokeCfgPropsCallback()
    local EntityProp = EntityProp
    for k, v in pairs(self:cfg()) do
        local p = EntityProp[k]
        if type(p) == "function" then
            --p(self, v, true)
        end
    end
end

function Entity.TryBuffCfg(name)
    return BuffCfg:get(name)
end

function Entity.BuffCfg(name)
    return assert(BuffCfg:get(name), name)
end

function Entity:calcBuff(buff, add, from)
    local prop = self:prop()
    for k, v in pairs(buff.cfg) do
        local dv = EntityProp[k]
        if dv ~= nil then
            local typ = type(dv)
            if typ == "function" then
                if from then
                    buff.from = from
                end
                if dv(self, v, add, buff) and buff.timer then
                    buff.timer()
                    buff.timer = nil
                end
            elseif typ == "table" then
                local tb = rawget(prop, k)
                if not tb then
                    tb = Lib.copy(prop[k])
                    prop[k] = tb
                end
                tb[buff.id] = add and v or nil
            elseif typ == "string" then
                prop[k] = add and v or nil
            else
                prop[k] = prop[k] + (add and v or -v)
            end
        end
    end
    if buff.cfg.inC then
        self:calcBuffProp(buff.cfg.id, add)
    end
    if buff.cfg.ignoreBlocks then
        self:updateIgnoreBlocks()
    end
    if not World.isClient then
        if add then
            Trigger.CheckTriggers(buff.cfg, "ENTITY_BUFF_ADD", { entity = self, cfg = buff.cfg })
        else
            Trigger.CheckTriggers(buff.cfg, "ENTITY_BUFF_REMOVE", { entity = self, cfg = buff.cfg })
        end
    end
end

function Entity:getTypeBuff(key, value)
    for id, buff in pairs(self:data("buff")) do
        if buff.cfg[key] == value then
            return buff
        end
    end
end

function Entity:updateIgnoreBlocks()
    local ids = {}
    for key, name in pairs(self:prop("ignoreBlocks")) do
        for _, name in pairs(self:prop("ignoreBlocks")[key]) do
            ids[#ids + 1] = Block.GetNameCfgId(name)
        end
    end
    self:setIgnoreBlocks(ids)
end

function Entity:removeAllBuff()
    for id, buff in pairs(self:data("buff")) do
        self:calcBuff(buff, false)
        buff.id = nil
    end
    self:setData("buff", {})
end

function Entity:getValue(key)
    local def = Entity.ValueDef[key]
    if def then
        local value
        if def[1] then
            value = self[key]
        else
            value = self:data("main")[key]
        end
        if value == nil then
            return (type(def[5]) == "table") and Lib.copy(def[5]) or def[5]
        else
            return (type(value) == "table") and Lib.copy(value) or value
        end
    else
        return nil
    end

end

function Entity:spawnNeedSync(key)
    local def = Entity.ValueDef[key]
    if not def[4] then
        return false
    end
    local value
    if def[1] then
        value = self[key]
    else
        value = self:data("main")[key]
    end
    if value == nil or value == def[5] then
        return false
    end
    return true
end

local EntityMoveStatus = { -- It Must Be Same as C+
    "EMPTY",
    "IDLE",
    "RUN",
    "WALK",
    "SPRINT",
    "SWIMMING",
    "SWIMMING_IDLE",
    "JUMP",
    "FALLING",
    "AERIAL",
    "CLIMB",
    "FLY",
    "FLY_IDLE",
}

function Entity:getMoveStateSwitchBuffFullNames(oldState, newState)
    local buffsKey = (self:cfg().entityMoveStateSwithBuffCfgs[newState] or {})[oldState]
    if not buffsKey then
        return nil
    end

    local pos = self:getPosition()
    if not pos then
        return
    end
    local underFootBlockCfg
    if newState == "JUMP" then
        underFootBlockCfg = Block.GetIdCfg(self:getLastCollidableUnderfootBlockId())
    else
        underFootBlockCfg = Block.GetIdCfg(self:getCollidableUnderfootBlockId())
    end
    local underFootObjectCfg = {}
    local underFootObjectId
    if newState == "JUMP" then
        underFootObjectId = self:getLastCollidableUnderfootObjId()
    else
        underFootObjectId = self:getCollidableUnderfootObjId()
    end

    -- 提供一个可选的被踩时的移动状态变化配置，
    -- 解决骑乘物被踩时，给踩在上面的entity错误的移动状态变化配�该骑乘物的移动状态变化配�
    if underFootObjectId > 0 then
        local obj = World.CurWorld:getObject(underFootObjectId)
        if obj and obj:isValid() then
            underFootObjectCfg = World.CurWorld:getObject(underFootObjectId):cfg()
            if underFootObjectCfg.objectWasTrampledMoveStateSwitchCfg then
                underFootObjectCfg = underFootObjectCfg.objectWasTrampledMoveStateSwitchCfg
            end
        end
    end

    for _, cfg in ipairs({ underFootBlockCfg, underFootObjectCfg, self:cfg() }) do
        if cfg[buffsKey] then
            return cfg[buffsKey]
        end
    end
    return nil
end

function Entity:getMoveStateSwitchSkillFullNames(oldState, newState)
    local buffsKey = (self:cfg().entityMoveStateSwithSkillCfgs[newState] or {})[oldState]
    if not buffsKey then
        return nil
    end
    return self:cfg()[buffsKey]
end

function Entity:handleMoveStateSwitchBuffs(oldState, newState, addBuffHandler, delBuffHandler)
    local moveStateBuffs = self:data("moveStateBuffs")    -- [fullName] = buff
    local newStateBuffs = {}
    for _, fullName in pairs(self:getMoveStateSwitchBuffFullNames(EntityMoveStatus[oldState], EntityMoveStatus[newState]) or {}) do
        if not moveStateBuffs[fullName] then
            moveStateBuffs[fullName] = addBuffHandler(self, fullName)
        end
        newStateBuffs[fullName] = true
    end
    for fullName, buff in pairs(moveStateBuffs) do
        if not newStateBuffs[fullName] then
            delBuffHandler(self, buff)
            moveStateBuffs[fullName] = nil
        end
    end
end

function Entity:handleMoveStateSwitchSkills(oldState, newState, castSkillHandler)
    for _, fullName in pairs(self:getMoveStateSwitchSkillFullNames(EntityMoveStatus[oldState], EntityMoveStatus[newState]) or {}) do
        if fullName then
            castSkillHandler(self, fullName)
        end
    end
end

function Entity:doSetValue(key, value)
    local def = Entity.ValueDef[key]
    if not def then
        return
    end
    local oldValue
    if type(value) == "table" then
        value = Lib.copy(value) ---clone(value)
        if def[1] then
            oldValue = self[key]
            self[key] = value
        else
            oldValue = self:data("main")[key]
            self:data("main")[key] = value
        end
        local func = ValueFunc[key]
        if func then
            func(self, value, oldValue)
        end
    else
        if def[1] then
            oldValue = self[key]
            self[key] = value
        else
            oldValue = self:data("main")[key]
            self:data("main")[key] = value
        end
        local func = ValueFunc[key]
        if func then
            func(self, value, oldValue)
        end
    end
end

function Entity:setPos(pos, yaw, pitch)
    if not self:isValid() then
        Lib.logError("Entity setPos not isValid")
        return
    end
    self:setPosition(pos)
    if yaw then
        self:setRotationYaw(yaw)
    end
    if pitch then
        self:setRotationPitch(pitch)
    end
    self.hitchingToId = 0
end

function Entity:getFrontPos(dis, isFoot, bCenter)
    dis = dis or 1
    local yaw = math.rad(self:getRotationYaw())
    local pos = isFoot and self:getPosition() or self:getEyePos()
    pos.x = pos.x - dis * math.sin(yaw)
    pos.z = pos.z + dis * math.cos(yaw)
    if bCenter then
        pos.x = math.floor(pos.x) + 0.5
        pos.z = math.floor(pos.z) + 0.5
    end
    return Lib.tov3(pos)
end

function Entity:setHeadText(x, y, txt)
    local headText = self:data("headText")
    local ary = headText.ary
    if not ary then
        ary = {}
        headText.ary = ary
    end
    local a = ary[y]
    if not a then
        if not txt then
            return false
        end
        ary[y] = { [x] = txt }
    elseif a[x] == txt then
        return false
    else
        a[x] = txt
        if not next(a) then
            ary[y] = nil
        end
    end
    return true
end

function Entity:checkCD(key)
    local time = self:data("cd")[key]
    if not time then
        return false
    end
    local rest = time - World.Now()
    if rest <= 0 then
        return false
    end
    return rest
end

function Entity:setCD(key, time)
    if time then
        time = time + World.Now()
    end
    self:data("cd")[key] = time
end

function Entity:checkRecharge(key, maxTimes , time , type , method )
    self:RefreshRecharge(key, maxTimes , time , type , method , false)
    local data = self:data("skillReacharge")[key]
    if not data then 
        return false
    end

    if not data.recTime then 
        return false
    end

    if data.times <= 0 and data.recTime > World.Now() then 
        return true
    end
    print("data.times " , data.times)
    return false
end

function Entity:RefreshRecharge(key, maxTimes , time , type , method , isUse)
    local data = self:data("skillReacharge")[key]
    if time <= 0 then 
        return 
    end
    if not data then 
        if isUse then
            self:data("skillReacharge")[key] = 
            {
                times = maxTimes - 1,
                recTime = (maxTimes > 1 and type ~= Define.SkillRechargeType.All) and World.Now() + time or nil,
                type = type,
                method = method
            }
        end
        return
    end

    if data.recTime and data.recTime < World.Now() then 
        if type ==  Define.SkillRechargeType.All and data.times <= 0 then
            if method == Define.SkillRechargeMethod.Once then 
                local addTimes = math.floor((World.Now() - data.recTime - time) / time)
                if addTimes + data.times >= maxTimes then 
                    self:data("skillReacharge")[key] = {
                        times = maxTimes,
                        recTime = nil
                    }
                    return 
                end
                self:data("skillReacharge")[key].times = data.times + addTimes
                self:data("skillReacharge")[key].recTime = data.recTime + addTimes * time
            else 
                self:data("skillReacharge")[key] = 
                {
                    times = maxTimes,
                    recTime = nil
                }
            end
        elseif type == Define.SkillRechargeType.Immediate then 
            if method == Define.SkillRechargeMethod.Once then 
                local addTimes = math.floor((World.Now() - data.recTime - time) / time)
                if addTimes + data.times >= maxTimes then 
                    self:data("skillReacharge")[key] = {
                        times = maxTimes,
                        recTime = nil
                    }
                    return 
                end
                self:data("skillReacharge")[key].times = data.times + addTimes
                self:data("skillReacharge")[key].recTime = data.recTime + addTimes * time
            else 
                self:data("skillReacharge")[key] = {
                    times = maxTimes,
                    recTime = nil
                }
            end
        end
    end

    if isUse then 
        self:data("skillReacharge")[key].times = data.times - 1
        if not data.recTime then 
            if type ==  Define.SkillRechargeType.All and data.times > 0 then 
            else
                self:setCD(key , time)
                self:data("skillReacharge")[key].recTime = World.Now() + time
            end
        end
    end

    
    
end

function Entity:tray()
    return self:data("tray")
end

function Entity:owner()
    if self.isPlayer then
        return self
    end
    local entity = self.world:getEntity(self.ownerId)
    return entity or self
end

function Entity:setOwner(owner)
    if self.isPlayer then
        error("")
    end
    self.ownerId = owner.objID
end

function Entity:canAttack(target)
    local control = self.getAIControl and self:getAIControl()
    if not target:isValid() or target:isWatch() then
        return false
    end
    if target:prop("unassailable") > 0 and (not control or self:cfg().attackAssailable) then
        return false
    elseif target.curHp <= 0 then
        return false
    end
    local selfOwner = self:owner()
    local targetOwner = target:owner()
    if selfOwner.objID == targetOwner.objID then
        return false
    end
    local selfTeam = selfOwner:getValue("teamId")
    local targetTeam = targetOwner:getValue("teamId")
    if not World.cfg.teammateHurt and selfTeam ~= 0 and selfTeam == targetTeam then
        return false
    end
    local camp1 = selfOwner:getValue("camp")
    local camp2 = targetOwner:getValue("camp")
    if camp1 ~= 0 and camp1 == camp2 then
        return false
    end
    return true
end

function Entity:getNearbyEntities(maxDistance, filter)
    local allEntity = self.map and self.map:isValid() and self.map:getNearbyEntities(self:getPosition(), maxDistance) or {}
    local ret = {}
    for _, entity in pairs(allEntity) do
        if not filter or filter(entity) then
            ret[#ret + 1] = entity
        end
    end
    return ret
end

function Entity:getEyePos()
    local pos = self:getPosition()
    if not pos then
        return nil
    end
    pos.y = pos.y + self:prop("eyeHeight") - (self.movingStyle == 1 and 0.2 or 0)
    return pos
end

function Entity:getChestPos()
    local pos = self:getPosition()
    if not pos then
        return nil
    end
    pos.y = pos.y + self:prop("chestHeight") - (self.movingStyle == 1 and 0.2 or 0)
    return pos
end

function Entity:getCtrlEntity()
    local entity = self.world:getEntity(self.rideOnId)
    if not entity then
        return self
    end
    if entity:cfg().ridePos[self.rideOnIdx + 1].ctrl then
        return entity
    end
    return self
end

function Entity:setForceMove(pos, time, simpleMove)
    self.forceTargetPos = pos or { 0, 0, 0 }
    self.forceTime = time and (World.Now() + time) or 0
    self.isSimpleMove = simpleMove or false
end

function Entity:doHurt(motionV)
    self:doHurtInC(motionV, -1)
end

function Entity:doHurtRepel(vector)
    -- 击退指定向量
    self:doHurt(Lib.tov3(vector) / math.max(1, self:prop().hurtTime))
end

function Entity:setAINavigateBlockIds()
    for _, blockId in pairs(self:cfg().navigateCanMoveToBlockIds or {}) do
        self:addCanMoveToBlock(blockId)
    end
    for _, blockId in pairs(self:cfg().navigateCannotMoveToBlockIds or {}) do
        self:addCannotMoveToBlock(blockId)
    end
end

local MoveStateSwithBuffCfgs = {
    { newState = "IDLE", oldState = "ALL", cfgKey = "idleBuff" },
    { newState = "RUN", oldState = "ALL", cfgKey = "runBuff" },
    { newState = "WALK", oldState = "ALL", cfgKey = "walkBuff" },
    { newState = "SPRINT", oldState = "ALL", cfgKey = "sprintBuff" },
    { newState = "SWIMMING", oldState = "ALL", cfgKey = "swimmingBuff" },
    { newState = "SWIMMING_IDLE", oldState = "ALL", cfgKey = "swimmingIdleBuff" },
    { newState = "AERIAL", oldState = "ALL", cfgKey = "aerialBuff" },
    { newState = "AERIAL", oldState = "SWIMMING", cfgKey = nil },
    { newState = "AERIAL", oldState = "SWIMMING_IDLE", cfgKey = nil },
    { newState = "JUMP", oldState = "ALL", cfgKey = "jumpBuff" },
    { newState = "JUMP", oldState = "SWIMMING", cfgKey = nil },
    { newState = "JUMP", oldState = "SWIMMING_IDLE", cfgKey = nil },
    { newState = "JUMP", oldState = "CLIMB", cfgKey = nil },
    { newState = "JUMP", oldState = "FLY", cfgKey = nil },
    { newState = "JUMP", oldState = "FALLING", cfgKey = nil },
    { newState = "IDLE", oldState = "SPRINT", cfgKey = "sprintSkidBuff" },
    { newState = "CLIMB", oldState = "ALL", cfgKey = "climbBuff" },
}
local MoveStateSwithSkillCfgs = {}

local function initEntityMoveStateSwithCfgkeys(cfgs)
    local ret = {}
    for _, cfg in ipairs(cfgs) do
        local t = ret[cfg.newState]
        if not t then
            t = {}
            ret[cfg.newState] = t
        end
        if cfg.oldState ~= "ALL" then
            t[cfg.oldState] = cfg.cfgKey
        else
            for _, oldState in pairs(EntityMoveStatus) do
                t[oldState] = cfg.cfgKey
            end
        end
    end
    return ret
end

local function initEntityMoveStateSwithBuffCfgs(cfg)
    local tempMoveStateSwithBuffCfgs = Lib.copy(MoveStateSwithBuffCfgs or {})
    for _, cfgs in pairs(cfg.moveStateSwithBuffCfgs or {}) do
        tempMoveStateSwithBuffCfgs[#tempMoveStateSwithBuffCfgs + 1] = cfgs
    end
    cfg.entityMoveStateSwithBuffCfgs = initEntityMoveStateSwithCfgkeys(tempMoveStateSwithBuffCfgs)
end

local function initEntityMoveStateSwithSkillCfgs(cfg)
    local tempMoveStateSwithSkillCfgs = Lib.copy(MoveStateSwithSkillCfgs or {})
    for _, cfg in pairs(cfg.moveStateSwithSkillCfgs or {}) do
        tempMoveStateSwithSkillCfgs[#tempMoveStateSwithSkillCfgs + 1] = cfg
    end
    cfg.entityMoveStateSwithSkillCfgs = initEntityMoveStateSwithCfgkeys(tempMoveStateSwithSkillCfgs)
end

function EntityCfg:onLoad(cfg, reload)
    setmetatable(cfg, cfgMT)
    World.CurWorld:loadEntityConfig(cfg.id, cfg)
    local pb = {}
    for k, v in pairs(EntityProp) do
        if cfg[k] ~= nil then
            pb[k] = cfg[k]
        elseif type(v) ~= "function" then
            pb[k] = v
        end
    end
    cfg.propMT = { __index = pb }
    initEntityMoveStateSwithBuffCfgs(cfg)
    initEntityMoveStateSwithSkillCfgs(cfg)
    cfg.actorName:match("[^/]+$")
    if reload then
        for _, entity in ipairs(World.CurWorld:getAllEntity()) do
            if entity._cfg == cfg then
                entity:onCfgChanged()
            end
        end
    end
end

function BuffCfg:onLoad(cfg, reload)
    cfg.inC = World.CurWorld:loadBuffConfig(cfg.id, cfg)
end

function Entity.IsProp(key)
    return EntityProp[key] ~= nil
end

function Entity.EntityProp:boundingBox(value, add, buff)
    local boxTable = {
        boundingVolume = {
            type = value.type,
            params = value.params
        }
    }
    self:setBoundingVolume(add and boxTable or self:cfg())
end

function Entity.EntityProp:rotateBoundingBox(value, add, buff)
    self:rotateBoundingBox(self:getPosition(), value.axisDir or { x = 0, y = 1, z = 0 }, (add and value.radian or -value.radian) * (math.pi / 180) or 0)
end

function Entity.EntityProp:enableClick(value, add, buff)
    self.canClick = add
end

function Entity.EntityProp:aura(value, add, buff)
    local name = value.name or (buff and "buff_" .. buff.id or "default_aura")
    if add then
        self:addAura(name, value, buff.from)
    else
        self:removeAura(name)
    end
end

function Entity.EntityProp:attachPointIndex(value, add, buff)
    self:setRideOnAttachPointsIndex(add and value or self:cfg().attachPointIndex or 0)
end

local cppPropType = {}
Entity.GetAllPropType(cppPropType)
local cppPropIndex = {}
Entity.GetAllPropIndex(cppPropIndex)
function Entity:doSetProp(key, value)
    if EntityProp[key] == nil or value == nil then
        return
    end

    if cppPropType[key] then
        if cppPropType[key] == 0 then
            value = math.modf(value)
            self:setPropertyInt(cppPropIndex[key], value)
        elseif cppPropType[key] == 1 then
            self:setPropertyFloat(cppPropIndex[key], value)
        end
    end
    self._prop[key] = value
end

function Entity:CheckIsDefaultActor()
	if not self.getPlayerAttrInfo then return false end
	local sex =	self:getPlayerAttrInfo().sex == 2 and 2 or 1
	local tempActor = 	sex == 2 and self:cfg().actorGirlName or self:cfg().actorName
	return not tempActor or tempActor == ""
end

function Entity:refreshFloatData()
    local skillFloatData = self:data("floatSkill")
    if not skillFloatData then 
        return 
    end
    if type(skillFloatData) == "table" then 
        for k,v in pairs(skillFloatData) do 
            if v.endTime and v.endTime < World.Now() then 
                Skill.touchStop(skillFloatData[k].fullName,self)
                skillFloatData[k] = nil
            end
        end
    end
end

function Entity:setFloatData(type, data)
    if not type then 
        return 
    end
    local skillFloatData = self:data("floatSkill") or {}
    skillFloatData[type] = data
end

function Entity:getFloatData(type)
    if not type then return {} end
    local skillFloatData = self:data("floatSkill") or {}
    return skillFloatData[type]  
end

local function init()
    local cppProp = {}
    Entity.GetAllProp(cppProp)
    for k, v in pairs(cppProp) do
        if EntityProp[k] == nil then
            -- 不覆盖client、server特别定义的部�
            EntityProp[k] = v
        end
    end

    for k, v in pairs(World.cfg.customProp or {}) do
        EntityProp[k] = v
    end

    if not cfgMT.__index then
        cfgMT.__index = {}
        Entity.GetAllCfg(cfgMT.__index)
    end
end



init()

