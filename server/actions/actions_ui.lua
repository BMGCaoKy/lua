local BehaviorTree = require("common.behaviortree")
local Actions = BehaviorTree.Actions
require "world.world"
local setting = require "common.setting"

--����ʽѡ��
function Actions.ShowCardOptionsView(data, params, context)
    local entity = params.entity
    local options = params.options
    if not entity.isPlayer or not options then
		return
	end
    local eventMap = {}
    for k, v in pairs(options) do
        eventMap[v.event] = v.event
    end
    local callBackModName = "CardOptionsSelect"
    local regId = entity:regCallBack(callBackModName, eventMap, true, true, context)

    entity:sendPacket({
        pid = "ShowCardOptionsView",
        uiCfg = params.uiCfg,
        regId = regId,
	    options = params.options,
        title = params.title,
        detail = params.detail,
        callBackModName = callBackModName
    })
end

function Actions.ShowNotice(data, params, context)
	local player = params.entity
    assert(player.isPlayer, player.isEntity and player:isValid() and player.name)
	local regId = nil
	if params.buttonType==2 or params.buttonType==1 then
		local eventMap = {
			["yes"] = params.eventYes or false,
			["no"] = params.eventNo or false,
			["sure"] = params.eventSure or false,
		}
		regId = player:regCallBack("notice", eventMap, true, true, context)
	end
    player:sendPacket({
        pid = "ShowNotice",
	    buttonType = params.buttonType,
        regId = regId,
        uiCfg = params.uiCfg,
        itemIcon = params.itemIcon,
        itemCount = params.itemCount,
        yesKey = params.yesKey,
		noKey = params.noKey,
		sureKey = params.sureKey,
        textArgs = {params.textP1, params.textP2, params.textP3},
        titleKey = params.titleKey,
        content = params.content
    })
end

function Actions.AddWaitDealUI(data, params, context)
    local player = params.entity
    assert(player.isPlayer, player.isEntity and player:isValid() and player.name)
    local eventMap = {
        ["yes"] = params.eventYes or false,
        ["no"] = params.eventNo or false,
        ["cancel"] = params.eventCancel or false,
    }

    local regId = player:regRemoteCallback("waitDeal", eventMap, true, true, context, false)
    player:sendPacket({
        pid = "AddWaitDealUI",
        level = params.level,
        name = params.name,
        desc = params.desc,
        offtime = params.offtime,
        regId = regId
    })
end

function Actions.ShowMerchantShop(data, params, content)
    params.entity:sendPacket({
        pid = "ShowMerchantShop",
        showType = params.showType,
        showTitle = params.showTitle
    })
end

function Actions.ShowUpgradeShop(data, params, context)
	params.entity:sendPacket({
        pid = "ShowUpgradeShop"
    })
end

function Actions.ShowPersonalInformations(data, params, context)
    if params.target then
        params.player:sendPacket({
            pid = "ShowPersonalInformations",
            objID = params.target.objID
        })
    end
end

function Actions.ShowRewardNotice(data, params, context)
    params.entity:sendPacket({
        pid = "ShowRewardNotice",
        tittletext = params.tittletext,
        tiptext = params.tiptext,
        cfg = params.cfg
    })
end

function Actions.ShowRewardRollTip(data, params, contetx)
    params.entity:sendPacket({
        pid = "ShowRewardRollTip",
        image = params.image,
        text = params.text
    })
end

function Actions.ShowComposition(data, params, context)
    params.entity:sendPacket({
        pid = "ShowComposition",
        class = params.class,
        show = params.show
    })
end

function Actions.ShowUINavigation(data, params, context)
    params.entity:sendPacket({
        pid = "ShowUINavigation",
        name = params.name,
        show = params.show == nil and true or params.show,
        delay = params.delay
    })
end

function Actions.ShowNavigation(data, params, context)
    local entity = params.entity
    local regId = entity:getCallBackRegId("uiNavigation")
    if regId then 
        entity:sendPacket({
            pid = "ShowNavigation",
            navRegId = regId
        })
    end
end

