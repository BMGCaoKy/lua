local handles = T(Player, "PackageHandlers")

function handles:SetGoldAppleHp(packet)
    Lib.emitEvent(Event.EVENT_SET_GOLD_APPLE_HP, packet)
end

function handles:SendGameResult(packet)
    Lib.emitEvent(Event.EVENT_GAME_RESULT, packet)
end

function handles:GetTeamHeadText(packet)
    local teamID = self:getValue("teamId")
    if teamID <= 0 then
        return
    end
    local teamName = Lang:toText(Game.GetTeamName(teamID))
    local teamColor = Game.GetTeamColorValue(teamID)
    self:doCallBack("GetTeamHeadText", "headText", packet.regId, { headText = string.format("[C=%s]%s[%s]", teamColor, self.name, teamName)})
end

function handles:UpdateTeamRank(packet)
    Lib.emitEvent(Event.EVENT_UPDATE_TEAM_RANK, packet.rankData)
end

function handles:UpdatePlayerRank(packet)
    Lib.emitEvent(Event.EVENT_UPDATE_PLAYER_RANK, packet.rankData)
end

function handles:ClacTemporaryShieldBar(packet)
    Lib.emitEvent(Event.CLAC_TEMPORARY_SHIELD, packet.objId)
end

function handles:ShowMerchantShop(packet)
    if GUIManager:Instance():isEnabled() then
        UI:openShopInstance("commodity", packet.merchantGroupName)
    else
        UI:openWnd("merchantstores", packet.merchantGroupName)
    end
end

function handles:UpdateEntityHeadUI(packet)
    local objID = packet.objID
	if not objID then
		return
    end
    local updateStatus = packet.updateStatus
    local params = packet.params
    if not SceneUIManager.GetEntityHeadUI(objID) then
        local params = {uiCfg = {name = "temporaryShield", width = 2, height = 5}, openParams = {area = {{0,23},{0,1},{0,-26},{0,10}}}}
        SceneUIManager.AddEntityHeadUI(objID, params)
    end
    if updateStatus == "remove" then
        SceneUIManager.RemoveEntityHeadUI(objID)
    elseif updateStatus == "ref" then
        SceneUIManager.RefreshEntityHeadUI(objID, params)
    end
end

function handles:PlayBreakBlockSound(packet)
    local blockCfg = Block.GetIdCfg(packet.id)
    local sound = blockCfg.breakBlockAfterSound
	if not sound or not sound.sound then
		return nil
    end
    
	if not sound.path then
        sound.path = ResLoader:filePathJoint(blockCfg, sound.sound)
    end
    
    local isLoop=false
    if sound.loop~=nil then
       isLoop= sound.loop
    end

    local id = TdAudioEngine.Instance():play3dSound(sound.path, packet.pos, isLoop)
	if sound.volume then
		TdAudioEngine.Instance():setSoundsVolume(id, sound.volume)
	end
end

function handles:KillTip(packet)
    local fromObjID = packet.fromObjID
    local targetObjID = packet.targetObjID
    local from = fromObjID and World.CurWorld:getObject(fromObjID)
    local target = targetObjID and World.CurWorld:getObject(targetObjID)
    local fromName = from and from.name or ""
    local targetName = target and target.name or ""
    if Me.objID == fromObjID then
        fromName = "▢FFFF0000 "..fromName.." ▢FF00FF00"
    elseif Me.objID == targetObjID then
        targetName = "▢FFFF0000 "..targetName.." ▢FF00FF00"
    end
    local msg = Lang:formatMessage(packet.key, {fromName, targetName})
    Lib.emitEvent(Event.EVENT_CHAT_MESSAGE, msg)
end

function handles:SendBuyCommodityResult(packet)
    Lib.emitEvent(Event.EVENT_SEND_BUY_COMMODITY_RESULT, packet.msg, packet.index, packet.result)
end

function handles:SendBuyCommodityShopIsLimit(packet)
    Lib.emitEvent(Event.EVENT_SEND_BUY_COMMODITY_SHOP_IS_LIMIT, packet.index)
end

function handles:UpdatePlayerEquipAdditionalBuffList(packet)
    self:updateEquipBuffList(packet)
end

function handles:UpdateMovingStyle(packet)
    Blockman.instance:setKeyPressing("key.sneak", packet.movingStyle == 0 and true or false)
end

function handles:SyncStageScore(packet)
    --覆盖引擎接口，不显示分数
end

function handles:UpdateScaleWhenRebirth(packet)
    local entity = World.CurWorld:getEntity(packet.objID)
    entity:entityActorSquashed(1)
end

function handles:SetForceMoveTimePos(packet)
    local entity = World.CurWorld:getEntity(packet.objID)
    if not entity then
        return false
    end
    entity.forceTargetPos = packet.targetDir
    entity.forceTime = packet.time
end

function handles:UpdateAliveCount(packet)
    Lib.emitEvent(Event.EVENT_UPDATE_ALIVE_COUNT, packet.aliveCount)
end

function handles:ExitGame(packet)
    if World.CurWorld.isEditorEnvironment then
        UI:getWnd("main"):enterEditorMode()
    elseif packet.canRevive then
        Lib.emitEvent(Event.EVENT_MENU_EXIT)
    else
        CGame.instance:exitGame()
    end
end

function handles:ShowOverPopView(packet)
    UI:openWnd("overPop", packet)
end

local msgQueue = {}
local msgTimer = nil 
local first, second = 1, 0
function handles:ShowToastTip(packet)
    second = second + 1
    msgQueue[second] = packet.textKey
    if msgTimer then
        return
    end
    msgTimer = World.Timer(20, function()
        if first > second then
            msgTimer = nil
            return false
        end
        local langKey = msgQueue[first] 
        msgQueue[first] = nil
        first = first + 1
        Lib.emitEvent(Event.EVENT_TOAST_TIP, Lang:toText(langKey), 20)
        return true
    end)
end

function handles:SendRoomOwnerId(packet)
    if not Me.isEditorServerEnvironment or UI:isOpenWindow("online_room_info") then
        return
    end
    local toolbarWnd = UI:isOpenWindow("toolbar")
    local isOpenOnlineRoom = packet.roomOwnerId and packet.roomOwnerId~=0
    if toolbarWnd and isOpenOnlineRoom then
        toolbarWnd:openOnlineRoom(packet.roomOwnerId)
    end
end

function handles:UpdateWorldTime(packet)
    local curTime = World.CurWorld:getWorldTime()
    local offset = curTime - packet.time
    local oneDayTime = World.cfg.oneDayTime or 1200
    local timeSpeed = 1200 / oneDayTime * 20
    if math.abs(offset) < timeSpeed then
        return
    end
    World.CurWorld:setWorldTime(packet.time)
end

function handles:UpdateLeftTime(packet)
    Client.ShowTip(5, "game.playTime", nil, packet)
end

function handles:ShowPropCollectRank(packet)
    --UI:openSystemWindowAsync(function(window) end,"CollectPropResultRank", "", {rankData = packet.rankData})
    UI:openSystemWindow("CollectPropResultRank", "", {rankData = packet.rankData})
end