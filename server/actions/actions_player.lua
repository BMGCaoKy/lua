local BehaviorTree = require("common.behaviortree")
local Actions = BehaviorTree.Actions
require "world.world"
local setting = require "common.setting"
local item_manager = require "item.item_manager"

function Actions.ShowSelect(data, params, context)
	if not params.entity.isPlayer then
		return
	end
    local player = params.entity
    local regId = nil
    local eventMap = {}
    local sendOptions = {}
    for i, v in pairs(params.options) do
        eventMap[i] = v[1] or v.triggerName
        sendOptions[i] = v[2] or v.showText
    end
    regId = player:regCallBack("select", eventMap, true, true)

    params.entity:sendPacket({
        pid = "ShowSelect",
        regId = regId,
	    content = params.content,
	    options = sendOptions,
        forcedChoice = params.forcedChoice,
        tittle = params.tittle,
        showMask = params.showMask
    })
end

function Actions.IsPlayer(data, params, context)
    return (params.entity or false) and params.entity:isValid() and params.entity.isPlayer
end

function Actions.GetPlayerKillCount(node, params, context)
    local entity = params.entity
    if ActionsLib.isInvalidPlayer(entity) then
        return
    end
    return entity:data("main").kills or 0
end

function Actions.setPlayCameraYawToAttacker(node, params, context)
    local entity = params.entity
    local target = params.target
    if ActionsLib.isInvalidPlayer(entity) or ActionsLib.isInvalidEntity(target, "Target") then
        return
    end
    entity:setCameraYaw(target)
end

function Actions.SetNoviceGuide(data, params, context)
    params.player:sendPacket({pid = "SetNoviceGuide", fullName = params.fullName, image = params.image})
end

function Actions.ShowNoviceGuide(data, params, context)
    local guideFullName = params.fullName
    if not guideFullName then
        guideFullName = "myplugin/guide"
    end
    params.player:sendPacket({pid = "SetNoviceGuide", fullName = guideFullName, image = params.image})
end

function Actions.ShowRecharge(data, params, context)
	params.player:sendPacket({pid = "ShowRecharge"})
end

function Actions.CheckPlayerAreaCount(node, params, context)
    return params.player:checkPlayerAreaCount(params.distance)
end

function Actions.PlayHeartbeat(data, params, context)
    params.player:sendPacket({
        pid = "PlayHeartbeat",
        path = params.path,
        interval = params.interval
    })
end

function Actions.StopHeartbeat(data, params, context)
    params.player:sendPacket({ pid = "StopHeartbeat" })
end

function Actions.SetHeartbeatSpeed(data, params, context)
    params.player:setHeartbeatSpeed(params.interval)
end

function Actions.AcceptTask(data, params, context)
    local player = params.player
    local taskData = player:data("task")
    if taskData[params.name] then
        return false
    end
    player:sendPacket({
        pid = "ShowTask",
        type = 1,
        show = params.show == nil and true or params.show,
        name = params.name
    })
end

function Actions.FinishTask(data, params, context)
    local player = params.player
    local taskData = player:data("task")
    local task = Player.GetTask(params.name)
    local ret = player:isTaskFinished(task)
    if ret or not taskData[params.name] then
        return
    end
    player:sendPacket({
        pid = "ShowTask",
        type = 2,
        show = params.show == nil and true or params.show,
        name = params.name
    })
end

function Actions.DoFinishTask(data, params, context)
	return params.player:finishTask(params.name)
end

function Actions.StartTask(data, params, context)
	local player = params.player
	return player:startTask(params.fullName)
end

function Actions.GetTaskData(data, params, context)
	local task = Player.GetTask(params.name)
	if not params.key then
		return task
	end
	return task[params.key]
end

function Actions.GetTaskStatus(data, params, context)
	local task = Player.GetTask(params.name, params.cfg)
	return params.player:getTaskData(task).status
end

function Actions.CancelTask(data, params, context)
	local player = params.player
    local taskData = player:data("task")
    local task = params.task or Player.GetTask(params.name)
	return player:abortTask(task.fullName)
end

function Actions.AddTarget(data, params, context)
	 params.entity:addTarget(params.type, params.fullName or params.target._cfg.fullName)
