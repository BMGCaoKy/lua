local taskShowType = {
    MAIN = 0,
    ACCEPT = 1,
    COMMIT = 2,
    TIP = 3,
    SIMPLE_ACCEPT = 4,
    TRACE_UI = 5
}

local taskState = {
    ACCEPTABLE = 0,
    UNDERWAY = 1,
    ACHIEVABLE = 2,
    COMPLETED = 3,
    OTHER = 10
}

function M:init()
    WinBase.init(self, "Task.json", true)
    self.curTaskIndex = 1
    self.needHintList = {}
    self.taskNameList = {}
    self:initMainPanel()
    self:initGetTaskPanel()
    self:initTipPanel()
    self:initProgressPanel()
    self:initCommitPanel()
    self:initHintPanel()

    Lib.subscribeEvent(Event.EVENT_UPDATE_TASK_DATA, function(type, fullName, msg)
        self:onUpdate(type, fullName, msg)
    end)
end

function M:onClose()
    self.tipPanel:SetVisible(false)
    self.getTaskPanel:SetVisible(false)
    self.maskBg:SetVisible(false)
    self.mainPanel:SetVisible(false)
    self.taskNameList = {}
    self.closeHintTimer = nil
    self.selectedRadio = nil
    self.currentTask = nil
end

--------------------------------------------

local function getLangText(name, sign, arg1, ...)
    local arg = name .. "." .. sign
    local text = Lang:toText(arg) == arg and arg1 and Lang:toText({ arg1, ... }) or Lang:toText({ arg, ... })
    return text
end

local function getItemIndexByList(self, name)
    if not next(self.taskNameList) then
        return nil
    end
    for i, n in ipairs(self.taskNameList) do
        if n == name then
            return i - 1
        end
    end
end

local function getTargetMsg(task)
    local name = task.fullName
    local msg = ""
    local taskData = Me:data("task")
    for i, t in ipairs(task.targets) do
        if msg:len() > 0 then
            msg = msg .. "\n"
        end
        local targets = taskData[name] and taskData[name].targets or {}
        local cfgName = t.cfgName and (t.cfgName ~= "nil" and t.cfgName or name .. "." .. t.type .. "." .. t.cfgName)
        local arg = cfgName and { cfgName, targets[i] or 0, t.count } or { t.count, targets[i] or 0, t.count }
        msg = msg .. getLangText(name, t.type .. ".target" .. i, t.name or "target." .. t.type, table.unpack(arg, 1, arg.n))
    end
    return msg
end

function M:showTaskFinishHint(fullName)
    local needHintList = self.needHintList
    table.insert(needHintList, fullName)
    local hintName = needHintList[1]
    if not hintName then
        self:onClickCloseBtn()
        return
    end
    if not self.closeHintTimer then
        local task = Me.GetTask(hintName)
        self.hintPanel:SetVisible(true)
		if not (task.group.disableHint or task.disableHint) then
			self.hintTaskName:SetText(getLangText(task.fullName, "name", task.name))
		end
        local index = getItemIndexByList(self, fullName)
        if index then
            self:updateMainPanel()
        end
        self.closeHintTimer = World.Timer(60, self.nextHint, self)
    end
end

function M:nextHint()
    local needHintList = self.needHintList
    table.remove(needHintList, 1)
    self.hintPanel:SetVisible(false)
    if self.closeHintTimer then
        self.closeHintTimer()
        self.closeHintTimer = nil
    end
    if not next(needHintList) and not self.maskBg:IsVisible() and not self.mainPanel:IsVisible() then
        self:onClickCloseBtn()
    elseif next(needHintList) then
        World.Timer(20, self.showTaskFinishHint, self)
    end
end

function M:onClickCloseBtn()
    UI:closeWnd(self)
end

function M:onUpdate(type, fullName, msg)
    self.tipPanel:SetVisible(false)
    self.getTaskPanel:SetVisible(false)
    self.maskBg:SetVisible(false)
    self.mainPanel:SetVisible(false)
    if type == taskShowType.MAIN then
        self:updateMainPanel()
    elseif type == taskShowType.ACCEPT then
        self:updateGetTaskPanel(Me.GetTask(fullName))
    elseif type == taskShowType.COMMIT then
        self:updateCommitPanel(Me.GetTask(fullName))
    elseif type == taskShowType.TIP then
        self:updateTipPanel(msg)
    end
end


--------------------------------------------

