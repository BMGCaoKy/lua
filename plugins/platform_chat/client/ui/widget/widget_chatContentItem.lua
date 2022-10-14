local widget_base = require "ui.widget.widget_base"
local M = Lib.derive(widget_base)
local chatSetting = World.cfg.chatSetting
local EmojiConfig = T(Config, "EmojiConfig")
local ShortConfig = T(Config, "ShortConfig")
--- @type UIChatManage
local UIChatManage = T(UIMgr, "UIChatManage")

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

function M:init()
    widget_base.init(self, "ChatContentItem.json")
    self:initWnd()
    self:initData()
    self:initEvent()
end

function M:initWnd()
    local size = chatSetting.alignment and chatSetting.alignment.miniSize or {450, 250, 400}
    self._root:SetHeight({0,(chatSetting.chtBarHeight or 30)})
    self._root:SetWidth({0,size[1] - 13})
    self.imgSound = self:child("ChatContentItem-Sound-Bar")
    self.txtChat = self:child("ChatContentItem-Text")
    self.txtChat:SetFontSize(chatSetting.chatFont or "HT16")
    self.imgPoint = self:child("ChatContentItem-Point")
    self.txtSoundTime = self:child("ChatContentItem-Sound-Time")
    self.txtPlaying = self:child("ChatContentItem-Sound-Playing")
    self.lytOpenPlayer = self:child("ChatContentItem-Open-Player")
    self.imgEffect = self:child("ChatContentItem-Effect")
    self.imgEmoji = self:child("ChatContentItem-Emoji")

    local miniContentSpacing = chatSetting.miniContentSpacing or 0
    self.txtChat:SetTextLineExtraSpace(miniContentSpacing)

    self.imgTypeBg = self:child("ChatContentItem-typeBg")
    self.txtTypeStr = self:child("ChatContentItem-typeStr")
    self.txtTypeStr:SetFontSize(chatSetting.chatFont or "HT16")

    if chatSetting.chatMiniVoiceColor then
        self.txtSoundTime:SetTextColor(getColorOfRGB(chatSetting.chatMiniVoiceColor))
    end

    self.imgEffect:SetVisible(false)
    self.txtPlaying:SetVisible(false)
end
function M:initData()
end

function M:initEvent()
    self:lightSubscribe("error!!!!! script_client widget_chatContentItem imgSound event : EventWindowClick",self.imgSound, UIEvent.EventWindowClick, function()
        if not self.data.playing then
            self:onPlaySound()
        end
    end)

    self:lightSubscribe("error!!!!! script_client widget_chatContentItem lytOpenPlayer event : EventWindowClick",self.lytOpenPlayer, UIEvent.EventWindowClick, function()
        if self.data and #self.data.fromname >0 then
            self.data.nameColorStr = self.nameColorStr
            UIChatManage:openChatPlayerInfoWnd(self.data.platId)
        end
    end)

    self.voiceStart = Lib.lightSubscribeEvent("error!!!!! script_client widget_chatContentItem Lib event : EVENT_CHAT_VOICE_START",Event.EVENT_CHAT_VOICE_START, function(path)
        local voiceName = string.sub(path,-19)
        if not self.data then
            return 
        end
        local voiceName2 = string.sub(self.data.msg,-19)
        if self.data.voiceTime  and voiceName2 == voiceName then
            self.data.isRead = true
            self.data.playing = true
            self.imgPoint:SetVisible(false)
            self.imgEffect:SetVisible(true)
            self.txtPlaying:SetVisible(true)
        end
    end)
    self.voiceEnd = Lib.lightSubscribeEvent("error!!!!! script_client widget_chatContentItem Lib event : EVENT_CHAT_VOICE_END",Event.EVENT_CHAT_VOICE_END, function(path)
        if not self.data then
            return
        end
        local voiceName = string.sub(path,-19)
        local voiceName2 = string.sub(self.data.msg,-19)
        if self.data.voiceTime  and voiceName == voiceName2 then
            self.imgEffect:SetVisible(false)
            self.txtPlaying:SetVisible(false)
            self.data.playing = false
        end
    end)
end

function M:onPlaySound()
    if not self.data.isRead then
        self.data.isRead = true
        self.imgPoint:SetVisible(false)
    end
    VoiceManager:playVoice(self.data.msg,self.data.times)
