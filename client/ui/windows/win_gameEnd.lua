local strfor = string.format

local gInstance = CGame.instance
local m_gameReslut, m_showAll

function M:init()
    WinBase.init(self, "GameEnd.json", true)
    self.exitBtn = self:child("GameEnd-Content-Exit")
    self.exitBtn:SetText(Lang:toText("gui.exit"))
    self.exitBtn:SetPushedImage("set:new_frame_common.json image:btn_green.png")
    self.exitBtn:SetNormalImage("set:new_frame_common.json image:btn_green.png")
    self:subscribe(self.exitBtn, UIEvent.EventButtonClick, function()
        self:exitbutton()
    end)

    self.nextBtn = self:child("GameEnd-Content-Next")
    self.nextBtn:SetText(Lang:toText("gui.continue"))
    self:subscribe(self.nextBtn, UIEvent.EventButtonClick, function()
        self:onNextClick()
    end)

    self.nameTxt = self:child("GameEnd-Content-Name")
    self.m_title = self:child("GameEnd-Title")
    self.m_title:SetText(Lang:toText("dead.summary.title"))
    self.m_title:SetScale({ x = 1, y = 1, z = 1 })

    self.eliminatedTipTitle = self:child("GameEnd-Content-Eliminated-Tip")
    self.eliminatedTipTitle:SetText(Lang:toText("dead_summary_eliminated_title"))

    self.showInfo = self:child("GameEnd-ShowInfo")
end

local function getResultEntry(result)
    local item = {}
    item.name = result.name
    item.vip = tonumber(result.vip)
    item.showPairs = result.showPairs
    return item
end

function M:onOpen(result, title, func)
    m_showAll = func
    m_gameReslut = getResultEntry(result)
    if title then
        self.eliminatedTipTitle:SetText(Lang:toText(title))
    end
    self:refreshUI()
	self.openArgs = table.pack(result, title, func)
end

function M:refreshUI()
    if not m_gameReslut then
        return
    end
    local name = m_gameReslut.name

    self.nameTxt:SetText(tostring(name))
    -- self:setVipIcon(m_gameReslut.vip)

    self.showInfo:ClearAllItem()
    for i = 1, #m_gameReslut.showPairs do 
        local temp = m_gameReslut.showPairs[i]
        local baseStr = Lang:toText(temp[1])
        local exStr = Lang:toText(temp[2])
        local text = UIMgr:new_widget("text", 300, 50, baseStr, exStr) --todo width height
        text:invoke("SET_HORIZONALIGN", 1) --水平居中
        text:invoke("SET_TEXT_HORIZONALIGN", 1) --水平居中
        text:invoke("SET_TEXT_COLOR", {105/255, 73/255, 29/255, 1})
        text:invoke("FRAME_AREA", {0.5, -150}, text:GetYPosition(), {0, 300}, nil)
        self.showInfo:AddItem1(text, 0, i - 1)
    end
end

-- function M:setVipIcon(vip)
--     local vipIconRes
--     if vip == 1 then
--         vipIconRes = "set:summary.json image:VIP"
--     elseif vip == 2 then
--         vipIconRes = "set:summary.json image:VIPPlus"
--     elseif vip == 3 then
--         vipIconRes = "set:summary.json image:MVP"
--     else
--         vipIconRes = ""
--     end
--     self:child("GameEnd-Content-VipIcon"):SetImage(vipIconRes)
-- end

function M:exitbutton()
    gInstance:exitGame("gameEnd")
end

function M:onNextClick()
    UI:closeWnd(self)
    m_showAll()
    Game.ReqNextGame()
end

return M