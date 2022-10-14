local widget_base = require "ui.widget.widget_base"
local M = Lib.derive(widget_base)
local chatSetting = World.cfg.chatSetting
local EmojiConfig = T(Config, "EmojiConfig")
local ShortConfig = T(Config, "ShortConfig")
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
    local size = chatSetting.alignment and chatSetting.alignment.miniSize or {617, 203, 336}
    self._root:SetHeight({0,(chatSetting.chtBarHeight or 28)})
    self._root:SetWidth({0,size[1] - 8})
    self.imgSound = self:child("ChatContentItem-Sound-Bar")
    self.txtChat = self:child("ChatContentItem-Text")
    self.txtChat:SetFontSize(chatSetting.chatFont or "HT16")
    self.imgPoint = self:child("ChatContentItem-Point")
    self.txtSoundTime = self:child("ChatContentItem-Sound-Time")
    self.txtPlaying = self:child("ChatContentItem-Sound-Playing")
    self.lytOpenPlayer = self:child("ChatContentItem-Open-Player")
    self.imgEffect = self:child("ChatContentItem-Effect")
    self.imgEmoji = self:child("ChatContentItem-Emoji")
    self.imgEffect:SetVisible(false)
    self.txtPlaying:SetVisible(false)
    self.imgEmoji:SetVisible(false)
    if chatSetting.chatVoiceColor then
        self.txtSoundTime:SetTextColor(getColorOfRGB(chatSetting.chatVoiceColor))
    end
end
function M:initData()
end

