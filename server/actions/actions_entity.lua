local BehaviorTree = require("common.behaviortree")
local Actions = BehaviorTree.Actions
require "world.world"
local setting = require "common.setting"

local function ResetItemSelect(player)
    local packet = {
        pid = "ResetItemSelect",
    }
    player:sendPacket(packet)
end

function Actions.ReviveEntity(data, params, context)
    local entity = params.entity
    local pos = params.pos
    local map = params.map or (pos and pos.map) or entity.map
    if ActionsLib.isInvalidEntity(entity) or ActionsLib.isInvalidMap(map) then
        return
    end
    entity.lastDamageTime = nil -- ��缃激瀹充��ゆ�堕��
    if entity.isPlayer then
        ResetItemSelect(entity)
    end
    entity.isRevive = true
    entity:serverRebirth(map, pos, params.yaw, params.pitch)
end

function Actions.GetRebirthPos(data,params,context)
    local entity = params.entity
    if ActionsLib.isInvalidEntity(entity) then
        return
    end
    local pos = entity:getRebirthPos()
    local targetPos = Lib.v3(pos.x, pos.y, pos.z)
    return targetPos
end

function Actions.Damage(data, params, context)
    local target = params.entity
    local atker = params.from
    if ActionsLib.isInvalidEntity(target, "Target") then
        return
    end
    target:doDamage({
        damage = params.damage,
        from = atker,
        cause = params.cause or "ACTIONS_DAMAGE"
    })
end

function Actions.Attack(data, params, context)
	params.from:doAttack({target = params.entity, cause = "ACTIONS_ATTACK"})
end

function Actions.SetHp(data, params, context)
    local entity = params.entity
    if ActionsLib.isInvalidEntity(entity) or entity.curHp<=0 then
        return
    end
    if ActionsLib.isNil(params.hp, "Hp") then
        return
    end
    entity:setHp(params.hp)
    if entity.curHp <= 0 then
        entity:onDead({
            from = entity and not entity.removed and entity or nil,
            cause = params.cause or "ACTIONS_SET_HP",
        })
    end
end

function Actions.GetEntityHeight(data, params, context)
    local entity = params.entity
    if ActionsLib.isInvalidEntity(entity) then
        return
    end
    local pos = entity:getPosition()
    return pos and pos.y
end

function Actions.SetEntityHeight(data, params, context)
    local entity = params.entity
    if ActionsLib.isInvalidEntity(entity) then
        return
    end
    local pos = entity:getPosition()
    if pos then
        pos.y = params.height or pos.y
        entity:setPos(pos)
    end
end

function Actions.SetEntityPosition(data, params, context)
    local entity = params.entity
    local map = params.map or entity.map
    if ActionsLib.isInvalidEntity(entity) or ActionsLib.isEmptyString(map, "Map") or ActionsLib.isInvalidMap(map) then
        return
    end
    entity:setMapPos(map, params.pos or {}, params.ry, params.rp)
end

function Actions.GetEntityPosition(data, params, context)
    local entity = params.entity
    if ActionsLib.isInvalidEntity(entity) then
        return nil
    end
	return entity:getPosition()
end

function Actions.GetEntityFrontPosition(data, params, context)
    return params.entity:getFrontPos(params.dis, true, params.center)
end

function Actions.GetNearbyEntities(node, params, context)
    return params.entity:getNearbyEntities(params.distance)
end

function Actions.GetNearbyTypeEntities(node, params, context)
    return params.entity:getNearbyEntities(params.distance, function (entity)
        return entity:cfg()[params.key] == params.value
    end)
end

function Actions.GetNearestEntity(data, params, context)
    local entity = params.entity
    local entitys = entity:getNearbyEntities(params.distance, function(ett)
        return entity ~= ett and ett.curHp > 0 and ett:isValid()
    end)
    local minDistance
    local target
    for _, ett in pairs(entitys or {}) do
        local distance = entity:distance(ett)
        if not minDistance then
            minDistance = distance
            target = ett
        elseif distance < minDistance then
            minDistance = distance
            target = ett
        end
    end
    return target
