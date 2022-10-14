-- 通用列表框，一般需要一个外层框
--[[ 
 _________________________
|                         |
|        往上下滑动        |
|        select Tab       |
|_________________________|
|         唯一btn         |  -- 点上面，这里btn显示对应信息
|_________________________|
]]
local IS_OPEN = false

local ICON_BUTTON_ENUM = {
    "widget_rectangle_icon_btn"
}

local SHOW_UI_WIDGET_ENUM = {
    "widget_store_show",
    "widget_store_show_2",
    "widget_store_show_3",
    "widget_store_show_4"
}

local function fetchBtnCell(self)
	return UIMgr:new_widget("cell",self.btnFile .. ".json",self.btnFile)
end

local function fetchUiWidgetCell(self, uiFile)
	return UIMgr:new_widget("cell",uiFile .. ".json",uiFile)
end

function M:init()
    WinBase.init(self, "GenericListDisplayBox3.json", true)
    self:initChild()
end

function M:initChild()
    self.childGv = self:child("GenericListDisplayBox3-Child_Gv")
    self.btnLayout = self:child("GenericListDisplayBox3-Btn_Layout")

    self.localContext = {}
end

--[[
infoTb = {
    regId = xx
    regUI = xx
    area = {{},{},{},{}} -- 可选
    listInfo = { -- 可选
        uiType = 1/2/3/4/..    -- 可选，指定展示信息的使用UI文件，后续可扩展，默认第一种
        showGvSpec = xxx -- gv怎么切分几块 默认3
        infoTb = [  -- 可选，传给指定窗口的信息
            {text = xxx, btnShowText = "", btnType = "可能存在一个界面的按钮风格要不同的", 
                image = xxx, , eventKey = xx, coinImg = xx, context = {}}, 
                btnShowText 点击后展示在btn的text
                coinImg 点击之后 不同的购买货币 显示不同的货币图标
            ..
        ]
    }
    btnInfo = {  -- 可选
        btnType = 1 2 3 4 -- 可选，选择使用的btn类型
        btnText = xx -- 显示在btn的text
        coinImg = xx -- btn中展示的小图标
    }
]]
function M:onOpen(infoTb)
    IS_OPEN = true
    infoTb = infoTb or {}
    self.infoTb = infoTb
    self.regId = infoTb.regId
    self.regUI = infoTb.regUI
    self:updateBtn(infoTb.btnInfo)
    self:updateList(infoTb.listInfo)
end

local function fetchShow(self, info, first)
    local cell = fetchUiWidgetCell(self, info.btnType and SHOW_UI_WIDGET_ENUM[info.uiType] or self.uiFile)
    cell:invoke("UPDATE_NEED_RESET_ITEM_SIZE",false)
    cell:invoke("RESET_OUTER_FRAME",false)
    cell:invoke("SET_ICON_BY_PATH", info.image or "")
    cell:invoke("LD_BOTTOM",Lang:toText(info.text or ""))
    local function cellClick()
        if self.curSelectCell then
            self.curSelectCell:invoke("RESET_OUTER_FRAME",false)
        end
        cell:invoke("RESET_OUTER_FRAME",true)
        self.curSelectCell = cell

        self.localContext = {}
        for i,v in pairs(info.context or {}) do
            self.localContext[i] = v
        end
        local buttomBtn = self.buttomBtn
        if buttomBtn then
            buttomBtn:invoke("CS_BOTTOM",Lang:toText(info.btnShowText or ""))
            buttomBtn:invoke("SET_ICON_BY_PATH", info.coinImg or "")
        end
    end
    self:subscribe(cell, UIEvent.EventWindowClick, function()
        cellClick()
    end)
    if first then
        cellClick()
    end
    return cell
end

local function initIndex(arr, num)
    if (not num) or type(num) ~= "number" or (num <= 0 or num > #arr) then
        return 1
    end
    return num
end

function M:updateList(listInfo)
    if not listInfo then
        return
    end
    self.childGv:RemoveAllItems()
    self.curSelectCell = nil
    self.childGv:InitConfig(1, 1, listInfo.showGvSpec or 3)
    self.uiFile = SHOW_UI_WIDGET_ENUM[initIndex(SHOW_UI_WIDGET_ENUM, listInfo.uiType)]
    local infoTb = listInfo.infoTb or {}
    for i,v in ipairs(infoTb) do
        self.childGv:AddItem(fetchShow(self, v, i == 1))
    end
end

local function fetchBtn(self, btnInfo)
    local cell = fetchBtnCell(self)
    cell:invoke("UPDATE_NEED_RESET_ITEM_SIZE",false)
    cell:invoke("RESET_OUTER_FRAME",false)
    cell:invoke("LD_BOTTOM",Lang:toText(btnInfo.btnText or ""))

    if btnInfo.eventKey then
        self:subscribe(cell, UIEvent.EventWindowClick, function()
            Me:doRemoteCallback(self.regUI, btnInfo.eventKey , self.regId, self.localContext)
        end)
    end
    return cell
end

function M:updateBtn(btnInfo)
    if not btnInfo then
        return
    end
    self.btnFile = ICON_BUTTON_ENUM[initIndex(ICON_BUTTON_ENUM, btnInfo.btnType)]
    local btnLayout = self.btnLayout
    self.buttomBtn = fetchBtn(self, btnInfo)
    local btn = self.buttomBtn
    btn:SetXPosition({0, 0})
    btn:SetYPosition({0, 0})
    btnLayout:AddChildWindow(btn)
    btnLayout:SetArea({ 0, 0 }, { 0, 0 }, 
        { 0, btn:GetPixelSize().x }, { 0, btn:GetPixelSize().y })
end

function M:onClose()
    IS_OPEN = false
    self.infoTb = {}
    self.localContext = {}
end