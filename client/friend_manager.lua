local self = FriendManager
local gameId = World.GameName

local CdTime = {
    INVITE = World.cfg.inviteCdSecond or 60,
    ADD_FRIEND = World.cfg.addFriendCdSecond or 60,
    VISIT = World.cfg.visitCdSecond or 0,
}

local OpTime = {
    INVITE = {},
    ADD_FRIEND = {},
    VISIT = {}
}

function FriendManager.Init()
    self.friends = {}
    self.friendsMap = {}
    self.friendPlayed = {}
    self.requests = {}
    self.centerFriends = {}
    self.operationType = {
        AGREE = "AGREE",
        REFUSE = "REFUSE",
        INVITE = "INVITE",
        VISIT = "VISIT",
        DELETE = "DELETE",
        ADD_FRIEND = "ADD_FRIEND",
    }
    local op = self.operationType
    Lib.subscribeEvent(Event.EVENT_FRIEND_OPERATION_CLIENT, function(opType, userId)
        Me:friendOperactionNotice(userId, opType)
        if opType == op.AGREE then
            AsyncProcess.LoadFriend()
            AsyncProcess.LoadUserRequests()
        elseif opType == op.REFUSE then
            AsyncProcess.LoadUserRequests()
        elseif opType == op.DELETE then
            AsyncProcess.LoadFriend()
        end
    end)
    Lib.subscribeEvent(Event.EVENT_FRIEND_OPERACTION_ADD_FRIEND, function(objID)
        local player = World.CurWorld:getObject(objID)
        if not player then
            return
        end
        assert(player.isPlayer)
        AsyncProcess.FriendOperation(op.ADD_FRIEND, player.platformUserId)
    end)
end

function FriendManager.ParseFriendData(data)
    local friends = {}
    local friendsMap = {}
    local friendPlayed = {}
    for _, member in pairs(data.data) do
        local userId = member.userId
        friends[#friends + 1] = userId
        friendsMap[userId] = true
        friendPlayed[userId] = member.played or {}
    end
    self.friends = friends
    self.friendsMap = friendsMap
    self.friendPlayed = friendPlayed
    UserInfoCache.UpdateUserInfos(data.data, true)
    Lib.emitEvent(Event.EVENT_FINISH_LOAD_FRIEND_DATA)
end

function FriendManager.ParseUserRequests(data)
    local requests = {}
    for _, member in pairs(data.data) do
        local userId = member.userId
        --0 untreated, 1 agreed, 2 rejected
        if member.status == 0 and userId > 0 then
            member.nickName = Lib.reconstructName(member.nickName, member.colorfulNickName)
            requests[userId] = member
        end
    end
    self.requests = requests
    Lib.emitEvent(Event.EVENT_FINISH_PARSE_REQUESTS_DATA)
end

function FriendManager.LoadFriendData(needReload)
    local friends = self.friends
    if #friends == 0 then
        needReload = true
    end
    if needReload then
        AsyncProcess.LoadFriend()
    else
        UserInfoCache.LoadCacheByUserIds(friends, "EVENT_FINISH_LOAD_FRIEND_DATA")
    end
end

function FriendManager.ReceiveCenterFriend(friends)
    self.centerFriends = friends
    Lib.emitEvent(Event.EVENT_CENTER_FRIEND_LOAD, friends)
end

local function isOutOfCdTime(opType, id)
    local osTime = os.time()
    local opTime = OpTime[opType][tostring(id)] or osTime
    return opTime <= osTime
end

function FriendManager.CanInvite(id)
    return isOutOfCdTime(self.operationType.INVITE, id)
end

function FriendManager.CanAddFriend(id)
    return isOutOfCdTime(self.operationType.ADD_FRIEND, id)
end

function FriendManager.CanVisit(id)
    return isOutOfCdTime(self.operationType.VISIT, id)
end

function FriendManager.UpdateCdTime(id, opType)
    if not OpTime[opType] or not CdTime[opType] or CdTime[opType] == 0 then
        return
    end
    OpTime[opType][tostring(id)] = os.time() + CdTime[opType]
end

function FriendManager.GetLastCdTime(id, opType)
    local opTime = OpTime[opType][tostring(id)] or os.time()
    return opTime - os.time()
end

---判断是否是未处理的请求
function FriendManager.IsNotProcessFriendRequest(id)
    local request = self.requests[id]
    if not request then
        return false
    end
    return request.status == 0
end

function FriendManager.ChangeFriendRequestStatus(id, status)
    local request = self.requests[id]
    if not request then
        return
    end
    request.status = status
end