end

--瀵绘�句�瀹����村������浜猴��ㄩ��杩���entitys涓���︽���ら������瀹��┿���烘��ntity锛�
function Actions.GetNearbyFilteredEntities(data, params, context)
    local entity = params.entity
    local teamId = entity:getValue("teamId") or 0
    local entitys = entity:getNearbyEntities(params.distance, function(ett)
        local cfg = ett:cfg()
        if not ett:isValid() or ett.curHp <= 0 or entity == ett then
            return false
        end
        local key, value = params.key, params.value
        if key and cfg[key] ~= value then
            return false
        end
        if params.petExclude and ett:owner() ~= ett then
            return false
        end
        if params.isAI and not ett:getAIControl() then
            return false
        end
        if params.teamMemberExclude and teamId > 0 and ett:getValue("teamId") == teamId then
            return false
        end
        if params.scenesExclude and (cfg.unassailable or cfg.undamageable) then
            return false
        end
        return true
    end)
    if not params.nearest then
        return entitys
    end
    local minDistance
    local target
    for _, ett in pairs(entitys or {}) do
        local distance = entity:distance(ett)
        if not minDistance then
            minDistance = distance
            target = ett
        elseif distance < minDistance then
            minDistance = distance
            target = ett
        end
    end
    return target
end

function Actions.GetEntityMap(data, params, context)
    local entity = params.entity
    if ActionsLib.isInvalidEntity(entity) then
        return
    end
	return entity.map
end

function Actions.SetEntityRebirthPosition(data, params, context)
    local entity = params.entity
    if ActionsLib.isInvalidEntity(entity) then
        return
    end
    local pos = params.pos
    if ActionsLib.isNil(pos, "Position") then
        return
    end
    local map = params.map or pos.map or entity.map
    if ActionsLib.isInvalidMap(map) then
        return
    end
    entity:setRebirthPos(pos, map)
end

function Actions.Play3dSound(data, params, context)
    if not params.file or not params.entity then
        return false
    end
    params.entity:Play3dSound(params.file)
end

function Actions.RideOn(data, params, context)
    if not params.entity or not params.target then
        return false
    end
    params.entity:rideOn(params.target, params.ctrl, params.targetIndex)
end

function Actions.Dismount(data, params, context)
    if not params.entity then
        return false
    end
    params.entity:rideOn()
end

function Actions.GetRideOn(data, params, context)
    if not params.entity then
        return nil
    end
	local id = params.entity.rideOnId
	if id<=0 then
		return nil
	end
    return params.entity.world:getEntity(id)
end

function Actions.ClearRide(data, params, context)
    if not params.entity then
        return
    end
    params.entity:clearRide()
end

function Actions.AddSkill(data, params, context)
    local entity = params.entity
    local skillName = params.name
    if ActionsLib.isInvalidEntity(entity) or ActionsLib.isEmptyString(skillName, "Skill") then
        return
    end
    entity:addSkill(skillName)
end

function Actions.RemoveSkill(data, params, context)
    local entity = params.entity
    local skillName = params.name
    if ActionsLib.isInvalidEntity(entity) or ActionsLib.isEmptyString(skillName, "Skill") then
        return
    end
    entity:removeSkill(skillName)
end

function Actions.LearnSkill(data, params, context)
    if not params.entity then
        return
    end
    params.entity:learnSkill(params.name)
end

function Actions.EquipSkill(data, params, context)
    if not params.entity then
        return
    end
    params.entity:equipSkill(params.name)
end

--锟斤拷取锟斤拷装锟斤拷锟斤拷studySkill
function Actions.GetEquipStudySkills(data, params, context)
    local studySkillMap = params.player:data("skill").studySkillMap
    return studySkillMap and studySkillMap.equipSkills
end

--装锟斤拷studySkill
function Actions.EquipStudySkills(data, params, context)
    for _, v in pairs(params.equipSkills or {}) do
        params.player:syncEquipSkill({equipSkill = {fullName = v.skill}, equipSkillBar = v.equipBar})
    end
end

