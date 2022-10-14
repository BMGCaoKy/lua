--Move TeamInfo from ToolBar
function M:init()
	 WinBase.init(self, "TopTeamInfo.json")

	Lib.lightSubscribeEvent("error!!!!! : win_topteamInfo lib event : EVENT_PLAYER_LOGIN", Event.EVENT_PLAYER_LOGIN, function(player)
        if not World.cfg.hideTeamStatusBar and next(Game.GetAllTeamsInfo()) then
			self:updateTeamInfo(player.teamID)
		end	
    end)

    Lib.lightSubscribeEvent("error!!!!! : win_topteamInfo lib event : EVENT_PLAYER_LOGOUT", Event.EVENT_PLAYER_LOGOUT, function(player)
        if not World.cfg.hideTeamStatusBar and next(Game.GetAllTeamsInfo()) then
			self:updateTeamInfo(player.teamID)
		end
    end)

    Lib.lightSubscribeEvent("error!!!!! : win_topteamInfo lib event : EVENT_UPDATE_TEAM_INFO", Event.EVENT_UPDATE_TEAM_INFO, function(teamID)
        if not World.cfg.hideTeamStatusBar then
            self:updateTeamInfo(teamID)
        end
    end)

    Lib.lightSubscribeEvent("error!!!!! : win_topteamInfo lib event : EVENT_UPDATE_TEAM_STATUS_BAR", Event.EVENT_UPDATE_TEAM_STATUS_BAR, function(data)
        local new, old, objID = data.newTeamID, data.oldTeamID, data.objID
        if old ~= 0 then
            self:updateTeamInfo(old)
        end
        if new ~= 0 then
            self:updateTeamInfo(new)
        end
        if Me.objID == objID then
            self:updateTeamBg(new, old)
        end
    end)

end

function M:setTeamInfo(teamID, teamInfo)
    local item = self:child("Top-Team-List-" .. teamID)
    if not item then --only show four team status bar
        return
    end
    item:SetVisible(true)
    local teamView = self.teamViews[teamID]
    teamView.info:SetVisible(true)
    teamView.title:SetVisible(true)
    teamView.icon:SetVisible(true)
    local count = teamInfo.playerCount
    teamView.info:SetText(count .. "/" .. count)
    teamView.title:SetText(Lang:toText("team.name." .. teamID))
    local icon = teamInfo.state and (World.cfg[teamInfo.state .. "." .. teamID] or World.cfg[teamInfo.state])
    if not icon then
        if teamID == 1 then
            icon = "set:new_gui_material.json image:team_yellow"
        elseif teamID == 2 then
            icon = "set:new_gui_material.json image:team_green"
        elseif teamID == 3 then
            icon = "set:new_gui_material.json image:team_blue"
        elseif teamID == 4 then
            icon = "set:new_gui_material.json image:team_red"
        else
            icon = "set:new_gui_material.json image:team_purple"
        end
    end
    teamView.icon:SetImage(icon)
end

function M:updateTeamBg(teamID, oldTeamId)
    if oldTeamId and oldTeamId == teamID then
        return
    end
    local tl = self:child("Top-Team-List-" .. (teamID or 0))
    if tl then
        tl:SetBackgroundColor({ 247/255, 136/255, 57/255 , 1 })
        local tlIdBg = self.teamViews[teamID].bg
        tlIdBg:SetVisible(true)
        tlIdBg:SetDrawColor({ 125/255, 125/255, 125/255 , 0.5 })
    end
    tl = self:child("Top-Team-List-" .. (oldTeamId or 0))
    if tl then
        tl:SetBackgroundColor({ 0, 0, 0 , 0 })
        local tlIdBg = self.teamViews[oldTeamId].bg
        tlIdBg:SetVisible(false)
        tlIdBg:SetDrawColor({ 0, 0, 0 , 0 })
    end
end

function M:updateTeamInfo(teamID)
    if not self.showTeamInfo then
        self:initTeamInfoView()
    else
        local teamInfo = Game.GetAllTeamsInfo()[teamID]
        if not teamInfo then
            return
        end
        self:setTeamInfo(teamID, teamInfo)
    end
end

function M:initTeamInfoView()
    local teamID = Me:getValue("teamId")
    if teamID == 0 then
        return
    end
    self.teamList = self:child("Top-Team-List")
    local views = {}
    for i = 1, 4 do
        local temp = {}
        temp.bg = self:child("Top-Team-List-bg-" .. i)
        temp.icon = self:child("Top-Team-List-icon-" .. i)
        temp.title = self:child("Top-Team-List-title-" .. i)
        temp.info = self:child("Top-Team-List-info-" .. i)
        temp.bg:SetVisible(false)
        temp.icon:SetVisible(false)
        temp.title:SetVisible(false)
        temp.info:SetVisible(false)
        views[i] = temp
    end
    self.teamViews = views

	self:updateTeamBg(teamID)

    self.teamList:SetVisible(true)

    for i, teamInfo in ipairs(Game.GetAllTeamsInfo()) do
        self:setTeamInfo(i, teamInfo)
    end
    self.showTeamInfo = true
end

return M
