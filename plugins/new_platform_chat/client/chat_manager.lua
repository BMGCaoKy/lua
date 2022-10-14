---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by hlm.
--- DateTime: 2021/3/18 11:07
--- 这里是聊天数据的管理类
--- @class UIChatManage
local UIChatManage = T(UIMgr, "UIChatManage")
--- @type PlayerSpInfoManager
local PlayerSpInfoManager = T(Lib, "PlayerSpInfoManager")
local cjson = require("cjson")

local chatSetting = World.cfg.chatSetting or {}
local operationType = FriendManager.operationType

UIChatManage.isInitInfo = false
local function getChatNameColor(num)
    local count = #chatSetting.chatHeadColor
    local index = num % count
    if index == 0 then index = count end
    return chatSetting.chatHeadColor[index]
end

function UIChatManage:init()
    if UIChatManage.isInitInfo then
        return
    end
    UIChatManage.isInitInfo = true
    self:initChatData()
    self:initEvent()
    World.LightTimer("",1,function()
        self:initDetailInfo(Me.platformUserId)
    end)

    self.curChatWinType = Define.chatWinSizeType.smallMiniChat
end

function UIChatManage:initChatData()
    self.curChatWinType = -1
    self.curPrivateUserId = nil
    --尚未全量的历史私聊消息字典
    self.undetailHistoryDic = {}
    --由于正在请求全量消息而暂存的新消息
    self.cacheNewMsgDic = {}

    --名字颜色
    self.headNameColor = {}
    --说话人次
    self.chatNum = 0

    --已屏蔽消息的列表
    self.ignoreList = {}

    --聊天数据表
    self.chatTabDataList = {}
    self.curMsgOrderId = 0
    --最近联系人
    self.privateHistoryList = {}
    --玩家头像信息缓存
    self.playerHeadCacheList = {}

    --正在请求头像信息的玩家
    self.getUserDetailIngPlayer = {}

    --需要请求在线状态的玩家列表
    self.needGetOnlineList = {}
    self.playerOnlineStateCache = {}

    -- 初始化聊天标签页数据列表
    for _, pageType in pairs(Define.Page) do
        self.chatTabDataList[pageType] = {}
    end

    self:initCalcText()
end

function UIChatManage:initEvent()
    Lib.lightSubscribeEvent("error!!!!! script_client win_chat Lib event : EVENT_CHAT_MESSAGE", Event.EVENT_CHAT_MESSAGE, function(msg, fromname, voiceTime, emoji, args, extraMsgArgs, msgPack, isWorldMsg)
        if not args then
            return
        end
        self:receiveChatMessage(msg, fromname, voiceTime, emoji, args[1],args[2],args[3],args[4], extraMsgArgs, msgPack, isWorldMsg)
    end)

    Lib.lightSubscribeEvent("error!!!!! script_client win_chat event : EVENT_SET_IGNORE", Event.EVENT_SET_IGNORE, function(id, objId, name, btn)
        if not self.ignoreList[id] then
            self.ignoreList[id] = true
            if btn then
                btn:SetText(Lang:toText("ui.chat.disignore"))
            end
        else
            self.ignoreList[id] = false
            if btn then
                btn:SetText(Lang:toText("ui.chat.ignore"))
            end
        end
        Client.ShowTip(1, Lang:toText(self.ignoreList[id] and "ui.chat.ignore.tip" or "ui.chat.disignore.tip"), 40)
    end)

    Lib.lightSubscribeEvent("error!!!!! script_client win_chat Lib event : EVENT_OPEN_PRIVATE_CHAT", Event.EVENT_OPEN_PRIVATE_CHAT, function(userId)
        self:setCurPrivateFriend(userId)
    end)

    Lib.lightSubscribeEvent("error!!!!! script_client win_chat Lib event : EVENT_CHAT_VOICE_START", Event.EVENT_CHAT_VOICE_START, function(path)
        self:voiceStartFunc(path)
    end)

    Lib.lightSubscribeEvent("error!!!!! script_client win_chat Lib event : EVENT_CHAT_VOICE_END", Event.EVENT_CHAT_VOICE_END, function(path)
        self:voiceEndFunc(path)
    end)

    -- 其他玩家对我进行好友操作的回调，只有对方操作的时候，我刚好在线才会触发
    Lib.subscribeEvent(Event.EVENT_FRIEND_OPERATION_NOTICE, function(opType, playerPlatformId)
        if opType == operationType.AGREE then -- 添加请求被同意
            Me:doRequestServerFriendInfo(Define.chatFriendType.game)
            Me:doRequestServerFriendInfo(Define.chatFriendType.platform)
            Me:addPlayerFriendFromExist(playerPlatformId, Define.friendStatus.gameFriend)
        elseif opType == operationType.DELETE then-- 被删除好友
            Me:doRequestServerFriendInfo(Define.chatFriendType.game)
            Me:doRequestServerFriendInfo(Define.chatFriendType.platform)
            Me:removePlayerFriendFromExist(playerPlatformId)
        elseif opType == operationType.ADD_FRIEND then -- 有添加好友请求
            AsyncProcess.LoadUserRequests()
        end
    end)

    Lib.subscribeEvent(Event.EVENT_INVITE_GAME, function(userId)
        self:sendInviteMsg(userId)
    end)

    Lib.subscribeEvent(Event.EVENT_PLAYER_STATUS, function(status, uId, uName)
        if status == 1 and self.headNameColor[uId] then
            self.headNameColor[uId] = nil
        end
    end)

    -- 打开玩家详情页
    Lib.subscribeEvent(Event.EVENT_OPEN_PLAYER_INFORMATION, function(userId)
        -- UI:getWnd("chatMyProfile"):onShow(true, userId)
    end)
