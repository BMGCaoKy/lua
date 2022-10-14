local globalSetting = require "editor.setting.global_setting"
local editorUtils = require "editor.utils"
local entity_obj = require "editor.entity_obj"
local gameOverData
local settingNum
local DEFAULT_WINDOW_HEIGHT = 820

local function initUi(self)
    self.endLayout = self:child("Setting-EndLayout-CheckLayout")
    self.endCheck = self:child("Setting-EndLayout-Check")
    self.endTitle = self:child("Setting-EndLayout-Title")
    self.endKillLayout = self:child("Setting-EndLayout-KillLayout")
    self.endKillCheck = self:child("Setting-EndLayout-EndKillCheck")
    self.endIntegralLayout = self:child("Setting-EndLayout-IntegralLayout")
    self.endIntegralCheck = self:child("Setting-EndLayout-EndIntegralCheck")

    self.killSliderLayout = self:child("Setting-KillLayout-SliderLayout")
    self.killCheck = self:child("Setting-KillLayout-Check")

    self.integralSliderLayout = self:child("Setting-IntegralLayout-SliderLayout")
    self.integralCheck = self:child("Setting-IntegralLayout-Check")

    self.besidesLayout = self:child("Setting-BesidesLayout")
    self.besidesCheck = self:child("Setting-BesidesLayout-Check")
    self.besidesTitle = self:child("Setting-BesidesLayout-Title")

    self.endPointTitle = self:child("Setting-endPointCondition-Title")
    self.endPointCheck = self:child("Setting-endPointCondition-Check")
    self.endPointLayout = self:child("Setting-endPointCondition")
    self.endPointItemLayout = self:child("Setting-EndPoint-AddItemLayout")
    self.endPointAddItemBtn = self:child("EndPoint-AddItemLayout-AddEndPointBtn")
    self.endPointSettingBtn = self:child("EndPoint-AddItemLayout-SettingEndPointBtn")

    self.propsCollectionLayout = self:child("Setting-PropsCollectionLayout")
    self.propCheck = self:child("Setting-PropsCollectionLayout-Check")
    self.PropsCollectionSliderLayout = self:child("Setting-PropsCollectionLayout-SliderLayout")
    self.propAddItemLayout = self:child("Setting-AddProp")

    self:child("Setting-title"):SetText(Lang:toText("win.map.global.setting.victory.title"))
    self:child("Setting-EndLayout-Title"):SetText(Lang:toText("win.map.global.setting.victory.endTitle"))
    local killText = Lang:toText("win.map.global.setting.victory.endKill1")
    local integralText = Lang:toText("win.map.global.setting.victory.endIntegral1")

    local killFrameText = self:child("Setting-EndLayout-KillLayout-Text")
    local integralFrameText = self:child("Setting-EndLayout-IntegralLayout-Text")

    killFrameText:SetText(killText)
    integralFrameText:SetText(integralText)
    self.endPointTitle:SetText(Lang:toText("win.map.global.setting.victory.endPointCondition"))
    self:child("Setting-KillLayout-Title"):setTextAutolinefeed(Lang:toText("win.map.global.setting.victory.killTitle"))
    self:child("Setting-IntegralLayout-Title"):SetText(Lang:toText("win.map.global.setting.victory.integralTitle"))
    self:child("Setting-BesidesLayout-Title"):SetText(Lang:toText("win.map.global.setting.victory.Besides"))
    self:child("Setting-PropsCollectionLayout-Title"):SetText(Lang:toText("win.global.vectorRule.CollectPropTips"))
    self:child("Setting-BesidesLayout-Tip"):SetText(Lang:toText("win.map.global.setting.victory.Besides.tip"))
    self:child("Setting-AddProp-text"):SetText(Lang:toText("items_tip"))
    self:initPopWnd()
end

