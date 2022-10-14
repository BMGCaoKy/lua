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

-- 更新语音聊天次数
function Player:updateVoiceCounts()
    if not self:checkVoiceMoonEnable() then
        -- 优先消耗免费喇叭，然后再消费付费喇叭
        if self:getFreeSoundTimes() > 0 then
            self:useFreeSoundTimes()
        else
            if self:getSoundTimes() > 0 then
                self:useSoundTimes()
            end
        end
    end
end

-- 检测是否还有语音聊天次数
function Player:checkCanSendVoice()
    if not self:checkVoiceMoonEnable() and self:getSoundTimes() < 1 and self:getFreeSoundTimes() < 1 then
        local packet = {
            pid = "ChatSystemMessage",
            msg = "ui.chat.voiceless",
            isLang = true,
            args = table.pack(nil, nil, Define.Page.SYSTEM),
        }
        self:sendChatMsg(packet, true)
        return false
    end
    return true
end

--------------------------------------------------
-----业务重载
----------------------------------------------------
-- 获得职业id
function Player:getCareerId()
    return 0
end