end

function UIChatManage:voiceStartFunc(path)
    local voiceName = string.sub(path, -19)
    -- local curTab = UI:getWnd("chatMain"):getCurTab()
    local list = self.chatTabDataList[curTab] or {}
    if curTab == Define.Page.PRIVATE and self.curPrivateUserId then
        list = self.chatTabDataList[Define.Page.PRIVATE][self.curPrivateUserId] or {}
    end
    for idx, item in pairs(list) do
        if list[idx].msg then
            local voiceName2 = string.sub(list[idx].msg, -19)
            if list[idx].voiceTime and voiceName2 == voiceName then
                list[idx].isRead = true
                list[idx].playing = true
                break
            end
        end
    end
end

function UIChatManage:voiceEndFunc(path)
    local voiceName = string.sub(path, -19)
    local curTab = UI:getWnd("chatMain"):getCurTab()
    local list = self.chatTabDataList[curTab] or {}
    if curTab == Define.Page.PRIVATE and self.curPrivateUserId then
        list = self.chatTabDataList[Define.Page.PRIVATE][self.curPrivateUserId] or {}
    end
    for idx, item in pairs(list) do
        if list[idx].msg then
            local voiceName2 = string.sub(list[idx].msg, -19)
            if list[idx].voiceTime and voiceName2 == voiceName then
                list[idx].isRead = true
                list[idx].playing = false
                break
            end
        end
    end
end

function UIChatManage:stopAllVoiceView(curTab)
    local list = self.chatTabDataList[curTab]
    if curTab == Define.Page.PRIVATE and self.curPrivateUserId then
        list = self.chatTabDataList[Define.Page.PRIVATE][self.curPrivateUserId] or {}
    end
    for idx, item in pairs(list) do
        if list[idx].voiceTime and list[idx].playing then
            list[idx].isRead = true
            list[idx].playing = false
        end
    end
end

-- 过滤聊天小窗需要显示的标签数据
function UIChatManage:getMiniChatShowDataList()
    local miniDataList = {}
    local curMiniMsgList = self:getCurMiniMsgList()
    for _, pageType in pairs(curMiniMsgList) do
        if pageType == Define.Page.PRIVATE then
            for _, privateData in pairs(self.chatTabDataList[pageType]) do
                for _, data in pairs(privateData) do
                    table.insert(miniDataList, data)
                end
            end
        else
            for _, data in pairs(self.chatTabDataList[pageType]) do
                table.insert(miniDataList, data)
            end
        end
    end
    table.sort(miniDataList, function (a, b)
        return a.msgOrderId < b.msgOrderId
    end)
    return miniDataList
end

function UIChatManage:checkNameColor(userId)
    local default = chatSetting.mainNiceNameColor or "FF0000"
    if not userId then
        return default
    end
    if not chatSetting.chatHeadColor then
        return nil
    end

    if self.headNameColor[userId] then
        return self.headNameColor[userId]
    end
    self.chatNum = self.chatNum + 1
    local color = getChatNameColor(self.chatNum)
    self.headNameColor[userId] = color
    return color or default
end

