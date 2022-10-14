M.NotDialogWnd = true

local EMPTY = L("EMPTY", {})
local DEFAULT_UI_KEY = "interactionUI"
local DEFAULT_FOLLOW_PARAMS = {
    followScenePos = false,
}
local DEFAULT_ANCHOR = { x = 0.5, y = 0.5 }
local DEFAULT_OFFSET = { x = 0, y = 0, z = 0 }
local bmSetting = Blockman.instance.gameSettings
local lastClickTick = 0

local autoCloseReason = {
    BUTTON_CLICK = "BUTTON_CLICK",
    SCENE_CLICK = "SCENE_CLICK",
    OUT_OF_RANGE = "OUT_OF_RANGE",
}

local function checkCanReset(self, objID, reason)
    local ret = true
    local curCfg = self.interactionUICfgs[objID]
    if not curCfg then
        print("no cfg, please check: ", objID)
        return ret
    end
    if curCfg[1] then
        curCfg = curCfg[1]
    end
    if reason == autoCloseReason.BUTTON_CLICK then
        if curCfg.disableResetByButtonClick then
            ret = false
        end
    elseif reason == autoCloseReason.SCENE_CLICK then
        -- have maintained in self.closeBySceneClick
    elseif reason == autoCloseReason.OUT_OF_RANGE then
        if curCfg.disableResetByOutOfRange then
            ret = false
        end
    end
    return ret
end

local function autoCloseWnd(self, objID, reason)
    if objID == 0 then
        return
    end
    local canReset = checkCanReset(self, objID, reason)
    self:hideInteractionUI(objID)
    local ranges = Me:data("inInteractionRanges")
    local show = ranges[objID]
    Me:updateObjectInteractionUI({objID = objID, reset = canReset, show = show})
end

local function updateUILevel(self, objIDs)
    local level = 100
    for _, objID in ipairs(objIDs) do
        local wnds = self.container[objID] or {}
        for _, wnd in ipairs(wnds) do
            wnd:SetLevel(level)
            level = level + 1
        end
    end
end

local function updateButtonTextCanShow(self, objIDs)
    local function enableText(wnds, enable)
        for _, wnd in pairs(wnds) do
            local count = wnd:GetChildCount()
            for i = 0, count - 1 do
                wnd:GetChildByIndex(i):invoke("showText", enable)
            end
        end
    end

    local function getFirstCanShowIndex(fromIndex)
        if not fromIndex then
            fromIndex = 1
        end
        for i = fromIndex, #objIDs do
            if Me:canShowObjectInteractionUI(objIDs[i]) then
                return objIDs[i], i
            end
        end
    end

    local canShowIDs = {}
    local firstID, firstIndex = getFirstCanShowIndex()
    if firstID then
        canShowIDs[firstID] = true
        if Me.rideOnId  ~= 0 then
            local nextID = getFirstCanShowIndex(firstIndex + 1)
            if nextID then
                canShowIDs[nextID] = true
            end
        end
    end

    for _, objID in ipairs(objIDs) do
        local wnds = self.container[objID] or {}
        enableText(wnds, canShowIDs[objID])
    end
end

