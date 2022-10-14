
--- @type Player
local Player = Player
local handles = T(Player, "PackageHandlers")
--- @type PlayerSpInfoManager
local PlayerSpInfoManager = T(Lib, "PlayerSpInfoManager")
-- 登陆游戏请求好友列表
function Player:loginRequestFriendInfo()
    --self:initServerFriendDataList()
    self:initServerFriendUserIdList()
end

-- 初始化好友userID列表
function Player:initServerFriendUserIdList()
    if not self:isValid() then
        return
    end
    -- status 0:非好友，1:仅平台好友，2:同玩好友
    self.existFriendList = {}        --所有好友userId列表
    self:requestWebFriendUserIdList(Define.chatFriendType.platform)
    self:requestWebFriendUserIdList(Define.chatFriendType.game)
end

-- 向平台请求好友userId列表
function Player:requestWebFriendUserIdList(type)
    AsyncProcess.GetChatFriendUserIdWithGameId(self.platformUserId, type,function(data)
        local userIdList = {}
        for _, userId in pairs(data) do
            if Define.chatFriendType.game == type then
                self.existFriendList[userId] = Define.friendStatus.gameFriend
            elseif Define.chatFriendType.platform == type then
                self.existFriendList[userId] = Define.friendStatus.platformFriend
            end
            table.insert(userIdList, { userId = userId })
        end
        if Define.chatFriendType.game == type then
            PlayerSpInfoManager:playerInit(userIdList, self)
            self:pushClientExistFriendList()
        end
    end)
end

-- 好友总数
function Player:getPlayerFriendsNum(friendType)
    if not self.existFriendList then
        return 0
    end
    local totalNum = 0
    for _, type in pairs(self.existFriendList) do
        if friendType == type then
            totalNum = totalNum + 1
        end
    end
    return totalNum
end

-- 删除好友成功， 从好友缓存中移除
function Player:removePlayerFriendFromExist(userId)
    if not self.existFriendList then
        self.existFriendList = {}
    end
    self.existFriendList[userId] = nil
end

-- 添加好友成功， 从好友缓存中增加
-- status 0:非好友，1:仅平台好友，2:同玩好友
function Player:addPlayerFriendFromExist(userId, status)
    if not self.existFriendList then
        self.existFriendList = {}
    end
    self.existFriendList[userId] = status or Define.friendStatus.gameFriend
end

-- 查询当前玩家是否我的好友
-- existFriendList[userId] 0:非好友，1:仅平台好友，2:同玩好友
function Player:checkPlayerIsMyFriend(userId)
    if not self.existFriendList then
        self.existFriendList = {}
    end
    if self.existFriendList[userId] then
        return self.existFriendList[userId]
    end
    return Define.friendStatus.notFriend
end

-- 向客户端同步好友userId列表
function Player:pushClientExistFriendList()
    self:sendPacket({
        pid = "PushClientExistFriendList",
        existFriendList = self.existFriendList
    })
end

-- 客户端添加删除好友后同步过来的数据
function handles:UpdateServerExistFriendList(packet)
    if self.existFriendList and self.existFriendList[packet.userId] ~= packet.status then
        self.existFriendList[packet.userId] = packet.status
    end
end

-- 初始化好友列表
function Player:initServerFriendDataList()
    self.allFriendData = {}        --所有好友
    self.allFriendData[Define.chatFriendType.game] = {}        --同玩好友
    self.allFriendData[Define.chatFriendType.platform] = {}        --非同玩好友
    self.allFriendData[Define.chatFriendType.game].nearTimeList = {}
    self.allFriendData[Define.chatFriendType.platform].nearTimeList = {}

    local player = Game.GetPlayerByUserId(self.platformUserId)
    local language = "en_US"
    if player then
        local userCache = UserInfoCache.GetCache(self.platformUserId)
        language = userCache and userCache.language or 'en_US'
    end
    self.allFriendData.language = language
    self:updateFriendDataList()
end

-- 更新服务端好友列表
function Player:updateFriendDataList()
    self.allFriendData[Define.chatFriendType.game].dataList = {}
    self.allFriendData[Define.chatFriendType.platform].dataList = {}
    self.allFriendData[Define.chatFriendType.platform].getFriendIsEnd = false
    self.allFriendData[Define.chatFriendType.game].getFriendIsEnd = false
    self:requestFriendInfoPage(Define.chatFriendType.platform,0,  Define.friendOnceRequestNum)
    self:requestFriendInfoPage(Define.chatFriendType.game,0,  Define.friendOnceRequestNum)
end

-- 向平台请求好友数据
function Player:requestFriendInfoPage(type, pageNo, pageSize)
    if not self:isValid() then
        return
    end
    AsyncProcess.GetChatFriendWithGameId(self.platformUserId, self.allFriendData.language, type, pageNo, pageSize, function(data)
        -- 平台数据是0~totalPage-1， 和0~totalSize-1
        self.allFriendData[type].totalPage = data.totalPage
        self.allFriendData[type].totalSize = data.totalSize
        for _, val in pairs(data.data) do
            table.insert(self.allFriendData[type].dataList, val)
        end
        if pageNo < data.totalPage - 1 then
            self.allFriendData[type].getFriendIsEnd = false
            self:requestFriendInfoPage(type, pageNo + 1, pageSize)
        else
            self.allFriendData[type].getFriendIsEnd = true
            self:dealAsyncFriendInfo(type)
        end

        if Define.chatFriendType.game == type then
            self:updateConditionAutoCounts(Define.tagConditionType.friend, data.totalSize)
            --PlayerSpInfoManager:playerInit(self.allFriendData[type].dataList,self)
        end
    end)
end

-- 处理客户端需要显示的好友数据
function Player:dealAsyncFriendInfo(type)
    if not self.allFriendData[type].getFriendIsEnd then
        return
    end
    self.allFriendData[type].nearTimeList = {}
    for key, val in pairs(self.allFriendData[type].dataList) do
        --if os.time() - val.logoutTime > 0 then  --三个月以内上线过的玩家
        --    table.insert(self.allFriendData[type].nearTimeList, val)
        --end
        table.insert(self.allFriendData[type].nearTimeList, val)
    end

end