local function initSlider(self)
    local function createSlider(sliderItem)
        local slider = UILib.createSlider({value = sliderItem.value, index = sliderItem.index, listenType = "onFinishTextChange"},sliderItem.func)
        slider:SetHeight({0, 44})
        slider:child("Slider-Name"):SetTextColor({99 / 255, 100 / 255, 106 / 255, 1})
        sliderItem.layout:AddChildWindow(slider)
        return slider
    end

    local function killFun(value, isInfinity)
        if isInfinity then
            gameOverData.killCount.enable = false
        else
            gameOverData.killCount.enable = true
            gameOverData.killCount.value = value
        end
    end

    local function integralFun(value, isInfinity)
        if isInfinity then
            gameOverData.attainScore.enable = false
        else
            gameOverData.attainScore.enable = true
            gameOverData.attainScore.value = value
        end
    end

    local function PropsCollectionFun(value, isInfinity)
        if isInfinity then
            gameOverData.propsCollection.enable = false
        else
            gameOverData.propsCollection.enable = true
            gameOverData.propsCollection.duration = value
        end
    end

    local sliderCfg = {
        {
            value = 10,
            index = 7,
            func = killFun,
            layout = self.killSliderLayout,
            slider = "killSlider"
        },
        {
            value = 100,
            index = 8,
            func = integralFun,
            layout = self.integralSliderLayout,
            slider = "integralSlider"
        },
        {
            value = 0,
            index = 5031,
            func = PropsCollectionFun,
            layout = self.PropsCollectionSliderLayout,
            slider = "PropsCollectionSlider"
        },
    }

    for k, sliderItem in pairs(sliderCfg) do
        self[sliderItem.slider] = createSlider(sliderItem)
    end
end

local function judgeInfiniteRebirth()

    local rebirthTimes = World.cfg.rebirth
    local teamInfo = World.cfg.team
    local gameTeamMode = globalSetting:getGameTeamMode()
    local playerSeettingWnd = UI:getWnd("mapEditPlayerSetting")
    local teamSettingWnd = UI:getWnd("mapEditTeamSetting")
    local teamItemSettingWnd = UI:getWnd("mapEditteamDetailItemBottom2")

    if teamSettingWnd and teamSettingWnd:getGameTeamMode() then
        gameTeamMode = teamSettingWnd:getGameTeamMode()
    end

    if playerSeettingWnd and playerSeettingWnd:getReviveInfo() then
        rebirthTimes = playerSeettingWnd:getReviveInfo()
    end

    if teamItemSettingWnd and teamItemSettingWnd:getTeamInfo() then
        teamInfo = teamItemSettingWnd:getTeamInfo()
    end

    local result = (rebirthTimes.times ~= -1) and (rebirthTimes.times ~= 999)
    if not result and gameTeamMode and teamInfo then
        result = true
        for _, data in pairs(teamInfo) do
            if not data.bed.enable then
                result = false
                break
            end
        end
    end
    return result
end

local function initSubscribe(self)
    local function judge(isCheck)
        if isCheck == false and settingNum <= 1 then
            return false
        end
        if isCheck then
            settingNum = settingNum + 1
        else
            settingNum = settingNum - 1
        end
        return true
    end

    self:subscribe(self:child("Setting-EndLayout-CheckLayout"), UIEvent.EventWindowTouchUp, function()
        local isChecked = not self.endCheck:GetChecked()
        if judge(isChecked) then
            gameOverData.timeOver.enable = isChecked
            self:setEndLayoutEnabled(isChecked)
            self.endCheck:SetChecked(isChecked)
        end
    end)

    self:subscribe(self:child("Setting-KillLayout-CheckFrame"), UIEvent.EventWindowTouchUp, function()
        local isChecked = not self.killCheck:GetChecked()
        if judge(isChecked) then
            self.killCheck:SetChecked(isChecked)
            gameOverData.killCount.enable = isChecked
            self:setSliderEnabled(self.killSlider, isChecked)
        end
    end)

    self:subscribe(self:child("Setting-PropsCollectionLayout-CheckFrame"), UIEvent.EventWindowTouchUp, function()
        local isChecked = not self.propCheck:GetChecked()
        if judge(isChecked) then
            self.propCheck:SetChecked(isChecked)
            gameOverData.propsCollection.enable = isChecked
            self:isShowChildItemUI(isChecked, "propCollectItemUI")
            self:setSliderEnabled(self.PropsCollectionSlider, isChecked)
        end
    end)

    self:subscribe(self:child("Setting-IntegralLayout-CheckFrame"), UIEvent.EventWindowTouchUp, function()

        local function killRewardEnable(isChecked)
            local killReward = globalSetting:getKillReward()
            local bedBreakReward = globalSetting:getBedBreakReward()
            if killReward and killReward.addScore then
                killReward.addScore.enable = isChecked
                globalSetting:saveKillReward(killReward, true)
            end
            if bedBreakReward and bedBreakReward.addScore then
                bedBreakReward.addScore.enable = isChecked
                globalSetting:saveBedBreakReward(bedBreakReward, true)
            end
        end

        local isChecked = not self.integralCheck:GetChecked()
        killRewardEnable(isChecked)
        if judge(isChecked) then
            self.integralCheck:SetChecked(isChecked)
            gameOverData.attainScore.enable = isChecked
            self:setSliderEnabled(self.integralSlider, isChecked)
        end
    end)

    self:subscribe(self:child("Setting-BesidesLayout-CheckFrame"), UIEvent.EventWindowTouchUp, function()
        local isChecked = not self.besidesCheck:GetChecked()
        if judge(isChecked) then
            gameOverData.otherAllDie = isChecked
            self.besidesCheck:SetChecked(isChecked)
        end
    end)

    self:subscribe(self:child("Setting-endPointCondition-CheckFrame"), UIEvent.EventWindowTouchUp, function()
        local isChecked = not self.endPointCheck:GetChecked()
        if judge(isChecked) then
            gameOverData.endPointCondition.enable = isChecked
            self:isShowChildItemUI(isChecked, "endPointItemUI")
            self.endPointCheck:SetChecked(isChecked)
            self.endPointTitle:SetEnabled(isChecked)
        end
    end)

    self:subscribe(self:child("EndPoint-AddItemLayout-AddEndPointBtn"), UIEvent.EventButtonClick, function()
        local initPos = globalSetting:getInitPos()
        self:setEndPointPos(8, {idx = 100, pos = initPos}, true)
    end)

    self:subscribe(self:child("EndPoint-AddItemLayout-SettingEndPointBtn"), UIEvent.EventButtonClick, function()
        self:setPopWndEnabled(true)
    end)

    self:subscribe(self:child("Setting-EndLayout-KillLayout"), UIEvent.EventWindowTouchUp, function()
        gameOverData.timeOver.value = "killCount"
        self:endLayoutSelect()
    end)

    self:subscribe(self:child("Setting-EndLayout-IntegralLayout"), UIEvent.EventWindowTouchUp, function()
        gameOverData.timeOver.value = "score"
        self:endLayoutSelect()
    end)
