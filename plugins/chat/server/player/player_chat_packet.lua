local handles = T(Player, "PackageHandlers")
---@type VoiceShopConfig
local VoiceShopConfig = T(Config, "VoiceShopConfig")
function handles:ChatMessage(packet)
    local msg = packet.msg
    if not msg or utf8.len(msg) > 1000 then
        return
    end

    if packet.voiceTime then
        if self.voiceChatTimes then
            self.voiceChatTimes = self.voiceChatTimes+1
        else
            self.voiceChatTimes = 1
        end

    else
        if self.textChatTimes then
            self.textChatTimes = self.textChatTimes+1
        else
            self.textChatTimes = 1
        end
    end

    if packet.voiceTime and not self:checkVoiceMoonEnable() and self:getSoundTimes() < 1 and self:getFreeSoundTimes() < 1 then
        self:sendPacket({pid = "ShowTip",  tipType = 1, keepTime = 40, textKey = "ui.chat.voiceless"})
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
	-- for _,v in pairs(self.vars.privilege) do
	-- 	if v == "myplugin/svip_privilege" then
	-- 		dg = Define.ChatPlayerType.svip
	-- 		break
	-- 	elseif v == "myplugin/vip_privilege" then
	-- 		dg = Define.ChatPlayerType.vip
	-- 	end
	-- end
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
end
function handles:ChatMessageToFamily(packet)
	if not World.cfg.chatSetting or not World.cfg.chatSetting.familyVal or self:getValue(World.cfg.chatSetting.familyVal) ==0 then
		return
	end
	local msg = packet.msg
	if utf8.len(msg) > 1000 then
		return
	end
	if packet.voiceTime and not self:checkVoiceMoonEnable() and self:getSoundTimes()<1 then
		-- self:sendChatMsg({
		-- 	pid = "ChatMessage",
		-- 	fromname = "",
		-- 	msg = "ui.chat.voiceless",
		-- 	args = table.pack(self.objID,Define.ChatPlayerType.server,Define.Page.FAMILY),
		-- })
        self:sendPacket({pid = "ShowTip",  tipType = 1, keepTime = 40, textKey = "ui.chat.voiceless"})
		return
    end

    if packet.voiceTime then
        if self.voiceChatTimes then
            self.voiceChatTimes = self.voiceChatTimes+1
        else
            self.voiceChatTimes = 1
        end

    else
        if self.textChatTimes then
            self.textChatTimes = self.textChatTimes+1
        else
            self.textChatTimes = 1
        end
    end

	if not packet.voiceTime then
		msg = World.CurWorld:filterWord(packet.msg)
	end
	local dg = false
	-- for _,v in pairs(self.vars.privilege) do
	-- 	if v == "myplugin/svip_privilege" then
	-- 		dg = Define.ChatPlayerType.svip
	-- 		break
	-- 	elseif v == "myplugin/vip_privilege" then
	-- 		dg = Define.ChatPlayerType.vip
	-- 	end
	-- end
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
		self:useSoundTimes()
	end
end

function handles:ChatMessageToPrivate(packet)
    local msg = packet.msg
    if utf8.len(msg) > 1000 then
        return
    end

    if packet.voiceTime and not self:checkVoiceMoonEnable() and self:getSoundTimes() < 1 and self:getFreeSoundTimes() < 1 then
        self:sendPacket({pid = "ShowTip",  tipType = 1, keepTime = 40, textKey = "ui.chat.voiceless"})
        return
    end

    if not packet.voiceTime then
        msg = World.CurWorld:filterWord(packet.msg)
    end

    if packet.voiceTime then
        if self.voiceChatTimes then
            self.voiceChatTimes = self.voiceChatTimes+1
        else
            self.voiceChatTimes = 1
        end

    else
        if self.textChatTimes then
            self.textChatTimes = self.textChatTimes+1
        else
            self.textChatTimes = 1
        end
    end



    --local entity = World.CurWorld:getEntity(packet.targetId)
    local entity = Game.GetPlayerByUserId(packet.targetId)
    --local backPacket = nil
    if not entity or not entity.isPlayer then
        --local allEntity = World.CurWorld:getAllEntity()
        --local isRefreshObjID = false
        --for _, _entity in pairs(allEntity) do
        --    if _entity.isPlayer and _entity.name == packet.targetName then
        --        packet.targetId = _entity.objID
        --        entity = _entity
        --        isRefreshObjID = true
        --        break
        --    end
        --end
        self:sendServerChat({ text = "ui.chat.offline",platId = packet.targetId }, Define.Page.PRIVATE, packet.targetId,packet.targetName)--
        return
    end
    local dg = nil
	-- for _,v in pairs(self.vars.privilege) do
	-- 	if v == "myplugin/svip_privilege" then
	-- 		dg = Define.ChatPlayerType.svip
	-- 		break
	-- 	elseif v == "myplugin/vip_privilege" then
	-- 		dg = Define.ChatPlayerType.vip
	-- 	end
	-- end
    entity:sendChatMsg({
        pid = "ChatMessage",
        fromname = self.name,
        msg = msg,
        voiceTime = packet.voiceTime,
        emoji = packet.emoji or false,
        args = table.pack(self.platformUserId,dg, Define.Page.PRIVATE, self.platformUserId),
    })
    self:sendChatMsg({
        pid = "ChatMessagePrivateSelf",
        fromname = self.name,
        msg = msg,
        voiceTime = packet.voiceTime,
        emoji = packet.emoji or false,
        args = table.pack(self.platformUserId,dg, Define.Page.PRIVATE, self.platformUserId),
        targetId = packet.targetId,
        targetUserId = entity.platformUserId,
        targetName = entity.name
    })
    if packet.voiceTime then
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
        if success then
            self:resetFreeSoundTimes()

            local reward = VoiceShopConfig:getItemById(packet.idx).num
            if reward > 0 then
                self:addVoiceCnt(reward)
            else
                self:addMoonCard(-reward)
            end
        end
    end,1,Define.ExchangeItemsReason.BuyVoice or 2)
end