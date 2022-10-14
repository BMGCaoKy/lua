local Handlers = T(Trigger, "Handlers")
local setting = require "common.setting"

local function entityAddItem(entity, cfg, count, reason)
    if not entity:tray():add_item(cfg, count, nil, true) then
        return false
    end
    assert(cfg ~= "/block", cfg)
    entity:data("tray"):add_item(cfg, count, nil, false, reason or "action")
end

local function entityAddBlock(entity, cfg, count, reason)
    entity:addItem("/block", count, function(item)
        item:set_block(cfg)
    end, "action")
end

local function addReward(entity, reward)
    --add item
    local addItem = reward.addItem
    if addItem and next(addItem) then
        for _, value in ipairs(addItem) do
            local fullName = value.name
            local count = value.count
            local type = value.type
            if type == "Item" or type == "item" then
                local cfg = setting:fetch(type, fullName)
                if cfg.isBuff then
                    entity:addBuff(cfg.itembuff)
                else
                    entityAddItem(entity, fullName, count)
                end
            elseif type == "buff" or type == "buff" then
                entity:addBuff(fullName)
            elseif type == "block"then
                entityAddBlock(entity, fullName, count)
            end
        end
    end

    --add score
    local addScore = reward.addScore
    if addScore and next(addScore) then
        if addScore.enable then
            Trigger.CheckTriggers(entity:cfg(), "ADD_SCORE_TO_TEAM_OR_PERSON", {obj1 = entity, score = addScore.score})
        end
    end
end

function Handlers.BED_BREAK_REWARD(context)
    local entity = context.obj1
    if not (entity and entity.isPlayer) then
        return
    end
    local reward = World.cfg.bedBreakReward
    if not reward then
        return
    end
    addReward(entity, reward)
end

function Handlers.KILL_REWARD(context)
    local entity, entity2 = context.obj1, context.obj2
    if entity == entity2 then
        return
    end
    if not entity.isPlayer then
        return
    end
    local reward = World.cfg.killReward
    if not reward then
        return
    end
    addReward(entity, reward)
end

local function updateWorldTime(context)
    local player = context.obj1
    if not player.isPlayer then
        return
    end
    player:sendPacket({
        pid = "UpdateWorldTime",
        time = World.CurWorld:getWorldTime()
    })
end

local function startAddMonsterAroundPlayer(context)
    local player = context.obj1
    if not player.isPlayer then
        return
    end
    --中途加入的玩家也可以刷怪
    if Game.GetState() ~= "GAME_GO" then
        return
    end
    player:addMonsterAroundPlayer()
end

local playTime = World.cfg.playTime or -1
function Handlers.GAME_GO(context)
    if playTime == -1 then
        return
    end
    Game.UpdateLeftTime()
end

function Handlers.ENTITY_DIE(context)
    local player = context.obj2
    local monster = context.obj1
    if not player or monster.objID then
        return
    end
    player:refreshAroundMonsters(monster.objID)
end

function Handlers.ENTITY_ENTER(context)
    updateWorldTime(context)
    startAddMonsterAroundPlayer(context)
end

function Handlers.ENTITY_LEAVE(context)
    local player = context.obj1
    if not player.isPlayer then
        return
    end
    local roomOwnerId = player:data("mainInfo").roomOwnerId
    if roomOwnerId == 0 then
        return
    end
    if roomOwnerId ~= player.platformUserId then
        return
    end
    local players = Game.GetAllPlayers()
    for curObjID, curPlayer in pairs(players) do
        curPlayer:sendTip(3, "room_owner_leave_and_close_server", 40)
    end
    World.Timer(40, function ()
        Game.StopServer()
    end)
end

function Handlers.ENTITY_VP_EMPTY(context)
    local entity = context.obj1
    local damage = entity:prop("maxHp") * 0.05
    entity:timer(80, function ()
        if entity.curVp > 1e-8 or entity.curHp < 1e-8 then
            return false
        end
        entity:doDamage({
            damage = damage,
            cause = "ENGINE_PROP_INIT_CONTINUE_DAMAGE",
        })
        return true
    end)
end

function Handlers.ENTITY_VP_RECOVERY_HP(context)
    local entity = context.obj1
    local maxVp = entity:prop("maxVp")
    local maxHp = entity:prop("maxHp")
    entity:timer(80, function ()
        if entity.curVp < maxVp * 0.9 or entity.curHp < 1e-8 then
            return false
        end
        if entity.curHp ~= maxHp then
            entity:addHp(maxHp * 0.05)
            entity:addVp(-maxVp * 0.015)
        end
        return true
    end)
end