--消息显示
function UIChatManage:receiveChatMessage(msg, fromname, voiceTime, emoji, objID, dign, type, platId, extraMsgArgs, msgPack, isWorldMsg)
    if platId and self.ignoreList[platId] then
        return
    end
    Me:receiveChatMsgBuriedPoint(msg, fromname, voiceTime, emoji, objID, dign, type, platId, extraMsgArgs, msgPack, isWorldMsg)
    if platId and platId ~= Me.platformUserId then
        self:initDetailInfo(platId)
    end

    local nameColor = nil
    if type ~= Define.Page.PRIVATE and not dign then
        nameColor = self:checkNameColor(platId)
    end

    local info = {
        type = type,
        msg = msg,
        fromname = fromname,
        privateName = extraMsgArgs and extraMsgArgs.privateName,
        voiceTime = voiceTime,
        emoji = emoji,
        objID = objID,
        dign = dign,
        platId = platId,
        msgPack = msgPack,
        isWorldMsg = isWorldMsg
    }

    if type == Define.Page.TEAM and extraMsgArgs then --组队邀请消息特殊处理
        info.teamInviteData = extraMsgArgs
        if nameColor then info.nameColor = nameColor end
        info.msg = Me:getTeamInviteMiniStr(extraMsgArgs)
        self:addMsg(type, info)
        -- UI:getWnd("chatMain"):receiveChatMessage(type, msg, fromname, nil, voiceTime)
    else
        local h, msgLen = 20, string.len(msg or "")
        if (msg == "nil" or msgLen == 0) and not emoji then
            return
        end

        if nameColor then info.nameColor = nameColor end
        self:addMsg(type, info, extraMsgArgs)
        -- UI:getWnd("chatMain"):receiveChatMessage(type, msg, fromname, extraMsgArgs, voiceTime)
    end
    
    if type == Define.Page.PRIVATE then
        Lib.emitEvent(Event.EVENT_RECEIVE_PRIVATE_TEXT_INFO, info , extraMsgArgs)
    end
end

function UIChatManage:addMsg(type, info, extraMsgArgs)
    Lib.logDebug("UIChatManage:addMsg:",Lib.v2s(info,2))
    Lib.logDebug("UIChatManage:addMsg2:",Lib.v2s(extraMsgArgs,2))
    if type == Define.Page.PRIVATE then
        local  keyId = extraMsgArgs.keyId
        if not self.chatTabDataList[type][keyId] then
            self.chatTabDataList[type][keyId] = {}
        end
        if #self.chatTabDataList[type][keyId] >= Define.miniChatMaxCnt then
            table.remove(self.chatTabDataList[type][keyId], 1)
        end
        self.curMsgOrderId = self.curMsgOrderId + 1
        info.msgOrderId = self.curMsgOrderId
        info.privateName = extraMsgArgs.privateName or extraMsgArgs.targetName or extraMsgArgs.receiverUserId or ""
        table.insert(self.chatTabDataList[type][keyId], info)
        self:updateHistory(keyId, info, extraMsgArgs)
    else
        if #self.chatTabDataList[type] >= Define.miniChatMaxCnt then
            table.remove(self.chatTabDataList[type],1)
        end
        self.curMsgOrderId = self.curMsgOrderId + 1
        info.msgOrderId = self.curMsgOrderId
        table.insert(self.chatTabDataList[type], info)
    end
    if not extraMsgArgs or not extraMsgArgs.isHistory then
        for _, pageType in pairs(self:getCurMiniMsgList()) do
            if pageType == type then
                break
            end
        end
    end

end
---@class getUserDetailInfo
---@field picUrl string
---@field nickName string
---@field sex number
---@return getUserDetailInfo
function UIChatManage:getUserDetailInfo(userId)
    if userId == Me.platformUserId then
        return self.meDetailInfo or false
    else
        return self.playerHeadCacheList[userId] and self.playerHeadCacheList[userId].detailInfo or false
    end

end

function UIChatManage:initDetailInfo(keyId)
    if not keyId then
        return
    end
    if self.playerHeadCacheList[keyId] then
        return
    end
    if keyId == Me.platformUserId then
        if self.meDetailInfo then
            return
        end
    end
    if self.getUserDetailIngPlayer[keyId] then
        return
    end
    self.getUserDetailIngPlayer[keyId] = true
    AsyncProcess.GetUserDetail(keyId, function (data)
        self.getUserDetailIngPlayer[keyId] = false
        if keyId == Me.platformUserId then
            self.meDetailInfo = {}
            self.meDetailInfo.nickName = ""
            self.meDetailInfo.sex = 1
            if data then
                if data.picUrl and #data.picUrl > 0  then
                    self.meDetailInfo.picUrl = data.picUrl
                end
                self.meDetailInfo.nickName = data.nickName
                self.meDetailInfo.sex = data.sex
            end
        else
            if not self.playerHeadCacheList[keyId] then
                self.playerHeadCacheList[keyId] = {}
            end
            self.playerHeadCacheList[keyId].detailInfo = {}
            self.playerHeadCacheList[keyId].detailInfo.nickName = ""
            self.playerHeadCacheList[keyId].detailInfo.sex = 1
            if data then
                if data.picUrl and #data.picUrl > 0  then
                    self.playerHeadCacheList[keyId].detailInfo.picUrl = data.picUrl
                end
                self.playerHeadCacheList[keyId].detailInfo.nickName = data.nickName
                self.playerHeadCacheList[keyId].detailInfo.sex = data.sex
            end
        end

        if self.playerHeadCacheList[keyId] then
            Lib.emitEvent("EVENT_USER_DETAIL"..keyId,self.playerHeadCacheList[keyId].detailInfo)
        end
    end)
