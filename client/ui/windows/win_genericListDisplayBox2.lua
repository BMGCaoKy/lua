-- 通用选择ui，点击右侧的选择栏的小图标，左侧会显示对应的选择的图片，可单独做一个界面也可嵌入其他外框
-- Title 点击可以更改标题内容，并触发需要的event
--[[
 ____________________________
|          title             |
|____________________________|
|              |             |
|              |             |
|    showImg   |  choiceTab  |
|              |             |
|______________|_____________|
|____________btns____________|
]]
local IS_OPEN = false

local BUTTON_ENUM = {
    "widget_rectangle_btn",
    "widget_rectangle_btn_2",
    "widget_rectangle_btn_3"
}

local SELECT_CELL_ENUM = {
    "widget_select"
}

local function fetchSelectCell(self)
	return UIMgr:new_widget("cell",self.selectUiFile .. ".json",self.selectUiFile)
end

local function fetchBtnCell(self, btnFile)
	return UIMgr:new_widget("cell",btnFile .. ".json",btnFile)
end

function M:init()
    WinBase.init(self, "GenericListDisplayBox2.json", true)
    self:initProp()
end

function M:initProp()
    self.baseImage = self:child("GenericListDisplayBox2-Base_Image")

    self.titleBase = self:child("GenericListDisplayBox2-Title_Base")
    self.titleImage = self:child("GenericListDisplayBox2-Title_Image")
    self.titleText = self:child("GenericListDisplayBox2-Title_Text")
    self.titleEdit = self:child("GenericListDisplayBox2-Title_Edit")
    
    self.selectImage = self:child("GenericListDisplayBox2-Select_Image")
    self:initOperatorSelect()

    self.btnLayout = self:child("GenericListDisplayBox2-Btn_Layout")

    self.localContext = {}
end

function M:initOperatorSelect()
    self.operatorBase = self:child("GenericListDisplayBox2-Operator_Base")
    self.operatorBaseImage = self:child("GenericListDisplayBox2-Operator_Base_Image")
    self.operatorTopText = self:child("GenericListDisplayBox2-Operator_Top_Text")
    self.selectGv = self:child("GenericListDisplayBox2-Select_Gv")
    self.operatorButtomText = self:child("GenericListDisplayBox2-Operator_Buttom_Text")
end
--[[
infoTb = {
    regId = xx
    regUI = xx
    area = {{},{},{},{}} -- 可选
    upperLayerKey = "" -- 上层选择的key -- 可选
    titleTb = {image = "可选", text = "可选", eventKey = xx, context = {xx}} -- 可选
    selectInfo = { -- 可选
        selectTitleText = "可选"
        selectButtomText = "可选"
        selectUiType = 1 2 3 4 可选 ，选择的ui类型
        selectGvSpec = xx -- 可选，选择的gv怎么切分几块，默认是4
        selectGvInfo = [ -- 可选
            {
                rightImg = "右侧小图片",
                leftImg = "点击右侧小图片后左侧展示的大图片",
                key = "key(用于记录当前选择key)",
                curSelect = true -- 当前选择
            },{},{}..]
    }
    btnInfo = {  -- 可选
        btnType = 1 2 3 4 -- 可选，选择使用的btn类型
        btnList = [ -- 可选
            [text = "", btnType = "可能存在一个界面的按钮风格要不同的", 
                , eventKey = xx, context = {} ,curSelect = xx],
            ..
        ]
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
    self:updateSelectGv(infoTb.selectInfo)
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
            Me:doRemoteCallback(self.regUI, titleTb.eventKey , self.regId, context)
        end)
    end
end

local function initIndex(arr, num)
    if (not num) or type(num) ~= "number" or (num <= 0 or num > #arr) then
        return 1
    end
    return num
end

local function cellOnSelect(self, cell, leftImage, key)
    if self.curSelectCell then
        self.curSelectCell:invoke("RESET_OUTER_FRAME",false)
    end
    cell:invoke("RESET_OUTER_FRAME",true)
    self.selectImage:SetImage(leftImage)
    self.curSelectCell = cell
    self.localContext.curSelectKey = key
end

function M:updateSelectGv(selectInfo)
    if not selectInfo then
        return
    end
    self.operatorTopText:SetText(Lang:toText(selectInfo.selectTitleText or ""))
    self.operatorButtomText:SetText(Lang:toText(selectInfo.selectButtomText or ""))
    local selectGvInfo = selectInfo.selectGvInfo or {}
    if #selectGvInfo <= 0 then
        return
    end

    self.selectUiFile = SELECT_CELL_ENUM[initIndex(SELECT_CELL_ENUM, selectInfo.selectUiType)]

    local selectGv = self.selectGv
    selectGv:RemoveAllItems()
    self.curSelectCell = nil
    selectGv:InitConfig(1, 1, selectInfo.selectGvSpec or 4)

	for i, info in ipairs(selectGvInfo) do
        local cell = fetchSelectCell(self)
        cell:invoke("UPDATE_NEED_RESET_ITEM_SIZE",false)
        cell:invoke("RESET_OUTER_FRAME",false)
        cell:invoke("SET_ICON_BY_PATH", info.rightImg)
        if info.curSelect then
            cellOnSelect(self, cell, info.leftImg, info.key)
            self.localContext.oldSelectKey = info.key
        end
        self:subscribe(cell, UIEvent.EventWindowClick, function()
            cellOnSelect(self, cell, info.leftImg, info.key)
        end)
		self.selectGv:AddItem(cell)
	end
end

local function fetchBtn(self, info)
    local cell = fetchBtnCell(self, info.btnType and BUTTON_ENUM[info.btnType] or self.btnFile)
    cell:invoke("UPDATE_NEED_RESET_ITEM_SIZE",false)
    cell:invoke("RESET_OUTER_FRAME",info.curSelect or false)
    cell:invoke("LD_BOTTOM",Lang:toText(info.text or ""))
    if info.eventKey then
        self:subscribe(cell, UIEvent.EventWindowClick, function()
            local context = info.context or {}
            for i,v in pairs(self.localContext) do
                context[i] = v
            end
            Me:doRemoteCallback(self.regUI, info.eventKey , self.regId, context)
        end)
    end
    return cell
end

function M:updateBtn(btnInfo)
    if not btnInfo then
        return
    end
    self.btnFile = BUTTON_ENUM[initIndex(BUTTON_ENUM, btnInfo.btnType)]
    local btnLayout = self.btnLayout
    local bl = btnInfo.btnList or {}
    local width = 0
    for i,v in ipairs(bl) do
        local btn = fetchBtn(self, v)
        btn:SetXPosition({0, width})
        width = width + btn:GetPixelSize().x
        btnLayout:AddChildWindow(btn)
    end
    btnLayout:SetArea({ 0, 0 }, { 0, 0 }, { 0, width }, { 0,  btnLayout:GetPixelSize().y})
end

function M:onClose()
    IS_OPEN = false
    self.infoTb = {}
    self.localContext = {}
end