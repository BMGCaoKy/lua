local handles = T(Player, "PackageHandlers")
---@type VoiceShopConfig
local VoiceShopConfig = T(Config, "VoiceShopConfig")

function handles:ChatMessage(packet)
    local msg = packet.msg
    if not msg or utf8.len(msg) > 1000 then
        return
    end

    if packet.voiceTime and not self:checkCanSendVoice() then
        return
    end

    if not packet.voiceTime then
        msg = World.CurWorld:filterWord(packet.msg)
    end

    local type = "msg"
    if packet.voiceTime then
        type = "voice"
    elseif packet.emoji then
        type = "emoji"
    end
    Trigger.CheckTriggers(self:cfg(), "SEND_CHAT_MESSAGE", { obj1 = self, msg = msg, msgType = type })

	local dg = nil
    local packet = {
        pid = "ChatMessage",
        fromname = self.name,
        msg = msg,
        voiceTime = packet.voiceTime,
        emoji = packet.emoji or false,
        args = table.pack(self.objID,dg, Define.Page.COMMON, self.platformUserId),
    }
    self:sendChatMsg(packet, true)

    if packet.voiceTime then
        self:updateVoiceCounts()
    end
    self:addConditionAutoCounts(Define.tagConditionType.talk, 1)
end

function handles:ChatMessageToFamily(packet)
	if not World.cfg.chatSetting or not World.cfg.chatSetting.familyVal or self:getValue(World.cfg.chatSetting.familyVal) ==0 then
		return
	end
	local msg = packet.msg
	if utf8.len(msg) > 1000 then
		return
	end
    if packet.voiceTime and not self:checkCanSendVoice() then
        return
    end


	if not packet.voiceTime then
		msg = World.CurWorld:filterWord(packet.msg)
	end
	local dg = false
	local familyParma = {}
	local familyId = self:getValue(World.cfg.chatSetting.familyVal)
	local backPacket = {
		pid = "ChatMessage",
		fromname = self.name,
		msg = msg,
		voiceTime = packet.voiceTime,
        emoji = packet.emoji or false,
		args = table.pack(self.objID,dg,Define.Page.FAMILY,self.platformUserId),
	}
	for _, entity in pairs(Game.GetAllPlayers()) do
		if entity.isPlayer and entity:getValue(World.cfg.chatSetting.familyVal)  == familyId then
			entity:sendChatMsg(backPacket)
		end
	end
	if packet.voiceTime then
        self:updateVoiceCounts()
	end
    self:addConditionAutoCounts(Define.tagConditionType.talk, 1)
end

function handles:ChatMessageToMap(packet)
    local msg = packet.msg
    if utf8.len(msg) > 1000 then
        return
    end
    if packet.voiceTime and not self:checkCanSendVoice() then
        return
    end

    if not packet.voiceTime then
        msg = World.CurWorld:filterWord(packet.msg)
    end
    local dg = false

    local backPacket = {
        pid = "ChatMessage",
        fromname = self.name,
        msg = msg,
        voiceTime = packet.voiceTime,
        emoji = packet.emoji or false,
        args = table.pack(self.objID,dg,Define.Page.MAP_CHAT,self.platformUserId),
    }

    local chatMapName = self.map.name
    if self.isInBattle and self:isInBattle() then
        chatMapName = self.battleLastMapName
    end
    for _, entity in pairs(Game.GetAllPlayers()) do
        if entity.isPlayer then
            local curMapName = entity.map.name
            if entity.isInBattle and entity:isInBattle() then
                curMapName = entity.battleLastMapName
            end
            if curMapName == chatMapName then
                entity:sendChatMsg(backPacket)
            end
        end
    end
    if packet.voiceTime then
        self:updateVoiceCounts()
    end
    self:addConditionAutoCounts(Define.tagConditionType.talk, 1)
end

