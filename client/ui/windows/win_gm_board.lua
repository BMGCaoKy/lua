--local setting = require "common.setting"

local pageSize = 9
local gridRowSize = 6
local totalPages = 1
local currentPage = 1
local currentArr
--local pluginFunc
local pack
local item_pool = {}

local function createGridNormalCell(item)
    local cell = GUIWindowManager.instance:CreateGUIWindow1("Layout", "GridCell")
    if item.key ~= "/" then
        cell:SetBackgroundColor({ 0, 1, 1, 0.15 })
    end
    cell:SetArea({ 0, 0 }, { 0, 0 }, { 0, 150 }, { 0, 40 })
    local nameLb = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "GridCell-Name")
    nameLb:SetArea({ 0, 0 }, { 0, 0 }, { 1, 0 }, { 1, 0 })
    nameLb:SetTextHorzAlign(1)
    nameLb:SetTextVertAlign(1)
    nameLb:SetText(item.name)
    cell:AddChildWindow(nameLb)
    return cell
end

local function loadImage(cfg, image)
    if type(image) ~= "string" then
        return nil
    end
    if image and (image:find("set:") or image:find("http:") or image:find("https:")) then
        return image
    end
    local path = ResLoader:filePathJoint(cfg, image)
    return path
end

local function createPluginCell(item, func)
    local cell = GUIWindowManager.instance:CreateGUIWindow1("Layout", "PluginCell")
    cell:SetBackgroundColor({ 0, 1, 1, 0.15 })
    cell:SetArea({ 0, 0 }, { 0, 0 }, { 0, 800 }, { 0, 40 })
    local nameLb = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "PluginCell-Name")
    nameLb:SetArea({ 0, 20 }, { 0, 0 }, { 0, 300 }, { 1, 0 })
    nameLb:SetTextHorzAlign(0)
    nameLb:SetTextVertAlign(1)
    nameLb:SetHorizontalAlignment(0)
    nameLb:SetText(item.name)
    cell:AddChildWindow(nameLb)
    local imageV = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "PluginCell-Image")
    imageV:SetArea({ 0, 370 }, { 0, 0 }, { 0, 40 }, { 0, 40 })
    if item.typ == "item" then
        local item = Item.CreateItem(item.name, 1)
        local cfg = item:cfg()
        imageV:SetImage(loadImage(cfg, cfg.icon))
    end
    if item.typ == "block" then
        local block = Item.CreateItem("/block", 1, function(block)
            block:set_block(item.name)
        end)
        imageV:SetImage(block:icon())
    end
    cell:AddChildWindow(imageV)
    local editV = GUIWindowManager.instance:CreateGUIWindow1("Edit", "PluginCell-Edit")
    editV:SetArea({ 0, 460 }, { 0, 0 }, { 0, 150 }, { 1, 0 })
    editV:SetBackgroundColor({ 1, 0, 0, 0.15 })
    editV:SetMaxLength(50)
    editV:SetTextHorzAlign(1)
    editV:SetTextVertAlign(1)
    editV:SetText(item.default)
    cell:AddChildWindow(editV)
    local btn = GUIWindowManager.instance:CreateGUIWindow1("Button", "PluginCell-Btn")
    btn:SetArea({ 0, -20 }, { 0, 0 }, { 0, 40 }, { 0, 40 })
    btn:SetBackgroundColor({ 0.9, 0.9, 0.9, 1 })
    btn:SetVerticalAlignment(1)
    btn:SetHorizontalAlignment(2)
    btn:SetText("OK")
    btn:SetTextColor({ 0.2, 0.2, 0.2, 1 })
    M:subscribe(btn, UIEvent.EventButtonClick, function()
        func(editV:GetPropertyString("Text", ""))
    end)
    cell:AddChildWindow(btn)
    return cell
end