local function subscribeEvents(self)
    Lib.lightSubscribeEvent("error!!!!! : win_interactionContainer lib event : EVENT_ENTITY_RIDE_ON", Event.EVENT_ENTITY_RIDE_ON, function(objID, rideOnId, rideOnIdx)
        World.Timer(1, Me.recheckAllInteractionUIs, Me)
    end)

    Lib.lightSubscribeEvent("error!!!!! : win_interactionContainer lib event : EVENT_ENTITY_RIDE_OFF", Event.EVENT_ENTITY_RIDE_OFF, function(objID, rideOnId, rideOnIdx)
        World.Timer(1, Me.recheckAllInteractionUIs, Me)
    end)

    Lib.lightSubscribeEvent("error!!!!! : win_interactionContainer lib event : EVENT_SWITCH_INTERACTION_WND", Event.EVENT_SWITCH_INTERACTION_WND, function(isShow)
        self._root:SetVisible(isShow)
    end)
    Lib.lightSubscribeEvent("error!!!!! : win_interactionContainer lib event : EVENT_OBJECT_INTERACTION_SORT_DISTANCE", Event.EVENT_OBJECT_INTERACTION_SORT_DISTANCE, function(objIDs)
        updateUILevel(self, objIDs)
        updateButtonTextCanShow(self, objIDs)
    end)
    Lib.lightSubscribeEvent("error!!!!! : win_interactionContainer lib event : EVENT_OBJECT_INTERACTION_SWITCH", Event.EVENT_OBJECT_INTERACTION_SWITCH, function(objID, show)
        interaction_event("onInteractionSwitch", objID, show)
        self:hideInteractionUI(objID)
        if show then
            local curCfg = self.interactionUICfgs[objID]
            if not curCfg then
                Me:updateObjectInteractionUI({objID = objID, show = true, reset = true})
                return
            end
            self:showInteractionUI(objID, curCfg)
        end
    end)
    Lib.lightSubscribeEvent("error!!!!! : win_interactionContainer lib event : EVENT_OBJECT_INTERACTION_SET", Event.EVENT_OBJECT_INTERACTION_SET, function(objID, show, curCfg)
        self:hideInteractionUI(objID)
        self.interactionUICfgs[objID] = curCfg
        if show then
             self:showInteractionUI(objID, curCfg)
        end
    end)
    local function sceneClickCloseUI()
        local list = self.closeBySceneClick
        if next(list) then
            for objID in pairs(list) do
                autoCloseWnd(self, objID, autoCloseReason.SCENE_CLICK)
            end
            list = EMPTY
        end
    end
    Lib.lightSubscribeEvent("error!!!!! : win_interactionContainer lib event : EVENT_SCENE_TOUCH_BEGIN", Event.EVENT_SCENE_TOUCH_BEGIN, function ()
        if not next(Me:data("inInteractionRanges")) then
            return
        end
        if self.answerSceneClick then
            return
        end
        self.answerSceneClick = World.Timer(3, function ()
            self.answerSceneClick = nil
            if bmSetting:isMouseMoving() then
                return
            end
            sceneClickCloseUI()
        end)
    end)
    Lib.lightSubscribeEvent("error!!!!! : win_interactionContainer lib event : EVENT_OBJECT_INTERACTION_CHECKIN", Event.EVENT_OBJECT_INTERACTION_CHECKIN, function (objID, isEnter)
        if objID == Me.objID then
            return
        end
        local curCfg = self.interactionUICfgs[objID]
        if not curCfg then
            Me:updateObjectInteractionUI({objID = objID, reset = true})
            curCfg = self.interactionUICfgs[objID]
        end
        if not curCfg then
            -- cases:
            --1. it can not be interaceted now
            --2. it has no interaction cfg
            return
        end
        local followParams = curCfg.followParams or DEFAULT_FOLLOW_PARAMS
        local followScenePos = (not curCfg[1]) and followParams.followScenePos or false
        if isEnter then
            local context = { btnCfg = curCfg, isShowUI = true }
            interaction_event("onEnterEntityRange", objID, context)
            if context.isShowUI then
                Me:updateObjectInteractionUI({objID = objID, show = true})
            end
        elseif not followScenePos then
            local context = { btnCfg = curCfg, isHideUI = true }
            interaction_event("onQuitEntityRange", objID, context)
            if context.isHideUI then
                Me:updateObjectInteractionUI({objID = objID, show = false, reset = followParams.resetWhenHide})
            end
        end
    end)
end

function M:init()
    WinBase.init(self, "InteractionContainer.json", true)
    self.container = {}
    self.containerCloser = {}
    self.interactionUICfgs = {}
    self.closeBySceneClick = {}
    self.showRanges = {}
    self.lastObjID = 0
    subscribeEvents(self)
end

function M:onOpen()
end

function M:onClose()
end

local batchFuncKey = {
    "background",
    "imageSize",
    "textSize",
    "textFontSize",
    "backgroundStretchType",
    "backgroundStretchOffset",
    "imageStretchType",
    "imageStretchOffset",
    "enableTextBorder",
    "disableAutoHideText",
    "image",
    "text",
}

local batchParamsKey = {
    "widgetFileName",
    "hideOnClick",
}

