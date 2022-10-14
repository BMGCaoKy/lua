local global_setting = require "editor.setting.global_setting"
local entity_obj = require "editor.entity_obj"

local teamData
local teamName = Lang:toText("win.map.global.setting.team.setting.tab")
local teamColor = {}

local function refreshTeamData()
    teamData = global_setting:getEditTeamMsg()
end

function M:init()
    WinBase.init(self, "teamDetail_edit.json")
    refreshTeamData()
    self.ltGrid = self:child("Team-LtGrid")
    self.ltGrid:InitConfig(0, 3, 1)
    self.ltGrid:SetMoveAble(false)
    self.ltGrid:SetAutoColumnCount(false)
    self.rtLayout = self:child("Team-Layout")
    self.m_root = self:child("Team-root")
    self.infoGrid = self:child("Team-Layout-Grid")

    self:initMask()
    self:initTeamItem()

    self:subscribe(self:child("Team-back"), UIEvent.EventButtonClick, function()
        UI:closeWnd(self)
    end)

    self:child("Team-delTeam"):SetText(Lang:toText("win.map.global.setting.team.setting.delTeam"))
    self:subscribe(self:child("Team-delTeam"), UIEvent.EventButtonClick, function()
        self:delTeam()
    end)
end

function M:sureSave()
    refreshTeamData()
    for _, team in ipairs(teamData) do
        if team.ignorePlayerSkin and not team.actorName then
            team.ignorePlayerSkin = false
        end
    end
    global_setting:saveEditTeamMsg(teamData, false)
    self:checkTeamColorChange(teamData)
    global_setting:onGamePlayerNumberChanged("teams")
    teamData = nil
    UI:closeWnd(self)
end

function M:initMask()
    self.maskBtn = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "maskImge")
    self.maskBtn:SetHeight({0, 80})
    self.maskBtn:SetWidth({0, 180})
    self.maskBtn:SetImage("set:setting_base.json image:tap_left_click.png")
    self.maskText = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "maskText")
    self.maskText:SetArea({0, 0}, {0, -7}, {0.8, 0}, {1, 0})
    self.maskText:SetTextVertAlign(1)
    self.maskText:SetTextHorzAlign(1)
    self.maskText:SetText(teamName .. 1)
    self.maskBtn:AddChildWindow(self.maskText)
    self.maskBtn:SetXPosition({0, 46})
    self.maskBtn:SetYPosition({0, 80})
    self.m_root:AddChildWindow(self.maskBtn)  
    self.selectIndex = 1 
end

function M:initGrid(selectIndex)
    self.ltGrid:RemoveAllItems()
    local firstBtn = {}
    for key = 1, self.teamNum do
        local btn = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "btn" .. key)
        btn:SetHeight({0, 80})
        btn:SetWidth({1, 0})
        btn:SetImage("set:setting_base.json image:tap_left_empty.png")
        local btnText = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "btnText" .. key)
        btnText:SetArea({0, 0}, {0, 0}, {0.8, 0}, {1, 0})
        btnText:SetTextVertAlign(1)
        btnText:SetTextHorzAlign(1)
        btnText:SetText(teamName .. key)
        btnText:SetTextColor({44 / 255, 177 / 255, 130 / 255,1})
        btn:AddChildWindow(btnText)
        self:subscribe(btn, UIEvent.EventWindowTouchUp, function()
            self:setSelectMask(btn, btnText:GetText())
            self.selectIndex = key
            self:setData()
            self.infoGrid:ResetPos()
        end)
        if key == selectIndex then
            firstBtn = {btn = btn, btnText = btnText:GetText()}
        end
        self.ltGrid:AddItem(btn)
    end
    World.Timer(1, function()
        self:setSelectMask(firstBtn.btn, firstBtn.btnText)
        return false
    end)
end

function M:initTeamItem()
    local winName1 = "mapEditteamDetailItemTop"
    local winName2 = "mapEditteamDetailItemBottom2"
    self.infoTopWnd = UI:getWnd(winName1) or nil
    self.infoBotWnd = UI:getWnd(winName2) or nil
    self.infoGrid:AddItem(self.infoTopWnd:root())
    self.infoGrid:AddItem(self.infoBotWnd:root())
end

function M:setSelectMask(btn, text)
    local y = btn:GetYPosition()[2]
    self.maskBtn:SetYPosition({0, y + 80})
    self.maskText:SetText(text)
end

function M:checkTeamColorChange(newData)
    if not newData then
        return
    end
    local check = false
    for i, v in ipairs(newData) do
        local color = teamColor[i] and teamColor[i].color
        if not color or color ~= v.color then 
            check = true
        end
    end
    if check then
        entity_obj:allEntityCmd("cehckTeamCorrelation", function(entity)
            return true
        end)
    end
end

function M:setData()
    self.infoBotWnd:onOpen(self.selectIndex, teamData)
    self.infoTopWnd:onOpen(self.selectIndex, teamData)
end

function M:onOpen(teamNum, selectIndex)
    refreshTeamData()
    self.teamNum = teamNum
    self.selectIndex = selectIndex or 1
    self:initGrid(self.selectIndex)
    self:setData()
    --todo init data
end

function M:delTeam()
    local tipContext = Lang:toText("win.team.del.team.tips") or ""
    local tipsWnd = UI:openWnd("mapEditTeamSettingTip", function()
        if self.teamNum == 1 then
            global_setting:saveGameTeamMode(false)
            self:sureSave()
        else
            refreshTeamData()
            table.remove(teamData, self.selectIndex)
            global_setting:saveEditTeamMsg(teamData, false)
            if self.selectIndex == self.teamNum then
                self.selectIndex = self.selectIndex -1
            end
            self.teamNum = self.teamNum -1
            self:initGrid(self.selectIndex)
            self:setData()
        end
        Lib.emitEvent("del_team")
    end, nil, tipContext)
    tipsWnd:switchBtnPosition()
end

function M:onClose()
    self.infoBotWnd:onClose()
    self.infoTopWnd:onClose()
    Lib.emitEvent(Event.EVENT_CLOSE_TEAM_DETAIL)
end

function M:onReload(reloadArg)

end

return M