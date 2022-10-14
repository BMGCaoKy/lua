local setting = require "common.setting"
local currentPage = 1
local itemWidth = 200
local itemHeight = 200
local itemImgWidth = 200
local itemImgHeight = 200
local currentArr
local uiCfg = {}
local data

local function createGridCell(self, item)
    local cell = GUIWindowManager.instance:CreateGUIWindow1("Layout", "GridCell")
    cell:SetArea({0, 0}, {0, 0}, {0, itemWidth}, {0, itemHeight})
    if uiCfg.itemBgImage then
        local bgImage = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "BgImage")
        bgImage:SetArea({0, 0}, {0, 0}, {1, 0}, {1, 0})
        bgImage:SetImage(uiCfg.itemBgImage.name or uiCfg.itemBgImage)
        bgImage:SetProperty("StretchType", uiCfg.itemBgImage.stretchType or "None")
        bgImage:SetProperty("StretchOffset", uiCfg.itemBgImage.stretchOffset or "0 0 0 0")
        cell:AddChildWindow(bgImage)
    end
    if item.title then
        local titleLb = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "GridCell-Title")
        titleLb:SetArea({0, 0}, {0, 10}, {1, -20}, {0, 40})
        titleLb:SetTextHorzAlign(1)
        titleLb:SetTextVertAlign(0)
        titleLb:SetHorizontalAlignment(1)
        titleLb:SetText(Lang:toText(item.title or ""))
        cell:AddChildWindow(titleLb)
    end
    local y = item.title and 50 or 0
    if item.image then
        if item.qualityImage then
            local qualityImage = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "BgImage2")
            qualityImage:SetArea({0, 0}, {0, y}, {0, itemImgWidth}, {0, itemImgHeight})
            qualityImage:SetImage(item.qualityImage.name or item.qualityImage)
            qualityImage:SetProperty("StretchType", item.qualityImage.stretchType or "None")
            qualityImage:SetProperty("StretchOffset", item.qualityImage.stretchOffset or "0 0 0 0 ")
            qualityImage:SetHorizontalAlignment(1)
            cell:AddChildWindow(qualityImage)
        end
        if item.pushImage and not item.eventBtn then
            local btn = GUIWindowManager.instance:CreateGUIWindow1("Button", "GridCell-Image")
            btn:SetArea({0, 0}, {0, y}, {0, itemImgWidth}, {0, itemImgHeight})
            btn:SetPushedImage(item.pushImage)
            btn:SetNormalImage(item.image)
            btn:SetHorizontalAlignment(1)
            cell:AddChildWindow(btn)
            self:subscribe(btn, UIEvent.EventButtonClick, function()
                Me:doCallBack(data.callBackModName, item.event, data.regId)
                UI:closeWnd(self)
            end)
        else
            local imageV = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "GridCell-Image")
            imageV:SetArea({0, 0}, {0, y}, {0, itemImgWidth}, {0, itemImgHeight})
            imageV:SetImage(item.image)
            imageV:SetHorizontalAlignment(1)
            cell:AddChildWindow(imageV)
        end
        y = y + itemImgHeight
    end
    if item.detail then
        local detailLb = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "GridCell-Detail")
        detailLb:SetArea({0, 0}, {0, -10}, {1, -20}, {0, itemHeight - y - 20})
        detailLb:SetTextHorzAlign(1)
        detailLb:SetTextVertAlign(0)
        detailLb:SetHorizontalAlignment(1)
        detailLb:SetVerticalAlignment(2)
        detailLb:SetText(Lang:toText(item.detail))
        detailLb:SetProperty("TextWordWrap", "true")
        cell:AddChildWindow(detailLb)
    end
    if item.eventBtn then
        local eventBtn = item.eventBtn
        local btn = GUIWindowManager.instance:CreateGUIWindow1("Button", "GridCell-Button")
        btn:SetHorizontalAlignment(1)
        btn:SetVerticalAlignment(2)
        btn:SetArea(table.unpack(eventBtn.area or {{0, 0}, {0, -10}, {1, 120}, {0, 50}}))
        btn:SetNormalImage(eventBtn.image.name or eventBtn.image)
        btn:SetPushedImage(eventBtn.image.name or eventBtn.image)
        btn:SetProperty("StretchType", eventBtn.image.stretchType or "None")
        btn:SetProperty("StretchOffset", eventBtn.image.stretchOffset or "0 0 0 0 ")
        cell:AddChildWindow(btn)
        self:subscribe(btn, UIEvent.EventButtonClick, function()
            Me:doCallBack(data.callBackModName, item.event, data.regId)
            UI:closeWnd(self)
        end)
        local titleLb = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "GridCell-Button-Text")
        titleLb:SetArea({0, 0}, {0, 0}, {1, 0}, {1, 0})
        titleLb:SetTextHorzAlign(1)
        titleLb:SetTextVertAlign(1)
        titleLb:SetText(Lang:toText(eventBtn.title or ""))
        titleLb:SetFontSize(eventBtn.titleFontSize or "HT18")
        btn:AddChildWindow(titleLb)
    end
    return cell
