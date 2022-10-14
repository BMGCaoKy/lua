local Player = Player
local chatSetting = World.cfg.chatSetting

function Player:getVoiceCardTime()
    self:sendPacket({pid = "GetVoiceCardTime"})
end

function Player:isFriendShip(platformUserId)
    return FriendManager.friendsMap[platformUserId]
end

-- 当前频道是否开放
function Player:isOpenedChatTabType(tabType)
    if chatSetting and chatSetting.chatTabList then
        for _, tab in pairs(chatSetting.chatTabList) do
            if tab == tabType then
                return true
            end
        end
    end
    return false
end

function Player:testSystemEvent(info)
    print(info)
end

function Player:checkIsOpenChatBar()
    --- @type UIChatManage
    local UIChatManage = T(UIMgr, "UIChatManage")
    if World.cfg.chatSetting and World.cfg.chatSetting.chatBar then
        UIMgr:registerOpenWindow("chatBar", function()
            UIChatManage:showChatViewByType(Define.chatWinSizeType.smallMiniChat)
        end)
    else
        UIChatManage:showChatViewByType(Define.chatWinSizeType.smallMiniChat)
    end
end

function Player:checkChatMainTabIsOpen(pageType)
    return true
end

function Player:checkChatMainProfileIsOpen()
    return true
end

function Player:checkChatMainFindFriendIsOpen()
    return true
end

function Player:checkChatPlayerInfoIsOpen()
    return true
end

function Player:checkChatPlayerBtnIsOpen(btnName,  targetLevel)
    return true
end

--==============================================================
-- 以下函数实现需要业务重载
--===============================================================
-- 获取好友名片界面，本游戏玩家特有的按钮，这些按钮平台好友不能点击
function Player:getPlayerInfoGameBtn()
    return {}
end

-- 获取当前所有宠物列表
function Player:getChatAllPetList()
    return {}
end

-- 解析宠物json信息
function Player:decodeChatPetBodyJson(petJson)
    local petData = cjson.decode(petJson)
    return petData
end

-- 显示宠物详情界面
function Player:showChatPetDetailView(petJson, dx,dy)
end

-- 获取当前所有物品列表，封装成json
function Player:getChatAllBagItemList()
    local goodList = {}
    return goodList
end

-- 解析物品json信息
function Player:decodeChatGoodBodyJson(goodJson)
    local goodData = cjson.decode(goodJson)
    return goodData
end

-- 显示物品详情界面
function Player:showChatGoodsDetailView(goodJson, dx,dy)
end

-- 获得职业id
function Player:getCareerId()
    return ""
end

-- 获得职业图标
function Player:getChatCareerIcon(careerId)
    return ""
end

-- 点击查找好友按钮
function Player:clickSearchFriendBtn()
end

-- 点击组队大厅按钮
function Player:clickChatTeamHallBtn()
end

-- 组队邀请信息拼接
function Player:getTeamInviteMiniStr(teamInviteData)
    return ""
end

-- 组队功能是否开启
function Player:checkTeamSystemIsOpen()
    return true
end

-- 玩家等级、职业、战力 等特殊消息数据处理
function Player:dealChatPlayerSpData(info)
    return {}
end

-- 玩家名片按钮名
function Player:getPlayerInfoBtnTxtName(btnName, userId)
    return Lang:toText(btnName or "")
end

-- 客户端发送非私聊消息的埋点
---@param chatTabType string
---@param msg string
---@param time string
---@param emoji string
function Player:sendNormalChatBuriedPoint(chatTabType, msg, time, emoji)
    if time then -- 有语音时长
        Plugins.CallTargetPluginFunc("report", "report", "chat_voice")
    elseif emoji then  -- 表情
        Plugins.CallTargetPluginFunc("report", "report", "chat_emoji")
    else -- 纯文字
        Plugins.CallTargetPluginFunc("report", "report", "chat_text")
    end
end

-- 客户端发送私聊消息的埋点
---@param userId number
---@param msg string
---@param emoji string
function Player:sendPrivateChatBuriedPoint(userId, msg, emoji)
    if emoji then  -- 表情
        Plugins.CallTargetPluginFunc("report", "report", "chat_emoji")
    else -- 纯文字
        Plugins.CallTargetPluginFunc("report", "report", "chat_text")
    end
end

-- 客户端收到消息的埋点
function Player:receiveChatMsgBuriedPoint(msg, fromname, voiceTime, emoji, objID, dign, type, platId, extraMsgArgs, msgPack, isWorldMsg)

end