function M:initEvent()
    -- print(debug.traceback())
    self:lightSubscribe("error!!!!! script_client widget_chatContentItem imgSound event : EventWindowClick",self.imgSound, UIEvent.EventWindowClick, function()
        if not self.data.playing then
            self:onPlaySound()
        end
    end)

    self:lightSubscribe("error!!!!! script_client widget_chatContentItem lytOpenPlayer event : EventWindowClick",self.lytOpenPlayer, UIEvent.EventWindowClick, function()
        if self.data and #self.data.fromname >0 then
            self:onOpenInfo()
        end
    end)

    self.voiceStart = Lib.lightSubscribeEvent("error!!!!! script_client widget_chatContentItem Lib event : EVENT_CHAT_VOICE_START",Event.EVENT_CHAT_VOICE_START, function(path)
        --   print("EVENT_CHAT_VOICE_START ininininininininininininininini")
        local voiceName = string.sub(path,-19)
        -- self.voiceTimer = World.Timer(2, function()
            
        -- end)
        if not self.data then
            --   print("EVENT_CHAT_VOICE_START but data still void")
            return 
        end
        --  print("self.data.voiceTime:",self.data.voiceTime)
        --  print("voiceName:",voiceName)
        --  print("voiceName2:",voiceName2)
        local voiceName2 = string.sub(self.data.msg,-19)
        if self.data.voiceTime  and voiceName2 == voiceName then
            self.data.isRead = true
            self.data.playing = true
            self.imgPoint:SetVisible(false)
            self.imgEffect:SetVisible(true)
            self.txtPlaying:SetVisible(true)
            -- self.imgSound:SetDrawColor({ 150/255, 255/255, 223/255 , 1 })
            -- print("-----------------EVENT_CHAT_VOICE_START  item------------------")
        else
            -- print("----------------EVENT_CHAT_VOICE_START------no pick  voiceName------------",voiceName)
            -- print("----------------EVENT_CHAT_VOICE_START------no pick  voiceName2------------",voiceName2)
        end 
        -- self.voiceTimer()
        -- self.voiceTimer = nil
        -- return false
        
       
    end)
    self.voiceEnd = Lib.lightSubscribeEvent("error!!!!! script_client widget_chatContentItem Lib event : EVENT_CHAT_VOICE_END",Event.EVENT_CHAT_VOICE_END, function(path)
        -- print("EVENT_CHAT_VOICE_END ininininininininininininininini")
        -- World.Timer(1, function()
           
        -- end)
        if not self.data then
            -- print("EVENT_CHAT_VOICE_END but data still void")
            return
        end
        local voiceName = string.sub(path,-19)
        local voiceName2 = string.sub(self.data.msg,-19)
        -- print("----------------EVENT_CHAT_VOICE_END------no pick  voiceName------------",voiceName)
        -- print("----------------EVENT_CHAT_VOICE_END------no pick  voiceName2------------",voiceName2)
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
    VoiceManager:playVoice(self.data.msg)
end
function M:onOpenInfo()
     --print("=======================================self.data.objID",Lib.v2s(self.data))
    if self.data.objID == -1 or not self.data.fromname or self.data.fromname =="" or not self.data.platId or self.data.platId == Me.platformUserId then
        return
    end
    -- print("=======================================self.data.objID",self.data.objID)
    -- print("=======================================Me.objID",Me.objID)
    Lib.emitEvent("EVENT_OPEN_CHAT_PLAYER", {self.data.objID,self.data.fromname,self.nameColorStr,self.data.platId})
    UI:openWnd("chatPlayerInfo", {
        objId = self.data.objID,
        name = self.data.fromname,
        nameColor = self.nameColorStr,
        uId = self.data.platId
    })
end

function M:initItem(data)
    self.data = data
    if self.data.playing then
        self.imgEffect:SetVisible(true)
    else
        self.imgEffect:SetVisible(false)
    end
    --self:setSide(data.fromname == Me.name)
    local defaultNameColor = chatSetting.chatNiceNameColor or "FF0000"
    self.nameColorStr = "FF"..(data.nameColor or defaultNameColor)
    local contentColorStr = "FF"..(chatSetting.chatFontColor or "000000")
    if data.fromname ==Me.name then
        self.nameColorStr = "FF"..(chatSetting.chatSelfNameColor or "33BD41")
    --elseif not data.dign then
    --    self.nameColorStr = "FF"..(chatSetting.chatNiceNameColor or "FF0000")
    elseif data.dign == Define.ChatPlayerType.server then
        self.nameColorStr = "FFFFFFFF"
        contentColorStr = "FF909090"
    --elseif data.dign == Define.ChatPlayerType.vip then
    --    self.nameColorStr = "FFFAFF07"
    --elseif data.dign == Define.ChatPlayerType.svip then
    --    self.nameColorStr = "FFEC0420"
    end

    if not data.fromname then
        return
    end
    local numLen =  #data.fromname
    local nameLen = self.txtChat:GetFont():GetStringWidth("["..data.fromname.."]:")
    -- print("nameLennameLennameLennameLennameLennameLennameLennameLennameLennameLennameLennameLennameLennameLen:",nameLen)
    -- self.lytOpenPlayer:SetWidth({0,30+10*numLen})
    self.lytOpenPlayer:SetWidth({0,nameLen})
    if data.voiceTime then
        if not data.isRead then
            data.isRead = data.objID==Me.objID
        end
        self.imgEmoji:SetVisible(false)
        self.imgPoint:SetVisible(not data.isRead)
        local times = math.floor(data.voiceTime/1000)
        self.txtSoundTime:SetText(times.."''")
        self.imgSound:SetVisible(true)
        -- if not Me.test then
        --     Me.test = "aaaa"
        -- end
        -- Me.test = Me.test.. "a"
        
        -- data.fromname = Me.test
        if false and data.fromname ==Me.name then
            self.txtChat:SetText(":▢"..self.nameColorStr.."["..data.fromname.."]")
        else
            self.txtChat:SetText("▢"..self.nameColorStr.."["..data.fromname.."]:")
        end

        self.imgSound:SetXPosition({0, 15+nameLen})
        
        self.imgSound:SetWidth({0,50+150*(times/chatSetting.voiceMaxTime or 59)})
        print("self.imgSound:GetWidth()",Lib.v2s(self.imgSound:GetWidth(),2))
    --elseif data.emoji then
    --    if false and data.fromname ==Me.name then
    --        self.txtChat:SetText(":�..self.nameColorStr.."["..data.fromname.."]")
    --    else
    --        self.txtChat:SetText("�..self.nameColorStr.."["..data.fromname.."]:")
    --    end
    --    self.imgSound:SetVisible(false)
    --    self.imgEmoji:SetVisible(true)
    --    self.imgEmoji:SetImage(data.emoji)
    else
        self.imgSound:SetVisible(false)
        self.imgEmoji:SetVisible(false)
        if  data.dign == Define.ChatPlayerType.server then
            -- if #data.fromname >0 then
            --     self.txtChat:SetText("�..self.nameColorStr.."["..Lang:toText(data.fromname).."]: �..contentColorStr..""..data.msg)
            -- else
            --     self.txtChat:SetText("�..self.nameColorStr.."�..contentColorStr..""..data.msg)
            -- end
            if false and data.fromname ==Me.name then
                self.txtChat:SetText("▢"..contentColorStr..""..data.msg .. "▢"..self.nameColorStr)
            else
                self.txtChat:SetText("▢"..self.nameColorStr.."▢"..contentColorStr..""..data.msg)
            end

            
            -- print("$$$$$$$$$$$$$$$$$$$$$$$$",data.msg)
            -- local listStr = Lib.splitString(data.msg, ",")
            -- print("$$$$$$$$$$$$$$$$$$$$$$$$",Lib.v2s(listStr))
            -- if #listStr == 1 then 
            --     self.txtChat:SetText("�..self.nameColorStr.."["..Lang:toText("ui.chat.system").."]: �..contentColorStr..""..Lang:toText(data.msg))
            -- else
            --     self.txtChat:SetText("�..self.nameColorStr.."["..Lang:toText("ui.chat.system").."]: �..contentColorStr..""..Lang:toText(listStr))
            -- end
            
            -- if data.msg == "offline" then
                
            -- elseif data.msg == "voiceFail" then
            --     self.txtChat:SetText("�..self.nameColorStr.."["..Lang:toText("ui.chat.system").."]:�..contentColorStr..""..Lang:toText("ui.chat.voiceless"))
            -- end
        else
            if data.fromname and #data.fromname>0 then
                --if false and data.fromname == Me.name then
                --    self.txtChat:SetText("�..contentColorStr..""..data.msg .. ":�..self.nameColorStr.."["..data.fromname.."]")
                --else
                --    self.txtChat:SetText("�..self.nameColorStr.."["..data.fromname.."]: �..contentColorStr..""..data.msg)
                --end
                --print("datadata:",Lib.v2s(data,2))
                if data.emoji then
                    local txt = EmojiConfig:getTextByIcon(data.emoji) and Lang:toText(EmojiConfig:getTextByIcon(data.emoji)) or "emoji"
                    self.txtChat:SetText("▢"..self.nameColorStr.."["..data.fromname.."]: ▢"..contentColorStr.."[" .. txt .. "]")
                else
                    local text = data.msg
                    local item = ShortConfig:getItemByName(text)
                    if item then
                        text = Lang:toText(text)
                    end
                    self.txtChat:SetText("▢"..self.nameColorStr.."["..data.fromname.."]: ▢"..contentColorStr.."".. text)
                end
            else
                self.txtChat:SetText("▢"..contentColorStr..""..data.msg)
            end
            
        end
    end
end

function M:onDataChanged(data)
    -- print("-------onDataChanged--------",Lib.v2s(data))
    self:initItem(data)
end

function M:setSide(isSelf)
    if isSelf then
        self.txtChat:SetXPosition({0, -10})
        self.txtChat:SetHorizontalAlignment(2)
        self.txtChat:SetTextHorzAlign(2)
        self.lytOpenPlayer:SetHorizontalAlignment(2)
        self.imgEmoji:SetXPosition({0, -102})
        self.imgEmoji:SetHorizontalAlignment(2)
        self.imgSound:SetXPosition({0, -102})
        self.imgSound:SetHorizontalAlignment(2)
        self.imgPoint:SetXPosition({0, -10})
        self.imgPoint:SetHorizontalAlignment(2)
        self.txtSoundTime:SetXPosition({0, -25})
        self.txtSoundTime:SetHorizontalAlignment(0)
        self.txtPlaying:SetXPosition({0, -50})
        self.txtPlaying:SetHorizontalAlignment(0)
        self.imgEffect:SetRotate(180)
        self.imgSound:SetRotate(180)
    else
        self.txtChat:SetXPosition({0, 10})
        self.txtChat:SetHorizontalAlignment(0)
        self.txtChat:SetTextHorzAlign(0)
        self.lytOpenPlayer:SetHorizontalAlignment(0)
        self.imgEmoji:SetXPosition({0, 102})
        self.imgEmoji:SetHorizontalAlignment(0)
        self.imgSound:SetXPosition({0, 102})
        self.imgSound:SetHorizontalAlignment(0)
        self.imgPoint:SetXPosition({0, 10})
        self.imgPoint:SetHorizontalAlignment(0)
        self.txtSoundTime:SetXPosition({0, 25})
        self.txtSoundTime:SetHorizontalAlignment(2)
        self.txtPlaying:SetXPosition({0, 50})
        self.txtPlaying:SetHorizontalAlignment(2)
        self.imgEffect:SetRotate(0)
        self.imgSound:SetRotate(0)
    end
end

function M:onDestroy()
    -- print("$$$$$$$$$$$$$$$$$$$$$$$$$$$$$destory")
    if self.voiceStart then
        self.voiceStart()
    end
    if self.voiceEnd then
        self.voiceEnd()
    end
end

function M:onInvoke(key, ...)
    local fn = M[key]
    assert(type(fn) == "function", key)
    return fn(self, ...)
end

return M