end

local function getColorOfRGB(str)
    local curColorStr = str or "000000"
    -- 去掉#字符
    local newstr = string.gsub(curColorStr, '#', '')

    -- 每次截取两个字符 转换成十进制
    local colorlist = {}
    local index = 1
    while index < string.len(newstr) do
        local tempstr = string.sub(newstr, index, index + 1)
        table.insert(colorlist, tonumber(tempstr, 16))
        index = index + 2
    end

    return {(colorlist[1] or 0)/255, (colorlist[2] or 0)/255, (colorlist[3] or 0)/255, 1}
end

local function getBorderColor(str)
    local curColorStr = str or "000000"
    -- 去掉#字符
    local newstr = string.gsub(curColorStr, '#', '')

    -- 每次截取两个字符 转换成十进制
    local colorlist = {}
    local index = 1
    while index < string.len(newstr) do
        local tempstr = string.sub(newstr, index, index + 1)
        table.insert(colorlist, tonumber(tempstr, 16))
        index = index + 2
    end
    return tostring(colorlist[1]/255) .. " " .. tostring(colorlist[2]/255) .. " " .. tostring(colorlist[3]/255) .. " 1"
end

local function getColorStr(colorlist)
    local curColorStr = "FF"
    for i = 1, 3 do
        local num = math.floor(colorlist[i]*255)
        local tempStr =  string.sub(string.format("%#x",num), 3)
        curColorStr = curColorStr .. tempStr
    end
    return curColorStr
end

function M:initNameColor(data)
    if data.type == Define.Page.SYSTEM then
        self.nameColorStr = ""
        return
    end

    local defaultNameColor = chatSetting.miniNiceNameColor or "FF0000"
    if chatSetting.isOpenChatHeadColor then
        self.nameColorStr = "FF"..(data.nameColor or defaultNameColor)
    else
        self.nameColorStr = "FF"..defaultNameColor
    end
    self.voiceColorStr = "FF"..(chatSetting.chatMiniVoiceColor or "000000")
    if data.platId == Me.platformUserId then
        self.nameColorStr =  "FF"..(chatSetting.miniSelfNameColor or "33BD41")
        self.voiceColorStr = "FF"..(chatSetting.chatMiniVoiceColor or "000000")
    --elseif not data.dign then
        --self.nameColorStr = "FF"..(chatSetting.miniNiceNameColor or "FF0000")
    elseif data.dign == Define.ChatPlayerType.server then
        self.nameColorStr = "FFFFFFFF"
    elseif data.dign == Define.ChatPlayerType.vip then
        self.nameColorStr = "FFFAFF07"
    elseif data.dign == Define.ChatPlayerType.svip then
        self.nameColorStr = "FFEC0420"
    end
end

--系统消息
function M:initSystemMsg(data)
    self.nameColorStr = ""
    self.imgEffect:SetVisible(false)
    self.imgSound:SetVisible(false)
    self.imgEmoji:SetVisible(false)
    self.lytOpenPlayer:SetVisible(false)
    local preNullStr
    if chatSetting.isShowChannel then
        preNullStr = "                 "
        self.imgTypeBg:SetVisible(true)
        self.txtTypeStr:SetVisible(true)
        local preTypeStr =  Lang:toText("ui.chat.chatMsgType" .. Define.Page.SYSTEM)
        local curColor = getColorOfRGB(chatSetting.chatTypeColor[data.type])
        self.imgTypeBg:SetDrawColor(curColor)
        local borderColor = getBorderColor(chatSetting.chatTypeColor[data.type])
        self.txtTypeStr:SetProperty("TextBorderColor", borderColor)
        self.txtTypeStr:SetText(preTypeStr)
    else
        preNullStr = ""
        self.imgTypeBg:SetVisible(false)
        self.txtTypeStr:SetVisible(false)
    end

    self.contentColorStr = "FF" .. chatSetting.chatTypeColor[Define.Page.SYSTEM] or "000000"
    local finalShowStr = preNullStr .. "▢"..self.contentColorStr..""..data.msg

    self:autoBarSize(preNullStr .. data.msg)
    self.txtChat:SetText(finalShowStr)
end

