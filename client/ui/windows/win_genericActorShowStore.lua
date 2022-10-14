-- 通用可以展示商品模型的商店，单击商店图标，触发trigger(购买/..)，长按展示actor，自动旋转，下边横排有只有有两个widght
-- 中间部分是可以左右滑动的 List，并且有一层标题选择
--[[
             _____________
            |      |title |
            | actor| desc |
 ___________|______|______|
|_________________________|    btnList
|   |    往左右滑动   |    |   
|___|________________|____|    uiList
]]
local IS_OPEN = false

local SHOW_UI_WIDGET_ENUM = {
    "widget_store_show",
    "widget_store_show_2",
    "widget_store_show_3",
    "widget_store_show_4"
}

local function fetchUiWidgetCell(self, uiFile)
	return UIMgr:new_widget("cell",uiFile .. ".json",uiFile)
end

local function fetchBtnCell(self)
	return UIMgr:new_widget("cell","widget_choice_type_btn.json","widget_choice_type_btn")
end

function M:init()
    WinBase.init(self, "GenericActorShowStore.json", true)
    self:initChild()
    self:initEvent()
end

function M:initChild()
    self.storeInfoBase = self:child("GenericActorShowStore-Info_Base")
    self.storeActorWin = self:child("GenericActorShowStore-Store_Model")
    self.storeImage = self:child("GenericActorShowStore-Store_Image")
    self.storeText = self:child("GenericActorShowStore-Store_Info_Text")
    self.storeDesc = self:child("GenericActorShowStore-Store_Info_Desc")
    
    self.storeTitleList = self:child("GenericActorShowStore-Title_List")

    self.leftWeight = self:child("GenericActorShowStore-Left_Weight")
    self.leftWeightImg = self:child("GenericActorShowStore-Left_Weight_Image")
    self.leftWeightText = self:child("GenericActorShowStore-Left_Weight_Text")
    self.rightWeight = self:child("GenericActorShowStore-Right_Weight")
    self.rightWeightImg = self:child("GenericActorShowStore-Right_Weight_Image")
    self.rightWeightText = self:child("GenericActorShowStore-Right_Weight_Text")

    self.storeList = self:child("GenericActorShowStore-Store_List")
    self.storeListXpos = self.storeList:GetXPosition()
    self.storeListWidth = self.storeList:GetPixelSize().x

    self.closeBtn = self:child("GenericActorShowStore-Close_Store_Btn")

    self.allEventTb = {
        close = {}, -- close = { eventKey = "", context = ""}
        left = {},
        right = {}
    }
    self.localContext = {}
end

function M:initEvent()
    self:subscribe(self.closeBtn, UIEvent.EventButtonClick, function()
        Lib.emitEvent(Event.EVENT_OPEN_GENERIC_ACTOR_SHOW_STORE, false)
        self:doGenericEvent(self.allEventTb.close)
    end)

    self:subscribe(self.leftWeight, UIEvent.EventWindowClick, function()
        self:doGenericEvent(self.allEventTb.left)
    end)

    self:subscribe(self.rightWeight, UIEvent.EventWindowClick, function()
        self:doGenericEvent(self.allEventTb.right)
    end)

    Lib.subscribeEvent(Event.EVENT_UPDATE_GENERIC_ACTOR_SHOW_STORE, function(infoTb)
        if IS_OPEN then
            self:onUpdate(infoTb)
        end
    end)

end

function M:doGenericEvent(eventTb)
    self.storeList:ResetScroll()
    if not eventTb or not eventTb.eventKey then
        return
    end
    local context = eventTb.context or {}
    for i,v in pairs(self.localContext) do
        context[i] = v
    end
    if eventTb.eventKey then
        Me:doCallBack(self.regUI, eventTb.eventKey, self.regId, context)
    end
end

