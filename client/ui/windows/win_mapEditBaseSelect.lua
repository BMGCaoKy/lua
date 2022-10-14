local global_setting = require "editor.setting.global_setting"
local entity_obj = require "editor.entity_obj"
local data_state = require "editor.dataState"

local baseImgMap = Clientsetting.getData("teamActorList") or {
    "myplugin/bed",
    "myplugin/egg",
}

local function fetchItem(baseName)
    local iconData = global_setting:actorsIconData(baseName)
    local item = GUIWindowManager.instance:LoadWindowFromJSON("base_cell.json")
    item:child("base_cell-name"):SetText("")
    item:child("base_cell-frame"):SetVisible(false)
    item:child("base_cell-frame"):SetImage("set:map_edit_global_setting.json image:icon_selected.png")
    item:child("base_cell-icon"):SetImage(iconData.icon)
    item:child("base_cell-icon"):SetHeight({0.8, 0})
    if iconData.height then
        item:child("base_cell-icon"):SetWidth({0.8 * iconData.width / iconData.height, 0})
    else
        item:child("base_cell-icon"):SetWidth({0.8, 0})
    end
    return item
end

function M:init()
    WinBase.init(self, "baseSelectjson.json")
    self.itemUIList = {}
    self:initUIName()
    self:initUI()
end

function M:initUIName()
    self.gridUI = self:child("root-grid")
end

function M:initUI()
    self:subscribe(self:child("root-close"), UIEvent.EventButtonClick, function()
        UI:closeWnd(self)
    end)
    self:subscribe(self:child("root-sure"), UIEvent.EventButtonClick, function()
        if self.backFunction then
            self.backFunction(self.baseName)
        end
        UI:closeWnd(self)
    end)
    
    self:child("root-title"):SetText(Lang:toText("win.ui.select.base.and.place"))

    self.gridUI:SetMoveAble(false)
    self.gridUI:InitConfig(46, 0, #baseImgMap)
    self.gridUI:SetItemAlignment(1)
    for _, name in pairs(baseImgMap) do
        self.itemUIList[name] = fetchItem(name)
        self.gridUI:AddItem(self.itemUIList[name])
        self:subscribe(self.itemUIList[name]:child("base_cell-bg"), UIEvent.EventWindowTouchUp, function() 
            self:selectItem(name)
        end)
    end
end

function M:selectItem(name)
    if not name then
        return
    end
    for _, ui in pairs(self.itemUIList) do
        ui:child("base_cell-frame"):SetVisible(false)
    end
    self.itemUIList[name]:child("base_cell-frame"):SetVisible(true)
    self.baseName = name
end

function M:onOpen(backFunction, baseName)
    self.baseName = baseName
    self.backFunction = backFunction
    self:selectItem(baseName)
    if not baseName then
        self:child("root-text"):SetText(Lang:toText("win.ui.select.base.sure.place"))
    else
        self:child("root-text"):SetText(Lang:toText("win.map.global.setting.team.setting.place.setting"))
    end
end

return M