function M:initMainPanel()
    local mainPanel = self:child("Task-Main-Panel")
    mainPanel:SetVisible(false)
    self.mainPanel = mainPanel
    self:child("Task-Title-Name"):SetText(Lang:toText("task.title.name"))
    self:subscribe(self:child("Task-Title-Close"), UIEvent.EventButtonClick, function()
        self:onClickCloseBtn()
    end)
    self.tabs = self:child("Task-Content-Tabs")
    self.taskList = self:child("Task-Content-Item-List")
    self.maskBg = self:child("Task-Tip-Bg")
    self.maskBg:SetVisible(false)
end

function M:initGetTaskPanel()
    self.getTaskPanel = self:child("Task-Acceptable")
    self.getTaskPanel:SetVisible(false)
end

function M:initTipPanel()
    self.tipPanel = self:child("Task-Tip")
    self.tipPanel:SetVisible(false)
    self:child("Task-Tip-Yes"):SetVisible(false)--no use
    self.tipNo = self:child("Task-Tip-No")
    self.tipNo:SetVisible(false)
end

function M:initProgressPanel()
    self.progressPanel = self:child("Task-View-Progress")
    self.progressPanel:SetVisible(false)
end

function M:initCommitPanel()
    self.commitPanel = self:child("Task-Commit")
    self.commitPanel:SetVisible(false)
end

function M:initHintPanel()
    self.hintPanel = self:child("Task-Hint")
    self.hintPanel:SetVisible(false)
    self:child("Task-Hint-Msg"):SetText(Lang:toText("task.hint.finish"))
    self.hintTaskName = self:child("Task-Hint-TaskName")
    self.hintTaskName:SetText("")
end

function M:updateMainPanel()
    self.mainPanel:SetVisible(true)
    Me:getTaskList(function(list)
        self.tabs:CleanupChildren()
        for index, group in ipairs(list) do
            self:addMainTabs(group, index - 1)
        end
    end)
end

local function fetchRadioButton(self, tabName, name, group, index)
    local radioBtn = GUIWindowManager.instance:CreateGUIWindow1("RadioButton", tabName)
    radioBtn:SetArea({ 0, 5 }, { 0, index * 82 + 5 }, { 0.96, 0 }, { 0, 82 })
    radioBtn:SetNormalImage("set:gui_composition.json image:tab_normal.png")
    radioBtn:SetPushedImage("set:gui_composition.json image:tab_pushed.png")
    radioBtn:SetProperty("StretchType", "NineGrid")
    radioBtn:SetProperty("StretchOffset", "25 25 15 15")
    self:unsubscribe(radioBtn)
    self:subscribe(radioBtn, UIEvent.EventRadioStateChanged, function(state)
        if state:IsSelected() then
            state:SetWidth({ 0.96, 12 })
            self:onChangeRadio(group)
            state:GetChildByIndex(0):SetTextColor({ 65 / 255, 60 / 255, 37 / 255 })
            self.selectedRadio = index
        else
            state:SetWidth({ 0.96, 0 })
            state:GetChildByIndex(0):SetTextColor({ 222 / 255, 218 / 255, 145 / 255 })
        end
    end)

    tabName = tabName .. "-Name"
    local radioName = GUIWindowManager.instance:CreateGUIWindow1("StaticText", tabName)
    radioName:SetArea({ 0, 0 }, { 0, 0 }, { 1, 0 }, { 1, 0 })
    radioName:SetText(getLangText(name, "tab", name))
    radioName:SetTextColor({ 222 / 255, 218 / 255, 145 / 255 })
    radioName:SetProperty("Font", "HT18")
    radioName:SetProperty("TextHorzAlignment", "Centre")
    radioName:SetProperty("TextVertAlignment", "Centre")
    radioName:SetProperty("TextWordWrap", "true")
    radioBtn:AddChildWindow(radioName)
    return radioBtn
end

function M:addMainTabs(group, index)
    local tabName = group.name or ("Task-Tab-" .. index)
    local name = Player.Tasks[group.name].name or group.name .. ".tab"
    local radioBtn = fetchRadioButton(self, tabName, name, group, index)
    self.tabs:AddChildWindow(radioBtn)
    if not self.selectedRadio and index == 0 or self.selectedRadio == index then
        radioBtn:SetSelected(true)
    end
end

