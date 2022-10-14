local callBackModName
local regId


local IM_INPUT_MODE = {
    IM_ANY = 0,             -- The user is allowed to enter any text, including line breaks.
    IM_EMAIL_ADDRESS = 1,   -- The user is allowed to enter an e-mail address.
    IM_NUMERIC = 2,         -- The user is allowed to enter an integer value.
    IM_PHONE_NUMBER = 3,    -- The user is allowed to enter a phone number.
    IM_URL = 4,             -- The user is allowed to enter a URL.
    IM_DECIMAL = 5,         -- The user is allowed to enter a real number value, allowing a decimal point.
    IM_SINGLE_LINE = 6      -- The user is allowed to enter any text, except for line breaks.
}

local TipType = {
    COMMON = 0,
    PAY = 1
}

function M:init()
    WinBase.init(self, "InputDialog.json", false)
    self:initTitle()
    self:initCloseBtn()
    self:initInputArea()
    self:initButtons()
    self:initPayButtons()
end

function M:onOpen(info)
    if not info or not info.contents then
        return
    end

    regId = info.regId
    callBackModName = info.callBackModName

    local contents = info.contents
    local showType = contents.showType or TipType.COMMON
    self.initInputTitle = contents.inputTitle

    self:updateTitle(contents.title)
    self:updateInputTitle(contents.inputTitle)
    self:updateCloseBtn(contents.closeBtn)
    self:updateBoxTextLength(contents.textLength)
    self:updateBoxText(contents.text, contents.isLangText)
    self:updateBoxTextHintMaxLength(contents.isHintMaxTextLength)
    self:updateBoxTextHintRemainingText(contents.isHintRemainingText)
    self:updateInputMode(contents.inputMode)
    if showType == TipType.COMMON then
        self:updateButtons(contents.buttons)
    elseif showType == TipType.PAY then
        self:updatePayButtons(contents.buttons)
    end
end

function M:initTitle()
    self.titleName = self:child("InputDialog-TitleName")
end

function M:initCloseBtn()
    self.closeBtn = self:child("InputDialog-Btn-Close")
    self:subscribe(self.closeBtn, UIEvent.EventButtonClick, function()
        self:onBtnClose()
    end)
end

function M:initInputArea()
    self.inputTitle = self:child("InputDialog-Input-Title")
    self.inputBox = self:child("InputDialog-Input-Box")
    self.bottomHitText = self:child("InputDialog-Bottom-Hint-Text")
    self.inputBox:SetTextVertAlign(1)
    self.inputBox:SetTextHorzAlign(1)
end

function M:initButtons()
    self.btnGridView = self:child("InputDialog-Buttons-Grid")
    self.btnBg = self:child("InputDialog-Panel-Btn-Bg")
end

function M:initPayButtons()
    self.payBtnLayout = self:child("InputDialog-Buttons-Pay")
    self.payLeftBtn = self:child("InputDialog-Buttons-Pay-Left")
    self.payLeftBtnPrice = self:child("InputDialog-Buttons-Pay-Left-Price")
    self.payLeftBtnCurrencyIcon = self:child("InputDialog-Buttons-Pay-Left-Currency-Icon")
    self.payRightBtn = self:child("InputDialog-Buttons-Pay-Right")
    self.payRightBtnPrice = self:child("InputDialog-Buttons-Pay-Right-Price")
    self.payRightBtnCurrencyIcon = self:child("InputDialog-Buttons-Pay-Right-Currency-Icon")
end

function M:onBtnClose()
    self.inputBox:SetText("")
    UI:closeWnd(self)
end

function M:updateTitle(title)
    if not title then
         return
    end

    if title.name then
        self.titleName:SetText(Lang:toText(title.name))
    end
end

function M:updateInputTitle(inputTitle)
    if not inputTitle then
        return
    end

    if inputTitle.name then
        self.inputTitle:SetText(Lang:toText(inputTitle.name))
    end
    local color = inputTitle.color or {255, 255, 255}
    self.inputTitle:SetTextColor({ color[1] / 255, color[2] / 255, color[3] / 255 })
end

function M:updateBottomHitText(text)
    if not text then
        return
    end

    if text.text then
        local args = text.args or ""
        self.bottomHitText:SetText(Lang:toText(text.text) .. args)
    end

    local color = text.color or {255, 255, 255}
    self.bottomHitText:SetTextColor({ color[1] / 255, color[2] / 255, color[3] / 255 })
end

function M:updateCloseBtn(closeBtn)
    if not closeBtn then
        return
    end

    if closeBtn.disableClose then
        self.closeBtn:SetVisible(false)
    end

    if closeBtn.normalImage then
        self.closeBtn:SetNormalImage(closeBtn.normalImage)
    end

    if closeBtn.pushedImage then
        self.closeBtn:SetPushedImage(closeBtn.pushedImage)
    end
end

