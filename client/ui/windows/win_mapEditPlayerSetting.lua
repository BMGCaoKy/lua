local globalSetting = require "editor.setting.global_setting"
local entitySetting = require "editor.setting.entity_setting"
local InfinityLang = Lang:toText("win.map.global.setting.game.Infinity")
local qualityData = {}
local reviveData = {}
local qualityDataKey = {
    maxHp = "maxHp",
    moveSpeed = "moveSpeed",
    jumpSpeed = "jumpSpeed",
    oriDamage = "oriDamage",
    canAttackObject = "canAttackObject",
    enableTwiceJump = "enableTwiceJump",
    hideItemBar = "hideItemBar",
    viewMode = "viewMode",
    ignorePlayerSkin = "ignorePlayerSkin",
    actorName = "actorName",
    allowFly = "allowFly",
    dropDamageEnable = "dropDamageEnable",
    maxVp = "maxVp",
    ignoreVpConsume = "ignoreVpConsume",
    undamageable = "undamageable",
    enableDamageProtection = "enableDamageProtection",
    damageProtectionTime = "damageProtectionTime",
    canSprint = "canSprint",
    canSquat = "canSquat"
}
local qualityDataSliderKey = { 
    qualityDataKey.maxHp,
    qualityDataKey.oriDamage,
    qualityDataKey.moveSpeed,
    qualityDataKey.jumpSpeed,
    qualityDataKey.maxVp
}
local qualityDataSwitchKey = {
    qualityDataKey.canSprint,
    qualityDataKey.enableTwiceJump,
    qualityDataKey.allowFly,
    qualityDataKey.canSquat,
    qualityDataKey.ignoreVpConsume, 
    qualityDataKey.undamageable,
    qualityDataKey.hideItemBar,
    qualityDataKey.dropDamageEnable,
    qualityDataKey.enableDamageProtection,
}
local itemIndexSliderStart = 1
local itemIndexSliderEnd   = #qualityDataSliderKey
local itemIndexSwitchStart = itemIndexSliderEnd + 1
local itemIndexSwitchEnd   = itemIndexSliderEnd + #qualityDataSwitchKey

local function refreshQualityData()
    qualityData = {}
    qualityData[qualityDataKey.maxHp] = entitySetting:getMaxHp("player1")
    qualityData[qualityDataKey.moveSpeed] = entitySetting:getMoveSpeed("player1")
    qualityData[qualityDataKey.jumpSpeed] = entitySetting:getJumpSpeed("player1")
    qualityData[qualityDataKey.oriDamage] = entitySetting:getOriDamage("player1")
    qualityData[qualityDataKey.canAttackObject] = entitySetting:getCanAttackObject("player1")
    qualityData[qualityDataKey.enableTwiceJump] = globalSetting:getEnableTwiceJump()
    qualityData[qualityDataKey.hideItemBar] = not globalSetting:getHideItemBar()
    qualityData[qualityDataKey.viewMode] = globalSetting:getViewMode()
    qualityData[qualityDataKey.ignorePlayerSkin] = entitySetting:getCfgByKey("player1", qualityDataKey.ignorePlayerSkin)
    qualityData[qualityDataKey.actorName] = entitySetting:getCfgByKey("player1", qualityDataKey.actorName)
    qualityData[qualityDataKey.allowFly] = entitySetting:getCfgByKey("player1", qualityDataKey.allowFly)
    qualityData[qualityDataKey.dropDamageEnable] = entitySetting:getCfgByKey("player1", qualityDataKey.dropDamageEnable)
    qualityData[qualityDataKey.maxVp] = entitySetting:getCfgByKey("player1", qualityDataKey.maxVp)
    qualityData[qualityDataKey.ignoreVpConsume] = entitySetting:getCfgByKey("player1", qualityDataKey.ignoreVpConsume)
    qualityData[qualityDataKey.undamageable] = entitySetting:getCfgByKey("player1", qualityDataKey.undamageable)
    qualityData[qualityDataKey.enableDamageProtection] = entitySetting:getCfgByKey("player1", qualityDataKey.enableDamageProtection)
    qualityData[qualityDataKey.damageProtectionTime] = entitySetting:getCfgByKey("player1", qualityDataKey.damageProtectionTime)
    qualityData[qualityDataKey.canSprint] = entitySetting:getCfgByKey("player1", qualityDataKey.canSprint)
    qualityData[qualityDataKey.canSquat] = entitySetting:getCfgByKey("player1", qualityDataKey.canSquat)