function Actions.ForgetSkill(data, params, context)
    params.entity:forgetSkill(params.name)
end

function Actions.AddSkillToAllPlayers(data, params, context)
    local skillName = params.name
    if ActionsLib.isEmptyString(skillName, "Skill") then
        return
    end
    for i,v in pairs(Game.GetAllPlayers()) do
        v:addSkill(skillName)
    end
end

function Actions.SearchStudySkill(data, params, context)
	local skillMap = params.entity:getStudySkillMap()
	for name in pairs(skillMap.studySkills or {}) do
		local skill = Skill.Cfg(name)
		if skill[params.key] == params.val then
			return skill.fullName
		end
	end
	return nil
end

function Actions.GetEntityName(data, params, context)
    local entity= params.entity
    if ActionsLib.isInvalidEntity(entity) then
        return ""
    end
    return entity.name
end

function Actions.GetCurrency(data, params, contetx)
    return params.entity:getCurrency(params.coinName).count
end

function Actions.AddCurrency(data, params, contetx)
    params.entity:addCurrency(params.coinName, params.count, params.reason or "action")
end

function Actions.PayCurrency(data, params, context)
    return params.entity:payCurrency(params.coinName,params.count, params.clear, false, params.reason or "action")
end

function Actions.GetWalletBalance(data, params, context)
    return params.entity:getWalletBalance(params.coinName)
end

function Actions.GetOwner(data, params, context)
    local entity = params.entity
    if ActionsLib.isInvalidEntity(entity) then
        return nil
    end
    return entity:owner()
end

function Actions.AddEntityExp(data, params, context)
    local entity = params.entity
    if not entity then
        return
    end
	entity:addExp(params.exp, params.reason or "action")
end

function Actions.GetEntityCurHp(data, params, context)
    local entity = params.entity
    if ActionsLib.isInvalidEntity(entity) then
        return
    end
    return entity.curHp
end

function Actions.GetEntityMaxHp(data, params, context)
    return params.entity:prop("maxHp")
end

function Actions.GetEntityCurVp(data, params, context)
    local entity = params.entity
    if ActionsLib.isInvalidEntity(entity) then
        return
    end
    return entity.curVp
end

function Actions.GetEntityMovingStyle(data, params, context)
    local entity = params.entity
    if ActionsLib.isInvalidEntity(entity) then
        return
    end
	return entity.movingStyle
end

function Actions.GetEntityOnGround(data, params, context)
	return params.entity.onGround
end

function Actions.RecoverFullHp(data, params, context)
    local entity = params.entity
    if ActionsLib.isInvalidEntity(entity) or entity.curHp<=0 then
        return
    end
    local fullHp = entity:prop("maxHp")
    entity:setHp(fullHp)
end

function Actions.RecoverFullVp(data, params, context)
    if params.entity.curHp<=0 then
        return false
    end
    local fullVp = params.entity:prop("maxVp")
    params.entity:setVp(fullVp)
end

function Actions.UpdateEspShop(data,params,content)
   local data= {
       title = params.title,
       des = params.des,
       price = params.price,
       id=params.id,
       key=params.key,
       btn=params.btn,
       money_type=params.money_type,
       image=params.image,
       menu=params.menu,
       event=params.event,
       deal_ico=params.deal_ico,
       lv = params.lv,
	   deal_item = params.deal_item,
	   skillType = params.skillType
   }
    return params.entity:especiallyShop_update(params.menu,params.id,data,params.event,params.close or false)
end

function Actions.AddItem(data, params, context)
    local entity = params.entity
    local itemCfg = params.cfg
    if ActionsLib.isInvalidPlayer(entity) or ActionsLib.isEmptyString(itemCfg, "Item") then
        return false
    end
    if not entity:tray():add_item(itemCfg, params.count, nil, true) then
        return false
    end
    assert(itemCfg ~= "/block",itemCfg)
    entity:data("tray"):add_item(itemCfg, params.count, nil, false, params.reason or "action")
end

