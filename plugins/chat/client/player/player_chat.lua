local Player = Player
function Player:getVoiceCardTime()
    self:sendPacket({pid = "GetVoiceCardTime"})
end

function Player:isFriendShip(platformUserId)

    print("-------------isFriendShip-----"..platformUserId.." -----------------",Lib.v2s(FriendManager.friendsMap))
    print("-------------isFriendShip-----"..platformUserId.." -----------------",Lib.v2s(FriendManager.friendsMap))
    return FriendManager.friendsMap[platformUserId]
end