--[[
infoTb = {
    regId = xx 
    regUI = xx
    btnInfo = {  -- 可选，显示在store上方的横向选择栏
        btnType = 1 2 3 4 -- 可选，选择使用的btn类型，默认1
        btnList = [ -- 可选
            [text = "", btnType = "可能存在一个界面的按钮风格要不同的", 
                curSelect = xx,  eventKey = xx, context = {} ],  curSelect 当前选中
            ..
        ]
    }
    listInfo = {  -- 可选 store选择栏
        uiType = 1 2 3 4 -- 可选，指定展示信息的使用UI文件，后续可扩展，默认第一种
        infoTb = [  -- 可选，传给指定窗口的信息
            {text = xxx, image = xxx, textColor = xxx, uiType = "可能存在一个界面的按钮风格要不同的",
                cfg = xxx, actorScale = xxx, coinImg = xx, eventKey = xx, context = {}}, 
                actorScale 当前商品的actor缩放度因为每个商品的碰撞盒大小不同，而显示的actor窗口固定大小，故需要这个控制大小
                coinImg 会存在同一列表的商品是由不同的货币购买的情况
            ..
        ]
    }
    eventInfo = { -- 可选 左边event，右边event，退出event
        closeEventInfo = {eventKey = xx ,, context = {}} -- 可选，退出时也可触发事件
        leftEventInfo = {image = xx, text = xx, eventKey = xx, context = {}} -- store列表中左侧组件事件
        rightEventInfo = {image = xx, text = xx, eventKey = xx, context = {}} -- store列表中右侧组件事件
    }
]]
-- uiType 3 btnType 2
function M:onOpen(infoTb)
    self:onUpdate(infoTb)
    IS_OPEN = true
end

function M:onUpdate(infoTb)
    infoTb = infoTb or {}
    self.infoTb = infoTb
    self.regId = infoTb.regId
    self.regUI = infoTb.regUI
    self:updateEvent(infoTb.eventInfo)
    self:updateTitle(infoTb.btnInfo)
    self:updateStoreList(infoTb.listInfo)
end

local function initIndex(arr, num)
    if (not num) or type(num) ~= "number" or (num <= 0 or num > #arr) then
        return 1
    end
    return num
end

local function fetchBtn(self, info)
    local cell = fetchBtnCell(self)

    local bg = cell:child("widget_choice_type_btn-bg_img_" .. (info.btnType or self.btnType))
    if bg then
        cell:child("widget_choice_type_btn-bg_img_" .. (info.btnType or self.btnType)):SetVisible(true)
    end
    local select = cell:child("widget_choice_type_btn-select_img_" .. (info.btnType or self.btnType))
    if select then
        cell:child("widget_choice_type_btn-select_img_" .. (info.btnType or self.btnType)):SetVisible(true)
    end

    cell:invoke("UPDATE_NEED_RESET_ITEM_SIZE",false)
    cell:invoke("RESET_OUTER_FRAME",info.curSelect or false)
    cell:invoke("LD_BOTTOM",Lang:toText(info.text or ""))
    if info.eventKey then
        self:subscribe(cell, UIEvent.EventWindowClick, function()
            local context = info.context or {}
            for i,v in pairs(self.localContext) do
                context[i] = v
            end
            Me:doCallBack(self.regUI, info.eventKey , self.regId, context)
        end)
    end
    return cell
end

function M:updateTitle(btnInfo)
    if not btnInfo then
        return
    end
    self.btnType = btnInfo.btnType or 1
    local storeTitleList = self.storeTitleList
    storeTitleList:ClearAllItem()
    for i,v in ipairs(btnInfo.btnList) do
        storeTitleList:AddItem(fetchBtn(self, v))
    end
end

local function fetchShow(self, info)
    -- text, image, textColor, cfg, eventKey, context, actorScale
    local uiFile = info.uiType and SHOW_UI_WIDGET_ENUM[info.uiType] or self.uiFile
    local cell = fetchUiWidgetCell(self, uiFile)
    cell:invoke("UPDATE_NEED_RESET_ITEM_SIZE",false)
    cell:invoke("SET_ICON_BY_PATH", info.image or "")
    cell:invoke("LD_BOTTOM",Lang:toText(info.text or ""))
    if info.textColor then 
        cell:invoke("LD_BOTTOM_COLOR",info.textColor)
    end
    local cellMoneyChild = cell:child(uiFile .. "-money_image")
    if cellMoneyChild then
        cellMoneyChild:SetImage(info.coinImg or "")
    end
    cell:setEnableLongTouch(true)
    if info.eventKey then
        self:subscribe(cell, UIEvent.EventWindowClick, function()
            local context = info.context or {}
            for i,v in pairs(self.localContext) do
                context[i] = v
            end
            Me:doCallBack(self.regUI, info.eventKey , self.regId, context)
        end)
    end
    self:subscribe(cell, UIEvent.EventWindowLongTouchStart, function()
        self:updateStoreInfo(true, info)
        self:subscribe(cell, UIEvent.EventWindowLongTouchEnd, function()
            self:updateStoreInfo(false)
        end)
        self:subscribe(cell, UIEvent.EventMotionRelease, function()
            self:updateStoreInfo(false)
        end)
    end)
    return cell
end

function M:updateStoreList(listInfo)
    if not listInfo then
        return
    end
    local storeList = self.storeList
    storeList:ClearAllItem()
    self.uiFile = SHOW_UI_WIDGET_ENUM[initIndex(SHOW_UI_WIDGET_ENUM, listInfo.uiType)]
    local infoTb = listInfo.infoTb or {}
    for i,v in ipairs(infoTb) do
        storeList:AddItem(fetchShow(self, v))
    end
    local lwx = self.leftWeight:GetPixelSize().x or 0
    storeList:SetXPosition({self.storeListXpos[1], 
        self.storeListXpos[2] + (self.leftWeight:IsVisible() and 0 or -lwx)})
    storeList:SetWidth({0, self.storeListWidth + (self.leftWeight:IsVisible() and 0 or lwx) * 2})
end

function M:updateStoreInfo(isShow, info)
    if not info then
        self.storeInfoBase:SetVisible(false)
        return
    end
    if not info.cfg then
        self.storeInfoBase:SetVisible(false)
        return
    end
    self.storeInfoBase:SetVisible(true)
    local cfg = Entity.GetCfg(info.cfg)
    local actor = cfg.actorName
    local showText = info.showName or cfg.showName
    local showDesc = info.showDesc or cfg.showDesc

    local actorWin = self.storeActorWin
    actorWin:UpdateSelf(1)
    actorWin:SetActor1(actor, "rotate")
    local showActorScale = cfg.showActorScale
    actorWin:SetActorScale(showActorScale or 0)
    if not showActorScale or showActorScale == 0 then
        self.storeImage:SetImage(info.image or "")
    end
    self.storeText:SetText(Lang:toText(showText or ""))
    self.storeDesc:SetText(Lang:toText(showDesc or ""))
end

function M:updateEvent(eventInfo)
    if not eventInfo then
        return
    end
    
    local closeTb = eventInfo.closeEventInfo
    local leftTb = eventInfo.leftEventInfo
    local rightTb = eventInfo.rightEventInfo

    local allEventTb = self.allEventTb
    if closeTb then
        allEventTb.close = closeTb
    end

    if leftTb then
        self.leftWeight:SetVisible(true)
        allEventTb.left = leftTb
        if leftTb.image then
            self.leftWeightImg:SetImage(leftTb.image)
        end
        self.leftWeightText:SetText(Lang:toText(leftTb.text or ""))
    else
        self.leftWeight:SetVisible(false)
    end

    if rightTb then
        self.rightWeight:SetVisible(true)
        allEventTb.right = rightTb
        if rightTb.image then
            self.rightWeightImg:SetImage(rightTb.image)
        end
        self.rightWeightText:SetText(Lang:toText(rightTb.text or ""))
    else
        self.rightWeight:SetVisible(false)
    end
end

function M:onClose()
    self.infoTb = {}
    self.localContext = {}
    self:updateStoreInfo(false)
    self:doGenericEvent(self.allEventTb.close)
    self.allEventTb = {
        close = {},
        left = {},
        right = {}
    }
    IS_OPEN = false
end