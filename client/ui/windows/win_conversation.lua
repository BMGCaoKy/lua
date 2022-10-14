require "common.entity"
local MAX_ANSWER = 4
local FRIST_PAGE = 1
local OPTION_LIMIT = 2
local talkType = {
    TALK = 0,
    CHOICE = 1,
}

local function updateTalk(self)
    local nextText = self._maxPage == self._curPage and "gui.conversation.finish" or "gui.conversation.next"
    self.nextBtn:SetText(Lang:toText(nextText))
    self.contentText:SetText(Lang:toText(self._talkList[self._curPage].msg))
    local npc = self._npcList[self._talkList[self._curPage].npc]
    local npcCfg = Entity.GetCfg(npc)
	local name = npcCfg.deputyName or npcCfg.name
    self.nameText:SetText(Lang:toText(name))
    if npcCfg.headPic then
        self.headImage:SetImage(ResLoader:filePathJoint(npcCfg, npcCfg.headPic))
    end
end

local function updateChoice(self)
    
    local nextText = self._maxPage == self._curPage and "gui.conversation.ok" or "gui.conversation.next"
    self.nextBtn:SetText(Lang:toText(nextText))
    self.contentText:SetText("")
    local npc = self._npcList[self._optionNpc]
    local npcCfg = Entity.GetCfg(npc)
    self.nameText:SetText(Lang:toText(npcCfg.name))
    if npcCfg.headPic then
        self.headImage:SetImage(ResLoader:filePathJoint(npcCfg, npcCfg.headPic))
    end

    local options = self._optionList
    if #options < OPTION_LIMIT then
        return
    end

    for i = 1, #options do
        local optionUi = GUIWindowManager.instance:LoadWindowFromJSON("ConversationItem.json")
        local x
        local y = {0, 76 * math.floor( i / 3 )}
        if i % 2 == 1 then
            x = {0, 0}
        else
            x = {0.6, 0}
        end

        optionUi:SetArea(x, y, {0.4, 0}, {0, 56})
        self.checkGridView:AddChildWindow(optionUi)
        self:subscribe(optionUi, UIEvent.EventRadioStateChanged, function()
            self:selectOption(i)
        end)
        optionUi:SetText(Lang:toText(options[i].showText))
    end

end

local talkTypeF = {
    [talkType.TALK] = updateTalk,
    [talkType.CHOICE] = updateChoice
}

local function updateFunction(type, self)
    local f = talkTypeF[type]
    f(self)
end

function M:init()
    WinBase.init(self, "app_conversation.json", true)
    self:initUiName()
    self:registerEvent()

end

function M:initUiName()
    self.nextBtn = self:child("app_conversation-btn_next")
    self.lastBtn = self:child("app_conversation-btn_back")
    self.headImage = self:child("app_conversation-Bg"):child("app_conversation-"):child("app_conversation-headPic")
    self.nameText = self:child("app_conversation-nameBG"):child("app_conversation-name")
    self.contentText = self:child("app_conversation-Bg"):child("app_conversation-ContentText")
    self.checkGridView = self:child("app_conversation-Bg"):child("app_conversation-checkGridView")
    self.checkGridView:SetVisible(true)
end

function M:registerEvent()
    self:subscribe(self.nextBtn, UIEvent.EventButtonClick, function()
        self:buttonNext()
    end)
    self:subscribe(self.lastBtn, UIEvent.EventButtonClick, function()
        self:buttonLast()
    end)

end

function M:sendAnswer()
    if self._selectResult <= 0 and #self._optionList >= OPTION_LIMIT then
        return false
    end

    if #self._optionList == 0 then
        return true
    end

    self._selectResult = self._selectResult > 0 and self._selectResult or 1
    Me:doCallBack("Conversation", self._selectResult , self._regId)
    return true
end

function M:hiheAllOption()
    self.checkGridView:CleanupChildren()
end

function M:selectOption(index)
    self._selectResult = index
end

function M:buttonNext()
    self._curPage = self._curPage + 1
    if self._maxPage < self._curPage then
        local ret = not self._optionList or self:sendAnswer() 
        if ret then
            Lib.emitEvent(Event.EVENT_OPEN_CONVERSATION, false)
        end
        self._curPage = self._maxPage
        return
    end

    self:update()
end

function M:buttonLast()
    self._curPage = self._curPage - 1
    if self._curPage < FRIST_PAGE then
        return
    end
    self._selectResult = -1
    self:hiheAllOption()
    self:update()
end

function M:update()
    local showType = talkType.TALK
    if self._curPage == self._maxPage and self._optionList and #self._optionList >= OPTION_LIMIT then
        showType = talkType.CHOICE
    elseif self._curPage > self._maxPage then
        return
    end
    self.lastBtn:SetVisible(self._curPage ~= FRIST_PAGE)
    self.lastBtn:SetText(Lang:toText("gui.conversation.back"))
    updateFunction(showType, self)
end

function M:onOpen(packet, ...)
    self._talkList = packet.talkList
    self._npcList = packet.npcList
    self._optionList = packet.optionList
    self._optionNpc = packet.optionNpc
    self._curPage = FRIST_PAGE
	self._regId = packet.regId
    self._selectResult = -1
    self._maxPage = self._optionList and #self._optionList >= OPTION_LIMIT  and #self._talkList + 1 or #self._talkList
    self:hiheAllOption()    
    self:update()
    self._selectResult = -1
end