function Actions.AddBlockItem(data, params, context) -- old AddBlock
    local entity = params.entity
    local block = params.block
    if ActionsLib.isInvalidEntity(entity) or ActionsLib.isEmptyString(block, "Block") then
        return
    end
    if ActionsLib.isNil(params.count, "BlockItemCount") or params.count<1 then
        return
    end
    entity:addItem("/block", params.count, function(item)
        item:set_block_id(assert(setting:name2id("block", block)), tostring(block))
    end, params.reason or "action")
end

function Actions.searchEquipItem(data,params,context)
    return params.entity:searchEquipItem(params.key,params.val)
end

function Actions.ReplaceItem(data,params,context)
    return params.sloter:replace(params.fullName)
end

function Actions.AddEntityHp(data, params, context)
    local entity = params.entity
    if ActionsLib.isInvalidEntity(entity) or entity.curHp<=0 then
        return
    end
    if params.step < 0 and entity:prop("undamageable") > 0 then
        return
    end
    local maxHp = entity:prop("maxHp")
    local targetHp = math.min( maxHp, params.step + entity.curHp)
    entity:setHp(targetHp)
    if entity.curHp <= 0 then
        entity:onDead({
            from = entity and not entity.removed and entity or nil,
            cause = params.cause or "ACTIONS_ADD_ENTITY_HP",
        })
    end
    return targetHp ~= maxHp
end

function Actions.AddEntityVp(data, params, context)
    local entity = params.entity
    if ActionsLib.isInvalidEntity(entity) then
        return
    end
    local maxVp = entity:prop("maxVp")
    local targetVp = math.min( maxVp, params.step + entity.curVp)
    entity:setVp(targetVp)
    return targetVp ~= maxVp
end

function Actions.replaceHandItem(data, params, context)
    local curHandItem = params.entity:getHandItem()
    if not curHandItem  or not curHandItem:cfg() then
        return false
    end
    curHandItem:replace(params.item)
    return true
end

function Actions.ConsumeItem(data, params, context)
    return params.item:consume(params.num, params.reason or "action")
end

function Actions.ConsumeItem2(data, params, context)
    local entity, item = params.entity, params.item
    if ActionsLib.isInvalidEntity(entity) or ActionsLib.isEmptyString(item, "Item") then
        return false
    end
    local num = params.num
    if ActionsLib.isNil(num, "ItemNumber") or num<1 then
        return
    end
    if not entity:tray():remove_item(item, num, true) then
        return false
    else
        entity:tray():remove_item(item, num, false, nil, nil, params.reason or "action")
        return true
    end
end

function Actions.ConsumeBlockItem(data, params, context)
	local succesd = params.entity:tray():remove_item("/block", params.num, true, params.mglichst, function(item)
		return item:block_id() == setting:name2id("block", params.item)
	end)

	if not succesd then
		return false
	else
		params.entity:tray():remove_item("/block", params.num, false, params.mglichst, function(item)
			return item:block_id() == setting:name2id("block", params.item)
		end, params.reason or "action")
		return true
	end
end

function Actions.SetTextFlash(data, params, context)
    params.entity:sendPacket({
        pid = "SetTextFlash",
	    pos = params.pos,
	    headText = params.headText,
        time = params.time
    })
end

function Actions.SetHeadText(data, params, context)
    local entity = params.entity
    if ActionsLib.isInvalidEntity(entity) then
        return
    end
    entity:setHeadText(params.x, params.y, params.headText)
end

function Actions.GetEntityYaw(data, params, context)
    local entity = params.entity
    if ActionsLib.isInvalidEntity(entity) then
        return
    end
    return entity:getRotationYaw() % 360
end

function Actions.SetEntityYaw(data, params, context)
    local entity = params.entity
    if ActionsLib.isInvalidEntity(entity) then
        return
    end
    entity:setRotationYaw(params.rotationYaw or entity:getRotationYaw())
    entity:syncPosDelay()
end

function Actions.GetEntityPitch(data, params, context)
    return params.entity:getRotationPitch()
end

function Actions.SetEntityPitch(data, params, context)
	local entity = params.entity
	if entity then
		entity:setRotationPitch(params.rotationPitch or entity:getRotationPitch())
        entity:syncPosDelay()
	end
