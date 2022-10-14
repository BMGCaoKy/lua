local globalSetting = require "editor.setting.global_setting"
local editWndOpenText = ""
function M:init()
    WinBase.init(self, "numpad_edit.json")
    self.editText = ""
    self.closeBtn = self:child("Numpad-Close")
    self.numpad = self:child("Numpad-Bg")
    for i = 0, 9 do
        self:subscribe(self:child("Numpad-Key-" .. i ), UIEvent.EventButtonClick, function()
            local dotPos = string.find(self.editText, "%.")
            local length = Lib.getStringLen(self.editText)
            if dotPos and dotPos <=  length - 2 or length >= 6 then
                return
            end
            if self.editWnd and self.editSlider then
                self.editText = self.editText .. i
                self.editWnd:SetText( self.editText )
                self:setEditWndEffect(false,false)
            end
        end)
    end
    self:subscribe(self:child("Numpad-Key-dot"), UIEvent.EventButtonClick, function()
        if string.find(self.editText, "%.") then
            return
        end
        if self.editWnd then
            self.editText = self.editText .. "."
            self.editWnd:SetText(self.editText)
            self:setEditWndEffect(false,false)
        end
    end)
    self:subscribe(self:child("Numpad-Key-del"), UIEvent.EventButtonClick, function()
        local length = Lib.getStringLen(self.editText)
        self.editText = Lib.subString(self.editText, length - 1)
        if self.editWnd then
            self.editWnd:SetText(self.editText)
            self:setEditWndEffect(false,false)
        end
    end)
    self:subscribe(self.closeBtn, UIEvent.EventWindowTouchDown, function()
        self:closeNumpad()
        UI:closeWnd(self)
    end)
    Lib.subscribeEvent(Event.EVENT_CLOSE_POP_WIN, function()
        self:closeNumpad()
        UI:closeWnd(self)
    end)
    self:root():setBelongWhitelist(true)
    self:root():SetLevel(0)
end

function M:onOpen()
    Blockman.instance.gameSettings.isPopWindow = true
end

function M:onClose()
    Blockman.instance.gameSettings.isPopWindow = false
end

function M:closeNumpad()
    if self.editWnd and self.editSlider then
        if editWndOpenText ~= self.editWnd:GetText() then
            self.editText = ( self.editText == "" or self.editText == "." ) and "0" or self.editText
            self.editSlider:onEditValueChanged( self.editText )
        end
        self:setEditWndEffect(false,true)
    end
    self.editWnd = nil
    self.editSlider = nil
    self.editText = ""
end

function M:setEditWnd(wnd, slider, isFloat, x, y)
    if self.editWnd then
        self:closeNumpad()
    end
    self.editWnd = wnd
    self.editSlider = slider
    self:child("Numpad-Key-dot"):SetEnabledRecursivly(isFloat)
    if x and y then
        x = x - self.numpad:GetWidth()[2] - 20
        y = y - 50
        y = math.max( 80,  y )
        y = math.min( 320, y )
        self.numpad:SetXPosition({ 0, x })
        self.numpad:SetYPosition({ 0, y })
    end
    self:setEditWndEffect(true,false)
    if self.editWnd then
        editWndOpenText = self.editWnd:GetText()
        self.editWnd:setBelongWhitelist(true)
    end
end

function M:setEditWndEffect(showEffect,isClose)
    if not self.editWnd or not self.editSlider then
        return
    end
    if showEffect then
        local width = self.editWnd:GetFont():GetTextExtent(self.editWnd:GetText(),1.0)
        self.editWnd:SetWidth({0,width + 2})
        self.editWnd:SetBackgroundColor({ 200 / 255, 246 / 255, 102 / 255, 1 })
        self.editSlider:child("Slider-edit_bg"):SetImage("set:numpad.json image:bg_number_border_selected.png")
    else
        self.editWnd:SetBackgroundColor({ 0,0,0,0 })
        self.editWnd:SetWidth({0, 50})
        if isClose then
            self.editSlider:child("Slider-edit_bg"):SetImage("set:setting_base.json image:bg_number_border.png")
        end
    end
end

return M