local handles = T(Player, "PackageHandlers")
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
local EmojiConfig = T(Config, "EmojiConfig")

function handles:ChatMessage(packet)
    Lib.emitEvent(Event.EVENT_CHAT_MESSAGE, packet.msg, packet.fromname, packet.voiceTime, packet.emoji or false, packet.args, nil, packet.msgPack)
    --公屏聊天以外的聊天（私聊，家族聊）以及所有语音聊天不显示在人物头�
    local entity = World.CurWorld:getEntity(packet.args[1])
    if entity and playerHeadEffect[entity.objID] then
        entity:delEffect(playerHeadEffect[entity.objID])
        playerHeadEffect[entity.objID] = nil
    end
    if entity and packet.voiceTime then
        entity:showHeadMessage("")
        playerHeadEffect[entity.objID] = entity:showEffect(chatSetting.voiceEffect or VoiceEffect)
    end
    if packet.args[3] ~= Define.Page.COMMON or packet.voiceTime or packet.args[2] == Define.ChatPlayerType.server then
        return
    end
    if entity ~= nil then
        local msg = packet.msg
        if packet.emoji then
            msg = EmojiConfig:getTextByIcon(packet.emoji) and Lang:toText(EmojiConfig:getTextByIcon(packet.emoji)) or "emoji"
        else
            local item = ShortConfig:getItemByName(msg)
            if item then
                msg = Lang:toText(string.len(item.headText or "") > 0 and item.headText or msg)
            end
        end
        if chatSetting.chatBubbleSetting then
            entity:showHeadMessage1(msg, chatSetting.chatBubbleSetting.time, chatSetting.chatBubbleSetting.size, chatSetting.chatBubbleSetting.font)
        else
            entity:showHeadMessage(msg)
        end
    end
end

function handles:ChatMessagePrivateSelf(packet)
    Lib.emitEvent(Event.EVENT_CHAT_MESSAGE, packet.msg, packet.fromname, packet.voiceTime, packet.emoji or false, packet.args, { targetId = packet.targetId, targetName = packet.targetName, targetUserId = packet.targetUserId })
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