local globalSetting = require "editor.setting.global_setting"
local entitySetting = require "editor.setting.entity_setting"
local editorSetting = require "editor.setting"

local Mod = {"basic","rich","unlimited"}
local dataMap = {
    ["basic"] = "basicEquip",
    ["rich"] = "richEquip"
}
local ResourcesData = {}
local equipData = {}

local function fetchCell()
    local	ret = UIMgr:new_widget("cell","widgetSettingItem_edt.json")
    return ret
end

local function CreateItemData(type, fullName, args)
    local item = EditorModule:createItem(type, fullName, args)
    local cfg = item:cfg()
    return item, cfg
end

local function selectCell(self, cell, item)
    local list = self:child("Equip-Desc-List")
    list:ClearAllItem()
    if not cell then
        self.lastSelect = nil
        self:child("Equip-Show-Equip"):SetImage("")
        self.introItemNameWnd:SetText("")
        self:child("Equip-Show-Btn"):SetEnabledRecursivly(false)
        return
    end
    if self.lastSelect then
        self.lastSelect:receiver():onClick(false, "")
        self.lastSelect:receiver()._btn_close:SetVisible(false)
    end
    self.lastSelect = cell
    cell:receiver():onClick(true, "set:setting_global.json image:check_equip_show_click.png")
    cell:receiver()._btn_close:SetVisible(true)
    self:child("Equip-Show-Btn"):SetEnabledRecursivly(true)
    self:child("Equip-Show-Equip"):SetImage(item:icon())
    self:child("Equip-Show-Name"):SetText(Lang:toText(item:getNameText() or ""))
    local attrs = Lib.splitString(item:getDescText() or "", "&")
    local yOffset = 0
	local w = list:GetPixelSize().x
	local h = list:GetPixelSize().y
    for index, attr in pairs(attrs) do
        local stAttr = GUIWindowManager.instance:CreateGUIWindow1("StaticText", string.format("ShopItem-Tip-Desc-%d", index))
		stAttr:SetWordWrap(true)
        if string.find(attr, "=") then
            local kvPair = Lib.splitString(attr, "=")
            stAttr:SetText(Lang:formatText(kvPair))
        else
            stAttr:SetText(Lang:formatText(attr))
        end
		stAttr:SetWidth({ 0, w })
		local height = stAttr:GetTextStringHigh()
        stAttr:SetHeight({ 0, height })
        stAttr:SetXPosition({ 0, 0 })
        stAttr:SetYPosition({ 0, yOffset})
        stAttr:SetTextColor({64/255, 135/255, 75/255, 1})
        stAttr:SetProperty("Font", "HT12")
		yOffset = yOffset + height
        list:AddItem(stAttr)
    end
	list:SetMoveAble(yOffset > h)
end


function M:refreshEquip()
    local grid = self:child("Equip-Layout-Grid")
    selectCell(self, nil, nil)
    grid:RemoveAllItems()
    for i = 1, #equipData do
        self:addItem(i)
    end
end

local function updateBasicEquipNum(self, index, num, isInfinity)
    local basicEquip = equipData
    local tb = basicEquip[index]
    tb.count = isInfinity and 64 or num
    tb.isInfinity = isInfinity
    self:refreshEquip()
end

local function createItem(self, grid, index, data)
    local cell = fetchCell()
    local numBtn = cell:receiver()._cs_bottom
    local delBtn = cell:receiver()._btn_close
    local nameText = cell:receiver()._lb_bottom
    local img = cell:receiver()._img_item
    local bg = cell:receiver()._img_bg
    local item = CreateItemData(data.type, data.name, {
        icon = data.icon
    })
    img:SetImage(item:icon())
    if data.isInfinity or data.count == 64 then
        cell:receiver()._bottom_text:SetText("∞")
    else
        cell:receiver()._bottom_text:SetText("X" .. (data.count or 1))
    end
    nameText:SetVisible(true)
    nameText:SetText(Lang:toText(item:getNameText() or ""))
    nameText:SetTextColor({64/255, 135/255, 75/255, 1})
    nameText:SetProperty("Font","HT14")
    cell:setData("index", index)
    numBtn:SetVisible(not data.isBuff and true or false)
    self:subscribe(delBtn, UIEvent.EventButtonClick, function()
        table.remove(equipData, index)
        self:refreshEquip()
    end)
    self:subscribe(bg, UIEvent.EventWindowTouchUp, function()
        selectCell(self, cell, item)
    end)
    self:subscribe(numBtn, UIEvent.EventButtonClick, function()
        UILib.openCountUI(data.count, function(num, isInfinity)
            updateBasicEquipNum(self, index, num, isInfinity and true or nil)
        end, true)
    end)
    if index == 1 then
        selectCell(self, cell, item)
    end
    return cell
