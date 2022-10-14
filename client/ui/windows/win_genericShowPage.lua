-- 通用展示页面
-- 支持修改title的值并触发事件
--[[ GenericShowPage
 ____________________________
|          title             |
|____________________________|
|              |             |
|              |             |
|    showImg   |  text1      |
|              |    text2    |
|______________|_____________|
|____________btns____________|
]]
local IS_OPEN = false

local BUTTON_ENUM = {
    "widget_rectangle_btn",
    "widget_rectangle_btn_2",
    "widget_rectangle_btn_3"
}

local function fetchBtnCell(self, btnFile)
	return UIMgr:new_widget("cell",btnFile .. ".json",btnFile)
end

local TEXT_WEIGHT_ENUM = {
    "widget_text_show"
}

local function fetchTextCell(self)
	return UIMgr:new_widget("cell",self.textFile .. ".json",self.textFile)
end

function M:init()
    WinBase.init(self, "GenericShowPage.json", true)
    self:initProp()
end

function M:initProp()
    self.baseImage = self:child("GenericShowPage-Base_Image")

    self.titleBase = self:child("GenericShowPage-Title_Base")
    self.titleImage = self:child("GenericShowPage-Title_Image")
    self.titleText = self:child("GenericShowPage-Title_Text")
    self.titleEdit = self:child("GenericShowPage-Title_Edit")

    self.showImage = self:child("GenericShowPage-Show_Image")

    self.showTextList = self:child("GenericShowPage-Show_Text_List")

    self.btnList = self:child("GenericShowPage-Btn_Gv")

    self.localContext = {}
end

--[[
infoTb = {
    regId = xx
    regUI = xx
    upperLayerKey = "" -- 上层选择的key
    titleTb = {image = "可选", text = "可选", eventKey = xx, context = {}} -- 可选
    showImage = ""  -- 可选
    showTextTb = {  -- 可选
        textWeightType = 1 2 3 4 -- 可选,注：通过1234选类型
        textWeightList = [  -- 可选
            {keyText = "", valueText = ""}
            ..
        ]
    }
    btnInfo = {  -- 可选
        btnType = 1 2 3 4 -- 可选，选择使用的btn类型
        btnList = [ -- 可选
            [text = "", btnType = "可能存在一个界面的按钮风格要不同的"
                , eventKey = xx, context = {}],
            ..
        ]
    }
}
]]
function M:onOpen(infoTb) 
    IS_OPEN = true
    infoTb = infoTb or {}
    self.infoTb = infoTb
    self.regId = infoTb.regId
    self.regUI = infoTb.regUI
    self.localContext.upperLayerKey = infoTb.upperLayerKey
    self:updateTitle(infoTb.titleTb)
    self:updateShowInfo(infoTb.showImage, infoTb.showTextTb)
    self:updateBtn(infoTb.btnInfo)
end

function M:updateTitle(titleTb)
    if not titleTb then
        return
    end
    if titleTb.image then
        self.titleImage:SetImage(titleTb.image)
    end
    self.titleText:SetText((Lang:toText(titleTb.text or "")))
    if titleTb.eventKey then
        self:subscribe(self.titleEdit, UIEvent.EventEditTextInput, function()
            local titleEditText = self.titleEdit:GetPropertyString("Text","")
            self.titleEdit:SetProperty("Text","")
            if titleEditText == "" or titleEditText == titleTb.text then
                return
            end
            self.titleText:SetText(titleEditText)
            local context = titleTb.context or {}
            for i,v in pairs(self.localContext) do
                context[i] = v
            end
            context.titleEditText = titleEditText
            Me:doCallBack(self.regUI, titleTb.eventKey, self.regId, context)
        end)
    end
end

local function fetchTextWeight(self, keyText, valueText)
    local cell = fetchTextCell(self)
    cell:invoke("UPDATE_NEED_RESET_ITEM_SIZE",false)
    cell:invoke("LD_BOTTOM",Lang:toText(keyText or ""))
    cell:invoke("CS_BOTTOM",Lang:toText(valueText or ""))

    return cell
end

local function initIndex(arr, num)
    if (not num) or type(num) ~= "number" or (num <= 0 or num > #arr) then
        return 1
    end
    return num
end

function M:updateShowInfo(showImage, showTextTb)
    self.showImage:SetImage(showImage or "")
    if not showTextTb then
        return
    end
    self.textFile = TEXT_WEIGHT_ENUM[initIndex(TEXT_WEIGHT_ENUM, showTextTb.textWeightType)]
    self.showTextList:ClearAllItem()
    for i,v in ipairs(showTextTb.textWeightList or {}) do
        self.showTextList:AddItem(fetchTextWeight(self, v.keyText or "", v.valueText or ""))
    end
end

local function fetchBtn(self, info)
    local cell = fetchBtnCell(self, info.btnType and BUTTON_ENUM[info.btnType] or self.btnFile)
    cell:invoke("UPDATE_NEED_RESET_ITEM_SIZE",false)
    cell:invoke("RESET_OUTER_FRAME",false)
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

function M:updateBtn(btnInfo)
    if not btnInfo then
        return
    end
    self.btnFile = BUTTON_ENUM[initIndex(BUTTON_ENUM, btnInfo.btnType)]
    local btnl = self.btnList
    local bl = btnInfo.btnList or {}
    btnl:RemoveAllItems()
    local width = 0
    for i,v in ipairs(bl) do
        local btn = fetchBtn(self, v)
        width = width + btn:GetPixelSize().x
        btnl:AddItem(btn)
    end
    btnl:SetArea({ 0, 0 }, { 0, 0 }, { 0, width }, { 0,  btnl:GetPixelSize().y})
end

function M:onClose()
    IS_OPEN = false
    self.infoTb = {}
    self.localContext = {}
end