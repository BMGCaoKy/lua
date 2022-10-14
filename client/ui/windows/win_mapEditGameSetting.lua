local globalSetting = require "editor.setting.global_setting"
local mapSetting = require "editor.map_setting"
local data_state = require "editor.dataState"
local entity_obj = require "editor.entity_obj"

local InfinityLang = Lang:toText("win.map.global.setting.game.Infinity")
local timeUnit = Lang:toText("win.map.global.setting.game.timeUnit")

local timeSlider = {}
local switchItems = {}
local switchCacheData = {}
local gameTimeData = {"playTime", "waitPlayerTime", "minPlayers"}
local initPos = nil

local oneDayTime
local oneDayMod

local offOnUI = {
    {index = 5003, key = "canJoinMidway"},
    {index = 5002, key = "blockCanBreak"}
}


function M:init()
    WinBase.init(self, "gameSettingGrid_edit.json")
    self.gridList = self:child("Setting-Grid")
    self.gridList:InitConfig(0, 36, 1)
    self.gridList:SetAutoColumnCount(false)
    local wnd = GUIWindowManager.instance:LoadWindowFromJSON("gameSetting_edit.json")
    self.gridList:AddItem(wnd)
    self.timeLayout = wnd:child("GameSetting-TimeLayout")
    self.isShowMore = false

    self:initPopWnd()
    self:initSlider(wnd)
    self:initSetPos(wnd)
    self:initSwitchAndRewardWnd()
    self:initClickExpansion()
end

