--ui window
local sign_in_title_close, sign_in_content_tabs, sign_in_content_panel
--value
local radio_panel_index = {}
local m_radio_index

local Status = {
    UNRECEIVED = 0,
    RECEIVED = 1,
    CURRENT = 2,
    MISS = 3,
}

local function getLangText(name, sign, d_arg, ...)
    local _arg = name .. "." .. sign
    local text = Lang:toText(_arg) == _arg and d_arg and Lang:toText({ d_arg, ... }) or Lang:toText({ _arg, ... })
    return text
end

local function checkImageStr(str, cfg)
    if str == "" then
        return ""
    end
    if str and str:find("set:") then
        return str
    end
    if str and cfg and cfg.plugin then
        local path = ResLoader:loadImage(cfg, str)
        return path
    end
    return nil
end

function M:init()
    WinBase.init(self, "SignIn.json", true)

    local today = Lib.getYearDayStr(os.time())
    -- self:child("Task-Title-Name"):SetText(Lang:toText("task.title.name"))
    sign_in_title_close = self:child("SignIn-Close")
    self:subscribe(sign_in_title_close, UIEvent.EventButtonClick, function()
        self:buttonClose()
    end)
    sign_in_content_tabs = self:child("SignIn-Content-Tabs")
    sign_in_content_panel = self:child("SignIn-Content-Panel")
    self:child("SignIn-TitleName"):SetText(Lang:toText("signIn.title.name"))
    local i = 0
    for _, cfg in pairs(Player.SignIns) do
        self:addTabView(cfg, i)
        i = i + 1
    end
end

function M:onOpen()

end

function M:updateSignIn()

end

function M:addTabView(group, index)
    local strTabName = group.fullName or ("SignIn-Tab-" .. index)
    local name = group._name or group.fullName .. ".tab"
    local radioItem = GUIWindowManager.instance:CreateGUIWindow1("RadioButton", strTabName)
    radioItem:SetArea({ 0, 5 }, { 0, index * 90 + 5 }, { 1, -5 }, { 0, 80 })
    radioItem:SetNormalImage("set:gui_sign_in.json image:tab_item_normal")
    radioItem:SetPushedImage("set:gui_sign_in.json image:tab_item_select")
    self:unsubscribe(radioItem)
    self:subscribe(radioItem, UIEvent.EventRadioStateChanged, function(state)
        if state:IsSelected() then
            self:onRadioChange(index)
        end
    end)
    strTabName = strTabName .. "-Name"
    local radioItemName = GUIWindowManager.instance:CreateGUIWindow1("StaticText", strTabName)
    radioItemName:SetArea({ 0, 23 }, { 0, 0 }, { 0.8, 0 }, { 1, 0 })
    radioItemName:SetText(getLangText(name, "tab", name))
    radioItemName:SetProperty("TextHorzAlignment", "Left")
    radioItemName:SetProperty("TextVertAlignment", "Centre")
    radioItemName:SetProperty("TextWordWrap", "true")
    radioItemName:SetProperty("TextBorder", "true")
    radioItemName:SetProperty("TextBorderColor", tostring(37 / 255) .. " " .. tostring(36 / 255) .. " " .. tostring(41 / 255) .. " 1")
    radioItem:AddChildWindow(radioItemName)
    sign_in_content_tabs:AddChildWindow(radioItem)

    local strPanelName = string.format("SignIn-Content-Panel-%d", index)
    local SignInPanel = GUIWindowManager.instance:CreateWindowFromTemplate(strPanelName, "SignInPanel.json")
    sign_in_content_panel:AddChildWindow(SignInPanel)
    SignInPanel:SetVisible(false)

    radio_panel_index[index] = {
        radioItem = radioItem,
        panelItem = SignInPanel,
        group = group,
        finishInit = false
    }

    if index == 0 then
        self:onRadioChange(index)
    end
end

local function clear(view)
    while (view:GetItemCount() > 0) do
        local p = view:GetItem(0)
        view:RemoveItem(p)
    end
end

function M:onRadioChange(index)
    --todo
    radio_panel_index[m_radio_index or 0].radioItem:SetSelected(false)
    radio_panel_index[m_radio_index or 0].panelItem:SetVisible(false)
    radio_panel_index[index].radioItem:SetSelected(true)
    radio_panel_index[index].panelItem:SetVisible(true)
    m_radio_index = index
    if not radio_panel_index[index].finishInit then
        radio_panel_index[index].finishInit = true
        self:initContentPanel(radio_panel_index[index].panelItem, radio_panel_index[index].group)
    end
end