end

function Actions.GetEntityRoll(data, params, context)
    return params.entity:getRotationRoll()
end

function Actions.SetEntityRoll(data, params, context)
    local entity = params.entity
    if entity then
        entity:setRotationRoll(params.rotationRoll or entity:getRotationRoll())
        entity:syncPosDelay()
    end
end

function Actions.GetEntityMainData(data, params, context)
    return params.entity:data("main")[params.key]
end

function Actions.SearchBagItem(data, params, context)
    return params.entity:searchOneItem(params.key,params.val, function(tray)
        return tray:class() == Define.TRAY_CLASS_BAG
    end)
end

function Actions.SetAiData(data, params, context)
    if not params.key then
        return
    end
    local entity = params.entity
    local data = entity:data("aiData")
    data[params.key] = params.value

end

function Actions.PetPutOn(data, params, context)
    local item = params.bagitem
    if not item then
        return false
    end

    local player = params.player
    local pet = params.pet
    local tray_bag = player:tray():fetch_tray(item:tid())
    local slot_bag = item:slot()
	return player:PetPutOn(pet, item)
end

function Actions.IfEntityInArea(data, params, context)
    local entity = params.entity
    local region = params.region
    if ActionsLib.isInvalidEntity(entity) or ActionsLib.isInvalidRegion(region) then
        return nil
    end
    local entityPos = entity:getPosition()
    return Lib.isPosInRegion(region, entityPos)
end

function Actions.ShowContentsList(data, params, context)
    local contentsList = {}
    for i,v in pairs(params.contents) do
        if v then
            contentsList[params.langKey..i] = v
        end
    end
    params.entity:sendPacket({
        pid = "ShowContentsList",
        contentsTittle = params.contentsTittle,
        contentsIcon = params.contentsIcon,
        contentsList = contentsList
    })
end

function Actions.SetGuideStep(data, params, context)
	params.player:setGuideStep(params.step, params.nextOnly, params.canBack)
end

function Actions.GetGuideStep(data, params, context)
    return params.player:getValue("guideStep")
end

function Actions.GetEntityView(data, params, context)
    local viewInfo = params.entity:data("viewInfo")
    if viewInfo.view then
        return viewInfo.view
    end
    return nil
end

function Actions.SetEntityView(data, params, context)
    local view = params.entity:data("viewInfo").view
    if view == params.view then
        return
    end
    params.entity:sendPacket({
        pid = "setEntityView",
        view = params.view
    })
end

function Actions.CastSkill(data, params, context)
    Skill.Cast(params.skill, params.packet, params.from)
end

function Actions.SetGuidePostion(data, params,context)
    params.entity:sendPacket({
        pid = "setGuidePosition",
        pos = params.pos
    })
end

function Actions.SetGuideTarget(data, params,context)
    params.entity:sendPacket({
        pid = "setGuideTarget",
        pos = params.pos,
		guideTexture = params.guideTexture,
		guideSpeed = params.guideSpeed
    })
end

function Actions.DelGuideTarget(data, params,context)
    params.entity:sendPacket({
        pid = "DelGuideTarget"
    })
end

function Actions.ChangeEntityActor(data, params, context)
    local entity = params.entity
    local actorName = params.name
    if ActionsLib.isInvalidEntity(entity) or ActionsLib.isEmptyString(actorName, "Actor") then
        return
    end
    entity:changeActor(actorName, params.clearSkin)
end

function Actions.ChangeEntityActorAlone(data, params, context)
	local entity = params.entity
	local packet = {
		pid = "ChangeActor",
		objID = entity.objID,
		name = params.name,
	}
	params.player:sendPacket(packet)
end

function Actions.Face2Position(data, params, context)
	params.entity:face2Pos(params.pos)
end

function Actions.AddEntityTrayCapacity(data, params, context)
	local size = params.size
    for _, element in pairs(params.entity:tray():query_trays(params.type)) do
        local tray = element.tray
		if tray:capacity() + size <= tray:max_capacity() then
			tray:add_capacity(size)
			return true
		end
	end
	return false