function M:closeWindow(window)
    if window then
        window:SetVisible(false)
        self.currentTask = nil
        self.maskBg:SetVisible(false)
    end
    if not self.mainPanel:IsVisible() then
        self:onClickCloseBtn()
    end
end

function M:onChangeRadio(group)
    self.taskNameList = {}
    local showTask = { [taskState.COMPLETED] = {}, [taskState.ACHIEVABLE] = {}, [taskState.OTHER] = {} }
    self.taskList:ClearAllItem()
    self.taskList:SetProperty("BetweenDistance", "10")
    for _, t in ipairs(group.tasks) do
        local status = t.status
        if t.show and status == taskState.ACCEPTABLE or status == taskState.UNDERWAY then
            table.insert(showTask[taskState.OTHER], t)
        elseif t.status == taskState.ACHIEVABLE then
            table.insert(showTask[taskState.ACHIEVABLE], t)
        elseif t.status == taskState.COMPLETED then
            table.insert(showTask[taskState.COMPLETED], t)
        end
    end
    self:updateTaskList(showTask[taskState.ACHIEVABLE], group)
    self:updateTaskList(showTask[taskState.OTHER], group)
    self:updateTaskList(showTask[taskState.COMPLETED], group)
end

function M:updateTaskList(list, group)
    for _, t in ipairs(list) do
        local task = Me.GetTask(t.name or t.fullName, group)
        local strItemName = "Task-Content-ItemList-Item-" .. task.fullName
        local taskItem = GUIWindowManager.instance:CreateWindowFromTemplate(strItemName, "TaskItem.json")
        self:updateTaskItem(taskItem, task, t.status, true)
        self.taskList:AddItem(taskItem)
        table.insert(self.taskNameList, t.name)
    end
end

local function getIcon(reward, cfg)
    local icon = reward.icon
    local type = reward.type
    local name = reward.name
    if icon and icon:find("set:") then
        return icon
    elseif icon and cfg and cfg.plugin then
        local path = ResLoader:loadImage(cfg, icon)
        return path
    end
    if not icon then
        icon = ResLoader:getIcon(type, name)
    end
    assert(icon)
    return icon
end

function M:updateTaskItem(template, task, status, needChangeBg)
    local index = self.curTaskIndex
    index = needChangeBg and self.taskList:getContainerWindow() and self.taskList:getContainerWindow():GetChildCount() + 1 or index
    if needChangeBg and index % 2 == 1 then
        template:SetBackImage("set:new_gui_task.json image:taskItemBg-1.png")
    elseif needChangeBg then
        template:SetBackImage("set:new_gui_task.json image:taskItemBg-2.png")
    end
    self.curTaskIndex = index

    local name = task.fullName
    local itemIcon = template:GetChildByIndex(0):GetChildByIndex(0)
    local itemName = template:GetChildByIndex(1)
    local itemDesc = template:GetChildByIndex(2)
    local itemReward = template:GetChildByIndex(3)
    local itemRewardItems = template:GetChildByIndex(4)
    local itemBtn = template:GetChildByIndex(5)
    if task.icon then
        itemIcon:SetImage(getIcon(task, task.group))
    end
    itemName:SetText(getLangText(name, "name", task.name))
    itemDesc:SetText(getLangText(name, "desc", task.desc))
    itemReward:SetText(getLangText(name, "reward", "task.item.reward"))
    local _, cfg, icons = ResLoader:rewardContent(task.reward, task.group)
    self:showRewardInfo(itemRewardItems, icons, cfg)

    local taskData = Me:data("task")
    local taskStatus = taskData[name] and taskData[name].status or status
    self:onChangTaskStatus(itemBtn, taskStatus, task)
    local data = taskData[task.fullName]
    if data and data.hint then
        data.hint = false
    end
    self:unsubscribe(template)
    if taskStatus == taskState.UNDERWAY or taskStatus == taskState.ACHIEVABLE then
        self:subscribe(template, UIEvent.EventWindowClick, function()
            self:updateProgressPanel(task)
        end)
    end
    Me:updateTaskHint()
end

