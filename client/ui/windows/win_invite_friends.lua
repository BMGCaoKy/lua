local loadFriends = {}
local searchFriends = {}
local needLoadInfoUserIds = {}
local waitLoadInfo = {}
local abandon = {}
local search_abandon = {}
local searching = false
local modName, regId
local cacheTime = 0

local function getFriendItem()
    local wnd = abandon[1]
    if wnd then
        table.remove(abandon, 1)
        return wnd
    end
    return GUIWindowManager.instance:CreateWindowFromTemplate("GameCenter", "InviteFriendsItem.json")
end

local sortRule = World.cfg.centerFriendSortRule or {}
function M:init()
    WinBase.init(self, "InviteFriends.json", true)

    self:child("InviteFriends-Title"):SetText(Lang:toText("invite.friend.title"))
    self.friends_content = self:child("InviteFriends-Friends")
    self.friends_content:InitConfig(10, 10, 2)
    --self.friends_content:SetAutoColumnCount(false)

    self.content_tip = self:child("InviteFriends-Content-Tip")
    self.content_tip:SetVisible(false)
    self.content_tip_text = self:child("InviteFriends-Tip-Text")
    self.content_tip_text:SetText(Lang:toText("no.friend.tip"))

    self.clean_search_text_btn = self:child("InviteFriends-Text-Clean")
    self.clean_search_text_btn:SetVisible(false)
    self:subscribe(self.clean_search_text_btn, UIEvent.EventButtonClick, function()
        self.search_input:SetText("")
        self:search("")
    end)
    self.search_input = self:child("InviteFriends-Text")
    self.search_input:SetTextHorzAlign(0)
    self.search_tip = self:child("InviteFriends-Tip")
    self.search_tip:SetText(Lang:toText("search.input.tip"))
    self.search_result_tip = self:child("InviteFriends-Result-Tip")
    self.search_result_tip:SetText("")
    --
    self:subscribe(self.search_input, UIEvent.EventWindowTextChanged, function()
        local text = self.search_input:GetPropertyString("Text", "")
        text = string.gsub(text, "^%s*(.-)%s*$", "%1")
        self.clean_search_text_btn:SetVisible(#text > 0)
        self.search_tip:SetText(#text > 0 and "" or Lang:toText("search.input.tip"))
    end)

    self:subscribe(self:child("InviteFriends-Btn"), UIEvent.EventButtonClick, function()
        -- 搜索好友
        local text = self.search_input:GetPropertyString("Text", "")
        text = string.gsub(text, "^%s*(.-)%s*$", "%1")
        self:search(text)
    end)
    self:subscribe(self:child("InviteFriends-Close-Bg"), UIEvent.EventWindowClick, function()
        UI:closeWnd(self)
    end)
    self:subscribe(self:child("InviteFriends-Close"), UIEvent.EventButtonClick, function()
        UI:closeWnd(self)
    end)

    Lib.subscribeEvent(Event.EVENT_CENTER_INFO_UPDATE, function()
        -- 请求玩家信息回调，更新头像信息
        self:loadHeadInfo()
    end)
end

function M:onOpen(data)
    modName, regId = data.modName, data.regId
    self.content_tip:SetVisible(not searching and self.friends_content:GetItemCount() == 0)
    if cacheTime < World.Now() then
        Me:sendPacket({
            pid = "RequestCenterFriends"
        })
        cacheTime = World.Now() + 10
    end
end

function M:registerEvent(wnd)
    local inviteBtn = wnd:child("GameCenter_InviteFriendsItem-Invite")
    local inviteIcon = wnd:child("GameCenter_InviteFriendsItem-Icon")
    local inviteText = wnd:child("GameCenter_InviteFriendsItem-Text")
    self:subscribe(inviteBtn, UIEvent.EventButtonClick, function()
        if not inviteBtn:IsEnabled() then
            return
        end
        local info = wnd:data("info")
        if modName and regId then
            Me:doCallBack(modName, "key", regId, {
                serverId = info.serverId,
                inviteeId = info.id,
                together = info.together,
                info = info,
            }
            )
        end
        inviteBtn:setEnabled(false)
        inviteIcon:SetVisible(false)
        local num = 100
        inviteText:SetText(math.ceil(num / 20))
        inviteText:SetVisible(true)
        World.Timer(1, function()
            num = num - 1
            if num <= 0 then
                inviteBtn:setEnabled(true)
                inviteIcon:SetVisible(true)
                inviteText:SetVisible(false)
                inviteBtn:setMask(0,0.8, 0.5)
                return false
            end
            inviteBtn:setMask(num / 100, 0.8, 0.5)
            inviteText:SetText(math.ceil(num / 20))
            return true
        end)
    end)
end

function M:loadFriendDataWindow(info)
    local id = info.id
    local friendItem = getFriendItem()
    friendItem:SetWidth({ 0, self.friends_content:GetPixelSize().x / 2 - 10 })
    local headIcon = friendItem:child("GameCenter_InviteFriendsItem-HeadIcon")
    local name = friendItem:child("GameCenter_InviteFriendsItem-Name")
    local desc = friendItem:child("GameCenter_InviteFriendsItem-Desc")
    local cache = UserInfoCache.GetCache(id) or {}
    if not next(cache) then
        table.insert(needLoadInfoUserIds, id)
    end
    if cache.picUrl and #cache.picUrl > 0 then
        headIcon:SetImageUrl(cache.picUrl)
    else
        headIcon:SetImage("set:default_icon.json image:header_icon")
    end
    local friendName = info.name
    name:SetText(#friendName >10 and string.sub(friendName,1,10) .. "..." or friendName)
    local descInfo = info.data or {}
    local cfg = Entity.GetCfg(descInfo.cfg)
    local str = ""
    local values = descInfo.values
    for i, _info in ipairs(cfg[descInfo.cfgName] or {}) do
        str = str .. (_info.langKey and Lang:toText({ _info.langKey, values[i] }) or " ")
    end
    desc:SetText(str)
    self:registerEvent(friendItem)
    return friendItem
end

local function loadCacheUserIds()
    if #needLoadInfoUserIds > 0 then
        UserInfoCache.LoadCacheByUserIds(needLoadInfoUserIds, "EVENT_CENTER_INFO_UPDATE")
        waitLoadInfo = needLoadInfoUserIds
        needLoadInfoUserIds = {}
    end
end

function M:onLoad(friends)
    -- 加载所有好友信息
    local sortFriend = {}
    for _, data in pairs(friends or {}) do
        table.insert(sortFriend, data)
    end
    table.sort(sortFriend, function(f1, f2)
        local f1_info, f2_info = f1.data, f2.data
        for _, key in ipairs(sortRule) do
            local v1, v2 = f1_info.values[key], f2_info.values[key]
            if not v1 or not v2 then
            elseif v1 > v2 then
                return true
            elseif v1 < v2 then
                return false
            end
        end
        if f1.name < f2.name then
            return true
        end
        return false
    end)
    local count = self.friends_content:GetItemCount()
    for i = 1, math.max(#sortFriend, count) do
        local wnd = count > i and self.friends_content:GetItem(i - 1)
        local oldInfo = wnd and wnd:data("info")
        local info = sortFriend[i]
        self:onUpdate((info and info.id) or (oldInfo and oldInfo.id), info)
    end
    self.content_tip:SetVisible(self.friends_content:GetItemCount() == 0)
    loadCacheUserIds()
end

local function calcPosition(friendsContent, info)
    local count = friendsContent:GetItemCount()
    for i = 0, count - 1 do
        local item = friendsContent:GetItem(i)
        if not item then
            return i
        end
        local i_info = item:data("info")
        local data, i_data = info.data, i_info.data
        for _, key in ipairs(sortRule) do
            local v1, v2 = data.values[key], i_data.values[key]
            if v1 > v2 then
                return i
            end
        end
        if info.name < i_info.name then
            return i
        end
    end
end

function M:onUpdate(userId, info)
    local wnd = loadFriends[userId]
    if wnd and not info then
        -- 好友退出，删除信息
        loadFriends[userId] = nil
        self.friends_content:RemoveItem(wnd)
        wnd:setData("info")
        table.insert(abandon, wnd)
        self.content_tip:SetVisible(not searching and self.friends_content:GetItemCount() == 0)
        return
    elseif not wnd and info then
        -- 好友登陆，添加信息
        wnd = getFriendItem()
        self:registerEvent(wnd)
        local index = calcPosition(self.friends_content, info)
        self.friends_content:AddItem(wnd, index)
        loadFriends[userId] = wnd
    elseif not wnd and not info then
        return
    end
    wnd:SetWidth({ 0, self.friends_content:GetPixelSize().x / 2 - 10 })
    --更新信息
    self.content_tip:SetVisible(not searching and self.friends_content:GetItemCount() == 0)
    wnd:setData("info", info)
    local headIcon = wnd:child("GameCenter_InviteFriendsItem-HeadIcon")
    local name = wnd:child("GameCenter_InviteFriendsItem-Name")
    local desc = wnd:child("GameCenter_InviteFriendsItem-Desc")
    local cache = UserInfoCache.GetCache(userId) or {}
    if not next(cache) then
        table.insert(needLoadInfoUserIds, userId)
    end
    if cache.picUrl and #cache.picUrl > 0 then
        headIcon:SetImageUrl(cache.picUrl)
    else
        headIcon:SetImage("set:default_icon.json image:header_icon")
    end
    local friendName = info.name
    name:SetText(#friendName >10 and string.sub(friendName,1,10) .. "..." or friendName)
    local descInfo = info.data or {}
    local cfg = Entity.GetCfg(descInfo.cfg)
    local str = ""
    local values = descInfo.values
    for i, _info in ipairs(cfg[descInfo.cfgName] or {}) do
        str = str .. (_info.langKey and Lang:toText({ _info.langKey, values[i] }) or " ")
    end
    desc:SetText(str)
end

local function content_match(txt, mTxt)
    mTxt = mTxt or ""
    if #mTxt == 0 then
        return true
    end
    return string.find(txt, mTxt)
end

function M:search(txt)
    for i, wnd in pairs(search_abandon) do
        local info = wnd:data("info")
        if #txt == 0 or (info and (content_match(info.name, txt) or content_match(tostring(info.id), txt))) then
            local index = calcPosition(self.friends_content, info)
            self.friends_content:AddItem(wnd, index)
            loadFriends[info.id] = wnd
            table.remove(search_abandon, i)
        end
    end
    if #txt == 0 then
        searching = false
        self.search_result_tip:SetText("")
        self.content_tip:SetVisible(not searching and self.friends_content:GetItemCount() == 0)
        return
    end
    searching = true
    local count = self.friends_content:GetItemCount()
    local index = count - 1
    local wnd = index >= 0 and self.friends_content:GetItem(index)
    while wnd do
        local info = wnd:data("info")
        if not (content_match(info.name, txt) or content_match(tostring(info.id), txt)) then
            loadFriends[info.id] = nil
            self.friends_content:RemoveItem(wnd)
            table.insert(search_abandon, 1, wnd)
        end
        index = index - 1
        wnd = index >= 0 and self.friends_content:GetItem(index)
    end
    if self.friends_content:GetItemCount() == 0 then
        self.search_result_tip:SetText(Lang:toText("search.result.tip"))
    else
        self.search_result_tip:SetText("")
    end
    self.content_tip:SetVisible(not searching and self.friends_content:GetItemCount() == 0)
end

function M:loadHeadInfo()
    for _, userId in pairs(waitLoadInfo) do
        local wnd = loadFriends[userId]
        if wnd then
            local headIcon = wnd:child("GameCenter_InviteFriendsItem-HeadIcon")
            local cache = UserInfoCache.GetCache(userId) or {}
            if cache.picUrl and #cache.picUrl > 0 then
                headIcon:SetImageUrl(cache.picUrl)
            else
                headIcon:SetImage("set:default_icon.json image:header_icon")
            end
        end
    end
    waitLoadInfo = {}
    loadCacheUserIds()
end

function M:onClose()
    self.friends_content:ResetPos()
    self.search_input:SetText("")
    self:search("")
    modName, regId = nil, nil
end

return M