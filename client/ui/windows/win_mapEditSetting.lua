local globalSetting = require "editor.setting.global_setting"
local editorUtil = require "editor.utils"

function M:init()
    WinBase.init(self, "setting_edit.json")
    self:initData()
    self:initUI()
end

function M:initData()
    local settingData = Clientsetting.getSetting()
    local value = 1 - settingData["usePole"]
    local selectLeftValue = value == 0 and true or false
    self.moveSettingData = {
        {
            title = "gui.setting.direc.rocker",
            image = "set:map_edit_new_setting.json image:direc_rocker",
            isSelect = selectLeftValue,
            offsetX = 0,
            width = {0, 140},
            height = {0, 140}
        },
        {
            title = "gui.setting.direc.key",
            image = "set:map_edit_new_setting.json image:direc_key",
            isSelect = not selectLeftValue,
            offset = 1,
            offsetX = 0,
            width = {0, 140},
            height = {0, 140}
        }
    }

    local isThirdView = globalSetting:getIsThirdView()
    self.editViewData = {
        {
            title = "gui.setting.view.frist",
            image = "set:map_edit_new_setting.json image:frist_view",
            isSelect = not isThirdView,
            width = {0, 300},
            height = {0, 148}
        },
        {
            title = "gui.setting.view.third",
            image = "set:map_edit_new_setting.json image:third_view",
            isSelect = isThirdView,
            offset = 1,
            width = {0, 300},
            height = {0, 148}
        }
    }

    local dropValue = 1 - settingData["dropBubble"]
    self.isOpenDrop = dropValue == 1 and true or false
end

function M:initUI()
    self:child("Setting-Tab-Nor-Text"):SetText(Lang:toText("win.map.global.setting.shop.set"))
    self:child("Setting-Client-GuideText"):SetText(Lang:toText("win.setting.Guidelines"))
    self:child("Setting-Client-BackHomeText"):SetText(Lang:toText("win.setting.backHome"))

    local strLenght = #Lang:toText("win.map.global.setting.shop.set")
    if strLenght > 10 then
        self:child("Setting-Tab-Nor"):SetWidth({0, 190})
    end

    self:subscribe(self:child("Setting-Close"), UIEvent.EventButtonClick, function()
		UI:closeWnd(self)
    end)

    self:subscribe(self:child("Setting-Client-GuideLayout"), UIEvent.EventWindowClick, function()
        UI:openWnd("mapEditHelp")
    end)

    self:subscribe(self:child("Setting-Client-BackHomeLayout"), UIEvent.EventWindowClick, function()
        editorUtil:screenShot(function (screenShotImgPath)
            UI:closeWnd(self)
            UI:openWnd("mapEditScreenShot", screenShotImgPath)
        end)
    end)
    self.grid = self:child("Setting-Client-Content")
    self.grid:SetAutoColumnCount(false)
    self.grid:InitConfig(1, 1, 1)

    self:initMoveSetting()
    self:initEditView()
    self:initViewSetting()
end

local function createLayoutAndTitle(grid, titleText, height)
    local layout = GUIWindowManager.instance:CreateGUIWindow1("Layout", "")
    layout:SetArea({0, 0}, {0, 0}, {1, 0}, {0, height})

    local titleLauout = GUIWindowManager.instance:CreateGUIWindow1("Layout", "")
    titleLauout:SetArea({0, 20}, {0, 20}, {1, -40}, {0, 60})

    local titleBg = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "")
    titleBg:SetArea({0 , 0}, {0, 0}, {1, 0}, {0, 40})
    titleBg:SetImage("set:setting_global.json image:bg_small_title.png")

    local title = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "")
    title:SetArea({0, 10}, {0, 0}, {1, 10}, {0, 40})
    title:SetProperty("Font", "HT20")
    title:SetTextVertAlign(1)
    title:SetText(Lang:toText(titleText))
    
    titleLauout:AddChildWindow(titleBg)
    titleLauout:AddChildWindow(title)
    layout:AddChildWindow(titleLauout)
    grid:AddItem(layout)
    return layout
end