end
--更新历史页面
function UIChatManage:updateHistory(keyId, info, extraMsgArgs)
    --自己发消息永远不更新
    --if extraMsgArgs.senderUserId == Me.platformUserId then
    --    return
    --end

    --过滤机器人信息
    if not FriendManager.friendsMap[extraMsgArgs.senderUserId] and 
    extraMsgArgs.senderUserId ~= Me.platformUserId then 
        return 
    end

    local has = false
    for _, history in pairs(self.privateHistoryList) do
        if history.keyId == keyId then
            has = true
            if info.keyId ~= Me.platformUserId then
                history.cnt = history.cnt + 1
                history.extraMsgArgs = extraMsgArgs
                history.info = info
                -- 越后面的消息排在越上面
                history.lastMsgTime = os.time()
            end
        end
    end
    if not has then
        local temp = {
            keyId = keyId,
            cnt = 1,
            extraMsgArgs = extraMsgArgs,
            info = info,
            lastMsgTime = os.time()
        }
        self.privateHistoryList[keyId] = temp
    end
    self:addOneNeedOnlineItem(keyId)
    Lib.emitEvent(Event.EVENT_UPDATE_PRIVATE_HISTORY)
end

function UIChatManage:splitStringToMultiLine(width, msg)
    local outList = {}
    outList = self.pStaticText:GetFont():SplitStringToMultiLine(width - 15, self.pStaticText:GetTextColor(), msg, outList, {})
    return outList
end

local function getColorOfRGB(str)
    -- 去掉#字符
    local newstr = string.gsub(str, '#', '')

    -- 每次截取两个字符 转换成十进制
    local colorlist = {}
    local index = 1
    while index < string.len(newstr) do
        local tempstr = string.sub(newstr, index, index + 1)
        table.insert(colorlist, tonumber(tempstr, 16))
        index = index + 2
    end

    return {(colorlist[1] or 0)/255, (colorlist[2] or 0)/255, (colorlist[3] or 0)/255}
end

function UIChatManage:initCalcText()
    self.pStaticText = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "CalcText")
    self.pStaticText:SetTouchable(false)
    self.pStaticText:SetHorizontalAlignment(1)
    self.pStaticText:SetVerticalAlignment(0)
    self.pStaticText:SetTextScale(1)
    self.pStaticText:SetFontSize(chatSetting.chatFont or "HT16")
    self.pStaticText:SetWordWrap(true)
    if chatSetting.chatFontColor then
        local c = getColorOfRGB(chatSetting.chatFontColor)
        self.pStaticText:SetTextColor(getColorOfRGB(chatSetting.chatFontColor))
    else
        self.pStaticText:SetTextColor( {0,0,0})
    end
end

function UIChatManage:checkIsIgnore(id)
    return self.ignoreList[id]
end


function UIChatManage:getCurMiniMsgList()
    if not Me.curMiniMsgList then
        Me.curMiniMsgList = chatSetting.miniMsgShowList or {}
    end
    return Me.curMiniMsgList
end

function UIChatManage:showChatViewByType(chatWinType, openTab)
    -- Lib.logDebug("engine showChatViewByType chatWinType = ", chatWinType)
    -- self.curChatWinType = chatWinType
    -- if self.curChatWinType == Define.chatWinSizeType.noChatWnd then
    --     if UI:isOpen("chatMain") then
    --         UI:getWnd("chatMain"):onShow(false)
    --     end
    --     if UI:isOpen("chatMini") then
    --         UI:getWnd("chatMini"):onShow(false)
    --     end
    --     if UI:isOpen("chatBar") then
    --         UI:getWnd("chatBar"):ShowBar(false)
    --     end
    -- elseif self.curChatWinType == Define.chatWinSizeType.mainChat then
    --     UI:getWnd("chatMain"):onShow(true, openTab)
    --     if UI:isOpen("chatMini") then
    --         UI:getWnd("chatMini"):onShow(false)
    --     end
    --     if UI:isOpen("chatBar") then
    --         UI:getWnd("chatBar"):ShowBar(false)
    --     end
    --     Plugins.CallTargetPluginFunc("email_system", "SetEmailBarVisible", false)
    -- elseif self.curChatWinType == Define.chatWinSizeType.bigMiniChat then
    --     if UI:isOpen("chatMain") then
    --         UI:getWnd("chatMain"):onShow(false)
    --     end
    --     UI:getWnd("chatMini"):onShow(true, Define.chatWinSizeType.bigMiniChat)
    --     UI:getWnd("chatBar"):ShowBar(true)
    --     Plugins.CallTargetPluginFunc("email_system", "SetEmailBarVisible", true)
    -- elseif self.curChatWinType == Define.chatWinSizeType.smallMiniChat then
    --     if UI:isOpen("chatMain") then
    --         UI:getWnd("chatMain"):onShow(false)
    --     end
    --     UI:getWnd("chatMini"):onShow(true, Define.chatWinSizeType.smallMiniChat)
    --     UI:getWnd("chatBar"):ShowBar(true)
    --     Plugins.CallTargetPluginFunc("email_system", "SetEmailBarVisible", true)
    -- end
