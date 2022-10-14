local path = Root.Instance():getGamePath():gsub("\\", "/") .. "lua/gm_client.lua"
local file, err = io.open(path, "r")
local GMItem
if file then
    GMItem = require("gm_client")
    file:close()
end
if not GMItem then
    GMItem = GM:createGMItem()
end

--- @type UIChatManage
local UIChatManage = T(UIMgr, "UIChatManage")

GMItem["聊天插件/窗体层级向前1级"] = function()
    local chatRt = UI:getWnd("chatMain")._root
    chatRt:SetLevel(chatRt:GetLevel()-1)

    local chatMini = UI:getWnd("chatMini")._root
    chatMini:SetLevel(chatMini:GetLevel()-1)
    print("the win_chat wnd level is :",chatRt:GetLevel())
end
GMItem["聊天插件/窗体层级向后1级"] = function()
    local chatRt = UI:getWnd("chatMain")._root
    chatRt:SetLevel(chatRt:GetLevel()+1)

    local chatMini = UI:getWnd("chatMini")._root
    chatMini:SetLevel(chatMini:GetLevel()+1)
    print("the win_chat wnd level is :",chatRt:GetLevel())
end

GMItem["聊天插件/开入口"] = function()
    UI:openWnd("chatBar")
end

GMItem["聊天插件/世界聊天"] = function()
    local chatSetting = World.cfg.chatSetting or {}
    local pos
    for key, val in pairs(UIChatManage:getCurMiniMsgList()) do
        if val == Define.Page.COMMON then
            pos = key
        end
    end
    if pos then
        table.remove( UIChatManage:getCurMiniMsgList(), pos )
    else
        table.insert( UIChatManage:getCurMiniMsgList(),Define.Page.COMMON )
    end
    --UI:getWnd("chatMini"):refreshMiniChatWin()
end

GMItem["聊天插件/私聊聊天"] = function()
    local chatSetting = World.cfg.chatSetting or {}
    local pos
    for key, val in pairs(UIChatManage:getCurMiniMsgList()) do
        if val == Define.Page.PRIVATE then
            pos = key
        end
    end
    if pos then
        table.remove( UIChatManage:getCurMiniMsgList(), pos)
    else
        table.insert( UIChatManage:getCurMiniMsgList(),Define.Page.PRIVATE)
    end
    --UI:getWnd("chatMini"):refreshMiniChatWin()
end

GMItem["聊天插件/当前聊天"] = function()
    local chatSetting = World.cfg.chatSetting or {}
    local pos
    for key, val in pairs(UIChatManage:getCurMiniMsgList()) do
        if val == Define.Page.MAP_CHAT then
            pos = key
        end
    end
    if pos then
        table.remove( UIChatManage:getCurMiniMsgList(), pos)
    else
        table.insert( UIChatManage:getCurMiniMsgList(),Define.Page.MAP_CHAT)
    end
    --UI:getWnd("chatMini"):refreshMiniChatWin()
end

GMItem["聊天插件/队伍聊天"] = function()
    local chatSetting = World.cfg.chatSetting or {}
    local pos
    for key, val in pairs(UIChatManage:getCurMiniMsgList()) do
        if val == Define.Page.TEAM then
            pos = key
        end
    end
    if pos then
        table.remove( UIChatManage:getCurMiniMsgList(), pos)
    else
        table.insert( UIChatManage:getCurMiniMsgList(),Define.Page.TEAM)
    end
    --UI:getWnd("chatMini"):refreshMiniChatWin()
end

GMItem["聊天插件/发系统消息"] = function()
    if Me.testNum then
        Me.testNum = Me.testNum + 1
    else
        Me.testNum = 0
    end
    Plugins.CallTargetPluginFunc("platform_chat", "sendOneSystemMsg", "合格率热客的时间和干净开会" .. Me.testNum)
end

GMItem["聊天插件/发送世界聊天"] = function()
    Plugins.CallTargetPluginFunc("platform_chat", "doRequestServerSendChatMsg", 1, "什么鬼啊")
end

GMItem["聊天插件/发送世界宠物"] = function()
    local cjson = require("cjson")
    ---@type EntityDataHelper
    local EntityDataHelper = T(Lib, "EntityDataHelper")
    --- @type PetConfig
    local PetConfig = T(Config, "PetConfig")

    local petInfo = EntityDataHelper:getPet(Me)
    local entityData = petInfo[1]
    local petId = entityData:getCfgId()
    local cfg = PetConfig:getCfgById(petId)
    local body = {
        name = entityData:getPetName() or Lang:toText(cfg.name) or "",
        petId = entityData:getCfgId(),
        uid = entityData:getUid(),
        level = entityData:getLevel(),
        power = entityData:getFight(),
        nameColor =  Define.PetRarityNameColor[cfg.rarity],
        icon =  cfg.icon,
        iconBg = Define.PetRarityHeaderBgImg[cfg.rarity],
    }
    local bodyJson = cjson.encode(body)

    local emojiInfo = {
        type = Define.chatEmojiTab.PET,
        emojiData = bodyJson
    }
    Plugins.CallTargetPluginFunc("platform_chat", "doRequestServerSendChatMsg", 1, "", false, emojiInfo)
end

GMItem["聊天插件/点击系统消息"] = function()
    local content = "测试消息啊"
    local msgPack = {
        event = "testSystemEvent",
        args = os.time()
    }
    Plugins.CallTargetPluginFunc("platform_chat", "sendOneSystemMsg", content, msgPack)
end

GMItem["聊天插件/初始标签"] = function()
    local tagsList = {10012}
    Plugins.CallTargetPluginFunc("platform_chat", "addPlayerTagsList", tagsList)
end