function M:initContentPanel(panel, group)
    local panel_backGround = panel:GetChildByIndex(0)
    local panel_image = panel:GetChildByIndex(1)
    local panel_text = panel:GetChildByIndex(2)
    local panel_items_layout = panel:GetChildByIndex(3)
    local panel_items = panel:GetChildByIndex(3):GetChildByIndex(0)
    local occupy = tonumber(group.imageOccupy) or 0

    if group.image_bg ~= "" then
        panel_backGround:SetImage(group.image_bg)
    end

    panel_text:SetArea({ group.text_pos_x, 0 }, { group.text_pos_y, 0 }, { 1 - group.text_pos_x, 0 }, { 1 -group.text_pos_y, 0 })
    panel_image:SetImage(checkImageStr(group.image_tips, group) or "")
    if tostring(group.imagePos) == "LeftTop" then
        if tostring(group.stretch) == "horizontal" then
            panel_image:SetArea({ 0, 0 }, { 0, 0 }, { occupy, 0 }, { 1, 0 })
            panel_items_layout:SetArea({ occupy, 0 }, { 0, 0 }, { 1 - occupy, 0 }, { 1, 0 })
        else
            panel_image:SetArea({ 0, 0 }, { 0, 0 }, { 1, 0 }, { occupy, 0 })
            panel_items_layout:SetArea({ 0, 0 }, { occupy, 0 }, { 1, 0 }, { 1 - occupy, 0 })
        end
    else
        panel_image:SetProperty("HorizontalAlignment", "Right")
        panel_image:SetProperty("VerticalAlignment", "Bottom")
        panel_items_layout:SetProperty("HorizontalAlignment", "Right")
        panel_items_layout:SetProperty("VerticalAlignment", "Bottom")
        if tostring(group.stretch) == "horizontal" then
            panel_image:SetArea({ 0, 0 }, { 0, 0 }, { occupy, 0 }, { 1, 0 })
            panel_items_layout:SetArea({ occupy * -1, 0 }, { 0, 0 }, { 1 - occupy, 0 }, { 1, 0 })
        else
            panel_image:SetArea({ 0, 0 }, { 0, 0 }, { 1, 0 }, { occupy, 0 })
            panel_items_layout:SetArea({ 0, 0 }, { occupy * -1, 0 }, { 1, 0 }, { 1 - occupy, 0 })
        end
    end

    local func = function(data)
        clear(panel_items)
        panel_items:SetArea({ 0, 0 }, { 0, 0 }, { 1, group.border_x * -2 }, { 1, group.border_y * -2 })
        local maxWidth = (panel_items:GetPixelSize().x - group.interval_x * (group.rowSize - 1)) / group.rowSize
        panel_items:InitConfig(group.interval_x, group.interval_y, group.rowSize)
        self:initPanelItems(panel_items, panel_text, group, maxWidth, data)
    end
    Me:getSignInData(group._name, func)
end

function M:initPanelItems(gridView, panel_text, group, itemSize, data)
    local sign_in_items = group.sign_in_items
    local finish_count = 0
    for index, item in pairs(sign_in_items) do
        local strItemName = string.format("SignIn-Content-Panel-Item-%d", index)
        local SignInItem = GUIWindowManager.instance:CreateWindowFromTemplate(strItemName, "SignInItem.json")
        SignInItem:GetChildByIndex(0):GetChildByIndex(0):SetImage(checkImageStr(item.icon, group) or "")
        if group.show_item_order then
            local order_text = SignInItem:GetChildByIndex(5)
            order_text:SetVisible(true)
            order_text:SetText(item.index)
        end
        self:subscribe(SignInItem:GetChildByIndex(0), UIEvent.EventButtonClick, function()
            if item.status == Status.CURRENT then
                local function func(ok, msg)
                    if ok then
                        item.status = Status.RECEIVED
                        SignInItem:GetChildByIndex(1):SetVisible(false)
                        SignInItem:GetChildByIndex(3):SetVisible(false)
                        SignInItem:GetChildByIndex(4):SetVisible(true)
                        finish_count = finish_count + 1
                        panel_text:SetText(string.format(Lang:toText(group.finish_text), finish_count))
                    else
                        print(msg)
                    end
                end
                Me:getSignInReward(item.group._name, item.index, func)
            end
        end)
        SignInItem:SetArea({ 0, 0 }, { 0, 0 }, { 0, itemSize }, { 0, itemSize })
        gridView:AddItem(SignInItem)
        item.status = data[index] or Status.UNRECEIVED
        if item.status == Status.RECEIVED then
            SignInItem:GetChildByIndex(3):SetVisible(false)
            SignInItem:GetChildByIndex(4):SetVisible(true)
            finish_count = finish_count + 1
        elseif item.status == Status.MISS then
            SignInItem:GetChildByIndex(3):SetVisible(false)
            SignInItem:GetChildByIndex(2):SetVisible(true)
        elseif item.status == Status.CURRENT then
            SignInItem:GetChildByIndex(3):SetVisible(false)
            SignInItem:GetChildByIndex(1):SetVisible(true)
        end
    end
    panel_text:SetText(string.format(Lang:toText(group.finish_text), finish_count))
end

local function getRewardList(reward, cfg)
    local setting = require "common.setting"
    local _cfg
    local t_reward = {}
    if type(reward) == "table" then
        t_reward = reward
        _cfg = cfg
    elseif not string.find(reward, "/") then
        t_reward = Lib.readGameJson("plugin/" .. cfg.plugin .. "/" .. cfg.modName .. "/" .. cfg._name .. "/" .. reward .. ".json")
        _cfg = cfg
    elseif setting:fetch("reward", reward) then
        t_reward = setting:fetch("reward", reward)
        _cfg = t_reward
    end
    assert(t_reward)
    return t_reward, _cfg
end

local function getIcon(reward, cfg)
    local icon = reward.icon
    local type = reward.type
    local name = reward.name
    local block = reward.blockId
    if icon and icon:find("set:") then
        return icon
    elseif icon and cfg and cfg.plugin then
        local path = ResLoader:loadImage(cfg, icon)
        return path
    end
    if not icon then
        icon = ResLoader:getIcon(type, name, block)
    end
    assert(icon)
    return icon
end

local function closeWindow(window)
    if window then
        window:SetVisible(false)
    end
end

local function getItemIndexByList(name)
    if not next(list_index) then
        return nil
    end
    for i, n in ipairs(list_index) do
        if n == name then
            return i - 1
        end
    end
end

function M:buttonClose()
    UI:closeWnd(self)
end

return M