end

function Actions.GetPlayerMap(data, params, context)
    local player = params.player
    if ActionsLib.isInvalidPlayer(player) then
        return
    end
    return player.map or player.map.name
end

function Actions.GetPlayerUserID(data, params, context)
	return params.player.platformUserId
end

function Actions.GetPartyInfoByUserId(data, params, context)
    local userId = params.player.platformUserId
    AsyncProcess.GetPartyInfo(params.targetUserId, function (inPartyInfo)
        local player = Game.GetPlayerByUserId(userId)
        if player then
            Trigger.CheckTriggers(player:cfg(), params.callback, {obj1 = player, partyInfo = inPartyInfo})
        end
    end)
end

function Actions.GetPartyInfo(data, params, context)
    AsyncProcess.GetPartyInfo(params.targetUserId, function (inPartyInfo)
        Trigger.CheckTriggers(nil, params.callback, { partyInfo = inPartyInfo})
    end)
end

function Actions.BroadcastPartyInvite(data, params, context)
    local inviter = params.player or params.inviter
    local inviterUserId = inviter.platformUserId
    local partyOwnerUserId = params.partyOwnerUserId or inviterUserId
    local factor = World.cfg.partyInviteNumFactor or 1
    AsyncProcess.GetPartyInfo(partyOwnerUserId, function (inPartyInfo)
        if not inPartyInfo.maxPlayerNum or not inPartyInfo.curPlayerNum then
            return
        end

        local leftNum = inPartyInfo.maxPlayerNum - inPartyInfo.curPlayerNum
        if leftNum <= 0 then
            return
        end
        UserInfoCache.LoadCacheByUserIds({inviterUserId}, function ()
            local selfInfo = UserInfoCache.GetCache(inviterUserId)
            local content = {
                userId = inviterUserId,
                picUrl = selfInfo.picUrl,
                nickName = selfInfo.nickName or selfInfo.name,
                fromParty = true,
                partyInfo = inPartyInfo,
                showTime = World.cfg.inviteShowTime or 100,
                count = math.floor(factor * leftNum),
                regionId = inviter:data("mainInfo").regionId or 0,
                lang = inPartyInfo.language,
            }
            AsyncProcess.SendBroadcastMessage(nil, content, Define.BROADCAST_INVITE, "game")
        end)
    end)
end

function Actions.TryJoinParty(data, params, context)
    local targetUserId = assert(params.targetUserId)
    if Game.GetPlayerByUserId(targetUserId) and WorldServer:getServerTags().isGameParty then
        Trigger.CheckTriggers(params.player:cfg(), "CROSS_SERVER_VISIT_FAILED", {obj1 = params.player, message = "tip.visit.same.server"})
        return
    end

    PartyManager.TryJoinParty(params.player.platformUserId, params.targetUserId, params.partyId)
end

function Actions.LeaveParty(data, params, context)
    PartyManager.LeaveParty(params.player.platformUserId, params.targetUserId)
end

function Actions.CloseParty(data, params, context)
    PartyManager.CloseParty(params.player.platformUserId)
end

function Actions.TryCreateParty(data, params, context)
    PartyManager.TryCreateParty(params.player.platformUserId)
end

function Actions.PayPartyCost(data, params, context)
    PartyManager.PayPartyCost(params.userId, params.time)
end

function Actions.GetPlayerByUserId(data, params, context)
    return Game.GetPlayerByUserId(params.userId)
end

function Actions.CrossServerVisitPlayerByUserId(data, params, context)
    local targetUserId = assert(params.targetUserId)
    local player = params.player
    if Game.GetPlayerByUserId(targetUserId) and WorldServer:getServerTags().isGameParty then
        Trigger.CheckTriggers(player:cfg(), "CROSS_SERVER_VISIT_FAILED", {obj1 = player, message = "tip.visit.same.server"})
        return
    end
    params.player:crossServerLogin(tonumber(targetUserId))
end

function Actions.ReenterGame(data, params, context)
    params.player:reenterGame()
end

function Actions.ShowAttackHitTip(data, params, context)
    params.player:sendPacket({
        pid = "ShowAttackHitTip",
        start = params.start,
		finish = params.finish,
        imageset = params.imageset,
    })