end

function Actions.GetEntityTrayCapacity(data, params, context)
    for _, element in pairs(params.entity:tray():query_trays(params.type)) do
        local tray = element.tray
        return tray:capacity()
    end
end

function Actions.GetEntityTrayMaxCapacity(data, params, context)
    for _, element in pairs(params.entity:tray():query_trays(params.type)) do
        local tray = element.tray
        return tray:max_capacity()
    end
end

function Actions.GetEntityTrayAvailableCapacity(data, params, context)
    return params.entity:tray():check_available_capacity(params.trayType)
end

function Actions.FindFreeTray(data, params, context)
	local trayArray = params.entity:tray():query_trays(params.trayType)
	for _, element in pairs(trayArray) do
		local tray = element.tray
		local slot = tray:find_free()
		if slot then
			return {tid = element.tid, slot = slot}
		end
	end
end

function Actions.CountTrayItemNum(data, params, context)
    local trayArray = params.entity:tray():query_trays(params.trayType)
    local count = 0
    for _, element in pairs(trayArray) do
        local tray = element.tray
        count = tray:count_item_num_by_fullname() + count
    end
    return count
end

function Actions.EntityDieDrop(data, params, context)
    local entity = params.entity
    if ActionsLib.isInvalidEntity(entity) then
        return nil
    end
    return entity:dropOnDie(params.from)
end

function Actions.ShowEntityInfo(data, params, context)
    local entity = params.entity
    if not entity then
        return
    end
    entity:showTargetInfo(params.target,params.flag)
end

function Actions.GetEntityLevel(node, params, context)
    local entity = params.entity
    if ActionsLib.isInvalidEntity(entity) then
        return nil
    end
    return entity:getValue("level")
end

function Actions.GetEntityHandItem(data, params, context)
    local entity = params.entity
    if not entity then
        return nil
    end
    return entity:getHandItem()
end

function Actions.SetDamageText(data, params, context)
    local entity = params.entity
    if not entity then
        return 
    end
    entity:setDamageText(params.text)
end

function Actions.SetEntityToBlock(data, params, context)
    local entity = params.entity
    local fillBlockData = params.fillBlock
    entity:SetEntityToBlock(fillBlockData)
end

function Actions.IsEntityMoving(data, params, context)
    return params.entity.isMoving
end

function Actions.IsEntitySwimming(data, params, context)
    return params.entity:isSwimming()
end

function Actions.PlayAction(data, params, context)
    local entity = params.entity
    local target = params.target
    local actionName = params.actionName
    local actionTime = params.actionTime
    local includeSelf = params.includeSelf or false
    if not entity or not actionName or not actionTime then
        return false
    end
    local packet = {
		pid = "EntityPlayAction",
		objID = entity.objID,
		action = actionName,
        time = actionTime,
        refreshBaseAction = params.refreshBaseAction
    }
    if target and target.isPlayer then
        target:sendPacket(packet)
    else
        entity:sendPacketToTracking(packet, includeSelf)
    end
    return true
end

function Actions.SetEntityActorFlashEffect(data, params,context)
    params.entity:sendPacket({
        pid = "SetEntityActorFlashEffect",
        add = params.add
    })
end

function Actions.GetEntityBoundingBox(data, params, content)
	local entity = params.entity
	if not entity then
		return false
	end
    return entity:getBoundingBox()
end

function Actions.IsEntityTouchOn(data, params, content)
	local entity1 = params.entity1
	local entity2 = params.entity2
	if not entity1 or not entity2 then
		return false
	end
	local BoundingBox = params.entity1:getBoundingBox()
    local box = { 0, 0, 0 }
    if BoundingBox then
	    box = {
		    math.abs(BoundingBox[2].x - BoundingBox[3].x),
		    math.abs(BoundingBox[2].y - BoundingBox[3].y),
		    math.abs(BoundingBox[2].z - BoundingBox[3].z)
	    }
    end
	local pos1 = entity1:getPosition()
	local pos2 = entity2:getPosition()
	if not pos1 and not pos2 then
		return false
	end
	return pos2.y - pos1.y >= box[2]