end

function M:setEndPointPos(op, data, isShowPanel)
    Lib.emitEvent(Event.EVENT_HIDE_GLOBAL_SETTING, true, op, 0)
    if UI:isOpen("mapEditPositionSetting") then
        UI:getWnd("mapEditPositionSetting"):onOpen(op, data, isShowPanel)
        return
    end
    UI:openWnd("mapEditPositionSetting", op, data, isShowPanel)
end

function M:setLayoutStatus(layoutUI, textUI, isEnable)
    if not isEnable then
        textUI:SetTextColor({141/255, 143/255, 151/255, 1})
    else
        textUI:SetTextColor({44/255, 177/255, 130/255, 1})
    end
    layoutUI:SetEnabledRecursivly(isEnable)
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
        gameOverData.endPointCondition.pos = nil
        gameOverData.endPointCondition.enable = false
        self:switchBtn(false)
        entity_obj:delEntityByFullName("myplugin/endPoint")
        self:setPopWndEnabled(false)
    end)

    self:subscribe(self.toolPopRespawnView, UIEvent.EventButtonClick, function()
        local pos = gameOverData.endPointCondition.pos
        self:setEndPointPos(8, {idx = 100, pos = pos, entity = "myplugin/endPoint"}, false)
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
    local pos = self.endPointAddItemBtn:GetRenderArea()
    local posx = {[1] = 0, [2] = pos[1] + self.endPointAddItemBtn:GetPixelSize().x + 14}
    local posy = {[1] = 0, [2] = pos[2]}
    if posx[2] >= 1000 then
        posx[2] = pos[1] - 247
    end

    self.showSeePopWnd:SetXPosition(posx)
    self.showSeePopWnd:SetYPosition(posy)
end

function M:switchBtn(flag)
    local isShow = flag and true or false
    self.endPointSettingBtn:SetVisible(isShow)
    self.endPointAddItemBtn:SetVisible(not isShow)
end

local function selectProp(self)
    UI:openMultiInstanceWnd("mapEditItemBagSelect", {uiNameList = {"block", "bagWeaponList", "shopItemList", "shopResourceList"},backFunc = function(item, isBuff)
        local propInfo = {name = item:full_name(), count = 1, icon = item:icon(), type = item:type()}
        gameOverData.propsCollection.propCfg = propInfo
        self:refreshProp()
    end})
end

local function getAddPropBtn(self)
    local addBtnLayout = GUIWindowManager.instance:CreateGUIWindow1("Layout", "addBtn")
    addBtnLayout:SetArea({0, 0}, {0, 0}, {0, 120}, {0, 120})
    local addBtn = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "addBtn")
    addBtn:SetImage("set:setting_global.json image:btn_add_equip_n.png")
    addBtn:SetArea({0, 0}, {0, 8}, {1, 0}, {1, 0})
    self:subscribe(addBtn, UIEvent.EventWindowTouchUp, function()
        selectProp(self)
    end)
    addBtnLayout:AddChildWindow(addBtn)
    return addBtnLayout