end

function Actions.ShowPlayerKillTip(data, params, context)
    params.player:sendPacket({ pid = "ShowPlayerKillTip", count = params.count })
end

function Actions.SetBgmRate(data, params, context)
    params.player:sendPacket({
        pid = "SetBgmRate",
        rate = params.rate
    })
end

-- 在某玩家客户端给entity加buff（如：在客户端给entity加个buff添加特效，只有该客户端可见）
function Actions.MarkEntityForPlayer(data, params, context)
    local player = params.player
    if player and player.isPlayer then
        player:sendPacket({pid = "MarkEntityForPlayer", targetId = params.entity.objID, buffName = params.buffName, buffTime = params.buffTime})
    end
end

function Actions.UnMarkEntityForPlayer(data, params, context)
    local player = params.player
    if player and player.isPlayer then
        player:sendPacket({pid = "UnMarkEntityForPlayer", targetId = params.entity.objID, buffName = params.buffName})
    end
end

function Actions.CommodityBuyItem(data, params, context)
  local commodity = Commodity:GetCommodity(params.itemIndex)
  if not Commodity:enoughMoney(commodity, params.player) then
    return "ack_of_money"
  end
  return Commodity:buyShop(commodity, params.player) --msg
end

function Actions.ShowBgmList(data, params, context)
	params.player:sendPacket({pid = "ShowBgmList", show = true, playingIndex = params.playingIndex})
end

function Actions.HideBgmList(data, params, context)
	params.player:sendPacket({pid = "ShowBgmList", show = false, playingIndex = params.playingIndex})
end

function Actions.SendUpdatePlayingBgmIndex(data, params, context)
	params.player:sendPacket({pid = "UpdateBgmPlayingIndex", show = false, playingIndex = params.playingIndex})
end

function Actions.RequestTrade(data, params, context)
	local player = params.player
	local target = params.target
	Trade.requestTrade(player, target, params.itemTrayType, params.itemFilters, params.maxImum)
end

function Actions.CreateTrade(data, params, context)
	local player1 = params.player1
	local player2 = params.player2
	local trade = Trade.create(player1, player2, params.itemTrayType, params.itemFilters, params.maxImum)
end

function Actions.BreakTrade(data, params, context)
	local trade = Trade.getTrade(params.tradeID)
	if trade then
		trade:close(params.reason or "Actions")
	end
end

function Actions.AbolishTrade(data, params, context)
	local trade = Trade.getTrade(params.tradeID)
	trade:close("Abolish")
end

function Actions.AccomplishTrade(data, params, context)
	local trade = Trade.getTrade(params.tradeID)
	trade:close("Accomplish")
end

function Actions.ResetTrade(data, params, context)
	local trade = Trade.getTrade(params.tradeID)
	if trade then
		trade:resetTrade()
	end
end

function Actions.SetHandItem(data, params, context)
    params.player:saveHandItem(params.item, params.excludeSelf)
end

function Actions.IsCameraMode(data, params, context)
    return params.player:isCameraMode()
end

function Actions.SetCameraMode(data, params, context)
    params.player:syncCameraMode(params.isOpen)
end

function Actions.CheckSignInShow(data, params, context)
	return params.player:checkSignIn()
end

function Actions.UploadPrivilege(data, params, context)
	if params.player then
		AsyncProcess.UploadPrivilege(params.player.platformUserId)
	end
end

function Actions.ShowEdge(data, params, context)
    local target = params.target
    params.player:sendPacket({
        pid = "ShowEdge",
        targetId = target and target.objID,
        switch = params.switch,
        color = params.color
    })
end

function Actions.IsPlayerReloading(data, params, context)
    return params.player:data("reload").reloadTimer and true or false
end

function Actions.GetPlayerManorId(data, params, content)
    local player = params.player
    if not player or not player.isPlayer then
        return
    end
    return player:data("mainInfo").manorId or -1
end

function Actions.ChangeToAppAppearance(data, params, content)
    local entity = params.entity 
    if ActionsLib.isInvalidPlayer(entity) then
        return
    end
    entity:changeToAppAppearance()
end
