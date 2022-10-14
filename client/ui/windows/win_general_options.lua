
local selectedIndex = 1
local floorCells
local itemHeight = 64
local listHeight = 448
local callBackModName
local regId
local challengeTower
local dungeon
local teamsInfo
local rightSideChildWindows = {}

local currentPage = 1
local pageSize
local currentArr

local function createFloorCell(item, selected)
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
    text:SetFontSize(item.textFont or "HT24")
    text:SetText(Lang:toText(item.name))
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
    local index = (currentPage - 1) * pageSize + selectedIndex
    local item = currentArr[index]
    Me:doCallBack(callBackModName, item.event, regId, {item = item})
end

local function fillListView(self, list)
    self.list:ClearAllItem()
    floorCells = {}
    for k, v in ipairs(list or {}) do
        local cell = createFloorCell(v)
        table.insert(floorCells, cell)
        self.list:AddItem(cell)
        self:subscribe(cell, UIEvent.EventWindowClick, function()
            if k ~= selectedIndex then
                selectedIndex = k
                optionClick(self)
            end
        end)
    end
    optionClick(self)
end

local function paging(self)
    local totalPages = math.ceil(#currentArr / pageSize)
    if totalPages == 0 then
        totalPages = 1
    end
    local startIdx = (currentPage - 1) * pageSize + 1
    local endIdx = currentPage * pageSize
    if endIdx > #currentArr then
        endIdx = #currentArr
    end
    local temp = {}
    for k, v in pairs(currentArr) do
        if k >= startIdx and k <= endIdx then
            temp[#temp + 1] = currentArr[k]
        end
    end
    fillListView(self, temp)
    self.upBtn:SetVisible(currentPage ~= 1 and totalPages > 1)
    self.downBtn:SetVisible(currentPage ~= totalPages)
end

function M:init()
    WinBase.init(self, "GeneralOptions.json", true)
    self.title = self:child("GeneralOptions-Title")
    self.left = self:child("GeneralOptions-Left")
    self.right = self:child("GeneralOptions-Right")
    self.list = self:child("GeneralOptions-List")
    self.list:SetMoveAble(false)
    self.upBtn = self:child("GeneralOptions-Up")
    self.downBtn = self:child("GeneralOptions-Down")
    self.closeBtn = self:child("GeneralOptions-Close")

    self:subscribe(self.closeBtn, UIEvent.EventButtonClick, function()
        UI:closeWnd("general_options")
    end)

    self:subscribe(self.upBtn, UIEvent.EventButtonClick, function()
        selectedIndex = 1
        currentPage = currentPage - 1
        paging(self)
    end)

    self:subscribe(self.downBtn, UIEvent.EventButtonClick, function()
        selectedIndex = 1
        currentPage = currentPage + 1
        paging(self)
    end)

    Lib.subscribeEvent(Event.EVENT_CLOSE_RELATED_WND, function()
        UI:closeWnd("general_options")
    end)

    Lib.subscribeEvent(Event.EVENT_GENERALOPTIONS_RIGHTSIDE, function(packet)
        local winName = packet.winName
        local area = packet.area or {{0, 0}, {0, 0}, {1, 0}, {1, 0}}
        local hAlign = packet.hAlign or 0
        local vAlign = packet.vAlign or 0
        winName = string.gsub(winName, "win_", "", 1)
        local win = rightSideChildWindows[winName]
        if not win then
            win = UI:getWnd(winName)
            view = win._root
            view:SetArea(table.unpack(area))
            view:SetHorizontalAlignment(hAlign)
            view:SetVerticalAlignment(vAlign)
            rightSideChildWindows[winName] = win
        end
        win._root:SetVisible(true)
        self.right:AddChildWindow(win._root)
        win:setData(packet)
    end)
end

function M:onOpen(packet)
    selectedIndex = 1
    local control = UI:getWnd("actionControl", true)
    if control and control.onDragTouchUp then
        control:onDragTouchUp()
    end
end

function M:onClose()
    for _, win in pairs(rightSideChildWindows) do
        local view = win._root
        view:SetVisible(false)
        self.right:RemoveChildWindow1(view)
    end
end

function M:fillData(packet)
    callBackModName = packet.callBackModName
    regId = packet.regId
    pageSize = packet.pageSize or 7
    currentArr = packet.options or {}
    local index = packet.selectedIndex or 1
    currentPage = math.ceil(index/pageSize)
    selectedIndex = index - (currentPage - 1) * pageSize
    self.title:SetText(Lang:toText(packet.title))
    self.list:SetHeight({0, itemHeight * pageSize})
    local leftWidth = packet.leftSideWidth
    if leftWidth and leftWidth > 0 then
        self.left:SetWidth({0, leftWidth})
        self.right:SetWidth({1, (-50-leftWidth)})
    end 
    paging(self)
end

return M