local function createListCell(name)
    local cell = GUIWindowManager.instance:CreateGUIWindow1("Layout", "ListCell")
    cell:SetArea({ 0, 0 }, { 0, 0 }, { 0, 100 }, { 0, 40 })
    cell:SetBackgroundColor({ 0, 1, 1, 0.15 })
    local selectedImgV = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "ListCell-SelectedImage")
    selectedImgV:SetImage("set:shortcut_bar.json image:shortcut_slot_selected")
    selectedImgV:SetArea({ 0, 0 }, { 0, 0 }, { 1, 0 }, { 1, 0 })
    selectedImgV:SetProperty("StretchType", "NineGrid")
    selectedImgV:SetProperty("StretchOffset", "5 5 5 5")
    selectedImgV:SetVisible(false)
    cell:AddChildWindow(selectedImgV)
    local nameLb = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "ListCell-Name")
    nameLb:SetArea({ 0, 0 }, { 0, 0 }, { 1, -20 }, { 1, 0 })
    nameLb:SetTextHorzAlign(1)
    nameLb:SetTextVertAlign(1)
    nameLb:SetHorizontalAlignment(1)
    nameLb:SetText(name)
    cell:AddChildWindow(nameLb)
    return cell
end

local function setPluginViewVisible(self, visible)
    self.searchBar:SetVisible(visible)
    self.pageContentV:SetVisible(visible)
    self.pluginListView:SetVisible(visible)
    self.gridView:SetVisible(not visible)
end

local function fillPluginListView(self, list)
    setPluginViewVisible(self, true)
    self.pluginListView:ClearAllItem()
    for _, v in pairs(list or {}) do
        local cell = createPluginCell(v, function(value)
            v.value = value
            GM.listCallBack(Me, v)
        end)
        self.pluginListView:AddItem(cell)
    end
end

local function showInputBox(self, show)
    self.inputBox:SetVisible(show)
end