end

function Actions.IsEntityTouchTop(data, params, content)
	local entity1 = params.entity1
	local entity2 = params.entity2
	if not entity1 or not entity2 then
		return false
	end
	local BoundingBox = params.entity2:getBoundingBox()
    local box = { 0, 0, 0 }
    if BoundingBox then
	    box = {
		    math.abs(BoundingBox[2].x - BoundingBox[3].x),
		    math.abs(BoundingBox[2].y - BoundingBox[3].y),
		    math.abs(BoundingBox[2].z - BoundingBox[3].z)
	    }
    end
	local pos1 = entity1:getPosition()
	local pos2 = entity2:getPosition()
	if not pos1 and not pos2 then
		return false
	end
	return pos1.y - pos2.y >= box[2]
end

local function boundingBoxTouch(BoundingBox1, BoundingBox2)
    local b1min = BoundingBox1[2]
    local b1max = BoundingBox1[3]
    local b2min = BoundingBox2[2]
    local b2max = BoundingBox2[3]
    
    if b1max.x < b2min.x then
        return false
    end
    if b1max.y < b2min.y then
        return false
    end
    if b1max.z < b2min.z then
        return false
    end
    if b2max.x < b1min.x then
        return false
    end
    if b2max.y < b1min.y then
        return false
    end
    if b2max.z < b1min.z then
        return false
    end
    return true
end

function Actions.IsEntityTouch(data, params, content)
	local entity1 = params.entity1
	local entity2 = params.entity2
	if not entity1 or not entity2 or (entity1.objID == entity2.objID) then
		return false
	end
    local b1 = params.entity1:getBoundingBox()
    local b2 = params.entity2:getBoundingBox()
    
	return b1 and b2 and boundingBoxTouch(b1, b2)
end

function Actions.SendPlayDeadAction(data, params, context)
    local entity = params.entity
    if not entity then
        return false
    end
    local actionCfgName = params.actionCfgName
    local deadActions = entity:cfg().deadActions
    if not deadActions then
        return false
    end
    local cfg = deadActions[actionCfgName]
    if not cfg then
        return false
    end
    local packet = {
        pid = "EntityDeadAction",
        objID = entity.objID,
        actionCfgName = actionCfgName,
    }
    entity:sendPacketToTracking(packet, true)
    return true
end

function Actions.GetEntityCfg(data, params, context)
    if not params.fullName then
        return
    end
    local cfg = Entity.GetCfg(params.fullName)
    if not params.key then
        return cfg
    end
    return cfg[params.key]
end

function Actions.SetActorAlpha(data, params, context)
	local entity = params.entity
	 entity:sendPacketToTracking({
		pid = "SetEntityActorAlpha",
		alpha = params.alpha,
		objID = entity.objID
	}, true)
end

function Actions.MoveForward(data, params, context)
    local entity = params.entity
    local step = params.step or 1
    local pos = entity:getFrontPos(step, true)
    local blockPos = Lib.v3(math.floor(pos.x),math.floor(pos.y), math.floor(pos.z))
    if entity.map:getBlockConfigId(blockPos) == 0 then
        entity:setMapPos(entity.map, pos)
    end
end

function Actions.SetPos(data, params, context)
    local entity = params.entity
    local pos = Lib.tov3({x = params.x, y = params.y, z = params.z})
    entity:setMapPos(entity.map, pos, params.yaw, params.pitch)
end

function Actions.GetBlockAndEntityCenterDistance(data, params, context)
    local entity = params.entity
    if not entity then
        return false
    end
    local map = entity.map
    local block = World.CurWorld:getMap(map):getBlock(params.block)
    if not block then
        return -1
    end

    local sinYaw = math.sin(math.rad(entity:getRotationYaw()))
    local cosYaw = math.cos(math.rad(entity:getRotationYaw()))
    if entity:getRotationYaw() % 90 == 0 then --math.rad 绮惧害��瀵艰��math.cos(-math.rad(-90)) ~= 0
        if math.abs(sinYaw) < 0.00001 then
            sinYaw = 0
        elseif math.abs(cosYaw) < 0.00001 then
            cosYaw = 0
        end
    end
    local bCenterX = math.floor(block.x)
    local bCenterZ = math.floor(block.z)
    local pos = entity:getPosition()
    local eCenterX = math.floor(pos.x)
    local eCenterZ = math.floor(pos.z)
    local distance = math.sqrt(math.abs((bCenterZ - eCenterZ) * sinYaw + (bCenterX - eCenterX) * cosYaw))
    return distance
