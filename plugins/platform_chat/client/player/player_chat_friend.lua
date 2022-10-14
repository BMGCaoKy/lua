--- @type Player
local Player = Player
local handles = T(Player, "PackageHandlers")
local chatSetting = World.cfg.chatSetting or {}
local operationType = FriendManager.operationType
-- 初始化客户端好友数据
function Player:initClientFriendInfo()
    if self.allFriendData then
        return
    end

    -- 缓存的好友列表
    if not self.existFriendList then
        self.existFriendList = {}
    end

    self.allFriendData = {}        --所有好友（只保存了一页的数据）
    self.allFriendData[Define.chatFriendType.game] = {}        --同玩好友
    self.allFriendData[Define.chatFriendType.game].dataList = {}
    self.allFriendData[Define.chatFriendType.platform] = {}        --非同玩好友
    self.allFriendData[Define.chatFriendType.platform].dataList = {}

    local player = Game.GetPlayerByUserId(Me.platformUserId)
    local language = "en_US"
    if player then
        local userCache = UserInfoCache.GetCache(Me.platformUserId)
        language = userCache and userCache.language or 'en_US'
    end
    self.allFriendData.language = language
end

-- 更新服务端好友列表
function Player:updateClientFriendDataList(friendType)
    if not  UI:getWnd("chatMain").firstGetFriendData then  -- 第一次拿好友数据的时候，先刷新界面
        Lib.emitEvent(Event.EVENT_UPDATE_FRIEND_LIST_SHOW, Define.chatFriendType.game)
        Lib.emitEvent(Event.EVENT_UPDATE_FRIEND_LIST_SHOW, Define.chatFriendType.platform)
    end
    self:doRequestServerFriendInfo(friendType,0 )
end

function Player:doRequestServerFriendInfo(friendType, pageNum)
    if not self.allFriendData then
        self:initClientFriendInfo()
    end
    local requestType = friendType or Define.chatFriendType.game
    local requestPage = 0
    if pageNum then
        requestPage = pageNum
    elseif self.allFriendData[requestType] and self.allFriendData[requestType].pageNo then
        requestPage = self.allFriendData[requestType].pageNo
    end
    self:requestWebFriendInfo(requestType , requestPage)
end

function Player:requestWebFriendInfo(type, requestPage)
    local pageSize = Define.friendOnceRequestNum
    local pageNo = requestPage
    if pageNo < 0 then
        pageNo = 0
    end
    AsyncProcess.ClientGetChatFriendWithGameId(self.allFriendData.language, type, pageNo, pageSize, function(data)
        -- 平台数据是0~totalPage-1， 和0~totalSize-1
        self.allFriendData[type].totalPage = data.totalPage
        self.allFriendData[type].totalSize = data.totalSize
        self.allFriendData[type].pageNo = data.pageNo
        self.allFriendData[type].dataList = {}
        for _, val in pairs(data.data) do
            table.insert(self.allFriendData[type].dataList, val)
            if type == Define.chatFriendType.game then
                Me:addPlayerFriendFromExist(val.userId, Define.friendStatus.gameFriend)
            else
                Me:addPlayerFriendFromExist(val.userId, Define.friendStatus.platformFriend)
            end
        end

        if Define.chatFriendType.game == type then
            Me:updateConditionAutoCounts(Define.tagConditionType.friend, data.totalSize)
        end

        -- 在线的在前面
        table.sort(self.allFriendData[type].dataList, function(a, b)
            return a.status < b.status
        end)
        Lib.emitEvent(Event.EVENT_UPDATE_FRIEND_LIST_SHOW, type)
        if #self.allFriendData[type].dataList <= 0 then
            return
        end
    end)
end

-- 重载引擎好友操作请求，操作成功，web的回调返回
function Player:friendOperactionNotice(targetUserId, opType)
    if opType == operationType.AGREE then -- 同意别人的好友申请
        Me:doRequestServerFriendInfo(Define.chatFriendType.game)
        Me:doRequestServerFriendInfo(Define.chatFriendType.platform)
        Me:addPlayerFriendFromExist(targetUserId, Define.friendStatus.gameFriend)
    --elseif opType == operationType.REFUSE then --拒绝的FriendManager里面有操作
    --    AsyncProcess.LoadUserRequests()
    elseif opType == operationType.DELETE then -- 删除好友
        Me:doRequestServerFriendInfo(Define.chatFriendType.game)
        Me:doRequestServerFriendInfo(Define.chatFriendType.platform)
        Me:removePlayerFriendFromExist(targetUserId)
    end

    if opType == operationType.ADD_FRIEND then
        Plugins.CallTargetPluginFunc("fly_tips", "pushNormalFlyTipsItem", Lang:toText("ui.chat.friend.send_add"))
    end
    self:sendPacket({
        pid = "FriendOperactionNotice",
        targetUserId = targetUserId,
        operationType = opType,
    })
end

-- 删除好友成功， 从好友缓存中移除
function Player:removePlayerFriendFromExist(userId)
    if not self.existFriendList then
        self.existFriendList = {}
    end
    self.existFriendList[userId] = nil
    self:updateServerExistFriendList(userId, Define.friendStatus.notFriend)
end

-- 添加好友成功， 从好友缓存中增加
-- status 0:非好友，1:仅平台好友，2:同玩好友
function Player:addPlayerFriendFromExist(userId, status)
    if not self.existFriendList then
        self.existFriendList = {}
    end
    if self.existFriendList[userId] ~= status then
        self.existFriendList[userId] = status or Define.friendStatus.gameFriend
        self:updateServerExistFriendList(userId, status)
    end
end

-- 查询当前玩家是否我的好友
-- existFriendList[userId] 0:非好友，1:仅平台好友，2:同玩好友
function Player:checkPlayerIsMyFriend(userId)
    if not self.allFriendData then
        self:initClientFriendInfo()
    end
    if not self.existFriendList then
        self.existFriendList = {}
    end
    if self.existFriendList[userId] then
        return self.existFriendList[userId]
    end
    for key, val in pairs(self.allFriendData[Define.chatFriendType.game].dataList) do
        if tonumber(userId) == tonumber(val.userId) then
            self.existFriendList[userId] = Define.friendStatus.gameFriend
            return self.existFriendList[userId]
        end
    end

    for key, val in pairs(self.allFriendData[Define.chatFriendType.platform].dataList) do
        if tonumber(userId) == tonumber(val.userId) then
            self.existFriendList[userId] = Define.friendStatus.platformFriend
            return self.existFriendList[userId]
        end
    end
    return Define.friendStatus.notFriend
end

-- 客户端主动推送的好友列表数据
function handles:PushClientExistFriendList(packet)
    if not self.existFriendList then
        self.existFriendList = {}
    end
    for userId, val in pairs(packet.existFriendList) do
        self.existFriendList[userId] = val
    end
end

-- 通知服务端同步好友列表
function Player:updateServerExistFriendList(userId, status)
    Me:sendPacket({
        pid = "UpdateServerExistFriendList",
        userId = userId,
        status = status
    })
end