end

function UIChatManage:sendChatSystemMsg(tabType, content, msgPack)
    if tabType == Define.Page.SYSTEM then
        local packet ={
            pid = "ChatMessageToSystem",
            msg = content,
            msgPack = msgPack
        }
        Me:sendPacket(packet)
    end
end

---组队邀请喊话
function UIChatManage:sendTeamChatInviteMsg(teamInviteData)
    local packet ={
        pid = "ChatTeamInviteMsg",
        teamInviteData = teamInviteData,
    }
    Me:sendPacket(packet)
end

--好友列表特殊数据接口
function UIChatManage:getFriendListItemSpDisplay(userId,cb)
    PlayerSpInfoManager:getPlayerSpDataById(userId,function(info)
        local data = self:getFriendItemSpInfo(info)
        if cb then
            cb(data)
        end
    end )
end

--好友关系特殊数据接口
function UIChatManage:getFriendTopDataSpDisplay(userId,cb)
    PlayerSpInfoManager:getPlayerSpDataById(userId,function(info)
        local data = self:getTopDataByUserSpInfo(info)
        if cb then
            cb(data)
        end
    end )
end

---打开好友名片界面
function UIChatManage:openChatPlayerInfoWnd(userId)
    if Me:checkChatPlayerInfoIsOpen() then
        -- UI:getWnd("chatPlayerInfo"):onShow(true, userId)
    end
end

---获取当前平台好友私聊对象
function UIChatManage:getCurPrivateFriend()
    return self.curPrivateUserId
end

---设置当前平台好友私聊对象
function UIChatManage:setCurPrivateFriend(userId)
    self.curPrivateUserId = userId
    self:checkHistoryIsNewAndDel(userId)
    if userId then
        UIChatManage:showChatViewByType(Define.chatWinSizeType.mainChat)
    end
    Lib.emitEvent(Event.EVENT_UPDATE_FRIEND_PRIVATE_SHOW,userId)
end

---封装好友私聊聊天消息
function UIChatManage:encodeJsonPrivateMsg(targetUserId, msg, emoji)
    local messageTxt = msg or ""
    if emoji then
        messageTxt = cjson.encode(emoji)
    end
    local content = {
        receivedTime = 0,
        sentTime = os.time(),
        senderUserId = tostring(Me.platformUserId),
        senderNickname = Me.name,
        receiverUserId = tostring(targetUserId),
        conversationType = "private",
        content = messageTxt,
        uri = ""
    }
    local resultStr = cjson.encode(content)
    return resultStr
end

local inviteLock = false
function UIChatManage:sendInviteMsg(userId)
    local player = Game.GetPlayerByUserId(userId)
    
    if not Game.CheckCanJoinMidway() then 
        Client.ShowTip(1, Lang:toText("gui.friend.cannot.join"), 40)
        return
    end

    if player then
        Client.ShowTip(1, Lang:toText("ui.chat.invite.isExist"), 40)
        return
    end
    if inviteLock then
        Client.ShowTip(1, Lang:toText("ui.chat.invite.toofast"), 40)
        return false
    end
    inviteLock = true
    World.LightTimer("",60,function()
        inviteLock = false
    end)
    CGame.instance:getShellInterface():onSendMessage(Define.privateMessageType.inviteMsg, userId)
    Client.ShowTip(1, Lang:toText("ui.chat.invite.succ"), 40)
    return true
end

---发送平台好友私聊
function UIChatManage:sendFriendPrivateMsg(msg, emoji)
    if not Me:isOpenedChatTabType(Define.Page.PRIVATE) then
        return
    end
    if not self.curPrivateUserId then
        return
    end
    self:requestAppSendOnePrivate(self.curPrivateUserId, msg, emoji)
    Me:sendPrivateChatBuriedPoint(self.curPrivateUserId, msg, emoji)
end