end

local function refreshReviveData()
    reviveData = globalSetting:getRebirth() or {}
end

local function setTopView(self)
    local topViewData = {
        {
            uiType = "createSlider",
            index = 5029,
            name = "distance",
            value = qualityData[qualityDataKey.viewMode].distance
        },
        {
            uiType = "createSlider",
            index = 5030,
            name = "defaultPitch",
            value = qualityData[qualityDataKey.viewMode].defaultPitch
        },
        {
            uiType = "createSwitch",
            index = 5028,
            name = "lockSlideScreen",
            value = qualityData[qualityDataKey.viewMode].lockSlideScreen
        },
    }
    for index, data in pairs(topViewData) do
        local heightOffset = (index - 1) * 70
        local wnd = UILib[data.uiType]({
            value = data.value,
            index = data.index
        }, function(value)
            self.topViewCfg[data.name] = value
        end)
        wnd:SetYPosition({0, heightOffset})
        self.TopViewLayout:AddChildWindow(wnd)
    end
end

function M:playerViewSwitch(selectIndex)
    if not self.viewSwitch then
        return
    end
    for index, data in pairs(self.viewSwitch) do
        local isSelect = (selectIndex == index)
        data.switch:SetCheckedNoEvent(isSelect)
        data.text:SetTextColor(isSelect and {99/255, 100/255, 106/255, 1} or {174/255, 184/255, 183/255, 1})
    end

    local function setLayoutOffset(offsetY)
        self.playerWnd:SetHeight({0, 560 + offsetY})
        self.playerResourcesLayout:SetYPosition({0, 280 + offsetY})
        self.playerModelLayout:SetYPosition({0, 400 + offsetY})
    end

    local isShowTopView = selectIndex == 3
    self.TopViewLayout:SetVisible(isShowTopView)
    setLayoutOffset(isShowTopView and 180 or 0)
end

function M:refreshQuality()
    for _, data in pairs(self.switchAndSliderTB) do
        if data.type == "slider" then
            local sliderWnd = self.m_playerGrid:GetItem(data.offsetIndex - 1)
            local key = qualityDataSliderKey[data.index]
            sliderWnd:invoke("setUIValue", qualityData[key])
        elseif data.type == "switch" then
            local onOffWnd = self.m_playerGrid:GetItem(data.offsetIndex - 1):child("Offon-CheckBox")
            local check = qualityData[qualityDataSwitchKey[data.index]] or false
            if qualityDataSwitchKey[data.index] == qualityDataKey.ignoreVpConsume then
                check = ( check == false or check == 0 ) and true or false
            elseif qualityDataSwitchKey[data.index] == qualityDataKey.undamageable then
                check = check == 1 and true or false
            elseif qualityDataSwitchKey[data.index] == qualityDataKey.enableDamageProtection then
                check = check == 1 and true or false
            end
            onOffWnd:SetCheckedNoEvent(check)
        end
    end
    if self.preSliderWnd and self.showDamageProtectionTime then
        local key = qualityDataKey.damageProtectionTime
        self.preSliderWnd:invoke("setUIValue", qualityData[key] and qualityData[key] / 20 )
    end

     if self.playerWnd then
        self:playerViewSwitch(qualityData[qualityDataKey.viewMode].selectViewBtn)

        local refreshWnd = self.playerWnd:child("Player-Model-Refresh")
        local actorIcon = self.playerWnd:child("Player-Model-Refresh-Actor")
        if qualityData[qualityDataKey.actorName] then
            refreshWnd:SetVisible(true)
            local actorsIconData = globalSetting:actorsIconData(qualityData[qualityDataKey.actorName])
            actorIcon:SetImage(actorsIconData.icon)
            actorIcon:SetWidth({0, (actorsIconData.width * 0.8) or 50})
            actorIcon:SetHeight({0, (actorsIconData.height * 0.8) or 80})
            -- "editor_boy.actor"为玩家自带模型
            qualityData[qualityDataKey.ignorePlayerSkin] = qualityData[qualityDataKey.actorName] ~= "editor_boy.actor"
        else
            refreshWnd:SetVisible(false)
        end
    end
end

function M:getReviveInfo()
    return reviveData
end