function Actions.OpenConversation(data, params, context)
    local entity = params.entity
    if ActionsLib.isInvalidPlayer(entity) then
        return
    end
    local npcList = {}
    local tmpNpc = {}
    local talkList = {}
    for _, v in pairs(params.talkList) do
        if not tmpNpc[v.npc] then
            npcList[#npcList + 1] = v.npc
            tmpNpc[v.npc] = #npcList
        end
        table.insert(talkList, {
            npc = tmpNpc[v.npc],
            msg = v.msg
        })
    end

	local eventMap = {}
	for k, v in pairs(params.optionList or {}) do
        eventMap[k] = v.triggerName
    end
    local regId = params.entity:regCallBack("Conversation", eventMap, true, true)
    npcList[#npcList + 1] = not tmpNpc[params.optionNpc] and params.optionNpc
    params.optionNpc = tmpNpc[params.optionNpc] or #npcList
   
    params.entity:sendPacket({
        pid = "OpenConversation",
        talkList = talkList,
        npcList = npcList,
        optionList = params.optionList,
        optionNpc = params.optionNpc,
		regId = regId
    })
end

function Actions.ShowSystemChat(data, params, context)
    local entity = params.entity
    params.args= params.args or {}
    params.args.isOpenChatWnd = true
    if ActionsLib.isInvalidPlayer(entity) then
        return
    end
    local packet ={
        pid = "SystemChat",
        objID = entity.objID,
        key = params.key,
        args = params.args
	}
	entity:sendPacket(packet)
end

function Actions.BroadcastNotice(data, params, context)
    WorldServer.SystemNotice(params.tipType, params.textKey, params.time,params.textP1, params.textP2, params.textP3, params.textP4)
end

function Actions.ShowTip(data, params, context)
    local entity = params.entity
    local keepTime = params.keepTime
    if ActionsLib.isInvalidPlayer(entity) or ActionsLib.isNil(keepTime, "KeepTime") then
        return
    end
    if keepTime <= 0 then
        return
    end
    entity:sendTip(params.tipType, params.textKey, keepTime, params.vars, params.event, params.textP1, params.textP2, params.textP3)
end

function Actions.ShowRoutine(data, params, context)
    if not params.entity or not params.entity.isPlayer then
        return
    end
    params.entity:UpdataRoutine(params.content, params.data)
end

function Actions.ShowCountDown(data, params, context)
    if not params.entity or not params.entity.isPlayer then
        return
    end
    params.entity:showCountDown(params.time, params.flag)
end

function Actions.StopDeadCountDown(data, params, context)
    if not params.entity or not params.entity.isPlayer then
        return
    end
    if params.entity then
        params.entity:sendPacket({pid = "StopDeadCountDown"})
    else
        WorldServer.BroadcastPacket({pid = "StopDeadCountDown"})
    end
end

function Actions.ShowBuyRevive(data, params, context)
    if not params.entity or not params.entity.isPlayer then
        return
    end
    params.entity:showBuyRevive(params.time, params.coin, params.cost, params.event, params.title, params.sure, params.cancel, params.msg, 
                                params.newReviveUI)
end

function Actions.ShowKillerInfo(data, params, context)
	local player = params.player
	assert(player.isPlayer)
	local killer = assert(params.killer, "need killer")
	player:sendKillerInfo(killer, params.weapon, params.cost, params.event, params.timeout)	
end

function Actions.HideKillerInfo(data, params, context)
	params.player:sendPacket({pid = "HideKillerInfo"})
end

function Actions.ShowDialogTip(data, params, context)
    local arg = {}
    local num = 1
    while params["p" .. num] ~= nil do
        table.insert(arg, params["p" .. num])
        num = num + 1
    end
    params.entity:showDialogTip(params.tipType, params.event, arg, params.context)
end

function Actions.ShowHome(data, params, context)
    local target = params.target or params.entity
    local eventMap = {}
    for i, v in pairs(params.content or {}) do
        eventMap[v.event] = v.event
    end
    for i, v in pairs(params.buttons or {}) do
        eventMap[v.event] = v.event
    end
    local modName = "HomeCallBack"
    local regId = params.entity:regCallBack(modName, eventMap, false, true)
    local _params = {
        targetUid = target.platformUserId,
        playerInfo = target and target:viewEntityInfo(params.playerInfo) or {},
        homeInfo = target and target:viewEntityInfo(params.homeInfo) or {},
        buttons = params.buttons or {},
        content = params.content or {},
        homeDesc = params.homeDesc,
        titleName = params.titleName,
        regId = regId,
        modName = modName
    }
    params.entity:sendPacket({
        pid = "ShowHome",
        show = params.show == nil and true or params.show,
        params = _params
    })
end

local function regEventMap(tb, eventMap)
    if not tb then
        return
    end
    for i,v in pairs(tb) do
        if type(v) == "table" then
            regEventMap(v, eventMap)
        elseif i == "event" then
            eventMap[#eventMap + 1] = v
            tb["eventKey"] = #eventMap
            tb[i] = nil
        end
    end
end

local function getRandomRegUI(regUIStr)
    return (regUIStr or "") .. os.time() .. World.CurWorld:getTickCount() .. math.random(999999)
end

-- 注：必须把 事件key写成 "event"，context也必须在同一层
function Actions.ShowGenericListDisplayBox(data, params, context)
    local entity = params.entity
    if not entity then
        return
    end
    local infoTb = params.infoTb
    if not params.closeWin then
        local eventMap = {}
        regEventMap(infoTb or {}, eventMap)
        local regUI = getRandomRegUI("GenericListDisplayBox")
        local regId = params.entity:regRemoteCallback(regUI, eventMap, false, true)
        infoTb.regId = regId
        infoTb.regUI = regUI
        if params.isOpenChild and infoTb.childInfoTb then
            infoTb.childInfoTb.regId = regId
            infoTb.childInfoTb.regUI = regUI
        end
    end
    entity:sendPacket({
        pid = "ShowGenericListDisplayBox",
        infoTb = infoTb,
        closeWin = params.closeWin,
        isOpenChild = params.isOpenChild
    })
end

function Actions.ShowGenericActorShowStore(data, params, context)
    local entity = params.entity
    if not entity then
        return
    end
    local infoTb = params.infoTb
    if not params.closeWin then
        local eventMap = {}
        regEventMap(infoTb or {}, eventMap)
        local regId = params.entity:regCallBack("GenericActorShowStore", eventMap, false, true)
        infoTb.regId = regId
        infoTb.regUI = "GenericActorShowStore"
    end
    entity:sendPacket({
        pid = "ShowGenericActorShowStore",
        infoTb = infoTb,
        closeWin = params.closeWin,
        updateWin = params.updateWin
    })
end

function Actions.ShowTitleBarPage(data, params, context)
    local entity = params.entity
    if not entity then
        return
    end
    local infoTb = params.infoTb
    if not params.closeWin then
        local eventMap = {}
        regEventMap(infoTb or {}, eventMap)
        local regId = params.entity:regCallBack("TitleBarPage", eventMap, false, true)
        infoTb.regId = regId
        infoTb.regUI = "TitleBarPage"
    end
    entity:sendPacket({
        pid = "ShowTitleBarPage",
        infoTb = params.infoTb,
        closeWin = params.closeWin,
        updateWin = params.updateWin
    })
end

function Actions.ShowBackpackDisplay(data, params, context)
    local player = params.player
    if not player then
        return
    end
    local regId
    if params.event then
        regId = player:regCallBack("backpackDisplay", {[params.key] = params.event}, false, true)
    end
    player:sendPacket({
        pid = "ShowBackpackDisplay",
        key = params.key,
        title = params.title,
        regId = regId,
        relativeSize = params.relativeSize,
    })
end

function Actions.UpdateEntityEditContainer(data, params, context)
    local player = params.player
    local entityId = params.entityId
    if not entityId or not player then
        return
    end
    player:sendPacket({
        pid = "UpdateEntityEditContainer",
        objID = entityId,
        show = params.show
    })
end

local function getSingletonKey(subKey)
    return "singleton-" .. assert(subKey)
end

function Actions.AddSceneUI(data, params, context)
    local data = params.data or params
    local key = data.key or getSingletonKey(data.name)
    SceneUIManager.AddSceneUI(params.map, key, data.name, data.width, data.height, data.rotate, data.position, data.args)
end

function Actions.RemoveSceneUI(data, params, context)
    local data = params.data or params
    local key = data.key or getSingletonKey(data.name)
    SceneUIManager.RemoveSceneUI(params.map, key)
end

function Actions.RefreshSceneUI(data, params, context)
    local data = params.data or params
    local key = data.key or getSingletonKey(data.name)
    SceneUIManager.RefreshSceneUI(params.map, key, data.args)
end

function Actions.AddEntitySceneUI(data, params, context)
    local data = params.data or params
    local key = data.key or getSingletonKey(data.name)
    SceneUIManager.AddEntitySceneUI(params.entity.objID, key, data.name, data.width, data.height, data.rotate, data.position, data.args)
end

function Actions.RemoveEntitySceneUI(data, params, context)
    local data = params.data or params
    local key = data.key or getSingletonKey(data.name)
    SceneUIManager.RemoveEntitySceneUI(params.entity.objID, key)
end

function Actions.RefreshEntitySceneUI(data, params, context)
    local data = params.data or params
    local key = data.key or getSingletonKey(data.name)
    SceneUIManager.RefreshEntitySceneUI(params.entity.objID, key, data.args)
end

function Actions.AddEntityHeadUI(data, params, context)
    local data = params.data or params
    SceneUIManager.AddEntityHeadUI(params.entity.objID, data.name, data.width, data.height, data.args)
end

function Actions.RemoveEntityHeadUI(data, params, context)
    SceneUIManager.RemoveEntityHeadUI(params.entity.objID)
end

function Actions.RefreshEntityHeadUI(data, params, context)
    local data = params.data or params
    SceneUIManager.RefreshEntityHeadUI(params.entity.objID, data.args)
end

function Actions.ShowTreasureBox(data, params, context)
	params.player:UpdataTreasureBox(params.boxName, params.updata, nil)
end

function Actions.ResreshTreasureBoxCd(data, params, context)
	params.player:sendPacket({pid = "ResreshTreasureBoxCd"})
end

function Actions.ShowGeneralOptions(data, params, context)
    local eventMap = {}
    for k, v in pairs(params.options or {}) do
        eventMap[v.event] = v.event
    end
    local callBackModName = "GeneralOptionsCallBack"
    local regId = params.entity:regCallBack(callBackModName, eventMap, false, true, params.context)
    params.entity:sendPacket({
        pid = "ShowGeneralOptions",
        regId = regId,
        title = params.title,
        leftSideWidth = params.leftSideWidth,
	    options = params.options,
        selectedIndex = params.selectedIndex,
        pageSize = params.pageSize,
        callBackModName = callBackModName,
        close = params.close
    })
end

function Actions.ShowGeneralOptionDerive(data, params, context)
    local eventMap = {}
    for _, v in pairs(params.options) do
        eventMap[v.event] = v.event
    end
    local callBackModName = "GeneralOptionDerive"
    local entity = params.entity
    local regId = entity:regCallBack(callBackModName, eventMap, false, true)
    entity:sendPacket({
        pid = "ShowGeneralOptionDerive",
        show = params.show,
        regId = regId,
        title = params.title,
        leftSideWidth = params.leftSideWidth,
        options = params.options,
        callBackModName = callBackModName,
    })
end

function Actions.UpdateGeneralOptionDeriveRight(data, params, context)
    params.entity:sendPacket({
        pid = "UpdateGeneralOptionDeriveRight",
        frame = params.frame,
        params = params.params
    })
end

function Actions.UpdateGeneralOptionsRightSide(data, params, context)
    local events = params.events
    local callBackModName
    local regId
    if events then
        local eventMap = {}
        for _, v in pairs(events) do
            eventMap[v] = v
        end
        callBackModName = "GeneralOptionsRightSideCallBack" .. params.winName
        regId = params.entity:regCallBack(callBackModName, eventMap, false, false, params.context)
    end
    params.entity:sendPacket({
        pid = "UpdateGeneralOptionsRightSide",
        data = params.data,
        regId = regId,
        callBackModName = callBackModName,
        events = events,
        winName = params.winName,
        area = params.area,
        hAlign = params.hAlign,
        vAlign = params.vAlign
    })
end

function Actions.ShowNewShop(data, params, context)
    params.player:sendPacket({
        pid = "ShowNewShop",
        key = params.key,
        show = params.show,
        tab = params.tab,
        index = params.index,
        uiCfg = params.uiCfg
    })
end

function Actions.ShowObjectInteractionUI(data, params, context)
    local player = params.player
    player:sendPacket({pid = "ShowObjectInteractionUI", objID = params.target.objID})
end

function Actions.HideObjectInteractionUI(data, params, context)
    local player = params.player
    player:sendPacket({pid = "HideObjectInteractionUI", objID = params.target.objID})
end

function Actions.HideInteractionWindow(data, params, context)
    local player = params.player
    player:sendPacket({pid = "SwitchInteractionWindow", isShow = false})
end

function Actions.ShowInteractionWindow(data, params, context)
    local player = params.player
    player:sendPacket({pid = "SwitchInteractionWindow", isShow = true})
end

function Actions.RecheckAllInteractionUIs(data, params, context)
    params.player:sendPacket({
        pid = "RecheckAllInteractionUIs",
    })
end

function Actions.RecheckObjectInteractionUI(data, params, context)
    local player = params.player
    player:sendPacket({
        pid = "UpdateObjectInteractionUI",
        objID = params.target.objID,
        show = params.show,
        recheck = true
    })
end

function Actions.UpdateObjectInteractionUI(data, params, context)
    local player = params.player
    player:sendPacket({
        pid = "UpdateObjectInteractionUI",
        objID = params.target.objID,
        cfgKey = params.cfgKey,
        reset = params.reset,
        show = params.show,
    })
end

function Actions.UpdatePartyInnerSettingUI(data, params, context)
    local player = params.player
    local userId = params.inPartyOwnerId
    AsyncProcess.GetPartyInfo(userId, function (inPartyInfo)
        player:sendPacket({
            pid = "UpdatePartyInnerSettingUI",
            inPartyOwnerId = userId,
            isShow = params.isShow,
            partyData = inPartyInfo,
        })
    end)
end

function Actions.ShowPartyList(data, params, context)
    local player = params.player
    local closeEvent = params.closeEvent
    local regId = closeEvent and player:regCallBack("ShowPartyList", {close = closeEvent}, true, true)
    player:sendPacket({
        pid = "ShowPartyList",
        regId = regId,
    })
end

function Actions.NavCollapsibleChange(data, params, context)
    params.player:sendPacket({
        pid = "NavCollapsible",
        type = params.type,
        colBool = params.colBool
    })
end

function Actions.OpenNpcChest(data, params, content)
    local regId
    local player, chest = params.player, params.chest
    if params.closeEvent then
        regId = player:regCallBack("NpcChest", {closeEvent = params.closeEvent}, true, true, {obj1 = player, chest = chest})
    end
    player:sendPacket({
        pid = "OpenNpcChest",
        objID = chest.objID,
        regId = regId,
    })
end

function Actions.ShowStore(data, params, context)
    params.player:sendPacket({ pid = "OpenStore", storeId = params.store.storeId, itemIndex = params.store.itemIndex })
end

function Actions.ShowInputDialog(data, params, content)
    local entity = params.entity
    local contents = params.contents

    if not entity.isPlayer or not contents then
        return
    end

    local eventMap = {}
    for _, v in pairs(contents.buttons or {}) do
        eventMap[v.event] = v.event
    end

    local callBackModName = "InputDialogCallBack"
    local regId = entity:regCallBack(callBackModName, eventMap, false, true, params.options)

    entity:sendPacket({
        pid = "ShowInputDialog",
        regId = regId,
        callBackModName = callBackModName,
        contents = contents,
    })
end

function Actions.ShowEquipUpgradeUI(data, params, context)
    params.player:sendPacket({pid = "ShowEquipUpgradeUI", sortGist = params.sortGist})
end

function Actions.AddMainGain(data, params, context)
    params.player:sendPacket({
        pid = "AddMainGain",
        type = params.type,
        fullName = params.fullName,
        count = params.count or 1,
        offsetY = params.offsetY,
    })
end

function Actions.UpdateSkillJackArea(data, params, content)
    local entity = params.entity
    if not entity.isPlayer then
        return
    end

    entity:sendPacket({
        pid = "UpdateSkillJackArea",
        info = params.info
    })
end

function Actions.AddMainGains(data, params, context)
    params.player:sendPacket({
        pid = "AddMainGains",
        type = params.type,
        fullName = params.fullName,
        count = params.count or 1,
        gains = params.gains or {},
        offsetY = params.offsetY,
    })
end

function Actions.OperationWindows(data, params, content)
    if params.isOpen == nil then
        params.isOpen = true
    end
    params.player:sendPacket({pid = "OperationWindows", winName = params.win, isOpen = params.isOpen, data = params.data or {}})
end

function Actions.ShowRewardItemEffect(data, params, content)
	params.player:sendPacket({
		pid = "ShowRewardItemEffect",
		key = params.fullName or params.image,
		time = params.time,
		count = params.count or 1,
		type = params.type
	})
end

function Actions.ShowSellShop(data, params, context)
    params.player:sendPacket({
        pid = "ShowSellShop",
        show = params.show,
        key = params.key,
        title = params.title,
        uiCfg = params.uiCfg
    })
end

function Actions.ShowEntityHeadCountDown(data, params, context)
	params.player:sendPacket({
		pid = "HeadCountDown",
		objID = params.entity.objID,
		time = params.time
	})
end

function Actions.TakePhotos(data, params, context)
    params.player:sendPacket({pid = "TakePhotos"})
end

function Actions.ShowInviteTip(data, params, context)
    local player = params.player
    local regId = player:regCallBack("ShowInviteTip", params.eventMap, true, true)
    player:sendPacket({
        pid = "ShowInviteTip",
        regId = regId,
        pic = params.pic,
        titleText = params.titleText,
        content = params.content,
        buttonInfo = params.buttonInfo,
        fullName = params.fullName,
        showTime = params.showTime
	})
end

function Actions.ShowLongTextTip(data, params, context)
    params.player:sendPacket({
        pid = "ShowLongTextTip",
        text = params.text,
        title = params.title
	})
end

function Actions.ShowToolBarButton(data, params, context)
	params.player:sendPacket({
		pid = "ShowToolBarBtn",
		name = params.name,
		show = params.show
	})
end

function Actions.ShowGameQuality(data, params, context)
    params.entity:sendPacket({
        pid = "ShowGameQuality",
        show = params.show
    })
end

function Actions.ShowGoldShop(data, params, context)
	params.player:sendPacket({
		pid = "ShowGoldShop",
		show = params.show
	})
end

function Actions.ShowAnimationReward(data, params, context)
	params.player:sendPacket({
        pid = "ShowAnimationReward",
        cfgKey = params.cfgKey,
		key = params.fullName or params.image,
		time = params.time,
		count = params.count or 1,
		type = params.type
	})
end

function Actions.HideOpenedWnd(data, params, context)
    local player = params.player
    local showFuncId = player.objID .. os.time()
	player:sendPacket({
        pid = "HideOpenedWnd",
        excluded = params.excluded,
        showFuncId = showFuncId
    })
    return showFuncId
end

function Actions.ShowOpenedWnd(data, params, context)
    local player = params.player
    local showFuncId = params.showFuncId
    if not showFuncId then
        return
    end
	player:sendPacket({
        pid = "ShowOpenedWnd",
        showFuncId = showFuncId
	})
end

function Actions.ShowRecharge(data, params, context)
	params.player:sendPacket({
		pid = "ShowRecharge"
	})
end

function Actions.ShowSumRecharge(data, params, context)
    params.player:showRecharge(params.show == nil and true or params.show)
end

function Actions.ShowCenterFriend(data, params, context)
    local player = assert(params.player, "no player(ShowCenterFriend)")
    local modName = params.modName or "CenterFriend"
    local regId = player:regCallBack(modName, {key = params.event or "INVITE_FRIEND_CENTER"}, false, true)
    player:sendPacket({
        pid = "ShowCenterFriend",
        modName = modName,
        regId = regId,
        show = params.show == nil or params.show
    })
end

function Actions.ShowSlidingPrompt(data, params, context)
    local player = assert(params.player, "no player(ShowSlidingPrompt)")
    local modName = params.modName or "SlidingPrompt"
    local regId = player:regCallBack(modName, params.eventMap, false, true, params.context)
    player:sendPacket({
        pid = "ShowSlidingPrompt",
        modName = modName,
        regId = regId,
        nameArg = params.nameArg,
        infoArg = params.infoArg,
        descArg = params.descArg,
        lifeSpan = params.lifeSpan,
        fromId = params.fromId,
    })
end

function Actions.ClearSlidingPrompt(data, params, context)
    local player = assert(params.player, "no player(ClearSlidingPrompt)")
    player:sendPacket({
        pid = "ClearSlidingPrompt",
        key = params.key,
        value = params.value
    })
end

function Actions.ShowUpglideTip(data, params, context)
    local player = assert(params.player, "no player(ShowUpglideTip)")
    assert(player.isPlayer, "Not a player")
    player:sendPacket({
        pid = "ShowUpglideTip",
        keepTime = params.keepTime,
        textKey = params.textKey,
        textArgs = {params.textP1, params.textP2, params.textP3}
    })
end

function Actions.ShowChatChannel(data, params, context)
    local player = assert(params.player)
    assert(player.isPlayer)
    player:sendPacket({
        pid = "ShowChatChannel",
        show = params.show,
        channelName = params.channelName,
    })
end