--调用平台接口发送私聊消息
function UIChatManage:requestAppSendOnePrivate(targetUserId, msg, emoji)
    msg = World.CurWorld:filterWord(msg)
    local content = self:encodeJsonPrivateMsg(targetUserId, msg, emoji)
    local messageType = Define.privateMessageType.txtMsg
    local sourceType = Define.privateMessageSource.gameMsg
    if emoji then
        messageType = Define.privateMessageType.emojiMsg
    end
    -- 增加标签次数
    Me:addConditionAutoCounts(Define.tagConditionType.talk, 1)
    -- 自己发消息，直接自己收一次--取消自己接收，使用平台回显
    local isPcPlatform = CGame.instance:getPlatformId() == 1
    if isPcPlatform then
        self:receivePlatformPrivateMsg(sourceType, messageType, content)
        self:testSendPrivateMsgToOthers(messageType, content)
    else
        -- 自己发消息通过app，通知其他人接收
        CGame.instance:getShellInterface():onSendMessage(messageType, content)
    end
end

-- pc测试玩家收到平台私聊消息
function UIChatManage:testSendPrivateMsgToOthers(messageType, content)
    local packet ={
        pid = "TestOtherPrivateMsg",
        messageType = messageType,
        content = content,
        receiverUserId = self.curPrivateUserId,
    }
    Me:sendPacket(packet)
end

---解析好友私聊聊天消息
function UIChatManage:decodeJsonPrivateMsg(sourceType, messageType, content)
    local privateMsg = self:safeDecodeJSON(content)
    if not privateMsg then
        return false
    end
    privateMsg.msgInfo = {}
    if not sourceType then
        sourceType = privateMsg.sourceType
    end
    if not messageType then
        messageType = privateMsg.messageType
    end
    if sourceType == Define.privateMessageSource.gameMsg then
        if messageType == Define.privateMessageType.emojiMsg then
            privateMsg.msgInfo.msg = ""
            privateMsg.msgInfo.emoji = self:safeDecodeJSON(privateMsg.content,"")

        else
            privateMsg.msgInfo.msg = privateMsg.content or ""
            privateMsg.msgInfo.emoji = false
        end
    else --平台消息
        if messageType == Define.privateMessageType.txtMsg then
            privateMsg.msgInfo.msg = privateMsg.content or ""
            --print("emoji:",privateMsg.msgInfo.msg)
            --print("emoji type:",string.byte(privateMsg.msgInfo.msg))
        elseif messageType == Define.privateMessageType.voiceMsg then--语音
            privateMsg.msgInfo.msg = privateMsg.uri  or ""
            privateMsg.msgInfo.voiceTime = privateMsg.duration*1000
        else
            privateMsg.msgInfo.msg =  Lang:toText("ui.chat.tips.unable_display")
        end
    end
    return privateMsg
end
--解析好友私聊历史消息列表
function UIChatManage:decodeJsonPrivateHistoryList(listInfo)
    local listTb = self:safeDecodeJSON(listInfo,{})
    for _,item in pairs(listTb) do
        self:receivePlatformPrivateMsg(false,false,item.latestMessage,true)
        self.undetailHistoryDic[item.targetId] = item.latestMessageId
    end
end
--兼差此好友的历史消息是否完成初始化，如的确未完成，则向平台请求，并改为已完成，返回true，否则返回false
function UIChatManage:checkHistoryIsNewAndDel(senderUserId)
    if type(senderUserId) ~= "string" then
        senderUserId = tostring(senderUserId)
    end
    if self.undetailHistoryDic[senderUserId]  then
        if self.undetailHistoryDic[senderUserId] >0 then
            self.undetailHistoryDic[senderUserId] = -1
            CGame.instance:getShellInterface():onGetTalkDetail(senderUserId, self.undetailHistoryDic[senderUserId],10)
        end
        return true
    end
    return false
end

---接收到平台好友私聊
function UIChatManage:receivePlatformPrivateMsg(sourceType, messageType, content,isHistory)
    Lib.logDebug("wwwwwwwww  UIChatManage receivePlatformPrivateMsg1 ", sourceType, messageType, content)
    local privateMsg = self:decodeJsonPrivateMsg(sourceType, messageType, content)
    Lib.logDebug("wwwwwwwww  UIChatManage receivePlatformPrivateMsg2 ", Lib.v2s(privateMsg))
    if not privateMsg then
        return
    end
    self:receiveFriendPrivateMsg(privateMsg,isHistory)
end