function M:showRewardInfo(items, reward, cfg)
    local x = 0
    for i, r in ipairs(reward) do
        local itemIcon = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "reward-icon-" .. i)
        itemIcon:SetArea({ 0, x }, { 0, 0 }, { 0, 40 }, { 0, 40 })
        itemIcon:SetImage(r.reDeal and getIcon(r, cfg or reward) or r.icon)
        itemIcon:SetVerticalAlignment(1)
        x = x + itemIcon:GetWidth()[2]
        items:AddChildWindow(itemIcon)
        local itemCount
        if r.count then
            itemCount = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "reward-count-" .. i)
            itemCount:SetText("x" .. tostring(r.count))
        elseif r.countRange then
            local range = r.countRange
            itemCount = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "reward-count-" .. i)
            itemCount:SetText("x" .. tostring(range.min) .. "-" .. tostring(range.max))
        end
        if itemCount then
            x = x + 10
            itemCount:SetArea({ 0, x }, { 0, 0 }, { 0, 0 }, { 0, 0 })
            itemCount:SetVerticalAlignment(1)
            itemCount:SetProperty("TextSelfAdaptHigh", "true")
            itemCount:SetProperty("AllShowOneLine", "true")
            itemCount:SetTextColor({ 143 / 255, 255 / 255, 0 / 255 })
            x = x + itemCount:GetWidth()[2]
            items:AddChildWindow(itemCount)
        end
        x = x + 25
    end
end

function M:onChangTaskStatus(btn, state, task)
    local name = task.fullName
    self:unsubscribe(btn)
    if state == taskState.ACCEPTABLE then
        local text = getLangText(name, "acceptable", "task.item.btn.acceptable")
        btn:SetText(text)
        btn:SetNormalImage("set:gui_composition.json image:yellow_btn.png")
        btn:SetPushedImage("set:gui_composition.json image:yellow_btn.png")
        self:subscribe(btn, UIEvent.EventButtonClick, function()
            self:updateGetTaskPanel(task)
        end)
    elseif state == taskState.UNDERWAY then
        local text = getLangText(name, "underway", "task.item.btn.underway")
        btn:SetText(text)
    elseif state == taskState.ACHIEVABLE then
        local text = getLangText(name, "accomplish", "task.item.btn.accomplish")
        btn:SetText(text)
        btn:SetNormalImage("set:new_gui_task.json image:yellow_btn.png")
        btn:SetPushedImage("set:new_gui_task.json image:yellow_btn.png")
        self:subscribe(btn, UIEvent.EventButtonClick, function()
            self:updateCommitPanel(task)
        end)
    elseif state == taskState.COMPLETED then
        btn:SetVisible(false)
        local parent = btn:GetParent()
        parent:GetChildByIndex(7):SetVisible(true)
        parent:GetChildByIndex(8):SetVisible(true)
    end
end

function M:showRewardItems(reward, layout, cfg)
    layout:CleanupChildren()
    local rewardWidget = UIMgr:new_widget("reward")
    rewardWidget:invoke("SET_ITEM_BG", "set:gui_composition.json image:item_frame.png")
    rewardWidget:invoke("SET_ITEM_COUNT_BG", "")
    rewardWidget:invoke("SHOW", reward, cfg, layout)
    rewardWidget:invoke("INIT_CONFIG", 15, 35, 5)
    rewardWidget:invoke("MOVE_ABLE", false)
end

function M:updateGetTaskPanel(task)
    self.currentTask = task
    self.maskBg:SetVisible(true)
    self.getTaskPanel:SetVisible(true)

    local name = task.fullName
    self:child("Task-Acceptable-Title-Name"):SetText(getLangText(name, "acceptable.title", "task.get.tip.title"))
    self:child("Task-Task"):SetText(getLangText(name, "acceptable.task.name", "task.get.task.name"))
    self:child("Task-Target-Name"):SetText(getLangText(name, "acceptable.target.name", "task.get.target.name"))
    self:child("Task-Reward-Name"):SetText(getLangText(name, "acceptable.reward.name", "task.get.reward.name"))
    self:child("Task-Confirm-Name"):SetText(getLangText(name, "acceptable.confirm.name", "task.get.confirm.name"))
    self:child("Task-Task-Name"):SetText(getLangText(name, "name", task.name))

    local msg = getTargetMsg(task)
    self:child("Task-Targets-Text"):SetText(msg)

    local closeBtn = self:child("Task-Acceptable-Close")
    self:unsubscribe(closeBtn)
    self:subscribe(closeBtn, UIEvent.EventButtonClick, function()
        self:closeWindow(self.getTaskPanel)
    end)
    local sureBtn = self:child("Task-Acceptable-Confirm-Btn")
    self:unsubscribe(sureBtn)
    self:subscribe(sureBtn, UIEvent.EventButtonClick, function()
        self:onClickAcceptBtn(name)
    end)

    self:showRewardItems(task.reward, self:child("Task-Task-Rewards"), task.group)
