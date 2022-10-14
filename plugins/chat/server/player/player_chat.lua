local Player = Player


function Player:checkVoiceMoonEnable()
    local mac = self:getSoundMoonCardMac()
    if mac == 0 then
        return false

    elseif mac - os.time() < 0 then
        self:setValue("soundMoonCard", 0)
        return false
    else
        return true
    end
end

function Player:addMoonCard(reward)
    if self:getSoundMoonCardMac() == 0 then
        self:setValue("soundMoonCard", (reward) * 30 * 24 * 3600 + os.time())
    else
        self:setValue("soundMoonCard",
                      (reward) * 30 * 24 * 3600 + self:getSoundMoonCardMac())
    end
end

function Player:addVoiceCnt(reward)
    self:setValue("soundTimes", self:getSoundTimes() + reward)
end

function Player:getVoiceCardTime()
    local mac = self:getSoundMoonCardMac()
    if mac == 0 then
        return -1
    else
        return math.max(-1, mac - os.time())
    end
end

function Player:sendChatMsg(packet, isBroadcast)
    if isBroadcast then
        WorldServer.BroadcastPacket(packet)
    else
        self:sendPacket(packet)
    end
end

function Player:sendServerChat(langMsg, type, targetId, targetName)
    self:sendChatMsg({
        pid = langMsg.platId and "ChatMessagePrivateSelf" or "ChatMessage" ,
        fromname = targetName and targetName or "ui.chat.system",
        msg = langMsg.text,
        args = table.pack(targetId and targetId or self.objID, Define.ChatPlayerType.server,type),
        msgPack = langMsg.textPack,
        targetUserId = langMsg.platId
    })
end

function Player:isFriendShip(objId)
    local playerData = self.playerDataMap[objId]
    if not playerData then return end
    return playerData.isFriend
end

function Player:initVoiceInfo(info)
    if info.expiryDateLong and tonumber(info.expiryDateLong) > 0 then
        self:setValue("soundMoonCard",tonumber(info.expiryDateLong) )
    end
    if info.times and tonumber(info.times) > 0 then
        self:setValue("soundTimes",tonumber(info.times) )
    end
    if info.freeTimes and tonumber(info.times) > 0 then
        self:setValue("freeSoundTimes",tonumber(info.times) )
    end
end