-- 名字过长的截取两个字符部分名字
function M:getOneShortName(name)
    local isColorName = false
    if string.find(name,"ffca00ff",1,15) then
        isColorName = true
        -- sub  67
        name = string.sub(name,68,-3)
    end
    local endIndex = Lib.subStringGetTotalIndex(name);
    local maxLen = chatSetting.miniChatNameMaxLen or 7
    if endIndex > maxLen then
        local content = Lib.subStringUTF8(name, 1, maxLen)
        if isColorName then
            content = "&$[ffca00ff-fbd33fff-cad2ceff-23b8feff-677dffff-ac61ffff-fd15ffff]$"..content.."$&"
        end
        return content .. "..."
    end
    if isColorName then
        name = "&$[ffca00ff-fbd33fff-cad2ceff-23b8feff-677dffff-ac61ffff-fd15ffff]$"..name.."$&"
    end
    return name
end


function M:listenDetailInfo(platId)
    if not platId then
        Lib.logError("ChatContentItem:listenDetailInfo id is nil!")
        return
    end
    if self.userDetailInfoCancel then
        self.userDetailInfoCancel()
    end
    self.userDetailInfoCancel = Lib.lightSubscribeEvent("error!!!!! EVENT_USER_DETAIL","EVENT_USER_DETAIL"..platId, function(data)
        --self.data.finalShowStr = string.gsub(self.data.finalShowStr,self.data.fromname,data.nickName,1)
        local startIndex, endIndex = string.find(self.data.finalShowStr, self.data.fromname, 1, true)
        if data.nickName and startIndex and startIndex > 0 then
            local preStr = string.sub(self.data.finalShowStr, 1, startIndex - 1 )
            local endStr = string.sub(self.data.finalShowStr, endIndex + 1)
            self.data.finalShowStr = preStr .. data.nickName .. endStr
        end
    end)
    UIChatManage:initDetailInfo(platId)
end

