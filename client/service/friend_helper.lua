local FriendHelper = {}

function FriendHelper:isFriend(userId)
    return FriendManager.friendsMap and  FriendManager.friendsMap[userId] and true or false
end

function FriendHelper:requestAddFriend(userId)
    return not self:isFriend(userId) and AsyncProcess.FriendOperation(FriendManager.operationType.ADD_FRIEND, userId)
end

function FriendHelper:getFriendsOnLine()
    local infoTb = {}
    local onLinePlayer = {}
    for _, playerInfo in pairs(Game.GetAllPlayersInfo() or {}) do
        local userId = playerInfo.userId
        onLinePlayer[userId] = 1
    end
    for i, userId in ipairs(FriendManager.friends or {}) do
        infoTb[userId] = onLinePlayer[userId] and UserInfoCache.GetCache(userId)  or nil
    end
    return infoTb
end

RETURN(FriendHelper)