local function checkboxItem(itemUi, data)
    data.offset = (data.offset or 0) * 0.5
    local heightOffset = data.height and (300 - data.height[2])
    local settingCheckBoxLayout = GUIWindowManager.instance:LoadWindowFromJSON("setting_checkbox_layout.json")
    settingCheckBoxLayout:SetArea({data.offset, 0}, {0, 80}, {0.4, 0}, {0, 420})
    local image = settingCheckBoxLayout:child("Setting-Image")
    local checkBox = settingCheckBoxLayout:child("Setting-CheckBoxUi")
    local checkBoxText = settingCheckBoxLayout:child("Setting-ShowText")
    local checkBoxLayout = settingCheckBoxLayout:child("Setting-Checkbox")

    checkBoxLayout:SetYPosition({0, (heightOffset and heightOffset + 20) or 265})

    if World.Lang == "zh_CN" then
        checkBoxLayout:SetXPosition({0, 45})
    end

    image:SetArea({0, data.offsetX or 30}, {0, 20}, data.width or {0, 240}, data.height or {0, 240})
    image:SetImage(data.image)
    checkBox:SetChecked(data.isSelect)
    checkBoxText:SetText(Lang:toText(data.title))
    itemUi:AddChildWindow(settingCheckBoxLayout)
    return settingCheckBoxLayout:child("Setting-Checkbox"), checkBox, image
end

function M:initCheckBoxUi(layout, checkItems, func, datas)
    for _, data in pairs(datas) do
        local checkLayout, checkBox, image = checkboxItem(layout, data)
        checkItems[#checkItems + 1] = {checkLayout = checkLayout, checkBox = checkBox}

        local function checkFunc()
            local isLeftCheck = checkLayout == checkItems[1].checkLayout
            checkItems[1].checkBox:SetChecked(isLeftCheck)
            checkItems[2].checkBox:SetChecked(not isLeftCheck)
            func(isLeftCheck)
        end
        
        self:subscribe(checkLayout, UIEvent.EventWindowTouchUp, function()
            checkFunc()
        end)

        self:subscribe(image, UIEvent.EventWindowTouchUp, function()
            checkFunc()
        end)

    end
end

-- 移动设置
function M:initMoveSetting()
    local layout = createLayoutAndTitle(self.grid, "win.setting.moveSetting", 300)

    local function setPoleControl(isLeftCheck)
        Clientsetting.refreshPoleControlState(isLeftCheck and 1 or 0)
        Lib.emitEvent(Event.EVENT_SWITCH_MOVE_CONTROL, isLeftCheck and 1 or 0)
    end
    local checkItems = {}
    self:initCheckBoxUi(layout, checkItems, setPoleControl, self.moveSettingData)
end

-- 编辑视角
function M:initEditView()
    local layout = createLayoutAndTitle(self.grid, "win.setting.changeView", 300)
    local checkViewItems = {}

    local function switchView(isFristView)
        if isFristView then
            CGame.instance:onEditorDataReport("click_setting_first_person_perspective", "")
            EditorModule:getMoveControl():showTips(Lang:toText("switch_frist_view"))     --切换第一视角飘字提示
            EditorModule:getMoveControl():switchFristMoveWay(EditorModule:getMoveControl():isEnableFly())    -- 切换第一人称视角接口
        else
            CGame.instance:onEditorDataReport("click_setting_third_person_perspective", "")
            EditorModule:getMoveControl():showTips(Lang:toText("switch_third_view"))     --切换第三视角飘字提示
            EditorModule:getMoveControl():switchThirdMoveWay(EditorModule:getMoveControl():isEnableFly())    -- 切换第三人称视角接口
        end
    end
    self:initCheckBoxUi(layout, checkViewItems, switchView, self.editViewData)
    Lib.subscribeEvent(Event.EVENT_CHANGE_MAIN_UI_STATE, function (cfg)
        if cfg.isThirdView ~= nil then
            checkViewItems[1].checkBox:SetChecked(not cfg.isThirdView)
            checkViewItems[2].checkBox:SetChecked(cfg.isThirdView)
        end
    end)
end

-- 界面设置
function M:initViewSetting()
    local uiCount = 0
    local function dropSwitch(value)
        Clientsetting.refreshDropBubbleState(not value and 1 or 0)
    end

    local function createSwitch(layout, index, switchValue, func)
        local offset = 80 * uiCount
        local ui = UILib.createSwitch({
            value = switchValue or false,
            index = index
        }, function(value)
            func(value)
        end)
        ui:SetArea({0, 35}, {0, 60 + offset}, {0, 300}, {0, 90 + offset})
        ui:invoke("setTextUiSize", 18)
        layout:AddChildWindow(ui)
        uiCount = uiCount + 1
    end

    local layout = createLayoutAndTitle(self.grid, "win.setting.interfaceSetting", 150)
    local items = {
        {
            index = 5027,
            value = self.isOpenDrop,
            func = dropSwitch
        }
    }
    for _, item in pairs(items) do
        createSwitch(layout, item.index, item.value, item.func)
    end
end

return M