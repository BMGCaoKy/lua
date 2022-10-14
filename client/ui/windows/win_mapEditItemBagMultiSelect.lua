local itemSetting = require "editor.setting.item_setting"
local loadTimers = {}
local isCanClick = true
local dragCell = nil
local multiSelectData = {}
local initUIFinish = {}
local selectedCell = {}
function M:init()
    WinBase.init(self, "bag_multi_select.json")
    self.btnSure = self:child("Bag-Multi-Select-Sure")
    self.btnCancel = self:child("Bag-Multi-Select-Cancel")
    self.btnSure:SetText(Lang:toText("global.sure"))
    self.btnCancel:SetText(Lang:toText("global.cancel"))
    self.bagGrid = self:child("Bag-Multi-Select-Grid")
    self:child("Bag-Multi-Select-Title"):SetText(Lang:toText("rule.setting.monster.range.select"))
    self.openType = 1
    self.bagTable = {}
    self:subscribe(self.btnCancel, UIEvent.EventButtonClick, function()
        UI:closeWnd(self)
    end)
    self:subscribe(self.btnSure, UIEvent.EventButtonClick, function()
        if self.backFunc then
            local data = {}
            for k,v in pairs(multiSelectData) do
                data[k] = v
            end
            self.backFunc(data)
            self.backFunc = nil
        end
        UI:closeWnd(self)
    end)
end

function M:setSureBackFunc(func)
    self.backFunc = func
end

local function closeLoadTimer()
    for _, timer in ipairs(loadTimers) do
        timer()
        timer = nil
    end
    loadTimers = {}
end

local function fetchCell()
    return UIMgr:new_widget("cell")
end

local function CreateItem(type, fullName, args)
    local item = EditorModule:createItem(type, fullName, args)
    local cfg = item:cfg()
    return item, cfg
end

local function showDropObjects(cell, dropobjects, size)
    if cell and dropobjects and dropobjects.fullName then
        local cfg = setting:fetch(dropobjects.type or "entity", dropobjects.fullName)
        local icon = ResLoader:loadImage(cfg, "small.png")
        if icon then
            if size then
                cell:receiver()._img_frame_sign:SetArea({0,10},{0,10},{0,20},{0,20})
            else
                cell:receiver()._img_frame_sign:SetArea({0,2},{0,2},{0,30},{0,30})
            end
            cell:receiver()._img_frame_sign:SetImage(icon)
        end
        cell:receiver()._img_frame_sign:SetVisible(true)
    elseif cell then
        cell:receiver()._img_frame_sign:SetVisible(false)
    end
end

local function selectCell(cell)
    local item = cell:data("item")
    if not item then
        return
    end
    local index = cell:data("index")
    selectedCell[index] = not selectedCell[index]
    local fullName = item:full_name()
    if selectedCell[index] then
        local name =  item.getNameText and item:getNameText() or item:cfg().itemname 
        multiSelectData[fullName] = { type = item:type(), icon = item:icon(), name = name, fullName = fullName }
        cell:receiver():onClick(true, "set:setting_global2.json image:icon_select_check2.png")
    else
        multiSelectData[fullName] = nil
        cell:receiver():onClick(false, "")
    end
end