function M:updateButtons(buttons)
    self.payBtnLayout:SetVisible(false)
    self.btnGridView:SetVisible(true)
    local btnGridView = self.btnGridView
    local size = #buttons
    local xLength = self.btnBg:GetPixelSize().x
    local px = 0.3
    local gridWidth = px * xLength * size + 20 * (size - 1)

    btnGridView:RemoveAllItems()
    btnGridView:InitConfig(20, 0, 3)
    btnGridView:SetMoveAble(false)
    btnGridView:SetWidth({0, gridWidth})
    for i, button in pairs(buttons or {}) do
        local btn = GUIWindowManager.instance:CreateGUIWindow1("Button", "button" .. i)
        btn:SetTextColor({ 1, 1, 1, 1 })
        btn:SetProperty("TextShadow", "true")
        if button.name then
            btn:SetText(Lang:toText(button.name))
        end

        if button.normalImage then
            btn:SetNormalImage(button.normalImage)
        end

        if button.pushedImage then
            btn:SetPushedImage(button.pushedImage)
        end

        self:unsubscribe(btn, UIEvent.EventButtonClick)
        self:subscribe(btn, UIEvent.EventButtonClick, function()
            if button.event then
                if button.event == "cancel" then
                    self:onBtnClose()
                else
                    local name = self.inputBox:GetPropertyString("Text","")
                    Me:doCallBack(callBackModName, button.event, regId, {name = name})
                    if not button.clickAndShow then
                        self:onBtnClose()
                    end
                end
            end
        end)

        btn:SetArea({0, 0}, {0, 0}, {0, px * xLength}, {0.705, 0})
        btn:SetVerticalAlignment(1)
        btn:SetProperty("StretchType", "NineGrid")
        btn:SetProperty("StretchOffset", "20 20 0 0")
        btnGridView:AddItem(btn)
    end
end

function M:updateBoxTextLength(textLength)
    self.textLength = textLength or 16
    self.inputBox:SetProperty("MaxTextLength", self.textLength)
end

function M:updateBoxText(text, isLangText)
    if text then
        if isLangText then
            text = Lang:toText(text)
        end
        self.inputBox:SetText(text)
    end
end

function M:updateBoxTextHintMaxLength(isHintMaxTextLength)
    if isHintMaxTextLength then
        self:unsubscribe(self.inputBox, UIEvent.EventEditTextInput)
        self:subscribe(self.inputBox, UIEvent.EventEditTextInput, function()
            self:checkNewName()
        end)
    else
        self:unsubscribe(self.inputBox, UIEvent.EventEditTextInput)
    end
end

function M:updateBoxTextHintRemainingText(isHintRemainingText)
    if isHintRemainingText then
        self:unsubscribe(self.inputBox, UIEvent.EventEditTextInput)
        self:subscribe(self.inputBox, UIEvent.EventEditTextInput, function()
            self:setRemainingText()
        end)
        self:setRemainingText()
    else
        self:unsubscribe(self.inputBox, UIEvent.EventEditTextInput)
        self:updateBottomHitText({text = ""})
    end
end

function M:updateInputMode(inputMode)
    local editBoxImpl = self.inputBox:getEditBoxImpl()
    if not editBoxImpl then
        return
    end

    if not inputMode then
        editBoxImpl:setInputMode(IM_INPUT_MODE.IM_ANY)
    else
        editBoxImpl:setInputMode(inputMode)
    end
end

function M:updatePayButtons(buttons)
    self.btnGridView:SetVisible(false)
    self.payBtnLayout:SetVisible(true)

    for i, button in pairs(buttons or {}) do
        if i <= 2 then
            local btnView = self.payBtnLayout:GetChildByIndex(i - 1)
            self:updatePayButtonInfo(btnView, button)
        end
    end
end

function M:updatePayButtonInfo(btnView, btnInfo)
    if btnInfo.normalImage then
        btnView:SetNormalImage(btnInfo.normalImage)
    end

    if btnInfo.pushedImage then
        btnView:SetPushedImage(btnInfo.pushedImage)
    end

    local btnCurrencyIconView = btnView:GetChildByIndex(0)
    local btnPriceView = btnView:GetChildByIndex(1)

    if type(btnInfo.coinId) == "number" then
        btnView:SetText("")
        btnCurrencyIconView:SetVisible(true)
        btnPriceView:SetVisible(true)
        btnCurrencyIconView:SetImage(Coin:iconByCoinId(btnInfo.coinId))
        btnPriceView:SetText(tostring(btnInfo.content))
    else
        btnCurrencyIconView:SetVisible(false)
        btnPriceView:SetVisible(false)
        btnView:SetText(Lang:toText(btnInfo.content or "gui_dialog_tip_pay_right"))
    end
    self:unsubscribe(btnView, UIEvent.EventButtonClick)
    self:subscribe(btnView, UIEvent.EventButtonClick, function()
        if btnInfo.event then
            if btnInfo.event ~= "cancel" then
                local name = self.inputBox:GetPropertyString("Text","")
                Me:doCallBack(callBackModName, btnInfo.event, regId, {name = name})
            end
            self:onBtnClose()
        end
    end)
end

function M:checkNewName()
    local name = self.inputBox:GetPropertyString("Text","")
    local count = 0
    for v in string.gmatch(name, "([%z\1-\127\194-\244][\128-\191]*)") do
        if #v ~= 1 then
            count = count + 2
        else
            count = count + 1
        end
    end

    if count > self.textLength then
        self.inputBox:OnInputText(name)
        local inputTitle = {
            name = "ui_lang_reach_maximum_length",
            color = {
                255,
                0,
                0
            }
        }
        self:updateInputTitle(inputTitle)
    else
        self:updateInputTitle(self.initInputTitle)
    end
    self.inputBox:SetProperty("MaxTextLength", self.textLength + 1)
end

function M:setRemainingText()
    local name = self.inputBox:GetPropertyString("Text","")
    local count = 0
    for v in string.gmatch(name, "([%z\1-\127\194-\244][\128-\191]*)") do
        if #v ~= 1 then
            count = count + 2
        else
            count = count + 1
        end
    end

    count = count > self.textLength and self.textLength or count

    local text = {
        text = "ui_lang_remaining_length",
        color = {
            255,
            255,
            255
        },
        args = count  .. "/" .. self.textLength
    }

    self:updateBottomHitText(text)
end