end

local function createItem(self, data)
    local function CreateItemData(type, fullName, args)
        local item = EditorModule:createItem(type, fullName, args)
        local cfg = item:cfg()
        return item, cfg
    end

    local cell = UIMgr:new_widget("cell","widgetSettingItem_edt.json")
    local numBtn = cell:receiver()._cs_bottom
    local delBtn = cell:receiver()._btn_close
    local nameText = cell:receiver()._lb_bottom
    local img = cell:receiver()._img_item
    local bg = cell:receiver()._img_bg
    local item = CreateItemData(data.type, data.name, {
        icon = data.icon
    })
    delBtn:SetVisible(true)
    img:SetImage(item:icon())
    cell:receiver()._bottom_text:SetText("X" .. (data.count or 1))
    nameText:SetVisible(true)
    nameText:SetText(Lang:toText(item:getNameText() or ""))
    nameText:SetTextColor({64/255, 135/255, 75/255, 1})
    nameText:SetProperty("Font","HT14")
    numBtn:SetVisible(not data.isBuff and true or false)
    self:subscribe(delBtn, UIEvent.EventButtonClick, function()
        gameOverData.propsCollection.propCfg = nil
        self:refreshProp()
    end)
    self:subscribe(bg, UIEvent.EventWindowTouchUp, function()
        selectProp(self)
    end)
    self:subscribe(numBtn, UIEvent.EventButtonClick, function()
        UILib.openCountUI(data.count, function(num, isInfinity)
            gameOverData.propsCollection.propCfg.count = isInfinity and 1 or num
            self:refreshProp()
        end, true)
    end)

    return cell
end

function M:isShowChildItemUI(isShow, showType)
    local offsetWindow = DEFAULT_WINDOW_HEIGHT
    local rootHeight = self:root():GetHeight()[2]
    local childUiList = {
        endPointItemUI = {
            isShowItem = self.endPointItemLayout:IsVisible(),
            itemHeight = self.endPointItemLayout:GetHeight()[2],
            layoutHeight = self.endPointLayout:GetHeight()[2],
            defaultLayoutHeight = 50,
            itemLayoutUi = self.endPointItemLayout,
            layoutUi = self.endPointLayout
        },
        propCollectItemUI = {
            isShowItem = self.propAddItemLayout:IsVisible(),
            itemHeight = self.propAddItemLayout:GetHeight()[2],
            layoutHeight = self.propsCollectionLayout:GetHeight()[2],
            defaultLayoutHeight = 138,
            itemLayoutUi = self.propAddItemLayout,
            layoutUi = self.propsCollectionLayout
        }
    }

    local opChildUi = childUiList[showType]
    local isSameStatus = opChildUi.isShowItem == isShow
    opChildUi.isShowItem = isShow
    for _, itemUi in pairs(childUiList) do
        if itemUi.isShowItem then
            offsetWindow = offsetWindow + itemUi.itemHeight
        end
    end

    local totleLayoutHeight = opChildUi.layoutHeight + (isSameStatus and 0 or opChildUi.itemHeight)
    local setRootHeight = isShow and (not isSameStatus) and (rootHeight + opChildUi.itemHeight) or offsetWindow
    local setLayoutHeight = isShow and totleLayoutHeight or opChildUi.defaultLayoutHeight

    opChildUi.itemLayoutUi:SetVisible(isShow)
    self:root():SetHeight({0, setRootHeight})
    opChildUi.layoutUi:SetHeight({0, setLayoutHeight})

end

function M:refreshProp()
    self.addPropGrid:RemoveAllItems()
    if not gameOverData.propsCollection.propCfg then
        self.addPropGrid:AddItem(getAddPropBtn(self))
    else
        local itemWnd = createItem(self, gameOverData.propsCollection.propCfg)
        self.addPropGrid:AddItem(itemWnd)
    end
end