local function newButton(objID, btn, layoutParams, pos)
    local context = {
        btnCfg = btn,
    }
    interaction_event("NewButton", objID, context)
    btn = context.btnCfg

    for _, key in ipairs(batchParamsKey) do
        if btn[key] == nil then
            btn[key] = layoutParams[key]
        end
    end

    local item = UIMgr:new_widget("button", btn.widgetFileName)

    for _, key in ipairs(batchFuncKey) do
        if btn[key] ~= nil then
            item:invoke(key, btn[key])
        else
            item:invoke(key, layoutParams[key])
        end
    end

    item:invoke("pos", pos)
    item:invoke("showText", false)

    context.button = item
    interaction_event("onAddButtonEnd", objID, context)
    return item
end

local function setButtonAction(self, item, btnCfg, objID, btnIndex, cfgKey, btnType, cfgIndex)
    local context = {--can be changed by custom scripts
        callback = nil,
        innerCallbacks = {},
        btnCfg = btnCfg,
    }

    interaction_event("ButtonSetClickAction", objID, context)

    btnCfg = context.btnCfg
    if btnCfg.disable then
        item:SetEnabledRecursivly(false)
        return
    end
    self:subscribe(item, UIEvent.EventButtonClick, function()
        autoCloseWnd(self, self.lastObjID, autoCloseReason.BUTTON_CLICK)
        self.lastObjID = objID
    end)
    local callback = context.callback
    if not callback and btnCfg.event then
        callback = function ()
            Me:interactWithObject(objID, cfgKey, cfgIndex, btnType, btnIndex)
        end
    end
    local allCallbacks = context.innerCallbacks
    allCallbacks[#allCallbacks + 1] = callback
    self:subscribe(item, UIEvent.EventButtonClick, function()
        --todo 交互冷却时间
        if World.cfg.interaction and World.cfg.interaction.calmDownTick and World.Now() - lastClickTick < World.cfg.interaction.calmDownTick then
            return
        end
        lastClickTick = World.Now()
        for _, func in pairs(allCallbacks) do
            func()
        end
    end)
end

local function checkCanDisplay(self, btnCfgs, objID)
    local count = #btnCfgs
    for index, btn in ipairs(btnCfgs) do
        local context = {
            btnCfg = btn,
            canHide = false,
        }

        interaction_event("ButtonDisplay", objID, context)

        btn = context.btnCfg
        local canHide = context.canHide
        btn.hide = canHide
        if canHide then
            count = count - 1
        end
    end
    return count
end

function M:displayAroundButtons(container, objID, cfgKey, btnCfgs, params, cfgIndex)
    local count = checkCanDisplay(self, btnCfgs, objID)
    if count == 0 then
        return
    end
    local posCfgs = count == 1 and {} or UILib.autoLayoutCircle({
        count = count,
        radius = params.radius or 100,
        startAngle = params.startAngle,
        endAngle = params.endAngle,
        deltaAngle = params.deltaAngle,
    })
    local posIndex = 0
    for index, btn in ipairs(btnCfgs) do
        if btn.hide then
            goto continue
        end
        posIndex = posIndex + 1
        local item = newButton(objID, btn, params or {}, posCfgs[posIndex])
        setButtonAction(self, item, btn, objID, index, cfgKey, "aroundBtns", cfgIndex)
        container:AddChildWindow(item)
        ::continue::
    end
end

function M:displayCenterButtons(container, objID, cfgKey, btnCfgs, params, cfgIndex)
    local count = checkCanDisplay(self, btnCfgs, objID)
    if count == 0 then
        return
    end
    for index, btn in ipairs(btnCfgs) do
        if not btn.hide then-- can only display one button
            local btn = btnCfgs[index]
            local item = newButton(objID, btn, params or {}, nil)
            setButtonAction(self, item, btn, objID, index, cfgKey, "centerBtns", cfgIndex)
            container:AddChildWindow(item)
            return
        end
    end
end

function M:setContainerFollow(wnd, objID, params, isGroup)
    if isGroup then
        params.followScenePos = false
    end
    local object = World.CurWorld:getObject(objID)
    local val = object:data("interactionUiOffset")
    local offset = params.offset or (next(val) and val) or DEFAULT_OFFSET
    local followParams = {
        anchor = DEFAULT_ANCHOR,
        offset = offset,
    }
    local result
    if not params.followScenePos then
        result = UILib.uiFollowObject(wnd, objID, followParams)
    else
        local pos = object:getPosition() + Lib.posAroundYaw(offset, object:getRotationYaw())
        result = UILib.uiFollowPos(wnd, pos, followParams)
    end
    return result
end

local function pushShowRanges(self, objID)
    self.showRanges[objID] = true
    if self.checkShowRangeTimer then
        return
    end
    self.checkShowRangeTimer = World.Timer(1, function ()
        for objID in pairs(self.showRanges) do
            local object = World.CurWorld:getObject(objID)
            if not object then
                self:hideInteractionUI(objID)
                self.interactionUICfgs[objID] = nil
                self.closeBySceneClick[objID] = nil
            else
                local interaction = assert(object:cfg().interaction, object:cfg().fullName)
                local followParams = self.interactionUICfgs[objID].followParams or DEFAULT_FOLLOW_PARAMS
                local showRange = math.max(interaction.radius, followParams.showRange or 0)
                local offset = interaction.offset or DEFAULT_OFFSET
                local disSqr = Lib.getPosDistanceSqr(Me:getPosition(), object:getPosition() + Lib.posAroundYaw(offset, object:getRotationYaw()))
                if disSqr > showRange * showRange then
                    autoCloseWnd(self, objID, autoCloseReason.OUT_OF_RANGE)
                end
            end
        end
        return true
    end)
end

local function popShowRanges(self, objID)
    local showRanges, checkShowRangeTimer = self.showRanges, self.checkShowRangeTimer
    showRanges[objID] = nil
    self.closeBySceneClick[objID] = nil
    if not next(showRanges) and checkShowRangeTimer then
        checkShowRangeTimer()
        self.checkShowRangeTimer = nil
    end
end

function M:showSingleUI(objID, cfg, cfgIndex)
    local container = GUIWindowManager.instance:LoadWindowFromJSON("InteractionLayout.json")
    self._root:AddChildWindow(container)
    local containerCloser = self.containerCloser[objID]
    if not containerCloser then
        containerCloser = {}
        self.containerCloser[objID] = containerCloser
    end
    local context = {
        cfg = cfg,
    }

    interaction_event("ShowSingleUI", objID, context)

    cfg = context.cfg
    local followParams = cfg.followParams or DEFAULT_FOLLOW_PARAMS
    if followParams.followScenePos then
        pushShowRanges(self, objID)
    end
    containerCloser[#containerCloser + 1] = self:setContainerFollow(container, objID, followParams, cfgIndex)
    local canResetBySceneClick = cfg.cfgKey ~= DEFAULT_UI_KEY
    if cfg.disableResetBySceneClick then
        canResetBySceneClick = false
    end
    if canResetBySceneClick then
        self.closeBySceneClick[objID] = true
    end
    local centerBtns, aroundBtns, cfgKey = cfg.centerBtns, cfg.aroundBtns, cfg.cfgKey
    if centerBtns then
        self:displayCenterButtons(container, objID, cfgKey, centerBtns, cfg.centerParams, cfgIndex)
    elseif aroundBtns then
        self:displayAroundButtons(container, objID, cfgKey, aroundBtns, cfg.aroundParams, cfgIndex)
    end
    container:SetVisible(true)
    local containers = self.container[objID]
    if not containers then
        containers = {}
        self.container[objID] = containers
    end
    containers[#containers + 1] = container
end

function M:showInteractionUI(objID, cfg)
    local context = { btnCfg = cfg }
    interaction_event("showInteractionUI", objID, context)
    assert(cfg, objID .. " has no interaction cfg!")
    if cfg[1] then
        for index, singleCfg in ipairs(cfg) do
            self:showSingleUI(objID, singleCfg, index)
        end
    else
        self:showSingleUI(objID, cfg)
    end
end

function M:hideInteractionUI(objID)
    local btnCfg = self.interactionUICfgs[objID]
    if btnCfg then
        local context = { btnCfg = btnCfg }
        interaction_event("hideInteractionUI", objID, context)
    end
    popShowRanges(self, objID)
    local closers = self.containerCloser[objID] or {}
    for _, closer in ipairs(closers) do
        closer()
    end
    self.containerCloser[objID] = nil
    local wnds = self.container[objID] or {}
    for _, wnd in ipairs(wnds) do
        GUIWindowManager.instance:DestroyGUIWindow(wnd)
    end
    self.container[objID] = nil
end