end

function Actions.SetOnCenterOfCurrentArea(data, params, context)
    local pos = params.entity:getPosition()
    pos.x = math.floor(pos.x) + 0.5
    pos.z = math.floor(pos.z) + 0.5
    params.entity:setMapPos(params.entity.map, pos)
end

function Actions.TouchBlock(data, params, context)
    local entity = params.entity
     entity:sendPacketToTracking({
        pid = "TouchBlock",
        objID = entity.objID,
        pos = params.pos
    }, true)
end

function Actions.ResetBuyCountByIndex(data, params, context)
    Shop:resetBuyCountByIndex(params.entity, params.index)
end

function Actions.GetHitching(data, params, context)
	local entity = params.entity
	local getHitchingId = entity:getHitchingId()
	if getHitchingId > 0 then
		return World.CurWorld:getObject(getHitchingId)
	end
	return 
end

function Actions.SetBodyYaw(data, params, content)
    local yaw = params.yaw
    local entity = params.entity
    local packet = {
        pid = "SetEntityBodyYaw",
        objID = params.entity.objID,
        rotationYaw = yaw
    }
    entity:sendPacketToTracking(packet, true)
end

function Actions.GetSkin(data, params, content)
    return params.entity:data("skin")[params.skinName]
end

function Actions.SetSkin(data, params, content)
    local skinData = {}
    skinData[params.skinName] = params.skinValue
    params.entity:changeSkin(skinData)
end

function Actions.SetEntityName(data, params, context)
    local entity = params.entity
    if not entity then
        return
    end
    entity.name = params.name or ""     -- auto sync during entity spawn
    local packet = {
        pid = "SetEntityName",
        objID = entity.objID,
        name = entity.name
    }
    entity:sendPacketToTracking(packet, true)
end

function Actions.CheckBalance(data, params, context)
    local currency = params.entity:getCurrency(params.coinName)
    return currency and currency.count >= params.price
end

function Actions.GetLastPos(data, params, context)
	return params.entity.lastPos
end

function Actions.GetPassengers(data, params, content)
    local entity = params.entity
    if not entity then
        return
    end

    return entity:data("passengers") or nil
end
function Actions.StopTimeLine(data, params, context)
    local timerLineData = params.entity:data("skill").timerLineData
    if timerLineData and timerLineData.timer then
        timerLineData.timer()
        timerLineData.timer = nil
        timerLineData.time = 0
        timerLineData.repeatTimes = 0
    end
    timerLineData = {}
end

function Actions.SetForceMove(data, params, context)
    params.entity:setForceMove(params.pos, params.time)
end

function Actions.ShowEditEntityPosRot(data, params, context)
    if not World.cfg.enableShowEditEntityPosRot then
        return
    end
    
    local player = params.player
    local entityId = params.entityId
    if not entityId or not player then
        return
    end
    player:sendPacket({
        pid = "ShowEditEntityPosRot",
        objID = entityId
    })
end

function Actions.AddAllEquipBuff(data, params, context)
    local entity = params.entity
    if not entity or not entity:isValid() then
        return
    end
    local equipTrays = entity:cfg().equipTrays
    if not equipTrays then
        return
    end
    for _, element in pairs(entity:tray():query_trays(type)) do
        local tray = element.tray
        local items = tray and tray:query_items(function(item)
            return item:cfg().equip_buff
        end)
        for _, item in pairs(items) do
            entity:addBuff(item:cfg().equip_buff)
        end
    end
    entity:saveHandItem(entity:getHandItem(), nil, true)
end