---接收到好友私聊
function UIChatManage:receiveFriendPrivateMsg(privateMsg,isHistory)
    local keyId
    local privateName
    if tonumber(privateMsg.senderUserId) == Me.platformUserId then
        keyId = tonumber(privateMsg.receiverUserId)
        if not keyId then
            return
        end
        local detailInfo = UIChatManage:getUserDetailInfo(keyId)
        if detailInfo then
            privateName = detailInfo.nickName or ""
            self:updateFriendPrivateMsg(privateMsg,isHistory, keyId, privateName)
        else
            if self["userDetailInfoCancel" .. keyId] then
                self["userDetailInfoCancel" .. keyId]()
            end
            self["userDetailInfoCancel" .. keyId] = Lib.lightSubscribeEvent("error!!!!! EVENT_USER_DETAIL","EVENT_USER_DETAIL"..keyId, function(data)
                privateName = data.nickName or privateMsg.receiverUserId or ""
                self:updateFriendPrivateMsg(privateMsg,isHistory, keyId, privateName)
                self["userDetailInfoCancel" .. keyId]()
            end)
            UIChatManage:initDetailInfo(keyId)
        end
    else
        keyId = tonumber(privateMsg.senderUserId)
        if not keyId then
            return
        end

        local detailInfo = UIChatManage:getUserDetailInfo(keyId)
        if detailInfo then
            privateName = detailInfo.nickName or privateMsg.senderNickname or privateMsg.senderUserId or ""
            self:updateFriendPrivateMsg(privateMsg,isHistory, keyId, privateName)
        else
            if self["userDetailInfoCancel" .. keyId] then
                self["userDetailInfoCancel" .. keyId]()
            end
            self["userDetailInfoCancel" .. keyId] = Lib.lightSubscribeEvent("error!!!!! EVENT_USER_DETAIL","EVENT_USER_DETAIL"..keyId, function(data)
                privateName = data.nickName or privateMsg.senderNickname or privateMsg.senderUserId or ""
                self:updateFriendPrivateMsg(privateMsg,isHistory, keyId, privateName)
                self["userDetailInfoCancel" .. keyId]()
            end)
            UIChatManage:initDetailInfo(keyId)
        end
    end
end

function UIChatManage:updateFriendPrivateMsg(privateMsg,isHistory, keyId, privateName)
    if self:checkHistoryIsNewAndDel(keyId) then
        if  not self.cacheNewMsgDic[keyId] then
            self.cacheNewMsgDic[keyId] = {}
        end
        table.insert(self.cacheNewMsgDic[keyId],privateMsg)
    end

    local extraMsgArgs = {
        senderUserId = tonumber(privateMsg.senderUserId),
        fromname = privateMsg.senderNickname or privateMsg.senderUserId,
        targetName = privateMsg.receiverUserId,
        receiverUserId = tonumber(privateMsg.receiverUserId),
        keyId = keyId,
        privateName = privateName,
        messageType = privateMsg.messageType,
        isHistory = isHistory
    }
    self:receiveChatMessage(privateMsg.msgInfo.msg, extraMsgArgs.fromname, privateMsg.msgInfo.voiceTime, privateMsg.msgInfo.emoji, 0,nil, Define.Page.PRIVATE,extraMsgArgs.senderUserId, extraMsgArgs)
    Lib.emitEvent(Event.EVENT_RECEIVE_PRIVATE_MSG, extraMsgArgs)
end

function UIChatManage:receiveHistoryTalkList(listInfo)
    Lib.logDebug("UIChatManage receiveHistoryTalkList ", Lib.v2s(listInfo,1))
    self:decodeJsonPrivateHistoryList(listInfo)
end

function UIChatManage:receiveHistoryTalkDetail(targetId, detailContent)
    Lib.logDebug("UIChatManage receiveHistoryTalkDetail ",targetId, detailContent)
    local detailTb = self:safeDecodeJSON(detailContent)

    Lib.logDebug("UIChatManage receiveHistoryTalkDetail  detailTb ",Lib.v2s(detailTb,1))
    --删除未全量标签
    self.undetailHistoryDic[targetId] = false
    --刪除预先显示的第一条消息
    --UI:getWnd("chatMain"):cleanPrivateContent(targetId)
    local jumpFirst = false
    for _,item in pairs(detailTb) do
        if jumpFirst then
            self:receivePlatformPrivateMsg(false, false,item,true)
        else
            jumpFirst = true
        end

    end
    --处理全量历史消息同步期间缓存的新消息
    if self.cacheNewMsgDic[targetId] then
        for _ ,cache in pairs(self.cacheNewMsgDic[targetId]) do
            self:receiveFriendPrivateMsg(cache)
        end
        self.cacheNewMsgDic[targetId] = nil
    end


end

function UIChatManage:safeDecodeJSON(content,def)
    local ok, ret = xpcall(cjson.decode, debug.traceback, content)
    if not ok then
        print("json decode fail:",content)
        return def or false
    end
    return ret
