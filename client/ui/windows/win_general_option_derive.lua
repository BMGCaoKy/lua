local addFrame = {}
local callBackModName, regId, options

function addFrame:rank(params)
    --todo 添加rank到right窗口里
    local wnd = UI:openWnd("rank_frame", params)
    if wnd then
        self.right:AddChildWindow(wnd:root())
    end
end

function M:init()
    WinBase.init(self, "GeneralOptions_2.json", true)
    self.title = self:child("GeneralOptions-Title")
    self.left = self:child("GeneralOptions-Left")
    self.right = self:child("GeneralOptions-Right")
    self.upBtn = self:child("GeneralOptions-Up")
    self.downBtn = self:child("GeneralOptions-Down")
    self.closeBtn = self:child("GeneralOptions-Close")

    self:subscribe(self.closeBtn, UIEvent.EventButtonClick, function()
        UI:closeWnd(self)
    end)

    Lib.subscribeEvent(Event.EVENT_UPDATE_GENERAL_OPTION_DERIVE, function(frame, params)
        self:updateRightWnd(frame, params)
    end)
    self:initTab()
end

function M:initTab()
    self.tab = UIMgr:new_widget("tab", "Left", 10)
    self.tab:invoke("BTN_SIZE", { 1, 0 }, { 0, 78 })
    self.tab:invoke("BTN_STRETCH", "60 60 0 0")
    self.tab:invoke("BTN_IMAGE", "set:backpack_display.json image:tab_normal.png", "set:backpack_display.json image:tab_push.png")
    self:child("GeneralOptions-List"):AddChildWindow(self.tab)
end

function M:onOpen(packet)
    callBackModName = packet.callBackModName
    regId = packet.regId
    options = packet.options
    self.title:SetText(Lang:toText(packet.title or "gui.general.option.title"))
    local leftWidth = packet.leftSideWidth
    if leftWidth and leftWidth > 0 then
        self.left:SetWidth({ 0, leftWidth })
        self.right:SetWidth({ 1, (-50 - leftWidth) })
    end
    self:refreshTab()
end

function M:refreshTab()
    self.tab:invoke("CLEAN")
    for i, option in pairs(options or {}) do
        self.tab:invoke("ADD_BUTTON", option.name or "general.option.derive." .. i, function(radioBtn)
            Me:doCallBack(callBackModName, option.event, regId, option.context)
            if radioBtn then
                radioBtn:GetChildByIndex(0):SetTextColor({ 1, 1, 1, 1 })
            end
        end, { 255 / 255, 233 / 255, 186 / 255 }, { 111 / 255, 55 / 255, 36 / 255 }, "HT22")
        if i == 1 then
            self.tab:invoke("SELECTED", 0)
        end
    end
end

function M:updateRightWnd(frameName, params)
    if not frameName then
        return
    end
    local frameProc = addFrame[frameName]
    if type(frameProc) == "function" then
        frameProc(self, params)
    end
end

function M:onClose()
end

return M