local queue = {}
local showing = false
local showTimer, modName, regId
local closing

function M:init()
    WinBase.init(self, "SlidingPrompt.json", true)

    self.queueNum = self:child("SlidingPrompt-Num-Text")
    self.lifeSpanProgress = self:child("SlidingPrompt-CountDown")

    self.headIcon = self:child("SlidingPrompt-Head-Icon")
    self.nameText = self:child("SlidingPrompt-Name")
    self.infoText = self:child("SlidingPrompt-Info")
    self.descText = self:child("SlidingPrompt-Desc")

    self.count_down_text = self:child("SlidingPrompt-CountDown-Text")
    self.count_down_text:SetText("")

    self.refuseBtn = self:child("SlidingPrompt-Refuse")
    self:subscribe(self.refuseBtn, UIEvent.EventButtonClick, function()
        if not closing then
            self:refuse()
        end
    end)
    self.agreeBtn = self:child("SlidingPrompt-Agree")
    self:subscribe(self.agreeBtn, UIEvent.EventButtonClick, function()
        if not closing then
            self:agree()
        end
    end)

    Lib.subscribeEvent(Event.ENTITY_CLEAR_SLIDING_PROMPT, function(key, value)
        self:clearPrompt(key, value)
    end)
end

function M:loadPrompt(data)
    if showing then
        --正在展示中，加入队列
        table.insert(queue, data)
    else
        -- 此时无展示，开始展示
        self:startPrompt(data)
    end
end

function M:startPrompt(data)
    showing = true
    modName = data.modName
    regId = data.regId
    local root = self:root()
    local width = root:GetPixelSize().x
    root:SetXPosition({ 0, -width })
    local cache = UserInfoCache.GetCache(data.fromId) or {}
    if cache.picUrl and #cache.picUrl > 0 then
        self.headIcon:SetImageUrl(cache.picUrl)
    else
        self.headIcon:SetImage("set:default_icon.json image:header_icon")
    end
    local name = Lang:toText(data.nameArg)
    self.nameText:SetText(#name > 10 and string.sub(name, 1, 10) .. "..." or name)
    self.infoText:SetText(Lang:toText(data.infoArg))
    self.descText:SetText(Lang:toText(data.descArg))
    UILib.uiTween(root, { X = { 0, 5 } }, 5, function()
        self:showPrompt(data.lifeSpan or 80)
    end)
end

function M:showPrompt(lifeSpan)
    local root = self:root()
    local width = root:GetPixelSize().x
    local time = lifeSpan
    showTimer = Me:timer(1, function()
        time = time - 1
        self.lifeSpanProgress:SetProgress(lifeSpan/time)
        if time <= 0 then
            closing = true
            Me:doCallBack(modName, "untreated", regId)
            UILib.uiTween(root, { X = { 0, -width } }, 5, function()
                closing = false
                self:nextPrompt()
            end)
            self.count_down_text:SetText("")
            return false
        end
        self.count_down_text:SetText(math.ceil(time/20) .. "s")
        return true
    end)
end

function M:nextPrompt()
    -- 上一个展示完成，准备下一个展示
    if #queue == 0 then
        showing = false
        UI:closeWnd(self)
        return
    end
    self:startPrompt(queue[1])
    table.remove(queue, 1)
end

function M:clearPrompt(key, value)
    if not key or not value then
        queue = {}
    end
    for i, d in ipairs(queue) do
        if d[key] == value then
            table.remove(queue, i)
        end
    end
end

function M:refuse()
    -- 拒绝请求
    local root = self:root()
    local width = root:GetPixelSize().x
    if showTimer then
        showTimer()
        showTimer = nil
        closing = true
        UILib.uiTween(root, { X = { 0, -width } }, 3, function()
            closing = false
            self:nextPrompt()
        end)
    end
    Me:doCallBack(modName, "refuse", regId)
end

function M:agree()
    -- 同意请求
    local root = self:root()
    local width = root:GetPixelSize().x
    if showTimer then
        showTimer()
        showTimer = nil
        closing = true
        UILib.uiTween(root, { X = { 0, -width } }, 3, function()
            closing = false
            self:nextPrompt()
        end)
    end
    Me:doCallBack(modName, "agree", regId)
end