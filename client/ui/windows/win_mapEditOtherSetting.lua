local globalSetting = require "editor.setting.global_setting"
local offOnUI = {
    {index = 5012, key = "isRandomAddMonster"}
}
local switchCacheData = {}
local switchItems = {}

local offSetY = 120

function M:init()
    WinBase.init(self, "otherSetting_edit.json")
    self.grid = self:child("OtherSetting-Grid")
    self.grid:InitConfig(0, 36, 1)
    self:initSwitchUi()
    self:initCompositeUi()

    self:subscribe(self:child("OtherSetting-Monster-Set-Btn"), UIEvent.EventButtonClick, function()
        UI:openWnd("mapEditRuleSettingMonster")
    end)

end

function M:initSwitchUi()
    local switchWnd = self:createSwitchItem(offOnUI[1], true)
    self:child("OtherSetting-MonsterSwitchLayout"):AddChildWindow(switchWnd)
    self:child("OtherSetting-Monster-Text"):SetText(Lang:toText("other_setting_set_monster"))
    self:child("OtherSetting-Monster-Set-Btn"):SetText(Lang:toText("block.die.drop.setting"))
end

function M:initCompositeUi()
    self.compositeLayout = self:child("OtherSetting-Composite")
    local setCompositeBtn = self:child("OtherSetting-Composite-Btn")
    self.compositeLayout:SetVisible(false)
    self:child("OtherSetting-Composite-Title"):SetText(Lang:toText("gui_player_composite"))
    setCompositeBtn:SetText(Lang:toText("block.die.drop.setting"))
    self:subscribe(setCompositeBtn, UIEvent.EventButtonClick, function()
        UI:openWnd("mapEditCompositeSetting")
    end)
end



function M:createSwitchItem(cfg, noAddGrid)
    local switchWnd = UILib.createSwitch({
        value = false, 
        index = cfg.index
    }, function(status) 
        switchCacheData[cfg.key] = status
        self:saveData()
        if cfg.key == "isRandomAddMonster" then
            self:child("OtherSetting-Monster"):SetVisible(status)
            local offY = status and 50 or -50
            offSetY = offSetY + offY
            self:refreshWnd()
        end
    end)
    switchWnd:SetHeight({0, 45})
    if not noAddGrid then
        self.grid:AddItem(switchWnd)
    end
    switchItems[cfg.key] = switchWnd
    return switchWnd
end

function M:refreshData()
    for _, cfg in pairs(offOnUI) do
        switchCacheData[cfg.key] = globalSetting:getValByKey(cfg.key) or false
    end
end

function M:refreshWnd()
    self.compositeLayout:SetYPosition({0, offSetY})
    for _, cfg in pairs(offOnUI) do
        switchItems[cfg.key]:invoke("setUIValue", switchCacheData[cfg.key])
        if cfg.key == "isRandomAddMonster" then
            self:child("OtherSetting-Monster"):SetVisible(switchCacheData[cfg.key])
        end
    end
end

function M:saveData()
    for _, cfg in pairs(offOnUI) do
        globalSetting:saveKey(cfg.key, switchCacheData[cfg.key])
    end
end

function M:onOpen()
    self:refreshData()
    self:refreshWnd()
end

function M:onReload(reloadArg)

end

return M