function M:initMore()
    local switchWnd = self:createSwitchItem(offOnUI[2].key, offOnUI[2].index)
    self.showMoreGridList[#self.showMoreGridList + 1] = switchWnd
    self:initDayMode()
end

function M:removeMore()
    for k, wnd in pairs(self.showMoreGridList) do
        self.gridList:RemoveItem(wnd)
    end

    for k, cfg in pairs(offOnUI) do
        if k > 1 then
            switchItems[cfg.key] = nil
        end
    end
end

function M:deleteInitPoint()
    self:switchBtn(true)
    initPos = nil
    entity_obj:delEntityByDeriveType(7, 1)
    globalSetting:saveInitPos(initPos, false)
end

function M:initSetPos(wnd)
    self.settingWnd = wnd:child("GameSetting-SettingPosLayout-SettingPos")
    self.toSettingWnd = wnd:child("GameSetting-SettingPosLayout-AddPos")
    wnd:child("GameSetting-SettingPosLayout-Title"):SetText(Lang:toText("editor.ui.playerWaitingPlace"))

    self:subscribe(self.toSettingWnd, UIEvent.EventButtonClick, function()
        local pos = initPos and {x = initPos.x, y = initPos.y, z = initPos.z, map = initPos.map} or nil
        self:setPosPoint(7, {idx = 1, pos = pos, teamId = 0}, true)
    end)

    self:subscribe(self.settingWnd, UIEvent.EventButtonClick, function()
        self:setPopWndEnabled(true)
    end)


    Lib.subscribeEvent(Event.EVENT_SAVE_POS, function(data, opType, ry)
        if opType == 7 then
            self:switchBtn(false)
            initPos = data.pos
            initPos.map = data_state.now_map_name
            globalSetting:saveInitPos(initPos, false)
        end
    end)

     Lib.subscribeEvent(Event.EVENT_POINT_DEL, function(opType)
        if opType ~= 7 then
            return
        end
        self:deleteInitPoint()
    end)
end

function M:initClickExpansion()
    self.showMoreGridList = {}
    self:initMore()
    -- self.tipWnd = GUIWindowManager.instance:LoadWindowFromJSON("playerSetting_tip.json")
    -- self.gridList:AddItem(self.tipWnd)
    -- self.tipWnd:child("Setting-Tip-BtnText"):SetText(Lang:toText("win.map.global.setting.player.showMore"))
    -- local m_tipBtn = self.tipWnd:child("Setting-Tip-Btn")
    -- local arrowImg = self.tipWnd:child("Setting-Tip-Img1")
    -- arrowImg:SetRotate(0)
    -- self:subscribe(m_tipBtn, UIEvent.EventButtonClick, function()
    --     self.isShowMore = not self.isShowMore
    --     if self.isShowMore then
    --         self.gridList:RemoveItem(self.tipWnd)
    --         self.showMoreGridList = {}
    --         self:initMore()
    --         self:refreshWnd()
    --         self.tipWnd:child("Setting-Tip-BtnText"):SetText(Lang:toText("win.map.global.setting.player.hideMore"))
    --         local gridCount = self.gridList:GetChildByIndex(0):GetChildCount()
    --         self.gridList:AddItem1(self.tipWnd,gridCount)
    --         arrowImg:SetRotate(180)
    --     else
    --         self.gridList:SetScrollOffset(0)
    --         self.gridList:RemoveItem(self.tipWnd)
    --         self:removeMore()
    --         self.tipWnd:child("Setting-Tip-BtnText"):SetText(Lang:toText("win.map.global.setting.player.showMore"))
    --         self.gridList:AddItem(self.tipWnd)
    --         arrowImg:SetRotate(0)
    --     end
    -- end)
end

function M:initSlider(wnd)
    self.timeInfo = { 
        {value = 20,index = 3 , funNum = 1},
        {value = 20, index = 4 , funNum = 2}
    }

    local offsetY = 0
    for _,v in pairs(self.timeInfo) do
        self:createSliderItem(self.timeLayout, v.value, v.index, v.funNum, offsetY)
        offsetY = offsetY + 92
    end

    if gameTimeData.playTime == 10000 then
        timeSlider[2]:child("Slider-Edit"):SetText("--")
        timeSlider[2]:child("Slider-unit"):SetText(InfinityLang)
    end

    self.playerSlider = self:createSliderItem(wnd:child("GameSetting-NumLayout"), gameTimeData.minPlayers, 5, 3)
end

function M:initDayMode()
    self.timeWnd = GUIWindowManager.instance:LoadWindowFromJSON("ruleSetting_edit.json")
    self.gridList:AddItem(self.timeWnd)
    self.showMoreGridList[#self.showMoreGridList + 1] = self.timeWnd
    self:child("RuleSetting-DayMode"):SetText(Lang:toText("rule.setting.day.night"))
    self:child("RuleSetting-Day-Text"):SetText(Lang:toText("rule.setting.day.mode"))
    self:child("RuleSetting-Night-Text"):SetText(Lang:toText("rule.setting.night.mode"))
    self:child("RuleSetting-DayNight-Text"):SetText(Lang:toText("rule.setting.dayAndNight.mode"))

    self.dayMod = self.timeWnd:child("RuleSetting-Day")
    self.nightMod = self.timeWnd:child("RuleSetting-Night")
    self.dayNightMod = self.timeWnd:child("RuleSetting-DayNight")

    self:subscribe(self.dayMod, UIEvent.EventWindowTouchUp, function()
        self:changeDayMod("day")
    end)
    self:subscribe(self.nightMod, UIEvent.EventWindowTouchUp, function()
        self:changeDayMod("night")
    end)
    self:subscribe(self.dayNightMod, UIEvent.EventWindowTouchUp, function()
        self:changeDayMod("dayAndNight")
    end)
    
    self.dayTimeSlider = UILib.createSlider({value = 0, index = 5005}, function(value)
        oneDayTime = value
        self:saveData()
    end)
    self.gridList:AddItem(self.dayTimeSlider)
    self.showMoreGridList[#self.showMoreGridList + 1] = self.dayTimeSlider
end

function M:changeDayMod(mod)
    if not self.timeWnd then
        return
    end
    oneDayMod = mod
    self:saveData()
    local color1 = {174/255, 184/255, 183/255, 1}
    local color2 = {99/255, 100/255, 106/255, 1}
    self.timeWnd:child("RuleSetting-Day-Text"):SetTextColor(color1)
    self.timeWnd:child("RuleSetting-Night-Text"):SetTextColor(color1)
    self.timeWnd:child("RuleSetting-DayNight-Text"):SetTextColor(color1)
    -- self.timeWnd:child("RuleSetting-DayTime"):SetEnabledRecursivly(false)
    if mod == "day" then
        self.timeWnd:child("RuleSetting-Day-Text"):SetTextColor(color2)
        self.timeWnd:child("RuleSetting-Day"):SetSelected(true)
    elseif mod == "night" then
        self.timeWnd:child("RuleSetting-Night-Text"):SetTextColor(color2)
        self.timeWnd:child("RuleSetting-Night"):SetSelected(true)
    else
        self.timeWnd:child("RuleSetting-DayNight-Text"):SetTextColor(color2)
        self.timeWnd:child("RuleSetting-DayNight"):SetSelected(true)
        -- self.timeWnd:child("RuleSetting-DayTime"):SetEnabledRecursivly(true)
    end
end

function M:initSwitchAndRewardWnd()
    self:createSwitchItem(offOnUI[1].key, offOnUI[1].index)
    local rewardWnd = GUIWindowManager.instance:LoadWindowFromJSON("Basics_Setting.json")
    local setRewardBtn = rewardWnd:child("Basics-Setting-Reward-Btn")
    rewardWnd:child("Basics-Setting-Reward-Title"):SetText(Lang:toText("win.map.global.rewardSetting"))
    setRewardBtn:SetText(Lang:toText("block.die.drop.setting"))
    self:subscribe(setRewardBtn, UIEvent.EventButtonClick, function()
        Lib.emitEvent(Event.EVENT_OPEN_REWARD_SETTING)
    end)
    self.gridList:AddItem(rewardWnd)
end

function M:getMinPlayers()
    return gameTimeData.minPlayers
end

local function checkMinPlayer(sliderUi, value)
    local singleMaxNumWnd = UI:getWnd("mapEditTeamSetting")
    local teamMaxNumWnd = UI:getWnd("mapEditteamDetailItemTop")
    local gameTeamMode, singleMaxNum, teamMaxNum

    if singleMaxNumWnd and singleMaxNumWnd:getGameTeamMode() then
        gameTeamMode = singleMaxNumWnd:getGameTeamMode()
    else
        gameTeamMode = globalSetting:getGameTeamMode()
    end

    if singleMaxNumWnd and singleMaxNumWnd:getMaxPlayer() then
        singleMaxNum = singleMaxNumWnd:getMaxPlayer()
    else
        singleMaxNum = globalSetting:getMaxPlayers()
    end

    if teamMaxNumWnd and teamMaxNumWnd:getTeamTotalPlayerNum() then
        teamMaxNum = teamMaxNumWnd:getTeamTotalPlayerNum()
    else
        teamMaxNum = globalSetting:getEditTeamMaxPlayerNum() or 4
    end
    local teamOrSingleMaxPlayerNum = gameTeamMode and teamMaxNum or singleMaxNum
    if value > teamOrSingleMaxPlayerNum  then
        sliderUi:invoke("onEditValueChanged", teamOrSingleMaxPlayerNum)
    else
        teamOrSingleMaxPlayerNum = value
    end
    return teamOrSingleMaxPlayerNum
end

function M:createSliderItem(layout, value, sliderIndex, funcNum, offsetY)
    local sliderWnd
    local function onClickNoCondition()
        local gameOverData = globalSetting:getGameOverCondition()
        gameOverData.timeOver.enable = false
        gameOverData.attainScore.enable = false
        gameOverData.killCount.enable = false
        gameOverData.otherAllDie = false
        gameOverData.noCondition = true
        globalSetting:saveGameOverCondition(gameOverData, false)
    end

    local function waitFun(value, isInfinity)
        gameTimeData.waitPlayerTime = value
        globalSetting:saveKey("waitPlayerTime",value * 20 ,false)
    end

    local function gameFun(value, isInfinity)
        if isInfinity then
            gameTimeData.playTime = -1
            globalSetting:saveKey("playTime", -1, false)
            timeSlider[2]:child("Slider-Edit"):SetText("--")
            timeSlider[2]:child("Slider-unit"):SetText(InfinityLang)
            onClickNoCondition()
        else
            gameTimeData.playTime = value
            globalSetting:saveKey("playTime", value * 20, false)
            timeSlider[2]:child("Slider-unit"):SetText(timeUnit)
        end
    end

    local function numFun(value, isInfinity)
        gameTimeData.minPlayers = checkMinPlayer(sliderWnd, value)
        globalSetting:saveMinPlayers(gameTimeData.minPlayers,false)
        globalSetting:onGamePlayerNumberChanged("minPlayers")
    end
    local func = {waitFun, gameFun, numFun}
    sliderWnd = UILib.createSlider({
        value = value,
        index = sliderIndex,
        listenType = "onFinishTextChange"
    }, funcNum and func[funcNum])
    sliderWnd:SetHeight({0, 72})
    if offsetY then
        sliderWnd:SetYPosition({0, offsetY})
    end
    if funcNum then
        timeSlider[funcNum] = sliderWnd
    end
    layout:AddChildWindow(sliderWnd)
    return sliderWnd
end

function M:createSwitchItem(key, switchIndex)
    local switchWnd = UILib.createSwitch({
        value = false, 
        index = switchIndex
    }, function(status) 
        switchCacheData[key] = status
        self:saveData()
    end)
    switchWnd:SetHeight({0, 45})
    self.gridList:AddItem(switchWnd)
    switchItems[key] = switchWnd
    return switchWnd
end

function M:initPopWnd()
    self.toolPopWnd = UI:openMultiInstanceWnd("mapEditPopWnd")

    self.toolPopWndBgBtn = self.toolPopWnd:child("popWndRoot-BgBtn")
    self.showSeePopWnd = self.toolPopWnd:child("Setting-Point-Brith-Show")
    
    self.toolPopRespawnView = self.showSeePopWnd:child("Setting-Point-Brith-Show-See")
    self.toolPopRespawnDel  = self.showSeePopWnd:child("Setting-Point-Brith-Show-Del")
    self.toolPopRespawnView:SetText(Lang:toText("win.map.global.setting.shop.tool.view"))
    self.toolPopRespawnDel:SetText(Lang:toText("win.map.global.setting.shop.tool.delete"))

    self:subscribe(self.toolPopRespawnDel, UIEvent.EventButtonClick, function()
        self:deleteInitPoint()
        self:setPopWndEnabled(false)
    end)

    self:subscribe(self.toolPopRespawnView, UIEvent.EventButtonClick, function()
        local pos = initPos and {x = initPos.x, y = initPos.y, z = initPos.z} or nil
        self:setPosPoint(7, {idx = 1, pos = pos, teamId = 0}, false)
        self:setPopWndEnabled(false)
    end)

    self:setPopWndEnabled(false)
    
    self:subscribe(self.toolPopWndBgBtn, UIEvent.EventWindowTouchUp, function()
        self:setPopWndEnabled(false)
	end)
end

function M:setPopWndEnabled(isEnable)
    
    if isEnable then
        self:setPopWndPosition()
    end
    self.toolPopWndBgBtn:SetEnabledRecursivly(isEnable)
    self.toolPopWndBgBtn:SetVisible(isEnable)

    self.showSeePopWnd:SetEnabledRecursivly(isEnable)
    self.showSeePopWnd:SetVisible(isEnable)

end

function M:setPopWndPosition()
    local pos = self.toSettingWnd:GetRenderArea()
    local posx = {[1] = 0, [2] = pos[1] + self.toSettingWnd:GetPixelSize().x + 14}
    local posy = {[1] = 0, [2] = pos[2]}
    if posx[2] >= 1000 then
        posx[2] = pos[1] - 247
    end
    
    self.showSeePopWnd:SetXPosition(posx)
    self.showSeePopWnd:SetYPosition(posy)
end

function M:switchBtn(flag)
    self.toSettingWnd:SetVisible(flag)
    self.settingWnd:SetVisible(not flag)
end

function M:initData()
    gameTimeData.playTime = globalSetting:getValByKey("playTime")
    if gameTimeData.playTime == -1 then
        gameTimeData.playTime = 10000
    else 
        gameTimeData.playTime = gameTimeData.playTime / 20
    end
    gameTimeData.waitPlayerTime = globalSetting:getValByKey("waitPlayerTime") / 20
    gameTimeData.minPlayers = not gameTimeData.minPlayers and globalSetting:getValByKey("minPlayers") or gameTimeData.minPlayers
    initPos = globalSetting:getInitPos()
    if initPos and initPos.default then
        initPos = nil
    end

    local skyBox = globalSetting:getValByKey("skyBox") or {}
    oneDayTime = globalSetting:getValByKey("oneDayTime") or 1
    oneDayMod = skyBox.mod or "day"
    for _, cfg in pairs(offOnUI) do
        switchCacheData[cfg.key] = globalSetting:getValByKey(cfg.key) or false
    end
end

function M:refreshWnd()
    local childCount = self.timeLayout:GetChildCount()
    local key = {"waitPlayerTime", "playTime"}
    for i = 1, childCount do
        local wnd = timeSlider[i]
        local setData = gameTimeData[key[i]]
        wnd:invoke("setUIValue", setData)
        if setData == 10000 then
            timeSlider[2]:child("Slider-Edit"):SetText("--")
            timeSlider[2]:child("Slider-unit"):SetText(InfinityLang)
        else
            timeSlider[2]:child("Slider-unit"):SetText(timeUnit)
        end
    end
    self.playerSlider:invoke("setUIValue", gameTimeData.minPlayers)
    if not next(initPos or {}) or initPos.default then
        self:switchBtn(true)
    else
        self:switchBtn(false)
    end

    if oneDayMod == "day" then
        self:changeDayMod("day")
    elseif oneDayMod == "night" then
        self:changeDayMod("night")
    else
        self:changeDayMod("dayAndNight")
    end
    if self.dayTimeSlider then
        self.dayTimeSlider:invoke("setUIValue", oneDayTime)
    end

    for _, cfg in pairs(offOnUI) do
        if switchItems[cfg.key] then
            switchItems[cfg.key]:invoke("setUIValue", switchCacheData[cfg.key])
        end
    end
end

function M:setPosPoint(op, data, isShowPanel)
    Lib.emitEvent(Event.EVENT_HIDE_GLOBAL_SETTING, true, op, 0)
    if UI:isOpen("mapEditPositionSetting") then
        UI:getWnd("mapEditPositionSetting"):onOpen(op, data, isShowPanel)
        return
    end
    UI:openWnd("mapEditPositionSetting", op, data, isShowPanel)
--    if isEmitEvent then
--        --Lib.emitEvent(Event.EVENT_SETTING_POS, pos)
--    end
end

function M:saveData()
    local skyBox = globalSetting:getValByKey("skyBox") or {}
    local brightness = globalSetting:getValByKey("dynamicBrightness") or {}
    skyBox.mod = oneDayMod
    globalSetting:saveKey("skyBox", skyBox)
    globalSetting:saveKey("oneDayTime", oneDayTime)
    mapSetting:saveSkyBox(skyBox[oneDayMod])
    mapSetting:saveDynamicBrightness(brightness[oneDayMod])
    for _, cfg in pairs(offOnUI) do
        globalSetting:saveKey(cfg.key, switchCacheData[cfg.key])
    end
end

function M:onOpen()
    self:initData()
    self:refreshWnd()
end

function M:onReload()

end

return M