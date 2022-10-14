-- 页面上边横排显示栏，可根据参数按钮多少动态显示长度
--[[ 
     ___________________________
    |          长按钮栏          | 可根据按钮多少大小改变大小
    |___________________________|
    |                           |
    |                           |
    |                           |
    |                           |
    |                           |
    |___________________________|
]]
M.NotDialogWnd = true
local IS_OPEN = false

local function fetchBtnCell(self)
	return UIMgr:new_widget("cell","widget_choice_type_btn.json","widget_choice_type_btn")
end

function M:init()
    WinBase.init(self, "TitleBarPage.json", true)
    self:initChild()
    self:initEvent()
end

local function cleanupAllEvent(self)
    for i,close in pairs(self.eventList) do
        close()
    end
    self.eventList = {}
end

function M:initChild()
    self.childBase = self:child("TitleBarPage-Base")
    self.childBase:SetVisible(true)
    self.baseImage = self:child("TitleBarPage-Base_Image")
    self.btnLayout = self:child("TitleBarPage-Btn_Layout")

    self.localContext = {}
    self.eventList = {}
end

function M:initEvent()
    Lib.subscribeEvent(Event.EVENT_UPDATE_TITLE_BAR_PAGE, function(infoTb)
        if IS_OPEN then
            self:onUpdate(infoTb)
        end
	end)
end
--[[
infoTb = {
    regId = xx
    regUI = xx
    btnBaseImage = ""  -- 可选
    btnInfo = {  -- 可选
        btnType = 1 2 3 4 -- 可选，选择使用的btn类型
        btnList = [ -- 可选
            [text = "", btnType = "可能存在一个界面的按钮风格要不同的", curSelect = xx,
                , eventKey = xx, context = {}],
            ..
        ]
    }
}
]]
function M:onOpen(infoTb)
    IS_OPEN = true
    self:onUpdate(infoTb)
end

function M:onUpdate(infoTb)
    cleanupAllEvent(self)
    infoTb = infoTb or {}
    self.infoTb = infoTb
    self.regId = infoTb.regId
    self.regUI = infoTb.regUI
    if infoTb.btnBaseImage then
        self.baseImage:SetImage(infoTb.btnBaseImage)
    end
    self:updateBtn(infoTb.btnInfo)
end

local function fetchBtn(self, info)
    local cell = fetchBtnCell(self)
    if not self.btnCellSize then
        self.btnCellWidth = cell:GetPixelSize()
    end

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
        self.eventList[#self.eventList + 1] = self:subscribe(cell, UIEvent.EventWindowClick, function()
            if self.curSelectCell then
                self.curSelectCell:invoke("RESET_OUTER_FRAME",false)
            end
            cell:invoke("RESET_OUTER_FRAME",true)
            self.curSelectCell = cell

            local context = {}
            for i,v in pairs(info.context or {}) do
                context[i] = v
            end
            for i,v in pairs(self.localContext) do
                context[i] = v
            end
            Me:doCallBack(self.regUI, info.eventKey, self.regId, context)

            SoundSystem.instance:playEffectByType(0)
        end)
    end
	cell:SetName("widget_choice_type_btn_" .. (info.btnType or 1))
    return cell
end

function M:updateBtn(btnInfo)
    if not btnInfo then
        return
    end
    self.btnType = btnInfo.btnType or 1
    local btnLayout = self.btnLayout
    btnLayout:CleanupChildren()
    self.curSelectCell = nil
    local bl = btnInfo.btnList or {}
    if #bl <= 0 then
        return
    end
    local width = 10
    for i,v in ipairs(bl) do
        local btn = fetchBtn(self, v)
        btn:SetXPosition({0, width})
        width = width + btn:GetPixelSize().x
        btnLayout:AddChildWindow(btn)
    end
    self.childBase:SetArea({0,0},{0,50},{0, #bl * (self.btnCellWidth.x + 10)}, {0, self.btnCellWidth.y + 10})
end

function M:onClose()
    -- cleanupAllEvent(self)
    IS_OPEN = false
    self.infoTb = {}
    self.localContext = {}
end