end

function UIChatManage:safeEncodeJSON(tb)
    local ok, ret = xpcall(cjson.encode, debug.traceback, tb)
    if not ok then
        print("json encode fail:",Lib.v2s(tb,2))
        return false
    end
    return ret
end

function UIChatManage:addOneNeedOnlineItem(item)
    if type(item) == "table" then
        for _, val in pairs(item) do
            if val.userId then
                self.needGetOnlineList[val.userId] = true
            end
        end
    else
        self.needGetOnlineList[item] = true
    end
end

function UIChatManage:getNeedOnlineList()
    local userIds = {}
    for userId, val in pairs(self.needGetOnlineList) do
        table.insert(userIds, userId)
    end
    return userIds
end

-- 获取玩家的在线状态
function UIChatManage:getChatPlayerOnlineState(userId)
    return self.playerOnlineStateCache[userId] or 30
end

--请求玩家在线状态
function UIChatManage:requestPlayerOnlineState()
    local userIds = self:getNeedOnlineList()
    if #userIds > 0 then
        local callFunc = function(data)
            self.playerOnlineStateCache = {}
            for _, onlineData in pairs(data) do
                self.playerOnlineStateCache[onlineData.userId] = onlineData.status
            end
            Lib.emitEvent(Event.EVENT_UPDATE_ONLINE_STATE_SHOW)
        end
        AsyncProcess.GetPlayerOnlineState(userIds, callFunc)
    end
end

function UIChatManage:sendNormalChat(pid, msg, time, emoji)
    local packet ={
        pid = pid,
        fromname = Me.name,
        msg = msg,
        voiceTime = time or false,
        emoji = emoji or false,
        senderUserId = Me.platformUserId
    }
    Me:sendPacket(packet)
end

-- 请求服务端发送聊天
function UIChatManage:requestServerSendChatMsg(curTab, msg, time, emoji)
    if curTab == Define.Page.COMMON then
        self:sendNormalChat("ChatMessage", msg, time, emoji)
        Me:sendNormalChatBuriedPoint("ChatMessage", msg, time, emoji)
    elseif curTab == Define.Page.FAMILY then
        self:sendNormalChat("ChatMessageToFamily", msg, time, emoji)
        Me:sendNormalChatBuriedPoint("ChatMessageToFamily", msg, time, emoji)
    elseif curTab == Define.Page.PRIVATE then
        if time then
            -- 私聊的语音消息走融云了
        else
            UIChatManage:sendFriendPrivateMsg(msg, emoji)
        end
    elseif curTab == Define.Page.MAP_CHAT then
        self:sendNormalChat("ChatMessageToMap", msg, time, emoji)
        Me:sendNormalChatBuriedPoint("ChatMessageToMap", msg, time, emoji)
    elseif curTab == Define.Page.TEAM then
        self:sendNormalChat("ChatMessageToTeam", msg, time, emoji)
        Me:sendNormalChatBuriedPoint("ChatMessageToTeam", msg, time, emoji)
    elseif curTab == Define.Page.CAREER then
        self:sendNormalChat("ChatMessageToCareer", msg, time, emoji)
        Me:sendNormalChatBuriedPoint("ChatMessageToCareer", msg, time, emoji)
    else
        self:sendNormalChat("ChatMessage", msg, time, emoji)
        Me:sendNormalChatBuriedPoint("ChatMessage", msg, time, emoji)
    end
end

--------------------------reload----------------------------------
function UIChatManage:doDeleteFriendOperate(userId, playerName)
    AsyncProcess.FriendOperation(FriendManager.operationType.DELETE, userId)
end

--game rewrite
---@class SpData
---@field txt1 string
---@field icon1 string
---@field txt2 string
---@field icon2 string
---@return SpData
function UIChatManage:getSpDataByUserSpInfo(data, curUserId)
    ---@type SpData
    local ret = nil
    return ret
end

--game rewrite
---@class TopData
---@field title1 string
---@field txt1 string
---@field icon1 string
---@field title2 string
---@field txt2 string
---@field icon2 string
---@return TopData
function UIChatManage:getTopDataByUserSpInfo(data, curUserId)
    ---@type TopData
    local ret = nil
    return ret
end
---@class FriendItemSpData
---@field icon string
---@field txt string
---@return TopData
function UIChatManage:getFriendItemSpInfo(data)
    ---@type FriendItemSpData
    local ret = nil
    return ret
end

-- 在线游戏好友在游戏内的地图名
function UIChatManage:getOnlineFriendLocationMap(userId)
    return nil
end

-- 获取组队喊话职业图标
function UIChatManage:getTeamJoinCareerIcon(classId)
    return nil
end