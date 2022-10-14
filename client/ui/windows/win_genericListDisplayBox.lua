-- 通用外框，选择左侧按钮栏，右侧展示对应的信息
--[[
 __________________________
|         title            |
|   _______________________|
|tab|                      |
|tab|                      |
|tab| childWin OR image    |
| ..|                      |
|___|______________________|
]]
local IS_OPEN = false

local BUTTON_ENUM = {
    "widget_rectangle_btn",
    "widget_rectangle_btn_2",
    "widget_rectangle_btn_3"
}

local function fetchBtnCell(self, btnFile)
	return UIMgr:new_widget("cell",btnFile .. ".json", btnFile)
end

function M:init()
    WinBase.init(self, "GenericListDisplayBox.json", true)
    self:initChild()
    self:initEvent()
end

function M:initChild()
    self.baseImage = self:child("GenericListDisplayBox-Base_Image")

    self.titleImage = self:child("GenericListDisplayBox-Title_Image")
    self.titleText = self:child("GenericListDisplayBox-Title_Text")

    self.closeBtn = self:child("GenericListDisplayBox-Close_Btn")

    self.childBase = self:child("GenericListDisplayBox-Child_Base")
    self.childBaseImage = self:child("GenericListDisplayBox-Child_Base_Image")
    self.rightChild = self:child("GenericListDisplayBox-Right_Child")
    self.rightChildImage = self:child("GenericListDisplayBox-Right_Child_Image")
    self.leftList = self:child("GenericListDisplayBox-Left_Child")

    self.localContext = {}
end

local function openRight(self, infoTb)
    if infoTb and infoTb.uiWin then
        self.childUiWin = UI:openWnd(infoTb.uiWin, infoTb.childInfoTb)._root
        self.rightChild:AddChildWindow(self.childUiWin) -- 重新加载窗口
    end
    if infoTb and infoTb.image then
        self.rightChildImage:SetImage(infoTb.image)
    end
end

function M:initEvent()
    self:subscribe(self.closeBtn, UIEvent.EventButtonClick, function()
        Lib.emitEvent(Event.EVENT_OPEN_GENERIC_LIST_DISPLAY_BOX, false)
    end)

    Lib.subscribeEvent(Event.EVENT_OPEN_GENERIC_LIST_DISPLAY_BOX_CHILD, function(infoTb)
        if IS_OPEN then
            if self.childUiWin then
                self.rightChild:RemoveChildWindow1(self.childUiWin) -- 清除右侧窗口
            end
            openRight(self, infoTb)
        end
	end)
end

--[[
infoTb = {
    regId = xx
    regUI = xx
    area = {{},{},{},{}} -- 可选
    titleTb = {image = "可选", text = "可选", eventKey = ""} -- 可选
    btnInfo = {
        btnType = 1 2 3 4 -- 可选，选择使用的btn类型
        btnList = { -- 可选 -- 每点击一个就去服务端脚本里面获取点击之后展示的东西
            [text = "", btnType = "可能存在一个界面的按钮风格要不同的"
                , eventKey = xx, context = {}, curSelect = xx, isEquip = xx], isEquip - 目前装备中，curSelect 当前选中
            ..
        }
    }
    child相关：
    uiWin = "xxx（比如genericListDisplayBox）"
    childInfoTb = {key = "", xxxx..., regUI = xx, regId = xx}, 
    image = ""
    -- childInfoTb 传给子UI文件的信息， key 是上层传给下层的选择的key， 
    -- image使用这个则是只是在右侧展示image
]]
function M:onOpen(infoTb)
    self:onUpdate(infoTb)
end

function M:onUpdate(infoTb)
    IS_OPEN = true
    infoTb = infoTb or {}
    self.infoTb = infoTb
    self.regId = infoTb.regId
    self.regUI = infoTb.regUI
    self:updateTitle(infoTb.titleTb)
    self:updateTab(infoTb.btnInfo)
end

function M:updateTitle(titleTb)
    if not titleTb then
        return
    end
    if titleTb.image then
        self.titleImage:SetImage(titleTb.image)
    end
    self.titleText:SetText(Lang:toText(titleTb.text or ""))
    if titleTb.eventKey then
        self:subscribe(self.titleImage, UIEvent.EventWindowClick, function()
            Me:doRemoteCallback(self.regUI, titleTb.eventKey , self.regId, self.localContext)
        end)
    end
end

local function fetchTab(self, info)
    local cell = fetchBtnCell(self, info.btnType and BUTTON_ENUM[info.btnType] or self.btnFile)
    cell:invoke("UPDATE_NEED_RESET_ITEM_SIZE",false)
    cell:invoke("RESET_OUTER_FRAME",info.curSelect or false)
    cell:invoke("LD_BOTTOM",Lang:toText(info.text or ""))
    cell:invoke("SHOW_MASKING",info.isEquip or false)
    local function cellClick()
        if self.curSelectCell then
            self.curSelectCell:invoke("RESET_OUTER_FRAME",false)
        end
        cell:invoke("RESET_OUTER_FRAME",true)
        self.curSelectCell = cell

        local context = info.context or {}
        for i,v in pairs(self.localContext) do
            context[i] = v
        end
        if info.eventKey then
            Me:doRemoteCallback(self.regUI, info.eventKey , self.regId, context)
        end
    end
    self:subscribe(cell, UIEvent.EventWindowClick, function()
        cellClick()
    end)
    if info.curSelect then
        World.Timer(1, function()
            cellClick()
        end)
    end
    return cell
end

local function initIndex(arr, num)
    if (not num) or type(num) ~= "number" or (num <= 0 or num > #arr) then
        return 1
    end
    return num
end

function M:updateTab(btnInfo)
    if not btnInfo then
        return
    end
    self.btnFile = BUTTON_ENUM[initIndex(BUTTON_ENUM, btnInfo.btnType)]
    self.leftList:ClearAllItem()
    self.curSelectCell = nil
    for i,v in ipairs(btnInfo.btnList or {}) do
        self.leftList:AddItem(fetchTab(self, v))
    end
end

function M:onClose()
    IS_OPEN = false
    self.infoTb = {}
    self.localContext = {}
    if self.childUiWin then
        self.rightChild:RemoveChildWindow1(self.childUiWin) -- 清除右侧窗口
    end
end