function M:initAddPropGrid()
    self.addPropGrid = self:child("Setting-AddProp-Grid")
    self.addPropGrid:InitConfig(20,20,5)
    self.addPropGrid:SetMoveAble(false)
    self.addPropGrid:SetAutoColumnCount(false)

    self:refreshProp()
end

function M:init()
    WinBase.init(self, "victorySettingLayout_edit.json")
    initUi(self)
    initSlider(self)
    initSubscribe(self)
    self:initData()
    self:initAddPropGrid()
end

function M:initData()
    if not gameOverData then
        gameOverData = globalSetting:getGameOverCondition() or {}
    end
    gameOverData.endPointCondition = editorUtils:getEndPointOnMap()

    if gameOverData.otherAllDie then
        gameOverData.otherAllDie = judgeInfiniteRebirth()
    end

    if gameOverData.timeOver.value ~= "score" and gameOverData.timeOver.value ~= "killCount" then
        gameOverData.timeOver.value = "killCount"
    end

    if not gameOverData.propsCollection then
        gameOverData.propsCollection = {}
        gameOverData.propsCollection.duration = 0
        gameOverData.propsCollection.enable = false
    end

    settingNum = 0
    for key, data in pairs(gameOverData) do
        local enable
        if type(data) == "table" then
            enable = data.enable
        else
            enable = data
        end
        if key ~= "noCondition" and enable then
            settingNum = settingNum + 1
        end
    end

    if settingNum == 0 then
        gameOverData.noCondition = false
        gameOverData.killCount.enable = true
        gameOverData.killCount.value = 10
    end
    self:endLayoutSelect()

    if not gameOverData.timeOver.enable then
        self.endCheck:SetChecked(false)
        self:setEndLayoutEnabled(false)
    else
        self:setEndLayoutEnabled(true)
        self.endCheck:SetChecked(true)
    end

    local enableEndCheck = globalSetting:getValByKey("playTime") ~= -1
    self:setLayoutStatus(self.endLayout, self.endTitle, enableEndCheck)

    self.killSlider:invoke("setUIValue", gameOverData.killCount.value)
    self.PropsCollectionSlider:invoke("setUIValue", gameOverData.propsCollection.duration)
    self.integralSlider:invoke("setUIValue", gameOverData.attainScore.value)

    self.killCheck:SetChecked(gameOverData.killCount.enable)
    self:setSliderEnabled(self.killSlider, gameOverData.killCount.enable)

    self.propCheck:SetChecked(gameOverData.propsCollection.enable)
    self:setSliderEnabled(self.PropsCollectionSlider, gameOverData.propsCollection.enable)

    self.integralCheck:SetChecked(gameOverData.attainScore.enable)
    self:setSliderEnabled(self.integralSlider, gameOverData.attainScore.enable)

    self.besidesCheck:SetChecked(gameOverData.otherAllDie)
    self:setLayoutStatus(self.besidesLayout, self.besidesTitle, judgeInfiniteRebirth())

    self.endPointCheck:SetChecked(gameOverData.endPointCondition.enable)
    self:switchBtn(gameOverData.endPointCondition.pos)

end

function M:setEndChild()
    self.endKillCheck:SetChecked(gameOverData.timeOver.value == "killCount")
    self.endKillCheck:SetEnabled(gameOverData.timeOver.value == "killCount")
    self.endKillCheckBG:SetEnabled(gameOverData.timeOver.value == "killCount")
    self.endIntegralCheck:SetChecked(gameOverData.timeOver.value == "score")
    self.endIntegralCheck:SetEnabled(gameOverData.timeOver.value == "score")
    self.endIntegralCheckBG:SetEnabled(gameOverData.timeOver.value == "score")
end

function M:setSliderEnabled(slider, isEnabled)
    slider:SetEnabledRecursivly(isEnabled)
end

function M:endLayoutSelect()
    self.endKillCheck:SetChecked(gameOverData.timeOver.value == "killCount")
    self.endIntegralCheck:SetChecked(gameOverData.timeOver.value == "score")
end

function M:setEndLayoutEnabled(isEnabled)
    self.endKillLayout:SetEnabledRecursivly(isEnabled)
    self.endIntegralLayout:SetEnabledRecursivly(isEnabled)
end

function M:saveData()
    globalSetting:saveGameOverCondition(gameOverData, false)
end

function M:onOpen()
    self:initData()
    self:isShowChildItemUI(gameOverData.endPointCondition.enable, "endPointItemUI")
    self:isShowChildItemUI(gameOverData.propsCollection.enable, "propCollectItemUI")
end

function M:onReload(reloadArg)

end

return M