function M:initViewByData(data)
    self.data = data
    if data.type == Define.Page.SYSTEM then
        self:initSystemMsg(data)
        return
    end
    self.lytOpenPlayer:SetVisible(true)
    if self.data.playing then
        self.imgEffect:SetVisible(true)
    else
        self.imgEffect:SetVisible(false)
    end
    self:initNameColor(data)

    local preTypeStr = ""
    if self.data.platId then
        print("initViewByData self.data.platId:",self.data.platId)
        local detailInfo = UIChatManage:getUserDetailInfo(self.data.platId)
        if detailInfo then
            data.fromname = detailInfo.nickName or ""
        else
            self:listenDetailInfo(self.data.platId)
        end
    end

    local preNullStr
    if chatSetting.isShowChannel then
        preNullStr = "                 "
        self.imgTypeBg:SetVisible(true)
        self.txtTypeStr:SetVisible(true)
    else
        preNullStr = ""
        self.imgTypeBg:SetVisible(false)
        self.txtTypeStr:SetVisible(false)
    end

    local initNameStr = "[".. self:getOneShortName(data.fromname) .."]:"
    local preNameStr = preNullStr .. initNameStr

    self.contentColorStr = "FF"..(chatSetting.chatFontColor or "000000")
    if data.type then
        preTypeStr = Lang:toText("ui.chat.chatMsgType" .. data.type)
        local curColor = getColorOfRGB(chatSetting.chatTypeColor[data.type])
        self.imgTypeBg:SetDrawColor(curColor)
        local borderColor = getBorderColor(chatSetting.chatTypeColor[data.type])
        self.txtTypeStr:SetProperty("TextBorderColor", borderColor)
        if chatSetting.miniFontColorUsePre then
            self.contentColorStr = "FF".. chatSetting.chatTypeColor[data.type] or "000000"
        end
    end

    if data.dign == Define.ChatPlayerType.server then
        preTypeStr = Lang:toText("ui.chat.chatMsgType" .. Define.Page.SYSTEM)
        preNameStr = preNullStr
    end
    self.txtTypeStr:SetText(preTypeStr)

    local nameLen = self.txtChat:GetFont():GetStringWidth(preNameStr)
    local nameWidth = self.txtChat:GetFont():GetStringWidth(initNameStr)
    local preStrWidth = self.txtTypeStr:GetFont():GetStringWidth(preNullStr)
    self.lytOpenPlayer:SetWidth({0, nameWidth})
    self.lytOpenPlayer:SetXPosition({0, 5 + preStrWidth})

    self.data.finalShowStr = ""
    if data.voiceTime then
        self.imgEmoji:SetVisible(false)
        if not data.isRead then
            data.isRead = data.objID==Me.objID
        end
        self.imgPoint:SetVisible(not data.isRead)
        local times = math.floor(data.voiceTime/1000)
        self.txtSoundTime:SetText("▢"..self.voiceColorStr .. times.."''")
        self.imgSound:SetVisible(true)

        self.data.finalShowStr = "▢"..self.nameColorStr.. preNameStr
        self.imgSound:SetXPosition({0, 15 + nameLen})
        self.imgSound:SetWidth({0,50+150*(times/chatSetting.voiceMaxTime or 59)})
        self:autoBarSize(preNullStr .. initNameStr)
    elseif data.emoji and data.emoji.type == Define.chatEmojiTab.FACE then
        self.imgSound:SetVisible(false)
        self.imgEmoji:SetVisible(true)
        self.imgEmoji:SetImage(data.emoji.emojiData)
        self.data.finalShowStr = "▢"..self.nameColorStr.. preNameStr

        self.imgEmoji:SetXPosition({0, 15 + nameLen})

        self:autoBarSize(preNullStr .. initNameStr)
    else
        -- 宠物、物品超链接
        if data.emoji then
            if data.emoji.type == Define.chatEmojiTab.PET then
                local petData = Me:decodeChatPetBodyJson(data.emoji.emojiData)
                self.contentColorStr = getColorStr( petData.nameColor)
                data.msg = "[" .. petData.name .. "]"
            elseif data.emoji.type == Define.chatEmojiTab.GOODS then
                local goodsData = Me:decodeChatGoodBodyJson(data.emoji.emojiData)
                data.msg = "[" .. goodsData.name .. "]"
            end
        end
        self.imgEmoji:SetVisible(false)
        self.imgSound:SetVisible(false)
        local finalMsg = data.msg
        if  data.dign == Define.ChatPlayerType.server then
            preTypeStr = Lang:toText("ui.chat.chatMsgType" .. Define.Page.SYSTEM)
            local msg = Lang:toText(data.msg)
            self.data.finalShowStr = preNullStr .. "▢"..self.contentColorStr.."".. msg
        else
            if data.fromname and #data.fromname>0 then
                local text = data.msg
                local item = ShortConfig:getItemByName(text)
                if item then
                    finalMsg = Lang:toText(text)
                end
                self.data.finalShowStr = "▢"..self.nameColorStr.. preNameStr .."▢"..self.contentColorStr.."".. finalMsg
            else
                preTypeStr = Lang:toText("ui.chat.chatMsgType" .. Define.Page.SYSTEM)
                self.data.finalShowStr = preNullStr .. "▢"..self.contentColorStr..""..data.msg
            end
        end
        self:autoBarSize(preNullStr .. initNameStr .. finalMsg)
    end
    self.txtChat:SetText(self.data.finalShowStr)
end

function M:autoBarSize(msg)
    local onlineHeight = chatSetting.chtBarHeight or 30
    local strW = self.txtChat:GetFont():GetStringWidth(msg)
    local rootW =  self._root:GetWidth()[2]
    local txtNodeW = self.txtChat:GetWidth()
    local uiW = rootW*txtNodeW[1] + txtNodeW[2]
    uiW = uiW>0 and uiW or -uiW
    if strW > uiW then
        local offsetLine = math.ceil(strW/uiW)
        local miniContentSpacing = chatSetting.miniContentSpacing or 0
        local curHeight = onlineHeight + (offsetLine-1)*(onlineHeight+miniContentSpacing)
        self._root:SetHeight({0, curHeight})
    else
        self._root:SetHeight({0, onlineHeight})
    end
end

function M:SetWidth(width1, width2)
    self._root:SetWidth({width1, width2})
end

function M:onDestroy()
    if self.voiceStart then
        self.voiceStart()
    end
    if self.voiceEnd then
        self.voiceEnd()
    end
    if self.userDetailInfoCancel then
        self.userDetailInfoCancel()
    end
end

function M:onInvoke(key, ...)
    local fn = M[key]
    assert(type(fn) == "function", key)
    return fn(self, ...)
end

return M