local function initCell(self, cell, newSize, item, idx, cfg, dropobjects, isSubscribe, droopobjectsSize)
    local textHeight = 40
    cell:SetArea({ 0, 0 }, { 0, 0 }, { 0, newSize }, { 0, newSize + textHeight })
    cell:setData("index", idx)
    cell:receiver()._img_frame:SetImage("set:map_edit_bag.json image:itembox1_bag.png")
    cell:receiver()._img_frame:SetArea({0,0},{0,0},{1,0},{1,-textHeight})
    cell:receiver()._img_frame_select:SetArea({0,0},{0,0},{1,0},{1,-textHeight})
    cell:receiver()._img_frame_select:SetImage("")
    cell:receiver()._img_frame_select:SetVisible(true)
    cell:receiver()._img_frame_select:SetLevel(10)
    if not item then
        cell:receiver()._img_locked:SetVisible(true)
        cell:receiver()._img_locked:SetArea({0,0},{0,0},{1,0},{1,-textHeight})
        cell:receiver()._img_locked:SetImage("set:map_edit_bag.json image:itembox2_empty_bag.png")
        return
    end
    local fullName = item:full_name()
    cell:setData("item", item)
    cell:setData("dropobjects", dropobjects)
    cell:setData("cfg", cfg)
    cell:invoke("ITEM_SLOTER", item)
    cell:SetName("item:"..fullName)
    cell:receiver()._img_item:SetArea({0,0},{0,12},{1,-20},{1,-textHeight-20})
    cell:receiver()._img_item:SetVerticalAlignment(0)
    if multiSelectData[fullName] then
        selectCell(cell)
    end
    local nameText = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "Name-Text")
    local name =  item.getNameText and item:getNameText() or item:cfg().itemname
    nameText:SetArea({ 0, 0 }, { 0, newSize + 5 }, { 0, newSize }, { 0, 30 })
    nameText:SetTextVertAlign(0)
    nameText:SetTextHorzAlign(1)
    nameText:SetWordWrap(true)
    nameText:setTextAutolinefeed(Lang:toText(name),2)
    nameText:SetTextColor({ 100 / 255, 100 / 255, 108 / 255, 1 })
    nameText:SetProperty("Font", "HT12")
    cell:AddChildWindow(nameText)

    showDropObjects(cell, item.dropobjects and item:dropobjects(), droopobjectsSize)
    if not isSubscribe then
        self:subscribe(cell, UIEvent.EventWindowClick, function()
            if not isCanClick then
                return
            end
            selectCell(cell)
        end)
    end
end

local function fetchBlock(self, bagGrid, items)
    bagGrid:InitConfig(20, 20, 9)
    local newSize = 100
    items = items or Clientsetting.getSpecialList()
    local idx = 1
    local maxIdx = #items
    local function fetch()
        for _ = idx, maxIdx do
            local itemName = items[idx]
            local type
            local name = itemName
            local icon
            if itemName.name then
                name =  itemName.name
                type = itemName.type
                icon = itemName.icon
            end
            local item, cfg
            item, cfg = CreateItem(type or "block", name, {
                type = type or "block",
                icon = itemName.icon,
                descTipInfo = itemName.descTipInfo,
                nameTipInfo = itemName.nameTipInfo,
            })

            function item:dropobjects()
                return itemName and itemName.dropobjects
            end

            local cell = fetchCell()
            initCell(self, cell, newSize, item, idx, cfg)
            bagGrid:AddItem(cell)
            idx = idx + 1
            if idx > maxIdx and maxIdx % 4 ~= 0 then
                for i = idx % 4, 4 do
                    local cell = fetchCell()
                    initCell(self, cell, newSize, nil, idx, nil)
                    bagGrid:AddItem(cell)
                end
                return false
            end
            return true
        end
        return false
    end
    fetch()
    loadTimers[#loadTimers + 1] = World.Timer(1, fetch)
end

function M:onOpen(params)
    self:root():SetLevel(10)
end

function M:setMultiSelectData(typeName, data, backFunc)
    if not typeName then
        return
    end
    local items = Clientsetting.getData(typeName or "block")
    local itemsNotShow = { "myplugin/aa_door_down","myplugin/huoba" }
    for _,name in pairs(itemsNotShow) do
        for k,v in pairs(items) do
            if v == name then
                table.remove(items,k)
                break
            end
        end
    end
    multiSelectData = data or {}
    self.backFunc = backFunc
    if not initUIFinish[typeName] then
        fetchBlock(self, self.bagGrid, items)
        initUIFinish[typeName] = true
    else
        self:refreshCellState()
    end
end

function M:refreshCellState()
    for i = 0, self.bagGrid:GetItemCount() - 1 do
        local cell = self.bagGrid:GetItem(i)
        if cell then
            local item = cell:data("item")
            if item then
                local fullName = item:full_name()
                if multiSelectData[fullName] then
                    selectCell(cell)
                end
            end
        end
    end
end

function M:onClose()
    for index, selected in pairs(selectedCell) do
        if selected then
            local cell = self.bagGrid:GetItem(index-1)
            selectCell(cell)
        end
    end
    multiSelectData = {}
    selectedCell = {}
end

return M