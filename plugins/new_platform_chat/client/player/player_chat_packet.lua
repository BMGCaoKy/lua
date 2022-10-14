local handles = T(Player, "PackageHandlers")
---@type EmojiConfig
local EmojiConfig = T(Config, "EmojiConfig")
local chatSetting = World.cfg.chatSetting or {}
local ShortConfig = T(Config, "ShortConfig")
local VoiceEffect = {
    effect = "g2042_voice_1.effect",
    pos = {
        x = 0,
        y = 2,
        z = 0
    },
    yaw = 0,
    time = chatSetting.chatBubbleSetting and chatSetting.chatBubbleSetting.time or 5000
}
local playerHeadEffect = {}

function handles:ChatMessage(packet)
    if not self:isOpenedChatTabType(packet.args[3]) then
        return
    end
    Lib.emitEvent(Event.EVENT_CHAT_MESSAGE, packet.msg, packet.fromname, packet.voiceTime, packet.emoji or false, packet.args, nil, packet.msgPack)
    if packet.args[3] ~= Define.Page.COMMON or packet.voiceTime or packet.args[2] == Define.ChatPlayerType.server then
        return
    end
    local entity = World.CurWorld:getEntity(packet.args[1])
    if entity ~= nil then
        if playerHeadEffect[entity.objID] then
            entity:delEffect(playerHeadEffect[entity.objID])
            playerHeadEffect[entity.objID] = nil
        end
        if packet.voiceTime then
            playerHeadEffect[entity.objID] = entity:showEffect(chatSetting.voiceEffect or VoiceEffect)
        end

        local msg = packet.msg
        if packet.emoji then
            if packet.emoji.type == Define.chatEmojiTab.FACE then
                msg = EmojiConfig:getTextByIcon(packet.emoji.emojiData) and Lang:toText(EmojiConfig:getTextByIcon(packet.emoji.emojiData)) or "emoji"
                if chatSetting.chatBubbleSetting then
                    entity:showHeadMessage1(msg, chatSetting.chatBubbleSetting.time, chatSetting.chatBubbleSetting.size,
                            chatSetting.chatBubbleSetting.font, chatSetting.chatBubbleSetting.offsetY)
                else
                    entity:showHeadMessage(msg)
                end
            end
        else
            local item = ShortConfig:getItemByName(msg)
            if item then
                msg = Lang:toText(string.len(item.headText or "") > 0 and item.headText or msg)
            end
            if chatSetting.chatBubbleSetting then
                entity:showHeadMessage1(msg, chatSetting.chatBubbleSetting.time, chatSetting.chatBubbleSetting.size,
                        chatSetting.chatBubbleSetting.font, chatSetting.chatBubbleSetting.offsetY)
            else
                entity:showHeadMessage(msg)
            end
        end
    end
end

function handles:ChatTeamInviteMsg(packet)
    if not self:isOpenedChatTabType(packet.args[3]) then
        return
    end
    if Me:isJoinTeam() then
        if packet.args[4] ~= Me.platformUserId then
            return
        end
    end
    Lib.emitEvent(Event.EVENT_CHAT_MESSAGE, packet.msg, packet.fromname, packet.voiceTime, packet.emoji or false, packet.args, packet.teamInviteData, packet.msgPack)
end

function handles:ChatSystemMessage(packet)
    if not self:isOpenedChatTabType(packet.args[3]) then
        return
    end
    local msg = Lang:toText(packet.msg)
    Lib.emitEvent(Event.EVENT_CHAT_MESSAGE, msg, packet.fromname, packet.voiceTime, packet.emoji or false, packet.args, nil, packet.msgPack)
end

function handles:BuyVoiceResult(packet)
    if not packet.isSucceed then
        Interface.onRecharge(1)
    end
    Client.ShowTip(1, Lang:toText(packet.isSucceed and "ui.chat.voiceBuySucc" or "ui.chat.voiceBuyFail"), 40)
end

function handles:GetVoiceCardTime(packet)
    Lib.emitEvent(Event.EVENT_CHAT_CARD_TIME, packet.time)
end

-- pc��������յ�ƽ̨˽����Ϣ
function handles:TestOtherPrivateMsg(packet)
    --- @type UIChatManage
    local UIChatManage = T(UIMgr, "UIChatManage")
    UIChatManage:receivePlatformPrivateMsg(Define.privateMessageSource.gameMsg, packet.messageType, packet.content)
end

function handles:PushClientSendPrivateChatEmoji(packet)
    Plugins.CallTargetPluginFunc("platform_chat", "doSendPrivateChatEmoji", packet.senderId)
end