local function paging(self)
    totalPages = math.ceil(#currentArr / pageSize)
    if totalPages == 0 then
        totalPages = 1
    end
    local startIdx = (currentPage - 1) * pageSize + 1
    local endIdx = currentPage * pageSize
    if endIdx > #currentArr then
        endIdx = #currentArr
    end
    local temp = {}
    for i = startIdx, endIdx do
        temp[#temp + 1] = currentArr[i]
    end
    fillPluginListView(self, temp)
    self.pageLb:SetText(currentPage .. "/" .. totalPages)
    self.lastPageBtn:SetVisible(currentPage ~= 1)
    self.nextPageBtn:SetVisible(currentPage ~= totalPages)
end

local function resetData(self, arr)
    currentArr = arr
    currentPage = 1
    paging(self)
end

local oldList = {}
local function filter(self, key)
    if not key or key == "" then
        return
    end
    if not next(oldList) then
        oldList = currentArr
    end
    local newList = {}
    for _, v in pairs(oldList) do
        if string.find(v.name, key) then
            table.insert(newList, v)
        end
    end
    resetData(self, newList)
end

local function clearFilter(self)
    if not next(oldList) then
        return
    end
    resetData(self, oldList)
    self.searchKey:SetText("")
    oldList = {}
end

local function fillGridView(self, item)
    setPluginViewVisible(self, false)
    self.gridView:InitConfig(10, 10, gridRowSize)
    self.gridView:RemoveAllItems()
    local count = 0
    for _, v in pairs(item.list or {}) do
        if v.key == "/" then
            for i = 1, gridRowSize - count do
                local cell = createGridNormalCell(v)
                self.gridView:AddItem(cell)
                count = count + 1
            end
        else
            local cell = createGridNormalCell(v)
            self:subscribe(cell, UIEvent.EventWindowClick, function()
                GM.click(Me, v.key)
            end)
            self.gridView:AddItem(cell)
            count = count + 1
        end
        count = count < gridRowSize and count or 0
    end
end

local function setChildViewVisible(view, visible)
    local imgV = view:GetChildByIndex(1)
    imgV:SetVisible(visible)
end

local function sortListView()
    local list = {}
    local typItems = {}
    local lastTyp = nil

    for _, gmlist in ipairs({ GM.ServerList or {}, GM.BTSGMList or {}, GM.GMList or {} }) do
        for _, value in ipairs(gmlist) do
            local typ, name = table.unpack(Lib.splitString(value, "/"))
            if not name then
                name = typ
                typ = lastTyp
            elseif typ == "" then
                typ = lastTyp
            else
                lastTyp = typ
            end
            local item = { name = name, key = value,
                           showPriority = GM.itemShowPriorityMap[typ] and GM.itemShowPriorityMap[typ][name] or 0 }
            local items = typItems[typ]
            if not items then
                items = {}
                typItems[typ] = items
                table.insert(list, { typ = typ, list = items, showPriority = GM.itemsShowPriorityMap[typ] or 0 })
            end
            table.insert(items, item)
        end
    end

    local showPriority = 999
    for _, item in pairs(list) do
        if item.showPriority == 0 then
            item.showPriority = showPriority
            showPriority = showPriority - 1
        end
    end

    table.sort(list, function(a, b)
        return a.showPriority > b.showPriority
    end)

    for _, v in ipairs(list) do
        showPriority = 999
        for _, item in pairs(v.list) do
            if item.showPriority == 0 then
                item.showPriority = showPriority
                showPriority = showPriority - 1
            end
        end
        table.sort(v.list, function(a, b)
            return a.showPriority > b.showPriority
        end)
    end

    return list
end

local function fillListView(self, list)
    fillGridView(self, list[1])
    self.listView:ClearAllItem()
    item_pool = {}
    for k, v in pairs(list or {}) do
        local cell = createListCell(v.typ)
        table.insert(item_pool, cell)
        self.listView:AddItem(cell)
        self:subscribe(cell, UIEvent.EventWindowClick, function()
            fillGridView(self, v)
            for _, v in pairs(item_pool) do
                setChildViewVisible(v, false)
            end
            setChildViewVisible(cell, true)
        end)
        if k == 1 then
            setChildViewVisible(cell, true)
        end
    end
end

function M:init()
    WinBase.init(self, "GMBoard.json", true)
    self:root():SetLevel(1)
    self.listView = self:child("GMBoard-List")
    self.listView:SetInterval(15)
    self.pluginListView = self:child("GMBoard-PluginList")
    self.pluginListView:SetInterval(15)
    self.gridView = self:child("GMBoard-Grid")
    self.gridView:SetAutoColumnCount(false)
    self.pageContentV = self:child("GMBoard-PageContent")
    self.lastPageBtn = self:child("GMBoard-Last")
    self.nextPageBtn = self:child("GMBoard-Next")
    self.searchBar = self:child("GMBoard-SearchBar")
    self.searchBtn = self:child("GMBoard-SearchBar-Search")
    self.clearBtn = self:child("GMBoard-SearchBar-Clear")
    self.pageLb = self:child("GMBoard-Page")
    self.searchKey = self:child("GMBoard-SearchBar-Key")
    self.inputBox = self:child("GMBoard-Input")
    self.editV = self:child("GMBoard-Input-Edit")
    self.confirmBtn = self:child("GMBoard-Input-Confirm")
    self.inputCloseBtn = self:child("GMBoard-Input-Close")
    self:subscribe(self:child("GMBoard-Close"), UIEvent.EventButtonClick, function()
        UI:closeWnd("gm_board")
    end)
    self:subscribe(self.lastPageBtn, UIEvent.EventButtonClick, function()
        currentPage = currentPage - 1
        paging(self)
    end)
    self:subscribe(self.nextPageBtn, UIEvent.EventButtonClick, function()
        currentPage = currentPage + 1
        paging(self)
    end)
    self:subscribe(self.searchKey, UIEvent.EventWindowTextChanged, function()
        filter(self, self.searchKey:GetPropertyString("Text", ""))
    end)
    self:subscribe(self.clearBtn, UIEvent.EventButtonClick, function()
        clearFilter(self)
    end)
    self:subscribe(self.confirmBtn, UIEvent.EventButtonClick, function()
        showInputBox(self, false)
        pack.value = self.editV:GetPropertyString("Text", "")
        GM.inputBoxCallBack(Me, pack)
    end)
    self:subscribe(self.inputCloseBtn, UIEvent.EventButtonClick, function()
        showInputBox(self, false)
        --local value = self.editV:SetText("")
    end)

    Lib.subscribeEvent(Event.EVENT_SHOW_GM_LIST, function()
        local list = sortListView()
        fillListView(self, list)
    end)

    Lib.subscribeEvent(Event.EVENT_SHOW_GM_INPUTBOX, function(packet)
        self.editV:SetText(packet.value)
        pack = packet
        showInputBox(self, true)
    end)

    Lib.subscribeEvent(Event.EVENT_SHOW_GM_PLUGIN, function(packet)
        pack = packet
        self.searchKey:SetText("")
        currentArr = pack.list
        currentPage = 1
        paging(self)
    end)
end

function M:onOpen()
    local list = sortListView()
    fillListView(self, list)
end

return M