local strfor = string.format
local root = nil
local title = nil
local routineList = nil
local tabs = nil
local selectedTab = nil
local curData = nil

function M:init()
    WinBase.init(self, "Routine.json")
    title = self:child("Routine-Context-Title-Name")
    routineList = self:child("Routine-Context-List")
    tabs = self:child("Routine-Tabs")
    self:subscribe(self:child("Routine-Btn-Close"), UIEvent.EventButtonClick, function()
        self:onBtnClose()
    end)
end

function M:onOpen(content, data)
    tabs:CleanupChildren()
    curData = data
    for i, c in pairs(content) do
        self:addTabView(c, i)
    end
    self.openArgs = table.pack(content, data)
end

function M:addTabView(context, index)
    local strTabName = strfor("Routine-Context-Tabs-Item-%d", index)
    local radioItem = GUIWindowManager.instance:CreateGUIWindow1("RadioButton", strTabName)
    radioItem:SetArea({ 0, 0 }, { (index - 1) * 0.2, 0 }, { 0.8, 0 }, { 0.18, 0 })
    radioItem:SetPushedImage("set:new_task.json image:tap_normal.png")
    radioItem:SetNormalImage("set:new_task.json image:tap_push_bg.png")
    radioItem:SetProperty("HorizontalAlignment", "Right")

    local tabName = Lang:toText(context.type)
    radioItem:SetProperty("TextShadow", "true")
    radioItem:SetProperty("TextShadowColor", tostring(37 / 255) .. " " .. tostring(36 / 255) .. " " .. tostring(41 / 255) .. " 1")
    radioItem:SetText(tabName)
    radioItem:SetProperty("Font", "HT24")

    self:subscribe(radioItem, UIEvent.EventRadioStateChanged, function(statu)
        if statu:IsSelected() then
            self:onRadioChange(context, radioItem, index)
        end
    end)
    tabs:AddChildWindow(radioItem)
    if index == 1 then
        radioItem:SetSelected(true)
    end
end

function M:onRadioChange(context, radio, index)
    if selectedTab == radio then
        return
    end
    title:SetText(Lang:toText(context.type))
    routineList:ClearAllItem()
    routineList:SetItemHeight(160)
    self:showRoutineItem(context, index)
    selectedTab = radio
end

function M:showRoutineItem(context, index)
    local content = context.content or {}
    for i, item in pairs(content) do
        local routineItem = GUIWindowManager.instance:CreateWindowFromTemplate("routineitem" .. tostring(i), "RoutineItem.json")
        self:refreshItem(routineItem, item, index)
        routineItem:SetArea({ 0, 0 }, { 0, 0 }, { 1, 0 }, { 0, 158 })
        routineList:AddItem(routineItem, true)
    end
    routineList:SetAllowScroll(true)
    routineList:SetTouchable(true)
end

function M:refreshItem(routineItem, item, index)
    local classify = routineItem:GetChildByIndex(0)
    local iconBg = classify:GetChildByIndex(0)
    local routineName = routineItem:GetChildByIndex(1)
    local submitBtn = routineItem:GetChildByIndex(2)
    local desc = routineItem:GetChildByIndex(3)
    local reward = routineItem:GetChildByIndex(4)
    local rewardName = reward:GetChildByIndex(0)
    local rewardContent = reward:GetChildByIndex(1)
    local submitBtnName = submitBtn:GetChildByIndex(0)

    self:subscribe(submitBtn, UIEvent.EventButtonClick, function()
        self:onSureBtn(item, routineItem, index)
    end)
    routineName:SetText("")
    if item.classIcon then
        iconBg:SetImage(item.classIcon)
    end
    if item.name then
        routineName:SetText(Lang:toText(item.name))
    end
    local exp = math.min(curData[tostring(item.condition)] or 0, item.nextExp)
    local args = {
        exp,
        item.nextExp
    }
    submitBtn:SetEnabled(exp >= item.nextExp)
    submitBtnName:SetText(Lang:toText("routine_btn_commit"))
    desc:SetText(Lang:toText({ item.desc, table.unpack(args) }))
    rewardName:SetText(Lang:toText("routine_text_reward"))
    self:showReward(rewardContent, item.reward)
    self:routineResult(item.isReward, routineItem, item)
end

function M:showReward(rewardContent, rewards)
    for i, item in pairs(rewards) do
        local fullName = item.fullName
        local type = item.type
        local strName = strfor("Routine-Reward-Item-%s", fullName)
        local strIconName = strfor("Routine-Reward-Item-Icon-%s", fullName)
        local strCountName = strfor("Routine-Reward-Item-Count-%s", fullName)
        local rewardItem = GUIWindowManager.instance:CreateGUIWindow1("Layout", strName)
        rewardItem:SetArea({ 0, (i - 1) * 120 }, { 0, 0 }, { 0, 120 }, { 1, 0 })
        local rewardIcon = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", strIconName)
        rewardIcon:SetArea({ 0, 0 }, { 0, 0 }, { 0, 40 }, { 0, 40 })
        rewardIcon:SetVerticalAlignment(1)
        if type == "item" then
            rewardIcon:SetImage(Item.CreateItem(fullName):icon())
        else
            rewardIcon:SetImage(fullName)
        end
        rewardItem:AddChildWindow(rewardIcon)

        local rewardNum = GUIWindowManager.instance:CreateGUIWindow1("StaticText", strCountName)
        rewardNum:SetArea({ 0, 35 }, { 0, 0 }, { 0, 90 }, { 1, 0 })
        rewardNum:SetVerticalAlignment(1)
        rewardNum:SetTextVertAlign(1)
        rewardNum:SetText(strfor(" X %d", item.count))
        rewardNum:SetTextColor({ 230 / 255, 89 / 255, 10 / 255 })
        rewardNum:SetProperty("TextShadow", "true")
        rewardNum:SetProperty("TextShadowColor", tostring(230 / 255) .. " " .. tostring(89 / 255) .. " " .. tostring(10 / 255) .. " 1")
        rewardItem:AddChildWindow(rewardNum)
        rewardContent:AddChildWindow(rewardItem)
    end
end

function M:onSureBtn(item, routineItem, index)
    Me:routineCommit(item.id, index, function(succees)
        self:routineResult(succees, routineItem, item)
    end)
end

function M:routineResult(suc, routineItem, item)
    if suc then
        local submitBtn = routineItem:GetChildByIndex(2)
        item.isReward = suc
        submitBtn:SetVisible(false)
        routineItem:GetChildByIndex(5):SetVisible(true)
        routineItem:GetChildByIndex(6):SetVisible(true)
    end
end

function M:onBtnClose()
    Lib.emitEvent(Event.EVENT_SHOW_ROUTINE, false)
end

return M