function M:refreshRevive()
    local wnd = self.m_reviveWnd
    local check1 = wnd:child("Revive-Layout-Check1")
    local check2 = wnd:child("Revive-Layout-Check2")
    local noRebrith = reviveData.times == 0
    for _, wnd in ipairs(self.reviveSliders) do
        wnd:SetEnabledRecursivly(not noRebrith)
    end
    check1:SetChecked(not noRebrith)
    check2:SetChecked(noRebrith)
    local sliderTimes = reviveData.times
    local slider = self.reviveSliders[1]
    if sliderTimes == -1 then
        sliderTimes = 1
        slider:invoke("setProgressUI", 1)
        slider:child("Slider-Edit"):SetText("--")
        slider:child("Slider-unit"):SetText(InfinityLang)
    else
        slider:invoke("setUIValue", sliderTimes)
        self.reviveSliders[2]:invoke("setUIValue", reviveData.time / 20)
    end
    local mod = globalSetting:getValByKey("resourcesMod") or "unlimited"
    wnd:child("Revive-Drop-Content"):SetEnabledRecursivly(mod ~= "unlimited")
    wnd:child("Revive-Drop-Mask"):SetVisible(mod == "unlimited")
end

local sliderIndexs = {12, 15, 13, 14, 25}
local switchIndexs = {5022, 18, 5000, 5023, 26, 5010, 20, 5001, 5011}

local function getSliderIndexs(slidersIndex)
    for k, v in pairs(sliderIndexs) do
        if v == slidersIndex then
            return k
        end
    end
    return
end

local function getSwitchIndexs(switchIndex)
    for k, v in pairs(switchIndexs) do
        if v == switchIndex then
            return k
        end
    end
    return
end

