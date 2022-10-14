local setting = require "common.setting"

local currentPage = 1
local itemWidth = 494
local itemHeight = 625
local itemImgWidth = 425
local itemImgHeight = 340
local currentArr
local guide

local function createGridCell(item)
    local cell = GUIWindowManager.instance:CreateGUIWindow1("Layout", "GridCell")
    cell:SetArea({0, 0}, {0, 0}, {0, itemWidth}, {0, itemHeight})
    local itemBgImage = guide.itemBgImage or "set:newbie_guide.json image:guidebottom"
    local path = ResLoader:loadImage(guide, itemBgImage.name or itemBgImage)
    local bgImage = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "BgImage")
    bgImage:SetArea({0, 0}, {0, 0}, {1, 0}, {1, 0})
    bgImage:SetImage(path)
    bgImage:SetProperty("StretchType", itemBgImage.stretchType or "NineGrid")
    bgImage:SetProperty("StretchOffset", itemBgImage.stretchOffset or "16 16 16 16")
    cell:AddChildWindow(bgImage)
    if item.title then
        local titleLb = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "GridCell-Title")
        local border = guide.itemTitleBorder or {0, 0, 0, 1}
        titleLb:SetTextBoader(border)
        titleLb:SetArea({0, 0}, {0, 10}, {1, -20}, {0, 40})
        titleLb:SetTextHorzAlign(1)
        titleLb:SetTextVertAlign(0)
        titleLb:SetHorizontalAlignment(1)
        titleLb:SetText(Lang:toText(item.title or ""))
        cell:AddChildWindow(titleLb)
    end
    local y = item.title and 50 or 0
    if item.image then
        local qualityImage = guide.qualityImage or "set:newbie_guide.json image:showimage"
        local stretchOffset = qualityImage.stretchOffset or "10 10 10 10"
        local path1 = ResLoader:loadImage(guide, qualityImage.name or qualityImage)
        local bgImage = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "BgImage1")
        bgImage:SetArea({0, 0}, {0, y}, {0, itemImgWidth}, {0, itemImgHeight})
        bgImage:SetImage(path1)
        bgImage:SetProperty("StretchType", qualityImage.stretchType or "NineGrid")
        bgImage:SetProperty("StretchOffset", stretchOffset)
        bgImage:SetHorizontalAlignment(1)
        cell:AddChildWindow(bgImage)

        local arr = Lib.splitString(stretchOffset, " ")
        local lr = tonumber(arr[1] or "0") + tonumber(arr[2] or "0")
        local tb = tonumber(arr[3] or "0") + tonumber(arr[4] or "0")
        local path2 = ResLoader:loadImage(guide, item.image)
        local imageV = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "GridCell-Image")
        imageV:SetArea({0, 0}, {0, 0}, {0, itemImgWidth - lr}, {0, itemImgHeight - tb})
        imageV:SetImage(path2)
        imageV:SetHorizontalAlignment(1)
        imageV:SetVerticalAlignment(1)
        bgImage:AddChildWindow(imageV)
        y = y + itemImgHeight
    end
    if item.content then
        local detailLb = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "GridCell-Detail")
        detailLb:SetArea({0, 0}, {0, -10}, {1, -20}, {0, itemHeight - y - 20})
        detailLb:SetTextHorzAlign(1)
        detailLb:SetTextVertAlign(0)
        detailLb:SetHorizontalAlignment(1)
        detailLb:SetVerticalAlignment(2)
        detailLb:SetText(Lang:toText(item.content))
        detailLb:SetProperty("TextWordWrap", "true")
        cell:AddChildWindow(detailLb)
    end
    return cell
end

local function fillGridView(self, list)
    local itemOffset = guide.itemOffset or 0
    self.grid:RemoveAllItems()
    self.grid:SetAutoColumnCount(false)
    self.grid:InitConfig(itemOffset, itemOffset, #list)
    for step, v in pairs(list or {}) do
        local cell = createGridCell(v)
        self.grid:AddItem(cell)
        if v.event then
            self:subscribe(cell, UIEvent.EventWindowClick, function()
                Me:sendPacket({pid = "GameExplainEvent", fullName = guide.fullName, step = step})
            end)
        end
    end
end

local function paging(self)
    local pageSize = guide.pageSize or 2
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
    fillGridView(self, temp)
    self.lastBtn:SetVisible(currentPage ~= 1 and totalPages > 1)
    self.nextBtn:SetVisible(currentPage ~= totalPages)
end

function M:init()
    WinBase.init(self, "GameExplain.json", true)
    self.mask = self:child("GameExplain-Mask")

    self.card = self:child("GameExplain-Content")
    self.closeBtn = self:child("GameExplain-Close")
    self.lastBtn = self:child("GameExplain-Last")
    self.nextBtn = self:child("GameExplain-Next")
    self.title = self:child("GameExplain-Title")
    self.detail = self:child("GameExplain-Detail")
    self.gridContent = self:child("GameExplain-GridContent")
    self.grid = self:child("GameExplain-Grid")
    self.grid:SetMoveAble(false)

    self:subscribe(self.closeBtn, UIEvent.EventButtonClick, function()
        UI:closeWnd(self)
    end)
    self:subscribe(self.lastBtn, UIEvent.EventButtonClick, function()
        currentPage = currentPage - 1
        paging(self)
    end)
    self:subscribe(self.nextBtn, UIEvent.EventButtonClick, function()
        currentPage = currentPage + 1
        paging(self)
    end)
end

function M:onOpen(fullName)
    guide = setting:fetch("explain", fullName) or {}
    currentArr = guide.explain
    self.mask:SetVisible(guide.showMask or false)
    self.title:SetText(Lang:toText(guide.title or ""))
    self.detail:SetText(Lang:toText(guide.detail or ""))
    if not guide.title and not guide.detail then
        self.gridContent:SetVerticalAlignment(1)
        self.gridContent:SetYPosition({0, 0})
    end
    if guide.contentArea then
        self.card:SetArea(table.unpack(guide.contentArea))
    end
    if guide.itemSize then
        itemWidth = guide.itemSize[1]
        itemHeight = guide.itemSize[2]
    end
    if guide.itemImageSize then
        local imageSize = guide.itemImageSize
        itemImgWidth = imageSize[1]
        itemImgHeight = imageSize[2]
    end
    self.gridContent:SetHeight({0, itemHeight})
    if guide.bgImage then
        local path = ResLoader:loadImage(guide, guide.bgImage.name or guide.bgImage)
        self.card:SetImage(path)
        self.card:SetProperty("StretchType", guide.bgImage.stretchType or "None")
        self.card:SetProperty("StretchOffset", guide.bgImage.stretchOffset or "0 0 0 0 ")
    end
    if guide.closeBtnImage then
        self.closeBtn:SetNormalImage(guide.closeBtnImage)
        self.closeBtn:SetPushedImage(guide.closeBtnImage)
    end
    if guide.lastBtnImage then
        self.lastBtn:SetNormalImage(guide.lastBtnImage)
        self.lastBtn:SetPushedImage(guide.lastBtnImage)
    end
    if guide.nextBtnImage then
        self.nextBtn:SetPushedImage(guide.nextBtnImage)
        self.nextBtn:SetPushedImage(guide.nextBtnImage)
    end
    paging(self)
end

function M:onClose()
    if World.cfg.continueWhenOpen and World.cfg.continueWhenOpen["gameExplain"] and World.CurWorld:isGamePause() == true then 
        Lib.emitEvent(Event.EVENT_PAUSE_BY_CLIENT)
    end
end

return M