function handles:ChatMessageToTeam(packet)
    local msg = packet.msg
    if utf8.len(msg) > 1000 then
        return
    end
    if packet.voiceTime and not self:checkCanSendVoice() then
        return
    end

    if not packet.voiceTime then
        msg = World.CurWorld:filterWord(packet.msg)
    end
    local dg = false

    local backPacket = {
        pid = "ChatMessage",
        fromname = self.name,
        msg = msg,
        voiceTime = packet.voiceTime,
        emoji = packet.emoji or false,
        args = table.pack(self.objID,dg,Define.Page.TEAM,self.platformUserId),
    }

    local teamInfoMe = self:getTeamInfo()
    for _, teamMate in pairs(teamInfoMe or {}) do
        local player = Game.GetPlayerByUserId(teamMate.userId)
        if player then
            player:sendChatMsg(backPacket)
        end
    end
    if packet.voiceTime then
        self:updateVoiceCounts()
    end
    self:addConditionAutoCounts(Define.tagConditionType.talk, 1)
end

function handles:ChatTeamInviteMsg(packet)
    local dg = false
    packet.teamInviteData.shoutContent = World.CurWorld:filterWord(packet.teamInviteData.shoutContent) or ""
    local backPacket = {
        pid = "ChatTeamInviteMsg",
        fromname = self.name,
        msg = "",
        voiceTime = false,
        emoji = false,
        args = table.pack(self.objID,dg,Define.Page.TEAM,self.platformUserId),
        teamInviteData = packet.teamInviteData
    }
    self:sendChatMsg(backPacket, true)
end

function handles:ChatMessageToSystem(packet)
    local msg = World.CurWorld:filterWord(packet.msg)
    if not msg or utf8.len(msg) > 1000 then
        return
    end

    local packet = {
        pid = "ChatSystemMessage",
        msg = msg,
        args = table.pack(nil, nil, Define.Page.SYSTEM),
        msgPack = packet.msgPack
    }
    self:sendChatMsg(packet, true)
end

function handles:ChatMessageToCareer(packet)
    local msg = packet.msg
    if utf8.len(msg) > 1000 then
        return
    end
    if packet.voiceTime and not self:checkCanSendVoice() then
        return
    end

    if not packet.voiceTime then
        msg = World.CurWorld:filterWord(packet.msg)
    end
    local dg = false
    local careerId = self:getCareerId()
    local backPacket = {
        pid = "ChatMessage",
        fromname = self.name,
        msg = msg,
        voiceTime = packet.voiceTime,
        emoji = packet.emoji or false,
        args = table.pack(self.objID,dg,Define.Page.CAREER,self.platformUserId),
    }
    for _, entity in pairs(Game.GetAllPlayers()) do
        if entity.isPlayer and entity:getCareerId()  == careerId then
            entity:sendChatMsg(backPacket)
        end
    end
    if packet.voiceTime then
        self:updateVoiceCounts()
    end
    self:addConditionAutoCounts(Define.tagConditionType.talk, 1)
end

-- pc测试玩家收到平台私聊消息
function handles:TestOtherPrivateMsg(packet)
    local player = Game.GetPlayerByUserId(packet.receiverUserId)
    if player then
        player:sendPacket(packet)
    end
end

function handles:GetVoiceCardTime(packet)
    self:sendPacket({
        pid = "GetVoiceCardTime",
        time = self:getVoiceCardTime()
    })
end

function handles:BuyVoice(packet)
    if not packet or not packet.idx then
        return
    end
    local cnt = VoiceShopConfig:getItemById(packet.idx).cost
    Lib.payMoney(self, 10000 + packet.idx, 0, cnt, function (success)
        self:sendPacket({pid = "BuyVoiceResult",isSucceed = success})
        if success then
            self:resetFreeSoundTimes()

            local reward = VoiceShopConfig:getItemById(packet.idx).num
            if reward > 0 then
                self:addVoiceCnt(reward)
            else
                self:addMoonCard(-reward)
            end
        else
            print("BuyVoice fail")
        end
    end,1,Define.ExchangeItemsReason.BuyVoice or 2)
end