local function createSliderItem(self, slidersIndex, offset, isMore)
    local index = getSliderIndexs(slidersIndex)
    if not index then
        return
    end
    offset = offset or 0
    local sliderWnd = UILib.createSlider({
        value = qualityData[qualityDataSliderKey[index]], 
        index = slidersIndex
    }, function(value)
        local saveKey =  qualityDataSliderKey[index]
        qualityData[qualityDataSliderKey[index]] = value
        entitySetting:saveCfgByKey("player1", saveKey, value, false)
    end)
    sliderWnd:SetHeight({0, 46})
    self.m_playerGrid:AddItem(sliderWnd)
    table.insert(self.switchAndSliderTB, {index = index, offsetIndex = index + offset, type = "slider", isMore = isMore})
    if isMore then
        self.showMoreGridList[#self.showMoreGridList + 1] = sliderWnd
    end
end

local function createSwitchItem(self, switchIndex, offset, isMore)
    local index = getSwitchIndexs(switchIndex)
    if not index then
        return
    end
    offset = offset or 0
    local switchWnd = UILib.createSwitch({
        index = switchIndex,
        value = qualityData[qualityDataSwitchKey[index]]
    }, function(status)
        if qualityDataSwitchKey[index] == qualityDataKey.enableTwiceJump or qualityDataSwitchKey[index] == qualityDataKey.hideItemBar then
            globalSetting:saveKey(qualityDataSwitchKey[index], status)
        else
            if qualityDataSwitchKey[index] == qualityDataKey.ignoreVpConsume then
                status = status and 0 or 1
            elseif qualityDataSwitchKey[index] == qualityDataKey.undamageable then
                status = status and 1 or 0
            elseif qualityDataSwitchKey[index] == qualityDataKey.enableDamageProtection then
                self.showDamageProtectionTime = status
                self:showDamageProtectionSlider(status)
                status = status and 1 or 0
            end
            entitySetting:saveCfgByKey("player1",qualityDataSwitchKey[index] , status)
        end
        qualityData[qualityDataSwitchKey[index]] = status
    end)
    self.m_playerGrid:AddItem(switchWnd)
    table.insert(self.switchAndSliderTB, {index = index, offsetIndex = index + offset, type = "switch", isMore = isMore})
    if isMore then
        self.showMoreGridList[#self.showMoreGridList + 1] = switchWnd
    end
end

function M:initQuality()
    self.m_playerGrid:InitConfig(0, 36, 1)
    self.m_playerGrid:SetAutoColumnCount(false)
    self.m_playerGrid:RemoveAllItems()
    local slidersIndex = {12, 15, 13, 14}
    for _, slidersIndexValue in pairs(slidersIndex) do
        createSliderItem(self, slidersIndexValue)
    end

    local switchIndex = {5022, 18, 5000, 5023}
    for _, switchIndexValue in pairs(switchIndex) do
        createSwitchItem(self, switchIndexValue, 4)
    end
    self:initClickExpansion()
end

function M:initMore()
    self:initRevive()
    self.playerWnd = GUIWindowManager.instance:LoadWindowFromJSON("qualityPlayer_edit.json")
    self.m_playerGrid:AddItem(self.playerWnd)
    self.showMoreGridList[#self.showMoreGridList + 1] = self.playerWnd
    
    createSwitchItem(self, 26, 6, true)
    createSliderItem(self, 25, 7, true)
    local switchIndex = {5010, 20, 5001, 5011}
    for _, switchIndexValue in pairs(switchIndex) do
        createSwitchItem(self, switchIndexValue, 7, true)
    end
    self:initSetResBtn()
    self:initPlayerView()
    self:initPlayerModel()
    self:showDamageProtectionSlider(self.showDamageProtectionTime)
    self:refreshQuality()
end

function M:initSetResBtn()
    local setResBtn = self.playerWnd:child("Player-Resources-Btn")
    self.playerResourcesLayout = self.playerWnd:child("Player-Resources")
    setResBtn:SetText(Lang:toText("block.die.drop.setting"))
    self.playerWnd:child("Player-Resources-Title"):SetText(Lang:toText("win.map.global.setting.player.tab.quality.startRes.setting"))
    self:subscribe(setResBtn, UIEvent.EventButtonClick, function()
        CGame.instance:onEditorDataReport("click_global_setting_player_resource_settings", "")
        UI:openWnd("mapEditBasicEquip", "basic")
    end)
end

function M:initPlayerView()
    self.viewSwitch = {}
    local textStr = {
        "win.map.global.setting.player.tab.quality.Perspective.normal",
        "win.map.global.setting.player.tab.quality.Perspective.fixed.third",
        "win.map.global.setting.player.tab.quality.Perspective.fixed.overheadView",
    }
    self.TopViewLayout = self.playerWnd:child("Player-View-TopViewLayout")
    for i = 1, 3 do
        local text = self.playerWnd:child("Player-View-Text-" .. i)
        local switch = self.playerWnd:child("Player-View-Switch-" .. i)
        local data = {
            text = text,
            switch = switch
        }
        self.viewSwitch[#self.viewSwitch + 1] = data
        text:SetText(Lang:toText(textStr[i]))
        self:subscribe(switch, UIEvent.EventCheckStateChanged, function()
            self:playerViewSwitch(i)
            qualityData[qualityDataKey.viewMode].selectViewBtn = i
        end)
    end
    self.playerWnd:child("Player-View-Title"):SetText(Lang:toText("win.map.global.setting.player.tab.quality.Perspective.title"))

    setTopView(self)
end

function M:initPlayerModel()
    local addBtn = self.playerWnd:child("Player-Model-Add")
    self.playerModelLayout = self.playerWnd:child("Player-Model")
    self.playerWnd:child("Player-Model-Title"):SetWordWrap(true)
    self.playerWnd:child("Player-Model-Title"):setTextAutolinefeed(Lang:toText("win.map.global.setting.player.tab.quality.model.title"))
    self:subscribe(addBtn, UIEvent.EventButtonClick, function()
        UI:openWnd("mapEditModleSetting", {selectedActor = qualityData[qualityDataKey.actorName], backFunc = function(actorName)
            qualityData[qualityDataKey.actorName] = actorName
            self:refreshQuality()
        end})
    end)
end

function M:removeMore()
    self.m_reviveWnd = nil
    self.playerWnd = nil
    self.preSliderWnd = nil
    self.isDamageProtectionSliderShow = false
    for k, wnd in pairs(self.showMoreGridList) do
        self.m_playerGrid:RemoveItem(wnd)
    end
    for k, data in pairs(self.switchAndSliderTB) do
        if data.isMore then
            table.remove(self.switchAndSliderTB, k)
        end
    end
end

function M:initRevive()
    self.m_reviveWnd = GUIWindowManager.instance:LoadWindowFromJSON("reviveLayout_edit.json")
    self.m_playerGrid:AddItem(self.m_reviveWnd)
    self.showMoreGridList[#self.showMoreGridList + 1] = self.m_reviveWnd
    self.m_reviveWnd:child("DieDrop-Title"):SetText(Lang:toText("die_drop_related"))
    
    local check1 = self.m_reviveWnd:child("Revive-Layout-Check1")
    local check2 = self.m_reviveWnd:child("Revive-Layout-Check2")

    local sliderLayout = {}
    self.reviveSliders = sliderLayout

    local times = reviveData.times
    local time = reviveData.time / 20
    if times == -1 then
        times = 1000
    end

    self.m_reviveWnd:child("Revive-Title"):SetText(Lang:toText("win.map.global.setting.player.tab.revive.title"))
    self.m_reviveWnd:child("Revive-Layout-Text1"):SetText(Lang:toText("win.map.global.setting.player.tab.revive.ok"))
    self.m_reviveWnd:child("Revive-Layout-Text2"):SetText(Lang:toText("win.map.global.setting.player.tab.revive.no"))

    local function numFun(value, isInfinity)
        if isInfinity then
            sliderLayout[1]:child("Slider-Edit"):SetText("--")
            sliderLayout[1]:child("Slider-unit"):SetText(InfinityLang)
            reviveData.times = -1
            globalSetting:saveRebirth(reviveData, false)
        else
            sliderLayout[1]:child("Slider-unit"):SetText(Lang:toText("win.map.global.setting.player.tab.revive.timesUnit"))
            reviveData.times = value
            globalSetting:saveRebirth(reviveData, false)
        end
    end

    local function timerFun(value, isInfinity)
        reviveData.time = value * 20
        globalSetting:saveRebirth(reviveData, false)
    end

    local slider = {"reviveNum", "reviveTimer"}
    local sliderIndex = {16, 17}
    local slidFun = {numFun, timerFun}
    local data = {times, time}
    local contentWnd = {self.m_reviveWnd:child("Revive-Revive-Times"), self.m_reviveWnd:child("Revive-Revive-Wait-Time")}
    local function setSliderEnabled(enable)
        for _, wnd in ipairs(sliderLayout) do
            wnd:SetEnabledRecursivly(enable)
        end
    end
    for i, v in ipairs(slider) do
        local sliderWnd = UILib.createSlider({value = data[i], index = sliderIndex[i]}, slidFun[i])
        sliderWnd:SetHeight({0, 44})
        if i == 1 and times == 1000 then
            sliderWnd:child("Slider-Edit"):SetText("--")
            sliderWnd:child("Slider-unit"):SetText(InfinityLang)
        end
        contentWnd[i]:AddChildWindow(sliderWnd)
        sliderLayout[i] = sliderWnd
    end
    local noRebrith = reviveData.times == 0
    setSliderEnabled(not noRebrith)
    check1:SetCheckedNoEvent(not noRebrith)
    check2:SetCheckedNoEvent(noRebrith)
    self:subscribe(check1, UIEvent.EventCheckStateChanged, function()
        check1:SetCheckedNoEvent(true)
        check2:SetCheckedNoEvent(false)
        setSliderEnabled(true)
        local progress = sliderLayout[1]:invoke("getProgressUI")
        reviveData.times = sliderLayout[1]:invoke("progressToValue", progress)
        globalSetting:saveRebirth(reviveData, false)
    end)

    self:subscribe(check2, UIEvent.EventCheckStateChanged, function()
        check2:SetCheckedNoEvent(true)
        check1:SetCheckedNoEvent(false)
        setSliderEnabled(false)
        reviveData.times = 0
        globalSetting:saveRebirth(reviveData, false)
    end)

    local indexs = {5006, 5007, 5008}
    local mods = {"all", "none", "other"}
    local itemDropMod = globalSetting:getValByKey("itemDropMod") or "all"
    for i, idx in ipairs(indexs) do
        local ui = UILib.createSingleChoice({index = idx, value = itemDropMod == mods[i]}, function(selected)
            if selected then
                globalSetting:saveKey("itemDropMod", mods[i])
            end
        end)
        ui:SetYPosition({0, (i - 1) * (50 + 15)})
        self.m_reviveWnd:child("Revive-Drop-Content"):AddChildWindow(ui)
    end
    self:subscribe(self.m_reviveWnd:child("Revive-Drop-Mask"), UIEvent.EventButtonClick, function()
        Lib.emitEvent(Event.EVENT_TOAST_TIP, Lang:toText("unlimited_resources_selected"), 20)
    end)
    self:refreshRevive()
end

function M:initClickExpansion()
    self:initMore()
    -- self.tipWnd = GUIWindowManager.instance:LoadWindowFromJSON("playerSetting_tip.json")
    -- self.m_playerGrid:AddItem(self.tipWnd)
    -- self.tipWnd:child("Setting-Tip-BtnText"):SetText(Lang:toText("win.map.global.setting.player.showMore"))
    -- local m_tipBtn = self.tipWnd:child("Setting-Tip-Btn")
    -- local arrowImg = self.tipWnd:child("Setting-Tip-Img1")
    -- arrowImg:SetRotate(0)
    -- self:subscribe(m_tipBtn, UIEvent.EventButtonClick, function()
    --     self.isShowMore = not self.isShowMore
    --     if self.isShowMore then
    --         self.m_playerGrid:RemoveItem(self.tipWnd)
    --         self:initMore()
    --         self.tipWnd:child("Setting-Tip-BtnText"):SetText(Lang:toText("win.map.global.setting.player.hideMore"))
    --         self.m_playerGrid:AddItem1(self.tipWnd,itemIndexSwitchEnd + 3)
    --         arrowImg:SetRotate(180)
    --     else
    --         self.m_playerGrid:SetScrollOffset(0)
    --         self.m_playerGrid:RemoveItem(self.tipWnd)
    --         self:removeMore()
    --         self.tipWnd:child("Setting-Tip-BtnText"):SetText(Lang:toText("win.map.global.setting.player.showMore"))
    --         self.m_playerGrid:AddItem(self.tipWnd)
    --         arrowImg:SetRotate(0)
    --     end
    -- end)
end

function M:init()
    WinBase.init(self, "playerSetting_edit.json")
    self.showMoreGridList = {}
    self.switchAndSliderTB = {}
    self.topViewCfg = globalSetting:getViewMode()
    self.isShowMore = false
    self:refreshData()
    self.m_layout = self:child("Setting-Layout")
    self.last_selectIdx = 1
    self.m_playerWnd = GUIWindowManager.instance:LoadWindowFromJSON("quality_edit.json")
    self.m_layout:AddChildWindow(self.m_playerWnd)
    self.m_playerGrid = self.m_playerWnd:child("Quality-Grid")
    self:initQuality()
    self:refreshQuality()
end


function M:showDamageProtectionSlider(isShow)
    if isShow and not self.isDamageProtectionSliderShow then
        self.preSliderWnd = UILib.createSlider({value = qualityData[qualityDataKey.damageProtectionTime], index = 27}, function(value)
            local saveKey =  qualityDataKey.damageProtectionTime
            qualityData[qualityDataKey.damageProtectionTime] = value
            entitySetting:saveCfgByKey("player1", saveKey, value , false)
        end)
        self.preSliderWnd:SetHeight({0, 46})
        self.m_playerGrid:AddItem1(self.preSliderWnd,itemIndexSwitchEnd + 2)
        self.isDamageProtectionSliderShow = true
        self.showMoreGridList[#self.showMoreGridList + 1] = self.preSliderWnd
    elseif not isShow and self.isDamageProtectionSliderShow then
        self.m_playerGrid:RemoveItem(self.preSliderWnd)
        self.isDamageProtectionSliderShow = false
        self.showMoreGridList[#self.showMoreGridList] = nil
    end
end

function M:refreshData()
    refreshQualityData()  
    refreshReviveData()
    self.showDamageProtectionTime = qualityData[qualityDataKey.enableDamageProtection] == 1
end

function M:saveData()
    entitySetting:saveMoveSpeed("player1", qualityData[qualityDataKey.moveSpeed])
    entitySetting:setCanAttackObject("player1", qualityData[qualityDataKey.canAttackObject])
    globalSetting:saveEnableTwiceJump(qualityData[qualityDataKey.enableTwiceJump])
    globalSetting:saveHideItemBar(not qualityData[qualityDataKey.hideItemBar])
    globalSetting:saveViewMode(qualityData[qualityDataKey.viewMode].selectViewBtn, self.topViewCfg)
    entitySetting:saveCfgByKey("player1", qualityDataKey.ignorePlayerSkin, qualityData[qualityDataKey.ignorePlayerSkin])
    entitySetting:saveCfgByKey("player1", qualityDataKey.actorName, qualityData[qualityDataKey.actorName])
end

function M:onOpen()  
    self:refreshData()
end

function M:onReload(reloadArg)

end

return M