end

function M:updateProgressPanel(task)
    local function closeSelf()
        self.progressPanel:SetVisible(false)
    end

    self.progressPanel:SetVisible(true)
    self:unsubscribe(self.progressPanel)
    self:subscribe(self.progressPanel, UIEvent.EventWindowClick, closeSelf)

    local name = task.fullName
    self:child("Task-Progress-Content-Task-Task"):SetText(getLangText(name, "progress.task.name", "task.progress.task.name"))
    self:child("Task-Progress-Targets-Name"):SetText(getLangText(name, "progress.target.name", "task.progress.target.name"))
    self:child("Task-Progress-Content-Task-Name"):SetText(getLangText(name, "name", task.name))
    self:child("Task-Progress-Title-Name"):SetText(getLangText(name, "progress.title", "task.progress.tip.title"))

    local sureBtn = self:child("Task-Progress-Btn")
    sureBtn:SetText(getLangText(name, "progress.btn.name", "task.progress.btn.name"))
    self:unsubscribe(sureBtn)
    self:subscribe(sureBtn, UIEvent.EventButtonClick, closeSelf)

    local msg = getTargetMsg(task)
    self:child("Task-Progress-Targets-Lists"):SetText(msg)
end

function M:updateCommitPanel(task)
    self.currentTask = task
    self.commitPanel:SetVisible(true)
    self.maskBg:SetVisible(true)

    local name = task.fullName
    self:child("Task-Commit-TitleName"):SetText(getLangText(name, "accomplish.title", "task.accomplish.tip.title"))
    self:child("Task-Content-Task-Task"):SetText(getLangText(name, "acceptable.commit", "task.accomplish.commit.task"))
    self:child("Task-Content-Task-Name"):SetText(getLangText(name, "name", task.name))
    self:child("Task-Commit-Reward-Name"):SetText(getLangText(name, "get.reward.name", "task.accomplish.get.reward.name"))
    self:showRewardItems(task.reward, self:child("Task-Commit-Reward-Lists"), task.group)

    local commitBtn = self:child("Task-Commit-Btn")
    commitBtn:SetText(getLangText(name, "task.tip.btn", "task.tip.btn"))
    self:unsubscribe(commitBtn)
    self:subscribe(commitBtn, UIEvent.EventButtonClick, function()
        self:onClickCommitBtn(name)
    end)

    local closeBtn = self:child("Task-Commit-Close")
    self:unsubscribe(closeBtn)
    self:subscribe(closeBtn, UIEvent.EventButtonClick, function()
        self:closeWindow(self.commitPanel)
    end)
end

function M:registerSimpleBtn(noProc, yesProc)
    self.maskBg:SetVisible(true)
    self:unsubscribe(self.simpleNoBtn)
    if noProc and type(noProc) == "function" then
        self:subscribe(self.simpleNoBtn, UIEvent.EventButtonClick, function()
            noProc()
        end)
    end
    self:unsubscribe(self.simpleYesBtn)
    if yesProc and type(yesProc) == "function" then
        self:subscribe(self.simpleYesBtn, UIEvent.EventButtonClick, function()
            yesProc()
        end)
    end
end

function M:updateTipPanel(msg)
    if not self.simplePanel then
        return
    end
    self.simplePanel:SetVisible(true)
    self.simpleDesc:SetText(Lang:toText(msg))
    local function noProc()
        self:closeWindow(self.simplePanel)
    end
    self:registerSimpleBtn(noProc, noProc)
end

function M:onClickAcceptBtn(name)
    Me:startTask(name, function(res)
        if res.ok then
            local index = getItemIndexByList(self, name)
            if index and self.currentTask then
                local container = self.taskList:getContainerWindow()
                local listItem = container:GetChildByIndex(index)
                self:updateTaskItem(listItem, self.currentTask)
            end
        else
            self:updateTipPanel(res.msg, name)
        end
        self:closeWindow(self.getTaskPanel)
    end)
end

function M:onClickCommitBtn(name)
    Me:finishTask(name, function(res)
        if res.ok then
            local index = getItemIndexByList(self, name)
            if index then
                self:updateMainPanel()
            end
            Me:removeTaskTrace()
        else
            self:updateTipPanel(res.msg, name)
        end
        self:closeWindow(self.commitPanel)
    end)
end

return M