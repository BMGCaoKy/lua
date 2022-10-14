
local selectedIndex
local floorCells
local itemHeight = 64
local listHeight = 448
local super
local arr

local function createFloorCell(name, selected)
    local cell = GUIWindowManager.instance:CreateGUIWindow1("Layout", "FloorCell")
    cell:SetArea({0, 0}, {0, 0}, {1, 0}, {0, itemHeight})
    local bg = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "FloorCell-Bg")
    bg:SetArea({0, 0}, {0, 0}, {1, 0}, {1, -3})
    bg:SetImage("set:challenge_tower.json image:floors_selected.png")
    bg:SetProperty("StretchType", "LeftRight")
    bg:SetProperty("StretchOffset", "20 60 0 0")
    cell:AddChildWindow(bg)
    bg:SetVisible(selected)
    local text = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "FloorLevel")
    text:SetArea({0, 0}, {0, 0}, {1, 0}, {1, 0})
    text:SetTextColor(selected and {1, 1, 1, 1} or {255/255, 233/255, 186/255})
    text:SetTextBoader({111/255, 55/255, 36/255})
    text:SetFontSize("HT24")
    text:SetText(name)
    text:SetTextHorzAlign(1)
    text:SetTextVertAlign(1)
    cell:AddChildWindow(text)
    local line = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "FloorCell-Line")
    line:SetArea({0, 8}, {0, 0}, {1, -18}, {0, 3})
    line:SetImage("set:challenge_tower.json image:floor_line.png")
    line:SetProperty("StretchType", "LeftRight")
    line:SetProperty("StretchOffset", "5 5 0 0")
    line:SetVerticalAlignment(2)
    cell:AddChildWindow(line)
    return cell
end

local function refreshFloorCells(self)
    for index, cell in ipairs(floorCells) do
        local bg = cell:GetChildByIndex(2)
        bg:SetVisible(index == selectedIndex)
        local text = cell:GetChildByIndex(1)
        text:SetTextColor(index == selectedIndex and {1, 1, 1, 1} or {255/255, 233/255, 186/255})
    end
end

local function optionClick(self)
    refreshFloorCells(self)
    if super and super.optionClick and arr then
        super:optionClick(arr[selectedIndex] and arr[selectedIndex].info)
    end
end

local function updateList(self, offset)
    local curOffset = self.list:GetScrollOffset()
    curOffset = curOffset + offset
    local maxOffset = listHeight - (arr and #arr or 0) * itemHeight
    curOffset = curOffset < maxOffset and maxOffset or curOffset
    curOffset = curOffset > 0 and 0 or curOffset
    self.list:SetScrollOffset(curOffset)
    self.upBtn:SetVisible(curOffset < 0)
    self.downBtn:SetVisible(curOffset > maxOffset)

    local update = false
    local selectedOffset = (selectedIndex - 1) * itemHeight * (-1)
    if selectedOffset > curOffset then
        selectedIndex = (-1) * curOffset / itemHeight + 1
        update = true
    end
    local maxVisiOffset = curOffset - listHeight + itemHeight
    if selectedOffset < maxVisiOffset then
        selectedIndex = (-1) * maxVisiOffset / itemHeight + 1
        update = true
    end
    selectedIndex = selectedIndex > #arr and #arr or selectedIndex
    selectedIndex = math.floor(selectedIndex)
    if update then
        optionClick(self)
        refreshFloorCells(self)
    end
end

local function fillList(self)
    self.list:ClearAllItem()
    floorCells = {}
    for k, v in ipairs(arr or {}) do
        local cell = createFloorCell(v.name)
        table.insert(floorCells, cell)
        self.list:AddItem(cell)
        self:subscribe(cell, UIEvent.EventWindowClick, function()
            selectedIndex = k
            optionClick(self)
            refreshFloorCells(self)
        end)
    end
    updateList(self, 0)
    optionClick(self)
end

function M:init()
    WinBase.init(self, "CustomList.json", true)
    self.list = self:child("CustomList-List")
    self.list:SetMoveAble(false)
    self.upBtn = self:child("CustomList-Up")
    self.downBtn = self:child("CustomList-Down")
    self:subscribe(self.upBtn, UIEvent.EventButtonClick, function()
        updateList(self, itemHeight)
    end)

    self:subscribe(self.downBtn, UIEvent.EventButtonClick, function()
        updateList(self, itemHeight * (-1))
    end)
end

function M:fillList(packet)
    super = packet.super
    arr = packet.arr
    selectedIndex = packet.defaulIndex or 1
    listHeight = (packet.showLines or 7) * itemHeight
    self.list:SetHeight({0, listHeight})
    fillList(self)
end

return M