end

local function fillGridView(self, list)
    self.grid:RemoveAllItems()
    self.grid:SetAutoColumnCount(false)
    local itemSpace = uiCfg.itemSpace or 20
    self.grid:InitConfig(itemSpace, itemSpace, #list)
    for _, v in pairs(list or {}) do
        local cell = createGridCell(self, v)
        self.grid:AddItem(cell)
        if not v.eventBtn and not v.pushImage then
            self:subscribe(cell, UIEvent.EventWindowClick, function()
                Me:doCallBack(data.callBackModName, v.event, data.regId)
                UI:closeWnd(self)
            end)
        end
    end
end

local function paging(self)
    local pageSize = uiCfg.pageSize or 2
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
    WinBase.init(self, "CardOptionsView.json", true)
    self.mask = self:child("CardOptionsView-Mask")

    self.card = self:child("CardOptionsView-Card")
    self.closeBtn = self:child("CardOptionsView-Close")
    self.lastBtn = self:child("CardOptionsView-Last")
    self.nextBtn = self:child("CardOptionsView-Next")
    self.titleBg = self:child("CardOptionsView-Title-Bg")
    self.title = self:child("CardOptionsView-Title-Text")
    self.detail = self:child("CardOptionsView-Detail")
    self.gridContent = self:child("CardOptionsView-GridContent")
    self.grid = self:child("CardOptionsView-Grid")
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

function M:onOpen(packet)
    data = packet
    currentArr = data.options or {}
    self.title:SetText(Lang:toText(data.title or ""))
    self.detail:SetText(Lang:toText(data.detail or ""))
    if not data.title and not data.detail then
        self.gridContent:SetVerticalAlignment(1)
        self.gridContent:SetYPosition({0, 0})
    end
    uiCfg = setting:fetch("ui_config", data.uiCfg)
    self.closeBtn:SetVisible(uiCfg.showClose)
    self.mask:SetVisible(uiCfg.showMask)
    if uiCfg.titleFontSize then
        self.title:SetFontSize(uiCfg.titleFontSize)
    end
    if uiCfg.titleBorder then
        self.title:SetTextBoader(uiCfg.titleBorder)
    end
    if uiCfg.titleArea then
        self.titleBg:SetArea(table.unpack(uiCfg.titleArea))
    end
    if uiCfg.titleBgImage then
        self.titleBg:SetImage(uiCfg.titleBgImage.name or uiCfg.titleBgImage)
        self.titleBg:SetProperty("StretchType", uiCfg.titleBgImage.stretchType or "None")
        self.titleBg:SetProperty("StretchOffset", uiCfg.titleBgImage.stretchOffset or "0 0 0 0 ")
    end
    if uiCfg.detailFontSize then
        self.detail:SetFontSize(uiCfg.detailFontSize)
    end
    if uiCfg.detailArea then
        self.detail:SetArea(table.unpack(uiCfg.detailArea))
    end
    if uiCfg.contentArea then
        self.card:SetArea(table.unpack(uiCfg.contentArea))
    end
    if uiCfg.itemSize then
        itemWidth = uiCfg.itemSize[1]
        itemHeight = uiCfg.itemSize[2]
    end
    if uiCfg.itemImageSize then
        local imageSize = uiCfg.itemImageSize
        itemImgWidth = imageSize[1]
        itemImgHeight = imageSize[2]
    end
    if uiCfg.itemSpace then
        itemSpace = uiCfg.itemSpace
    end
    self.gridContent:SetHeight({0, itemHeight})
    if uiCfg.bgImage then
        self.card:SetImage(uiCfg.bgImage.name or uiCfg.bgImage)
        self.card:SetProperty("StretchType", uiCfg.bgImage.stretchType or "None")
        self.card:SetProperty("StretchOffset", uiCfg.bgImage.stretchOffset or "0 0 0 0 ")
    end
    if uiCfg.closeBtnImage then
        self.closeBtn:SetNormalImage(uiCfg.closeBtnImage)
        self.closeBtn:SetPushedImage(uiCfg.closeBtnImage)
    end
    if uiCfg.closeBtnArea then
        self.closeBtn:SetArea(table.unpack(uiCfg.closeBtnArea))
    end
    if uiCfg.lastBtnImage then
        self.lastBtn:SetNormalImage(uiCfg.lastBtnImage)
        self.lastBtn:SetPushedImage(uiCfg.lastBtnImage)
    end
    if uiCfg.lastBtnArea then
        self.lastBtn:SetArea(table.unpack(uiCfg.lastBtnArea))
    end
    if uiCfg.nextBtnImage then
        self.nextBtn:SetPushedImage(uiCfg.nextBtnImage)
        self.nextBtn:SetPushedImage(uiCfg.nextBtnImage)
    end
    if uiCfg.nextBtnArea then
        self.nextBtn:SetArea(table.unpack(uiCfg.nextBtnArea))
    end
    paging(self)
end

return M