end

function M:addItem(index)
    local grid = self:child("Equip-Layout-Grid")
    local itemWnd = createItem(self, grid, index, equipData[index])
    grid:AddItem(itemWnd)
end

local function addBasicEquip(self, item, isBuff)
    local basicEquip = equipData
    local tb = {name = item:full_name(), count = 1, icon = item:icon(), type = item:type(), isBuff = isBuff}
    table.insert(basicEquip,1,tb)
    self:refreshEquip()
end

local function replaceBasicEquip(self, item, isBuff, index)
    local basicEquip = equipData
    local tb = {name = item:full_name(), count = 1, icon = item:icon(), type = item:type(), isBuff = isBuff}
    basicEquip[index] = tb
    self:refreshEquip()
end

function M:init()
    WinBase.init(self, "equip_edit2.json")

    self:child("Equip-Add-Txt"):SetText(Lang:toText("win.map.global.setting.player.tab.equip.add"))
    self:child("Equip-Layout-Title"):SetText(Lang:toText("win.map.global.setting.player.tab.equip.grid.title"))
    self:child("Equip-Layout-Die-Txt"):SetText(Lang:toText("win.map.global.setting.player.tab.equip.grid.die"))
    self:child("Equip-Show-Txt"):SetText(Lang:toText("win.map.global.setting.player.tab.equip.show.title"))
    self:child("Equip-Show-Btn-Txt"):SetText(Lang:toText("win.map.global.setting.player.tab.equip.show.btn"))
    local grid = self:child("Equip-Layout-Grid")
    self.introItemNameWnd = self:child("Equip-Show-Name")
    self.introItemNameWnd:SetProperty("Font", "HT14")
    grid:InitConfig(0, 8, 5)
    grid:SetAutoColumnCount(false)

    self:subscribe(self:child("Equip-Add"), UIEvent.EventButtonClick, function()
        UI:openMultiInstanceWnd("mapEditItemBagSelect", {backFunc = function(item, isBuff)
            addBasicEquip(self, item, isBuff)
        end})
    end)

    self:subscribe(self:child("Equip-Show-Btn"), UIEvent.EventButtonClick, function()
        UI:openMultiInstanceWnd("mapEditItemBagSelect", {backFunc = function(item, isBuff)
            if self.lastSelect then
                local index = self.lastSelect:data("index")
                replaceBasicEquip(self, item, isBuff, index)
            end
        end})
    end)

    self:subscribe(self:child("Equip-back"), UIEvent.EventButtonClick ,function()
        self:saveData()
        UI:closeWnd(self)
    end)


    self:root():SetLevel(11)
end

function M:saveData()
    if self.teamIndex then
        local teamData = globalSetting:getEditTeamMsg()
        teamData[self.teamIndex].basicEquip = equipData
        globalSetting:saveEditTeamMsg(teamData)
    else
        globalSetting:saveKey(dataMap[self.modName], equipData)
    end
end

function M:initData(params)
    local titleText
    if type(params) == "string" then
        self.teamIndex = nil
        local modName = params
        titleText = modName == "basic" and "win.map.global.setting.player.tab.resource.standard" or "win.map.global.setting.player.tab.resource.rich"
        equipData = Lib.copy(globalSetting:getValByKey(dataMap[modName]) or {})
        self.modName = modName
    else
        self.teamIndex = params.teamIndex
        titleText = "win.map.global.setting.player.tab.resource.standard"
        local teamData = globalSetting:getEditTeamMsg()
        equipData = teamData[self.teamIndex].basicEquip or {}
    end
    self:child("Equip-titleName"):SetText(Lang:toText(titleText))
end

function M:onOpen(params)
    self:initData(params)
    self:refreshEquip()
end

return M