local function broadcastWorldTime()
    WorldServer.BroadcastPacket({
        pid = "UpdateWorldTime",
        time = World.CurWorld:getWorldTime()
    })
end

local function skyBoxChange(stage)
    local function checkMonsterMissDuringDay(obj)
        if not World.cfg.monsterMissDuringDay then
            return
        end
        if stage == "day" then
            local missDuringDay = obj:cfg().missDuringDay
            if missDuringDay then
                obj:monsterDisappear()
            end
        elseif stage == "night" then
            obj:monsterAppear()
        end
    end

    local function checkRandomMonster(obj)
        if not World.cfg.isRandomAddMonster then
            return
        end
        local environment = obj.appearEnvironment
        if environment == "allday" then
            return
        end
        if stage == environment then
            obj:monsterAppear()
        else
            obj:monsterDisappear()
        end
    end

    local mapList = T(World, "mapList")
    for _, map in pairs(mapList) do
        for _, obj in pairs(map.objects) do
            if obj.isPlayer or not obj.isEntity then
                goto continue
            end
            local merchantGroupName = obj:cfg().shopGroupName
            if merchantGroupName then
                goto continue
            end
            if obj.isRandomMonster then
                checkRandomMonster(obj)
                goto continue
            end
            checkMonsterMissDuringDay(obj)
            ::continue::
        end
    end
end

local function checkNeedBroadcastSkyBox()
    local worldCfg = World.cfg
    if worldCfg.monsterMissDuringDay then
        return true
    end

    local data = setting:fetch("add_monster", "myplugin/main" )
    local monsterSetData = data and data.addMonsters and data.addMonsters[1] or {}

    if worldCfg.isRandomAddMonster and monsterSetData[1]then
        return true
    end

    return false
end

local curStage = ""
function Handlers.CHECK_SKY_BOX(context)
    if not checkNeedBroadcastSkyBox() then
        return
    end
    
    local function checkStage()
        local stage = World.CurWorld:getCurTimeMode()
        if curStage ~= stage then
            curStage = stage
            broadcastWorldTime()
            skyBoxChange(curStage)
        end
    end
    checkStage()
    World.Timer(20, function()
        checkStage()
        return true
    end)
end

function Handlers.ENTITY_CAN_REBIRTH(context)
    if World.cfg.monsterMissDuringDay and context.obj1:cfg().missDuringDay and World.CurWorld:getCurTimeMode() == "day" then
        context.canRebirth = false
    end
end

function Handlers.IN_BLOCK_CHANGED(context)
    local entity = context.obj1
    local oldCfg = Block.GetIdCfg(context.oldId)
    local newCfg = Block.GetIdCfg(context.newId)
    local damageBuff = "myplugin/in_lava_damage_buff"
    local retardBuff = "myplugin/in_lava_retard_buff"
    if oldCfg.blockType == "lava" and newCfg.blockType ~= "lava" then--���ҽ������
        entity:removeTypeBuff("fullName", retardBuff)
    end
    if oldCfg.blockType ~= "lava" and newCfg.blockType == "lava" then--�����ҽ�
        local buffCfg = setting:fetch("buff", damageBuff)
        entity:addBuff(damageBuff, buffCfg.buffTime)
        entity:addBuff(retardBuff)
        if entity.checkInLavaTimer then
            entity.checkInLavaTimer()
        end
        entity.checkInLavaTimer = entity:lightTimer(damageBuff, buffCfg.buffTime, function()
            local curPos = entity:getPosition()
            curPos = {x = math.floor(curPos.x), y = math.floor(curPos.y), z = math.floor(curPos.z)}
            local curBlockCfg = entity.map:getBlock(curPos)
            if curBlockCfg.blockType == "lava" and entity.curHp > 0 then
                entity:addBuff(damageBuff, buffCfg.buffTime)
                return true
            end
            return false
        end)
    end
    if oldCfg.blockType ~= "water" and newCfg.blockType == "water" then--����ˮ��
        entity:removeTypeBuff("fullName", "myplugin/flame_bomb_burn_buff")
        entity:removeTypeBuff("fullName", "myplugin/fire_effect")
        entity:removeTypeBuff("fullName", "myplugin/in_lava_damage_buff")
        entity:removeTypeBuff("attachType", "fire")
    end
end

function Handlers.PLAYER_PLAY_TIMER_START(context)
    local player = context.obj1
    if not player.isPlayer then
        return
    end
    if player.clientReady then
        player:startPlayTime()
    end
end

function Handlers.BLOCK_REMOVED(context)
    WaterMgr.BlockBreak(context.map, context.pos)
end

function Handlers.BLOCK_REPLACED(context)
    WaterMgr.BlockReplace(context.map, context.pos, context.oldId, context.newId)
end